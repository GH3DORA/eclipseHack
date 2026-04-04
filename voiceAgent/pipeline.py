# pipeline.py
# used to chain all modules together
# STT -> INPUT GUARDRAILS -> EMOTION ANALYSIS -> QUERY REWRITER -> EXECUTION ROUTER -> RAG -> MAIN SLM -> OUTPUT GUARDRAILS -> MEMORY MANAGER -> TTS
# for EXECUTION ROUTER, stages : ANSWER / CHITCHAT / CLARIFY / ESCALATE

from loguru import logger
from modules.stt import STTModule
from modules.guardrails import Guardrails
from modules.emotion_analyzer import EmotionAnalyzer
from modules.query_rewriter import QueryRewriter
from modules.routers import ExecutionRouter
from modules.memory_manager import MemoryManager
from modules.main_slm import MainSLM
from modules.tts import TTSModule
from modules.rag import RAGModule

# fallbacks
FALLBACK_INVALID = ("I'm sorry, I didn't quite catch that. Could you rephrase your question?")
FALLBACK_ESCALATE = ("This sounds like it could be serious. Please call emergency services or visit the nearest hospital immediately. If in India, dial 112 or 108 for an ambulance.")
FALLBACK_CLARIFY = ("Could you please describe your symptoms in a bit more detail? For example, when did it start, how severe is it, and where exactly do you feel it?")
FALLBACK_ERROR = ("I encountered a problem processing your request. Please try again later.")
SYSTEM_OVERRIDE_CHITCHAT = ("You are a friendly personal health assistant. The user has sent a casual social message - a greeting, thanks, or farewell. Reply warmly and naturally in one short sentence. Do not ask any follow up questions unless it feels natural.")


class VoiceAgentPipeline:
    def __init__(self):
        logger.info("Starting personal health assistant pipeline...")
        self.stt=STTModule()
        self.memory_manager=MemoryManager()
        self.guardrails=Guardrails(memory_manager=self.memory_manager)
        self.emotion_analyzer=EmotionAnalyzer()
        self.rewriter=QueryRewriter()
        self.exec_router=ExecutionRouter()
        self.main_slm=MainSLM()
        self.tts=TTSModule()

        # RAG knowledge base
        logger.info("Loading Knowledge Base...")
        self.rag=RAGModule(index_path="medical_knowledge.index", doc_path="medical_knowledge.json")
        logger.info("Pipeline is ready.")
        
        # NEW: Initialize RAG
        logger.info("Loading Knowledge Base...")
        self.rag = RAGModule(index_path="medical_knowledge.index", doc_path="medical_knowledge.json")


    # PROCESSING LOGIC
    def process(self,user_text:str)->str:
        print(f"\n YOU : {user_text}")
        input_status=self.guardrails.check_input(user_text)
        if input_status=="INVALID":
            return FALLBACK_INVALID

        # emotion detection
        emotion=self.emotion_analyzer.detect(user_text)
        emotion_tone=self.emotion_analyzer.get_tone_instruction(emotion)
        print(f" [Emotion: {emotion}]")

        clean_query=self.rewriter.rewrite(user_text)
        memory_context=self.memory_manager.get_context()
        exec_route=self.exec_router.route(clean_query)

        #route based branching
        if exec_route=="CHITCHAT":
            response=self.main_slm.generate(clean_query,memory_context,system_override=SYSTEM_OVERRIDE_CHITCHAT)
        elif exec_route=="CLARIFY":
            response=FALLBACK_CLARIFY
        elif exec_route=="ESCALATE":
            response=FALLBACK_ESCALATE
        else:
            # ANSWER — the main path: symptom analysis, diagnosis, health advice
            # Use RAG to retrieve relevant medical context
            logger.info("Retrieving medical context via RAG...")
            rag_context=self.rag.retrieve(clean_query, top_k=2)

            if rag_context:
                # Augment the query with retrieved knowledge
                augmented_query=f"Relevant medical knowledge:\n{rag_context}\n\nPatient query: {clean_query}"
                response=self.main_slm.generate(augmented_query,memory_context,emotion_tone=emotion_tone)
            else:
                # No RAG results — fall back to model's own knowledge
                response=self.main_slm.generate(clean_query,memory_context,emotion_tone=emotion_tone)

        output_status=self.guardrails.check_output(response,user_query=clean_query)
        if output_status in {"INVALID","UNSAFE"}:
            logger.warning(f"Output guardrail blocked response {response}")
            response="I apologise, I wasn't able to generate a suitable response. Please try again."
        self.memory_manager.extract_and_store(clean_query,response)
        return response
    
    def run(self):
        print("\n"+"="*50)
        print("  Personal Health Voice Assistant  ")
        print("="*50)
        print("Speak after microphone prompt appears")
        print("Press Ctrl+C to exit.")

        while True:
            try:
                user_text=self.stt.listen()
                if not user_text.strip():
                    print("No voice recorded, try again.")
                    continue
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
        print("  Personal Health Text Assistant  ")
        print("="*50)
        print("Type your health query and press Enter. Press Ctrl+C to exit.")
        while True:
            try:
                user_input=input("You : ").strip()
                if not user_input:
                    continue
                if user_input.lower() in {"exit","quit","goodbye","bye","thanks","thank you"}:
                    print("Goodbye! Take care of your health!")
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
