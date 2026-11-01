# backend/app/rag/pipeline.py

import os
from tqdm import tqdm
from app.processors.pdf_processor import PDFProcessor
from app.rag.retriever import Retriever
from app.rag.reranker import Reranker
from app.rag.generator import Generator
from app.rag.services import RagService
from app.rag.vector_store import VectorStore
from app.rag.chunker import Chunker
from app.rag.embedder import Embedder
from database.db import get_connection


class RAGPipeline:
    """
    Full RAG pipeline:
    1. PDF ingestion (books, notes, pyqs)
    2. Automatic text extraction + OCR
    3. Automatic branch/semester/subject detection
    4. Chunking & embedding into FAISS
    5. RAG-ready document storage
    """

    def __init__(self):
        self.processor = PDFProcessor()
        self.chunker = Chunker()
        self.embedder = Embedder()
        self.vector_store = VectorStore()
        self.retriever = Retriever()
        self.reranker = Reranker()
        self.generator = Generator()
        self.rag_service = RagService()
        self.conn = get_connection()

    # -----------------------------
    # Process all PDFs in data folder
    # -----------------------------
    def process_pdfs(self):
        pdf_files = self.processor.traverse_data_folder()
        print(f"Found {len(pdf_files)} PDFs to process.\n")

        for pdf_path, category in tqdm(pdf_files, desc="Processing PDFs"):
            if self.processor.already_processed(pdf_path):
                print(f"Skipping already processed file: {pdf_path}")
                continue

            print(f"\nProcessing: {pdf_path} (Category: {category})")

            # Extract text (with OCR fallback)
            text, total_pages = self.processor.extract_text(pdf_path)

            if not text or len(text.strip()) < 10:
                print(f"No text extracted from {pdf_path}. Skipping.")
                continue

            # Auto-detect branch, semester, subject
            parts = pdf_path.replace("\\", "/").split("/")
            branch = None
            semester = None
            subject = None

            for p in parts:
                p_lower = p.lower()
                if p_lower in ["cse", "ece", "eee", "mech"]:
                    branch = p_lower
                if p_lower.isdigit():
                    semester = p_lower
                if category != "pyqs":
                    # folder name as subject
                    subject = p_lower

            # Store document metadata in DB
            self.processor.store_document(
                name=os.path.basename(pdf_path),
                path=pdf_path,
                category=category,
                branch=branch,
                semester=semester,
                subject=subject,
                total_pages=total_pages,
                content=text
            )

            # -----------------------------
            # Chunking
            # -----------------------------
            chunks = self.chunker.chunk_text(text)

            # -----------------------------
            # Generate embeddings
            # -----------------------------
            embeddings = self.embedder.embed(chunks)

            # -----------------------------
            # Add embeddings to FAISS
            # -----------------------------
            vector_ids = self.vector_store.add_embeddings(embeddings)

            # -----------------------------
            # Store chunks in DB
            # -----------------------------
            cursor = self.conn.cursor()
            doc_id = cursor.execute(
                "SELECT id FROM documents WHERE file_path = ?", (os.path.abspath(pdf_path),)
            ).fetchone()[0]

            for i, chunk in enumerate(chunks):
                cursor.execute(
                    """
                    INSERT INTO chunks
                    (document_id, chunk_text, vector_id, chunk_index)
                    VALUES (?, ?, ?, ?)
                    """,
                    (doc_id, chunk, vector_ids[i], i)
                )

            self.conn.commit()
            self.vector_store.save()
            print(f"Document indexed successfully: {os.path.basename(pdf_path)}")

        print("\nAll PDFs processed successfully.")

    # -----------------------------
    # Run the RAG pipeline
    # -----------------------------
    def run(self):
        # Step 1: Ingest and index PDFs
        self.process_pdfs()

        # Step 2: RAG service ready for queries
        print("\nRAG pipeline is ready. You can now use RagService to ask questions.")