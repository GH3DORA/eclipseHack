# MediGuide — SLM Voice Assistant

MediGuide is a production-ready, RAG-enabled Small Language Model (SLM) voice assistant designed specifically for medical professionals (Doctors, Nurses, and Surgeons). It consists of a highly responsive Flutter frontend and a powerful Python FastAPI backend pipeline.

## 🏗️ Architecture Overview

The system is split into two primary autonomous layers:

### 1. Python Backend (`/voiceAgent`)
- **FastAPI Core (`api.py`)**: Hosts the `/chat/text` and `/chat/voice` endpoints. Handles audio ingestion, dynamic conversation UUID creation, and manages a local SQLite conversational memory system across asynchronous threads.
- **Agent Pipeline (`pipeline.py`)**: The brain of the operation. A bespoke multi-step machine-learning pipeline:
  1. **STT (Speech-To-Text)**: Standardizes incoming `.m4a`/`.wav` blobs into text.
  2. **Combined Classifier**: Evaluates the emotional tone of the user's prompt.
  3. **Query Rewriter**: Normalizes the prompt for highly accurate database retrieval operations.
  4. **RAG Module (Retrieval-Augmented Generation)**: Leverages the user's exact discipline (Surgeon/Doctor/Nurse) to retrieve precisely relevant medical contexts from the localized database.
  5. **Main SLM Generation**: Weaves the retrieved medical context, the user's real name and ID (from Flutter), and the user's role together into a single master instruction payload for the primary language model.
  6. **TTS (Text-To-Speech)**: Synthesizes the generated intelligence into an audio file response (`.wav`).
  7. **Memory Manager**: Silently logs historical context linked directly to the `userId` to allow the assistant to remember what was previously discussed during the active session.
  8. **Guardrails**: Ensure inputs to the Small Language Models and outputs from them are secure and do not break rules or policies.

### 2. Flutter Frontend (`/application/frontend`)
- **UI/UX**: High-end, dark-mode medical interface with continuous voice-calling capability, wave-form animations, and slick chat bubbles.
- **Firebase Authentication**: Users securely sign up and are immediately mandated to select their specific clinical discipline (e.g., Doctor, Nurse). 
- **Firestore Database**: Stores the user's selected role natively in their profile footprint (`users/{uid}`).
- **Chat & Voice Service**: Communicates dynamically with the Python backend, transparently tunneling the user's exact `userId`, `username`, and `role` alongside their audio files to accurately personalize the RAG processing.

---

## 🚀 How to Run the Application

### Prerequisites
- Python 3.11+
- Conda (Anaconda or Miniconda)
- NVIDIA GPU with CUDA 12.4 support (RTX 4050 6GB or higher recommended)
- Flutter SDK 3.x
- Firebase project with Authentication and Firestore enabled

---

### Step 1: Create the Conda Environment

```bash
conda create -n eclipseHack python=3.11 -y
conda activate eclipseHack
```

### Step 2: Install Dependencies

PyTorch must be installed separately with CUDA support before the rest of the requirements:

```bash
# Install PyTorch with CUDA 12.4
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu124

# Install all other dependencies
pip install -r requirements.txt
```

### Step 3: Prepare the Training Dataset

This downloads the `ruslanmv/ai-medical-chatbot` and `curaihealth/medical_questions_pairs` datasets from HuggingFace and formats them into Oumi-compatible JSONL files.

```bash
cd voiceAgent
python data/prepare_dataset.py
```

This creates:
- `data/processed/train.jsonl` (50k training examples)
- `data/processed/test.jsonl` (1k evaluation examples)

### Step 4: Build the RAG Knowledge Base

This downloads the `openlifescienceai/medmcqa` (183k medical Q&A entries) and `micheletadi/nursing-dataset`, splits them by medical subject, and builds 3 separate FAISS indexes — one per role (Surgeon, Doctor, Nurse).

```bash
python build_knowledge.py
```

This creates:
- `data/surgeon.index` + `data/surgeon.json` — Surgery, Anatomy, Anesthesia, Orthopedics
- `data/doctor.index` + `data/doctor.json` — Medicine, Pathology, Pharmacology, Radiology, etc.
- `data/nurse.index` + `data/nurse.json` — Physiology, Biochemistry, Microbiology, PSM + nursing procedures

### Step 5: Train the Model

Fine-tune the Qwen2.5-3B-Instruct model using Oumi with QLoRA (4-bit quantization + LoRA adapters):

```bash
oumi train -c training/train_large.yaml
```

> **Note**: Training requires a GPU with sufficient VRAM. For cloud training, upload the `voiceAgent/` directory and run the same command. After training, download the `models/main-slm/` adapter folder back to your local machine at `voiceAgent/models/main-slm/`.

### Step 6: Start the Backend Server

```bash
python api.py
```

> Wait for the log: `[API] Pre-warming complete! Server is ready to accept requests.`
> This takes ~15–30 seconds to load and quantize the models into GPU/CPU memory.

For quick local testing without the Flutter app:
```bash
python main.py --text
```
This prompts you to select a role (Surgeon/Doctor/Nurse) and starts a text-based chat.

### Step 7: Start the Flutter Frontend

Open a separate terminal:

```bash
cd application/frontend

# Install Dart dependencies
flutter pub get

# Run on Chrome
flutter run -d chrome
```


---

## 🧠 Custom Firebase-to-Pipeline Flow

What makes MediGuide incredibly capable is its localized role-based access routing:
1. **The User logs in**: An individual identifies as "Akshat", choosing the "Surgeon" discipline. Firebase secures and maps this permanently.
2. **The Micro-Interaction**: When Akshat taps the microphone and speaks, Flutter packages his Audio File, `username=Akshat`, `userId=firebase_auth_uid`, and `role=surgeon` into a payload to the `/chat/voice` FastAPI endpoint.
3. **The Pipeline Reaction**: The backend unzips this payload. The `pipeline.py` intercepts the details and dynamically architects the core instruction:
   > *"You are an expert Surgeon assisting Akshat. Focus on surgical interventions, anatomical details, precise pre-operative and post-operative care..."*
4. **The End Result**: The audio generation is entirely isolated, contextually strict, and effortlessly tailored to the authenticated clinical role without breaking strict medical persona guidelines!

---

## ⚠️ Future Improvements & Hackathon Constraints

Due to time and internet limitations during the hackathon, several optimizations could not be fully realized:

1. **Limited training duration**: The fine-tuned model was trained for only 100 steps due to time constraints. A full multi-epoch training run on the 50k-example dataset would significantly improve response quality, reduce hallucinated doctor names, and better align outputs with the system prompt.

2. **llama-cpp-python for faster inference**: Low network bandwidth at the venue prevented successful installation of the `llama-cpp-python` CUDA wheel (~2GB). This library would have enabled GGUF-quantized inference, cutting generation latency by 2–3x and reducing VRAM usage, allowing the model to handle longer context windows and faster multi-turn conversations.

3. **Dataset cleaning at training time**: The training data (`ruslanmv/ai-medical-chatbot`) contains doctor names, clinic greetings, and sign-offs baked into responses. While we added post-processing regex cleanup and a `clean_doctor_response()` function in the data pipeline, retraining on the fully cleaned dataset would eliminate these artifacts at the source rather than relying on runtime filtering.
