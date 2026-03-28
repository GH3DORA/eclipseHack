# main.py -> entry point for SLM
# for voice mode, run --  python main.py  --
# for text mode, run --  python main.py --text  --

import sys
import os
from loguru import logger
from dotenv import load_dotenv

load_dotenv()

logger.remove()
logger.add(sys.stderr,level="WARNING")
logger.add(
    "logs/agent.log",
    rotation="10 MB",
    retention="7 DAYS",
    level="INFO",
    format="{time:HH:mm:ss} | {level:<8} | {module}.{function} | {message}"
)

from pipeline import VoiceAgentPipeline

if __name__=="__main__":
    text_mode="--text" in sys.argv
    agent=VoiceAgentPipeline()

    if text_mode:
        agent.run_text()
    else:
        agent.run()