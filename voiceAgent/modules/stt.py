import numpy as np
import sounddevice as sd
import torch
from faster_whisper import WhisperModel
from loguru import logger
from config import WHISPER_MODEL_SIZE,SAMPLE_RATE,RECORD_DURATION

class STTModule:
    def __init__(self):
        device="cuda" if torch.cuda.is_available() else "cpu"
        self.sample_rate=SAMPLE_RATE
        compute_type="float16" if device=="cuda" else "int8"
        logger.info(f"Loading Whisper ({WHISPER_MODEL_SIZE}) on {device}")
        self.model=WhisperModel(WHISPER_MODEL_SIZE,device=device,compute_type=compute_type)
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
    
    def transcribe(self,audio:np.ndarray)->str:
        segments,_=self.model.transcribe(audio,"en")
        text=" ".join(seg.text for seg in segments).strip()
        logger.info(f"STT --> {text}")
        return text
    
    def listen(self)->str:
        audio=self.record(RECORD_DURATION)
        return self.transcribe(audio)