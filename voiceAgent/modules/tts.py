# convert using kokoro tts

import numpy as np
import soundfile as sf
import sounddevice as sd
from loguru import logger
try:
    from kokoro import KPipeline
    KOKORO_AVAILABLE = True
except ImportError:
    KOKORO_AVAILABLE = False
    logger.warning("Kokoro TTS is not installed. TTS will be disabled.")

from config import TTS_VOICE

class TTSModule:
    def __init__(self):
        if KOKORO_AVAILABLE:
            logger.info("Loading Kokoro TTS...")
            self.pipeline=KPipeline(lang_code="a")
            self.voice=TTS_VOICE
            self.sample_rate=24000
            logger.info("Kokoro ready.")
        else:
            self.pipeline = None
            self.sample_rate = 24000
    
    def speak(self,text:str):
        if not text.strip() or not KOKORO_AVAILABLE:
            if not KOKORO_AVAILABLE:
                print(f"Agent : {text} (TTS disabled)")
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

    def synthesize_to_file(self, text: str, output_path: str):
        if not text.strip() or not KOKORO_AVAILABLE:
            return
        logger.info(f"Synthesizing '{text}' to {output_path}")
        try:
            generator = self.pipeline(text=text, voice=self.voice)
            audio_chunks = []
            for _,_,audio in generator:
                if audio is not None and len(audio)>0:
                    audio_chunks.append(audio)
            
            if audio_chunks:
                full_audio = np.concatenate(audio_chunks)
                sf.write(output_path, full_audio, self.sample_rate)
                logger.info(f"Saved audio to {output_path}")
        except Exception as e:
            logger.error(f"TTS to file error! {e}")