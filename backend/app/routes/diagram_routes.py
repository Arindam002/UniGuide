import os
from pathlib import Path, PurePosixPath
from flask import Blueprint, jsonify, send_file
from database.db import get_connection

diagram_bp = Blueprint("diagram_bp", __name__, url_prefix="/diagrams")
BACKEND_DIR = Path(__file__).resolve().parents[2]


def _resolve_diagram_path(image_path):
    if not image_path or os.path.isfile(image_path):
        return image_path

    path_parts = PurePosixPath(str(image_path).replace("\\", "/")).parts
    try:
        diagrams_index = next(
            index
            for index, part in enumerate(path_parts)
            if part.lower() == "extracted_diagrams"
        )
    except StopIteration:
        return image_path

    container_path = BACKEND_DIR.joinpath(*path_parts[diagrams_index:])
    return str(container_path) if container_path.is_file() else image_path


@diagram_bp.route("/view/<int:diagram_id>", methods=["GET"])
def view_diagram(diagram_id):
    conn = None
    try:
        conn = get_connection()
        cursor = conn.cursor()

        cursor.execute(
            """
            SELECT
                d.id,
                d.image_path,
                d.caption,
                d.page_number,
                d.document_id,
                doc.name,
                doc.category
            FROM diagrams d
            JOIN documents doc ON d.document_id = doc.id
            WHERE d.id = ?
              AND doc.category = 'books'
            """,
            (diagram_id,)
        )
        row = cursor.fetchone()

        if not row:
            return jsonify({"error": "Diagram not found"}), 404

        _, image_path, caption, page_number, document_id, document_name, category = row
        image_path = _resolve_diagram_path(image_path)

        if not image_path or not os.path.exists(image_path):
            return jsonify({
                "error": "Diagram file not found on disk",
                "diagram_id": diagram_id,
                "document_id": document_id,
                "document_name": document_name,
                "image_path": image_path
            }), 404

        ext = os.path.splitext(image_path)[1].lower()
        mime_map = {
            ".png": "image/png",
            ".jpg": "image/jpeg",
            ".jpeg": "image/jpeg",
            ".webp": "image/webp",
            ".bmp": "image/bmp",
            ".gif": "image/gif"
        }
        mimetype = mime_map.get(ext, "application/octet-stream")

        return send_file(
            image_path,
            mimetype=mimetype,
            as_attachment=False,
            download_name=os.path.basename(image_path)
        )

    except Exception as e:
        return jsonify({"error": str(e)}), 500

    finally:
        if conn:
            conn.close()


@diagram_bp.route("/meta/<int:diagram_id>", methods=["GET"])
def diagram_meta(diagram_id):
    conn = None
    try:
        conn = get_connection()
        cursor = conn.cursor()

        cursor.execute(
            """
            SELECT
                d.id,
                d.document_id,
                d.page_number,
                d.image_path,
                d.caption,
                d.context_text,
                doc.name,
                doc.category,
                doc.subject,
                doc.branch,
                doc.semester
            FROM diagrams d
            JOIN documents doc ON d.document_id = doc.id
            WHERE d.id = ?
              AND doc.category = 'books'
            """,
            (diagram_id,)
        )
        row = cursor.fetchone()

        if not row:
            return jsonify({"error": "Diagram not found"}), 404

        return jsonify({
            "id": row[0],
            "document_id": row[1],
            "page_number": row[2],
            "image_path": _resolve_diagram_path(row[3]),
            "caption": row[4],
            "context_text": row[5],
            "document_name": row[6],
            "category": row[7],
            "subject": row[8],
            "branch": row[9],
            "semester": row[10],
            "image_url": f"/diagrams/view/{row[0]}"
        })

    except Exception as e:
        return jsonify({"error": str(e)}), 500

    finally:
        if conn:
            conn.close()


@diagram_bp.route("/document/<int:document_id>", methods=["GET"])
def diagrams_by_document(document_id):
    conn = None
    try:
        conn = get_connection()
        cursor = conn.cursor()

        cursor.execute(
            """
            SELECT
                d.id,
                d.page_number,
                d.caption,
                d.image_path,
                doc.name,
                doc.category,
                doc.subject,
                doc.branch,
                doc.semester
            FROM diagrams d
            JOIN documents doc ON d.document_id = doc.id
            WHERE d.document_id = ?
              AND doc.category = 'books'
            ORDER BY d.page_number ASC, d.id ASC
            """,
            (document_id,)
        )
        rows = cursor.fetchall()

        if not rows:
            return jsonify({
                "document_id": document_id,
                "diagrams": []
            })

        diagrams = []
        for row in rows:
            diagrams.append({
                "id": row[0],
                "page_number": row[1],
                "caption": row[2],
                "image_path": _resolve_diagram_path(row[3]),
                "document_name": row[4],
                "category": row[5],
                "subject": row[6],
                "branch": row[7],
                "semester": row[8],
                "image_url": f"/diagrams/view/{row[0]}"
            })

        return jsonify({
            "document_id": document_id,
            "document_name": rows[0][4],
            "category": rows[0][5],
            "subject": rows[0][6],
            "branch": rows[0][7],
            "semester": rows[0][8],
            "total_diagrams": len(diagrams),
            "diagrams": diagrams
        })

    except Exception as e:
        return jsonify({"error": str(e)}), 500

    finally:
        if conn:
            conn.close()