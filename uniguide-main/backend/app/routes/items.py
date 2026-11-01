import os
from flask import Blueprint, request, jsonify, send_file, abort

items_bp = Blueprint("items", __name__)

# Base directory (D:\Uniguide\data)
BASE_DIR = os.path.dirname(os.path.dirname(os.path.dirname(__file__)))
PDF_BASE_DIR = os.path.abspath(os.path.join(BASE_DIR, "data"))


# ---------------------------
# Helper: safe path join
# ---------------------------
def safe_join(base, *paths):
    full_path = os.path.abspath(os.path.normpath(os.path.join(base, *paths)))
    base_path = os.path.abspath(base)

    if not full_path.startswith(base_path):
        return None

    return full_path


# ---------------------------
# Get Branches
# ---------------------------
@items_bp.route("/branches", methods=["GET"])
def get_branches():
    category = request.args.get("category")

    if not category:
        return jsonify({"error": "category required"}), 400

    path = safe_join(PDF_BASE_DIR, category)
    if not path or not os.path.exists(path):
        return jsonify({"error": "Category not found"}), 404

    branches = sorted([
        d for d in os.listdir(path)
        if os.path.isdir(os.path.join(path, d))
    ])

    return jsonify({"branches": branches})


# ---------------------------
# Get Semesters
# ---------------------------
@items_bp.route("/semesters", methods=["GET"])
def get_semesters():
    category = request.args.get("category")
    branch = request.args.get("branch")

    if not category or not branch:
        return jsonify({"error": "category and branch required"}), 400

    path = safe_join(PDF_BASE_DIR, category, branch)
    if not path or not os.path.exists(path):
        return jsonify({"error": "Branch not found"}), 404

    semesters = sorted([
        d for d in os.listdir(path)
        if os.path.isdir(os.path.join(path, d))
    ])

    return jsonify({"semesters": semesters})


# ---------------------------
# Get Subjects
# ---------------------------
@items_bp.route("/subjects", methods=["GET"])
def get_subjects():
    category = request.args.get("category")
    branch = request.args.get("branch")
    semester = request.args.get("semester")

    if not category or not branch or not semester:
        return jsonify({"error": "category, branch and semester required"}), 400

    path = safe_join(PDF_BASE_DIR, category, branch, semester)
    if not path or not os.path.exists(path):
        return jsonify({"error": "Semester not found"}), 404

    subjects = sorted([
        d for d in os.listdir(path)
        if os.path.isdir(os.path.join(path, d))
    ])

    return jsonify({"subjects": subjects})


# ---------------------------
# Get PDF files
# ---------------------------
@items_bp.route("/files", methods=["GET"])
def get_files():
    category = request.args.get("category")
    branch = request.args.get("branch")
    semester = request.args.get("semester")
    subject = request.args.get("subject")

    if not category or not branch or not semester or not subject:
        return jsonify({"error": "category, branch, semester and subject required"}), 400

    path = safe_join(PDF_BASE_DIR, category, branch, semester, subject)
    if not path or not os.path.exists(path):
        return jsonify({"error": "Subject not found"}), 404

    files = []
    for file in sorted(os.listdir(path)):
        if file.lower().endswith(".pdf"):
            relative_path = os.path.join(category, branch, semester, subject, file)
            files.append({
                "name": file,
                "file_path": relative_path.replace("\\", "/")
            })

    return jsonify({"files": files})


# ---------------------------
# View PDF
# ---------------------------
@items_bp.route("/view", methods=["GET"])
def view_file():
    file_path = request.args.get("file_path")

    if not file_path:
        return jsonify({"error": "file_path required"}), 400

    normalized_file_path = file_path.replace("/", os.sep).replace("\\", os.sep)
    full_path = safe_join(PDF_BASE_DIR, normalized_file_path)

    print("---- VIEW DEBUG ----")
    print("PDF_BASE_DIR:", PDF_BASE_DIR)
    print("Requested file_path:", file_path)
    print("Normalized file_path:", normalized_file_path)
    print("Resolved full_path:", full_path)
    print("File exists:", os.path.exists(full_path) if full_path else False)

    if not full_path:
        return abort(403, description="Access denied")

    if not os.path.exists(full_path):
        return abort(404, description=f"File not found: {full_path}")

    return send_file(full_path, mimetype="application/pdf")


# ---------------------------
# Download PDF
# ---------------------------
@items_bp.route("/download", methods=["GET"])
def download_file():
    file_path = request.args.get("file_path")

    if not file_path:
        return jsonify({"error": "file_path required"}), 400

    normalized_file_path = file_path.replace("/", os.sep).replace("\\", os.sep)
    full_path = safe_join(PDF_BASE_DIR, normalized_file_path)

    print("---- DOWNLOAD DEBUG ----")
    print("PDF_BASE_DIR:", PDF_BASE_DIR)
    print("Requested file_path:", file_path)
    print("Normalized file_path:", normalized_file_path)
    print("Resolved full_path:", full_path)
    print("File exists:", os.path.exists(full_path) if full_path else False)

    if not full_path:
        return abort(403, description="Access denied")

    if not os.path.exists(full_path):
        return abort(404, description=f"File not found: {full_path}")

    return send_file(full_path, as_attachment=True)