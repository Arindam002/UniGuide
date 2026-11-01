# backend/app/rag/pipeline.py

import os
from tqdm import tqdm
from app.processors.pdf_processor import PDFProcessor
from app.rag.retriever import Retriever
from app.rag.reranker import Reranker
from app.rag.generator import Generator
from app.services import RagService
from app.rag.vector_store import VectorStore
from app.rag.chunker import Chunker
from app.rag.embedder import Embedder
from database.db import get_connection
from app.rag.query_router import classify_document_domain


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

        for item in tqdm(pdf_files, desc="Processing PDFs"):
            pdf_path = item["pdf_path"]
            category = item["category"]
            branch = item["branch"]
            semester = item["semester"]
            subject = item["subject"]

            if self.processor.already_processed(pdf_path):
                print(f"Skipping already processed file: {pdf_path}")
                continue

            print(f"\nProcessing: {pdf_path} (Category: {category})")

            # Extract text (with OCR fallback)
            text, total_pages, _used_ocr = self.processor.extract_text(pdf_path)

            if not text or len(text.strip()) < 10:
                print(f"No text extracted from {pdf_path}. Skipping.")
                continue

            domain = classify_document_domain(
                title=os.path.basename(pdf_path),
                subject=subject,
                text=text,
            )

            # Store document metadata in DB
            doc_id = self.processor.store_document(
                path=pdf_path,
                category=category,
                branch=branch,
                semester=semester,
                subject=subject,
                total_pages=total_pages,
                content=text,
                domain=domain,
            )

            if not doc_id:
                print(f"Could not store document metadata for {pdf_path}. Skipping.")
                continue

            if category not in ["books", "pyqs"]:
                print(f"Skipping vector indexing for non-RAG category: {category}")
                continue

            # -----------------------------
            # Chunking
            # -----------------------------
            chunks = self.chunker.chunk_text(text)

            if not chunks:
                print(f"No chunks generated from {pdf_path}. Skipping.")
                continue

            # -----------------------------
            # Generate embeddings
            # -----------------------------
            embeddings = self.embedder.embed(chunks)

            # -----------------------------
            # Add embeddings to FAISS
            # -----------------------------
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

            # -----------------------------
            # Store chunks in DB
            # -----------------------------
            cursor = self.conn.cursor()

            for i, chunk in enumerate(chunks):
                cursor.execute(
                    """
                    INSERT INTO chunks
                    (document_id, chunk_text, vector_id, store_type, chunk_index)
                    VALUES (?, ?, ?, ?, ?)
                    """,
                    (doc_id, chunk, vector_ids[i], category, i)
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
