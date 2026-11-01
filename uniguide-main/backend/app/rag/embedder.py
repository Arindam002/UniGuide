from sentence_transformers import SentenceTransformer
import numpy as np


class Embedder:
    def __init__(self, model_name="sentence-transformers/all-MiniLM-L6-v2"):
        self.model = SentenceTransformer(model_name)

    def embed(self, texts, show_progress_bar=False, normalize=True):
        if isinstance(texts, str):
            texts = [texts]

        if not texts:
            return np.array([], dtype=np.float32).reshape(0, 384)

        texts = [str(t).strip() for t in texts if str(t).strip()]

        if not texts:
            return np.array([], dtype=np.float32).reshape(0, 384)

        embeddings = self.model.encode(
            texts,
            convert_to_numpy=True,
            show_progress_bar=show_progress_bar,
            normalize_embeddings=normalize
        )

        return embeddings.astype(np.float32)