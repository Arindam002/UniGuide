import os
import re
import fitz  # PyMuPDF
import hashlib
import sqlite3
import pytesseract
import gc
from pdf2image import convert_from_path
from dotenv import load_dotenv
from database.db import get_connection
from app.rag.query_router import classify_document_domain

# -----------------------------
# CONFIG
# -----------------------------
BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../"))
load_dotenv(os.path.join(BASE_DIR, ".env"))
DATA_DIR = os.path.join(BASE_DIR, "data")
DIAGRAMS_DIR = os.path.join(BASE_DIR, "extracted_diagrams")

POPPLER_PATH = os.getenv("POPPLER_PATH") or None
TESSERACT_PATH = os.getenv("TESSERACT_PATH")
if TESSERACT_PATH:
    pytesseract.pytesseract.tesseract_cmd = TESSERACT_PATH


class PDFProcessor:
    def __init__(self):
        self.conn = get_connection()
        self.cursor = self.conn.cursor()
        os.makedirs(DIAGRAMS_DIR, exist_ok=True)

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        try:
            self.conn.close()
        except Exception:
            pass

    def get_file_hash(self, file_path):
        hasher = hashlib.md5()
        with open(file_path, "rb") as f:
            while chunk := f.read(8192):
                hasher.update(chunk)
        return hasher.hexdigest()

    def already_processed(self, file_path):
        if not os.path.isfile(file_path):
            return False

        file_hash = self.get_file_hash(file_path)
        self.cursor.execute(
            "SELECT 1 FROM documents WHERE file_hash = ? LIMIT 1",
            (file_hash,)
        )
        return self.cursor.fetchone() is not None

    # ---------------------------------
    # Metadata extraction from path
    # ---------------------------------
    def extract_metadata(self, file_path):
        norm_path = os.path.normpath(file_path)
        parts = norm_path.split(os.sep)

        branch = None
        semester = None
        subject = None
        category = "unknown"

        try:
            lower_parts = [p.lower() for p in parts]

            if "data" in lower_parts:
                data_idx = lower_parts.index("data")

                if len(parts) > data_idx + 1:
                    category = lower_parts[data_idx + 1]

                # data/books/{branch}/{semester}/{subject}/file.pdf
                # data/notes/{branch}/{semester}/{subject}/file.pdf
                if category in ["books", "notes"]:
                    if len(parts) > data_idx + 2:
                        branch = parts[data_idx + 2].upper()

                    if len(parts) > data_idx + 3:
                        semester = parts[data_idx + 3]

                    if len(parts) > data_idx + 4:
                        subject = parts[data_idx + 4]
                    else:
                        subject = os.path.splitext(os.path.basename(file_path))[0]

                # data/pyqs/branch/{branch}/file.pdf
                elif category == "pyqs":
                    if "branch" in lower_parts:
                        b_idx = lower_parts.index("branch")
                        if len(parts) > b_idx + 1:
                            branch = parts[b_idx + 1].upper()

                    filename = os.path.basename(file_path)
                    filename_no_ext = os.path.splitext(filename)[0]

                    match = re.search(r'(\d+)[-_ ]?sem|sem[-_ ]?(\d+)', filename.lower())
                    if match:
                        semester = match.group(1) or match.group(2)

                    subject = filename_no_ext

        except Exception as e:
            print(f"[ERROR] Metadata extraction failed for {file_path}: {e}")

        return branch, semester, subject, category

    def traverse_data_folder(self):
        pdf_files = []

        if not os.path.isdir(DATA_DIR):
            print(f"[ERROR] DATA_DIR does not exist: {DATA_DIR}")
            return pdf_files

        for root, _, files in os.walk(DATA_DIR):
            for file in files:
                if file.lower().endswith(".pdf"):
                    full_path = os.path.join(root, file)
                    branch, semester, subject, category = self.extract_metadata(full_path)

                    pdf_files.append({
                        "pdf_path": full_path,
                        "category": category,
                        "branch": branch,
                        "semester": semester,
                        "subject": subject
                    })

        return pdf_files

    def clean_text(self, text):
        if not text:
            return ""

        # Normalize unicode (NFKC handles ligatures, symbols)
        import unicodedata
        text = unicodedata.normalize("NFKC", text)

        # Strip unprintable control characters while preserving math/scientific unicode
        text = re.sub(r"[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]", "", text)
        text = re.sub(r"[ \t]+", " ", text)
        text = re.sub(r"\n{3,}", "\n\n", text)
        return text.strip()

    def sanitize_filename(self, value):
        if not value:
            return "unknown"
        value = re.sub(r'[<>:"/\\|?*]+', "_", value)
        value = re.sub(r"\s+", "_", value.strip())
        return value

    # ---------------------------------
    # Extract full text
    # ---------------------------------
    def extract_text(self, pdf_path):
        page_texts = []
        total_pages = 0
        used_ocr = False

        try:
            doc = fitz.open(pdf_path)
            total_pages = len(doc)

            for page in doc:
                page_texts.append(self.clean_text(page.get_text() or ""))

            doc.close()

        except Exception as e:
            print(f"[ERROR] fitz failed for {pdf_path}: {e}")

        page_word_counts = [len(text.split()) for text in page_texts]
        if sum(page_word_counts) < 100:
            low_text_pages = [
                page_number
                for page_number, word_count in enumerate(page_word_counts, start=1)
                if word_count < 20
            ]
        else:
            low_text_pages = [
                page_number
                for page_number, word_count in enumerate(page_word_counts, start=1)
                if word_count == 0
            ]

        if low_text_pages or not page_texts:
            print(f"[INFO] Using OCR fallback for: {pdf_path}")
            ocr_pages, ocr_total_pages = self.ocr_pdf(
                pdf_path,
                page_numbers=low_text_pages or None,
            )
            total_pages = total_pages or ocr_total_pages

            for page_number, ocr_text in ocr_pages.items():
                page_index = page_number - 1
                if page_index >= len(page_texts):
                    page_texts.extend([""] * (page_index + 1 - len(page_texts)))
                if len(ocr_text.split()) > len(page_texts[page_index].split()):
                    page_texts[page_index] = ocr_text
                    used_ocr = True

        return self.clean_text("\n".join(page_texts)), total_pages, used_ocr

    def ocr_pdf(self, pdf_path, page_numbers=None):
        """
        OCR selected pages one at a time to limit image memory usage.
        When no page list is provided, process every page.
        """
        total_pages = 0

        try:
            doc = fitz.open(pdf_path)
            total_pages = len(doc)
            doc.close()

            print(f"[INFO] OCR started for {pdf_path} | Total pages: {total_pages}")

            pages_to_process = page_numbers or range(1, total_pages + 1)
            page_texts = {}

            for page_number in pages_to_process:
                images = []
                img = None
                try:
                    images = convert_from_path(
                        pdf_path,
                        poppler_path=POPPLER_PATH,
                        first_page=page_number,
                        last_page=page_number,
                        dpi=150,
                        fmt="jpeg",
                        thread_count=1
                    )

                    if not images:
                        print(f"[WARN] No image generated for page {page_number} in {pdf_path}")
                        continue

                    img = images[0].convert("L")

                    page_text = pytesseract.image_to_string(
                        img,
                        config="--oem 3 --psm 6"
                    )

                    if page_text and page_text.strip():
                        page_texts[page_number] = self.clean_text(page_text)

                    if page_number % 10 == 0 or page_number == total_pages:
                        print(f"[INFO] OCR progress: {page_number}/{total_pages} pages completed for {pdf_path}")

                except Exception as e:
                    print(f"[WARN] OCR failed on page {page_number} of {pdf_path}: {e}")
                finally:
                    if img is not None:
                        img.close()
                    for image in images:
                        image.close()
                    gc.collect()

            return page_texts, total_pages

        except Exception as e:
            print(f"[ERROR] OCR failed for {pdf_path}: {e}")
            return {}, 0

    # ---------------------------------
    # Store document metadata
    # ---------------------------------
    def store_document(
        self,
        path,
        category,
        branch=None,
        semester=None,
        subject=None,
        total_pages=None,
        content="",
        domain=None,
    ):
        try:
            name = os.path.basename(path)
            file_hash = self.get_file_hash(path)
            domain = domain or classify_document_domain(
                title=name,
                subject=subject,
                text=content,
            )

            # books + pyqs in RAG, notes excluded from RAG
            if category in ["books", "pyqs"]:
                rag_flag = 1
            elif category == "notes":
                rag_flag = 0
            else:
                rag_flag = 0

            self.cursor.execute(
                """
                INSERT INTO documents
                (name, file_path, file_hash, category, domain, branch, semester, subject, total_pages, content, use_for_rag)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    name, path, file_hash, category, domain, branch, semester,
                    subject, total_pages, content, rag_flag,
                )
            )
            self.conn.commit()
            return self.cursor.lastrowid

        except sqlite3.IntegrityError:
            self.cursor.execute(
                "SELECT id FROM documents WHERE file_hash = ?",
                (self.get_file_hash(path),)
            )
            result = self.cursor.fetchone()
            return result[0] if result else None

        except Exception as e:
            print(f"[ERROR] Store failed for {path}: {e}")
            return None

    # ---------------------------------
    # Diagram extraction helpers
    # ---------------------------------
    def get_diagram_output_dir(self, category, branch, semester, subject, pdf_path):
        pdf_name = os.path.splitext(os.path.basename(pdf_path))[0]

        parts = [
            DIAGRAMS_DIR,
            self.sanitize_filename(category),
            self.sanitize_filename(branch),
            self.sanitize_filename(semester),
            self.sanitize_filename(subject),
            self.sanitize_filename(pdf_name)
        ]

        out_dir = os.path.join(*parts)
        os.makedirs(out_dir, exist_ok=True)
        return out_dir

    def extract_page_context(self, page):
        try:
            text = page.get_text("text")
            return self.clean_text(text[:2000])
        except Exception:
            return ""

    def guess_diagram_caption(self, page_text):
        if not page_text:
            return None

        lines = [line.strip() for line in page_text.splitlines() if line.strip()]
        caption_patterns = [
            r'^(figure|fig\.?)\s*\d+[\.: -].*',
            r'^(diagram)\s*\d*[\.: -].*',
            r'^(block diagram)[\s:.-].*',
            r'^(flowchart)[\s:.-].*',
            r'^(architecture)[\s:.-].*',
            r'^(circuit diagram)[\s:.-].*',
            r'^(schematic)[\s:.-].*',
        ]

        for line in lines:
            low = line.lower()
            for pattern in caption_patterns:
                if re.match(pattern, low):
                    return line[:300]

        for line in lines:
            low = line.lower()
            if any(keyword in low for keyword in [
                "figure", "diagram", "block diagram", "flowchart",
                "architecture", "schematic", "circuit"
            ]):
                return line[:300]

        return None

    def store_diagram(
        self,
        document_id,
        page_number,
        image_path,
        caption=None,
        context_text=None,
        vector_id=None
    ):
        try:
            self.cursor.execute(
                """
                INSERT INTO diagrams
                (document_id, page_number, image_path, caption, context_text, vector_id)
                VALUES (?, ?, ?, ?, ?, ?)
                """,
                (document_id, page_number, image_path, caption, context_text, vector_id)
            )
            self.conn.commit()
            return self.cursor.lastrowid

        except sqlite3.IntegrityError as e:
            print(f"[WARN] Diagram already exists or unique constraint hit: {image_path} | {e}")
            return None

        except Exception as e:
            print(f"[ERROR] Failed to store diagram {image_path}: {e}")
            return None

    def is_full_page_image(self, page, xref, threshold=0.70):
        try:
            page_rect = page.rect
            page_area = page_rect.width * page_rect.height

            if page_area <= 0:
                return False

            rects = page.get_image_rects(xref)
            if not rects:
                return False

            img_rect = rects[0]
            img_area = img_rect.width * img_rect.height
            coverage = img_area / page_area

            return coverage >= threshold

        except Exception:
            return False

    def is_likely_diagram(self, page, xref, min_width=120, min_height=120):
        """
        Keep useful embedded images, skip tiny icons and full-page scans.
        """
        pix = None

        try:
            pix = fitz.Pixmap(page.parent, xref)
            width = pix.width
            height = pix.height

            if width < min_width or height < min_height:
                return False

            if self.is_full_page_image(page, xref, threshold=0.70):
                return False

            return True

        except Exception:
            return False

        finally:
            pix = None

    def should_extract_diagrams(self, category, used_ocr):
        """
        Extract diagrams only for BOOKS.
        Skip notes and pyqs.
        Skip OCR/scanned PDFs to avoid saving full scanned pages as diagrams.
        """
        if category != "books":
            return False

        if used_ocr:
            return False

        return True

    def extract_and_store_diagrams(
        self,
        pdf_path,
        document_id,
        category,
        branch=None,
        semester=None,
        subject=None
    ):
        saved_count = 0
        doc = None

        try:
            doc = fitz.open(pdf_path)

            output_dir = self.get_diagram_output_dir(
                category=category,
                branch=branch,
                semester=semester,
                subject=subject,
                pdf_path=pdf_path
            )

            pdf_name = os.path.splitext(os.path.basename(pdf_path))[0]

            for page_index in range(len(doc)):
                page = doc.load_page(page_index)
                page_number = page_index + 1
                image_list = page.get_images(full=True)

                if not image_list:
                    if page_number % 5 == 0:
                        gc.collect()
                    continue

                page_text_raw = page.get_text("text")
                context_text = self.extract_page_context(page)
                caption = self.guess_diagram_caption(page_text_raw)

                for img_index, img in enumerate(image_list, start=1):
                    xref = img[0]
                    pix = None

                    try:
                        if not self.is_likely_diagram(page, xref):
                            continue

                        # NEW SAFE EXTRACTION CODE HERE

                        pix = fitz.Pixmap(doc, xref)

                        if pix.colorspace is None or pix.colorspace.n not in (1, 3):
                            pix = fitz.Pixmap(fitz.csRGB, pix)

                        if pix.alpha:
                            pix = fitz.Pixmap(pix, 0)

                        image_ext = "png"

                        filename = (
                            f"{self.sanitize_filename(pdf_name)}"
                            f"_page_{page_number}_img_{img_index}.{image_ext}"
                        )

                        image_path = os.path.join(output_dir, filename)

                        pix.save(image_path)

                        pix = None

                        diagram_id = self.store_diagram(
                            document_id=document_id,
                            page_number=page_number,
                            image_path=image_path,
                            caption=caption,
                            context_text=context_text,
                            vector_id=None
                        )

                        if diagram_id:
                            saved_count += 1

                    except Exception as e:
                        print(
                            f"[WARN] Failed to extract image from {pdf_path}, "
                            f"page {page_number}, image {img_index}: {e}"
                        )

                    finally:
                        pix = None

                # Memory cleanup every 5 pages
                if page_number % 5 == 0:
                    gc.collect()

            gc.collect()

        except Exception as e:
            print(f"[ERROR] Diagram extraction failed for {pdf_path}: {e}")

        finally:
            if doc:
                doc.close()
            gc.collect()

        return saved_count

    # ---------------------------------
    # Main runner
    # ---------------------------------
    def run(self):
        all_pdfs = self.traverse_data_folder()

        for item in all_pdfs:
            pdf_path = item["pdf_path"]
            category = item["category"]
            branch = item["branch"]
            semester = item["semester"]
            subject = item["subject"]

            if self.already_processed(pdf_path):
                print(f"[SKIP] Already processed file: {pdf_path}")
                continue

            print(f"[INFO] Processing: {pdf_path}")

            text, pages, used_ocr = self.extract_text(pdf_path)

            if not text or len(text.strip()) < 10:
                print(f"[WARN] No usable text extracted from: {pdf_path}")
                continue

            document_id = self.store_document(
                path=pdf_path,
                category=category,
                branch=branch,
                semester=semester,
                subject=subject,
                total_pages=pages,
                content=text,
            )

            if not document_id:
                print(f"[ERROR] Failed to store document: {pdf_path}")
                continue

            diagram_count = 0

            if self.should_extract_diagrams(category, used_ocr):
                diagram_count = self.extract_and_store_diagrams(
                    pdf_path=pdf_path,
                    document_id=document_id,
                    category=category,
                    branch=branch,
                    semester=semester,
                    subject=subject
                )
            else:
                if used_ocr:
                    print(f"[INFO] Skipping diagram extraction for scanned/OCR PDF: {pdf_path}")
                else:
                    print(f"[INFO] Skipping diagram extraction for category: {category}")

            print(
                f"[SUCCESS] Stored document: {os.path.basename(pdf_path)} | "
                f"Category: {category} | Pages: {pages} | Diagrams stored: {diagram_count}"
            )

        print("[DONE] PDF processing completed.")


if __name__ == "__main__":
    with PDFProcessor() as proc:
        proc.run()