#!/usr/bin/env python3
"""Safely preview or remove rows associated with UniGuide eval guest IDs."""

import argparse
import os
import sqlite3
import sys
from pathlib import Path


BACKEND_DIR = Path(__file__).resolve().parents[1]
DEFAULT_DB_PATH = BACKEND_DIR / "database" / "uniguide.db"
DEFAULT_BACKUP_PATH = BACKEND_DIR / "database" / "uniguide_eval.db"
DEFAULT_MEMORY_INDEX_DIR = (
    BACKEND_DIR / "app" / "vector_db" / "faiss_index"
)
EVAL_GUEST_PREFIX = "uniguide-eval-"
DIRECT_TABLES = {
    "chat_sessions",
    "chat_messages",
    "chat_context",
    "search_history",
}
LINK_COLUMNS = ("chat_id", "chat_session_id", "session_id", "guest_id")
MEMORY_INDEX_NAME = "chat_memory_index.faiss"


def quote_identifier(value):
    return '"' + value.replace('"', '""') + '"'


def connect_read_only(path):
    uri = f"file:{path.resolve().as_posix()}?mode=ro"
    return sqlite3.connect(uri, uri=True, timeout=10)


def list_tables(connection):
    return {
        row[0]
        for row in connection.execute(
            "SELECT name FROM sqlite_master WHERE type = 'table' "
            "AND name NOT LIKE 'sqlite_%'"
        )
    }


def table_columns(connection, table):
    return {
        row[1]
        for row in connection.execute(
            f"PRAGMA table_info({quote_identifier(table)})"
        )
    }


def linked_row_predicate(table, columns):
    if table == "chat_sessions":
        if "guest_id" not in columns:
            return None
        guest_column = quote_identifier("guest_id")
        return (
            f"substr({guest_column}, 1, ?) = ?",
            (len(EVAL_GUEST_PREFIX), EVAL_GUEST_PREFIX),
        )

    predicates = []
    parameters = []
    for column in LINK_COLUMNS:
        if column not in columns:
            continue
        quoted_column = quote_identifier(column)
        if column == "guest_id":
            predicates.append(f"substr({quoted_column}, 1, ?) = ?")
            parameters.extend((len(EVAL_GUEST_PREFIX), EVAL_GUEST_PREFIX))
        else:
            predicates.append(
                f"{quoted_column} IN ("
                "SELECT id FROM chat_sessions "
                "WHERE substr(guest_id, 1, ?) = ?)"
            )
            parameters.extend((len(EVAL_GUEST_PREFIX), EVAL_GUEST_PREFIX))

    if not predicates:
        return None
    return " OR ".join(predicates), tuple(parameters)


def cleanup_plan(connection):
    tables = list_tables(connection)
    if "chat_sessions" not in tables:
        raise RuntimeError("The database does not contain chat_sessions.")

    relevant_tables = set(DIRECT_TABLES)
    relevant_tables.update(
        table
        for table in tables
        if "memory" in table.lower()
        or (
            "diagram" in table.lower()
            and not table.lower().startswith("diagram_search")
        )
    )
    relevant_tables.intersection_update(tables)

    plan = {}
    counts = {}
    for table in sorted(relevant_tables):
        columns = table_columns(connection, table)
        predicate = linked_row_predicate(table, columns)
        if predicate is None:
            plan[table] = (None, ())
            counts[table] = 0
            continue

        condition, parameters = predicate
        count = connection.execute(
            f"SELECT COUNT(*) FROM {quote_identifier(table)} "
            f"WHERE {condition}",
            parameters,
        ).fetchone()[0]
        plan[table] = (condition, parameters)
        counts[table] = count
    return plan, counts


def row_counts(connection, tables):
    existing_tables = list_tables(connection)
    return {
        table: connection.execute(
            f"SELECT COUNT(*) FROM {quote_identifier(table)}"
        ).fetchone()[0]
        for table in sorted(tables & existing_tables)
    }


