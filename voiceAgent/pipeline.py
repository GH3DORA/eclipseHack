# pipeline.py
# used to chain all modules together
# STT -> EMOTION CLASSIFIER -> QUERY REWRITER -> RAG -> MAIN SLM -> MEMORY MANAGER -> TTS

from loguru import logger
from modules.stt import STTModule
from modules.combined_classifier import CombinedClassifier 
from modules.query_rewriter import QueryRewriter
from modules.memory_manager import MemoryManager
from modules.main_slm import MainSLM
from modules.tts import TTSModule
from modules.rag import RAGModule

# fallbacks
FALLBACK_ERROR = ("I encountered a problem processing your request. Please try again later.")


class VoiceAgentPipeline:
    def __init__(self):
        logger.info("Starting personal health assistant pipeline...")
        self.stt=STTModule()
        self.memory_manager=MemoryManager()
        self.classifier=CombinedClassifier()   
        self.rewriter=QueryRewriter()
        self.main_slm=MainSLM()
        self.tts=TTSModule()

        # RAG knowledge base
        logger.info("Loading Knowledge Base...")
        self.rag=RAGModule(index_path="medical_knowledge.index", doc_path="medical_knowledge.json")
        logger.info("Pipeline is ready.")


    # PROCESSING LOGIC
    def process(self,user_text:str,user_id:str="local_user")->str:
        print(f"\n YOU : {user_text}")
        emotion,emotion_tone=self.classifier.classify(user_text)
        print(f" [Emotion: {emotion}]")

        clean_query=self.rewriter.rewrite(user_text)
        memory_context=self.memory_manager.get_context(user_id)

        # Default route: ANSWER with RAG augmentation when available
        logger.info("Retrieving medical context via RAG...")
        rag_context=self.rag.retrieve(clean_query, top_k=2)

        if rag_context:
            augmented_query=f"Relevant medical knowledge:\n{rag_context}\n\nPatient query: {clean_query}"
            response=self.main_slm.generate(augmented_query,memory_context,emotion_tone=emotion_tone)
        else:
            response=self.main_slm.generate(clean_query,memory_context,emotion_tone=emotion_tone)

        self.memory_manager.extract_and_store(user_id,clean_query,response)
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