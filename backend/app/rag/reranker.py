import logging
import math
from app.rag.model_loader import get_shared_cross_encoder

logger = logging.getLogger(__name__)


def normalize_relevance_score(score):
    """Map a cross-encoder logit monotonically into the [0, 1] range."""
    score = float(score)
    if math.isnan(score):
        return 0.0
    if score >= 0:
        return 1.0 / (1.0 + math.exp(-score))
    exp_score = math.exp(score)
    return exp_score / (1.0 + exp_score)


class Reranker:
    def __init__(self, model_name="cross-encoder/ms-marco-MiniLM-L-6-v2", device="cpu"):
        self.model_name = model_name
        self.device = device

    @property
    def model(self):
        return get_shared_cross_encoder(self.model_name, device=self.device)

    def rerank(self, question, chunks, top_k=None):
        """
        Rerank retrieved chunks using a cross-encoder model.
        Defensively handles empty chunks and attaches cross-encoder scores.
        """
        if not question or not chunks:
            return []

        # Prepare question-context pairs
        valid_chunks = [c for c in chunks if c and isinstance(c, dict) and c.get("chunk_text")]
        if not valid_chunks:
            return []

        pairs = [[question, chunk["chunk_text"]] for chunk in valid_chunks]

        try:
            scores = self.model.predict(pairs)
        except Exception as e:
            logger.error(f"[Reranker] CrossEncoder prediction failed: {e}")
            return valid_chunks[:top_k] if top_k else valid_chunks

        # Normalize logits for consistent diagnostics without threshold-dropping
        # candidates; the sigmoid is monotonic, so relative ranking is preserved.
        for chunk, score in zip(valid_chunks, scores):
            chunk["rerank_score_raw"] = float(score)
            chunk["rerank_score"] = normalize_relevance_score(score)

        # Sort descending by cross-encoder score
        ranked = sorted(
            valid_chunks,
            key=lambda x: x.get("rerank_score", float("-inf")),
            reverse=True
        )

        if top_k is not None and top_k > 0:
            return ranked[:top_k]

        return ranked
