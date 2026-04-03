# used to load ChatDoctor HealthCareMagic-100k dataset and format it into oumi-compatible JSONL form.

import json
import os
from pathlib import Path
from datasets import load_dataset
from loguru import logger

DATASET_NAME="lavita/ChatDoctor-HealthCareMagic-100k"
OUTPUT_DIR=Path("data/processed")
TRAINING_FILE=OUTPUT_DIR/"train.jsonl"
EVAL_FILE=OUTPUT_DIR/"test.jsonl"
EVAL_SIZE=1000
MAX_TRAIN=20_000
SYSTEM_PROMPT="""
You are a compassionate and knowledgeable medical support assistant.
You help patients understand their symptoms, conditions, medications, and general health concerns.
Your response will be spoken aloud, so use plain sentences without bullet points or markdown.
Always recommend consulting a doctor for serious or urgent symptoms.
Never diagnose definitively — use phrases like "this could be" or "it may be helpful to".
Be empathetic and reassuring in your tone.
"""

def format_example(row: dict) -> dict:
    """
    HealthCareMagic-100k columns: input (patient question), output (doctor answer)
    We wrap with a medical system prompt for Oumi SFT chat format.
    """
    patient_query = row.get("input", "").strip()
    doctor_response = row.get("output", "").strip()
    if not patient_query or not doctor_response:
        return None
    return {
        "messages": [
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": patient_query},
            {"role": "assistant", "content": doctor_response},
        ]
    }
    
def save_jsonl(examples: list[dict], path: Path):
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        for ex in examples:
            f.write(json.dumps(ex) + "\n")
    logger.info(f"Saved {len(examples)} examples → {path}")

def main():
    logger.info(f"Loading dataset: {DATASET_NAME}")
    ds = load_dataset(DATASET_NAME, split="train")
    logger.info(f"Total examples: {len(ds)}")
 
    # Shuffle for variety
    ds = ds.shuffle(seed=42)
 
    # Format all examples, skip empty ones
    formatted = [ex for row in ds if (ex := format_example(row)) is not None]
    logger.info(f"Formatted examples: {len(formatted)}")
 
    # Split
    eval_data  = formatted[:EVAL_SIZE]
    train_data = formatted[EVAL_SIZE : EVAL_SIZE + MAX_TRAIN]
 
    save_jsonl(train_data, TRAINING_FILE)
    save_jsonl(eval_data,  EVAL_FILE)
 
    # Print a sample
    print("\n── Sample training example ──────────────────────────────")
    sample = train_data[1]
    for msg in sample["messages"]:
        role = msg["role"].upper()
        print(f"[{role}]\n{msg['content']}\n")
    print(f"Train: {len(train_data)} | Eval: {len(eval_data)}")
    print("Dataset ready.")
 
 
if __name__ == "__main__":
    main()