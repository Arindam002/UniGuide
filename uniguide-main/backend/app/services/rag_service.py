from app.rag.generator import Generator
from app.rag.reranker import Reranker
from app.rag.retriever import Retriever
from app.utils.subject_classifier import SubjectClassifier


class RagService:
    """
    RAG service to handle normal and streaming responses with optional
    subject detection and diagram generation.
    """

    def __init__(self):
        self.retriever = Retriever()
        self.generator = Generator()
        self.reranker = Reranker()
        self.subject_classifier = SubjectClassifier()

    def _top_book_source(self, chunks):
        for chunk in chunks:
            if chunk.get("category") == "books" and chunk.get("file_name"):
                return [chunk["file_name"]]

        for chunk in chunks:
            if chunk.get("file_name"):
                return [chunk["file_name"]]

        return []

    def ask(self, question, branch=None, semester=None, subject=None):
        if subject is None:
            subject = self.subject_classifier.classify(question)

        retrieved_chunks = self.retriever.retrieve(
            question,
            branch=branch,
            semester=semester,
            subject=subject,
            top_k=10,
        )
        print(
            f"[RAG] Retrieved chunks count: "
            f"{len(retrieved_chunks) if retrieved_chunks else 0}"
        )

        reranked_chunks = self.reranker.rerank(question, retrieved_chunks)
        top_chunks = reranked_chunks[:3] if reranked_chunks else []

        sources = self._top_book_source(top_chunks)
        pyq_sources = list(
            {c["file_name"] for c in top_chunks if c.get("category") == "pyqs"}
        )

        answer = self.generator.generate(question, top_chunks)
        diagram = self.generator.generate_diagram(question, top_chunks, answer)

        return {
            "answer": answer,
            "sources": sources,
            "pyq_sources": pyq_sources,
            "subject": subject,
            "diagram": diagram,
        }

    def generate_stream(self, question, branch=None, semester=None, subject=None):
        if subject is None:
            subject = self.subject_classifier.classify(question)

        retrieved_chunks = self.retriever.retrieve(
            question,
            branch=branch,
            semester=semester,
            subject=subject,
            top_k=10,
        )

        reranked_chunks = self.reranker.rerank(question, retrieved_chunks)
        top_chunks = reranked_chunks[:3] if reranked_chunks else []

        for token in self.generator.generate_stream(question, top_chunks):
            yield token

        pyq_sources = list(
            {c["file_name"] for c in top_chunks if c.get("category") == "pyqs"}
        )

        footer = "\n\n---"
        if subject and subject != "general":
            footer += f"\nSubject: {subject.upper()}"
        if pyq_sources:
            footer += f"\nReferenced PYQs: {', '.join(pyq_sources)}"

        yield footer
