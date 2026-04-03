# used to break multi-intent queries into an ordered list of steps
# uses the larger model to improve step generation reasoning

from modules.model_manager import ModelManager
from loguru import logger

PROMPT="""
You are a planning agent for a medical support system.
Given a patient query that requires multiple steps, produce a numbered action plan.
Available actions:
check_patient_record(patient_id)
check_appointment(patient_id)
check_medication_info(medication)
check_symptoms(symptom)
escalate_to_doctor()
check_emergency_guidance()
answer_directly(your answer here)
 
Rules:
- Use answer_directly when no tool is needed for that step
- Keep each step on one line
- Do not add explanation, steps only
- If the patient describes an emergency, always include escalate_to_doctor()
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
        raw=self.mm.generate(model,token,PROMPT,query,max_new_tokens=256)
        steps=[]
        for line in raw.strip().splitlines():
            line=line.strip()
            if line and (line[0].isdigit() or line.lower().startswith("step")):
                steps.append(line)
        if not steps:
            steps=["Step 1: answer_directly(I will help you with your request)"]
        logger.info(f"Plan ({len(steps)} steps) : {steps}")
        return steps
    