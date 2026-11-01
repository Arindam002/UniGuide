from flask import Flask
from flask_cors import CORS
from dotenv import load_dotenv
import logging
import os
import re
import sqlite3
import sys
from pathlib import Path
from werkzeug.middleware.proxy_fix import ProxyFix
from database.db import get_db_path, init_db

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8")

# -----------------------------
# Load environment variables
# -----------------------------
load_dotenv(os.path.join(os.path.dirname(__file__), ".env"))
import config
from app.extensions import limiter

logger = logging.getLogger(__name__)


def validate_runtime_assets():
    db_path = Path(get_db_path()).resolve()
    if not db_path.is_file():
        raise RuntimeError(
            f"Required SQLite database is missing: {db_path}. "
            "Build it locally and include it in the Space image."
        )

    try:
        connection = sqlite3.connect(f"{db_path.as_uri()}?mode=ro", uri=True)
        try:
            index_pairs = connection.execute(
                """
                SELECT DISTINCT d.domain, c.store_type
                FROM chunks c
                JOIN documents d ON d.id = c.document_id
                WHERE d.use_for_rag = 1
                ORDER BY d.domain, c.store_type
                """
            ).fetchall()
        finally:
            connection.close()
    except sqlite3.Error as exc:
        raise RuntimeError(
            f"Cannot read required SQLite database {db_path}: {exc}"
        ) from exc

    if not index_pairs:
        raise RuntimeError(
            f"No searchable RAG chunks were found in {db_path}; "
            "build the database and FAISS indexes locally first."
        )

    index_root = Path(config.VECTOR_DB_DIR) / "namespaces"
    missing_indexes = []
    for domain, store_type in index_pairs:
        domain = str(domain)
        store_type = str(store_type)
        if not re.fullmatch(r"[a-z0-9_]+", domain) or store_type not in {"books", "pyqs"}:
            raise RuntimeError(
                f"Invalid RAG index metadata in {db_path}: "
                f"domain={domain!r}, store_type={store_type!r}."
            )
        index_path = index_root / domain / f"{store_type}.faiss"
        if not index_path.is_file():
            missing_indexes.append(index_path)

    memory_index = Path(config.VECTOR_DB_DIR) / "chat_memory_index.faiss"
    if not memory_index.is_file():
        missing_indexes.append(memory_index)

    if missing_indexes:
        missing_list = ", ".join(str(path) for path in missing_indexes)
        raise RuntimeError(
            f"Required FAISS index files are missing: {missing_list}. "
            "Build them locally with run_pipeline.py and include them in the Space image."
        )

# -----------------------------
# Create Flask app
# -----------------------------
def create_app():
    try:
        validate_runtime_assets()
    except RuntimeError as exc:
        logger.critical("UniGuide startup validation failed: %s", exc)
        raise
    print(f"Database path: {get_db_path()}")
    init_db()

    # Import route modules after database initialization.
    from app.routes.items import items_bp
    from app.routes.home import home_bp
    from app.routes.chat import chat_bp
    from app.routes.students import students_bp
    from app.routes.diagram_routes import diagram_bp

    app = Flask(__name__)
    app.wsgi_app = ProxyFix(
        app.wsgi_app,
        x_for=config.PROXY_FIX_X_FOR,
        x_proto=1,
    )
    CORS(app, origins=config.CORS_ORIGINS)
    limiter.init_app(app)

    # -------------------------
    # Register blueprints
    # -------------------------
    app.register_blueprint(home_bp, url_prefix="/")
    app.register_blueprint(chat_bp, url_prefix="/chat")
    app.register_blueprint(items_bp, url_prefix="/items")
    app.register_blueprint(students_bp, url_prefix="/students")
    app.register_blueprint(diagram_bp)
    # -------------------------
    # Health check for backend
    # -------------------------
    @app.route("/health", methods=["GET"])
    @limiter.exempt
    def health_check():
        return "UniGuide backend is alive and running!"

    return app


# -----------------------------
# Start app
# -----------------------------
app = create_app()
print(f"UniGuide ready on port {config.PORT}", flush=True)

if __name__ == "__main__":
    print(f"Starting UniGuide backend on http://{config.HOST}:{config.PORT} ...\n")
    
    # Print all available routes
    print("Available routes:")
    for rule in app.url_map.iter_rules():
        methods = ','.join(rule.methods)
        print(f"{rule} -> methods: [{methods}]")
    
    # Run Flask app
    app.run(
        host=config.HOST,
        port=config.PORT,
        debug=config.DEBUG,
        use_reloader=False,
    )
