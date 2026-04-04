from modules.model_manager import ModelManager
from loguru import logger

PROMPT="""
You are a query cleanup assistant. The input was transcribed from spoken audio.
Your ONLY job is to fix transcription noise (misheard words, broken grammar).

CRITICAL RULES:
- The input is FROM A PATIENT describing their problem. Keep it in first person ("I", "my", "me").
- NEVER rewrite it as a question from a doctor or assistant.
- If the input is already clear, return it EXACTLY as-is.
- Do NOT add medical terminology.
- Do NOT change the meaning.

Examples:
  Input: "im having pain in my chest what do i do" → "I'm having pain in my chest, what do I do?"
  Input: "my head hurts real bad since morning" → "My head hurts really bad since morning."
Return ONLY the cleaned query. Nothing else.
"""

class QueryRewriter:
    def __init__(self):
        self.mm=ModelManager.get_instance()
    
    def rewrite(self,text:str)->str:
        model,tokenizer=self.mm.load_small_base()
        result=self.mm.generate(model,tokenizer,PROMPT,text,max_new_tokens=100)
        cleaned=result.strip() if result.strip() else text
        logger.info(f"Cleaned up text --> {cleaned}")
        return cleaned