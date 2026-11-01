#!/usr/bin/env python3
"""Ingest PDFs into a local FAISS index with page-level OCR fallback and hash caching."""

import argparse
import hashlib
import json
import os
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path

BACKEND_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(BACKEND_DIR))

import faiss
import numpy as np
import pytesseract
from pdf2image import convert_from_path
from pypdf import PdfReader
from sentence_transformers import SentenceTransformer

from app.rag.query_router import classify_document_domain


DEFAULT_MODEL = "BAAI/bge-small-en-v1.5"
DEFAULT_CHUNK_SIZE = 500
DEFAULT_CHUNK_OVERLAP = 50
DEFAULT_OCR_THRESHOLD = 40
DEFAULT_BATCH_SIZE = 64


def md5_file(path, block_size=1024 * 1024):
    digest = hashlib.md5()
    with path.open("rb") as pdf_file:
        for block in iter(lambda: pdf_file.read(block_size), b""):
            digest.update(block)
    return digest.hexdigest()


def extract_pdf_text(path, ocr_threshold, dpi, poppler_path=None):
    reader = PdfReader(str(path))
    page_texts = []

    for page_number, page in enumerate(reader.pages, start=1):
        text = (page.extract_text() or "").strip()

        if len(text) < ocr_threshold:
            images = convert_from_path(
                str(path),
                dpi=dpi,
                first_page=page_number,
                last_page=page_number,
                fmt="png",
                grayscale=True,
                thread_count=1,
                poppler_path=poppler_path,
            )
            try:
                text = pytesseract.image_to_string(images[0]).strip() if images else ""
            finally:
                for image in images:
                    image.close()

        if text:
            page_texts.append(text)

    return "\n\n".join(page_texts), len(reader.pages)


def chunk_text(text, chunk_size, overlap):
    if chunk_size <= 0:
        raise ValueError("chunk_size must be greater than zero")
    if overlap < 0 or overlap >= chunk_size:
        raise ValueError("overlap must be non-negative and smaller than chunk_size")

    normalized = " ".join(text.split())
    chunks = []
    start = 0

    while start < len(normalized):
        end = min(start + chunk_size, len(normalized))
        if end < len(normalized):
            boundary = normalized.rfind(" ", start, end)
            if boundary > start:
                end = boundary

        chunk = normalized[start:end].strip()
        if chunk:
            chunks.append(chunk)
        if end >= len(normalized):
            break
        start = max(end - overlap, start + 1)

    return chunks


def atomic_write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary_path = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="w",
            encoding="utf-8",
            dir=path.parent,
            prefix=f".{path.name}.",
            suffix=".tmp",
            delete=False,
        ) as temporary_file:
            temporary_path = Path(temporary_file.name)
            json.dump(value, temporary_file, ensure_ascii=False, indent=2)
            temporary_file.flush()
            os.fsync(temporary_file.fileno())
        os.replace(temporary_path, path)
    finally:
        if temporary_path and temporary_path.exists():
            temporary_path.unlink()


def atomic_write_faiss(path, index):
    path.parent.mkdir(parents=True, exist_ok=True)
    file_descriptor, temporary_name = tempfile.mkstemp(
        dir=path.parent,
        prefix=f".{path.name}.",
        suffix=".tmp",
    )
    os.close(file_descriptor)
    temporary_path = Path(temporary_name)
    try:
        faiss.write_index(index, str(temporary_path))
        os.replace(temporary_path, path)
    finally:
        if temporary_path.exists():
            temporary_path.unlink()


