import sqlite3
from flask import Blueprint, request, jsonify
from werkzeug.security import generate_password_hash, check_password_hash
import os
from app.utils.jwt_utils import generate_token, generate_reset_token, verify_reset_token

students_bp = Blueprint("students", __name__)

# ---------------------------
# Correct Database Path
# ---------------------------
BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../"))
DB_PATH = os.path.join(BASE_DIR, "database", "uniguide.db")
import os

# Get the directory where students.py is, then go up two levels to 'backend'
BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../"))
DB_PATH = os.path.join(BASE_DIR, "database", "uniguide.db")

# Now print it once when the app starts so you can see exactly where it's looking
print(f"🚀 DATABASE LINKED AT: {DB_PATH}")
def get_connection():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn

# ---------------------------
# Signup (Updated: Branch/Year Removed)
# ---------------------------
@students_bp.route("/signup", methods=["POST"])
def signup():
    data = request.json
    name = data.get("name")
    email = data.get("email")
    password = data.get("password")

    # Only validate name, email, and password now
    if not all([name, email, password]):
        return jsonify({"error": "Missing fields"}), 400

    hashed_password = generate_password_hash(password)

    conn = get_connection()
    cursor = conn.cursor()

    try:
        # SQL query updated to match the new schema
        cursor.execute("""
            INSERT INTO students (name, email, password)
            VALUES (?, ?, ?)
        """, (name, email, hashed_password))

        conn.commit()
        student_id = cursor.lastrowid

    except sqlite3.IntegrityError:
        conn.close()
        return jsonify({"error": "Email already exists"}), 400
    except Exception as e:
        conn.close()
        return jsonify({"error": str(e)}), 500

    conn.close()
    return jsonify({
        "message": "Signup successful",
        "student_id": student_id
    }), 201

# ---------------------------
# Login (Updated: Branch/Year Removed)
# ---------------------------
@students_bp.route("/login", methods=["POST"])
def login_with_jwt():
    data = request.json
    email = data.get("email")
    password = data.get("password")

    if not email or not password:
        return jsonify({"error": "Email and password required"}), 400

    conn = get_connection()
    cursor = conn.cursor()

    # Query only existing columns
    cursor.execute(
        "SELECT id, password, name FROM students WHERE email=?",
        (email,)
    )

    row = cursor.fetchone()
    conn.close()

    if row and check_password_hash(row["password"], password):
        token = generate_token(student_id=row["id"], email=email)

        return jsonify({
            "message": "Login successful",
            "token": token,
            "student": {
                "id": row["id"],
                "name": row["name"]
                # branch and year are no longer returned here
            }
        })

    return jsonify({"error": "Invalid email or password"}), 401

# ---------------------------
# Save search history (Kept metadata for logging)
# ---------------------------
@students_bp.route("/save_search", methods=["POST"])
def save_search():
    data = request.json
    student_id = data.get("student_id")
    query = data.get("query")
    category = data.get("category")
    
    # These can be None if not applicable
    branch = data.get("branch")
    semester = data.get("semester")
    subject = data.get("subject")

    if not all([student_id, query]):
        return jsonify({"error": "Missing required fields"}), 400

    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute("""
        INSERT INTO search_history (student_id, query, category, branch, semester, subject)
        VALUES (?, ?, ?, ?, ?, ?)
    """, (student_id, query, category, branch, semester, subject))

    conn.commit()
    conn.close()
    return jsonify({"message": "Search saved successfully"})

# ---------------------------
# Get search history
# ---------------------------
@students_bp.route("/history/<int:student_id>", methods=["GET"])
def get_history(student_id):
    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute("""
        SELECT query, category, branch, semester, subject, created_at
        FROM search_history
        WHERE student_id=?
        ORDER BY created_at DESC
    """, (student_id,))

    rows = cursor.fetchall()
    conn.close()

    history = [dict(r) for r in rows]
    return jsonify({"history": history})

# ---------------------------
# Forgot/Reset Password (unchanged logic, verified paths)
# ---------------------------
@students_bp.route("/forgot_password", methods=["POST"])
def forgot_password():
    data = request.json
    email = data.get("email")

    if not email:
        return jsonify({"error": "Email is required"}), 400

    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT id FROM students WHERE email=?", (email,))
    row = cursor.fetchone()
    conn.close()

    if not row:
        return jsonify({"error": "Email not found"}), 404

    reset_token = generate_reset_token(row["id"])
    # Adjust this to your actual frontend URL later
    reset_link = f"http://localhost:3000/reset-password?token={reset_token}"

    return jsonify({
        "message": "Password reset link generated",
        "reset_link": reset_link
    })

@students_bp.route("/reset_password", methods=["POST"])
def reset_password():
    data = request.json
    token = data.get("token")
    new_password = data.get("new_password")

    if not token or not new_password:
        return jsonify({"error": "Missing token or new password"}), 400

    payload = verify_reset_token(token)
    if not payload:
        return jsonify({"error": "Invalid or expired token"}), 401

    hashed_password = generate_password_hash(new_password)
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute("UPDATE students SET password=? WHERE id=?", (hashed_password, payload["student_id"]))
    conn.commit()
    conn.close()

    return jsonify({"message": "Password reset successful"})