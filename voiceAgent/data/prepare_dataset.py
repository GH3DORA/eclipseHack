# used to load dataset and format it into oumi-compatible JSONL form.

import json
import os
from pathlib import Path
from datasets import load_dataset
from loguru import logger

DATASET_NAME="bitext/Bitext-customer-support-llm-chatbot-training-dataset"
OUTPUT_DIR=Path("data/processed")
TRAINING_FILE=OUTPUT_DIR/"train.jsonl"
EVAL_FILE=OUTPUT_DIR/"test.jsonl"
EVAL_SIZE=1000
MAX_TRAIN=20_000
SYSTEM_PROMPT="""
You are a helpful, professional customer support agent. 
Answer the customer's question clearly and concisely. 
Your response will be spoken aloud, so avoid bullet points and markdown.
"""

def format_example(row: dict) -> dict:
    """
    Bitext columns: instruction, response, category, intent, tags
    We keep instruction + response and wrap with a system prompt.
    Oumi SFT expects: {"messages": [...]} in ChatML format.
    """
    return {
        "messages": [
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": row["instruction"].strip()},
            {"role": "assistant", "content": row["response"].strip()},
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
 
    # Format all examples
    formatted = [format_example(row) for row in ds]
 
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