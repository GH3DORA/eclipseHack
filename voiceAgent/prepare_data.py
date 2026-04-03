from datasets import load_dataset
import json
import os

os.makedirs("./data", exist_ok=True)

print("Downloading ChatDoctor dataset...")
dataset = load_dataset(
    "lavita/ChatDoctor-HealthCareMagic-100k",
    split="train"
)

# Emergency/medical keywords to filter relevant examples
emergency_keywords = [
    "chest pain", "heart attack", "stroke", "bleeding",
    "unconscious", "breathing", "choking", "seizure",
    "poison", "burn", "fracture", "emergency", "urgent",
    "severe", "accident", "injury", "allergic", "fever",
    "dizzy", "fainted", "vomit", "pain", "swollen",
    "infection", "wound", "broken", "headache", "nausea"
]

print("Filtering medical examples...")
filtered = []
for example in dataset:
    text = example['input'].lower()
    if any(kw in text for kw in emergency_keywords):
        filtered.append({
            "messages": [
                {
                    "role": "system",
                    "content": "You are an offline medical voice assistant. Give concise, accurate, actionable medical guidance. Always recommend emergency services for life-threatening situations."
                },
                {
                    "role": "user",
                    "content": example['input']
                },
                {
                    "role": "assistant",
                    "content": example['output']
                }
            ]
        })

# Cap at 2000 examples — safe for 4GB VRAM
final = filtered[:2000]

# Save as JSONL
with open("./data/medical_train.jsonl", "w") as f:
    for item in final:
        f.write(json.dumps(item) + "\n")

print(f"✅ Done! Saved {len(final)} examples to ./data/medical_train.jsonl")
print(f"Total filtered: {len(filtered)}, Used: {len(final)}")

# Preview first example
print("\nPreview of first example:")
print(json.dumps(final[0], indent=2)[:500])