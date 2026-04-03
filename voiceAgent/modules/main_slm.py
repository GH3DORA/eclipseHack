# core generation model — emotion-aware personal health assistant
from modules.model_manager import ModelManager
from loguru import logger

BASE_PROMPT="""
You are a compassionate and knowledgeable personal health assistant.
A user will describe their symptoms, feelings, or health concerns, and you provide:
  - Possible explanations or conditions that match their symptoms
  - Practical self-care advice and home remedies where appropriate
  - When they should see a doctor

Guidelines:
  - This response will be spoken aloud, so use plain conversational sentences
  - Do not use bullet points, markdown, numbered lists, or special formatting
  - Never diagnose definitively — say "this could be", "it might be", "one possibility is"
  - Always recommend seeing a doctor for anything serious, persistent, or worsening
  - If the user has shared symptoms before (in memory context), connect the dots
  - Be warm and human — you are talking to someone who may be worried
  - Keep responses to 3-5 sentences
  - Never prescribe specific medications or dosages
"""

class MainSLM:
    def __init__(self):
        self.mm=ModelManager.get_instance()

    def generate(self,query:str,memory_context:str="",system_override:str | None=None, emotion_tone:str | None=None)->str:
        system_prompt=system_override if system_override else BASE_PROMPT
        if emotion_tone and not system_override:
            system_prompt=f"{BASE_PROMPT}\n\nEMOTIONAL CONTEXT: {emotion_tone}"
        parts=[]
        if memory_context:
            parts.append(memory_context)
        parts.append(f"User: {query}")
        user_prompt="\n\n".join(parts)
        model,token=self.mm.load_large()
        response=self.mm.generate(model,token,system_prompt,user_prompt,max_new_tokens=256)
        logger.info(f"Main SLM response : {response[:80]}")
        return response