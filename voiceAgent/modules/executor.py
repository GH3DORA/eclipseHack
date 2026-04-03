# to convert each natural-language plan into a JSON call and then dispatch to the matching function in mock_tools.TOOL_MAP

import json
import re
from loguru import logger
from modules.model_manager import ModelManager
from mock_tools import TOOL_MAP

PROMPT="""
You are an executor agent for a medical support system. Convert the given plan step into a JSON call.
Available tools:
check_patient_record - params: {"patient_id":"string"}
check_appointment - params: {"patient_id":"string"}
check_medication_info - params: {"medication":"string"}
check_symptoms - params: {"symptom":"string"}
escalate_to_doctor - params: {}
check_emergency_guidance - params: {}
answer_directly - params: {"response":"your answer"}

Return only a valid JSON response, nothing else.
{"tool":"<tool_name>","params":{<params>}}

If no patient ID or medication name is mentioned, use an empty string value.
"""

class Executor:
    def __init__(self):
        self.mm=ModelManager.get_instance()
    

    # parsing model's JSON output
    def _parse(self, text: str) -> dict:
        try:
            match = re.search(r'\{.*\}', text, re.DOTALL)
            if match:
                return json.loads(match.group())
        except (json.JSONDecodeError, AttributeError):
            pass
        return {"tool": "answer_directly", "params": {"response": text}}

    # single step execution
    def execute_step(self, step: str, context: str = "") -> str:
        model, tok  = self.mm.load_small()
        user_input  = f"Context so far:\n{context}\n\nStep to execute: {step}"
        raw         = self.mm.generate(model, tok, PROMPT, user_input, max_new_tokens=120)
        call        = self._parse(raw)
 
        tool_name = call.get("tool", "answer_directly")
        params    = call.get("params", {})
        # Remove any params that are just empty strings to avoid call errors
        params    = {k: v for k, v in params.items() if v}
 
        logger.info(f"Executor: {tool_name}({params})")
 
        if tool_name in TOOL_MAP:
            try:
                result = TOOL_MAP[tool_name](**params)
                return result
            except TypeError as e:
                logger.warning(f"Tool call failed ({e}), trying without params")
                try:
                    return TOOL_MAP[tool_name]()
                except Exception as e2:
                    logger.error(f"Tool error: {e2}")
                    return f"Could not complete step: {step}"
 
        if tool_name == "answer_directly":
            return params.get("response", "I will take care of that for you.")
 
        return "Step completed."
    
    # full plan execution
    def execute_plan(self, steps: list[str], context: str = "") -> list[str]:
        results = []
        running_context = context
        for step in steps:
            result = self.execute_step(step, running_context)
            results.append(result)
            running_context += f"\n{step} → {result}"
        logger.info(f"Plan execution complete. {len(results)} results.")
        return results
