# Builds 3 separate FAISS indexes — one per role (surgeon, doctor, nurse)
# Uses openlifescienceai/medmcqa (split by subject_name) + micheletadi/nursing-dataset for nurse

from datasets import load_dataset
from modules.rag import RAGModule

# Subject → Role mapping
SURGEON_SUBJECTS = {"Surgery", "Anatomy", "Anesthesia", "Orthopedics"}
DOCTOR_SUBJECTS = {
    "Medicine", "Pathology", "Pharmacology", "Radiology",
    "Psychiatry", "Pediatrics", "Gynaecology & Obstetrics",
    "Ophthalmology", "ENT", "Skin", "Forensic Medicine (FM)",
    "Dental",
}
# Nurse gets everything else (Physiology, Biochemistry, Microbiology, PSM, etc.)

ROLE_PATHS = {
    "surgeon": ("data/surgeon.index", "data/surgeon.json"),
    "doctor":  ("data/doctor.index",  "data/doctor.json"),
    "nurse":   ("data/nurse.index",   "data/nurse.json"),
}

def format_mcqa(row: dict) -> str | None:
    q = (row.get("question") or "").strip()
    exp = (row.get("exp") or "").strip()
    if not q or not exp:
        return None
    # Include correct answer for richer context
    cop = row.get("cop", 1)
    options = {1: "opa", 2: "opb", 3: "opc", 4: "opd"}
    answer = (row.get(options.get(cop, "opa")) or "").strip()
    topic = row.get("topic_name") or ""
    header = f"[{topic}] " if topic else ""
    return f"{header}Q: {q}\nA: {answer}\nExplanation: {exp}"

def main():
    # ── 1. Load MedMCQA and split by subject ──
    print("Loading MedMCQA dataset...")
    ds = load_dataset("openlifescienceai/medmcqa", split="train")
    print(f"Total MedMCQA entries: {len(ds)}")

    surgeon_docs, doctor_docs, nurse_docs = [], [], []

    for row in ds:
        doc = format_mcqa(row)
        if not doc:
            continue
        subj = row.get("subject_name", "").strip()
        if subj in SURGEON_SUBJECTS:
            surgeon_docs.append(doc)
        elif subj in DOCTOR_SUBJECTS:
            doctor_docs.append(doc)
        else:
            nurse_docs.append(doc)

    print(f"MedMCQA split — Surgeon: {len(surgeon_docs)} | Doctor: {len(doctor_docs)} | Nurse: {len(nurse_docs)}")

    # ── 2. Load nursing dataset and merge into nurse tier ──
    print("Loading nursing dataset...")
    nursing_ds = load_dataset("micheletadi/nursing-dataset", split="train")
    nursing_count = 0
    for row in nursing_ds:
        q = row.get("question", "").strip()
        a = row.get("answer", "").strip()
        if q and a:
            nurse_docs.append(f"[Nursing] Q: {q}\nA: {a}")
            nursing_count += 1
    print(f"Added {nursing_count} nursing entries. Total nurse docs: {len(nurse_docs)}")

    # ── 3. Cap each index to keep RAM safe ──
    MAX_PER_ROLE = 20000
    surgeon_docs = surgeon_docs[:MAX_PER_ROLE]
    doctor_docs = doctor_docs[:MAX_PER_ROLE]
    nurse_docs = nurse_docs[:MAX_PER_ROLE]

    # ── 4. Build and save each index ──
    for role, docs in [("surgeon", surgeon_docs), ("doctor", doctor_docs), ("nurse", nurse_docs)]:
        idx_path, doc_path = ROLE_PATHS[role]
        print(f"\nBuilding {role} index ({len(docs)} docs)...")
        rag = RAGModule(index_path=idx_path, doc_path=doc_path)
        rag.build_and_save(docs)
        print(f"{role} index saved.")

    print("\nAll 3 knowledge bases ready!")

if __name__ == "__main__":
    main()