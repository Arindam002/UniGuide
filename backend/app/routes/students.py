import sqlite3
from flask import Blueprint, request, jsonify
from werkzeug.security import generate_password_hash, check_password_hash
from app.utils.jwt_utils import generate_token, generate_reset_token, verify_reset_token
from database.db import get_connection

students_bp = Blueprint("students", __name__)

def _request_data():
    data = request.get_json(silent=True)
    return data if isinstance(data, dict) else None


# ---------------------------
# Signup
# ---------------------------
@students_bp.route("/signup", methods=["POST"])
def signup():
    data = _request_data()
    if data is None:
        return jsonify({"error": "A JSON object is required"}), 400

    name = data.get("name")
    email = data.get("email")
    password = data.get("password")

    if not all(
        isinstance(value, str) and value.strip()
        for value in (name, email, password)
    ):
        return jsonify({"error": "Missing fields"}), 400

    name = name.strip()
    email = email.strip()
    hashed_password = generate_password_hash(password)

    conn = get_connection()
    cursor = conn.cursor()

    try:
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
# Login
# ---------------------------
@students_bp.route("/login", methods=["POST"])
def login_with_jwt():
    data = _request_data()
    if data is None:
        return jsonify({"error": "A JSON object is required"}), 400

    email = data.get("email")
    password = data.get("password")
    guest_id = data.get("guest_id") 

    if (
        not isinstance(email, str)
        or not email.strip()
        or not isinstance(password, str)
        or not password
    ):
        return jsonify({"error": "Email and password required"}), 400

    conn = get_connection()
    cursor = conn.cursor()

    try:
        cursor.execute(
            "SELECT id, password, name FROM students WHERE email=?",
            (email.strip(),)
        )
        row = cursor.fetchone()

        if not row or not check_password_hash(row["password"], password):
            return jsonify({"error": "Invalid email or password"}), 401

        if isinstance(guest_id, str) and guest_id.strip():
            cursor.execute("""
                UPDATE search_history
                SET student_id = ?, guest_id = NULL
                WHERE guest_id = ?
            """, (row["id"], guest_id.strip()))
            conn.commit()

        token = generate_token(student_id=row["id"], email=email.strip())
        return jsonify({
            "message": "Login successful",
            "token": token,
            "student": {
                "id": row["id"],
                "name": row["name"]
            }
        })
    finally:
        conn.close()


