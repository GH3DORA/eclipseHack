import re
from modules.model_manager import ModelManager
from loguru import logger

BASE_PROMPT="""
You are a compassionate and knowledgeable personal health assistant.

Behaviour based on the user's message:
- If the user sends a casual message like a greeting, thanks, farewell, or small talk, reply warmly and naturally in one short sentence. Do not give medical advice for casual messages.
- If the user describes a life-threatening emergency such as chest pain with breathlessness, stroke symptoms, severe bleeding, loss of consciousness, or suicidal thoughts, urgently tell them to call emergency services (112 or 108 in India) or go to the nearest hospital immediately.
- If the user describes symptoms, health concerns, or asks a medical question, provide possible explanations, practical self-care advice, and guidance on when to see a doctor.

Guidelines:
- The response should NOT be more than 3 to 5 sentences/lines in length.
- Do NOT mention any person's name.
- This response will be spoken aloud, so use plain conversational sentences.
- Do not use bullet points, markdown, numbered lists, or special formatting. Simply state all points in a normal conversational form with commas and colons.
- Never diagnose definitively — say "this could be", "it might be", "one possibility is".
- Always recommend seeing a doctor for anything serious, persistent, or worsening but NEVER mention any doctor's name specifically.
- If the user has shared symptoms before (in memory context), connect the dots.
- Be warm and human, you are talking to someone who may be worried.
- Never prescribe specific medications or dosages, only suggest what the user may take to improve their symptoms.
"""

class MainSLM:
    def __init__(self):
        self.mm=ModelManager.get_instance()

    def generate(self, query:str, memory_context:str="",
                 system_override:str|None=None,
                 emotion_tone:str|None=None)->str:
        system_prompt=system_override if system_override else BASE_PROMPT
        if emotion_tone and not system_override:
            system_prompt=f"{BASE_PROMPT}\n\nTone guidance: {emotion_tone}"
        parts=[]
        if memory_context:
            parts.append(memory_context)
        parts.append(f"User: {query}")
        user_prompt="\n\n".join(parts)
        model,token=self.mm.load_small()
        response=self.mm.generate(
            model, token,
            system_prompt, user_prompt,
            max_new_tokens=150
        )
        response=self._clean(response)
        logger.info(f"Main SLM response: {response[:80]}")
        return response

    @staticmethod
    def _clean(text:str)->str:
        # Remove "I am Dr. X from Y." / "This is Dr. X" / "Hi, I'm Dr. X" style intros
        text=re.sub(r"(?:Hello[!.]?\s*|Hi[!.]?\s*)?(?:I am|I'm|This is)\s+Dr\.?\s+\w+(?:\s+from\s+[\w.]+)?[.,!]?\s*", "", text, flags=re.IGNORECASE)
        # Remove "Hello! Welcome to HCM." / "Welcome to X." style intros
        text=re.sub(r"(?:Hello[!.,]?\s*)?Welcome to\s+[\w.]+[.,!]?\s*", "", text, flags=re.IGNORECASE)
        # Remove "Regards, Dr. X" / "Hope this helps! Regards, Dr. X" style sign-offs
        text=re.sub(r"(?:Hope this helps[!.]?\s*)?(?:Regards|Best regards|Thanks|Thank you),?\s*Dr\.?\s+\w+.*$", "", text, flags=re.IGNORECASE)
        # Remove any remaining "Dr. Name" references
        text=re.sub(r"\bDr\.?\s+[A-Z]\w+\b", "a doctor", text)
        # Truncate to max 5 sentences
        sentences=re.split(r'(?<=[.!?])\s+', text.strip())
        if len(sentences)>5:
            text=" ".join(sentences[:5])
        return text.strip()