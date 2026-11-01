import os

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

DATA_DIR = os.path.join(BASE_DIR, "data")
VECTOR_DB_DIR = os.path.join(BASE_DIR, "app", "vector_db", "faiss_index")

BOOKS_DIR = os.path.join(DATA_DIR, "books")
NOTES_DIR = os.path.join(DATA_DIR, "notes")
PYQ_DIR = os.path.join(DATA_DIR, "pyqs")

DEBUG = os.getenv("FLASK_DEBUG", "false").strip().lower() in {"1", "true", "yes"}
HOST = os.getenv("HOST", "0.0.0.0")
PORT = int(os.getenv("PORT", "5000"))