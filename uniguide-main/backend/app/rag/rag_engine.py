from app.rag.retriever import Retriever
from app.rag.generator import Generator


class RAGEngine:

    def __init__(self):
        self.retriever = Retriever()
        self.generator = Generator()

    def answer(self, question, branch=None, semester=None, subject=None, category=None):

        # Retrieve relevant chunks
        results = self.retriever.search(
            query=question,
            branch=branch,
            semester=semester,
            subject=subject,
            category=category
        )

        if not results:
            return "No relevant material found."

        # Generate answer
        answer = self.generator.generate(question, results)

        return answer