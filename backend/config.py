import os

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

DATA_DIR = os.path.join(BASE_DIR, "data")
VECTOR_DB_DIR = os.path.join(BASE_DIR, "app", "vector_db", "faiss_index")

BOOKS_DIR = os.path.join(DATA_DIR, "books")
NOTES_DIR = os.path.join(DATA_DIR, "notes")
PYQ_DIR = os.path.join(DATA_DIR, "pyqs")

DEBUG = os.getenv("FLASK_DEBUG", "false").strip().lower() in {"1", "true", "yes"}
HOST = os.getenv("HOST", "0.0.0.0")
PORT = int(os.getenv("PORT", "7860"))
SECRET_KEY = os.getenv("SECRET_KEY")
GROQ_API_KEY = os.getenv("GROQ_API_KEY")
GROQ_MODEL = os.getenv("GROQ_MODEL", "openai/gpt-oss-120b")
PASSWORD_RESET_URL = os.getenv(
	"PASSWORD_RESET_URL",
	"http://localhost:3000/reset-password",
)
CORS_ORIGINS = tuple(
	origin.strip().rstrip("/")
	for origin in os.getenv(
		"CORS_ORIGINS",
		"http://localhost:3000,http://127.0.0.1:3000",
	).split(",")
	if origin.strip()
)

RATE_LIMIT_DEFAULT = os.getenv("RATE_LIMIT_DEFAULT", "60 per hour")
CHAT_RATE_LIMIT_PER_MINUTE = int(
	os.getenv("CHAT_RATE_LIMIT_PER_MINUTE", "10")
)
CHAT_RATE_LIMIT_PER_DAY = int(os.getenv("CHAT_RATE_LIMIT_PER_DAY", "100"))
RATE_LIMIT_STORAGE_URI = os.getenv("RATE_LIMIT_STORAGE_URI", "memory://")
PROXY_FIX_X_FOR = int(os.getenv("PROXY_FIX_X_FOR", "1"))
DISABLE_FILE_DOWNLOADS = (
	os.getenv("DISABLE_FILE_DOWNLOADS", "false").strip().lower()
	in {"1", "true", "yes", "on"}
)