# core generation model.
from model_manager import ModelManager
from loguru import logger

PROMPT="""
You are a helpful, professional, and friendly customer support agent.
You assist customers with orders, returns, refunds, account issues, and general inquiries.
 
Guidelines:
  - Be concise and clear — this response will be spoken aloud
  - Do not use bullet points or markdown — plain sentences only
  - Never invent order numbers or specific details
  - If tool results are provided, use them to give a specific answer
  - If memory context is provided, use it to personalise your response
  - Keep your response under 3 sentences when possible
"""

class MainSLM:
    def __init__(self):
        self.mm=ModelManager.get_instance()

    def generate(self,query:str,memory_context:str="",tool_results:list[str] | None=None)->str:
        parts=[]
        if memory_context:
            parts.append(memory_context)
        if tool_results:
            parts.append("Information requested :")
            parts.extend(f" - {r}" for r in tool_results)
        parts.append(f"Customer query : {query}")
        user_prompt="\n\n".join(parts)
        model,token=self.mm.load_large()
        response=self.mm.generate(model,token,PROMPT,user_prompt,max_newToken=256)
        logger.info(f"Main SLM response : {response[:80]}")
        return response