from flask import Flask
from flask_cors import CORS
from dotenv import load_dotenv
import os
import sys
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

# -----------------------------
# Create Flask app
# -----------------------------
def create_app():
    print(f"Database path: {get_db_path()}")
    init_db()

    # Import route modules after database initialization.
    from app.routes.items import items_bp
    from app.routes.home import home_bp
    from app.routes.chat import chat_bp
    from app.routes.students import students_bp
    from app.routes.diagram_routes import diagram_bp

    app = Flask(__name__)
    CORS(app)

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
    def health_check():
        return "UniGuide backend is alive and running!"

    return app


# -----------------------------
# Start app
# -----------------------------
app = create_app()

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
