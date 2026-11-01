import re


class Chunker:
    def __init__(self, chunk_size=1000, overlap=150):
        if chunk_size <= 0:
            raise ValueError("chunk_size must be greater than zero")
        if overlap < 0 or overlap >= chunk_size:
            raise ValueError("overlap must be non-negative and smaller than chunk_size")

        self.chunk_size = chunk_size
        self.overlap = overlap

    # -----------------------------
    # Clean text
    # -----------------------------
    def clean_text(self, text):
        if not text:
            return ""
        # Collapse multiple whitespace characters while keeping words intact
        text = re.sub(r'[ \t]+', ' ', text)
        text = re.sub(r'\n{3,}', '\n\n', text)
        return text.strip()

    # -----------------------------
    # Split into sentences / segments
    # -----------------------------
    def split_sentences(self, text):
        if not text:
            return []

        # Split on sentence boundaries (. ! ?) followed by whitespace or line breaks
        sentences = re.split(r'(?<=[.!?])\s+|\n+', text)

        # Retain all non-empty sentences, definitions, questions, and headings
        cleaned = [s.strip() for s in sentences if s and s.strip()]
        return cleaned

    # -----------------------------
    # Get overlap sentences
    # -----------------------------
    def get_overlap_sentences(self, chunk_sentences, overlap_chars):
        if overlap_chars <= 0:
            return []

        overlap_sentences = []
        total_len = 0

        for sentence in reversed(chunk_sentences):
            sentence_length = len(sentence) + (1 if overlap_sentences else 0)
            if total_len + sentence_length > overlap_chars:
                break
            overlap_sentences.insert(0, sentence)
            total_len += sentence_length

        return overlap_sentences

    # -----------------------------
    # Split long sentence if needed
    # -----------------------------
    def split_long_sentence(self, sentence, max_len):
        if len(sentence) <= max_len:
            return [sentence]

        parts = []
        words = sentence.split()
        current = ""

        for word in words:
            if len(word) > max_len:
                if current:
                    parts.append(current)
                    current = ""
                parts.extend(
                    word[start:start + max_len]
                    for start in range(0, len(word), max_len)
                )
                continue

            if len(current) + len(word) + 1 <= max_len:
                current = f"{current} {word}".strip()
            else:
                if current:
                    parts.append(current)
                current = word

        if current:
            parts.append(current)

        return parts

    # -----------------------------
    # Chunk text
    # -----------------------------
    def chunk_text(self, text):
        if not text:
            return []

        cleaned_text = self.clean_text(text)
        if not cleaned_text:
            return []

        sentences = self.split_sentences(cleaned_text)
        if not sentences:
            return []

        chunks = []
        current_sentences = []
        current_chunk_text = ""

        for sentence in sentences:
            sentence_parts = self.split_long_sentence(sentence, self.chunk_size)

            for part in sentence_parts:
                candidate = f"{current_chunk_text} {part}".strip() if current_chunk_text else part

                if len(candidate) <= self.chunk_size:
                    current_chunk_text = candidate
                    current_sentences.append(part)
                else:
                    if current_chunk_text:
                        chunks.append(current_chunk_text.strip())

                    overlap_budget = min(
                        self.overlap,
                        self.chunk_size - len(part) - 1,
                    )
                    overlap_sentences = self.get_overlap_sentences(
                        current_sentences,
                        overlap_budget,
                    )
                    while (
                        overlap_sentences
                        and len(" ".join(overlap_sentences + [part])) > self.chunk_size
                    ):
                        overlap_sentences.pop(0)

                    current_sentences = overlap_sentences + [part]
                    current_chunk_text = " ".join(current_sentences).strip()

        if current_chunk_text:
            chunks.append(current_chunk_text.strip())

        return [chunk for chunk in chunks if chunk]
