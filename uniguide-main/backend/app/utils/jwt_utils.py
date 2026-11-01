import jwt
import datetime
import os

# Load secret from environment variable if you want
SECRET_KEY = os.getenv("SECRET_KEY", "a8V9s!3kL#1pX2bR7qZ@6mN4wY0eH^tG")  # change to strong secret

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
        "exp": datetime.datetime.utcnow() + datetime.timedelta(minutes=expire_minutes)
    }
    token = jwt.encode(payload, SECRET_KEY, algorithm="HS256")
    return token

def verify_token(token):
    """
    Verify a token and return payload or None
    """
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=["HS256"])
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
        "exp": datetime.datetime.utcnow() + datetime.timedelta(minutes=expire_minutes)
    }
    return jwt.encode(payload, SECRET_KEY, algorithm="HS256")

def verify_reset_token(token):
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=["HS256"])
        return payload
    except jwt.ExpiredSignatureError:
        return None
    except jwt.InvalidTokenError:
        return None