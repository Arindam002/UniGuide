import os
from pathlib import Path
from database.db import get_connection
from app.rag.vector_store import (
    LEGACY_MIGRATION_MARKER,
    LEGACY_INDEX_FILES,
    NAMESPACE_INDEX_DIR,
)


def delete_file_if_exists(file_path, label):
    try:
        if os.path.exists(file_path):
            os.remove(file_path)
            print(f"[INFO] Deleted {label} FAISS index: {file_path}")
        else:
            print(f"[INFO] No {label} FAISS index file found at: {file_path}")
    except Exception as e:
        print(f"[ERROR] Failed to delete {label} FAISS index: {e}")


def reset_db():
    conn = get_connection()
    cursor = conn.cursor()

    try:
        # First delete chunks linked to books and pyqs documents
        cursor.execute("""
            DELETE FROM chunks
            WHERE document_id IN (
                SELECT id FROM documents
                WHERE category IN ('books', 'pyqs')
            )
        """)

        # Then delete books and pyqs documents
        cursor.execute("""
            DELETE FROM documents
            WHERE category IN ('books', 'pyqs')
        """)

        conn.commit()
        print("[INFO] Cleared books and pyqs data from documents and chunks tables.")

    except Exception as e:
        conn.rollback()
        print(f"[ERROR] Failed to clear DB: {e}")

    finally:
        conn.close()


if __name__ == "__main__":
    print("[INFO] Reset started...")

    for store_type, path in LEGACY_INDEX_FILES.items():
        delete_file_if_exists(path, store_type)

    for index_path in Path(NAMESPACE_INDEX_DIR).glob("*/*.faiss"):
        delete_file_if_exists(str(index_path), "namespaced")
    delete_file_if_exists(LEGACY_MIGRATION_MARKER, "migration marker")
    # Reset DB data
    reset_db()

    print("[INFO] Reset completed.")