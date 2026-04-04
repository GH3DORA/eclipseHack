import os
import json
import faiss
import numpy as np
from sentence_transformers import SentenceTransformer

class RAGModule:
    def __init__(self, index_path="medical_knowledge.index", doc_path="medical_knowledge.json"):
        self.embedding_model = SentenceTransformer('all-MiniLM-L6-v2', device='cpu')  # keep VRAM free for SLM
        self.dimension = self.embedding_model.get_sentence_embedding_dimension()
        
        self.index_path = index_path
        self.doc_path = doc_path
        self.documents = []
        self.index = None
        
        self._load_or_create_index()

    def _load_or_create_index(self):
        if os.path.exists(self.index_path) and os.path.exists(self.doc_path):
            print("Loading existing RAG index from disk...")
            self.index = faiss.read_index(self.index_path)
            with open(self.doc_path, "r", encoding="utf-8") as f:
                self.documents = json.load(f)
        else:
            print("No existing index found. Starting fresh.")
            self.index = faiss.IndexFlatL2(self.dimension)

    def build_and_save(self, new_documents: list[str]):
        if not new_documents:
            return

        self.documents.extend(new_documents)
        
        BATCH_SIZE = 256  # conservative for 16GB RAM
        all_embeddings = []
        for i in range(0, len(new_documents), BATCH_SIZE):
            batch = new_documents[i:i+BATCH_SIZE]
            embeddings = self.embedding_model.encode(batch, show_progress_bar=True)
            all_embeddings.append(embeddings)
            print(f"Encoded {min(i+BATCH_SIZE, len(new_documents))}/{len(new_documents)}")
        
        all_embeddings = np.concatenate(all_embeddings, axis=0)
        self.index.add(all_embeddings.astype('float32'))
        
        faiss.write_index(self.index, self.index_path)
        with open(self.doc_path, "w", encoding="utf-8") as f:
            json.dump(self.documents, f)
            
        print("Knowledge base built and saved.")

    def retrieve(self, query: str, top_k: int = 2) -> str:
        if not self.documents:
            return ""
            
        query_embedding = self.embedding_model.encode([query])
        distances, indices = self.index.search(np.array(query_embedding).astype('float32'), top_k)
        
        results = [self.documents[i] for i in indices[0] if i < len(self.documents)]
        return "\n".join(results) 