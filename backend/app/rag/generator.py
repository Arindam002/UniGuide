from groq import Groq
import os
import re


class Generator:

    def __init__(self):
        # Load API key
        self.client = Groq(api_key=os.getenv("GROQ_API_KEY"))

        # Limit chunks sent to LLM
        self.MAX_CHUNKS = 5

    # -----------------------------
    # Detect marks from question
    # -----------------------------
    def detect_marks(self, question):

        match = re.search(r"(\d+)\s*marks?", question.lower())

        if match:
            return int(match.group(1))

        return None

    # -----------------------------
    # Build context safely
    # -----------------------------
    def build_context(self, retrieved_chunks):

        context_lines = []

        for item in retrieved_chunks[:self.MAX_CHUNKS]:

            context_lines.append(
                f"{item['chunk_text']} (source: {item['category']} - {item['file_name']})"
            )

        return "\n\n".join(context_lines)

    # -----------------------------
    # Marks based instructions
    # -----------------------------
    def marks_instruction(self, marks):

        if not marks:
            return ""

        if marks <= 2:
            return """
Give a very short exam answer:
- Definition
- 2–3 bullet points
"""

        elif marks <= 5:
            return """
Give a short exam answer:
- Definition
- 3–5 bullet points
"""

        elif marks <= 10:
            return """
Write a structured exam answer:
1. Definition
2. Explanation
3. Example if possible
"""

        else:
            return """
Write a detailed exam answer:
1. Definition
2. Detailed explanation
3. Example
4. Key points summary
"""

    # -----------------------------
    # NORMAL RESPONSE
    # -----------------------------
    def generate(self, question, retrieved_chunks, marks=None):

        if not retrieved_chunks:
            return "Sorry, I could not find relevant material for this question."

        # Auto detect marks if not provided
        if not marks:
            marks = self.detect_marks(question)

        context = self.build_context(retrieved_chunks)

        marks_instruction = self.marks_instruction(marks)

        system_prompt = f"""
You are UniGuide, a friendly university study assistant.

Your personality:
- Speak in a friendly and supportive tone.
- Explain concepts simply like a good teacher.
- Use easy language students can understand.
- Break complex ideas into steps.

{marks_instruction}

Rules:
- Use ONLY the provided context to answer.
- Do not invent information.
- If the context does not contain the answer, say you are not sure.

Answer format:
Write the answer clearly for exam preparation.

After the answer include:

Sources:
- <Book or PYQ name>
"""

        user_prompt = f"""
Context:
{context}

Student Question:
{question}
"""

        completion = self.client.chat.completions.create(
            model="llama-3.3-70b-versatile",
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt}
            ]
        )

        return completion.choices[0].message.content

    # -----------------------------
    # STREAMING RESPONSE
    # -----------------------------
    def generate_stream(self, question, retrieved_chunks, marks=None):

        if not retrieved_chunks:
            yield "Sorry, I could not find relevant material for this question."
            return

        if not marks:
            marks = self.detect_marks(question)

        context = self.build_context(retrieved_chunks)

        marks_instruction = self.marks_instruction(marks)

        system_prompt = f"""
You are UniGuide, a friendly university study assistant.

Your personality:
- Speak in a friendly and supportive tone.
- Explain concepts simply like a good teacher.
- Break complex ideas into steps.

{marks_instruction}

Rules:
- Use ONLY the provided context to answer.
- Do not invent information.
- If the context does not contain the answer, say you are not sure.

After the answer include:

Sources:
- <Book or PYQ name>
"""

        user_prompt = f"""
Context:
{context}

Student Question:
{question}
"""

        stream = self.client.chat.completions.create(
            model="llama-3.3-70b-versatile",
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt}
            ],
            stream=True
        )

        for chunk in stream:

            if chunk.choices[0].delta.content:
                yield chunk.choices[0].delta.content

    # -----------------------------
    # IMPORTANT TOPICS (placeholder)
    # -----------------------------
    def generate_important_topics(self):

        return """
Here are some important topics for this subject:

1. Topic A
2. Topic B
3. Topic C

These topics frequently appear in exams.
"""