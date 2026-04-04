from datasets import load_dataset
from modules.rag import RAGModule

print("Loading ai-medical-chatbot dataset from HuggingFace...")
dataset = load_dataset("ruslanmv/ai-medical-chatbot", split="train")

documents = []
for row in dataset:
    patient = row.get("Patient", "").strip()
    doctor = row.get("Doctor", "").strip()
    if patient and doctor:
        documents.append(f"Patient: {patient}\nDoctor: {doctor}")

print(f"Total available: {len(documents)} documents.")

MAX_DOCS = 20000  # safe for your 16GB RAM
documents = documents[:MAX_DOCS]
print(f"Using {len(documents)} documents.")

rag = RAGModule(index_path="data/medical_knowledge.index", doc_path="data/medical_knowledge.json")
rag.build_and_save(documents)
print("Done! You can now run the pipeline.")