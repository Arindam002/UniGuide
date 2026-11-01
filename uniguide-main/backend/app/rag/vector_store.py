import faiss
import numpy as np
import os


# -------------------------------
# PATH CONFIGURATION
# -------------------------------
CURRENT_DIR = os.path.dirname(os.path.abspath(__file__))          # backend/app/rag
APP_DIR = os.path.dirname(CURRENT_DIR)                           # backend/app
VECTOR_DB_PATH = os.path.join(APP_DIR, "vector_db", "faiss_index")
INDEX_FILE = os.path.join(VECTOR_DB_PATH, "index.faiss")

os.makedirs(VECTOR_DB_PATH, exist_ok=True)


class VectorStore:
    def __init__(self, dimension=384):
        """
        dimension = embedding size
        all-MiniLM-L6-v2 = 384
        """
        self.dimension = dimension
        self.index = None
        self.load()

    # -------------------------------
    # LOAD EXISTING INDEX
    # -------------------------------
    def load(self):
        if os.path.exists(INDEX_FILE):
            print(f"[INFO] Loading existing FAISS index from: {INDEX_FILE}")
            self.index = faiss.read_index(INDEX_FILE)

            # Optional validation
            if self.index.d != self.dimension:
                raise ValueError(
                    f"FAISS dimension mismatch: index dimension = {self.index.d}, "
                    f"expected = {self.dimension}"
                )
        else:
            print("[INFO] No existing FAISS index found. Creating new index...")
            self.index = faiss.IndexFlatL2(self.dimension)

    # -------------------------------
    # ADD EMBEDDINGS
    # -------------------------------
    def add_embeddings(self, embeddings):
        if embeddings is None or len(embeddings) == 0:
            raise ValueError("No embeddings provided to add.")

        embeddings = np.array(embeddings, dtype=np.float32)

        if len(embeddings.shape) != 2:
            raise ValueError(
                f"Embeddings must be 2D, got shape: {embeddings.shape}"
            )

        if embeddings.shape[1] != self.dimension:
            raise ValueError(
                f"Embedding dimension mismatch: got {embeddings.shape[1]}, expected {self.dimension}"
            )

        start_id = self.index.ntotal
        self.index.add(embeddings)
        end_id = self.index.ntotal

        added_count = end_id - start_id
        if added_count != len(embeddings):
            raise ValueError(
                f"FAISS add mismatch: tried to add {len(embeddings)} embeddings, "
                f"but index increased by {added_count}"
            )

        vector_ids = list(range(start_id, end_id))
        return vector_ids

    # -------------------------------
    # SEARCH SIMILAR VECTORS
    # -------------------------------
    def search(self, query_embedding, top_k=5):
        if self.index is None or self.index.ntotal == 0:
            return []

        query_embedding = np.array(query_embedding, dtype=np.float32)

        if query_embedding.ndim == 1:
            query_embedding = query_embedding.reshape(1, -1)
        elif query_embedding.ndim != 2:
            raise ValueError(
                f"Query embedding must be 1D or 2D, got shape: {query_embedding.shape}"
            )

        if query_embedding.shape[1] != self.dimension:
            raise ValueError(
                f"Query embedding dimension mismatch: got {query_embedding.shape[1]}, expected {self.dimension}"
            )

        distances, indices = self.index.search(query_embedding, top_k)

        valid_indices = [idx for idx in indices[0].tolist() if idx != -1]
        return valid_indices

    # -------------------------------
    # TOTAL VECTORS
    # -------------------------------
    def get_total_vectors(self):
        if self.index is None:
            return 0
        return self.index.ntotal

    # -------------------------------
    # SAVE INDEX
    # -------------------------------
    def save(self):
        if self.index is not None:
            faiss.write_index(self.index, INDEX_FILE)
            print(f"[INFO] FAISS index saved at: {INDEX_FILE}")
        else:
            print("[WARNING] No index to save.")