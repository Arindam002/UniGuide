PRAGMA foreign_keys = ON;

-- ============================
-- DROP TABLES IN SAFE ORDER
-- ============================
DROP TABLE IF EXISTS chunks;
DROP TABLE IF EXISTS search_history;
DROP TABLE IF EXISTS documents;
DROP TABLE IF EXISTS students;

-- ============================
-- DOCUMENTS (PDF metadata)
-- ============================
CREATE TABLE documents (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    file_path TEXT UNIQUE NOT NULL,
    file_hash TEXT UNIQUE NOT NULL,
    category TEXT NOT NULL,          -- books / notes / pyqs
    branch TEXT,                     -- CSE / ECE
    semester TEXT,                   -- 1-8
    subject TEXT,                    -- COA / DAA
    total_pages INTEGER,
    content TEXT,
    use_for_rag INTEGER DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================
-- RAG CHUNKS (Granular text segments)
-- ============================
CREATE TABLE chunks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    document_id INTEGER NOT NULL,
    chunk_text TEXT NOT NULL,
    vector_id INTEGER UNIQUE,
    chunk_index INTEGER NOT NULL,

    FOREIGN KEY (document_id)
        REFERENCES documents(id)
        ON DELETE CASCADE
);

CREATE UNIQUE INDEX idx_unique_chunk ON chunks(document_id, chunk_index);

-- ============================
-- STUDENTS
-- ============================
CREATE TABLE students (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    password TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================
-- SEARCH HISTORY
-- ============================
CREATE TABLE search_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    student_id INTEGER NOT NULL,
    query TEXT NOT NULL,
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
-- INDEXES
-- ============================

-- Join performance: Linking chunks to metadata during RAG retrieval
CREATE INDEX idx_chunks_doc_lookup ON chunks(document_id);

-- Optional: useful if you query by vector_id often
CREATE INDEX idx_chunks_vector_id ON chunks(vector_id);

-- Activity tracking
CREATE INDEX idx_search_student ON search_history(student_id);