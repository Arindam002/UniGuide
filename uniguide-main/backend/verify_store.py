from database.db import get_connection
from app.rag.vector_store import VectorStore

conn = get_connection()
cursor = conn.cursor()
cursor.execute("SELECT COUNT(*) FROM chunks")
db_count = cursor.fetchone()[0]
conn.close()

vs = VectorStore()
faiss_count = vs.get_total_vectors()

print("DB chunks  :", db_count)
print("FAISS vecs :", faiss_count)

if db_count == faiss_count:
    print("[OK] Mapping is correct")
else:
    print("[ERROR] Mismatch")