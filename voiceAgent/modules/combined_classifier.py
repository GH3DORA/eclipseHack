# modules/combined_classifier.py
# Single LLM call: emotion classification only (safety handled by main SLM)
from modules.model_manager import ModelManager
from loguru import logger
from config import EMOTION_LABELS

EMOTION_PROMPT="""Classify the emotional state of this message into exactly ONE word:
neutral, anxious, frustrated, sad, grateful, or confused.
Reply with ONE word only."""

EMOTION_TONE_MAP={
    "neutral":    "Respond in a calm, professional, and informative manner.",
    "anxious":    "The patient is anxious. Be extra reassuring and gentle. Acknowledge their worry before giving information.",
    "frustrated": "The patient is frustrated. Acknowledge their frustration empathetically. Be direct and solution-oriented.",
    "sad":        "The patient sounds sad or low. Be warm, compassionate, and supportive. Gently encourage them.",
    "grateful":   "The patient is grateful. Respond warmly and positively. Reinforce their good feelings.",
    "confused":   "The patient is confused. Use simple, clear language. Avoid jargon. Explain step by step.",
}

class CombinedClassifier:
    def __init__(self):
        self.mm = ModelManager.get_instance()

    def classify(self, query: str) -> tuple[str, str]:
        """Returns (emotion, emotion_tone)."""
        model, token = self.mm.load_small_base()
        raw = self.mm.generate(
            model, token,
            EMOTION_PROMPT, query,
            max_new_tokens=5
        )
        emotion = raw.strip().lower().split()[0] if raw.strip() else "neutral"
        if emotion not in EMOTION_LABELS:
            emotion = "neutral"

        tone = EMOTION_TONE_MAP.get(emotion, EMOTION_TONE_MAP["neutral"])
        logger.info(f"Classifier: emotion={emotion}")
        return emotion, tone