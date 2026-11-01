import sqlite3
import numpy as np

from app.rag.embedder import Embedder
from app.rag.vector_store import VectorStore
from database.db import get_connection


def fetch_chunks_by_vector_ids(vector_ids):
    conn = get_connection()
    cursor = conn.cursor()

    results = []
    try:
        for vector_id in vector_ids:
            cursor.execute(
                """
                SELECT c.chunk_text, c.vector_id, d.name, d.category, d.subject, d.branch, d.semester
                FROM chunks c
                JOIN documents d ON c.document_id = d.id
                WHERE c.vector_id = ?
                """,
                (str(vector_id),)
            )
            row = cursor.fetchone()
            if row:
                results.append({
                    "chunk_text": row[0],
                    "vector_id": row[1],
                    "file_name": row[2],
                    "category": row[3],
                    "subject": row[4],
                    "branch": row[5],
                    "semester": row[6],
                })
    finally:
        conn.close()

    return results


def main():
    query = input("Enter your question: ").strip()
    if not query:
        print("[ERROR] Empty query.")
        return

    print("\n[INFO] Loading embedder...")
    embedder = Embedder()

    print("[INFO] Loading vector store...")
    vector_store = VectorStore()

    total_vectors = vector_store.get_total_vectors()
    print(f"[INFO] Total vectors in FAISS: {total_vectors}")

    if total_vectors == 0:
        print("[ERROR] FAISS index is empty.")
        return

    print("[INFO] Generating query embedding...")
    query_embedding = embedder.embed(query, show_progress_bar=False)

    if query_embedding is None or len(query_embedding) == 0:
        print("[ERROR] Failed to generate query embedding.")
        return

    if isinstance(query_embedding, np.ndarray) and query_embedding.ndim == 2:
        query_embedding = query_embedding[0]

    print("[INFO] Searching FAISS...")
    vector_ids = vector_store.search(query_embedding, top_k=5)

    print(f"[INFO] Retrieved vector IDs: {vector_ids}")

    if not vector_ids:
        print("[ERROR] No vectors retrieved from FAISS.")
        return

    print("[INFO] Fetching chunks from database...")
    chunks = fetch_chunks_by_vector_ids(vector_ids)

    if not chunks:
        print("[ERROR] No matching chunks found in DB for retrieved vector IDs.")
        print("[HINT] This means FAISS and SQLite chunk mapping is broken.")
        return

    print(f"\n[INFO] Retrieved {len(chunks)} chunks:\n")

    for i, item in enumerate(chunks, start=1):
        print("=" * 80)
        print(f"Rank      : {i}")
        print(f"Vector ID : {item['vector_id']}")
        print(f"File      : {item['file_name']}")
        print(f"Category  : {item['category']}")
        print(f"Subject   : {item['subject']}")
        print(f"Branch    : {item['branch']}")
        print(f"Semester  : {item['semester']}")
        print("-" * 80)
        print(item["chunk_text"][:1000])
        print()

if __name__ == "__main__":
    main()