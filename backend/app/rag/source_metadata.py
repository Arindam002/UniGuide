import os
import re


_FOUNDATIONAL_TOPICS = (
    "algorithm",
    "data structure",
    "dsa",
    "discrete math",
    "computer organization",
    "computer architecture",
    "operating system",
    "database",
    "automata",
    "compiler",
    "theory of computation",
    "software engineering",
    "artificial intelligence",
    "machine learning",
    "dbms",
    "computer science",
)

_ALGORITHMS_AND_DATA_STRUCTURES = (
    "algorithm",
    "data structure",
    "dsa",
)

_CONCEPT_TERMS = (
    "abstract data type",
    "array",
    "linked list",
    "stack",
    "queue",
    "tree",
    "graph",
    "hash table",
    "hash map",
    "sorting",
    "searching",
    "algorithm",
    "time complexity",
    "space complexity",
    "big o",
    "recursion",
    "pointer",
    "memory allocation",
    "data structure",
    "invariant",
    "compiler",
    "operating system",
    "database",
)

_LIBRARY_OR_IMPLEMENTATION_TERMS = (
    "python",
    "numpy",
    "pandas",
    "library",
    "api",
    "package",
    "framework",
    "implementation",
    "code example",
    "syntax",
    "function call",
)

_KNOWN_TEXTBOOKS = (
    (
        ("introduction to algorithms", "clrs"),
        "Introduction to Algorithms",
        "Thomas H. Cormen, Charles E. Leiserson, Ronald L. Rivest, and Clifford Stein",
    ),
    (
        ("algorithms, 4", "algorithms fourth", "sedgewick"),
        "Algorithms",
        "Robert Sedgewick and Kevin Wayne",
    ),
    (
        ("data structures and algorithms in c++",),
        "Data Structures and Algorithms in C++",
        "Michael T. Goodrich",
    ),
)


def is_foundational_cs_query(query):
    normalized = re.sub(r"[^a-z0-9]+", " ", str(query or "").lower()).strip()

    if not normalized:
        return False

    if any(term in normalized for term in _LIBRARY_OR_IMPLEMENTATION_TERMS):
        return False

    return any(term in normalized for term in _CONCEPT_TERMS) or bool(
        re.search(r"\b(what is|define|explain|describe)\b", normalized)
    )


def get_textbook_metadata(file_name, subject=None, category=None):
    title = os.path.splitext(os.path.basename(str(file_name or "")))[0].strip()
    searchable = f"{title} {subject or ''}".lower()
    is_book = str(category or "").strip().lower() == "books"
    is_computer_science_textbook = is_book and any(
        topic in searchable for topic in _FOUNDATIONAL_TOPICS
    )
    is_algorithms_and_data_structures = is_computer_science_textbook and any(
        topic in searchable for topic in _ALGORITHMS_AND_DATA_STRUCTURES
    )

    textbook_title = title or "Unknown textbook"
    textbook_author = "Not identified in source metadata"

    for aliases, known_title, known_author in _KNOWN_TEXTBOOKS:
        if any(alias in searchable for alias in aliases):
            textbook_title = known_title
            textbook_author = known_author
            break

    return {
        "textbook_title": textbook_title,
        "textbook_author": textbook_author,
        "rag_category": (
            "computer_science_textbook"
            if is_computer_science_textbook
            else None
        ),
        "rag_source": (
            "algorithms_and_data_structures"
            if is_algorithms_and_data_structures
            else None
        ),
    }
