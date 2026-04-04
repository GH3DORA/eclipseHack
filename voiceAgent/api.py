from fastapi import FastAPI, UploadFile, File, Form, HTTPException
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import uvicorn
import os
import uuid
import asyncio
import sqlite3
from loguru import logger
import shutil

from pipeline import VoiceAgentPipeline

app = FastAPI(title="SLM Voice Agent Engine")

# --- DATABASE SETUP ---
DB_FILE = "chat_history.db"

def init_db():
    conn = sqlite3.connect(DB_FILE)
    c = conn.cursor()
    c.execute('''
        CREATE TABLE IF NOT EXISTS chats (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_text TEXT NOT NULL,
            ai_text TEXT NOT NULL,
            timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    conn.commit()
    conn.close()

def save_chat(user_text: str, ai_text: str):
    conn = sqlite3.connect(DB_FILE)
    c = conn.cursor()
    c.execute("INSERT INTO chats (user_text, ai_text) VALUES (?, ?)", (user_text, ai_text))
    # Keep only the last 10 chats
    c.execute('''
        DELETE FROM chats 
        WHERE id NOT IN (
            SELECT id FROM chats ORDER BY id DESC LIMIT 10
        )
    ''')
    conn.commit()
    conn.close()

@app.get("/chat/history")
def get_history():
    """Retrieve the last 10 chats"""
    conn = sqlite3.connect(DB_FILE)
    c = conn.cursor()
    c.execute("SELECT user_text, ai_text, timestamp FROM chats ORDER BY id ASC")
    rows = c.fetchall()
    conn.close()
    return [{"user": r[0], "ai": r[1], "timestamp": r[2]} for r in rows]

init_db()
# ----------------------

# Enable CORS for Flutter frontend
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

os.makedirs("audio_output", exist_ok=True)
os.makedirs("audio_input", exist_ok=True)

# Mount the output directory so Flutter can download the TTS responses
app.mount("/static", StaticFiles(directory="audio_output"), name="static")

agent = VoiceAgentPipeline()

@app.on_event("startup")
def preload_models():
    """ Pre-warm the models during server startup so the first request is instant! """
    logger.info("[API] Pre-warming models for instantaneous response...")       
    from modules.model_manager import ModelManager
    mm = ModelManager.get_instance()
    mm.load_small()
    mm.load_large()
    # Dummy inferences to compile CUDA graphs / initialize caches
    logger.info("[API] Warmup: Small Model")
    mm.generate(mm.small_model, mm.small_tokenizer, "System", "Test", max_new_tokens=2)
    logger.info("[API] Warmup: Large Model")
    mm.generate(mm.large_model, mm.large_tokenizer, "System", "Test", max_new_tokens=2)
    # Pre-warm TTS and STT
    logger.info("[API] Warmup: Processing pipeline caches...")
    agent.tts.synthesize_to_file("Ready.", "audio_output/warmup.wav")
    logger.info("[API] Pre-warming complete! Server is ready to accept requests.")

class ChatRequest(BaseModel):
    message: str

@app.post("/chat/text")
async def chat_text(req: ChatRequest):
    """ Text-to-Text interaction. Returns response and an optional generated TTS audio file path """
    try:
        message = req.message
        logger.info(f"[API] Received text: {message}")
        
        # Process text directly
        response = await asyncio.to_thread(agent.process, message)
        
        # Save to local db
        save_chat(message, response)

        resp_id = uuid.uuid4().hex
        output_filename = f"audio_output/resp_{resp_id}.wav"
        try:
            await asyncio.to_thread(agent.tts.synthesize_to_file, response, output_filename)
            audio_url = f"http://127.0.0.1:5000/static/resp_{resp_id}.wav"
            
            return {"reply": response, "audio_url": audio_url, "type": "text"}
        except Exception as e:
            logger.error(f"[API] TTS generation failed: {e}")
            return {"reply": response, "audio_url": None, "type": "text"}
    except Exception as e:
        logger.error(f"[API] Error in text processing: {e}")
        import traceback
        logger.error(traceback.format_exc())
        raise HTTPException(status_code=500, detail=str(e))
@app.post("/chat/voice")
async def chat_voice(audio: UploadFile = File(...)):
    """ Voice-to-Voice interaction. Accepts audio file, transcripts, processes, and returns generated audio """
    logger.info(f"[API] Received voice file: {audio.filename}")
    
    in_id = uuid.uuid4().hex
    input_path = f"audio_input/in_{in_id}.wav"
    try:
        with open(input_path, "wb") as f:
            shutil.copyfileobj(audio.file, f)
            
        # 1. Transcribe the saved file
        text = await asyncio.to_thread(agent.stt.transcribe, input_path)
        logger.info(f"[API] Transcribed: {text}")
        if not text.strip():
            return {
                "transcription": "",
                "reply": "I could not hear anything clearly. Please try speaking again.",
                "audio_url": None,
                "type": "voice",
            }
        
        # 2. Process via Agent
        response = await asyncio.to_thread(agent.process, text)
        
        # Save to local DB
        save_chat(text, response)

        # 3. Text to Speech
        resp_id = uuid.uuid4().hex
        output_filename = f"audio_output/resp_{resp_id}.wav"
        await asyncio.to_thread(agent.tts.synthesize_to_file, response, output_filename)
        
        audio_url = f"http://127.0.0.1:5000/static/resp_{resp_id}.wav"
        
        return {
            "transcription": text, 
            "reply": response, 
            "audio_url": audio_url,
            "type": "voice"
        }
    except Exception as e:
        logger.error(f"[API] Error in voice breakdown: {e}")
        raise HTTPException(status_code=500, detail=str(e))


if __name__ == "__main__":
    uvicorn.run(app, host="127.0.0.1", port=5000)