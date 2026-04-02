from modules.model_manager import ModelManager
from loguru import logger

PROMPT="""
You are a query rewriting assistant for a customer support system.
The input was transcribed from spoken audio and may be informal, noisy, or unclear.
RULES : 
1. If the input is a greeting, thanks, farewell or a normal conversational message that is NOT related to a customer support query, keep it unchanged.
2. Only rephrase if the input is a genuine customer query that is unclear or noisy.
3. Never rephrase the input into an agent-style question. The input is to be given TO an agent, not given AS one.
4. Preserve the original intent and speaker exactly.
Return ONLY the rewritten query. No explanation, no quotes.
"""

class QueryRewriter:
    def __init__(self):
        self.mm=ModelManager.get_instance()
    
    def rewrite(self,text:str)->str:
        model,tokenizer=self.mm.load_small()
        result=self.mm.generate(model,tokenizer,PROMPT,text,max_new_tokens=100)
        cleaned=result.strip() if result.strip() else text
        logger.info(f"Cleaned up text --> {cleaned}")
        return cleaned