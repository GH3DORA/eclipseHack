# used to chain all the 9 modules together
# STT -> INPUT GUARDRAILS -> QUERY REWRITER -> EXECUTION ROUTER -> OUTPUT GUARDRAILS -> MEMORY MANAGER -> TTS
# for EXECUTION ROUTER, stages : ANSWER / SEARCH / PLAN / CLARIFY / ESCALATE

from loguru import logger
from modules.stt import STTModule
from voiceAgent.modules.guardrails import Guardrails
from modules.query_rewriter import QueryRewriter
from modules.routers import ExecutionRouter, ModelRouter, RetrievalRouter
from modules.planner import Planner
from modules.verifier import Verifier
from modules.executor import Executor
from modules.memory_manager import MemoryManager
from modules.main_slm import MainSLM
from modules.tts import TTSModule

#fallbacks
FALLBACK_INVALID = ("I'm sorry, I didn't quite catch that. Could you rephrase your question?")
FALLBACK_UNSAFE =  ("I'm sorry, I cannot help with that. Please ask customer support related queries.")
FALLBACK_ESCALATE = ("I will be connecting you with a human agent now. Please wait for a moment.")
FALLBACK_CLARIFY = ("Could you please give me some more detail about your query, so i could assist you better?")
FALLBACK_ERROR = ("I encountered a problem processing your request. Please try again later.")

class VoiceAgentPipeline:
    def __init__(self):
        logger.info("Starting voice agent pipeline...")
        self.stt=STTModule()
        self.guardrails=Guardrails()
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
        input_status=self.guardrails.check_input(user_text)
        if input_status=="INVALID":
            return FALLBACK_INVALID
        if input_status=="UNSAFE":
            return FALLBACK_UNSAFE
        clean_query=self.rewriter.rewrite(user_text)
        memory_context=self.memory_manager.get_context()
        exec_route=self.exec_router.route(clean_query)
        tool_results:list[str]=[]
        response:str=""

        #route based branching
        if exec_route=="CLARIFY":
            response=FALLBACK_CLARIFY
        elif exec_route=="ESCALATE":
            response=FALLBACK_ESCALATE
        elif exec_route=="SEARCH":
            data_source=self.retrieval_router.route(clean_query)
            search_step=f"Search {data_source} for: {clean_query}"
            search_result=self.executor.execute_step(search_step,context=memory_context)
            tool_results.append(search_result)
            response=self.main_slm.generate(clean_query,memory_context,tool_results)
        elif exec_route=="PLAN":
            plan=self.planner.plan(clean_query)
            is_valid,reason=self.verifier.verify(clean_query,plan)
            if not is_valid:
                logger.info(f"Plan rejected, it is not valid. Reason - {reason}")
                plan=self.planner.plan("Please help : {clean_query}")
            tool_results=self.executor.execute_plan(plan,memory_context)
            response=self.main_slm.generate(clean_query,memory_context,tool_results)
        else : 
            response=self.main_slm.generate(clean_query,memory_context)
        output_status=self.guardrails.check_output(response)
        if output_status in {"INVALID","UNSAFE"}:
            logger.warning(f"Output guardrail blocked response {response}")
            response="I apologise, i wasn't able to generate a suitable response. Please try again."
        self.memory_manager.extract_and_store(clean_query,response)
        return response
    
    def run(self):
        print("\n"+"="*50)
        print("  SLM Based Voice Customer Support Agent  ")
        print("="*50)
        print("Speak after microphone prompt appears")
        print("Type 'text' to switch to text mode")
        print("Press Ctrl+C to exit.")

        while True:
            try:
                user_text=self.stt.listen()
                if not user_text.strip():
                    print("No voice recorded, try again.")
                response=self.process(user_text)
                self.tts.speak(response)
            except KeyboardInterrupt:
                print("Turning off.")
                break
            except Exception as e:
                logger.exception(f"Unexpected pipeline error : {e}")
                self.tts.speak(FALLBACK_ERROR)
                break
    def run_text(self):
        print("\n"+"="*50)
        print("  SLM Based Text Customer Support Agent  ")
        print("="*50)
        print("Type your query and press Enter. Press Ctrl+C to exit.")
        while True:
            try:
                user_input=input("You : ").strip()
                if not user_input:
                    continue
                if user_input.lower() in {"exit","quit","goodbye","bye","thanks","thank you"}:
                    print("Goodbye!")
                    break
                response=self.process(user_input)
                self.tts.speak(response)
            except KeyboardInterrupt:
                print("Turning off.")
                break
            except Exception as e:
                logger.exception(f"Encountered an unexpected error : {e}")
                self.tts.speak(FALLBACK_ERROR)
                break