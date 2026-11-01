import os
import tempfile
from collections import defaultdict
from pathlib import Path

import faiss
import numpy as np

from app.rag.query_router import COMPUTER_SCIENCE
from database.db import get_connection, init_db


CURRENT_DIR = os.path.dirname(os.path.abspath(__file__))
APP_DIR = os.path.dirname(CURRENT_DIR)
VECTOR_DB_PATH = os.path.join(APP_DIR, "vector_db", "faiss_index")
NAMESPACE_INDEX_DIR = os.path.join(VECTOR_DB_PATH, "namespaces")
LEGACY_MIGRATION_MARKER = os.path.join(NAMESPACE_INDEX_DIR, ".legacy_migrated")
LEGACY_INDEX_FILES = {
    "books": os.path.join(VECTOR_DB_PATH, "books_index.faiss"),
    "pyqs": os.path.join(VECTOR_DB_PATH, "pyqs_index.faiss"),
}
BOOKS_INDEX_FILE = LEGACY_INDEX_FILES["books"]
PYQS_INDEX_FILE = LEGACY_INDEX_FILES["pyqs"]


class VectorStore:
    def __init__(self, dimension=384):
        self.dimension = dimension
        self.indexes = {}
        os.makedirs(NAMESPACE_INDEX_DIR, exist_ok=True)
        init_db()
        self._load_namespaced_indexes()
        if not os.path.exists(LEGACY_MIGRATION_MARKER):
            self._migrate_legacy_indexes()

    def _create_index(self):
        return faiss.IndexIDMap(faiss.IndexFlatL2(self.dimension))

    def _index_path(self, store_type, namespace):
        return os.path.join(NAMESPACE_INDEX_DIR, namespace, f"{store_type}.faiss")

    def _key(self, store_type, namespace):
        store_type = str(store_type).strip().lower()
        namespace = str(namespace or COMPUTER_SCIENCE).strip().lower()
        if store_type not in {"books", "pyqs"}:
            raise ValueError("store_type must be 'books' or 'pyqs'.")
        if not namespace.replace("_", "").isalnum():
            raise ValueError(f"Invalid namespace: {namespace}")
        return store_type, namespace

    def _load_namespaced_indexes(self):
        for store_type in ("books", "pyqs"):
            for path in Path(NAMESPACE_INDEX_DIR).glob(f"*/{store_type}.faiss"):
                namespace = path.parent.name
                key = self._key(store_type, namespace)
                index = faiss.read_index(str(path))
                if index.d != self.dimension:
                    raise ValueError(
                        f"{path} has dimension {index.d}; expected {self.dimension}."
                    )
                self.indexes[key] = index
                print(f"[INFO] Loaded {store_type} namespace '{namespace}': {path}")

    def _migrate_legacy_indexes(self):
        legacy_files = {
            store_type: path
            for store_type, path in LEGACY_INDEX_FILES.items()
            if os.path.exists(path)
        }
        if not legacy_files:
            return

        conn = get_connection()
        grouped_vectors = defaultdict(list)
        try:
            cursor = conn.cursor()
            existing_ids = {
                key: set(faiss.vector_to_array(index.id_map).tolist())
                for key, index in self.indexes.items()
            }
            for store_type, path in legacy_files.items():
                legacy_index = faiss.read_index(path)
                if legacy_index.d != self.dimension:
                    raise ValueError(
                        f"Legacy {store_type} index dimension {legacy_index.d} "
                        f"does not match expected {self.dimension}."
                    )

                vector_ids = faiss.vector_to_array(legacy_index.id_map)
                for position, vector_id in enumerate(vector_ids):
                    cursor.execute(
                        """
                        SELECT d.domain
                        FROM chunks c
                        JOIN documents d ON d.id = c.document_id
                        WHERE c.vector_id = ? AND c.store_type = ?
                        LIMIT 1
                        """,
                        (int(vector_id), store_type),
                    )
                    row = cursor.fetchone()
                    if row is None:
                        print(
                            f"[WARN] No SQLite metadata for legacy "
                            f"{store_type} vector {int(vector_id)}; skipping it."
                        )
                        continue

                    key = self._key(store_type, row["domain"])
                    if int(vector_id) in existing_ids.get(key, set()):
                        continue

                    vector = legacy_index.index.reconstruct(position)
                    grouped_vectors[key].append(
                        (int(vector_id), vector)
                    )

            for (store_type, namespace), items in grouped_vectors.items():
                key = self._key(store_type, namespace)
                index = self.indexes.get(key) or self._create_index()
                vectors = np.asarray([item[1] for item in items], dtype=np.float32)
                vector_ids = np.asarray([item[0] for item in items], dtype=np.int64)
                index.add_with_ids(vectors, vector_ids)
                self.indexes[key] = index

            self.save()
            temporary_marker = f"{LEGACY_MIGRATION_MARKER}.tmp"
            with open(temporary_marker, "w", encoding="utf-8") as marker_file:
                marker_file.write("complete\n")
                marker_file.flush()
                os.fsync(marker_file.fileno())
            os.replace(temporary_marker, LEGACY_MIGRATION_MARKER)
            print(
                f"[INFO] Migrated legacy FAISS vectors into "
                f"{len(grouped_vectors)} isolated namespace index(es)."
            )
        finally:
            conn.close()

    def get_index(self, store_type, namespace=COMPUTER_SCIENCE):
        key = self._key(store_type, namespace)
        if key not in self.indexes:
            self.indexes[key] = self._create_index()
        return self.indexes[key]

    def get_indexes(self, store_type, namespaces):
        """Return namespace/index pairs, creating empty indexes as needed."""
        return [
            (self._key(store_type, namespace)[1], self.get_index(store_type, namespace))
            for namespace in dict.fromkeys(namespaces)
        ]

    def get_next_ids(self, count, store_type, namespace=COMPUTER_SCIENCE):
        if count <= 0:
            raise ValueError("count must be greater than 0")
        store_type, namespace = self._key(store_type, namespace)
        ids = [
            int(vector_id)
            for (indexed_store, _), index in self.indexes.items()
            if indexed_store == store_type
            for vector_id in faiss.vector_to_array(index.id_map)
        ]
        conn = get_connection()
        try:
            row = conn.execute(
                "SELECT MAX(vector_id) FROM chunks WHERE store_type = ?",
                (store_type,),
            ).fetchone()
            database_max_id = row[0] if row else None
        finally:
            conn.close()
        database_max_id = (
            database_max_id if database_max_id is not None else -1
        )
        start_id = max(max(ids, default=-1), database_max_id) + 1
        return list(range(start_id, start_id + count))

    def add_embeddings(
        self,
        embeddings,
        vector_ids,
        store_type,
        namespace=COMPUTER_SCIENCE,
    ):
        if embeddings is None or len(embeddings) == 0:
            raise ValueError("No embeddings provided to add.")
        if vector_ids is None or len(vector_ids) == 0:
            raise ValueError("No vector_ids provided to add.")

        index = self.get_index(store_type, namespace)
        embeddings = np.asarray(embeddings, dtype=np.float32)
        vector_ids = np.asarray(vector_ids, dtype=np.int64)
        if embeddings.ndim != 2 or embeddings.shape[1] != self.dimension:
            raise ValueError(
                f"Embeddings must have shape [N, {self.dimension}], "
                f"got {embeddings.shape}."
            )
        if vector_ids.ndim != 1 or len(embeddings) != len(vector_ids):
            raise ValueError("Embedding and vector ID counts must match.")

        index.add_with_ids(embeddings, vector_ids)
        return vector_ids.tolist()

    def search(
        self,
        query_embedding,
        store_type="books",
        top_k=5,
        namespace=COMPUTER_SCIENCE,
    ):
        index = self.get_index(store_type, namespace)
        if index.ntotal == 0:
            return []

        query_embedding = np.asarray(query_embedding, dtype=np.float32)
        if query_embedding.ndim == 1:
            query_embedding = query_embedding.reshape(1, -1)
        if query_embedding.ndim != 2 or query_embedding.shape[1] != self.dimension:
            raise ValueError(
                f"Query embedding must have shape [N, {self.dimension}], "
                f"got {query_embedding.shape}."
            )

        _, ids = index.search(query_embedding, top_k)
        return [int(vector_id) for vector_id in ids[0] if vector_id != -1]

    def get_total_vectors(self, store_type=None):
        counts = {"books": 0, "pyqs": 0}
        for (indexed_store, _), index in self.indexes.items():
            counts[indexed_store] += index.ntotal
        if store_type in counts:
            return counts[store_type]
        if store_type is None:
            return counts
        raise ValueError("store_type must be 'books', 'pyqs', or None.")

    def save(self):
        for (store_type, namespace), index in self.indexes.items():
            path = Path(self._index_path(store_type, namespace))
            path.parent.mkdir(parents=True, exist_ok=True)
            descriptor, temporary_name = tempfile.mkstemp(
                dir=path.parent,
                prefix=f".{path.name}.",
                suffix=".tmp",
            )
            os.close(descriptor)
            try:
                faiss.write_index(index, temporary_name)
                os.replace(temporary_name, path)
            finally:
                if os.path.exists(temporary_name):
                    os.remove(temporary_name)

    def reset(self):
        for path in Path(NAMESPACE_INDEX_DIR).glob("*/*.faiss"):
            path.unlink()
        self.indexes.clear()
        for path in LEGACY_INDEX_FILES.values():
            if os.path.exists(path):
                os.remove(path)
        if os.path.exists(LEGACY_MIGRATION_MARKER):
            os.remove(LEGACY_MIGRATION_MARKER)
