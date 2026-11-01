import os

from app.processors.pdf_processor import PDFProcessor
from app.rag.chunker import Chunker
from app.rag.embedder import Embedder
from app.rag.vector_store import VectorStore

from database.db import get_db_connection


class DocumentIngestion:

    def __init__(self):
        self.processor = PDFProcessor()
        self.chunker = Chunker()
        self.embedder = Embedder()
        self.vector_store = VectorStore()

    def process_pdf(self, pdf_path, category, branch, semester, subject):

        # =========================
        # 0️⃣ Normalize file path
        # =========================
        pdf_path = os.path.abspath(pdf_path)
        file_name = os.path.basename(pdf_path)

        conn = get_db_connection()
        cursor = conn.cursor()

        # =========================
        # 1️⃣ Skip if already indexed
        # =========================
        cursor.execute(
            "SELECT id FROM documents WHERE file_path = ?",
            (pdf_path,)
        )

        existing = cursor.fetchone()

        if existing:
            print(f"Skipping already processed file: {pdf_path}")
            conn.close()
            return

        print(f"\nProcessing file: {pdf_path}")

        # =========================
        # 2️⃣ Extract text from PDF
        # =========================
        try:
            text, total_pages = self.processor.extract_text(pdf_path)
        except Exception as e:
            print(f"Text extraction failed: {e}")
            conn.close()
            return

        if not text or len(text.strip()) == 0:
            print("No text extracted.")
            conn.close()
            return

        # =========================
        # 3️⃣ Insert document metadata
        # =========================
        cursor.execute(
            """
            INSERT INTO documents
            (name, file_path, category, branch, semester, subject, total_pages, content)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                file_name,
                pdf_path,
                category,
                branch,
                semester,
                subject,
                total_pages,
                text
            )
        )

        document_id = cursor.lastrowid

        # =========================
        # 4️⃣ Chunk text
        # =========================
        print("Chunking document...")

        chunks = self.chunker.chunk_text(text)

        if not chunks:
            print("No chunks generated.")
            conn.close()
            return

        print(f"Generated {len(chunks)} chunks")

        # =========================
        # 5️⃣ Generate embeddings
        # =========================
        print("Generating embeddings...")

        embeddings = self.embedder.embed(chunks)

        if len(embeddings) != len(chunks):
            print("Embedding mismatch error")
            conn.close()
            return

        # =========================
        # 6️⃣ Store embeddings in FAISS
        # =========================
        print("Adding vectors to FAISS...")

        vector_ids = self.vector_store.add_embeddings(embeddings)

        # =========================
        # 7️⃣ Store chunks in database
        # =========================
        for i, chunk in enumerate(chunks):

            cursor.execute(
                """
                INSERT INTO chunks
                (document_id, chunk_text, vector_id, chunk_index)
                VALUES (?, ?, ?, ?)
                """,
                (
                    document_id,
                    chunk,
                    vector_ids[i],
                    i
                )
            )

        conn.commit()
        conn.close()

        print(f"Indexed {len(chunks)} chunks successfully.")