from functools import wraps
from flask import request, jsonify
from app.utils.jwt_utils import verify_token
from database.db import get_connection

def token_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        token = None
        
        # 1. Extract Bearer Token from the Authorization header
        auth_header = request.headers.get("Authorization")
        if auth_header:
            parts = auth_header.split(" ")
            if len(parts) == 2 and parts[0] == "Bearer":
                token = parts[1]

        if not token:
            return jsonify({"error": "Token is missing"}), 401

        # 2. Verify Token via jwt_utils (returns the payload/student_id)
        payload = verify_token(token)
        if not payload:
            return jsonify({"error": "Invalid or expired token"}), 401

        # 3. Fetch Student Context (Branch and Semester removed)
        try:
            conn = get_connection()
            cursor = conn.cursor()
            
            # Simplified query: only fetch ID and Name
            cursor.execute(
                "SELECT id, name, email FROM students WHERE id = ?", 
                (payload["student_id"],)
            )
            student = cursor.fetchone()
            conn.close()

            if not student:
                return jsonify({"error": "Student account not found"}), 404
            
            # Convert the sqlite3.Row to a dictionary
            # We explicitly set branch/semester to None so the RAG service 
            # knows to search everything by default.
            current_student = dict(student)
            current_student["branch"] = None
            current_student["semester"] = None
            
        except Exception as e:
            return jsonify({"error": f"Database error: {str(e)}"}), 500

        # 4. Pass the student dictionary to the route function
        return f(current_student, *args, **kwargs)
        
    return decorated