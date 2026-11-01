import os

from app.processors.pdf_processor import PDFProcessor
from app.rag.chunker import Chunker
from app.rag.embedder import Embedder
from app.rag.vector_store import VectorStore

from database.db import get_connection
from app.rag.query_router import classify_document_domain


class DocumentIngestion:

    def __init__(self):
        self.processor = PDFProcessor()
        self.chunker = Chunker()
        self.embedder = Embedder()
        self.vector_store = VectorStore()

    def process_pdf(self, pdf_path, category, branch, semester, subject):
        pdf_path = os.path.abspath(pdf_path)
        file_name = os.path.basename(pdf_path)

        conn = get_connection()
        try:
            cursor = conn.cursor()

            # Skip if already indexed
            cursor.execute(
                "SELECT id FROM documents WHERE file_path = ?",
                (pdf_path,)
            )
            existing = cursor.fetchone()

            if existing:
                print(f"Skipping already processed file: {pdf_path}")
                return

            print(f"\nProcessing file: {pdf_path}")

            # Extract text from PDF
            try:
                text, total_pages, _used_ocr = self.processor.extract_text(pdf_path)
            except Exception as e:
                print(f"Text extraction failed: {e}")
                return

            if not text or len(text.strip()) == 0:
                print("No text extracted.")
                return

            domain = classify_document_domain(
                title=file_name,
                subject=subject,
                text=text,
            )

            # Insert document metadata
            cursor.execute(
                """
                INSERT INTO documents
                (name, file_path, file_hash, category, domain, branch, semester, subject, total_pages, content, use_for_rag)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    file_name,
                    pdf_path,
                    self.processor.get_file_hash(pdf_path),
                    category,
                    domain,
                    branch,
                    semester,
                    subject,
                    total_pages,
                    text,
                    1 if category in ["books", "pyqs"] else 0,
                )
            )

            document_id = cursor.lastrowid

            if category not in ["books", "pyqs"]:
                conn.commit()
                print(f"Stored metadata only. Skipping vector indexing for non-RAG category: {category}")
                return

            # Chunk text
            print("Chunking document...")
            chunks = self.chunker.chunk_text(text)

            if not chunks:
                print("No chunks generated.")
                return

            print(f"Generated {len(chunks)} chunks")

            # Generate embeddings
            print("Generating embeddings...")
            embeddings = self.embedder.embed(chunks)

            if len(embeddings) != len(chunks):
                print("Embedding mismatch error")
                return

            # Store embeddings in FAISS
            print("Adding vectors to FAISS...")
            vector_ids = self.vector_store.get_next_ids(
                len(embeddings),
                category,
                namespace=domain,
            )
            vector_ids = self.vector_store.add_embeddings(
                embeddings=embeddings,
                vector_ids=vector_ids,
                store_type=category,
                namespace=domain,
            )

            # Store chunks in database
            for i, chunk in enumerate(chunks):
                cursor.execute(
                    """
                    INSERT INTO chunks
                    (document_id, chunk_text, vector_id, store_type, chunk_index)
                    VALUES (?, ?, ?, ?, ?)
                    """,
                    (
                        document_id,
                        chunk,
                        vector_ids[i],
                        category,
                        i
                    )
                )

            conn.commit()
            self.vector_store.save()
            print(f"Indexed {len(chunks)} chunks successfully.")

        finally:
            conn.close()

