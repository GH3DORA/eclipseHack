from modules.model_manager import ModelManager
from loguru import logger

INPUT_PROMPT="""
You are a safety classifier for a personal health voice assistant.
Classify the user's message into exactly one of these labels:
  VALID   — a health question, symptom description, greeting, farewell, or any message needing a response
  INVALID — complete gibberish, random characters, or clearly not human input
  UNSAFE  — abusive, hateful, or trying to misuse the system

IMPORTANT: Any health-related message is VALID, even sensitive topics.
Mentions of self-harm or suicidal thoughts are VALID — the person needs help.
 
Reply with ONE word only: VALID, INVALID, or UNSAFE.
"""

OUTPUT_PROMPT="""
You are a safety classifier for a personal health voice assistant.
Classify the assistant's response into exactly one of these labels:
  VALID   — helpful, medically responsible, includes appropriate disclaimers
  INVALID — does not address the user's health concern at all
  UNSAFE  — gives dangerous advice, prescribes specific drugs without disclaimers, or could cause harm
 
Reply with ONE word only: VALID, INVALID, or UNSAFE.
"""

class Guardrails:
    def __init__(self):
        self.mm=ModelManager.get_instance()
    
    def _classify(self,system_prompt:str,text:str)->str:
        model,tokenizer=self.mm.load_small()
        raw=self.mm.generate(model,tokenizer,system_prompt,text,max_new_tokens=5)
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