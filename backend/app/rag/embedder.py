import numpy as np
from app.rag.model_loader import get_shared_sentence_transformer

# BGE models use an instruction prompt for query embeddings to optimize passage retrieval
BGE_QUERY_PREFIX = "Represent this sentence for searching relevant passages: "


class Embedder:
    def __init__(self, model_name="BAAI/bge-small-en-v1.5", device="cpu"):
        self.model_name = model_name
        self.device = device

    @property
    def model(self):
        return get_shared_sentence_transformer(self.model_name, device=self.device)

    def embed(self, texts, show_progress_bar=False, normalize=True):
        """
        Embed a list of document chunks or raw texts.
        """
        if isinstance(texts, str):
            texts = [texts]

        if not texts:
            return np.array([], dtype=np.float32).reshape(0, 384)

        texts = [str(text).strip() for text in texts]

        if not texts:
            return np.array([], dtype=np.float32).reshape(0, 384)
        if any(not text for text in texts):
            raise ValueError("Texts to embed must not contain empty values.")

        embeddings = self.model.encode(
            texts,
            convert_to_numpy=True,
            show_progress_bar=show_progress_bar,
            normalize_embeddings=normalize
        )

        return embeddings.astype(np.float32)

    def embed_query(self, query: str, normalize=True):
        """
        Embed a search query with the appropriate BGE instruction prefix for asymmetric retrieval.
        """
        if not query or not str(query).strip():
            return np.zeros((1, 384), dtype=np.float32)

        query_text = str(query).strip()
        if "bge" in self.model_name.lower() and not query_text.startswith(BGE_QUERY_PREFIX):
            query_text = f"{BGE_QUERY_PREFIX}{query_text}"

        embedding = self.model.encode(
            [query_text],
            convert_to_numpy=True,
            show_progress_bar=False,
            normalize_embeddings=normalize
        )
        return embedding.astype(np.float32)
