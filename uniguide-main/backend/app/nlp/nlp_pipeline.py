from spellchecker import SpellChecker
import re

class NLPPipeline:
    """
    NLP preprocessing for UniGuide:
    - Corrects spelling mistakes
    - Detects intent (answer / important_topics / marks-specific)
    - Extracts marks if mentioned
    - Simplifies question text if needed
    """

    def __init__(self):
        self.spell = SpellChecker()

    def correct_spelling(self, text: str) -> str:
        words = text.split()
        corrected = [self.spell.correction(word) for word in words]
        return " ".join(corrected)

    def detect_intent(self, question: str):
        q_lower = question.lower()
        intent = "answer"
        marks = None

        if "important topics" in q_lower:
            intent = "important_topics"
        else:
            # Detect if marks mentioned
            match = re.search(r'(\d+)\s*marks', q_lower)
            if match:
                marks = int(match.group(1))
                intent = "answer"

        return {"intent": intent, "marks": marks}

    def process_question(self, question: str):
        """
        Run full NLP pipeline on question
        Returns:
            - cleaned_question: corrected text
            - intent: parsed intent
            - marks: parsed marks (if any)
        """
        corrected = self.correct_spelling(question)
        intent_info = self.detect_intent(corrected)
        return corrected, intent_info["intent"], intent_info["marks"]