PRAGMA foreign_keys = ON;

-- ============================
-- STUDENTS
-- ============================
CREATE TABLE IF NOT EXISTS students (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    password TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================
-- DOCUMENTS
-- ============================
CREATE TABLE IF NOT EXISTS documents (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    file_path TEXT UNIQUE NOT NULL,
    file_hash TEXT UNIQUE NOT NULL,
    category TEXT NOT NULL CHECK (category IN ('books', 'notes', 'pyqs')),
    domain TEXT NOT NULL DEFAULT 'computer_science',
    branch TEXT,
    semester TEXT,
    subject TEXT,
    total_pages INTEGER,
    content TEXT,
    use_for_rag INTEGER NOT NULL DEFAULT 1 CHECK (use_for_rag IN (0, 1)),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================
-- RAG CHUNKS
-- ============================
CREATE TABLE IF NOT EXISTS chunks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    document_id INTEGER NOT NULL,
    chunk_text TEXT NOT NULL,
    vector_id INTEGER NOT NULL,
    store_type TEXT NOT NULL CHECK (store_type IN ('books', 'pyqs')),
    chunk_index INTEGER NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (document_id)
        REFERENCES documents(id)
        ON DELETE CASCADE,

    UNIQUE(store_type, vector_id),
    UNIQUE(document_id, chunk_index)
);

-- ============================
-- SEARCH HISTORY
-- ============================
CREATE TABLE IF NOT EXISTS search_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    student_id INTEGER,
    guest_id TEXT,
    query TEXT NOT NULL,
    answer TEXT NOT NULL DEFAULT '',
    category TEXT,
    branch TEXT,
    semester TEXT,
    subject TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (student_id)
        REFERENCES students(id)
        ON DELETE CASCADE
);

-- ============================
-- DIAGRAMS
-- ============================
CREATE TABLE IF NOT EXISTS diagrams (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    document_id INTEGER NOT NULL,
    page_number INTEGER NOT NULL,
    image_path TEXT NOT NULL UNIQUE,
    caption TEXT,
    context_text TEXT,
    vector_id INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (document_id)
        REFERENCES documents(id)
        ON DELETE CASCADE
);

-- ============================
-- DIAGRAM FULL-TEXT SEARCH
-- Searches caption + context_text
-- ============================
CREATE VIRTUAL TABLE IF NOT EXISTS diagram_search USING fts5(
    caption,
    context_text,
    content='diagrams',
    content_rowid='id'
);

-- Auto-sync diagram_search when diagrams are inserted
CREATE TRIGGER IF NOT EXISTS diagrams_ai AFTER INSERT ON diagrams
BEGIN
    INSERT INTO diagram_search(rowid, caption, context_text)
    VALUES (new.id, new.caption, new.context_text);
END;

-- Auto-sync diagram_search when diagrams are updated
CREATE TRIGGER IF NOT EXISTS diagrams_au AFTER UPDATE ON diagrams
BEGIN
    INSERT INTO diagram_search(diagram_search, rowid, caption, context_text)
    VALUES ('delete', old.id, old.caption, old.context_text);

    INSERT INTO diagram_search(rowid, caption, context_text)
    VALUES (new.id, new.caption, new.context_text);
END;

-- Auto-sync diagram_search when diagrams are deleted
CREATE TRIGGER IF NOT EXISTS diagrams_ad AFTER DELETE ON diagrams
BEGIN
    INSERT INTO diagram_search(diagram_search, rowid, caption, context_text)
    VALUES ('delete', old.id, old.caption, old.context_text);
END;

-- ==============================
-- CHAT SESSIONS
-- ==============================
CREATE TABLE IF NOT EXISTS chat_sessions (
    id TEXT PRIMARY KEY,
    student_id INTEGER,
    guest_id TEXT,
    title TEXT,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT DEFAULT CURRENT_TIMESTAMP
);

-- ==============================
-- CHAT MESSAGES
-- ==============================
CREATE TABLE IF NOT EXISTS chat_messages (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    chat_id TEXT NOT NULL,
    role TEXT NOT NULL CHECK(role IN ('user', 'assistant')),
    content TEXT NOT NULL,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (chat_id)
        REFERENCES chat_sessions(id)
        ON DELETE CASCADE
);

-- ==============================
-- LONG-TERM CHAT MEMORY
-- ==============================
CREATE TABLE IF NOT EXISTS chat_memory (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    student_id INTEGER,
    guest_id TEXT,
    chat_id TEXT NOT NULL,
    memory_text TEXT NOT NULL,
    vector_id INTEGER UNIQUE,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (chat_id)
        REFERENCES chat_sessions(id)
        ON DELETE CASCADE
);

-- ==============================
-- CHAT CONTEXT
-- ==============================
CREATE TABLE IF NOT EXISTS chat_context (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    chat_id TEXT NOT NULL,
    question TEXT,
    rewritten_question TEXT,
    source_files TEXT,
    retrieved_chunks_json TEXT,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (chat_id)
        REFERENCES chat_sessions(id)
        ON DELETE CASCADE
);

-- ============================
-- INDEXES
-- ============================
CREATE INDEX IF NOT EXISTS idx_chunks_doc_lookup
ON chunks(document_id);

CREATE INDEX IF NOT EXISTS idx_chunks_store_vector
ON chunks(store_type, vector_id);

CREATE INDEX IF NOT EXISTS idx_documents_category
ON documents(category);

CREATE INDEX IF NOT EXISTS idx_documents_branch_sem_subject
ON documents(branch, semester, subject);

CREATE INDEX IF NOT EXISTS idx_documents_use_for_rag
ON documents(use_for_rag);

CREATE INDEX IF NOT EXISTS idx_search_student
ON search_history(student_id);

CREATE INDEX IF NOT EXISTS idx_search_guest
ON search_history(guest_id);

CREATE INDEX IF NOT EXISTS idx_diagrams_doc_lookup
ON diagrams(document_id);

CREATE INDEX IF NOT EXISTS idx_diagrams_page_lookup
ON diagrams(page_number);

CREATE INDEX IF NOT EXISTS idx_diagrams_vector_id
ON diagrams(vector_id);

CREATE INDEX IF NOT EXISTS idx_chat_sessions_student
ON chat_sessions(student_id);

CREATE INDEX IF NOT EXISTS idx_chat_sessions_guest
ON chat_sessions(guest_id);

CREATE INDEX IF NOT EXISTS idx_chat_messages_chat
ON chat_messages(chat_id);

CREATE INDEX IF NOT EXISTS idx_chat_memory_chat
ON chat_memory(chat_id);

CREATE INDEX IF NOT EXISTS idx_chat_context_chat
ON chat_context(chat_id);