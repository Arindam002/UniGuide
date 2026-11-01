from app.rag.retriever import Retriever
from app.rag.generator import Generator
from app.rag.reranker import Reranker
from app.rag.source_metadata import (
    get_textbook_metadata,
    is_foundational_cs_query,
)
from app.rag.query_router import route_query
from app.utils.subject_classifier import SubjectClassifier
from app.memory import chat_memory
from app.memory.chat_memory_vector_store import ChatMemoryVectorStore
from database.db import get_connection
from app.nlp.query_preprocessing import normalize_query_typos


class RagService:
    def __init__(self):
        self.retriever = Retriever()
        self.generator = Generator()
        self.reranker = Reranker()
        self.subject_classifier = SubjectClassifier()
        self.memory_vector_store = ChatMemoryVectorStore()

    def is_small_talk(self, question):
        return self.generator.is_small_talk(question)

    def get_small_talk_response(self, question):
        return self.generator.small_talk_response(question)

    def _normalize_subject(self, subject):
        if not subject:
            return None

        subject = str(subject).strip().lower()

        if subject in ["general", "unknown", "none", "null", ""]:
            return None

        return subject

    def _normalize_text(self, text):
        return normalize_query_typos(text).lower()

    def _format_chat_history(self, chat_history):
        if not chat_history:
            return ""

        formatted = []

        for msg in chat_history[-8:]:
            role = msg.get("role", "")
            content = msg.get("content", "")

            if not content:
                continue

            if role == "user":
                formatted.append(f"User: {content}")
            elif role == "assistant":
                formatted.append(f"Assistant: {content}")

        return "\n".join(formatted)

    def _is_context_followup(self, question):
        q = self._normalize_text(question)

        followup_keywords = [
            "simple",
            "simplify",
            "explain",
            "again",
            "more",
            "example",
            "summarize",
            "short",
            "easy",
        ]

        pronouns = ["it", "this", "that", "same", "above", "previous"]

        # If both exist → strong follow-up
        if any(p in q for p in pronouns) and any(k in q for k in followup_keywords):
            return True

        # If contains strong follow-up intent
        strong_patterns = [
            "explain in simple",
            "explain simply",
            "make it simple",
            "simplify",
            "in simple words",
            "in easy words",
            "explain again",
            "give example",
            "summarize",
            "short answer",
        ]

        if any(p in q for p in strong_patterns):
            return True

        return False

    def _get_long_term_memories(self, question, student_id=None, guest_id=None, top_k=3):
        try:
            search_results = self.memory_vector_store.search(question, top_k=top_k)

            vector_ids = [
                item["vector_id"]
                for item in search_results
                if item.get("vector_id") is not None
            ]

            memories = chat_memory.get_memory_by_vector_ids(
                vector_ids=vector_ids,
                student_id=student_id,
                guest_id=guest_id,
            )

            if memories:
                print(f"[MEMORY] Retrieved long-term memories: {len(memories)}")
                return memories

            fallback_memories = chat_memory.get_recent_long_term_memories(
                student_id=student_id,
                guest_id=guest_id,
                limit=2,
            )

            print(f"[MEMORY] Fallback recent memories: {len(fallback_memories)}")
            return fallback_memories

        except Exception as e:
            print(f"[MEMORY ERROR] Failed to retrieve long-term memories: {e}")
            return []

    def _rewrite_question_with_history(self, question, chat_history):
        if not chat_history:
            return question

        q = self._normalize_text(question)

        followup_words = [
            "it",
            "its",
            "this",
            "that",
            "these",
            "those",
            "they",
            "them",
            "same",
            "above",
            "previous",
            "continue",
            "types",
            "advantages",
            "disadvantages",
            "conditions",
            "features",
            "uses",
            "example",
            "examples",
            "simple",
            "simply",
            "again",
            "more",
        ]

        is_followup = any(word in q.split() for word in followup_words)

        if not is_followup:
            return question

        history_text = self._format_chat_history(chat_history)

        try:
            rewritten = self.generator.rewrite_followup_question(
                question=question,
                chat_history=history_text,
            )

            if rewritten and len(rewritten.strip()) > 3:
                print(f"[RAG] Original question: {question}")
                print(f"[RAG] Rewritten question: {rewritten}")
                return rewritten.strip()

        except Exception as e:
            print(f"[RAG] Question rewrite failed: {e}")

        return question

    def _is_diagram_request(self, question):
        q = self._normalize_text(question)

        diagram_keywords = [
            "diagram",
            "block diagram",
            "flowchart",
            "flow chart",
            "architecture",
            "schematic",
            "circuit diagram",
            "figure",
            "illustration",
            "show diagram",
            "draw diagram",
            "with diagram",
            "explain with diagram",
            "neat diagram",
            "labelled diagram",
            "labeled diagram",
            "circuit",
            "circuit of",
        ]

        return any(keyword in q for keyword in diagram_keywords)

    def _is_pyq_request(self, question):
        q = self._normalize_text(question).replace("-", " ")

        pyq_keywords = [
            "pyq",
            "pyqs",
            "previous year",
            "previous year question",
            "previous year questions",
            "past paper",
            "past papers",
            "old paper",
            "old papers",
            "previous question",
            "previous questions",
            "last year question",
            "last year questions",
            "past year question",
            "past year questions",
            "exam question",
            "exam questions",
            "important question",
            "important questions",
            "question from exam",
            "questions asked",
            "asked question",
            "asked in exam",
            "asked previously",
            "university question",
            "question paper",
            "question papers",
            "paper solution",
            "from pyq",
            "from previous year",
            "important pyq",
            "pyq question",
            "pyq questions",
            "give pyq",
            "give pyqs",
            "show pyq",
            "show pyqs",
            "find pyq",
            "find pyqs",
        ]

        return any(keyword in q for keyword in pyq_keywords)

    def _extract_query_keywords(self, question):
        stop_words = {
            "show", "me", "the", "a", "an", "of", "for", "with", "and",
            "or", "to", "is", "are", "in", "on", "explain", "draw",
            "give", "please", "diagram", "figure", "block", "flowchart",
            "flow", "chart", "architecture", "illustration", "schematic",
            "circuit", "labelled", "labeled",
        }

        words = []

        for token in self._normalize_text(question).replace(",", " ").split():
            token = token.strip()

            if len(token) < 3:
                continue

            if token in stop_words:
                continue

            words.append(token)

        return list(dict.fromkeys(words))

    def _detect_subject(self, question, subject=None):
        detected_subject = subject

        if detected_subject is None:
            try:
                detected_subject = self.subject_classifier.classify(question)
            except Exception as e:
                print(f"[RAG] Subject classification failed: {e}")
                detected_subject = None

        return self._normalize_subject(detected_subject)

    def _choose_retrieval_category(self, question):
        if self._is_pyq_request(question):
            return "pyqs"

        return "books"

    def _retrieve_with_fallback(self, question, branch=None, semester=None, subject=None, top_k=10):
        question = normalize_query_typos(question)
        detected_subject = self._detect_subject(question, subject)
        retrieval_category = self._choose_retrieval_category(question)
        prioritize_textbooks = (
            retrieval_category == "books"
            and is_foundational_cs_query(question)
        )
        namespace = route_query(question)
        retrieval_subject = detected_subject
        if prioritize_textbooks:
            retrieval_subject = self._normalize_subject(subject)
            if subject is None:
                detected_subject = None

        print(f"[RAG] Question: {question}")
        print(f"[RAG] Detected subject: {detected_subject}")
        print(f"[RAG] Branch: {branch}")
        print(f"[RAG] Semester: {semester}")
        print(f"[RAG] Retrieval category: {retrieval_category}")
        print(f"[RAG] Routed namespace: {namespace}")
        print(f"[RAG] Prioritize CS textbooks: {prioritize_textbooks}")

        retrieved_chunks = self.retriever.retrieve(
            query=question,
            branch=branch,
            semester=semester,
            subject=retrieval_subject,
            category=retrieval_category,
            top_k=top_k,
            prioritize_computer_science_textbooks=prioritize_textbooks,
            namespace=namespace,
        )

        print(
            f"[RAG] Retrieved chunks count (with subject filter): "
            f"{len(retrieved_chunks) if retrieved_chunks else 0}"
        )

        if not retrieved_chunks and retrieval_subject is not None:
            print("[RAG] No chunks found with subject filter. Retrying without subject filter...")

            retrieved_chunks = self.retriever.retrieve(
                query=question,
                branch=branch,
                semester=semester,
                subject=None,
                category=retrieval_category,
                top_k=top_k,
                prioritize_computer_science_textbooks=prioritize_textbooks,
                namespace=namespace,
            )

            print(
                f"[RAG] Retrieved chunks count (without subject filter): "
                f"{len(retrieved_chunks) if retrieved_chunks else 0}"
            )

        if not retrieved_chunks:
            fallback_category = "books" if retrieval_category == "pyqs" else "pyqs"
            print(f"[RAG] No chunks found in {retrieval_category}. Retrying in {fallback_category}...")

            retrieved_chunks = self.retriever.retrieve(
                query=question,
                branch=branch,
                semester=semester,
                subject=None,
                category=fallback_category,
                top_k=top_k,
                namespace=namespace,
            )

            print(
                f"[RAG] Retrieved chunks count (cross-category fallback): "
                f"{len(retrieved_chunks) if retrieved_chunks else 0}"
            )

        return retrieved_chunks, detected_subject, retrieval_category

    def _prioritize_textbook_chunks(self, chunks, question):
        if not is_foundational_cs_query(question):
            return chunks

        for chunk in chunks or []:
            if not chunk.get("rag_category"):
                chunk.update(
                    get_textbook_metadata(
                        file_name=chunk.get("file_name"),
                        subject=chunk.get("subject"),
                        category=chunk.get("category"),
                    )
                )

        return sorted(
            chunks or [],
            key=lambda chunk: (
                chunk.get("rag_category") != "computer_science_textbook",
            ),
        )

    def _get_candidate_document_names(self, chunks):
        names = []

        for chunk in chunks or []:
            file_name = chunk.get("file_name")
            category = str(chunk.get("category") or "").strip().lower()

            if file_name and category == "books":
                names.append(file_name)

        return list(dict.fromkeys(names))

    def _fetch_diagrams_for_documents(self, document_names, question, limit=4):
        if not document_names:
            return []

        keywords = self._extract_query_keywords(question)
        conn = None

        try:
            conn = get_connection()
            cursor = conn.cursor()

            placeholders = ",".join(["?"] * len(document_names))

            query = f"""
                SELECT
                    d.id,
                    d.page_number,
                    d.image_path,
                    d.caption,
                    d.context_text,
                    doc.name AS document_name,
                    doc.subject,
                    doc.branch,
                    doc.semester
                FROM diagrams d
                JOIN documents doc
                    ON d.document_id = doc.id
                WHERE doc.name IN ({placeholders})
                  AND doc.category = 'books'
                ORDER BY d.page_number ASC, d.id ASC
            """

            cursor.execute(query, tuple(document_names))
            rows = cursor.fetchall()

            matched = []
            fallback = []

            for row in rows:
                diagram = {
                    "id": row[0],
                    "page_number": row[1],
                    "image_path": row[2],
                    "caption": row[3],
                    "context_text": row[4],
                    "document_name": row[5],
                    "subject": row[6],
                    "branch": row[7],
                    "semester": row[8],
                }

                searchable = " ".join([
                    str(row[3] or ""),
                    str(row[4] or ""),
                    str(row[5] or ""),
                    str(row[6] or ""),
                ]).lower()

                if keywords and any(keyword in searchable for keyword in keywords):
                    matched.append(diagram)
                else:
                    fallback.append(diagram)

            final_diagrams = matched if matched else fallback
            return final_diagrams[:limit]

        except Exception as e:
            print(f"[RAG] Diagram lookup failed: {e}")
            return []

        finally:
            if conn:
                conn.close()

    def _get_relevant_diagrams(self, question, top_chunks, limit=4):
        if not self._is_diagram_request(question):
            return []

        document_names = self._get_candidate_document_names(top_chunks)

        if not document_names:
            return []

        return self._fetch_diagrams_for_documents(
            document_names=document_names,
            question=question,
            limit=limit,
        )

    def _select_diverse_top_chunks(self, chunks, max_chunks=4):
        """
        Deduplicates and selects the top most relevant chunks across sources,
        enabling multi-document synthesis while avoiding redundant passages.
        """
        if not chunks:
            return []
        selected = []
        seen_texts = set()
        for chunk in chunks:
            text = chunk.get("chunk_text", "").strip()
            text_sig = " ".join(text.split()).casefold()
            if text_sig in seen_texts:
                continue
            seen_texts.add(text_sig)
            selected.append(chunk)
            if len(selected) >= max_chunks:
                break
        return selected

    def _prepare_sources(self, top_chunks):
        sources = []
        pyq_sources = []
        book_sources = []

        for chunk in top_chunks or []:
            file_name = chunk.get("file_name")
            category = str(chunk.get("category") or "").strip().lower()

            if not file_name:
                continue

            if file_name not in sources:
                sources.append(file_name)

            if category == "pyqs" and file_name not in pyq_sources:
                pyq_sources.append(file_name)

            if category == "books" and file_name not in book_sources:
                book_sources.append(file_name)

        return sources, pyq_sources, book_sources

    def ask(
        self,
        question,
        branch=None,
        semester=None,
        subject=None,
        marks=None,
        chat_history=None,
        student_id=None,
        guest_id=None,
        chat_id=None,
    ):
        if self.is_small_talk(question):
            return {
                "answer": self.get_small_talk_response(question),
                "sources": [],
                "pyq_sources": [],
                "book_sources": [],
                "subject": None,
                "retrieval_category": None,
                "diagrams": [],
            }

        rewritten_question = self._rewrite_question_with_history(
            question=question,
            chat_history=chat_history,
        )

        long_term_memories = self._get_long_term_memories(
            question=rewritten_question,
            student_id=student_id,
            guest_id=guest_id,
            top_k=3,
        )

        last_context = None

        is_pyq_query = self._is_pyq_request(question)

        if chat_id and self._is_context_followup(question) and not is_pyq_query:
            last_context = chat_memory.get_last_chat_context(chat_id)

        if last_context and last_context.get("chunks"):
            print("[RAG] Using previous retrieved context for follow-up question.")

            top_chunks = last_context["chunks"][:4]
            detected_subject = subject
            retrieval_category = top_chunks[0].get("category") if top_chunks else None

        else:
            retrieved_chunks, detected_subject, retrieval_category = self._retrieve_with_fallback(
                question=rewritten_question,
                branch=branch,
                semester=semester,
                subject=subject,
                top_k=10,
            )

            reranked_chunks = (
                self.reranker.rerank(rewritten_question, retrieved_chunks)
                if retrieved_chunks
                else []
            )

            top_chunks = (
                self._prioritize_textbook_chunks(
                    reranked_chunks,
                    rewritten_question,
                )[:4]
                if reranked_chunks
                else []
            )

        top_chunks = self._prioritize_textbook_chunks(top_chunks, rewritten_question)
        top_chunks = self._select_diverse_top_chunks(top_chunks, max_chunks=4)

        print(f"[RAG] Final top chunks count: {len(top_chunks)}")

        if chat_id and top_chunks:
            chat_memory.save_chat_context(
                chat_id=chat_id,
                question=question,
                rewritten_question=rewritten_question,
                chunks=top_chunks,
            )

        sources, pyq_sources, book_sources = self._prepare_sources(top_chunks)
        diagrams = self._get_relevant_diagrams(rewritten_question, top_chunks, limit=4)

        formatted_diagrams = []

        for d in diagrams:
            formatted_diagrams.append({
                "id": d["id"],
                "document_name": d["document_name"],
                "page_number": d["page_number"],
                "caption": d["caption"],
                "image_url": f"/diagrams/view/{d['id']}",
            })

        answer = self.generator.generate(
            question=question,
            chunks=top_chunks,
            chat_history=chat_history,
            long_term_memories=long_term_memories,
            rewritten_question=rewritten_question,
            marks=marks,
        )

        return {
            "answer": answer,
            "sources": sources,
            "pyq_sources": pyq_sources,
            "book_sources": book_sources,
            "subject": detected_subject,
            "retrieval_category": retrieval_category,
            "domain": route_query(rewritten_question),
            "diagrams": formatted_diagrams,
        }

    def generate_stream(
        self,
        question,
        branch=None,
        semester=None,
        subject=None,
        marks=None,
        chat_history=None,
        student_id=None,
        guest_id=None,
        chat_id=None,
    ):
        if self.is_small_talk(question):
            yield self.get_small_talk_response(question)
            return

        rewritten_question = self._rewrite_question_with_history(
            question=question,
            chat_history=chat_history,
        )

        long_term_memories = self._get_long_term_memories(
            question=rewritten_question,
            student_id=student_id,
            guest_id=guest_id,
            top_k=3,
        )

        last_context = None

        is_pyq_query = self._is_pyq_request(question)

        if chat_id and self._is_context_followup(question) and not is_pyq_query:
            last_context = chat_memory.get_last_chat_context(chat_id)

        if last_context and last_context.get("chunks"):
            print("[RAG] Using previous retrieved context for stream follow-up question.")

            top_chunks = last_context["chunks"][:4]
            detected_subject = subject
            retrieval_category = top_chunks[0].get("category") if top_chunks else None

        else:
            retrieved_chunks, detected_subject, retrieval_category = self._retrieve_with_fallback(
                question=rewritten_question,
                branch=branch,
                semester=semester,
                subject=subject,
                top_k=10,
            )

            reranked_chunks = (
                self.reranker.rerank(rewritten_question, retrieved_chunks)
                if retrieved_chunks
                else []
            )

            top_chunks = (
                self._prioritize_textbook_chunks(
                    reranked_chunks,
                    rewritten_question,
                )[:4]
                if reranked_chunks
                else []
            )

        top_chunks = self._prioritize_textbook_chunks(top_chunks, rewritten_question)
        top_chunks = self._select_diverse_top_chunks(top_chunks, max_chunks=4)

        print(f"[RAG] Final top chunks count (stream): {len(top_chunks)}")

        if chat_id and top_chunks:
            chat_memory.save_chat_context(
                chat_id=chat_id,
                question=question,
                rewritten_question=rewritten_question,
                chunks=top_chunks,
            )

        for token in self.generator.generate_stream(
            question=question,
            chunks=top_chunks,
            chat_history=chat_history,
            long_term_memories=long_term_memories,
            rewritten_question=rewritten_question,
            marks=marks,
        ):
            yield token

        _, pyq_sources, book_sources = self._prepare_sources(top_chunks)
        diagrams = self._get_relevant_diagrams(rewritten_question, top_chunks, limit=2)

        footer = "\n\n---"

        if detected_subject:
            footer += f"\n📚 Subject: {detected_subject.upper()}"

        if retrieval_category:
            footer += f"\n🔎 Search Type: {retrieval_category.upper()}"

        if book_sources:
            footer += f"\n📘 Referenced Books: {', '.join(book_sources)}"

        if pyq_sources:
            footer += f"\n📂 Referenced PYQs: {', '.join(pyq_sources)}"

        if diagrams:
            footer += f"\n🖼️ Related diagrams found: {len(diagrams)}"

        yield footer
