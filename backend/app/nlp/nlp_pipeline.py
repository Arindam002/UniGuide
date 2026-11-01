from spellchecker import SpellChecker
from difflib import get_close_matches
import re
from app.nlp.query_preprocessing import (
    clean_query,
    normalize_known_typos,
)


class NLPPipeline:
    """
    NLP preprocessing for UniGuide:
    - Corrects spelling mistakes safely without mangling technical vocabulary
    - Protects important academic keywords and acronyms
    - Detects intent (syllabus, question types, exam marks)
    - Extracts marks
    """

    DOMAIN_VOCABULARY = {
        "algorithm", "array", "automata", "compiler", "database", "deadlock",
        "graph", "inode", "linked", "malloc", "mutex", "numpy", "pandas",
        "pointer", "queue", "realloc", "scanf", "semaphore", "sql", "stack",
        "stdio", "struct", "tree",
    }

    def __init__(self):
        self.spell = SpellChecker()

        self.protected_words = {
            "pyq", "pyqs", "pya", "pyas", "rag", "faiss", "os", "dbms",
            "coa", "dsa", "ai", "ml", "cn", "toc", "cd", "compiler",
            "sql", "nosql", "tcp", "udp", "ip", "http", "https", "fifo",
            "lru", "bfs", "dfs", "bst", "avl", "mutex", "semaphore",
            "dijkstra", "quicksort", "mergesort", "radix", "heap", "heaps",
            "paging", "segmentation", "deadlock", "multithreading",
            "boolean", "varchar", "btree", "numpy", "pandas", "pytorch",
            "tensorflow", "scipy", "matplotlib", "json", "rest", "api",
            "cpu", "gpu", "ram", "rom", "alu", "cache", "asymptotic",
            "adt", "lifo", "invariance", "clrs", "tanenbaum", "galvin",
            "malloc", "calloc", "realloc", "printf", "scanf", "stdio",
            "struct", "inode", "join", "pointer", "pointers", "array",
            "arrays", "linkedlist", "stack", "queue", "thread", "threads",
            "process", "kernel", "syscall", "filesystem",
            "namespace", "iterator", "template", "nullptr", "sizeof",
            "stdin", "stdout", "stderr", "typedef", "enum", "union",
        }

        # Add domain keywords to spellchecker lexicon so they are treated as known words
        self.spell.word_frequency.load_words(list(self.protected_words))

    def correct_spelling(self, text: str) -> str:
        if not text:
            return ""

        text = normalize_known_typos(text)
        words = text.split()
        corrected_words = []

        for word in words:
            # Separate word from leading and trailing punctuation
            match = re.match(r"^([^\w]*)(.*?)([^\w]*)$", word)
            if not match:
                corrected_words.append(word)
                continue

            prefix, core, suffix = match.groups()
            if not core:
                corrected_words.append(word)
                continue

            clean_lower = core.lower()

            # Skip numbers, single characters, code-like identifiers, and protected words
            if (
                clean_lower in self.protected_words
                or clean_lower in self.spell
                or re.search(r"\d", core)
                or "_" in core
                or re.search(r"[a-z][A-Z]|[A-Z]{2,}[a-z]", core)
                or len(core) <= 2
            ):
                corrected_words.append(word)
                continue

            try:
                candidate = self.spell.correction(core)
                domain_match = get_close_matches(
                    clean_lower,
                    self.DOMAIN_VOCABULARY,
                    n=1,
                    cutoff=0.8,
                )
                corrected_core = (
                    domain_match[0]
                    if domain_match
                    else candidate if candidate else core
                )
            except Exception:
                corrected_core = core

            # Preserve capitalization style
            if core.isupper() and len(core) > 1:
                corrected_core = corrected_core.upper()
            elif core.istitle():
                corrected_core = corrected_core.capitalize()

            corrected_words.append(f"{prefix}{corrected_core}{suffix}")

        return " ".join(corrected_words)

    def detect_intent(self, question: str):
        raw_question = str(question or "")
        q_lower = clean_query(raw_question).lower()
        intent = "answer"
        marks = None

        if "important topics" in q_lower or "syllabus" in q_lower:
            intent = "important_topics"
        else:
            match = re.search(
                r"\b(\d+)\s*marks?\b",
                raw_question.lower(),
            )
            if match:
                marks = int(match.group(1))
                intent = "answer"

        return {
            "intent": intent,
            "marks": marks,
        }

    def process_question(self, question: str):
        detected_intent = self.detect_intent(question)
        corrected = self.correct_spelling(clean_query(question))
        intent_info = self.detect_intent(corrected)

        return (
            corrected,
            intent_info["intent"],
            detected_intent["marks"],
        )
