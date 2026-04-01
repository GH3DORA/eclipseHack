# convert using kokoro tts

import sounddevice as sd
from loguru import logger
from kokoro import KPipeline
from config import TTS_VOICE

class TTSModule:
    def __init__(self):
        logger.info("Loading Kokoro TTS...")
        self.pipeline=KPipeline(lang_code="a")
        self.voice=TTS_VOICE
        self.sample_rate=24000
        logger.info("Kokoro ready.")
    
    def speak(self,text:str):
        if not text.strip():
            return
        
        print(f"Agent : {text}")
        logger.info(f"TTS working...")
        try:
            generator=self.pipeline(text=text, voice=self.voice)
            for _,_,audio in generator:
                if audio is not None and len(audio)>0:
                    sd.play(audio,samplerate=self.sample_rate)
                    sd.wait()
        except Exception as e:
            logger.info(f"TTS error! {e}")
            print(f"TTS failed. Response was {text}")