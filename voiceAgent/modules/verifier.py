# used to check a generated plan for logical correctness before execution

from modules.model_manager import ModelManager
from loguru import logger

PROMPT="""
You are a plan verifier for a customer support system.
Given the customer's query and a proposed action plan, verify:
1. Steps are in a logical order
2. No steps conflict with each other
3. The plan actually addresses the query
 
Respond with:
VALID - if the plan is correct, then proceed further.
INVALID : <one line reason> - if the plan has a problem.
Be concise. One line only, give no explanation.
"""

class Verifier:
    def __init__(self):
        self.mm=ModelManager.get_instance()
    

    def verify(self,query:str,plan:list[str])->tuple[bool,str]:
        model,token=self.mm.load_small()
        plan_text="\n".join(plan)
        user_input=f"Customer query : {query} \n Plan : \n {plan_text}"
        raw=self.mm.generate(model,token,PROMPT,user_input,max_newToken=64)
        is_valid=raw.strip().upper().startswith("VALID")
        logger.info(f"Verifier : {"VALID" if is_valid else "INVALID"} | {raw.strip()}")
        return is_valid,raw.strip()
    