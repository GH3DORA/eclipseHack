# CENTRAL MANAGER for all model instances. All instanced call "get_instance" to share the same model and not load the same weights multiple times.

import re
import torch
from loguru import logger
from transformers import AutoModelForCausalLM, AutoTokenizer, BitsAndBytesConfig
from peft import PeftModel
from config import SMALLMODEL,LARGEMODEL,BASE_SMALL,BASE_LARGE,GUARDRAILMODEL

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
        self.small_base_model=None
        self.small_base_tokenizer=None
        self.guardrail_model=None
        self.guardrail_tokenizer=None
        self.large_model=None
        self.large_tokenizer=None
        self.device="cuda" if torch.cuda.is_available() else "cpu"
        logger.info(f"ModelManager initialised - device is {self.device}")

    # lazy loaders, only loaded when needed.
    def load_small(self): #load fine-tuned small model (medical QA)
        if self.small_model is None:
            logger.info("Loading fine-tuned small model on CPU...")
            self.small_tokenizer=AutoTokenizer.from_pretrained(BASE_SMALL)
            base_model=AutoModelForCausalLM.from_pretrained(
                BASE_SMALL,
                torch_dtype=torch.float32,
            )
            self.small_model = PeftModel.from_pretrained(base_model, SMALLMODEL).to("cpu")
            self.small_model.eval()
            logger.info("Fine-tuned small model ready (CPU).")
        return self.small_model, self.small_tokenizer

    def load_small_base(self): #load base (unfinetuned) model for classifiers
        if self.small_base_model is None:
            logger.info("Loading base small model for classifiers on CPU...")
            self.small_base_tokenizer=AutoTokenizer.from_pretrained(BASE_SMALL)
            self.small_base_model=AutoModelForCausalLM.from_pretrained(
                BASE_SMALL,
                torch_dtype=torch.float32,
            ).to("cpu")
            self.small_base_model.eval()
            logger.info("Base small model ready (CPU).")
        return self.small_base_model, self.small_base_tokenizer

    def load_guardrail(self): #load fine-tuned guardrail classifier
        if self.guardrail_model is None:
            logger.info("Loading fine-tuned guardrail model on CPU...")
            self.guardrail_tokenizer=AutoTokenizer.from_pretrained(BASE_SMALL)
            base_model=AutoModelForCausalLM.from_pretrained(
                BASE_SMALL,
                torch_dtype=torch.float32,
            )
            self.guardrail_model = PeftModel.from_pretrained(base_model, GUARDRAILMODEL).to("cpu")
            self.guardrail_model.eval()
            logger.info("Guardrail model ready (CPU).")
        return self.guardrail_model, self.guardrail_tokenizer

    def load_large(self):
        if self.large_model is None:
            torch.cuda.empty_cache()
            logger.info("Loading large model on GPU (4-bit)...")
            bnb=BitsAndBytesConfig(
                load_in_4bit=True,
                bnb_4bit_quant_type="nf4",
                bnb_4bit_compute_dtype=torch.float16,
            )
            self.large_tokenizer=AutoTokenizer.from_pretrained(BASE_LARGE)
            base_model=AutoModelForCausalLM.from_pretrained(
                BASE_LARGE,
                quantization_config=bnb,
                device_map="auto",
                low_cpu_mem_usage=True,
            )
            self.large_model = PeftModel.from_pretrained(base_model, LARGEMODEL)
            self.large_model.eval()
            logger.info("Large model ready (GPU, 4-bit).")
        return self.large_model, self.large_tokenizer
    
    #shared inference used by every model
    def generate(self,model,tokenizer,system_prompt:str,user_prompt:str,max_new_tokens:int=256,enable_thinking:bool=False)->str:
        messages=[
            {"role":"system","content":system_prompt},
            {"role":"user","content":user_prompt}
        ]
        # Qwen3.5 supports enable_thinking kwarg in chat template
        template_kwargs={"tokenize":False,"add_generation_prompt":True}
        try:
            text=tokenizer.apply_chat_template(
                messages,enable_thinking=enable_thinking,**template_kwargs
            )
        except TypeError:
            # Fallback for models whose template doesn't support enable_thinking
            text=tokenizer.apply_chat_template(messages,**template_kwargs)
        inputs=tokenizer(text,return_tensors="pt").to(model.device)

        with torch.no_grad():
            outputs=model.generate(
                **inputs,
                max_new_tokens=max_new_tokens,
                do_sample=True,
                temperature=0.3,
                top_p=0.9,
                repetition_penalty=1.15,
                pad_token_id=tokenizer.eos_token_id
            )

        new_tokens=outputs[0][inputs["input_ids"].shape[1]:]
        response=tokenizer.decode(new_tokens,skip_special_tokens=True)
        # Strip any <think>...</think> blocks from thinking models
        response=re.sub(r"<think>.*?</think>","",response,flags=re.DOTALL).strip()
        return response