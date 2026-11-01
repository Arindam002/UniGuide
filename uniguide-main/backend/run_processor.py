import os

from database.db import get_connection
from app.processors.pdf_processor import PDFProcessor
from app.rag.chunker import Chunker
from app.rag.embedder import Embedder
from app.rag.vector_store import VectorStore


# -----------------------------------------
# Save chunks into database
# -----------------------------------------
def save_chunks(document_id, chunks, vector_ids):
    if len(chunks) != len(vector_ids):
        raise ValueError(
            f"Mismatch while saving chunks: {len(chunks)} chunks vs {len(vector_ids)} vector_ids"
        )

    conn = get_connection()
    cursor = conn.cursor()

    try:
        for i, chunk in enumerate(chunks):
            cursor.execute(
                """
                INSERT INTO chunks
                (document_id, chunk_text, vector_id, chunk_index)
                VALUES (?, ?, ?, ?)
                """,
                (document_id, chunk, int(vector_ids[i]), i)
            )
        conn.commit()
    except Exception as e:
        conn.rollback()
        raise Exception(f"Database save_chunks failed: {e}")
    finally:
        conn.close()


# -----------------------------------------
# Cleanup if processing fails after document
# insertion
# -----------------------------------------
def cleanup_document(document_id):
    conn = get_connection()
    cursor = conn.cursor()

    try:
        cursor.execute("DELETE FROM chunks WHERE document_id = ?", (document_id,))
        cursor.execute("DELETE FROM documents WHERE id = ?", (document_id,))
        conn.commit()
    except Exception as e:
        conn.rollback()
        print(f"[WARN] Cleanup failed for document_id={document_id}: {e}")
    finally:
        conn.close()


# -----------------------------------------
# Count DB chunks
# -----------------------------------------
def get_db_chunk_count():
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("SELECT COUNT(*) FROM chunks")
        return cursor.fetchone()[0]
    finally:
        conn.close()


# -----------------------------------------
# Process a single PDF
# -----------------------------------------
def process_pdf(pdf_path, chunker, embedder, vector_store):
    abs_path = os.path.abspath(pdf_path)
    file_name = os.path.basename(abs_path)

    processor = PDFProcessor()
    document_id = None

    try:
        print(f"\n[INFO] Processing: {file_name}")

        # 1. Skip if already processed
        if processor.already_processed(abs_path):
            return f"[SKIP] {file_name} (Already processed)"

        # 2. Extract metadata
        branch, semester, subject, category = processor.extract_metadata(abs_path)

        # 3. Extract text
        text, total_pages = processor.extract_text(abs_path)

        if not text or len(text.strip()) < 100:
            return f"[WARN] {file_name} (Insufficient text extracted)"

        # 4. Create chunks
        chunks = chunker.chunk_text(text)
        if not chunks:
            return f"[WARN] {file_name} (No chunks created)"

        print(f"[INFO] {file_name}: {len(chunks)} chunks created")

        # 5. Generate embeddings
        embeddings = embedder.embed(chunks, show_progress_bar=False)

        if embeddings is None or len(embeddings) != len(chunks):
            return (
                f"[ERROR] {file_name} "
                f"(Embedding count mismatch: chunks={len(chunks)}, "
                f"embeddings={len(embeddings) if embeddings is not None else 0})"
            )

        # 6. Store document only after chunking/embedding succeeds
        document_id = processor.store_document(
            path=abs_path,
            category=category,
            branch=branch,
            semester=semester,
            subject=subject,
            total_pages=total_pages,
            content=text[:1000]
        )

        if not document_id:
            return f"[FAIL] {file_name} (Failed to store document record)"

        # 7. Add embeddings to vector store
        vector_ids = vector_store.add_embeddings(embeddings)

        if vector_ids is None or len(vector_ids) != len(chunks):
            cleanup_document(document_id)
            return (
                f"[ERROR] {file_name} "
                f"(Vector ID mismatch: chunks={len(chunks)}, "
                f"vector_ids={len(vector_ids) if vector_ids is not None else 0})"
            )

        # 8. Save chunks with vector mapping
        save_chunks(document_id, chunks, vector_ids)

        return f"[SUCCESS] {file_name} ({len(chunks)} chunks stored)"

    except Exception as e:
        if document_id is not None:
            cleanup_document(document_id)
        return f"[ERROR] {file_name} -> {str(e)}"

    finally:
        if hasattr(processor, "conn") and processor.conn:
            processor.conn.close()


