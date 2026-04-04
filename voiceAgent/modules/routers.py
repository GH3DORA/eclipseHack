# execution routing — rule-based for reliability, no LLM needed
# CHITCHAT and ESCALATE have clear keyword patterns; everything else is ANSWER

import re
from loguru import logger

# patterns that indicate pure chitchat (no health content)
CHITCHAT_PATTERNS=re.compile(
    r"^(hi|hello|hey|good morning|good evening|good afternoon|good night|"
    r"bye|goodbye|see you|thanks|thank you|ok|okay|sure|"
    r"how are you|what's up|whats up|who are you|what is your name)[\s!?.]*$",
    re.IGNORECASE
)

# keywords that signal a medical emergency
ESCALATE_KEYWORDS=[
    "chest pain", "can't breathe", "cannot breathe", "difficulty breathing",
    "heart attack", "stroke", "seizure", "unconscious", "passed out",
    "severe bleeding", "heavy bleeding", "choking",
    "want to die", "want to kill myself", "suicidal", "end my life",
    "overdose", "poisoning"
]

# health-related keywords — if any are present, it's definitely ANSWER not CHITCHAT
HEALTH_KEYWORDS=[
    "pain", "ache", "hurt", "fever", "sick", "ill", "symptom",
    "headache", "nausea", "vomit", "cough", "cold", "sneeze",
    "weak", "tired", "fatigue", "dizzy", "swollen", "rash",
    "infection", "medication", "medicine", "doctor", "hospital",
    "blood", "pressure", "sugar", "diabetes", "allergy",
    "stomach", "chest", "throat", "back", "joint", "muscle",
    "breathing", "sleep", "weight", "diet", "exercise",
    "feeling", "feverish", "sweating", "body", "energy",
]

class ExecutionRouter:
    def __init__(self):
        pass

    def route(self,query:str)->str:
        q=query.lower().strip()

        # check escalation first (life-threatening)
        for kw in ESCALATE_KEYWORDS:
            if kw in q:
                logger.info("Route: ESCALATE")
                return "ESCALATE"

        # check if any health keyword is present — if so, skip chitchat check
        has_health=any(kw in q for kw in HEALTH_KEYWORDS)
        if has_health:
            logger.info("Route: ANSWER")
            return "ANSWER"

        # pure chitchat — only if message is short and matches greeting/farewell pattern
        if CHITCHAT_PATTERNS.match(q):
            logger.info("Route: CHITCHAT")
            return "CHITCHAT"

        # default: ANSWER
        logger.info("Route: ANSWER")
        return "ANSWER"