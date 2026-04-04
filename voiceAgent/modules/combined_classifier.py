# modules/combined_classifier.py — NEW FILE
from modules.model_manager import ModelManager
from loguru import logger

COMBINED_PROMPT="""
You are a classifier for a personal health voice assistant.
Given the user message, reply with exactly TWO words on one line:

Word 1 - Safety: VALID or INVALID
Word 2 - Route: ANSWER, CHITCHAT, CLARIFY, or ESCALATE

Rules for Safety:
VALID = any health question, symptom, greeting, or normal message
INVALID = abusive, gibberish, random characters, clear misuse

Rules for Route:
CHITCHAT = greeting, thanks, farewell, casual message
ANSWER = symptoms, health question, medication, advice
CLARIFY = too vague to help (e.g. just "I feel bad")
ESCALATE = emergency: chest pain + breathlessness, stroke, severe bleeding, suicidal thoughts

Example outputs:
VALID ANSWER
VALID CHITCHAT
VALID ESCALATE
INVALID ANSWER

Reply with exactly two words only.
"""

class CombinedClassifier:
    def __init__(self):
        self.mm = ModelManager.get_instance()

    def classify(self, query: str) -> tuple[str, str]:
        model, token = self.mm.load_small_base()
        raw = self.mm.generate(
            model, token,
            COMBINED_PROMPT, query,
            max_new_tokens=5
        )
        parts = raw.strip().upper().split()
        safety = parts[0] if parts else "VALID"
        route = parts[1] if len(parts) > 1 else "ANSWER"

        if safety not in {"VALID", "INVALID"}:
            safety = "VALID"
        if route not in {"ANSWER", "CHITCHAT", "CLARIFY", "ESCALATE"}:
            route = "ANSWER"

        logger.info(f"Classifier: safety={safety} route={route}")
        return safety, route