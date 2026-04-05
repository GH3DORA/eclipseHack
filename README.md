# MediGuide — SLM Voice Assistant

MediGuide is a production-ready, RAG-enabled Small Language Model (SLM) voice assistant designed specifically for medical professionals (Doctors, Nurses, and Surgeons). It consists of a highly responsive Flutter frontend and a powerful Python FastAPI backend pipeline.

## 🏗️ Architecture Overview

The system is split into two primary autonomous layers:

### 1. Flutter Frontend (`/application/frontend`)
- **UI/UX**: High-end, dark-mode medical interface with continuous voice-calling capability, wave-form animations, and slick chat bubbles.
- **Firebase Authentication**: Users securely sign up and are immediately mandated to select their specific clinical discipline (e.g., Doctor, Nurse). 
- **Firestore Database**: Stores the user's selected role natively in their profile footprint (`users/{uid}`).
- **Chat & Voice Service**: Communicates dynamically with the Python backend, transparently tunneling the user's exact `userId`, `username`, and `role` alongside their audio files to accurately personalize the RAG processing.

### 2. Python Backend (`/voiceAgent`)
- **FastAPI Core (`api.py`)**: Hosts the `/chat/text` and `/chat/voice` endpoints. Handles audio ingestion, dynamic conversation UUID creation, and manages a local SQLite conversational memory system across asynchronous threads.
- **Agent Pipeline (`pipeline.py`)**: The brain of the operation. A bespoke multi-step machine-learning pipeline:
  1. **STT (Speech-To-Text)**: Standardizes incoming `.m4a`/`.wav` blobs into text.
  2. **Combined Classifier**: Evaluates the emotional tone of the clinician's prompt.
  3. **Query Rewriter**: Normalizes the prompt for highly accurate database retrieval operations.
  4. **RAG Module (Retrieval-Augmented Generation)**: Leverages the user's exact discipline (Doctor/Nurse) to retrieve precisely relevant medical contexts from the localized KB.
  5. **Main SLM Generation**: Weaves the retrieved medical context, the user's real name (from Flutter), and the user's role together into a single master instruction payload for the primary language model.
  6. **TTS (Text-To-Speech)**: Synthesizes the generated intelligence into an audio file response (`.wav`).
  7. **Memory Manager**: Silently logs historical context linked directly to the `userId` to allow the assistant to remember what was previously discussed during the active session.

---

## 🚀 How to Run the Application

You must run both the Backend Python SLM Server and the Flutter Web/App client concurrently in separate terminals.

### Step 1: Start the Backend (Python)
The backend manages all intelligence and needs to load the SLM into RAM/CPU before taking network requests.
```bash
cd voiceAgent

# Ensure your virtual environment is activated
# Windows format:
.venv\Scripts\activate

# Boot the API server
python api.py
```
> **Note**: Wait for the server to log `[API] Pre-warming complete! Server is ready to accept requests.` This setup usually takes ~15 seconds to safely load the quantized models into system memory.

### Step 2: Start the Frontend (Flutter)
Open an entirely new/split terminal window to serve the visual Flutter interface.

```bash
cd application/frontend

# Install all Dart dependencies
flutter pub get

# Run on the local chrome web browser
flutter run -d chrome
```
> Use the hot-reload command (`r`) in the terminal if you modify any UI logic.

---

## 🧠 Custom Firebase-to-Pipeline Flow

What makes MediGuide incredibly capable is its localized role-based access routing:
1. **The User logs in**: An individual identifies as "Akshat", choosing the "Surgeon" discipline. Firebase secures and maps this permanently.
2. **The Micro-Interaction**: When Akshat taps the microphone and speaks, Flutter packages his Audio File, `username=Akshat`, `userId=firebase_auth_uid`, and `role=surgeon` into a payload to the `/chat/voice` FastAPI endpoint.
3. **The Pipeline Reaction**: The backend unzips this payload. The `pipeline.py` intercepts the details and dynamically architects the core instruction:
   > *"You are an expert Surgeon assisting Akshat. Focus on surgical interventions, anatomical details, precise pre-operative and post-operative care..."*
4. **The End Result**: The audio generation is entirely isolated, contextually strict, and effortlessly tailored to the authenticated clinical role without breaking strict medical persona guidelines!
