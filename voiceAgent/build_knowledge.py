from datasets import load_dataset
from modules.rag import RAGModule

print("Loading ChatDoctor dataset from HuggingFace...")
dataset = load_dataset("lavita/ChatDoctor-HealthCareMagic-100k", split="train")

documents = []
for row in dataset:
    instruction = row.get("instruction", "").strip()
    output = row.get("output", "").strip()
    if instruction and output:
        documents.append(f"Patient: {instruction}\nDoctor: {output}")

print(f"Total available: {len(documents)} documents.")

MAX_DOCS = 20000  # safe for your 16GB RAM
documents = documents[:MAX_DOCS]
print(f"Using {len(documents)} documents.")

rag = RAGModule(index_path="medical_knowledge.index", doc_path="medical_knowledge.json")
rag.build_and_save(documents)
print("Done! You can now run the pipeline.")