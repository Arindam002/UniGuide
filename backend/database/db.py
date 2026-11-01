import sqlite3
import os
from app.rag.query_router import classify_document_domain

# -----------------------------
# Base paths
# -----------------------------
BASE_DIR = os.path.dirname(os.path.abspath(__file__))   # backend/database
DEFAULT_DB_PATH = os.path.join(BASE_DIR, "uniguide.db")
SCHEMA_PATH = os.path.join(BASE_DIR, "schema.sql")

os.makedirs(BASE_DIR, exist_ok=True)


def get_db_path():
    path = os.environ.get("UNIGUIDE_DB_PATH", DEFAULT_DB_PATH)
    return os.path.realpath(os.path.expanduser(path))


DB_PATH = get_db_path()


def get_connection():
    try:
        conn = sqlite3.connect(
            get_db_path(),
            timeout=10,
            check_same_thread=False,
        )
        conn.execute("PRAGMA foreign_keys = ON;")
        conn.execute("PRAGMA busy_timeout = 10000;")
        conn.row_factory = sqlite3.Row
        return conn
    except sqlite3.Error as e:
        print(f"Database connection error: {e}")
        raise


def init_db():
    conn = None

    try:
        if not os.path.exists(SCHEMA_PATH):
            raise FileNotFoundError(f"Schema file not found: {SCHEMA_PATH}")

        conn = get_connection()

        with open(SCHEMA_PATH, "r", encoding="utf-8") as f:
            schema_sql = f.read()

        if not schema_sql.strip():
            raise ValueError("schema.sql is empty")

        conn.executescript(schema_sql)
        document_columns = {
            row["name"]
            for row in conn.execute("PRAGMA table_info(documents)")
        }
        if "domain" not in document_columns:
            conn.execute(
                "ALTER TABLE documents "
                "ADD COLUMN domain TEXT NOT NULL DEFAULT 'computer_science'"
            )
            documents = conn.execute(
                "SELECT id, name, subject, content FROM documents"
            ).fetchall()
            conn.executemany(
                "UPDATE documents SET domain = ? WHERE id = ?",
                (
                    (
                        classify_document_domain(
                            title=row["name"],
                            subject=row["subject"],
                            text=row["content"],
                        ),
                        row["id"],
                    )
                    for row in documents
                ),
            )
        conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_documents_domain_category "
            "ON documents(domain, category)"
        )
        search_history_columns = {
            row["name"]
            for row in conn.execute("PRAGMA table_info(search_history)")
        }
        if "answer" not in search_history_columns:
            conn.execute(
                "ALTER TABLE search_history "
                "ADD COLUMN answer TEXT NOT NULL DEFAULT ''"
            )
        conn.commit()

        print("Database initialized successfully.")

    except Exception as e:
        if conn:
            conn.rollback()

        print(f"Database initialization failed: {e}")
        raise

    finally:
        if conn:
            conn.close()


def show_tables():
    conn = get_connection()
    cursor = conn.cursor()

    try:
        cursor.execute("""
            SELECT name
            FROM sqlite_master
            WHERE type = 'table'
            ORDER BY name;
        """)

        tables = cursor.fetchall()

        print("\nTables available in database:")

        if not tables:
            print("No tables found.")
        else:
            for table in tables:
                print(f" - {table['name']}")

    finally:
        conn.close()


def show_table_columns(table_name):
    conn = get_connection()
    cursor = conn.cursor()

    try:
        quoted_table_name = table_name.replace('"', '""')
        cursor.execute(f'PRAGMA table_info("{quoted_table_name}");')
        columns = cursor.fetchall()

        print(f"\nColumns in table: {table_name}")

        if not columns:
            print("Table not found or no columns.")
        else:
            for col in columns:
                print(f" - {col['name']} ({col['type']})")

    finally:
        conn.close()


if __name__ == "__main__":
    init_db()
    show_tables()

    # Memory tables check
    show_table_columns("chat_sessions")
    show_table_columns("chat_messages")
    show_table_columns("chat_memory")