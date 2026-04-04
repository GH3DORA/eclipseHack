# execution routing only — decides whether to answer, clarify, escalate, or chitchat

from modules.model_manager import ModelManager  
from loguru import logger

EXECUTION_PROMPT="""
You are a routing agent for a personal health assistant. Classify the user's message into ONE category.

ESCALATE — ONLY for life-threatening emergencies: chest pain with breathlessness, stroke symptoms, severe bleeding, loss of consciousness, suicidal intent.
CHITCHAT — ONLY for greetings, thanks, farewell, or casual social messages with ZERO health content.
ANSWER — ANY message that mentions symptoms, body parts, pain, conditions, medications, diet, exercise, health questions, or describes how they feel physically. This is the DEFAULT. When in doubt, choose ANSWER.

Reply with ONE word only: CHITCHAT, ANSWER, or ESCALATE.
"""

class ExecutionRouter:
    VALID={"CHITCHAT","ANSWER","ESCALATE"}
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