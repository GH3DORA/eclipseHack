from fastapi import FastAPI, UploadFile, File, Form, HTTPException
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional
import uvicorn
import os
import uuid
import asyncio
import sqlite3
from loguru import logger
import shutil
from datetime import datetime

from pipeline import VoiceAgentPipeline

app = FastAPI(title="SLM Voice Agent Engine")

# --- DATABASE SETUP ---
DB_FILE = "chat_history.db"


def get_db():
    conn = sqlite3.connect(DB_FILE)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    return conn


def init_db():
    conn = get_db()
    c = conn.cursor()
    c.execute('''
        CREATE TABLE IF NOT EXISTS conversations (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL DEFAULT 'New Chat',
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    c.execute('''
        CREATE TABLE IF NOT EXISTS messages (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            conversation_id TEXT NOT NULL,
            role TEXT NOT NULL CHECK(role IN ('user', 'ai')),
            text TEXT NOT NULL,
            audio_url TEXT,
            timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE
        )
    ''')
    conn.commit()
    conn.close()


# Migrate old flat chat_history if it exists
def migrate_old_data():
    conn = get_db()
    c = conn.cursor()
    try:
        c.execute("SELECT user_text, ai_text, timestamp FROM chats ORDER BY id ASC")
        rows = c.fetchall()
        if rows:
            conv_id = uuid.uuid4().hex
            first_msg = rows[0]["user_text"][:60] if rows[0]["user_text"] else "Imported Chat"
            c.execute(
                "INSERT INTO conversations (id, title) VALUES (?, ?)",
                (conv_id, first_msg),
            )
            for row in rows:
                if row["user_text"]:
                    c.execute(
                        "INSERT INTO messages (conversation_id, role, text, timestamp) VALUES (?, 'user', ?, ?)",
                        (conv_id, row["user_text"], row["timestamp"]),
                    )
                if row["ai_text"]:
                    c.execute(
                        "INSERT INTO messages (conversation_id, role, text, timestamp) VALUES (?, 'ai', ?, ?)",
                        (conv_id, row["ai_text"], row["timestamp"]),
                    )
            conn.commit()
            logger.info(f"[DB] Migrated {len(rows)} old chat rows into conversation {conv_id}")
            c.execute("DROP TABLE chats")
            conn.commit()
    except sqlite3.OperationalError:
        # 'chats' table doesn't exist — nothing to migrate
        pass
    finally:
        conn.close()


init_db()
migrate_old_data()
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
    """Pre-warm the models during server startup so the first request is instant!"""
    logger.info("[API] Pre-warming models for instantaneous response...")
    from modules.model_manager import ModelManager
    mm = ModelManager.get_instance()
    mm.load_small()
    mm.load_small()
    logger.info("[API] Warmup: Small Model")
    mm.generate(mm.small_model, mm.small_tokenizer, "System", "Test", max_new_tokens=2)
    logger.info("[API] Warmup: Processing pipeline caches...")
    agent.tts.synthesize_to_file("Ready.", "audio_output/warmup.wav")
    logger.info("[API] Pre-warming complete! Server is ready to accept requests.")


# ── Conversation Endpoints ──────────────────────────────────────────────────


@app.post("/conversations")
def create_conversation():
    """Create a new conversation and return its ID."""
    conv_id = uuid.uuid4().hex
    conn = get_db()
    conn.execute(
        "INSERT INTO conversations (id, title) VALUES (?, ?)",
        (conv_id, "New Chat"),
    )
    conn.commit()
    conn.close()
    return {"id": conv_id, "title": "New Chat"}


@app.get("/conversations")
def list_conversations():
    """List all conversations, newest first."""
    conn = get_db()
    rows = conn.execute(
        "SELECT id, title, created_at, updated_at FROM conversations ORDER BY updated_at DESC"
    ).fetchall()
    conn.close()
    return [dict(r) for r in rows]


@app.get("/conversations/{conversation_id}/messages")
def get_conversation_messages(conversation_id: str):
    """Get all messages for a specific conversation."""
    conn = get_db()
    # Check conversation exists
    conv = conn.execute(
        "SELECT id, title FROM conversations WHERE id = ?", (conversation_id,)
    ).fetchone()
    if not conv:
        conn.close()
        raise HTTPException(status_code=404, detail="Conversation not found")

    rows = conn.execute(
        "SELECT role, text, audio_url, timestamp FROM messages WHERE conversation_id = ? ORDER BY id ASC",
        (conversation_id,),
    ).fetchall()
    conn.close()
    return {
        "conversation_id": conversation_id,
        "title": conv["title"],
        "messages": [dict(r) for r in rows],
    }


@app.delete("/conversations/{conversation_id}")
def delete_conversation(conversation_id: str):
    """Delete a conversation and all its messages."""
    conn = get_db()
    conn.execute("DELETE FROM conversations WHERE id = ?", (conversation_id,))
    conn.commit()
    conn.close()
    return {"status": "deleted"}


# Keep the old /chat/history for backward compat (returns flat list)
@app.get("/chat/history")
def get_history():
    """Legacy: retrieve recent messages across all conversations."""
    conn = get_db()
    rows = conn.execute(
        """SELECT m.text as user_text, m2.text as ai_text, m.timestamp
           FROM messages m
           LEFT JOIN messages m2 ON m.conversation_id = m2.conversation_id
               AND m2.role = 'ai' AND m2.id = (
                   SELECT MIN(id) FROM messages
                   WHERE conversation_id = m.conversation_id AND role = 'ai' AND id > m.id
               )
           WHERE m.role = 'user'
           ORDER BY m.id DESC LIMIT 10"""
    ).fetchall()
    conn.close()
    return [{"user": r["user_text"], "ai": r["ai_text"] or "", "timestamp": r["timestamp"]} for r in rows]


# ── Chat Endpoints (updated with conversation_id) ──────────────────────────


class ChatRequest(BaseModel):
    message: str
    conversation_id: Optional[str] = None


@app.post("/chat/text")
async def chat_text(req: ChatRequest):
    """Text-to-Text interaction. Returns response and an optional TTS audio URL."""
    try:
        message = req.message
        conversation_id = req.conversation_id
        logger.info(f"[API] Received text: {message} (conv: {conversation_id})")

        # Auto-create conversation if none provided
        if not conversation_id:
            conv_id = uuid.uuid4().hex
            conn = get_db()
            title = message[:60] if message else "New Chat"
            conn.execute(
                "INSERT INTO conversations (id, title) VALUES (?, ?)",
                (conv_id, title),
            )
            conn.commit()
            conn.close()
            conversation_id = conv_id

        # Process text
        response = await asyncio.to_thread(agent.process, message)

        # Save messages to DB
        conn = get_db()
        conn.execute(
            "INSERT INTO messages (conversation_id, role, text) VALUES (?, 'user', ?)",
            (conversation_id, message),
        )

        # Generate TTS
        resp_id = uuid.uuid4().hex
        output_filename = f"audio_output/resp_{resp_id}.wav"
        audio_url = None
        try:
            await asyncio.to_thread(agent.tts.synthesize_to_file, response, output_filename)
            if os.path.exists(output_filename):
                audio_url = f"http://127.0.0.1:5000/static/resp_{resp_id}.wav"
        except Exception as e:
            logger.error(f"[API] TTS generation failed: {e}")

        conn.execute(
            "INSERT INTO messages (conversation_id, role, text, audio_url) VALUES (?, 'ai', ?, ?)",
            (conversation_id, response, audio_url),
        )

        # Update conversation title (use first message) and updated_at
        conv = conn.execute(
            "SELECT title FROM conversations WHERE id = ?", (conversation_id,)
        ).fetchone()
        if conv and conv["title"] == "New Chat":
            new_title = message[:60] if message else "New Chat"
            conn.execute(
                "UPDATE conversations SET title = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?",
                (new_title, conversation_id),
            )
        else:
            conn.execute(
                "UPDATE conversations SET updated_at = CURRENT_TIMESTAMP WHERE id = ?",
                (conversation_id,),
            )
        conn.commit()
        conn.close()

        return {
            "reply": response,
            "audio_url": audio_url,
            "type": "text",
            "conversation_id": conversation_id,
        }
    except Exception as e:
        logger.error(f"[API] Error in text processing: {e}")
        import traceback
        logger.error(traceback.format_exc())
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/chat/voice")
async def chat_voice(audio: UploadFile = File(...), conversation_id: str = Form(default=None)):
    """Voice-to-Voice interaction. Accepts audio file, transcribes, processes, and returns audio."""
    logger.info(f"[API] Received voice file: {audio.filename} (conv: {conversation_id})")

    in_id = uuid.uuid4().hex
    input_path = f"audio_input/in_{in_id}.wav"
    try:
        with open(input_path, "wb") as f:
            shutil.copyfileobj(audio.file, f)

        # 1. Transcribe
        text = await asyncio.to_thread(agent.stt.transcribe, input_path)
        logger.info(f"[API] Transcribed: {text}")
        if not text.strip():
            return {
                "transcription": "",
                "reply": "I could not hear anything clearly. Please try speaking again.",
                "audio_url": None,
                "type": "voice",
                "conversation_id": conversation_id,
            }

        # Auto-create conversation if none provided
        if not conversation_id:
            conv_id = uuid.uuid4().hex
            conn = get_db()
            title = text[:60] if text else "Voice Chat"
            conn.execute(
                "INSERT INTO conversations (id, title) VALUES (?, ?)",
                (conv_id, title),
            )
            conn.commit()
            conn.close()
            conversation_id = conv_id

        # 2. Process via Agent
        response = await asyncio.to_thread(agent.process, text)

        # 3. Text to Speech
        resp_id = uuid.uuid4().hex
        output_filename = f"audio_output/resp_{resp_id}.wav"
        await asyncio.to_thread(agent.tts.synthesize_to_file, response, output_filename)
        if os.path.exists(output_filename):
            audio_url = f"http://127.0.0.1:5000/static/resp_{resp_id}.wav"
        else:
            audio_url = None

        # Save to DB
        conn = get_db()
        conn.execute(
            "INSERT INTO messages (conversation_id, role, text) VALUES (?, 'user', ?)",
            (conversation_id, text),
        )
        conn.execute(
            "INSERT INTO messages (conversation_id, role, text, audio_url) VALUES (?, 'ai', ?, ?)",
            (conversation_id, response, audio_url),
        )
        # Update title if needed
        conv = conn.execute(
            "SELECT title FROM conversations WHERE id = ?", (conversation_id,)
        ).fetchone()
        if conv and conv["title"] in ("New Chat", "Voice Chat"):
            conn.execute(
                "UPDATE conversations SET title = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?",
                (text[:60], conversation_id),
            )
        else:
            conn.execute(
                "UPDATE conversations SET updated_at = CURRENT_TIMESTAMP WHERE id = ?",
                (conversation_id,),
            )
        conn.commit()
        conn.close()

        return {
            "transcription": text,
            "reply": response,
            "audio_url": audio_url,
            "type": "voice",
            "conversation_id": conversation_id,
        }
    except Exception as e:
        logger.error(f"[API] Error in voice breakdown: {e}")
        raise HTTPException(status_code=500, detail=str(e))


if __name__ == "__main__":
    uvicorn.run(app, host="127.0.0.1", port=5000)