# ---------------------------
# Save search history
# Supports search history associated with student_id or guest_id.
# ---------------------------
@students_bp.route("/save_search", methods=["POST"])
def save_search():
    data = _request_data()
    if data is None:
        return jsonify({"error": "A JSON object is required"}), 400

    student_id = data.get("student_id")
    guest_id = data.get("guest_id")

    question = data.get("question")
    answer = data.get("answer", "")

    category = data.get("category")
    branch = data.get("branch")
    semester = data.get("semester")
    subject = data.get("subject")

    if not isinstance(question, str) or not question.strip():
        return jsonify({"error": "Question is required"}), 400

    if student_id is not None and (
        isinstance(student_id, bool)
        or not isinstance(student_id, int)
        or student_id <= 0
    ):
        return jsonify({"error": "student_id must be an integer"}), 400

    if guest_id is not None and not isinstance(guest_id, str):
        return jsonify({"error": "guest_id must be a string"}), 400

    if not student_id and (
        not isinstance(guest_id, str) or not guest_id.strip()
    ):
        return jsonify({"error": "student_id or guest_id is required"}), 400

    if not isinstance(answer, str):
        return jsonify({"error": "answer must be a string"}), 400

    for field_name, value in (
        ("category", category),
        ("branch", branch),
        ("semester", semester),
        ("subject", subject),
    ):
        if value is not None and not isinstance(value, str):
            return jsonify({"error": f"{field_name} must be a string"}), 400

    if isinstance(guest_id, str):
        guest_id = guest_id.strip() or None

    conn = get_connection()
    cursor = conn.cursor()

    try:
        cursor.execute("""
            INSERT INTO search_history (
                student_id, guest_id, query, answer, category, branch, semester, subject
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            student_id,
            guest_id,
            question,
            answer,
            category,
            branch,
            semester,
            subject
        ))
        conn.commit()

        return jsonify({"message": "Search saved successfully"}), 200

    except Exception as e:
        conn.rollback()
        return jsonify({"error": str(e)}), 500

    finally:
        conn.close()


# ---------------------------
# Get search history
# Use:
# /students/history?student_id=1
# or
# /students/history?guest_id=abc-123
# ---------------------------
@students_bp.route("/history", methods=["GET"])
def get_history():
    student_id = request.args.get("student_id", type=int)
    guest_id = request.args.get("guest_id", type=str)

    if not student_id and not guest_id:
        return jsonify({"error": "student_id or guest_id is required"}), 400

    conn = get_connection()
    cursor = conn.cursor()

    try:
        if student_id:
            cursor.execute("""
                SELECT id, query AS question, answer, category, branch, semester, subject,
                       created_at AS searched_at
                FROM search_history
                WHERE student_id = ?
                ORDER BY searched_at DESC, id DESC
            """, (student_id,))
        else:
            cursor.execute("""
                SELECT id, query AS question, answer, category, branch, semester, subject,
                       created_at AS searched_at
                FROM search_history
                WHERE guest_id = ?
                ORDER BY searched_at DESC, id DESC
            """, (guest_id,))

        rows = cursor.fetchall()
        history = [dict(r) for r in rows]

        return jsonify({"history": history}), 200

    except Exception as e:
        return jsonify({"error": str(e)}), 500

    finally:
        conn.close()


# ---------------------------
# Optional: Transfer guest history after login
# ---------------------------
@students_bp.route("/transfer_guest_history", methods=["POST"])
def transfer_guest_history():
    data = _request_data()
    if data is None:
        return jsonify({"error": "A JSON object is required"}), 400
    student_id = data.get("student_id")
    guest_id = data.get("guest_id")

    if (
        isinstance(student_id, bool)
        or not isinstance(student_id, int)
        or student_id <= 0
        or not isinstance(guest_id, str)
        or not guest_id.strip()
    ):
        return jsonify({"error": "student_id and guest_id are required"}), 400

    conn = get_connection()
    cursor = conn.cursor()

    try:
        cursor.execute("""
            UPDATE search_history
            SET student_id = ?, guest_id = NULL
            WHERE guest_id = ?
        """, (student_id, guest_id.strip()))
        conn.commit()

        return jsonify({"message": "Guest history transferred successfully"}), 200

    except Exception as e:
        conn.rollback()
        return jsonify({"error": str(e)}), 500

    finally:
        conn.close()


# ---------------------------
# Forgot Password
# ---------------------------
@students_bp.route("/forgot_password", methods=["POST"])
def forgot_password():
    data = _request_data()
    if data is None:
        return jsonify({"error": "A JSON object is required"}), 400
    email = data.get("email")

    if not isinstance(email, str) or not email.strip():
        return jsonify({"error": "Email is required"}), 400

    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT id FROM students WHERE email=?", (email.strip(),))
    row = cursor.fetchone()
    conn.close()

    if not row:
        return jsonify({"error": "Email not found"}), 404

    reset_token = generate_reset_token(row["id"])
    reset_link = f"http://localhost:3000/reset-password?token={reset_token}"

    return jsonify({
        "message": "Password reset link generated",
        "reset_link": reset_link
    })


# ---------------------------
# Reset Password
# ---------------------------
@students_bp.route("/reset_password", methods=["POST"])
def reset_password():
    data = _request_data()
    if data is None:
        return jsonify({"error": "A JSON object is required"}), 400
    token = data.get("token")
    new_password = data.get("new_password")

    if (
        not isinstance(token, str)
        or not token
        or not isinstance(new_password, str)
        or not new_password
    ):
        return jsonify({"error": "Missing token or new password"}), 400

    payload = verify_reset_token(token)
    if not payload:
        return jsonify({"error": "Invalid or expired token"}), 401

    hashed_password = generate_password_hash(new_password)
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute(
        "UPDATE students SET password=? WHERE id=?",
        (hashed_password, payload["student_id"])
    )
    conn.commit()
    conn.close()

    return jsonify({"message": "Password reset successful"})

@students_bp.route("/history/delete/<int:history_id>", methods=["DELETE"])
def delete_history_item(history_id):
    student_id = request.args.get("student_id", type=int)
    guest_id = request.args.get("guest_id", type=str)

    if not student_id and not guest_id:
        return jsonify({"error": "student_id or guest_id is required"}), 400

    conn = get_connection()
    cursor = conn.cursor()

    try:
        if student_id:
            cursor.execute("""
                DELETE FROM search_history
                WHERE id = ? AND student_id = ?
            """, (history_id, student_id))
        else:
            cursor.execute("""
                DELETE FROM search_history
                WHERE id = ? AND guest_id = ?
            """, (history_id, guest_id))

        conn.commit()

        if cursor.rowcount == 0:
            return jsonify({"error": "History item not found"}), 404

        return jsonify({"message": "History item deleted successfully"}), 200

    except Exception as e:
        conn.rollback()
        return jsonify({"error": str(e)}), 500

    finally:
        conn.close()
