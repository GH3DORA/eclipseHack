# execution routing only — decides whether to answer, clarify, escalate, or chitchat

from modules.model_manager import ModelManager  
from loguru import logger

EXECUTION_PROMPT="""
You are a routing agent for a personal health assistant.
Given the user's message, choose the best action:
CHITCHAT - greeting, thanks, farewell, or casual social message not about health.
ANSWER — the user is describing symptoms, asking about a condition, medication, diet, exercise, or any health topic. This is the default for anything health-related.
CLARIFY — the user's message is too vague to give useful health advice (e.g. just "I feel bad" with no details).
ESCALATE — the user describes an emergency: chest pain with breathlessness, signs of stroke, severe bleeding, loss of consciousness, suicidal thoughts, or any life-threatening situation.

Reply with ONE word only: CHITCHAT, ANSWER, CLARIFY, or ESCALATE.
"""

class ExecutionRouter:
    VALID={"CHITCHAT","ANSWER","CLARIFY","ESCALATE"}
    def __init__(self):
        self.mm=ModelManager.get_instance()

    def route(self,query:str)->str:
        model,token=self.mm.load_small_base()
        raw=self.mm.generate(model,token,EXECUTION_PROMPT,query,max_new_tokens=5)
        label=raw.strip().upper().split()[0] if raw.strip() else "ANSWER"
        if label not in self.VALID:
            label="ANSWER"
        logger.info(f"Route: {label}")
        return label