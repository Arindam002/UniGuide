# backend/app/utils/subject_classifier.py

import numpy as np
import logging
from app.rag.model_loader import get_shared_sentence_transformer
from database.db import get_connection

logger = logging.getLogger(__name__)

EMBED_MODEL = "BAAI/bge-small-en-v1.5"
SIMILARITY_THRESHOLD = 0.35


class SubjectClassifier:
    def __init__(self, device="cpu"):
        self.device = device
        self.subject_embeddings = {}
        self._prepare_subject_embeddings()

    @property
    def model(self):
        return get_shared_sentence_transformer(EMBED_MODEL, device=self.device)

    def _prepare_subject_embeddings(self):
        """
        Build lightweight, high-signal subject embeddings from distinct document
        metadata (subject names, titles, branches) rather than loading entire multi-megabyte texts into RAM.
        """
        conn = get_connection()
        try:
            cursor = conn.cursor()
            cursor.execute(
                """
                SELECT DISTINCT subject, name, branch
                FROM documents 
                WHERE subject IS NOT NULL AND TRIM(subject) != ''
                """
            )
            rows = cursor.fetchall()
        except Exception as e:
            logger.error(f"[SubjectClassifier] Failed to fetch subject metadata: {e}")
            return
        finally:
            conn.close()

        subject_descriptions = {}
        for row in rows:
            subj = str(row["subject"]).strip().lower()
            name = str(row["name"] or "").replace("_", " ").replace("-", " ")
            branch = str(row["branch"] or "")
            if subj not in subject_descriptions:
                subject_descriptions[subj] = []
            subject_descriptions[subj].append(f"{subj} {name} {branch}".strip())

        # Create one normalized centroid embedding per subject
        for subject, desc_list in subject_descriptions.items():
            combined_desc = " ; ".join(set(desc_list))[:1500]
            try:
                emb = self.model.encode(combined_desc, convert_to_numpy=True, normalize_embeddings=True)
                self.subject_embeddings[subject] = emb.astype(np.float32)
            except Exception as e:
                logger.warning(f"[SubjectClassifier] Could not encode subject '{subject}': {e}")

    def classify(self, question):
        """
        Returns the most similar academic subject if confidence exceeds threshold, else None.
        """
        if not question or not str(question).strip() or not self.subject_embeddings:
            return None

        try:
            q_emb = self.model.encode(
                str(question).strip(),
                convert_to_numpy=True,
                normalize_embeddings=True
            ).astype(np.float32)
        except Exception as e:
            logger.error(f"[SubjectClassifier] Query encoding failed: {e}")
            return None

        best_subject = None
        best_score = -1.0

        for subject, emb in self.subject_embeddings.items():
            # Dot product between unit-normalized vectors is cosine similarity
            score = float(np.dot(q_emb, emb))
            if score > best_score:
                best_score = score
                best_subject = subject

        if best_score >= SIMILARITY_THRESHOLD:
            return best_subject

        return None
