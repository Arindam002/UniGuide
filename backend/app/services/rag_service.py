from app.rag.retriever import Retriever
from app.rag.generator import Generator
from app.rag.reranker import Reranker
from app.utils.subject_classifier import SubjectClassifier

class RagService:
    """
    RAG service to handle:
    - Normal and streaming responses
    - Subject detection (Global search if branch/sem are removed)
    """

    def __init__(self):
        self.retriever = Retriever()
        self.generator = Generator()
        self.reranker = Reranker()
        self.subject_classifier = SubjectClassifier()

    # -----------------------------
    # NORMAL RESPONSE
    # -----------------------------
    def ask(self, question, branch=None, semester=None, subject=None):
        # 1️⃣ Auto-detect subject if not provided (Crucial now that branch/sem are gone)
        if subject is None:
            subject = self.subject_classifier.classify(question)

        # 2️⃣ Retrieve candidate chunks 
        # Since branch/sem are None, retriever should perform a wider search
        retrieved_chunks = self.retriever.retrieve(
            question,
            branch=branch,
            semester=semester,
            subject=subject,
            top_k=10
        )
        print(f"[RAG] Retrieved chunks count: {len(retrieved_chunks) if retrieved_chunks else 0}")

        # 3️⃣ Rerank & Select Top 3
        reranked_chunks = self.reranker.rerank(question, retrieved_chunks)
        top_chunks = reranked_chunks[:3] if reranked_chunks else []

        # 4️⃣ Detect Sources & PYQs
        sources = list({c.get("file_name", "Unknown Source") for c in top_chunks})
        pyq_sources = list({c["file_name"] for c in top_chunks if c.get("category") == "pyqs"})

        # 5️⃣ Generate answer
        answer = self.generator.generate(question, top_chunks)

        return {
            "answer": answer,
            "sources": sources,
            "pyq_sources": pyq_sources,
            "subject": subject
        }

    # -----------------------------
    # STREAMING RESPONSE
    # -----------------------------
    def generate_stream(self, question, branch=None, semester=None, subject=None):
        # 1️⃣ Auto-detect subject
        if subject is None:
            subject = self.subject_classifier.classify(question)

        # 2️⃣ Retrieve (passing branch/sem as None allows global search)
        retrieved_chunks = self.retriever.retrieve(
            question,
            branch=branch,
            semester=semester,
            subject=subject,
            top_k=10
        )

        # 3️⃣ Rerank
        reranked_chunks = self.reranker.rerank(question, retrieved_chunks)
        top_chunks = reranked_chunks[:3] if reranked_chunks else []

        # 4️⃣ Stream LLM tokens first
        # Pass the chunks to the generator for context-aware answering
        for token in self.generator.generate_stream(question, top_chunks):
            yield token

        # 5️⃣ Metadata Footer
        pyq_sources = list({c["file_name"] for c in top_chunks if c.get("category") == "pyqs"})
        
        footer = "\n\n---"
        if subject and subject != "general":
            footer += f"\n📚 Subject: {subject.upper()}"
        if pyq_sources:
            footer += f"\n📂 Referenced PYQs: {', '.join(pyq_sources)}"
        
        yield footer