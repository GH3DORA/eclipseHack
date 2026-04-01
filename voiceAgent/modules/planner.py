# used to break multi-intent queries into an ordered list of steps
# uses the larger model to improve step generation reasoning

from modules.model_manager import ModelManager
from loguru import logger

PROMPT="""
You are a planning agent for a customer support system.
Given a customer query that requires multiple steps, produce a numbered action plan.
Available actions:
check_order_status(order_id)
cancel_order(order_id)
check_refund_status(order_id)
update_email(new_email)
escalate_to_human()
check_return_policy()
check_delivery_options()
answer_directly(your answer here)
 
Rules:
- Use answer_directly when no tool is needed for that step
- Keep each step on one line
- Do not add explanation, steps only
Format:
Step 1: <action>
Step 2: <action>
...
"""

class Planner:
    def __init__(self):
        self.mm=ModelManager.get_instance()
    def plan(self,query:str)->list[str]:
        model,token=self.mm.load_large()
        raw=self.mm.generate(model,token,PROMPT,query,max_newToken=256)
        steps=[]
        for line in raw.strip().splitlines():
            line=line.strip()
            if line and (line[0].isdigit() or line.lower().startswith("step")):
                steps.append(line)
        if not steps:
            steps=["Step 1: answer_directly(I will help you with your request)"]
        logger.info(f"Plan ({len(steps)} steps) : {steps}")
        return steps
    