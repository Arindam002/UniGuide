import re

class Chunker:
    def __init__(self, chunk_size=1200, overlap=200, min_chunk_size=400):
        self.base_chunk_size = chunk_size
        self.base_overlap = overlap
        self.min_chunk_size = min_chunk_size

    # -----------------------------
    # Clean text
    # -----------------------------
    def clean_text(self, text):
        if not text:
            return ""
        text = re.sub(r'\s+', ' ', text)
        return text.strip()

    # -----------------------------
    # Split into sentences
    # -----------------------------
    def split_sentences(self, text):
        if not text:
            return []

        # More tolerant sentence split
        sentences = re.split(r'(?<=[.!?])\s+', text)

        cleaned = [s.strip() for s in sentences if len(s.strip()) > 20]
        return cleaned

    # -----------------------------
    # Dynamic chunk parameters
    # -----------------------------
    def get_dynamic_chunk_params(self, text_length):
        if text_length < 5000:
            return self.base_chunk_size, self.base_overlap
        elif text_length < 20000:
            return int(self.base_chunk_size * 1.5), int(self.base_overlap * 1.5)
        elif text_length < 50000:
            return self.base_chunk_size * 2, self.base_overlap * 2
        else:
            return self.base_chunk_size * 3, self.base_overlap * 3

    # -----------------------------
    # Get overlap sentences
    # -----------------------------
    def get_overlap_sentences(self, chunk_sentences, overlap_chars):
        overlap_sentences = []
        total_len = 0

        for sentence in reversed(chunk_sentences):
            if total_len + len(sentence) > overlap_chars:
                break
            overlap_sentences.insert(0, sentence)
            total_len += len(sentence)

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

        text_length = len(cleaned_text)
        chunk_limit, overlap_limit = self.get_dynamic_chunk_params(text_length)

        sentences = self.split_sentences(cleaned_text)
        if not sentences:
            return []

        chunks = []
        current_sentences = []
        current_chunk_text = ""

        for sentence in sentences:
            sentence_parts = self.split_long_sentence(sentence, chunk_limit)

            for part in sentence_parts:
                candidate = f"{current_chunk_text} {part}".strip()

                if len(candidate) <= chunk_limit:
                    current_chunk_text = candidate
                    current_sentences.append(part)
                else:
                    if len(current_chunk_text.strip()) >= self.min_chunk_size:
                        chunks.append(current_chunk_text.strip())

                    overlap_sentences = self.get_overlap_sentences(current_sentences, overlap_limit)

                    current_sentences = overlap_sentences + [part]
                    current_chunk_text = " ".join(current_sentences).strip()

        if len(current_chunk_text.strip()) >= self.min_chunk_size:
            chunks.append(current_chunk_text.strip())

        chunks = [c for c in chunks if len(c.split()) > 30]

        return chunks