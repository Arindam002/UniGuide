import re
from app.nlp.query_preprocessing import normalize_query_typos


DATA_STRUCTURES = "data_structures"
DATABASES = "databases"
PYTHON_DOCUMENTATION = "python_documentation"
COMPUTER_SCIENCE = "computer_science"
COMPILER_DESIGN = "compiler_design"
THEORY_OF_COMPUTATION = "theory_of_computation"
DOMAIN_NAMESPACES = (
    DATA_STRUCTURES,
    DATABASES,
    PYTHON_DOCUMENTATION,
    COMPUTER_SCIENCE,
    COMPILER_DESIGN,
    THEORY_OF_COMPUTATION,
)

_DATABASE_TERMS = (
    "database",
    "database management",
    "dbms",
    "rdbms",
    "sql",
    "sql query",
    "relational",
    "relational algebra",
    "relational model",
    "data warehouse",
    "data mining",
    "transaction",
    "normalization",
    "normalisation",
    "schema",
    "b-tree",
    "b tree",
    "btree",
    "index scan",
    "database index",
    "primary key",
    "foreign key",
    "join",
    "joins",
    "acid",
    "nosql",
    "concurrency control",
)

_PYTHON_TERMS = (
    "python",
    "numpy",
    "pandas",
    "scipy",
    "matplotlib",
    "pytorch",
    "tensorflow",
    "pip install",
    "python library",
    "python package",
    "virtualenv",
    "conda",
)

_DATA_STRUCTURE_TERMS = (
    "data structure",
    "data structures",
    "dsa",
    "daa",
    "array",
    "arrays",
    "link list",
    "link lists",
    "linked list",
    "linked lists",
    "stack",
    "stacks",
    "queue",
    "queues",
    "deque",
    "binary tree",
    "binary search tree",
    "bst",
    "avl tree",
    "red black tree",
    "tree traversal",
    "graph",
    "graphs",
    "hash table",
    "hash map",
    "heap",
    "heaps",
    "sorting",
    "searching",
    "algorithm",
    "algorithms",
    "big o",
    "time complexity",
    "space complexity",
    "recursion",
    "pointer",
    "pointers",
    "structural invariant",
    "dynamic programming",
    "greedy algorithm",
    "shortest path",
    "dijkstra",
)

_COMPILER_DESIGN_TERMS = (
    "compiler",
    "compilers",
    "compiler design",
    "compiler construction",
    "lexical analysis",
    "syntax analysis",
    "semantic analysis",
    "parsing",
    "parser",
    "parsers",
)

_THEORY_OF_COMPUTATION_TERMS = (
    "automata",
    "automaton",
    "finite automata",
    "finite automaton",
    "automata theory",
    "theory of computation",
    "regular language",
    "regular expression",
    "context free grammar",
    "pushdown automaton",
    "turing machine",
)

_PYQ_TERMS = (
    "pyq",
    "pyqs",
    "previous year",
    "question paper",
    "past paper",
    "exam question",
    "past year",
)


def _normalize(text):
    return re.sub(r"[^a-z0-9]+", " ", str(text or "").lower()).strip()


def _matches_term(query: str, term: str) -> bool:
    """
    Match term against query using word boundaries to prevent substring collisions
    (e.g., 'adjoining' matching 'join', 'disarray' matching 'array').
    """
    term_clean = term.strip().lower()
    if not term_clean:
        return False
    # Use word boundary regex
    pattern = r'\b' + re.escape(term_clean) + r'\b'
    return bool(re.search(pattern, query, re.IGNORECASE))


def _has_any_match(query: str, terms: tuple) -> bool:
    return any(_matches_term(query, term) for term in terms)


def route_query(user_query):
    """Choose a domain namespace using boundary-safe technical term matching."""
    query = normalize_query_typos(user_query).lower()

    # Prioritize specific technical domains
    # Library names should win over generic structures such as arrays and lists.
    if _has_any_match(query, _PYTHON_TERMS):
        return PYTHON_DOCUMENTATION

    # Databases
    if _has_any_match(query, _DATABASE_TERMS):
        return DATABASES

    if _has_any_match(query, _COMPILER_DESIGN_TERMS):
        return COMPILER_DESIGN

    if _has_any_match(query, _THEORY_OF_COMPUTATION_TERMS):
        return THEORY_OF_COMPUTATION

    # Data structures & algorithms
    if _has_any_match(query, _DATA_STRUCTURE_TERMS):
        return DATA_STRUCTURES

    return COMPUTER_SCIENCE


def retrieval_namespaces(user_query, namespace=None):
    """Include legacy namespaces while documents are reindexed under new domains."""
    primary = namespace or route_query(user_query)
    if primary in {COMPILER_DESIGN, THEORY_OF_COMPUTATION}:
        return (primary, COMPUTER_SCIENCE, DATA_STRUCTURES)
    return (primary,)


def classify_document_domain(title="", subject="", text=""):
    """Classify a document using its path metadata, then a bounded text sample."""
    metadata = f"{title} {subject}".lower()

    if _has_any_match(metadata, _PYTHON_TERMS):
        return PYTHON_DOCUMENTATION

    db_terms_without_btree = [t for t in _DATABASE_TERMS if t not in {"b-tree", "b tree", "btree"}]
    if _has_any_match(metadata, tuple(db_terms_without_btree)):
        return DATABASES

    if _has_any_match(metadata, _COMPILER_DESIGN_TERMS):
        return COMPILER_DESIGN

    if _has_any_match(metadata, _THEORY_OF_COMPUTATION_TERMS):
        return THEORY_OF_COMPUTATION

    if _has_any_match(metadata, _DATA_STRUCTURE_TERMS):
        return DATA_STRUCTURES

    content = str(text or "")[:15000].lower()
    if _has_any_match(content, _PYTHON_TERMS):
        return PYTHON_DOCUMENTATION
    if _has_any_match(content, tuple(db_terms_without_btree)):
        return DATABASES
    if _has_any_match(content, _COMPILER_DESIGN_TERMS):
        return COMPILER_DESIGN
    if _has_any_match(content, _THEORY_OF_COMPUTATION_TERMS):
        return THEORY_OF_COMPUTATION
    if _has_any_match(content, _DATA_STRUCTURE_TERMS):
        return DATA_STRUCTURES

    return COMPUTER_SCIENCE


def is_pyq_query(user_query):
    query = normalize_query_typos(user_query).lower()
    return _has_any_match(query, _PYQ_TERMS)
