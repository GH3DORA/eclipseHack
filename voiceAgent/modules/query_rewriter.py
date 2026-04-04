# modules/query_rewriter.py — replace entire file
import re
from loguru import logger

class QueryRewriter:
    def __init__(self):
        pass  # no model needed

    def rewrite(self, text: str) -> str:
        # Simple rule-based cleanup — instant, no model call
        text = text.strip()
        # Remove filler words common in speech
        fillers = [
            r'\bum+\b', r'\buh+\b', r'\blike\b',
            r'\byou know\b', r'\bi mean\b', r'\bso\b'
        ]
        for f in fillers:
            text = re.sub(f, '', text, flags=re.IGNORECASE)
        # Clean up extra spaces
        text = re.sub(r'\s+', ' ', text).strip()
        logger.info(f"Rewritten query: {text}")
        return text if text else text