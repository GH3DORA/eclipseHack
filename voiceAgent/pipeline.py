# pipeline.py
# used to chain all modules together
# STT -> INPUT GUARDRAILS -> EMOTION ANALYSIS -> QUERY REWRITER -> EXECUTION ROUTER -> MAIN SLM -> OUTPUT GUARDRAILS -> MEMORY MANAGER -> TTS
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

# NEW: Import the RAG module
from modules.rag import RAGModule

# fallbacks
FALLBACK_INVALID = ("I'm sorry, I didn't quite catch that. Could you rephrase your question?")
# FALLBACK_UNSAFE =  ("I'm sorry, I cannot assist with that request. Please ask health-related questions.")
FALLBACK_ESCALATE = ("This sounds like it could be serious. Please call emergency services or visit the nearest hospital immediately. If in India, dial 112 or 108 for an ambulance.")
FALLBACK_CLARIFY = ("Could you please describe your symptoms in a bit more detail? For example, when did it start, how severe is it, and where exactly do you feel it?")
FALLBACK_ERROR = ("I encountered a problem processing your request. Please try again later.")
SYSTEM_OVERRIDE_CHITCHAT = ("You are a friendly personal health assistant. The user has sent a casual social message - a greeting, thanks, or farewell. Reply warmly and naturally in one short sentence. Do not ask any follow up questions unless it feels natural.")


class VoiceAgentPipeline:
    def __init__(self):
        logger.info("Starting personal health assistant pipeline...")
        self.stt = STTModule()
        self.guardrails = Guardrails()
        self.emotion_analyzer = EmotionAnalyzer()
        self.query_rewriter = QueryRewriter()
        self.router = ExecutionRouter()
        self.memory = MemoryManager()
        self.slm = MainSLM()
        self.tts = TTSModule()
        
        # NEW: Initialize RAG
        logger.info("Loading Knowledge Base...")
        self.rag = RAGModule(index_path="medical_knowledge.index", doc_path="medical_knowledge.json")

        self.stt=STTModule()
        self.memory_manager=MemoryManager()
        self.guardrails=Guardrails(memory_manager=self.memory_manager)
        self.emotion_analyzer=EmotionAnalyzer()
        self.rewriter=QueryRewriter()
        self.exec_router=ExecutionRouter()
        self.main_slm=MainSLM()
        self.tts=TTSModule()
        logger.info("Pipeline is ready.")

    # PROCESSING LOGIC
    def process(self,user_text:str)->str:
        print(f"\n YOU : {user_text}")
        input_status=self.guardrails.check_input(user_text)
        if input_status=="INVALID":
            return FALLBACK_INVALID
        # if input_status=="UNSAFE":
        #     return FALLBACK_UNSAFE

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
            response=self.main_slm.generate(clean_query,memory_context,emotion_tone=emotion_tone)

        output_status=self.guardrails.check_output(response,user_query=clean_query)
        if output_status in {"INVALID","UNSAFE"}:
            logger.warning(f"Output guardrail blocked response {response}")
            response="I apologise, I wasn't able to generate a suitable response. Please try again."
        self.memory_manager.extract_and_store(clean_query,response)
        return response
    
    def run(self):
        """Continuous voice loop."""
        import sounddevice as sd
        import numpy as np
        logger.info("Voice mode active. Speak now...")

        SAMPLE_RATE = 16000
        DURATION = 5  # seconds per recording chunk

        while True:
            try:
                logger.info("Listening...")
                audio = sd.rec(int(DURATION * SAMPLE_RATE), samplerate=SAMPLE_RATE, channels=1, dtype='float32')
                sd.wait()
                audio_np = np.squeeze(audio)
                self._process(audio_np, is_audio=True)
            except KeyboardInterrupt:
                logger.info("Shutting down.")
                break

    def run_text(self):
        """Continuous text loop."""
        logger.info("Text mode active. Type your question.")
        while True:
            try:
                user_input = input("You: ").strip()
                if not user_input:
                    continue
                if user_input.lower() in ["exit", "quit"]:
                    break
                self._process(user_input, is_audio=False)
            except KeyboardInterrupt:
                logger.info("Shutting down.")
                break

    def _process(self, user_audio_or_text, is_audio=True):
        """Executes the full pipeline for a single turn."""
        try:
            # 1. STT
            if is_audio:
                user_text = self.stt.transcribe(user_audio_or_text)
            else:
                user_text = user_audio_or_text
                
            if not user_text:
                return self.tts.speak(FALLBACK_INVALID)

            # 2. Input Guardrails
            if self.guardrails.check_input(user_text) != "VALID":
                return self.tts.speak(FALLBACK_UNSAFE)

            # 3. Emotion & Rewriting
            emotion = self.emotion_analyzer.analyze(user_text)
            clean_query = self.query_rewriter.rewrite(user_text, self.memory.get_context())

            # 4. Router
            route = self.router.determine_route(clean_query)

            # 5. Handle Routes (Inject RAG if needed)
            if route == "ESCALATE":
                response = FALLBACK_ESCALATE
            elif route == "CLARIFY":
                response = FALLBACK_CLARIFY
            elif route == "CHITCHAT":
                response = self.slm.generate(SYSTEM_OVERRIDE_CHITCHAT + "\nUser: " + clean_query)
            else:
                # ROUTE IS "ANSWER" -> THIS IS WHERE RAG HAPPENS
                logger.info("Retrieving medical context...")
                context = self.rag.retrieve(clean_query, top_k=2)

                # Guard: if nothing retrieved, don't hallucinate
                if not context:
                    response = "I don't have enough information on that. Please consult a doctor."
                else:
                    rag_prompt = f"""You are a medical assistant. Use ONLY the context below to answer.
Do not make up information. Be concise and clear.
Context:
{context}

User's Emotion: {emotion}
User Query: {clean_query}
Assistant:"""
                    response = self.slm.generate(rag_prompt)

            # 6. Output Guardrails & Memory
            safe_response = response if self.guardrails.check_output(response) == "VALID" else FALLBACK_ERROR
            self.memory.add_interaction(user_text, safe_response)

            # 7. TTS Output
            self.tts.speak(safe_response)

        except Exception as e:
            logger.error(f"Pipeline error: {e}")
            self.tts.speak(FALLBACK_ERROR)