def load_state(index_path, metadata_path, model_name, dimension):
    if index_path.exists() != metadata_path.exists():
        raise RuntimeError(
            "Index and metadata files must either both exist or both be absent. "
            "Restore the missing file or choose a new --output-dir."
        )

    if not index_path.exists():
        return faiss.IndexFlatL2(dimension), {
            "model_name": model_name,
            "embedding_dimension": dimension,
            "vector_count": 0,
            "chunks": [],
            "processed_files": {},
        }

    index = faiss.read_index(str(index_path))
    with metadata_path.open("r", encoding="utf-8") as metadata_file:
        metadata = json.load(metadata_file)

    if index.d != dimension or metadata.get("embedding_dimension") != dimension:
        raise ValueError(
            f"Saved embedding dimension does not match model dimension {dimension}."
        )
    if metadata.get("model_name") != model_name:
        raise ValueError(
            f"Saved index uses model {metadata.get('model_name')!r}, not "
            f"{model_name!r}. Choose a new --output-dir or use the matching model."
        )
    if index.ntotal != len(metadata.get("chunks", [])):
        raise ValueError(
            "FAISS vector count does not match metadata chunk count; refusing "
            "to append to an inconsistent index."
        )
    if metadata.get("vector_count") != index.ntotal:
        raise ValueError(
            "Metadata vector_count does not match the FAISS index; refusing "
            "to append to an inconsistent index."
        )

    metadata.setdefault("processed_files", {})
    return index, metadata


def ingest(args):
    input_dir = args.input_dir.resolve()
    output_dir = args.output_dir.resolve()
    if not input_dir.is_dir():
        raise NotADirectoryError(f"Input directory does not exist: {input_dir}")
    if input_dir == output_dir:
        raise ValueError("The output directory must not be the input directory.")

    cache_path = output_dir / "processed_files.json"
    output_dir.mkdir(parents=True, exist_ok=True)
    if cache_path.exists():
        with cache_path.open("r", encoding="utf-8") as cache_file:
            processed_files = json.load(cache_file)
    else:
        processed_files = {}

    model = SentenceTransformer(args.model, device=args.device)
    dimension = model.get_sentence_embedding_dimension()
    if not dimension:
        raise ValueError(f"Could not determine embedding dimension for {args.model!r}.")

    namespace_states = {}
    pdf_paths = sorted(
        path for path in args.input_dir.rglob("*")
        if path.is_file() and path.suffix.lower() == ".pdf"
    )

    added_files = 0
    added_chunks = 0
    errors = []

    print(f"Found {len(pdf_paths)} PDF file(s) under {args.input_dir}")

    for pdf_path in pdf_paths:
        try:
            file_hash = md5_file(pdf_path)
            if file_hash in processed_files:
                print(f"Skipping cached PDF: {pdf_path}")
                continue

            print(f"Processing: {pdf_path}")
            text, page_count = extract_pdf_text(
                pdf_path,
                ocr_threshold=args.ocr_threshold,
                dpi=args.dpi,
                poppler_path=args.poppler_path,
            )
            chunks = chunk_text(text, args.chunk_size, args.chunk_overlap)
            if not chunks:
                raise ValueError(
                    "No text was extracted. Check the PDF, OCR installation, "
                    "and Tesseract language configuration."
                )

            namespace = classify_document_domain(
                title=pdf_path.stem,
                subject=pdf_path.parent.name,
                text=text,
            )
            print(f"  Classified document namespace: {namespace}")
            if namespace not in namespace_states:
                namespace_dir = output_dir / "namespaces" / namespace
                namespace_states[namespace] = load_state(
                    namespace_dir / "documents.faiss",
                    namespace_dir / "chunks.json",
                    args.model,
                    dimension,
                )
            index, metadata = namespace_states[namespace]

            embedding_batches = []
            for start in range(0, len(chunks), args.batch_size):
                batch = chunks[start:start + args.batch_size]
                embeddings = model.encode(
                    batch,
                    batch_size=args.batch_size,
                    convert_to_numpy=True,
                    show_progress_bar=False,
                    normalize_embeddings=False,
                )
                embeddings = np.asarray(embeddings, dtype=np.float32)
                if embeddings.shape != (len(batch), dimension):
                    raise ValueError(
                        f"Unexpected embedding shape {embeddings.shape}; expected "
                        f"({len(batch)}, {dimension})."
                    )
                embedding_batches.append(embeddings)

            first_vector_id = index.ntotal
            new_records = [
                {
                    "vector_id": first_vector_id + offset,
                    "source_file": str(pdf_path.resolve()),
                    "source_title": pdf_path.stem,
                    "source_hash": file_hash,
                    "page_count": page_count,
                    "chunk_index": offset,
                    "text": chunk,
                }
                for offset, chunk in enumerate(chunks)
            ]
            index.add(np.concatenate(embedding_batches, axis=0))

            metadata["chunks"].extend(new_records)
            metadata["vector_count"] = index.ntotal
            metadata["model_name"] = args.model
            metadata["embedding_dimension"] = dimension
            namespace_dir = output_dir / "namespaces" / namespace
            atomic_write_faiss(namespace_dir / "documents.faiss", index)
            atomic_write_json(namespace_dir / "chunks.json", metadata)
            processed_files[file_hash] = {
                "source_file": str(pdf_path.resolve()),
                "domain": namespace,
                "processed_at": datetime.now(timezone.utc).isoformat(),
                "page_count": page_count,
                "chunk_count": len(chunks),
            }
            atomic_write_json(cache_path, processed_files)
            added_files += 1
            added_chunks += len(chunks)
            print(
                f"  Added {len(chunks)} chunk(s) from {page_count} page(s) "
                f"to namespace '{namespace}'"
            )
        except Exception as error:
            errors.append((pdf_path, error))
            print(f"ERROR processing {pdf_path}: {error}", file=sys.stderr)

    if added_chunks:
        print(f"Saved namespace indices and metadata under: {output_dir / 'namespaces'}")
        print(f"Saved MD5 cache: {cache_path}")
    else:
        print("No new documents to index.")

    print(f"Complete: {added_files} PDF(s), {added_chunks} chunk(s) added.")
    return 1 if errors else 0