# -----------------------------------------
# Main processing
# -----------------------------------------
def main():
    print("--- UniGuide Data Ingestion Pipeline ---")

    # IMPORTANT:
    # Do NOT call init_db() here.
    # Run python init_db.py manually only when you want a full DB reset.

    # 1. Initialize pipeline components
    chunker = Chunker(chunk_size=1200, overlap=200, min_chunk_size=400)
    embedder = Embedder()
    vector_store = VectorStore()

    # 2. Safety check before ingestion
    existing_db_chunks = get_db_chunk_count()
    existing_faiss = vector_store.get_total_vectors()

    print(f"[CHECK] Existing DB chunks : {existing_db_chunks}")
    print(f"[CHECK] Existing FAISS vecs: {existing_faiss}")

    if existing_db_chunks == 0 and existing_faiss > 0:
        raise RuntimeError(
            "FAISS index already contains vectors but DB chunks table is empty. "
            "Reset both DB and FAISS before running ingestion."
        )

    if existing_db_chunks > 0 and existing_faiss == 0:
        raise RuntimeError(
            "DB chunks exist but FAISS index is empty. "
            "Reset both DB and FAISS before running ingestion."
        )

    # 3. Discover PDFs
    scanner = PDFProcessor()
    pdf_paths = scanner.traverse_data_folder()

    if hasattr(scanner, "conn") and scanner.conn:
        scanner.conn.close()

    # Remove duplicate paths just in case
    pdf_paths = list(dict.fromkeys([os.path.abspath(path) for path in pdf_paths]))

    print(f"[INFO] Found {len(pdf_paths)} PDF files.")

    if not pdf_paths:
        print("[WARN] No PDF files found. Exiting.")
        return

    # 4. Process one by one
    success_count = 0
    skip_count = 0
    warn_count = 0
    error_count = 0

    for pdf_path in pdf_paths:
        result = process_pdf(pdf_path, chunker, embedder, vector_store)
        print(result)

        if result.startswith("[SUCCESS]"):
            success_count += 1
        elif result.startswith("[SKIP]"):
            skip_count += 1
        elif result.startswith("[WARN]"):
            warn_count += 1
        elif result.startswith("[ERROR]") or result.startswith("[FAIL]"):
            error_count += 1

    # 5. Save FAISS index at end
    try:
        vector_store.save()
        print("\n[INFO] FAISS index saved successfully.")
    except Exception as e:
        print(f"\n[ERROR] Failed to save FAISS index: {e}")

    # 6. Verify DB/FAISS consistency
    db_chunk_count = get_db_chunk_count()
    faiss_count = vector_store.get_total_vectors()

    print(f"\n[VERIFY] DB chunks  : {db_chunk_count}")
    print(f"[VERIFY] FAISS vecs : {faiss_count}")

    if db_chunk_count != faiss_count:
        print("[WARNING] DB and FAISS mismatch!")
    else:
        print("[OK] DB and FAISS match ✅")

    # 7. Final summary
    print("\n--- Pipeline Finished ---")
    print(f"[SUMMARY] Success: {success_count}")
    print(f"[SUMMARY] Skipped: {skip_count}")
    print(f"[SUMMARY] Warnings: {warn_count}")
    print(f"[SUMMARY] Errors: {error_count}")


if __name__ == "__main__":
    main()