import jwt
import datetime
import os
from dotenv import load_dotenv

BACKEND_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
load_dotenv(os.path.join(BACKEND_DIR, ".env"))

SECRET_KEY = os.getenv("SECRET_KEY")
if not SECRET_KEY:
    raise RuntimeError("SECRET_KEY must be configured in the environment")

# -----------------------------
# Regular JWT for login/auth
# -----------------------------
def generate_token(student_id, email=None, expire_minutes=60*24):
    """
    Generate a JWT token for a student
    """
    payload = {
        "student_id": student_id,
        "email": email,
        "token_type": "access",
        "exp": datetime.datetime.now(datetime.timezone.utc)
        + datetime.timedelta(minutes=expire_minutes)
    }
    token = jwt.encode(payload, SECRET_KEY, algorithm="HS256")
    return token

def verify_token(token):
    """
    Verify a token and return payload or None
    """
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=["HS256"])
        if payload.get("token_type") != "access":
            return None
        return payload
    except jwt.ExpiredSignatureError:
        return None
    except jwt.InvalidTokenError:
        return None


# -----------------------------
# Short-lived reset token
# -----------------------------
def generate_reset_token(student_id, expire_minutes=15):
    payload = {
        "student_id": student_id,
        "token_type": "password_reset",
        "exp": datetime.datetime.now(datetime.timezone.utc)
        + datetime.timedelta(minutes=expire_minutes)
    }
    return jwt.encode(payload, SECRET_KEY, algorithm="HS256")

def verify_reset_token(token):
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=["HS256"])
        if payload.get("token_type") != "password_reset":
            return None
        return payload
    except jwt.ExpiredSignatureError:
        return None
    except jwt.InvalidTokenError:
        return None