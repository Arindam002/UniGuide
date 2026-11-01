from flask import Flask
from flask_cors import CORS
from dotenv import load_dotenv
import os

# -----------------------------
# Load environment variables
# -----------------------------
load_dotenv()

# -----------------------------
# Import routes
# -----------------------------
from app.routes.items import items_bp
from app.routes.home import home_bp
from app.routes.chat import chat_bp
from app.routes.students import students_bp

# -----------------------------
# Create Flask app
# -----------------------------
def create_app():
    app = Flask(__name__)
    CORS(app)

    # -------------------------
    # Register blueprints
    # -------------------------
    app.register_blueprint(home_bp, url_prefix="/")
    app.register_blueprint(chat_bp, url_prefix="/chat")
    app.register_blueprint(items_bp, url_prefix="/items")
    app.register_blueprint(students_bp, url_prefix="/students")

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
    print("Starting UniGuide backend on http://127.0.0.1:5000 ...\n")
    
    # Print all available routes
    print("Available routes:")
    for rule in app.url_map.iter_rules():
        methods = ','.join(rule.methods)
        print(f"{rule} -> methods: [{methods}]")
    
    # Run Flask app
    app.run(host="0.0.0.0", port=5000, debug=True)