import uuid
import json
from database.db import get_connection


# =============================
# MEMORY INTENT DETECTION
# =============================

MEMORY_TRIGGER_WORDS = [
    "previous",
    "earlier",
    "before",
    "last time",
    "you said",
    "continue",
    "same topic",
    "our last chat",
    "yesterday",
    "remember",
    "we discussed",
    "you told",
    "my last question",
]

FOLLOW_UP_WORDS = [
    "explain again",
    "again",
    "simplify",
    "simple words",
    "make it simple",
    "short answer",
    "long answer",
    "elaborate",
    "continue",
    "give example",
    "example",
    "diagram",
    "explain this",
    "what about this",
]


def should_use_long_term_memory(question: str) -> bool:
    if not question:
        return False

    q = question.lower().strip()
    return any(word in q for word in MEMORY_TRIGGER_WORDS)


def is_follow_up_question(question: str) -> bool:
    if not question:
        return False

    q = question.lower().strip()
    return any(word in q for word in FOLLOW_UP_WORDS)


# =============================
# CHAT SESSION
# =============================

def create_chat_session(student_id=None, guest_id=None, title=None):
    chat_id = str(uuid.uuid4())

    if not title:
        title = "New Chat"

    conn = get_connection()
    cursor = conn.cursor()

    try:
        cursor.execute(
            """
            INSERT INTO chat_sessions (
                id, student_id, guest_id, title
            )
            VALUES (?, ?, ?, ?)
            """,
            (chat_id, student_id, guest_id, title),
        )

        conn.commit()
        return chat_id

    except Exception as e:
        conn.rollback()
        print(f"[ERROR] Failed to create chat session: {e}")
        raise

    finally:
        conn.close()


def ensure_chat_session(chat_id=None, student_id=None, guest_id=None, title=None):
    if chat_id:
        conn = get_connection()
        cursor = conn.cursor()

        try:
            cursor.execute(
                "SELECT id FROM chat_sessions WHERE id = ?",
                (chat_id,),
            )
            row = cursor.fetchone()

            if row:
                return chat_id

        finally:
            conn.close()

    return create_chat_session(
        student_id=student_id,
        guest_id=guest_id,
        title=title,
    )


# =============================
# SHORT-TERM MEMORY
# =============================

def save_message(chat_id, role, content):
    if role not in ["user", "assistant"]:
        raise ValueError("role must be either 'user' or 'assistant'")

    if not chat_id or not content:
        return

    conn = get_connection()
    cursor = conn.cursor()

    try:
        cursor.execute(
            """
            INSERT INTO chat_messages (
                chat_id, role, content
            )
            VALUES (?, ?, ?)
            """,
            (chat_id, role, content),
        )

        cursor.execute(
            """
            UPDATE chat_sessions
            SET updated_at = CURRENT_TIMESTAMP
            WHERE id = ?
            """,
            (chat_id,),
        )

        conn.commit()

    except Exception as e:
        conn.rollback()
        print(f"[ERROR] Failed to save chat message: {e}")
        raise

    finally:
        conn.close()


def load_recent_messages(chat_id, limit=8):
    if not chat_id:
        return []

    conn = get_connection()
    cursor = conn.cursor()

    try:
        cursor.execute(
            """
            SELECT role, content, created_at
            FROM chat_messages
            WHERE chat_id = ?
            ORDER BY id DESC
            LIMIT ?
            """,
            (chat_id, limit),
        )

        rows = cursor.fetchall()

        messages = [
            {
                "role": row["role"],
                "content": row["content"],
                "created_at": row["created_at"],
            }
            for row in rows
        ]

        messages.reverse()
        return messages

    except Exception as e:
        print(f"[ERROR] Failed to load recent messages: {e}")
        return []

    finally:
        conn.close()


def get_chat_messages(chat_id):
    if not chat_id:
        return []

    conn = get_connection()
    cursor = conn.cursor()

    try:
        cursor.execute(
            """
            SELECT role, content, created_at
            FROM chat_messages
            WHERE chat_id = ?
            ORDER BY id ASC
            """,
            (chat_id,),
        )

        rows = cursor.fetchall()

        return [
            {
                "role": row["role"],
                "content": row["content"],
                "created_at": row["created_at"],
            }
            for row in rows
        ]

    except Exception as e:
        print(f"[ERROR] Failed to get chat messages: {e}")
        return []

    finally:
        conn.close()


# =============================
# CHAT SESSION LIST
# =============================

