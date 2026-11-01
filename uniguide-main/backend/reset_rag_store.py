import os
from database.db import get_connection
from app.rag.vector_store import INDEX_FILE

# Delete FAISS file
if os.path.exists(INDEX_FILE):
    os.remove(INDEX_FILE)
    print(f"[INFO] Deleted FAISS index: {INDEX_FILE}")
else:
    print("[INFO] No FAISS index file found.")

# Clear DB tables
conn = get_connection()
cursor = conn.cursor()

try:
    cursor.execute("DELETE FROM chunks")
    cursor.execute("DELETE FROM documents")
    conn.commit()
    print("[INFO] Cleared documents and chunks tables.")
except Exception as e:
    conn.rollback()
    print(f"[ERROR] Failed to clear DB: {e}")
finally:
    conn.close()