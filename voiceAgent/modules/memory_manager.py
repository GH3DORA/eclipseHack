import threading
from modules.model_manager import ModelManager
from loguru import logger
from config import MAX_MEMORY_FACTS

PROMPT="""
You are a memory extraction agent for a personal health assistant.
Read the conversation turn below and extract any facts useful in future turns.
Focus on: user's name, age, gender, symptoms described, duration of symptoms, severity,
known conditions, current medications, allergies, lifestyle details.
Format each fact as - 
key: value
ONLY one fact per line. If no useful facts are found, reply with: NONE
"""

class MemoryManager:
    def __init__(self):
        self.mm=ModelManager.get_instance()
        self.memory:dict[str,str]={}

    def extract_and_store(self, user_query:str, agent_response:str):
        # Runs in background — doesn't block response
        thread=threading.Thread(
            target=self._extract_worker,
            args=(user_query, agent_response),
            daemon=True
        )
        thread.start()

    def _extract_worker(self, user_query:str, agent_response:str):
        try:
            model,token=self.mm.load_small_base()
            conversation=f"\nUser: {user_query}\nAssistant: {agent_response}"
            raw=self.mm.generate(
                model, token, PROMPT,
                conversation, max_new_tokens=64
            )
            if not raw.strip() or raw.strip().upper()=="NONE":
                return
            for line in raw.strip().splitlines():
                if ":" in line:
                    key,_,value=line.partition(":")
                    key=key.strip().lower().replace(" ","_")
                    value=value.strip()
                    if key and value:
                        self.memory[key]=value
                        if len(self.memory)>MAX_MEMORY_FACTS:
                            oldest=next(iter(self.memory))
                            del self.memory[oldest]
            logger.info(f"Memory updated: {self.memory}")
        except Exception as e:
            logger.warning(f"Memory extraction failed: {e}")

    def get_context(self)->str:
        if not self.memory:
            return ""
        lines="\n".join(f"{k}: {v}" for k,v in self.memory.items())
        return f"Known facts about this user:\n{lines}"

    def clear(self):
        self.memory.clear()
        logger.info("Memory cleared.")