def get_chat_sessions(student_id=None, guest_id=None):
    conn = get_connection()
    cursor = conn.cursor()

    try:
        if student_id:
            cursor.execute(
                """
                SELECT id, title, created_at, updated_at
                FROM chat_sessions
                WHERE student_id = ?
                ORDER BY updated_at DESC
                """,
                (student_id,),
            )

        elif guest_id:
            cursor.execute(
                """
                SELECT id, title, created_at, updated_at
                FROM chat_sessions
                WHERE guest_id = ?
                ORDER BY updated_at DESC
                """,
                (guest_id,),
            )

        else:
            return []

        rows = cursor.fetchall()

        return [
            {
                "chat_id": row["id"],
                "title": row["title"],
                "created_at": row["created_at"],
                "updated_at": row["updated_at"],
            }
            for row in rows
        ]

    except Exception as e:
        print(f"[ERROR] Failed to get chat sessions: {e}")
        return []

    finally:
        conn.close()


# =============================
# LONG-TERM MEMORY DB
# =============================

def save_long_term_memory(
    chat_id,
    memory_text,
    vector_id=None,
    student_id=None,
    guest_id=None,
):
    """
    Saves long-term memory only.
    Do not call this for every academic question.
    """

    if not chat_id or not memory_text:
        return None

    conn = get_connection()
    cursor = conn.cursor()

    try:
        cursor.execute(
            """
            INSERT INTO chat_memory (
                student_id,
                guest_id,
                chat_id,
                memory_text,
                vector_id
            )
            VALUES (?, ?, ?, ?, ?)
            """,
            (
                student_id,
                guest_id,
                chat_id,
                memory_text,
                vector_id,
            ),
        )

        memory_id = cursor.lastrowid
        conn.commit()
        return memory_id

    except Exception as e:
        conn.rollback()
        print(f"[ERROR] Failed to save long-term memory: {e}")
        return None

    finally:
        conn.close()


def update_memory_vector_id(memory_id, vector_id):
    if memory_id is None or vector_id is None:
        return

    conn = get_connection()
    cursor = conn.cursor()

    try:
        cursor.execute(
            """
            UPDATE chat_memory
            SET vector_id = ?
            WHERE id = ?
            """,
            (vector_id, memory_id),
        )

        conn.commit()

    except Exception as e:
        conn.rollback()
        print(f"[ERROR] Failed to update memory vector_id: {e}")

    finally:
        conn.close()


def get_memory_by_vector_ids(vector_ids, student_id=None, guest_id=None):
    if not vector_ids:
        return []

    conn = get_connection()
    cursor = conn.cursor()

    try:
        placeholders = ",".join(["?"] * len(vector_ids))
        params = list(vector_ids)

        owner_filter = ""

        if student_id:
            owner_filter = "AND student_id = ?"
            params.append(student_id)

        elif guest_id:
            owner_filter = "AND guest_id = ?"
            params.append(guest_id)

        cursor.execute(
            f"""
            SELECT
                id,
                student_id,
                guest_id,
                chat_id,
                memory_text,
                vector_id,
                created_at
            FROM chat_memory
            WHERE vector_id IN ({placeholders})
            {owner_filter}
            ORDER BY created_at DESC
            """,
            params,
        )

        rows = cursor.fetchall()

        return [
            {
                "id": row["id"],
                "student_id": row["student_id"],
                "guest_id": row["guest_id"],
                "chat_id": row["chat_id"],
                "memory_text": row["memory_text"],
                "vector_id": row["vector_id"],
                "created_at": row["created_at"],
            }
            for row in rows
        ]

    except Exception as e:
        print(f"[ERROR] Failed to get memories by vector IDs: {e}")
        return []

    finally:
        conn.close()


def get_recent_long_term_memories(student_id=None, guest_id=None, limit=5):
    conn = get_connection()
    cursor = conn.cursor()

    try:
        if student_id:
            cursor.execute(
                """
                SELECT id, chat_id, memory_text, vector_id, created_at
                FROM chat_memory
                WHERE student_id = ?
                ORDER BY created_at DESC
                LIMIT ?
                """,
                (student_id, limit),
            )

        elif guest_id:
            cursor.execute(
                """
                SELECT id, chat_id, memory_text, vector_id, created_at
                FROM chat_memory
                WHERE guest_id = ?
                ORDER BY created_at DESC
                LIMIT ?
                """,
                (guest_id, limit),
            )

        else:
            return []

        rows = cursor.fetchall()

        return [
            {
                "id": row["id"],
                "chat_id": row["chat_id"],
                "memory_text": row["memory_text"],
                "vector_id": row["vector_id"],
                "created_at": row["created_at"],
            }
            for row in rows
        ]

    except Exception as e:
        print(f"[ERROR] Failed to get recent long-term memories: {e}")
        return []

    finally:
        conn.close()


def get_safe_long_term_memories(question, student_id=None, guest_id=None, limit=5):
    """
    Safe wrapper.
    Long-term memory is used only when user clearly asks for previous context.
    """

    if not should_use_long_term_memory(question):
        print("[MEMORY] Skipped long-term memory: no memory intent")
        return []

    print("[MEMORY] Long-term memory allowed")

    return get_recent_long_term_memories(
        student_id=student_id,
        guest_id=guest_id,
        limit=limit,
    )


