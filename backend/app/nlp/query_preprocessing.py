import re


_MARK_ALLOCATION_PATTERN = re.compile(
    r"[\[(]\s*\d+\s*marks?\s*[\])]",
    re.IGNORECASE,
)
_QUESTION_PREFIX_PATTERN = re.compile(
    r"^\s*(?:(?:q(?:uestion)?\s*\.?\s*\d+[a-z]?[.)]?)|"
    r"(?:\d+|[a-z])[.)])\s*",
    re.IGNORECASE,
)
_TYPO_CORRECTIONS = {
    "deadlok": "deadlock",
    "lexcal": "lexical",
    "linkd": "linked",
}


def clean_query(query_text):
    query = str(query_text or "")
    query = _MARK_ALLOCATION_PATTERN.sub(" ", query)
    query = _QUESTION_PREFIX_PATTERN.sub("", query)
    query = re.sub(r"\s+", " ", query)
    return query.strip().rstrip(" \t\r\n.,!?;:")


def normalize_query_typos(query_text):
    return normalize_known_typos(clean_query(query_text))


def normalize_known_typos(query_text):
    query = str(query_text or "")
    if not query:
        return ""

    def replace_typo(match):
        word = match.group(0)
        correction = _TYPO_CORRECTIONS[word.casefold()]
        if word.isupper():
            return correction.upper()
        if word.istitle():
            return correction.capitalize()
        return correction

    pattern = re.compile(
        r"\b(" + "|".join(map(re.escape, _TYPO_CORRECTIONS)) + r")\b",
        re.IGNORECASE,
    )
    return pattern.sub(replace_typo, query)
