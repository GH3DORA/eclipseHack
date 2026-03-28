# used to chain all the 9 modules together
# STT -> INPUT GUARDRAILS -> QUERY REWRITER -> EXECUTION ROUTER -> OUTPUT GUARDRAILS -> MEMORY MANAGER -> TTS
# for EXECUTION ROUTER, stages : ANSWER / SEARCH / PLAN / CLARIFY / ESCALATE

from loguru import logger
from modules.stt import STTModule
from modules.input_guardrails import InputGuardrails
from modules.query_rewriter import QueryRewriter
from modules.routers import ExecutionRouter, ModelRouter, RetrievalRouter
from modules.planner import Planner
from modules.verifier import Verifier
from modules.executor import Executor
from modules.memory_manager import MemoryManager
from modules.main_slm import MainSLM
from modules.tts import TTSModule

#fallbacks
_FALLBACK_INVALID = ("I'm sorry, I didn't quite catch that. Could you rephrase your question?")
_FALLBACK_UNSAFE =  ("I'm sorry, I cannot help with that. Please ask customer support related queries.")
_FALLBACK_ESCALATE = ("I will be connecting you with a human agent now. Please wait for a moment.")
_FALLBACK_CLARIFY = ("Could you please give me some more detail about your query, so i could assist you better?")
_FALLBACK_ERROR = ("I encountered a problem processing your request. Please try again later.")

class voiceAgentPipeline:
    def __init__(self):
        logger.info("Starting voice agent pipeline...")
        self.stt=STTModule()
        self.guardrails=InputGuardrails()
        self.rewriter=QueryRewriter()
        self.exec_router=ExecutionRouter()
        self.model_router=ModelRouter()
        self.retrieval_router=RetrievalRouter()
        self.planner=Planner()
        self.verifier=Verifier()
        self.executor=Executor()
        self.memory_manager=MemoryManager()
        self.main_slm=MainSLM()
        self.tts=TTSModule()
        logger.info("Pipeline is ready.")

    # PROCESSING LOGIC
    def process(self,user_text:str)->str:
        print(f"/n YOU : {user_text}")

        #input guardrails
        input_check=self.guardrails.check_input(user_text)