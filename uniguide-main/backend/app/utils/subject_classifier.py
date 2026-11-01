# backend/app/utils/subject_classifier.py

import numpy as np
from sentence_transformers import SentenceTransformer
from database.db import get_connection

# Use same embedding model as RAG
EMBED_MODEL = "sentence-transformers/all-MiniLM-L6-v2"


class SubjectClassifier:

    def __init__(self):
        self.model = SentenceTransformer(EMBED_MODEL)
        self.conn = get_connection()
        self.cursor = self.conn.cursor()
        self.subject_embeddings = {}
        self._prepare_subject_embeddings()

    def _prepare_subject_embeddings(self):
        """
        Load all documents grouped by subject, generate embeddings
        """
        self.cursor.execute(
            "SELECT subject, content FROM documents WHERE use_for_rag=1"
        )

        data = self.cursor.fetchall()

        # group by subject
        subject_texts = {}
        for subject, content in data:
            if content and len(content.strip()) > 50:
                subject_texts.setdefault(subject, []).append(content)

        # create a single embedding per subject
        for subject, texts in subject_texts.items():
            combined_text = " ".join(texts)
            embedding = self.model.encode(combined_text, convert_to_numpy=True)
            self.subject_embeddings[subject] = embedding / np.linalg.norm(embedding)

    def classify(self, question):
        """
        Returns the most similar subject
        """
        q_emb = self.model.encode(question, convert_to_numpy=True)
        q_emb /= np.linalg.norm(q_emb)

        best_subject = None
        best_score = -1

        for subject, emb in self.subject_embeddings.items():
            score = np.dot(q_emb, emb)
            if score > best_score:
                best_score = score
                best_subject = subject

        return best_subject