def parse_args():
    parser = argparse.ArgumentParser(
        description="Extract, embed, and index PDF documents with page-level OCR fallback."
    )
    parser.add_argument("input_dir", type=Path, help="Directory to search recursively for PDFs")
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path("rag_index"),
        help="Directory for per-domain FAISS indices, metadata, and MD5 cache",
    )
    parser.add_argument("--model", default=DEFAULT_MODEL, help="SentenceTransformer model")
    parser.add_argument(
        "--device",
        default=None,
        help="Embedding device, e.g. cpu, cuda, or mps (default: library auto-detection)",
    )
    parser.add_argument("--chunk-size", type=int, default=DEFAULT_CHUNK_SIZE)
    parser.add_argument("--chunk-overlap", type=int, default=DEFAULT_CHUNK_OVERLAP)
    parser.add_argument("--ocr-threshold", type=int, default=DEFAULT_OCR_THRESHOLD)
    parser.add_argument("--batch-size", type=int, default=DEFAULT_BATCH_SIZE)
    parser.add_argument("--dpi", type=int, default=200, help="Resolution for OCR page renders")
    parser.add_argument(
        "--poppler-path",
        default=None,
        help="Optional path to Poppler binaries required by pdf2image on Windows",
    )
    return parser.parse_args()


if __name__ == "__main__":
    arguments = parse_args()
    if (
        arguments.ocr_threshold < 0
        or arguments.batch_size <= 0
        or arguments.dpi <= 0
        or arguments.chunk_size <= 0
        or arguments.chunk_overlap < 0
        or arguments.chunk_overlap >= arguments.chunk_size
    ):
        raise SystemExit(
            "OCR threshold must be non-negative; batch size, DPI, and chunk "
            "size must be positive; overlap must be non-negative and smaller "
            "than chunk size."
        )
    try:
        raise SystemExit(ingest(arguments))
    except Exception as error:
        print(f"Fatal ingestion error: {error}", file=sys.stderr)
        raise SystemExit(1) from error
