# detects patient emotional state from text to adapt response tone
# runs on the small model to keep latency low

from modules.model_manager import ModelManager
from loguru import logger
from config import EMOTION_LABELS

PROMPT="""
You are an emotion classifier for a medical support voice agent.
Analyse the patient's message and classify their emotional state into exactly one label:
  neutral    — calm, informational, matter-of-fact
  anxious    — worried, scared, fearful about health
  frustrated — angry, impatient, dissatisfied with care or wait times
  sad        — feeling low, hopeless, grieving
  grateful   — thankful, relieved, appreciative
  confused   — unsure, overwhelmed, does not understand medical terms

Reply with ONE word only: neutral, anxious, frustrated, sad, grateful, or confused.
"""

# maps emotion to a tone instruction injected into the main SLM system prompt
EMOTION_TONE_MAP={
    "neutral":    "Respond in a calm, professional, and informative manner.",
    "anxious":    "The patient is anxious. Be extra reassuring and gentle. Acknowledge their worry before giving information. Use calming language.",
    "frustrated": "The patient is frustrated. Acknowledge their frustration empathetically. Be direct, solution-oriented, and avoid dismissive language.",
    "sad":        "The patient sounds sad or low. Be warm, compassionate, and supportive. Show you care. Gently encourage them.",
    "grateful":   "The patient is grateful. Respond warmly and positively. Reinforce their good feelings.",
    "confused":   "The patient is confused. Use simple, clear language. Avoid medical jargon. Explain step by step.",
}

class EmotionAnalyzer:
    def __init__(self):
        self.mm=ModelManager.get_instance()

    def detect(self, text: str) -> str:
        model, tokenizer = self.mm.load_small_base()
        raw = self.mm.generate(model, tokenizer, PROMPT, text, max_new_tokens=5)
        label = raw.strip().lower().split()[0] if raw.strip() else "neutral"
        if label not in EMOTION_LABELS:
            label = "neutral"
        logger.info(f"Emotion detected: {label}")
        return label

    def get_tone_instruction(self, emotion: str) -> str:
        return EMOTION_TONE_MAP.get(emotion, EMOTION_TONE_MAP["neutral"])
