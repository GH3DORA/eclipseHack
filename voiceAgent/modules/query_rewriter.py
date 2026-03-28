from model_manager import ModelManager
from loguru import logger

PROMPT="""
You are a query rewriting assistant for a customer support system.
The input was transcribed from spoken audio and may be informal, noisy, or unclear.
Rewrite it as a clean, concise customer support query — preserve the original intent exactly.
Return ONLY the rewritten query. No explanation, no quotes.
"""

class QueryRewriter:
    def __init__(self):
        self.mm=ModelManager.get_instance()
    
    def rewrite(self,text:str)->str:
        model,tokenizer=self.mm.load_small()
        result=self.mm.generate(model,tokenizer,PROMPT,text,max_newToken=100)
        cleaned=result.strip() if result.strip() else text
        logger.info(f"Cleaned up text --> {cleaned}")
        return cleaned