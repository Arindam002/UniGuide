import os

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

DATA_DIR = os.path.join(BASE_DIR, "data")
VECTOR_DB_DIR = os.path.join(BASE_DIR, "vector_db")

BOOKS_DIR = os.path.join(DATA_DIR, "books")
NOTES_DIR = os.path.join(DATA_DIR, "notes")
PYQ_DIR = os.path.join(DATA_DIR, "pyqs")

DEBUG = True
HOST = "127.0.0.1"
PORT = 5000