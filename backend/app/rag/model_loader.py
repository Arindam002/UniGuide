import threading
import logging
from sentence_transformers import SentenceTransformer, CrossEncoder

logger = logging.getLogger(__name__)

_LOCK = threading.Lock()
_SENTENCE_TRANSFORMERS = {}
_CROSS_ENCODERS = {}


def get_shared_sentence_transformer(
    model_name: str = "BAAI/bge-small-en-v1.5",
    device: str = "cpu"
) -> SentenceTransformer:
    """
    Thread-safe singleton accessor for SentenceTransformer models.
    Tries offline cache first; if not found, falls back to standard loading.
    Prevents duplicate models from consuming hundreds of MBs in memory.
    """
    cache_key = (model_name, device)
    if cache_key in _SENTENCE_TRANSFORMERS:
        return _SENTENCE_TRANSFORMERS[cache_key]

    with _LOCK:
        if cache_key in _SENTENCE_TRANSFORMERS:
            return _SENTENCE_TRANSFORMERS[cache_key]

        try:
            # Try offline / local cache first for speed and isolation
            model = SentenceTransformer(
                model_name,
                device=device,
                local_files_only=True
            )
        except Exception:
            # Graceful fallback for new environments or missing local cache
            logger.info(
                f"[ModelLoader] Model {model_name} not found in local cache; downloading/loading normally..."
            )
            model = SentenceTransformer(
                model_name,
                device=device,
                local_files_only=False
            )

        _SENTENCE_TRANSFORMERS[cache_key] = model
        return model


def get_shared_cross_encoder(
    model_name: str = "cross-encoder/ms-marco-MiniLM-L-6-v2",
    device: str = "cpu"
) -> CrossEncoder:
    """
    Thread-safe singleton accessor for CrossEncoder models.
    Tries offline cache first; falls back to standard loading on cache miss.
    """
    cache_key = (model_name, device)
    if cache_key in _CROSS_ENCODERS:
        return _CROSS_ENCODERS[cache_key]

    with _LOCK:
        if cache_key in _CROSS_ENCODERS:
            return _CROSS_ENCODERS[cache_key]

        try:
            model = CrossEncoder(
                model_name,
                device=device,
                local_files_only=True
            )
        except Exception:
            logger.info(
                f"[ModelLoader] CrossEncoder {model_name} not found in local cache; downloading/loading normally..."
            )
            model = CrossEncoder(
                model_name,
                device=device,
                local_files_only=False
            )

        _CROSS_ENCODERS[cache_key] = model
        return model

