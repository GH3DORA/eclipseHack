from modules.model_manager import ModelManager
from loguru import logger

INPUT_PROMPT="""
You are a safety classifier for a customer support voice agent.
Classify the user message into exactly one of these labels:
  VALID   — a legitimate customer support question
  INVALID — off-topic, gibberish, or not related to customer support
  UNSAFE  — abusive, harmful, or inappropriate content
 
Reply with ONE word only: VALID, INVALID, or UNSAFE.
"""

OUTPUT_PROMPT="""
You are a safety classifier for a customer support voice agent.
Classify the agent's response into exactly one of these labels:
  VALID   — appropriate, helpful, and safe
  INVALID — does not address the customer's query
  UNSAFE  — contains harmful or inappropriate content
 
Reply with ONE word only: VALID, INVALID, or UNSAFE.
"""

class Guardrails:
    def __init__(self):
        self.mm=ModelManager.get_instance()
    
    def _classify(self,system_prompt:str,text:str)->str:
        model,tokenizer=self.mm.load_small()
        raw=self.mm.generate(model,tokenizer,system_prompt,text,max_newToken=5)
        label=raw.strip().upper().split()[0] if raw.strip() else "VALID"
        if label not in {"VALID","INVALID","UNSAFE"}:
            label="VALID"
        return label
    
    def check_input(self,user_query:str)->str:
        label=self._classify(INPUT_PROMPT,user_query)
        logger.info(f"Input guardrail - {label}")
        return label
    
    def check_output(self,user_query:str)->str:
        label=self._classify(OUTPUT_PROMPT,user_query)
        logger.info(f"Output guardrail = {label}")
        return label