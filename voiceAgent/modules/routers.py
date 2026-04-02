# 3 types of routing. Execution, model and retrieval.
# EXECUTION - decides action (escalate,answer,plan,search,clarify)
# MODEL - determines model selection. simple for fast, complex for full SLM
# RETRIEVAL - querying mock databases to get data source for order, refund, policy, account details etc.

from modules.model_manager import ModelManager  
from loguru import logger

# system prompts
EXECUTION_PROMPT="""
You are a routing agent for a customer support system.
Given the user query, choose the best action:
CHITCHAT - greeting, thanks, farewell or a casual social message.
ANSWER — query can be answered directly without any tool or multi-step plan.
PLAN — query requires multiple ordered steps (e.g. "cancel my order AND update my email").
SEARCH — query requires looking up specific live data (e.g. order status, refund status).
CLARIFY — query is ambiguous and needs more information from the customer.
ESCALATE — query requires a human agent.
Reply with ONE word only without giving any explanation: ANSWER, PLAN, SEARCH, CLARIFY, or ESCALATE
"""
MODEL_PROMPT="""
You are a complexity classifier for a customer support system.
Classify the user query:
SIMPLE - a short, direct question with a straightforward answer (e.g. "what is your return policy?")
COMPLEX - requires reasoning, multi-step handling, or customer-specific data
 
Reply with ONE word only, without any explanation: SIMPLE or COMPLEX.
"""
RETRIEVAL_PROMPT="""
You are a data-source routing classifier for a customer support system.
Given the user query, choose the most relevant data source:
ORDER_DB - specific order, tracking, delivery, or shipping status
REFUND_DB - refund progress or return status
POLICY_DOCS - company policies, FAQs, return rules, delivery options
ACCOUNT_DB - account settings, email, password, profile info
 
Reply with ONE word only: ORDER_DB, REFUND_DB, POLICY_DOCS, or ACCOUNT_DB.
"""

# ROUTER CLASSES

class ExecutionRouter:
    VALID={"CHITCHAT","ANSWER","PLAN","SEARCH","CLARIFY","ESCALATE"}
    def __init__(self):
        self.mm=ModelManager.get_instance()

    def route(self,query:str)->str:
        model,token=self.mm.load_small()
        raw=self.mm.generate(model,token,EXECUTION_PROMPT,query,max_new_tokens=5)
        label=raw.strip().upper().split()[0] if raw.strip() else "ANSWER"
        if label not in self.VALID:
            label="ANSWER"
        logger.info(f"Label : {label}")
        return label

class ModelRouter:
    def __init__(self):
        self.mm=ModelManager.get_instance()
    VALID={"SIMPLE","COMPLEX"}
    def route(self,query:str)->str:
        model,token=self.mm.load_small()
        raw=self.mm.generate(model,token,MODEL_PROMPT, query, max_new_tokens=5)
        label=raw.strip().upper().split()[0] if raw.strip() else "SIMPLE"
        if label not in self.VALID:
            label="SIMPLE"
        logger.info(f"Label : {label}")
        return label
    
class RetrievalRouter:
    def __init__(self):
        self.mm=ModelManager.get_instance()
    VALID={"ORDER_DB","REFUND_DB","POLICY_DOCS","ACCOUNT_DB"}
    def route(self,query:str)->str:
        model,token=self.mm.load_small()
        raw=self.mm.generate(model,token,RETRIEVAL_PROMPT,query, max_new_tokens=5)
        label=raw.strip().upper().split()[0] if raw.strip() else "POLICY_DOCS"
        if label not in self.VALID:
            label="POLICY_DOCS"
        logger.info(f"Label : {label}")
        return label