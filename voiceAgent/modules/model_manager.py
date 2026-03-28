# CENTRAL MANAGER for all model instances. All instanced call "get_instance" to share the same model and not load the same weights multiple times.

import torch
from loguru import logger
from transformers import AutoModelForCausalLM, AutoTokenizer
from config import SMALLMODEL,LARGEMODEL

class ModelManager:

    _instance=None
    @classmethod
    def get_instance(cls):
        if cls._instance is None:
            cls._instance=cls()
        return cls._instance

    def __init__(self):
        self.small_model=None
        self.small_tokenizer=None
        self.large_model=None
        self.large_tokenizer=None
        self.device="cuda" if torch.cuda.is_available() else "cpu"
        logger.info("ModelManager initialised - device is {self.device}")

    # lazy loaders, only loaded when needed.
    def load_small(self): #load small qwen model for smaller tasks
        if self.small_model is None:
            logger.info("Loading small model...")
            self.small_tokenizer=AutoTokenizer.from_pretrained(SMALLMODEL)
            self.small_model=AutoModelForCausalLM.from_pretrained(
                SMALLMODEL,
                torch_dtype=torch.float16,
                device_map="auto"
            )
            self.small_model.eval()
            logger.info("Small model ready.")
        return self.small_model, self.small_tokenizer

    def load_large(self):
        if self.large_model is None:
            logger.info("Loading large model...")
            self.large_tokenizer=AutoTokenizer.from_pretrained(LARGEMODEL)
            self.large_model=AutoModelForCausalLM.from_pretrained(
                LARGEMODEL,
                torch_dtype=torch.float16,
                device_map="auto"
            )
            self.large_model.eval()
            logger.info("Large model ready.")
        return self.large_model,self.large_tokenizer
    
    #shared inference used by every model
    def generate(self,model,tokenizer,system_prompt:str,user_prompt:str,max_newToken:int=256,)->str:
        messages=[
            {"role":"system","content":system_prompt},
            {"role":"user","content":user_prompt}
        ]
        text=tokenizer.apply_chat_template(
            messages,tokenize=False,add_generation_prompt=True
        )
        inputs=tokenizer(text,return_tensors="pt").to(model.device)

        with torch.no_grad():
            outputs=model.generate(
                **inputs,
                max_newToken=max_newToken,
                do_sample=False,
                pad_token_id=tokenizer.eos_token_id
            )

        new_tokens=outputs[0][inputs["input_ids"].shape[1]:]
        response=tokenizer.decode(new_tokens,skip_special_tokens=True)
        return response.strip()