from modules.model_manager import ModelManager
from loguru import logger

PROMPT="""
You are a query rewriting assistant for a personal health assistant.
The input was transcribed from spoken audio and may be informal, noisy, or unclear.
RULES:
1. If the input is a greeting, thanks, farewell, or casual message, keep it unchanged.
2. Only rephrase if the input is a health query that is unclear or noisy from transcription.
3. Preserve the user's exact symptoms, feelings, and descriptions.
4. Do not add medical terms the user did not use.
5. Do not turn the message into a doctor's question. Keep the user's perspective.
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