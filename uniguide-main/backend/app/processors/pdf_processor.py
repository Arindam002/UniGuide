import os
import re
import fitz  # PyMuPDF
import hashlib
import sqlite3
import pytesseract
from pdf2image import convert_from_path
from database.db import get_connection

# -----------------------------
# CONFIG
# -----------------------------
BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../"))
DATA_DIR = os.path.join(BASE_DIR, "data")

POPPLER_PATH = os.getenv(
    "POPPLER_PATH",
    r"C:\Users\arind\Downloads\Release-25.12.0-0\poppler-25.12.0\Library\bin"
)

pytesseract.pytesseract.tesseract_cmd = os.getenv(
    "TESSERACT_PATH",
    r"C:\Program Files\Tesseract-OCR\tesseract.exe"
)

class PDFProcessor:
    def __init__(self):
        # Using the centralized connection from db.py
        self.conn = get_connection()
        self.cursor = self.conn.cursor()

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self.conn.close()

    def get_file_hash(self, file_path):
        hasher = hashlib.md5()
        with open(file_path, "rb") as f:
            while chunk := f.read(8192):
                hasher.update(chunk)
        return hasher.hexdigest()

    def already_processed(self, file_path):
        file_hash = self.get_file_hash(file_path)
        self.cursor.execute(
            "SELECT 1 FROM documents WHERE file_hash = ? LIMIT 1",
            (file_hash,)
        )
        return self.cursor.fetchone() is not None

    # ---------------------------------
    # IMPROVED: Metadata extraction based on your actual folder tree
    # ---------------------------------
    def extract_metadata(self, file_path):
        # Use normalized paths to avoid issues with mixed slashes
        norm_path = os.path.normpath(file_path).lower()
        parts = norm_path.split(os.sep)
        
        branch, semester, subject, category = None, None, None, "unknown"

        try:
            if "data" in parts:
                data_idx = parts.index("data")
                category = parts[data_idx + 1]

                # Pattern: data/books/{branch}/{semester}/{subject}/file.pdf
                if category in ["books", "notes"]:
                    branch = parts[data_idx + 2].upper()
                    semester = parts[data_idx + 3]
                    # Check if there is a subject folder before the filename
                    if len(parts) > data_idx + 5:
                        subject = parts[data_idx + 4]
                    else:
                        subject = os.path.basename(file_path).replace(".pdf", "")

                # Pattern: data/pyqs/branch/{branch}/file.pdf
                elif category == "pyqs":
                    # Your structure shows data/pyqs/branch/cse/...
                    if "branch" in parts:
                        b_idx = parts.index("branch")
                        branch = parts[b_idx + 1].upper()
                    
                    filename = os.path.basename(file_path)
                    # Extract semester from filename like '6-sem' or 'sem-6'
                    match = re.search(r'(\d+)[-_]?sem', filename)
                    semester = match.group(1) if match else "unknown"
                    subject = filename.replace(".pdf", "")
        except Exception as e:
            print(f"[ERROR] Metadata extraction failed: {e}")
        
        return branch, semester, subject, category

    def traverse_data_folder(self):
        pdf_files = []
        for root, _, files in os.walk(DATA_DIR):
            for file in files:
                if file.lower().endswith(".pdf"):
                    pdf_files.append(os.path.join(root, file))
        return pdf_files

    def clean_text(self, text):
        if not text:
            return ""

        text = re.sub(r'\s+', ' ', text)
        text = re.sub(r'[^\x00-\x7F]+', ' ', text)  # remove weird unicode
        return text.strip()

    def extract_text(self, pdf_path):
        text = ""
        total_pages = 0

        try:
            doc = fitz.open(pdf_path)
            total_pages = len(doc)

            for page in doc:
                page_text = page.get_text()
                if page_text:
                    text += page_text

            doc.close()

        except Exception as e:
            print(f"[ERROR] fitz failed: {e}")

        # Better condition
        if len(text.split()) < 100:
            print("[INFO] Using OCR fallback...")
            text, total_pages = self.ocr_pdf(pdf_path)

        return self.clean_text(text), total_pages

    def ocr_pdf(self, pdf_path):
        text = ""
        try:
            images = convert_from_path(pdf_path, poppler_path=POPPLER_PATH)

            for img in images:
                text += pytesseract.image_to_string(img.convert("L"))

            return text, len(images)

        except Exception as e:
            print(f"[ERROR] OCR failed: {e}")
            return "", 0

    # ---------------------------------
    # FIXED: Returns the ID for run_processor.py
    # ---------------------------------
    def store_document(self, path, category, branch=None, semester=None, subject=None, total_pages=None, content=""):
        try:
            name = os.path.basename(path)
            file_hash = self.get_file_hash(path)
            rag_flag = 1 if category in ["books", "pyqs"] else 0

            self.cursor.execute(
                """
                INSERT INTO documents 
                (name, file_path, file_hash, category, branch, semester, subject, total_pages, content, use_for_rag)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (name, path, file_hash, category, branch, semester, subject, total_pages, content, rag_flag)
            )
            self.conn.commit()
            return self.cursor.lastrowid  # Returns the new primary key ID
        except sqlite3.IntegrityError:
            # If hash already exists, fetch the existing ID
            self.cursor.execute("SELECT id FROM documents WHERE file_hash = ?", (file_hash,))
            result = self.cursor.fetchone()
            return result[0] if result else None
        except Exception as e:
            print(f"[ERROR] Store failed: {e}")
            return None

    def run(self):
        """Standalone run logic for testing."""
        all_pdfs = self.traverse_data_folder()
        for file_path in all_pdfs:
            if not self.already_processed(file_path):
                branch, sem, sub, cat = self.extract_metadata(file_path)
                text, pages = self.extract_text(file_path)
                self.store_document(file_path, cat, branch, sem, sub, pages, text[:500])
        print("Done.")

if __name__ == "__main__":
    with PDFProcessor() as proc:
        proc.run()