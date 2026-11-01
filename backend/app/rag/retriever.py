import os
import sys
import numpy as np
from app.rag.query_router import retrieval_namespaces
from app.nlp.query_preprocessing import normalize_query_typos
from app.rag.vector_store import VectorStore
from app.rag.embedder import Embedder
from app.rag.source_metadata import (
    get_textbook_metadata,
    is_foundational_cs_query,
)
from database.db import get_connection

# Ensure backend root is accessible for imports
CURRENT_DIR = os.path.dirname(os.path.abspath(__file__))
BACKEND_DIR = os.path.abspath(os.path.join(CURRENT_DIR, "../../"))
if BACKEND_DIR not in sys.path:
    sys.path.append(BACKEND_DIR)


class Retriever:
    def __init__(self, embedder=None, vector_store=None):
        self.embedder = embedder or Embedder()
        self.vector_store = vector_store or VectorStore()

    def _get_category(self, category):
        """Map request category to the corpus partition."""
        if not category:
            return "books"

        cat = str(category).strip().lower()
        if cat in {"books", "pyqs"}:
            return cat
        if cat == "notes":
            return None
        return "books"

    def retrieve(
        self,
        query,
        branch=None,
        semester=None,
        subject=None,
        category=None,
        top_k=5,
        prioritize_computer_science_textbooks=False,
        namespace=None,
    ):
        """
        Search routed domain namespace in FAISS and fetch SQLite metadata.
        Thread-safe: creates a dedicated database connection per retrieval call.
        """
        query = normalize_query_typos(query)
        if not query:
            return []

        db_category = self._get_category(category)
        if db_category is None:
            return []

        search_namespaces = retrieval_namespaces(query, namespace)
        if hasattr(self.vector_store, "get_indexes"):
            namespace_indexes = self.vector_store.get_indexes(
                db_category,
                search_namespaces,
            )
        else:
            namespace_indexes = [
                (name, self.vector_store.get_index(db_category, name))
                for name in search_namespaces
            ]
        namespace_indexes = [
            (name, index)
            for name, index in namespace_indexes
            if index.ntotal > 0
        ]
        if not namespace_indexes:
            return []

        prioritize_textbooks = (
            prioritize_computer_science_textbooks
            and db_category == "books"
            and is_foundational_cs_query(query)
        )

        embedding_query = query
        if prioritize_textbooks:
            embedding_query = (
                f"{query} foundational computer science textbook "
                "abstract data type algorithms data structures "
                "memory allocation asymptotic time and space complexity "
                "structural invariants"
            )

        # 1. Embed query with BGE prefix and L2 normalization
        query_embedding = self.embedder.embed_query(embedding_query, normalize=True)
        if query_embedding.ndim == 1:
            query_embedding = query_embedding.reshape(1, -1)

        results = []
        conn = get_connection()
        try:
            cursor = conn.cursor()

            for search_namespace, index in namespace_indexes:
                # Fetch extra candidates to compensate for SQLite metadata filters.
                k_search = min(top_k * 10, index.ntotal)
                distances, indices = index.search(query_embedding, k_search)
                for i, vector_id in enumerate(indices[0]):
                    vector_id = int(vector_id)
                    if vector_id < 0:
                        continue

                    # 3. Fetch chunk + document metadata from SQLite
                    cursor.execute(
                        """
                        SELECT
                            c.chunk_text,
                            c.vector_id,
                            d.name,
                            d.category,
                            d.domain,
                            d.subject,
                            d.branch,
                            d.semester
                        FROM chunks c
                        JOIN documents d ON c.document_id = d.id
                        WHERE c.vector_id = ?
                          AND c.store_type = ?
                          AND d.category = ?
                          AND d.domain = ?
                          AND d.use_for_rag = 1
                        LIMIT 1
                        """,
                        (
                            vector_id,
                            db_category,
                            db_category,
                            search_namespace,
                        ),
                    )

                    row = cursor.fetchone()
                    if not row:
                        continue

                    # 4. Apply metadata filters safely
                    if branch:
                        row_branch = (row["branch"] or "").strip().lower()
                        if row_branch != str(branch).strip().lower():
                            continue

                    if semester:
                        row_semester = str(row["semester"] or "").strip().lower()
                        if row_semester != str(semester).strip().lower():
                            continue

                    if subject and str(subject).strip().lower() != "general":
                        row_subject = (row["subject"] or "").strip().lower()
                        if row_subject != str(subject).strip().lower():
                            continue

                    metadata = get_textbook_metadata(
                        file_name=row["name"],
                        subject=row["subject"],
                        category=row["category"],
                    )

                    # d^2 = 2 - 2*cos(theta) for normalized vectors.
                    l2_dist_sq = float(distances[0][i])
                    cosine_sim = max(0.0, min(1.0, 1.0 - (l2_dist_sq / 2.0)))

                    results.append({
                        "chunk_text": row["chunk_text"],
                        "file_name": row["name"],
                        "category": row["category"],
                        "domain": row["domain"],
                        "subject": row["subject"],
                        "branch": row["branch"],
                        "semester": row["semester"],
                        "namespace": search_namespace,
                        **metadata,
                        "score": round(cosine_sim, 4),
                        "l2_distance": round(l2_dist_sq, 4),
                        "vector_id": int(row["vector_id"])
                    })

        finally:
            conn.close()

        if prioritize_textbooks:
            results.sort(
                key=lambda result: (
                    result["rag_category"] != "computer_science_textbook",
                    -result["score"],
                )
            )
            return results[:top_k]

        if len(search_namespaces) > 1:
            candidates_by_namespace = {
                name: [] for name in search_namespaces
            }
            for result in results:
                candidates_by_namespace[result["namespace"]].append(result)
            results = []
            for name in search_namespaces:
                candidates = candidates_by_namespace[name]
                candidates.sort(
                    key=lambda result: result["score"],
                    reverse=True,
                )
                results.extend(candidates[:top_k])
            return results

        results.sort(key=lambda result: result["score"], reverse=True)
        return results[:top_k]

    def retrieve_from_books(self, query, branch=None, semester=None, subject=None, top_k=5):
        return self.retrieve(
            query=query,
            branch=branch,
            semester=semester,
            subject=subject,
            category="books",
            top_k=top_k
        )

    def retrieve_from_pyqs(self, query, branch=None, semester=None, subject=None, top_k=5):
        return self.retrieve(
            query=query,
            branch=branch,
            semester=semester,
            subject=subject,
            category="pyqs",
            top_k=top_k
        )

    def close(self):
        """No-op for backward compatibility since connections are managed per-request."""
        pass