def print_plan(connection, plan, counts, backup_path):
    print(f"Database: {connection.execute('PRAGMA database_list').fetchone()[2]}")
    print(f"Eval guest ID prefix: {EVAL_GUEST_PREFIX}")
    print("Rows selected for deletion:")
    for table in sorted(counts):
        print(f"  {table}: {counts[table]}")

    backup_counts = {}
    current_counts = row_counts(connection, set(counts))
    if backup_path.is_file():
        with connect_read_only(backup_path) as backup:
            backup_counts = row_counts(backup, set(counts))
        print(f"Backup row counts ({backup_path}):")
        for table in sorted(counts):
            before = current_counts[table]
            reference = backup_counts.get(table, "not present")
            projected = before - counts[table]
            delta = (
                projected - reference
                if isinstance(reference, int)
                else "n/a"
            )
            print(
                f"  {table}: current={before}, selected={counts[table]}, "
                f"projected={projected}, backup={reference}, "
                f"projected-minus-backup={delta}"
            )
    else:
        print(f"Backup database not found: {backup_path}")

    memory_path = Path(
        os.environ.get(
            "UNIGUIDE_MEMORY_INDEX_DIR",
            str(DEFAULT_MEMORY_INDEX_DIR),
        )
    ).expanduser().resolve() / MEMORY_INDEX_NAME
    memory_vectors = []
    if "chat_memory" in plan and counts.get("chat_memory", 0):
        condition, parameters = plan["chat_memory"]
        rows = connection.execute(
            f"SELECT vector_id FROM chat_memory WHERE {condition}",
            parameters,
        ).fetchall()
        memory_vectors = sorted(
            {row[0] for row in rows if row[0] is not None}
        )

    print(f"Chat-memory FAISS index: {memory_path}")
    if not memory_path.is_file():
        print("  Index file not found; vector membership could not be checked.")
        return
    if not memory_vectors:
        print("  No eval-linked chat_memory vector IDs were found.")
        return
    try:
        import faiss
    except ImportError:
        print(
            "  FAISS is not installed in this Python environment; "
            "vector membership could not be checked."
        )
        return

    index = faiss.read_index(str(memory_path))
    present = [vector_id for vector_id in memory_vectors if vector_id < index.ntotal]
    missing = [vector_id for vector_id in memory_vectors if vector_id >= index.ntotal]
    print(f"  Index vectors: {index.ntotal}")
    print(f"  Eval-linked vector IDs: {memory_vectors}")
    print(f"  Eval-linked vectors present: {present}")
    if missing:
        print(f"  Stored IDs outside index range: {missing}")


def execute_cleanup(connection, plan, counts):
    connection.execute("BEGIN IMMEDIATE")
    try:
        current_plan, current_counts = cleanup_plan(connection)
        if current_counts != counts:
            raise RuntimeError(
                "Eval-linked row counts changed since the preview. "
                "No rows were deleted; run a fresh preview."
            )

        deletion_order = sorted(
            plan,
            key=lambda table: (table == "chat_sessions", table),
        )
        deleted_counts = {}
        for table in deletion_order:
            condition, parameters = plan[table]
            if condition is None or counts.get(table, 0) == 0:
                deleted_counts[table] = 0
                continue
            cursor = connection.execute(
                f"DELETE FROM {quote_identifier(table)} WHERE {condition}",
                parameters,
            )
            deleted_counts[table] = cursor.rowcount
            if cursor.rowcount != counts[table]:
                raise RuntimeError(
                    f"Expected to delete {counts[table]} rows from {table}, "
                    f"but SQLite deleted {cursor.rowcount}."
                )
        connection.commit()
        return deleted_counts
    except Exception:
        connection.rollback()
        raise


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--execute",
        action="store_true",
        help="After previewing, require typing DELETE before removing rows.",
    )
    parser.add_argument(
        "--database",
        default=os.getenv("UNIGUIDE_DB_PATH", str(DEFAULT_DB_PATH)),
        help="SQLite database to inspect (defaults to UNIGUIDE_DB_PATH).",
    )
    parser.add_argument(
        "--backup",
        default=str(DEFAULT_BACKUP_PATH),
        help="Optional pre-eval database used for row-count comparison.",
    )
    args = parser.parse_args()

    database_path = Path(args.database).expanduser().resolve()
    backup_path = Path(args.backup).expanduser().resolve()
    if not database_path.is_file():
        raise FileNotFoundError(f"Database file not found: {database_path}")

    connection = sqlite3.connect(database_path, timeout=10)
    try:
        connection.execute("PRAGMA foreign_keys = ON")
        plan, counts = cleanup_plan(connection)
        print_plan(connection, plan, counts, backup_path)

        if not args.execute:
            print("DRY RUN ONLY: no rows were changed.")
            return

        confirmation = input(
            "Type DELETE to remove exactly these eval-linked rows: "
        )
        if confirmation != "DELETE":
            print("Confirmation not received; no rows were changed.")
            return

        deleted_counts = execute_cleanup(connection, plan, counts)
        print("Deletion committed in one transaction:")
        for table in sorted(deleted_counts):
            print(f"  {table}: {deleted_counts[table]}")

        if backup_path.is_file():
            with connect_read_only(backup_path) as backup:
                backup_counts = row_counts(backup, set(counts))
            after_counts = row_counts(connection, set(counts))
            print(f"Post-cleanup comparison with {backup_path}:")
            for table in sorted(after_counts):
                reference = backup_counts.get(table, "not present")
                delta = (
                    after_counts[table] - reference
                    if isinstance(reference, int)
                    else "n/a"
                )
                print(
                    f"  {table}: after={after_counts[table]}, "
                    f"backup={reference}, after-minus-backup={delta}"
                )
    finally:
        connection.close()


if __name__ == "__main__":
    try:
        main()
    except (OSError, sqlite3.Error, RuntimeError) as error:
        print(f"Cleanup failed: {error}", file=sys.stderr)
        sys.exit(1)
