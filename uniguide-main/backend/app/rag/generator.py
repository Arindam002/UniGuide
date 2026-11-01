from groq import Groq
import os
import re
import json


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

    def should_generate_diagram(self, question, answer):
        normalized_question = question.lower()
        diagram_keywords = (
            "diagram",
            "flowchart",
            "architecture",
            "workflow",
            "process",
            "steps",
            "working",
            "lifecycle",
            "how",
            "explain",
        )

        if any(keyword in normalized_question for keyword in diagram_keywords):
            return True

        return len(answer.split()) >= 60

    def generate_diagram(self, question, retrieved_chunks, answer):
        if not retrieved_chunks or not answer:
            return None

        if not self.should_generate_diagram(question, answer):
            return None

        context = self.build_context(retrieved_chunks)
        prompt = f"""
Create a compact study diagram in strict JSON.

Return only valid JSON with this exact schema:
{{
  "title": "Short diagram title",
  "steps": [
    {{"title": "Step title", "detail": "One short explanation"}},
    {{"title": "Step title", "detail": "One short explanation"}}
  ],
  "footer": "Optional short takeaway"
}}

Rules:
- Use 3 to 5 steps only.
- Keep each title under 6 words.
- Keep each detail under 18 words.
- The diagram must help explain the answer visually.
- Do not include markdown fences or extra commentary.

Context:
{context}

Question:
{question}

Answer:
{answer}
"""

        try:
            completion = self.client.chat.completions.create(
                model="llama-3.3-70b-versatile",
                messages=[
                    {"role": "system", "content": "You turn study answers into compact educational diagrams."},
                    {"role": "user", "content": prompt}
                ],
                temperature=0.2,
            )

            content = completion.choices[0].message.content.strip()
            match = re.search(r"\{.*\}", content, re.DOTALL)
            if not match:
                return None

            parsed = json.loads(match.group(0))
            title = str(parsed.get("title", "")).strip()
            footer = str(parsed.get("footer", "")).strip() or None
            raw_steps = parsed.get("steps", [])

            if not title or not isinstance(raw_steps, list):
                return None

            steps = []
            for step in raw_steps[:5]:
                if not isinstance(step, dict):
                    continue
                step_title = str(step.get("title", "")).strip()
                step_detail = str(step.get("detail", "")).strip()
                if not step_title:
                    continue
                steps.append({
                    "title": step_title,
                    "detail": step_detail,
                })

            if len(steps) < 3:
                return None

            return {
                "title": title,
                "steps": steps,
                "footer": footer,
            }
        except Exception as e:
            print(f"[Generator] Diagram generation skipped: {e}")
            return None

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
Write the answer in clean Markdown-style formatting:
- Start with a short heading using ##.
- Use short paragraphs.
- Use bullet points for key facts.
- Use numbered steps when explaining a process.
- Use subheadings for sections like Definition, Explanation, Example, Key Points, or Sources.
- Keep lines easy to scan on a phone screen.
- If the answer contains code, wrap the full code snippet in fenced Markdown with the language name.

After the answer include:

## Sources
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

Answer format:
- Start with a short heading using ##.
- Use short paragraphs.
- Use bullet points for key facts.
- Use numbered steps when explaining a process.
- Use subheadings for sections like Definition, Explanation, Example, Key Points, or Sources.
- Keep lines easy to scan on a phone screen.
- If the answer contains code, wrap the full code snippet in fenced Markdown with the language name.

After the answer include:

## Sources
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
