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