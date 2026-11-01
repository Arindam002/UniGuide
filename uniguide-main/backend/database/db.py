import sqlite3
import os

# -----------------------------
# Base paths
# -----------------------------
BASE_DIR = os.path.dirname(os.path.abspath(__file__))   # backend/database
DB_PATH = os.path.join(BASE_DIR, "uniguide.db")
SCHEMA_PATH = os.path.join(BASE_DIR, "schema.sql")

os.makedirs(BASE_DIR, exist_ok=True)


def get_connection():
    try:
        conn = sqlite3.connect(DB_PATH, check_same_thread=False)
        conn.execute("PRAGMA foreign_keys = ON;")
        conn.row_factory = sqlite3.Row
        return conn
    except sqlite3.Error as e:
        print(f"❌ Database connection error: {e}")
        raise


def init_db():
    conn = None
    try:
        if not os.path.exists(SCHEMA_PATH):
            raise FileNotFoundError(f"Schema file not found: {SCHEMA_PATH}")

        conn = get_connection()

        with open(SCHEMA_PATH, "r", encoding="utf-8") as f:
            schema_sql = f.read()

        conn.executescript(schema_sql)
        conn.commit()

        print(f"✅ Database initialized successfully at: {DB_PATH}")

    except Exception as e:
        if conn:
            conn.rollback()
        print(f"❌ Database initialization failed: {e}")
        raise

    finally:
        if conn:
            conn.close()