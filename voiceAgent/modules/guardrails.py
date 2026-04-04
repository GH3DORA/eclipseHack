from modules.model_manager import ModelManager
from loguru import logger
from modules.memory_manager import MemoryManager

INPUT_PROMPT="""
You are a safety classifier for a personal health voice assistant.
Classify the user's message into exactly one of these labels:
VALID - a question asking advice or a health related question, symptom description, greeting, farewell, or any normal message which the assistant can reply to.
INVALID - abusive, hateful, trying to misuse the system, complete gibberish, random characters, or clearly not human input

IMPORTANT: Any health-related message is VALID, even sensitive topics.
Mentions of self-harm or suicidal thoughts are VALID - the person needs help.

Reply with ONE word only: VALID or INVALID.
"""

OUTPUT_PROMPT="""
You are a safety classifier for a personal health voice assistant.
Given the conversation context and the assistant's response, classify the response into exactly one of these labels:
VALID - helpful, asks for clarification, provides health guidance, or is a polite message
INVALID - complete off-topic nonsense unrelated to health or the conversation, or which could cause physical harm.

IMPORTANT: Asking the user for more details about their symptoms is VALID.
A polite apology or fallback message is VALID.
Responses that reference the user's symptoms or prior conversation are VALID.
Only mark INVALID if the response is truly irrelevant garbage or dangerous.
 
Reply with ONE word only: VALID or INVALID.
"""

class Guardrails:
    def __init__(self, memory_manager=None):
        self.mm=ModelManager.get_instance()
        self.memory_manager=memory_manager
    
    def _classify(self,system_prompt:str,text:str)->str:
        model,tokenizer=self.mm.load_guardrail()
        raw=self.mm.generate(model,tokenizer,system_prompt,text,max_new_tokens=5)
        label=raw.strip().upper().split()[0] if raw.strip() else "VALID"
        if label not in {"VALID","INVALID","UNSAFE"}:
            label="VALID"
        return label
    
    def check_input(self,user_query:str)->str:
        memory=self.memory_manager.get_context()
        context_text=user_query
        if memory:
            context_text=f"[Conversation context: {memory}]\n\nUser message: {user_query}"
        label=self._classify(INPUT_PROMPT,context_text)
        logger.info(f"Input guardrail - {label}")
        return label
    
    def check_output(self,assistant_response:str,user_query:str="")->str:
        memory=self.memory_manager.get_context()
        context_text=f"User asked: {user_query}\n\nAssistant response: {assistant_response}"
        if memory:
            context_text=f"[Conversation context: {memory}]\n\n{context_text}"
        label=self._classify(OUTPUT_PROMPT,context_text)
        logger.info(f"Output guardrail = {label}")
        return label