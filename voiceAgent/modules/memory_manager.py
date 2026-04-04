# used to extract key details from conversations for future context

from modules.model_manager import ModelManager
from loguru import logger
from config import MAX_MEMORY_FACTS

PROMPT="""
You are a memory extraction agent for a personal health assistant.
Read the conversation turn below and extract any facts useful in future turns.
Focus on: user's name, age, gender, symptoms described, duration of symptoms, severity,
known conditions, current medications, allergies, lifestyle details (smoker, diet, exercise).
Format each fact as - 
key: value
ONLY one fact per line. If no useful facts are found, reply with: NONE
"""

class MemoryManager:
    def __init__(self):
        self.mm=ModelManager.get_instance()
        self.memory:dict[str,str]={}

    def extract_and_store(self,user_query:str,agent_response:str):
        model,token=self.mm.load_small_base()
        conversation=f"\n User prompt : {user_query} \n Agent response={agent_response}"
        raw=self.mm.generate(model,token,PROMPT,conversation,max_new_tokens=128)
        if raw.strip().upper()==None:
            return
        for line in raw.strip().splitlines():
            if ":" in line:
                key,_,value=line.partition(":")
                key=key.strip().lower().replace(" ","_")
                value=value.strip()
                if key and value :
                    self.memory[key]=value
                    if len(self.memory)>MAX_MEMORY_FACTS:
                        oldest=next(iter(self.memory))
                        del self.memory[oldest]
        logger.info(f"Memory : {self.memory}")
    
    def get_context(self)->str:
        # to return memory as a string to prepend to prompts
        if not self.memory:
            return ""
        lines="\n".join(f"{k} : {v}" for k,v in self.memory.items())
        return f"Known facts about this user:\n{lines}"
    
    def clear(self):
        self.memory.clear()
        logger.info("Memory cleared.")