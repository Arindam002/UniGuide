import os
import gc

from database.db import get_connection
from app.processors.pdf_processor import PDFProcessor
from app.rag.chunker import Chunker
from app.rag.embedder import Embedder
from app.rag.vector_store import VectorStore
from app.rag.query_router import classify_document_domain


# -----------------------------------------
# Save chunks into database
# -----------------------------------------
def save_chunks(document_id, chunks, vector_ids, store_type):
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
                (document_id, chunk_text, vector_id, store_type, chunk_index)
                VALUES (?, ?, ?, ?, ?)
                """,
                (document_id, chunk, int(vector_ids[i]), store_type, i)
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
        cursor.execute("DELETE FROM diagrams WHERE document_id = ?", (document_id,))
        cursor.execute("DELETE FROM documents WHERE id = ?", (document_id,))
        conn.commit()
    except Exception as e:
        conn.rollback()
        print(f"[WARN] Cleanup failed for document_id={document_id}: {e}")
    finally:
        conn.close()


# -----------------------------------------
# Count DB chunks by category
# -----------------------------------------
def get_db_chunk_counts():
    conn = get_connection()
    cursor = conn.cursor()

    try:
        cursor.execute(
            """
            SELECT d.category, COUNT(*) AS cnt
            FROM chunks c
            JOIN documents d ON c.document_id = d.id
            GROUP BY d.category
            """
        )
        rows = cursor.fetchall()

        counts = {"books": 0, "pyqs": 0}
        for row in rows:
            category = str(row[0]).strip().lower()
            if category in counts:
                counts[category] = row[1]

        return counts
    finally:
        conn.close()


# -----------------------------------------
# Process a single PDF
# -----------------------------------------
def process_pdf(pdf_input, chunker, embedder, vector_store):
    if isinstance(pdf_input, dict):
        pdf_path = pdf_input["pdf_path"]
        branch = pdf_input.get("branch")
        semester = pdf_input.get("semester")
        subject = pdf_input.get("subject")
        category = pdf_input.get("category")
    else:
        pdf_path = pdf_input
        branch = None
        semester = None
        subject = None
        category = None

    abs_path = os.path.abspath(pdf_path)
    file_name = os.path.basename(abs_path)

    document_id = None
    chunks = None
    embeddings = None
    vector_ids = None
    text = None

    try:
        print(f"\n[INFO] Processing: {file_name}")

        with PDFProcessor() as processor:
            if processor.already_processed(abs_path):
                return f"[SKIP] {file_name} (Already processed)"

            # If metadata not passed, extract it
            if not category:
                branch, semester, subject, category = processor.extract_metadata(abs_path)

            category = str(category or "").strip().lower()

            # Processor returns: text, total_pages, used_ocr
            text, total_pages, used_ocr = processor.extract_text(abs_path)

            if not text or len(text.strip()) < 100:
                return f"[WARN] {file_name} (Insufficient text extracted)"

            domain = classify_document_domain(
                title=file_name,
                subject=subject,
                text=text,
            )

            # Store document first
            document_id = processor.store_document(
                path=abs_path,
                category=category,
                branch=branch,
                semester=semester,
                subject=subject,
                total_pages=total_pages,
                content=text[:1000],
                domain=domain,
            )

            if not document_id:
                return f"[FAIL] {file_name} (Failed to store document record)"

            # Extract diagrams only for books and non-OCR PDFs
            diagram_count = 0
            if processor.should_extract_diagrams(category, used_ocr):
                diagram_count = processor.extract_and_store_diagrams(
                    pdf_path=abs_path,
                    document_id=document_id,
                    category=category,
                    branch=branch,
                    semester=semester,
                    subject=subject
                )
            else:
                if used_ocr:
                    print(f"[INFO] Skipping diagram extraction for scanned/OCR PDF: {file_name}")
                else:
                    print(f"[INFO] Skipping diagram extraction for category: {category}")

        # NOTES: store document only, do not create embeddings/chunks
        if category == "notes":
            return f"[SUCCESS] {file_name} (Notes stored, excluded from RAG, diagrams={diagram_count})"

        # Only books and pyqs go to vector store
        if category not in ["books", "pyqs"]:
            cleanup_document(document_id)
            return f"[WARN] {file_name} (Unknown category: {category})"

        chunks = chunker.chunk_text(text)
        if not chunks:
            cleanup_document(document_id)
            return f"[WARN] {file_name} (No chunks created)"

        print(f"[INFO] {file_name}: {len(chunks)} chunks created")

        embeddings = embedder.embed(chunks, show_progress_bar=False)

        if embeddings is None or len(embeddings) != len(chunks):
            cleanup_document(document_id)
            return (
                f"[ERROR] {file_name} "
                f"(Embedding count mismatch: chunks={len(chunks)}, "
                f"embeddings={len(embeddings) if embeddings is not None else 0})"
            )

        # Generate vector IDs first
        vector_ids = vector_store.get_next_ids(
            len(chunks),
            category,
            namespace=domain,
        )

        if vector_ids is None or len(vector_ids) != len(chunks):
            cleanup_document(document_id)
            return (
                f"[ERROR] {file_name} "
                f"(Vector ID generation mismatch: chunks={len(chunks)}, "
                f"vector_ids={len(vector_ids) if vector_ids is not None else 0})"
            )

        # Save DB first
        save_chunks(document_id, chunks, vector_ids, category)

        # Add to FAISS only after DB save succeeds
        added_ids = vector_store.add_embeddings(
            embeddings,
            vector_ids,
            store_type=category,
            namespace=domain,
        )

        if added_ids is None or len(added_ids) != len(chunks):
            cleanup_document(document_id)
            return (
                f"[ERROR] {file_name} "
                f"(FAISS add mismatch: chunks={len(chunks)}, "
                f"added_ids={len(added_ids) if added_ids is not None else 0})"
            )

        return (
            f"[SUCCESS] {file_name} "
            f"(category={category}, domain={domain}, "
            f"chunks={len(chunks)}, diagrams={diagram_count})"
        )

    except Exception as e:
        if document_id is not None:
            cleanup_document(document_id)
        return f"[ERROR] {file_name} -> {str(e)}"

    finally:
        # Explicit memory cleanup for large ingestion runs
        del text
        del chunks
        del embeddings
        del vector_ids
        gc.collect()


# -----------------------------------------
# Main processing
# -----------------------------------------
def main():
    print("--- UniGuide Data Ingestion Pipeline ---")

    # 1. Initialize pipeline components
    chunker = Chunker(chunk_size=1200, overlap=200)
    embedder = Embedder()
    vector_store = VectorStore()

    # 2. Safety check before ingestion
    existing_db_counts = get_db_chunk_counts()
    existing_faiss_counts = vector_store.get_total_vectors()

    print(f"[CHECK] Existing DB chunks   : {existing_db_counts}")
    print(f"[CHECK] Existing FAISS vecs  : {existing_faiss_counts}")

    if existing_db_counts["books"] == 0 and existing_faiss_counts["books"] > 0:
        raise RuntimeError(
            "Books FAISS index contains vectors but DB has no books chunks. "
            "Reset both DB and books FAISS before running ingestion."
        )

    if existing_db_counts["books"] > 0 and existing_faiss_counts["books"] == 0:
        raise RuntimeError(
            "DB has books chunks but books FAISS index is empty. "
            "Reset both DB and books FAISS before running ingestion."
        )

    if existing_db_counts["pyqs"] == 0 and existing_faiss_counts["pyqs"] > 0:
        raise RuntimeError(
            "PYQs FAISS index contains vectors but DB has no PYQ chunks. "
            "Reset both DB and pyqs FAISS before running ingestion."
        )

    if existing_db_counts["pyqs"] > 0 and existing_faiss_counts["pyqs"] == 0:
        raise RuntimeError(
            "DB has PYQ chunks but PYQs FAISS index is empty. "
            "Reset both DB and pyqs FAISS before running ingestion."
        )

    # 3. Discover PDFs
    with PDFProcessor() as scanner:
        pdf_items = scanner.traverse_data_folder()

    print(f"[INFO] Found {len(pdf_items)} PDF files.")

    if not pdf_items:
        print("[WARN] No PDF files found. Exiting.")
        return

    # Remove duplicate paths while preserving metadata
    unique_items = {}
    for item in pdf_items:
        key = os.path.abspath(item["pdf_path"])
        if key not in unique_items:
            unique_items[key] = item

    pdf_items = list(unique_items.values())
    print(f"[INFO] Unique PDF files to process: {len(pdf_items)}")

    # 4. Process one by one
    success_count = 0
    skip_count = 0
    warn_count = 0
    error_count = 0

    for item in pdf_items:
        result = process_pdf(item, chunker, embedder, vector_store)
        print(result)

        if result.startswith("[SUCCESS]"):
            success_count += 1
        elif result.startswith("[SKIP]"):
            skip_count += 1
        elif result.startswith("[WARN]"):
            warn_count += 1
        elif result.startswith("[ERROR]") or result.startswith("[FAIL]"):
            error_count += 1

    # 5. Save FAISS indices at end
    try:
        vector_store.save()
        print("\n[INFO] FAISS indices saved successfully.")
    except Exception as e:
        print(f"\n[ERROR] Failed to save FAISS indices: {e}")

    # 6. Verify DB/FAISS consistency
    db_chunk_counts = get_db_chunk_counts()
    faiss_counts = vector_store.get_total_vectors()

    print(f"\n[VERIFY] DB chunks   : {db_chunk_counts}")
    print(f"[VERIFY] FAISS vecs  : {faiss_counts}")

    books_match = db_chunk_counts["books"] == faiss_counts["books"]
    pyqs_match = db_chunk_counts["pyqs"] == faiss_counts["pyqs"]

    if not books_match or not pyqs_match:
        print("[WARNING] DB and FAISS mismatch detected!")
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