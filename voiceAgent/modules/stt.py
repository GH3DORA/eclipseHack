import numpy as np
import sounddevice as sd
import torch
from faster_whisper import WhisperModel
from loguru import logger
from config import WHISPER_MODEL_SIZE,SAMPLE_RATE,RECORD_DURATION

class STTModule:
    def __init__(self):
        self.sample_rate=SAMPLE_RATE
        # Force CPU to keep GPU free for Mistral-7B
        logger.info(f"Loading Whisper ({WHISPER_MODEL_SIZE}) on cpu")
        self.model=WhisperModel(WHISPER_MODEL_SIZE,device="cpu",compute_type="int8")
        logger.info("Finished loading Whisper.")
    
    def record(self, duration:int=RECORD_DURATION)->np.ndarray:
        print(f"Recording started for {duration}s")
        audio=sd.rec(
            int(duration*self.sample_rate),
            samplerate=self.sample_rate,
            channels=1,
            dtype="float32"
        )
        sd.wait()
        return audio
    
    def transcribe(self,audio)->str:
        segments,_=self.model.transcribe(audio,"en")
        text=" ".join(seg.text for seg in segments).strip()
        logger.info(f"STT --> {text}")
        return text
    
    def listen(self)->str:
        audio=self.record(RECORD_DURATION)
        return self.transcribe(audio)