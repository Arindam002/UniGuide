# backend/run_processor.py

import os
import sys
from tqdm import tqdm

sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from app.rag.pipeline import RAGPipeline
from app.processors.pdf_processor import PDFProcessor


def main():
    print("Initializing RAG pipeline and PDF processor...")

    # -------------------------
    # Initialize PDF processor
    # -------------------------
    processor = PDFProcessor()

    # Traverse all PDFs
    pdf_files = processor.traverse_data_folder()

    print(f"Found {len(pdf_files)} PDF files to process.\n")

    for pdf_path, category in tqdm(pdf_files, desc="Processing PDFs"):
        # Skip already processed files
        if processor.already_processed(pdf_path):
            print(f"Skipping already processed file: {pdf_path}")
            continue

        print(f"\nProcessing file: {pdf_path} (Category: {category})")

        # Extract text (will OCR if scanned)
        text = processor.extract_text(pdf_path)

        if not text or len(text.strip()) < 10:
            print("No text extracted. Skipping this PDF.")
            continue

        # Auto-detect branch, semester, subject from path
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

        # Store document in DB
        processor.store_document(
            name=os.path.basename(pdf_path),
            path=pdf_path,
            category=category,
            content=text,
            branch=branch,
            semester=semester,
            subject=subject
        )

    # -------------------------
    # Initialize RAG pipeline
    # -------------------------
    print("\nBuilding RAG pipeline...")
    pipeline = RAGPipeline()
    pipeline.run()

    print("\nAll PDFs processed successfully.")


if __name__ == "__main__":
    main()