def memory_exists_for_chat(chat_id):
    if not chat_id:
        return False

    conn = get_connection()
    cursor = conn.cursor()

    try:
        cursor.execute(
            """
            SELECT id
            FROM chat_memory
            WHERE chat_id = ?
            LIMIT 1
            """,
            (chat_id,),
        )

        row = cursor.fetchone()
        return row is not None

    except Exception as e:
        print(f"[ERROR] Failed to check chat memory: {e}")
        return False

    finally:
        conn.close()


def build_chat_summary_text(chat_id, max_messages=12):
    """
    Builds text for long-term summary.
    Use this only when you intentionally want to save a useful memory.
    """

    messages = load_recent_messages(chat_id, limit=max_messages)

    if not messages:
        return ""

    lines = []

    for msg in messages:
        role = msg.get("role")
        content = msg.get("content")

        if not content:
            continue

        if role == "user":
            lines.append(f"Student: {content}")
        elif role == "assistant":
            lines.append(f"UniGuide: {content}")

    return "\n".join(lines)


# =============================
# CHAT CONTEXT
# Used for follow-up answers
# =============================

def save_chat_context(chat_id, question, rewritten_question, chunks):
    """
    Saves last retrieved academic chunks.
    This is short-term academic context, not long-term memory.
    """

    if not chat_id or not chunks:
        print("[CHAT CONTEXT] Not saved: missing chat_id or chunks")
        return

    source_files = []

    for chunk in chunks:
        file_name = chunk.get("file_name")
        if file_name and file_name not in source_files:
            source_files.append(file_name)

    conn = get_connection()
    cursor = conn.cursor()

    try:
        cursor.execute(
            """
            INSERT INTO chat_context (
                chat_id,
                question,
                rewritten_question,
                source_files,
                retrieved_chunks_json
            )
            VALUES (?, ?, ?, ?, ?)
            """,
            (
                chat_id,
                question,
                rewritten_question,
                json.dumps(source_files),
                json.dumps(chunks),
            ),
        )

        conn.commit()

        print(f"[CHAT CONTEXT] Saved context for chat_id: {chat_id}")
        print(f"[CHAT CONTEXT] Sources: {source_files}")
        print(f"[CHAT CONTEXT] Chunks saved: {len(chunks)}")

    except Exception as e:
        conn.rollback()
        print(f"[ERROR] Failed to save chat context: {e}")

    finally:
        conn.close()


def get_last_chat_context(chat_id):
    if not chat_id:
        print("[CHAT CONTEXT] Cannot load: missing chat_id")
        return None

    conn = get_connection()
    cursor = conn.cursor()

    try:
        cursor.execute(
            """
            SELECT question, rewritten_question, source_files, retrieved_chunks_json
            FROM chat_context
            WHERE chat_id = ?
            ORDER BY id DESC
            LIMIT 1
            """,
            (chat_id,),
        )

        row = cursor.fetchone()

        if not row:
            print(f"[CHAT CONTEXT] No context found for chat_id: {chat_id}")
            return None

        context = {
            "question": row["question"],
            "rewritten_question": row["rewritten_question"],
            "source_files": json.loads(row["source_files"] or "[]"),
            "chunks": json.loads(row["retrieved_chunks_json"] or "[]"),
        }

        print(f"[CHAT CONTEXT] Loaded context for chat_id: {chat_id}")
        print(f"[CHAT CONTEXT] Sources: {context['source_files']}")
        print(f"[CHAT CONTEXT] Loaded chunks: {len(context['chunks'])}")

        return context

    except Exception as e:
        print(f"[ERROR] Failed to load last chat context: {e}")
        return None

    finally:
        conn.close()


def get_safe_chat_context(question, chat_id):
    """
    Use previous retrieved chunks only for follow-up type questions.
    """

    if not is_follow_up_question(question):
        print("[CHAT CONTEXT] Skipped: not a follow-up question")
        return None

    return get_last_chat_context(chat_id)


# =============================
# FINAL CONTEXT BUILDER
# Use this in chat route / RAG pipeline
# =============================

def build_memory_context_for_chat(
    question,
    chat_id=None,
    student_id=None,
    guest_id=None,
):
    """
    This function keeps everything separated.

    Returns:
    - short_term_messages
    - last_chat_context
    - long_term_memories
    """

    short_term_messages = load_recent_messages(chat_id, limit=8)

    last_chat_context = get_safe_chat_context(
        question=question,
        chat_id=chat_id,
    )

    long_term_memories = get_safe_long_term_memories(
        question=question,
        student_id=student_id,
        guest_id=guest_id,
        limit=5,
    )

    return {
        "short_term_messages": short_term_messages,
        "last_chat_context": last_chat_context,
        "long_term_memories": long_term_memories,
    }