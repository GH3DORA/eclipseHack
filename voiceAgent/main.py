# main.py -> entry point for medical voice agent
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

VALID_ROLES = {"surgeon", "doctor", "nurse"}

def select_role() -> str:
    print("\n" + "=" * 50)
    print("  Select your role:")
    print("  1. Surgeon")
    print("  2. Doctor")
    print("  3. Nurse")
    print("=" * 50)
    while True:
        choice = input("Enter 1/2/3: ").strip()
        if choice == "1":
            return "surgeon"
        elif choice == "2":
            return "doctor"
        elif choice == "3":
            return "nurse"
        print("Invalid choice. Please enter 1, 2, or 3.")

if __name__=="__main__":
    text_mode="--text" in sys.argv
    role = select_role()
    print(f"Starting as: {role.upper()}")
    agent=VoiceAgentPipeline(role=role)

    if text_mode:
        agent.run_text()
    else:
        agent.run()