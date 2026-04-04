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
        self.memories:dict[str,dict[str,str]]={}

    def _get_user_memory(self, user_id:str)->dict[str,str]:
        if user_id not in self.memories:
            self.memories[user_id]={}
        return self.memories[user_id]

    def extract_and_store(self, user_id:str, user_query:str, agent_response:str):
        # Runs in background — doesn't block response
        thread=threading.Thread(
            target=self._extract_worker,
            args=(user_id, user_query, agent_response),
            daemon=True
        )
        thread.start()

    def _extract_worker(self, user_id:str, user_query:str, agent_response:str):
        try:
            memory=self._get_user_memory(user_id)
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
                        memory[key]=value
                        if len(memory)>MAX_MEMORY_FACTS:
                            oldest=next(iter(memory))
                            del memory[oldest]
            logger.info(f"Memory updated for {user_id}: {memory}")
        except Exception as e:
            logger.warning(f"Memory extraction failed: {e}")

    def get_context(self, user_id:str)->str:
        memory=self._get_user_memory(user_id)
        if not memory:
            return ""
        lines="\n".join(f"{k}: {v}" for k,v in memory.items())
        return f"Known facts about this user:\n{lines}"

    def clear(self, user_id:str):
        if user_id in self.memories:
            del self.memories[user_id]
        logger.info(f"Memory cleared for {user_id}.")