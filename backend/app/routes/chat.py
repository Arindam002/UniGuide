import json
from flask import Blueprint, request, jsonify, Response

from app.services.rag_service import RagService
from app.nlp.nlp_pipeline import NLPPipeline
from app.memory import chat_memory
from app.memory.chat_memory_vector_store import ChatMemoryVectorStore
from database.db import get_connection


chat_bp = Blueprint("chat", __name__, url_prefix="/chat")

rag_service = RagService()
nlp = NLPPipeline()
memory_vector_store = ChatMemoryVectorStore()


def log_search(question, answer, intent, metadata, student_id=None, guest_id=None):
    conn = None

    try:
        conn = get_connection()
        cursor = conn.cursor()

        category = metadata.get("category") if metadata else None
        branch = metadata.get("branch") if metadata else None
        semester = metadata.get("semester") if metadata else None
        subject = metadata.get("subject") if metadata else None

        valid_student_id = None

        if student_id is not None:
            cursor.execute(
                "SELECT id FROM students WHERE id = ?",
                (student_id,),
            )
            existing_student = cursor.fetchone()

            if existing_student:
                valid_student_id = student_id

        guest_id_to_use = None if valid_student_id is not None else guest_id

        cursor.execute(
            """
            INSERT INTO search_history (
                student_id,
                guest_id,
                query,
                answer,
                category,
                branch,
                semester,
                subject
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                valid_student_id,
                guest_id_to_use,
                question,
                answer or "",
                category,
                branch,
                semester,
                subject,
            ),
        )

        conn.commit()

    except Exception as e:
        print(f"[ERROR] Failed to log search: {e}")

    finally:
        if conn:
            conn.close()


def save_chat_as_long_term_memory(chat_id, student_id=None, guest_id=None):
    """
    Save long-term memory only after enough conversation.
    Saves at 6, 12, 18... messages.
    """

    try:
        if not chat_id:
            return

        messages = chat_memory.get_chat_messages(chat_id)

        if len(messages) < 6:
            return

        if len(messages) % 6 != 0:
            return

        memory_text = chat_memory.build_chat_summary_text(
            chat_id=chat_id,
            max_messages=12,
        )

        if not memory_text or len(memory_text.strip()) < 100:
            return

        memory_id = chat_memory.save_long_term_memory(
            chat_id=chat_id,
            memory_text=memory_text,
            student_id=student_id,
            guest_id=guest_id,
            vector_id=None,
        )

        if memory_id is None:
            return

        vector_id = memory_vector_store.add_memory(memory_text)

        if vector_id is not None:
            chat_memory.update_memory_vector_id(
                memory_id=memory_id,
                vector_id=vector_id,
            )

        print(f"[MEMORY] Long-term memory saved for chat_id: {chat_id}")

    except Exception as e:
        print(f"[MEMORY ERROR] Failed to save long-term memory: {e}")


def prepare_chat_context(data):
    raw_question = data.get("question")
    student_id = data.get("student_id")
    guest_id = data.get("guest_id")

    # Accept both possible frontend keys
    chat_id = data.get("chat_id") or data.get("backend_chat_id")

    print(f"[CHAT DEBUG] Incoming chat_id: {chat_id}")
    print(f"[CHAT DEBUG] Incoming student_id: {student_id}")
    print(f"[CHAT DEBUG] Incoming guest_id: {guest_id}")

    if not isinstance(raw_question, str) or not raw_question.strip():
        return None, jsonify({"error": "No question provided"}), 400

    if student_id is not None and (
        isinstance(student_id, bool)
        or not isinstance(student_id, int)
        or student_id <= 0
    ):
        return None, jsonify({"error": "student_id must be an integer"}), 400

    if guest_id is not None and not isinstance(guest_id, str):
        return None, jsonify({"error": "guest_id must be a string"}), 400

    if isinstance(guest_id, str):
        guest_id = guest_id.strip() or None

    if chat_id is not None and not isinstance(chat_id, str):
        return None, jsonify({"error": "chat_id must be a string"}), 400

    if isinstance(chat_id, str):
        chat_id = chat_id.strip() or None

    raw_question = raw_question.strip()
    if not student_id and not guest_id:
        return None, jsonify({"error": "student_id or guest_id is required"}), 400

    # If frontend failed to send chat_id, reuse latest session for same user/guest
    if not chat_id:
        existing_sessions = chat_memory.get_chat_sessions(
            student_id=student_id,
            guest_id=guest_id,
        )

        if existing_sessions:
            chat_id = existing_sessions[0]["chat_id"]
            print(f"[CHAT DEBUG] Reusing latest chat_id: {chat_id}")

    chat_id = chat_memory.ensure_chat_session(
        chat_id=chat_id,
        student_id=student_id,
        guest_id=guest_id,
        title=raw_question[:60],
    )

    print(f"[CHAT DEBUG] Final chat_id used: {chat_id}")

    history = chat_memory.load_recent_messages(
        chat_id=chat_id,
        limit=8,
    )

    return {
        "raw_question": raw_question,
        "student_id": student_id,
        "guest_id": guest_id,
        "chat_id": chat_id,
        "history": history,
        "branch": data.get("branch"),
        "semester": data.get("semester"),
        "subject": data.get("subject"),
    }, None, None

@chat_bp.route("/stream", methods=["POST"])
def chat_stream():
    data = request.get_json(silent=True)
    if not isinstance(data, dict):
        return jsonify({"error": "A JSON object is required"}), 400

    context, error_response, status_code = prepare_chat_context(data)

    if error_response:
        return error_response, status_code

    raw_question = context["raw_question"]
    student_id = context["student_id"]
    guest_id = context["guest_id"]
    chat_id = context["chat_id"]
    history = context["history"]
    branch = context["branch"]
    semester = context["semester"]
    subject = context["subject"]

    question, intent, marks = nlp.process_question(raw_question)

    def generate():
        full_answer = ""

        try:
            if rag_service.generator.is_small_talk(question):
                answer = rag_service.generator.small_talk_response(question)
                full_answer = answer

                chat_memory.save_message(chat_id, "user", raw_question)
                chat_memory.save_message(chat_id, "assistant", answer)
                save_chat_as_long_term_memory(chat_id, student_id, guest_id)

                payload = json.dumps({
                    "chat_id": chat_id,
                    "answer": answer,
                    "sources": [],
                    "book_sources": [],
                    "pyq_sources": [],
                    "diagrams": [],
                    "subject": None,
                    "retrieval_category": None,
                    "intent": "small_talk",
                })

                yield f"data: {payload}\n\n"

                log_search(
                    question=raw_question,
                    answer=full_answer,
                    intent="small_talk",
                    metadata={
                        "category": None,
                        "branch": branch,
                        "semester": semester,
                        "subject": subject,
                    },
                    student_id=student_id,
                    guest_id=guest_id,
                )

                return

            if intent == "important_topics":
                answer = "The 'Important Topics' feature is currently being calibrated for your syllabus."
                full_answer = answer

                chat_memory.save_message(chat_id, "user", raw_question)
                chat_memory.save_message(chat_id, "assistant", answer)
                save_chat_as_long_term_memory(chat_id, student_id, guest_id)

                payload = json.dumps({
                    "chat_id": chat_id,
                    "answer": answer,
                    "sources": [],
                    "book_sources": [],
                    "pyq_sources": [],
                    "diagrams": [],
                    "subject": None,
                    "retrieval_category": None,
                    "intent": "important_topics",
                })

                yield f"data: {payload}\n\n"

                log_search(
                    question=raw_question,
                    answer=full_answer,
                    intent="important_topics",
                    metadata={
                        "category": None,
                        "branch": branch,
                        "semester": semester,
                        "subject": subject,
                    },
                    student_id=student_id,
                    guest_id=guest_id,
                )

                return

            result = rag_service.ask(
                question=question,
                branch=branch,
                semester=semester,
                subject=subject,
                marks=marks,
                chat_history=history,
                student_id=student_id,
                guest_id=guest_id,
                chat_id=chat_id,
            )

            answer = result.get(
                "answer",
                "I couldn't find a specific answer in the documents.",
            )

            sources = result.get("sources", [])
            book_sources = result.get("book_sources", [])
            pyq_sources = result.get("pyq_sources", [])
            diagrams = result.get("diagrams", [])
            detected_subject = result.get("subject")
            retrieval_category = result.get("retrieval_category")
            domain = result.get("domain")

            full_answer = answer

            chat_memory.save_message(chat_id, "user", raw_question)
            chat_memory.save_message(chat_id, "assistant", answer)
            save_chat_as_long_term_memory(chat_id, student_id, guest_id)

            payload = json.dumps({
                "chat_id": chat_id,
                "answer": answer,
                "sources": sources,
                "book_sources": book_sources,
                "pyq_sources": pyq_sources,
                "diagrams": diagrams,
                "subject": detected_subject,
                "retrieval_category": retrieval_category,
                "domain": domain,
                "intent": intent,
            })

            yield f"data: {payload}\n\n"

            log_search(
                question=raw_question,
                answer=full_answer,
                intent=intent,
                metadata={
                    "category": retrieval_category,
                    "branch": branch,
                    "semester": semester,
                    "subject": detected_subject or subject,
                },
                student_id=student_id,
                guest_id=guest_id,
            )

        except Exception as e:
            print(f"[ERROR] Chat stream failed: {e}")
            yield f"data: {json.dumps({'error': str(e)})}\n\n"

    return Response(generate(), mimetype="text/event-stream")


@chat_bp.route("/", methods=["POST"])
def chat():
    data = request.get_json(silent=True)
    if not isinstance(data, dict):
        return jsonify({"error": "A JSON object is required"}), 400

    context, error_response, status_code = prepare_chat_context(data)

    if error_response:
        return error_response, status_code

    raw_question = context["raw_question"]
    student_id = context["student_id"]
    guest_id = context["guest_id"]
    chat_id = context["chat_id"]
    history = context["history"]
    branch = context["branch"]
    semester = context["semester"]
    subject = context["subject"]

    question, intent, marks = nlp.process_question(raw_question)

    try:
        if rag_service.generator.is_small_talk(question):
            answer = rag_service.generator.small_talk_response(question)
            sources = []
            book_sources = []
            pyq_sources = []
            diagrams = []
            final_intent = "small_talk"
            detected_subject = None
            retrieval_category = None
            domain = None

        elif intent == "important_topics":
            answer = "The 'Important Topics' feature is currently being calibrated for your syllabus."
            sources = []
            book_sources = []
            pyq_sources = []
            diagrams = []
            final_intent = "important_topics"
            detected_subject = None
            retrieval_category = None
            domain = None

        else:
            result = rag_service.ask(
                question=question,
                branch=branch,
                semester=semester,
                subject=subject,
                marks=marks,
                chat_history=history,
                student_id=student_id,
                guest_id=guest_id,
                chat_id=chat_id,
            )

            answer = result.get(
                "answer",
                "I couldn't find a specific answer in the documents.",
            )

            sources = result.get("sources", [])
            book_sources = result.get("book_sources", [])
            pyq_sources = result.get("pyq_sources", [])
            diagrams = result.get("diagrams", [])
            detected_subject = result.get("subject")
            retrieval_category = result.get("retrieval_category")
            domain = result.get("domain")
            final_intent = intent

        chat_memory.save_message(chat_id, "user", raw_question)
        chat_memory.save_message(chat_id, "assistant", answer)
        save_chat_as_long_term_memory(chat_id, student_id, guest_id)

        log_search(
            question=raw_question,
            answer=answer,
            intent=final_intent,
            metadata={
                "category": retrieval_category,
                "branch": branch,
                "semester": semester,
                "subject": detected_subject or subject,
            },
            student_id=student_id,
            guest_id=guest_id,
        )

        return jsonify({
            "chat_id": chat_id,
            "answer": answer,
            "sources": sources,
            "book_sources": book_sources,
            "pyq_sources": pyq_sources,
            "diagrams": diagrams,
            "subject": detected_subject,
            "retrieval_category": retrieval_category,
            "domain": domain,
            "intent": final_intent,
        })

    except Exception as e:
        print(f"[ERROR] Chat route failed: {e}")

        return jsonify({
            "error": str(e),
            "message": "Chat request failed",
        }), 500


@chat_bp.route("/status", methods=["GET"])
def chat_test():
    return jsonify({
        "status": "online",
        "message": "UniGuide RAG Engine is active",
        "memory_vectors": memory_vector_store.count(),
    })