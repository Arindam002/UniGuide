import json
from flask import Blueprint, request, jsonify, Response
from app.services.rag_service import RagService
from app.nlp.nlp_pipeline import NLPPipeline
from database.db import get_connection

chat_bp = Blueprint("chat", __name__, url_prefix="/chat")

rag_service = RagService()
nlp = NLPPipeline()


def log_search(student_id, query, intent, metadata):
    """Saves the search query to the database for analytics."""
    try:
        conn = get_connection()
        cursor = conn.cursor()
        cursor.execute(
            """
            INSERT INTO search_history (student_id, query, category, branch, semester, subject)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            (
                student_id,
                query,
                metadata.get('category'),
                metadata.get('branch'),
                metadata.get('semester'),
                metadata.get('subject')
            )
        )
        conn.commit()
        conn.close()
    except Exception as e:
        print(f"[ERROR] Failed to log search: {e}")


@chat_bp.route("/stream", methods=["POST"])
def chat_stream():
    data = request.get_json()
    raw_question = data.get("question")

    if not raw_question:
        return jsonify({"error": "No question provided"}), 400

    question, intent, marks = nlp.process_question(raw_question)

    # Optional: skip logging for now, or use a dummy student_id
    # log_search(1, raw_question, intent, {})

    def generate():
        if intent == "important_topics":
            yield f"data: {json.dumps({'answer': 'Looking up important topics for your branch...'})}\n\n"
            return

        try:
            for token in rag_service.generate_stream(question):
                yield f"data: {token}\n\n"
        except Exception as e:
            yield f"data: {json.dumps({'error': str(e)})}\n\n"

    return Response(generate(), mimetype="text/event-stream")


@chat_bp.route("/", methods=["POST"])
def chat():
    data = request.get_json()
    raw_question = data.get("question")

    if not raw_question:
        return jsonify({"error": "No question provided"}), 400

    question, intent, marks = nlp.process_question(raw_question)

    # Optional: skip logging for now, or use a dummy student_id
    # log_search(1, raw_question, intent, {})

    if intent == "important_topics":
        answer = "The 'Important Topics' feature is currently being calibrated for your syllabus."
        sources = []
    else:
        result = rag_service.ask(question)
        answer = result.get("answer", "I couldn't find a specific answer in the documents.")
        sources = result.get("sources", [])

    return jsonify({
        "answer": answer,
        "sources": sources,
        "intent": intent,
        "student_branch": None
    })


@chat_bp.route("/status", methods=["GET"])
def chat_test():
    return jsonify({
        "status": "online",
        "message": "UniGuide RAG Engine is active",
    })