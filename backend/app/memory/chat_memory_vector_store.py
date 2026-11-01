import os
import faiss
import numpy as np
from app.rag.model_loader import get_shared_sentence_transformer

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_VECTOR_DIR = os.path.join(BASE_DIR, "vector_db", "faiss_index")
VECTOR_DIR = os.path.realpath(
    os.path.expanduser(
        os.environ.get("UNIGUIDE_MEMORY_INDEX_DIR", DEFAULT_VECTOR_DIR)
    )
)
MEMORY_INDEX_FILE = os.path.join(VECTOR_DIR, "chat_memory_index.faiss")

EMBEDDING_MODEL_NAME = "BAAI/bge-small-en-v1.5"
EMBEDDING_DIM = 384


class ChatMemoryVectorStore:
    def __init__(self, device="cpu"):
        os.makedirs(VECTOR_DIR, exist_ok=True)
        self.device = device
        self.index = self._load_or_create_index()

    @property
    def model(self):
        return get_shared_sentence_transformer(EMBEDDING_MODEL_NAME, device=self.device)

    def _load_or_create_index(self):
        if os.path.exists(MEMORY_INDEX_FILE):
            try:
                index = faiss.read_index(MEMORY_INDEX_FILE)
                if index.d == EMBEDDING_DIM:
                    return index
            except Exception as e:
                print(f"[WARN] Could not load chat memory index, recreating: {e}")

        return faiss.IndexFlatL2(EMBEDDING_DIM)

    def save(self):
        faiss.write_index(self.index, MEMORY_INDEX_FILE)

    def embed_text(self, text):
        if not text or not str(text).strip():
            return np.zeros((1, EMBEDDING_DIM), dtype=np.float32)

        embedding = self.model.encode(
            [str(text).strip()],
            convert_to_numpy=True,
            normalize_embeddings=True
        )
        return embedding.astype(np.float32)

    def add_memory(self, memory_text):
        if not memory_text or not str(memory_text).strip():
            return None

        vector_id = self.index.ntotal
        embedding = self.embed_text(memory_text)
        self.index.add(embedding)
        self.save()
        return vector_id

    def search(self, query, top_k=5):
        if not query or not str(query).strip():
            return []

        if self.index.ntotal == 0:
            return []

        embedding = self.embed_text(query)
        distances, indices = self.index.search(embedding, min(top_k, self.index.ntotal))

        results = []
        for distance, vector_id in zip(distances[0], indices[0]):
            if vector_id == -1:
                continue

            # Convert normalized L2 distance to cosine similarity
            cos_sim = max(0.0, min(1.0, 1.0 - (float(distance) / 2.0)))
            results.append({
                "vector_id": int(vector_id),
                "distance": float(distance),
                "similarity": round(cos_sim, 4),
            })

        return results

    def count(self):
        return self.index.ntotal
