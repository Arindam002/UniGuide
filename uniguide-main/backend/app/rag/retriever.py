import os
import sys
import faiss
import numpy as np
from sentence_transformers import SentenceTransformer

# 1. Get the directory of the current file: D:\Uniguide\backend\app\rag\
CURRENT_DIR = os.path.dirname(os.path.abspath(__file__))

# 2. Go up ONE level to reach: D:\Uniguide\backend\app\
BASE_DIR = os.path.abspath(os.path.join(CURRENT_DIR, "../"))

# 3. Define the exact path to the index file
VECTOR_DB_PATH = os.path.join(BASE_DIR, "vector_db", "faiss_index", "index")

# --- DEBUG PRINTS ---
print(f"📍 Current File: {__file__}")
print(f"📂 App Root: {BASE_DIR}")
print(f"🔍 Searching for FAISS at: {VECTOR_DB_PATH}")
# --------------------

# Ensure backend root is accessible for imports
BACKEND_DIR = os.path.abspath(os.path.join(CURRENT_DIR, "../../"))
if BACKEND_DIR not in sys.path:
    sys.path.append(BACKEND_DIR)

from database.db import get_connection


class Retriever:
    def __init__(self):
        self.model = SentenceTransformer(
            "all-MiniLM-L6-v2",
            device="cpu",
            local_files_only=True
        )

        if not os.path.exists(VECTOR_DB_PATH):
            alt_path = VECTOR_DB_PATH + ".faiss"
            if os.path.exists(alt_path):
                self.index = faiss.read_index(alt_path)
                print(f"✅ FAISS index loaded from {alt_path}")
            else:
                print(f"❌ CRITICAL ERROR: FAISS index NOT found at {VECTOR_DB_PATH}")
                self.index = None
        else:
            self.index = faiss.read_index(VECTOR_DB_PATH)
            print("✅ FAISS index loaded successfully.")

        self.conn = get_connection()
        self.cursor = self.conn.cursor()

    def retrieve(self, query, branch=None, semester=None, subject=None, category=None, top_k=5):
        """
        Retrieve chunks from FAISS and filter by SQLite metadata.
        Renamed to 'retrieve' to match RagService usage.
        """
        if self.index is None:
            return []

        # 1. Embed query
        query_embedding = self.model.encode([query])
        query_embedding = np.array(query_embedding).astype("float32")

        # 2. Normalize for cosine similarity
        faiss.normalize_L2(query_embedding)

        # 3. Search FAISS
        distances, indices = self.index.search(query_embedding, top_k * 20)

        results = []

        for i, vector_id in enumerate(indices[0]):
            vector_id = str(vector_id)

            if int(vector_id) < 0:
                continue

            # 4. Fetch chunk + metadata from SQLite
            self.cursor.execute(
                """
                SELECT 
                    c.chunk_text,
                    d.name,
                    d.category,
                    d.subject,
                    d.branch,
                    d.semester
                FROM chunks c
                JOIN documents d ON c.document_id = d.id
                WHERE c.vector_id = ?
                """,
                (vector_id,)
            )

            row = self.cursor.fetchone()

            if not row:
                continue

            # 5. Apply Metadata Filters
            if branch and row["branch"] and row["branch"].upper() != branch.upper():
                continue

            if semester and str(row["semester"]) != str(semester):
                continue

            if subject and subject.lower() != "general":
                if row["subject"] and row["subject"].lower() != subject.lower():
                    continue

            if category and row["category"] != category:
                continue

            results.append({
                "chunk_text": row["chunk_text"],
                "file_name": row["name"],
                "category": row["category"],
                "subject": row["subject"],
                "branch": row["branch"],
                "semester": row["semester"],
                "score": float(distances[0][i])
            })

            if len(results) >= top_k:
                break

        return results