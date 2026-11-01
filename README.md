# UniGuide

UniGuide is a Flutter study app backed by a Flask Retrieval-Augmented Generation (RAG) service. The backend extracts text from academic PDFs, retrieves relevant passages, and uses Groq-hosted language models to draft study answers with source information.

## Architecture

### Document ingestion

1. Put PDFs in `backend/data/books/`, `backend/data/pyqs/`, or `backend/data/notes/`.
2. The ingestion pipeline extracts text with PyMuPDF and uses Tesseract OCR with Poppler as a fallback for low-text PDFs.
3. Books and PYQs are split into sentence-aware chunks (the main `run_pipeline.py` path uses a 1,200-character target and 200-character overlap).
4. `BAAI/bge-small-en-v1.5` creates normalized 384-dimensional embeddings. FAISS stores them in `IndexIDMap(IndexFlatL2)` indexes partitioned by corpus type and domain namespace; SQLite stores the chunk text and document metadata used to resolve vector IDs.

**Notes are not currently embedded or searched by RAG.** The current ingestion path stores their document metadata only. The file-browsing API can still list and serve PDFs from the notes directory.

### Question answering

1. Flask validates the chat request, corrects spelling, and detects intent and requested exam marks.
2. The domain router selects a namespace (`data_structures`, `databases`, `python_documentation`, or `computer_science`).
3. FAISS retrieves candidates; SQLite applies document and academic metadata filters; a cross-encoder (`cross-encoder/ms-marco-MiniLM-L-6-v2`) reranks the passages.
4. Up to four retrieved passages are truncated to 2,400 characters each, combined with the last three chat messages and relevant long-term memories, and fitted to an estimated 6,000-token prompt-plus-completion budget. If needed, the lowest-ranked prompt passage is removed; this does not change retrieval or its results.
5. Groq generates the answer. By default the backend uses `openai/gpt-oss-120b` and caps completions at 1,000 tokens. Debug logs report approximate prompt token counts using characters divided by four.

SQLite also stores users, chat history, long-term memory metadata, search history, and diagram metadata. Diagram caption/context search uses SQLite FTS5. Chat memory embeddings use a separate FAISS index.

## Technology stack

### Backend

- Python and Flask with Flask-CORS
- Groq Python SDK for chat completions
- Sentence Transformers: `BAAI/bge-small-en-v1.5` embeddings and `cross-encoder/ms-marco-MiniLM-L-6-v2` reranking
- FAISS CPU for vector indexes
- SQLite with FTS5 for document, chat, and diagram metadata
- PyMuPDF, `pypdf`, `pdf2image`, Pillow, and pytesseract for PDF extraction and OCR
- `pyspellchecker` for query spelling correction
- PyJWT for authentication tokens

Python dependency versions are not pinned in `backend/requirements.txt`; install with a Python version supported by the listed packages.

### Frontend

- Flutter / Dart (the package requires Dart SDK `>=3.1.0 <4.0.0`)
- Google Fonts: Poppins for student messages, Inter for assistant/UI text, Lora for bold key terms, and JetBrains Mono for code; font choices are centralized in `lib/theme/app_fonts.dart`
- `flutter_markdown_plus` with GitHub-flavored Markdown extensions for assistant messages, including rendered tables and styled headings, lists, and inline code. Raw HTML is not enabled in assistant Markdown.
- `flutter_highlight` for language-aware fenced code blocks, with horizontal scrolling and a copy button
- Chat conversations are stored locally; only the 10 most recently updated are retained, with older entries removed automatically.
- REST API calls to Flask; the backend also exposes an SSE-framed `/chat/stream` endpoint that sends the completed answer as a final event rather than token-by-token output.
- `API_HOST` can be supplied at Flutter build/run time. Defaults are `127.0.0.1:5000` for web/desktop and `10.0.2.2:5000` for the Android emulator.

## Setup

### Requirements

- Python 3.10 or newer and pip (use a version supported by the unpinned dependencies)
- Flutter SDK
- A Groq API key
- Tesseract OCR and Poppler for scanned or low-text PDFs; searchable PDFs can be ingested without configuring them

### Backend

From the repository root:

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

Create `backend/.env`:

```env
SECRET_KEY=replace_with_a_long_random_secret
GROQ_API_KEY=your_groq_api_key
GROQ_MODEL=openai/gpt-oss-120b
HOST=0.0.0.0
PORT=5000
FLASK_DEBUG=false

# Optional: set these only when the tools are not on PATH.
TESSERACT_PATH=C:\Program Files\Tesseract-OCR\tesseract.exe
POPPLER_PATH=C:\path\to\poppler\Library\bin
```

`SECRET_KEY` is required when the student routes load. `GROQ_API_KEY` is required for successful LLM calls. If `GROQ_MODEL` is omitted, the backend defaults to `openai/gpt-oss-120b`. The generator uses a fixed 1,000-token completion limit.

Initialize the database and ingest PDFs:

```powershell
python init_db.py
# Place files under data\books or data\pyqs, then:
python run_pipeline.py
```

Start the API:

```powershell
python run.py
```

Run the focused backend tests from `backend/`:

```powershell
python -m unittest discover -s tests -v
```

The server defaults to `http://localhost:5000`. The SQLite database is stored at `backend/database/uniguide.db`; namespaced FAISS indexes are stored under `backend/app/vector_db/faiss_index/`.

### Frontend

From the repository root:

```powershell
flutter pub get
flutter run -d chrome
```

For an Android emulator:

```powershell
flutter run
```

For a physical device or a backend on a different host, pass the reachable host and port:

```powershell
flutter run --dart-define=API_HOST=192.168.1.10:5000
```

The frontend defaults are defined in `lib/core/app_config.dart`.

## API endpoints

| Method | Endpoint | Purpose |
|---|---|---|
| `GET` | `/health` | Backend health check |
| `POST` | `/chat/` | Complete chat answer and metadata as JSON |
| `POST` | `/chat/stream` | SSE-framed response containing the completed answer payload |
| `GET` | `/chat/status` | Chat service and memory-index status |
| `POST` | `/students/signup` | Register a student |
| `POST` | `/students/login` | Authenticate a student |
| `GET` | `/items/branches` | List branches for a corpus category |
| `GET` | `/items/semesters` | List semesters for a branch |
| `GET` | `/items/subjects` | List subjects for a branch and semester |
| `GET` | `/diagrams/view/<id>` | View an extracted diagram |

## Data and generated files

- Add source PDFs under `backend/data/`.
- The SQLite database is `backend/database/uniguide.db`.
- FAISS indexes and extracted diagram images are generated under `backend/app/vector_db/` and `backend/extracted_diagrams/`.
- Do not commit `.env` or API credentials.

## License

MIT License.
