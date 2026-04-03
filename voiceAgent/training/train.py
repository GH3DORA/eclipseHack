# launcher for oumi fine-training
import argparse
import subprocess
import sys
import os
from pathlib import Path
from loguru import logger

CONFIGS={
    "large":"training/train_large.yaml",
    "small":"training/train_small.yaml"
}
DATASET_TRAIN=Path("data/processed/train.jsonl")
DATASET_EVAL=Path("data/processed/test.jsonl")

def checkDataset():
    if not DATASET_TRAIN.exists() or not DATASET_EVAL.exists():
        logger.error("Dataset does not exist. Run `python data/prepare_dataset.py` first.")
        sys.exit(1)
    with open(DATASET_TRAIN) as f:
        count=sum(1 for _ in f)
        logger.info(f"Dataset OK - found {count} training samples.")

def checkGPU():
    import torch
    if not torch.cuda.is_available():
        logger.warning("No GPU detected. Training will be done on CPU.")
        print("Ctrl + C to exit, auto start in 5 seconds.")
        import time
        try:
            time.sleep(5)
        except KeyboardInterrupt:
            sys.exit(0)
    else:
        name=torch.cuda.get_device_name(0)
        vram=torch.cuda.get_device_properties(0).total_memory / 1e9
        logger.info(f"GPU Detected - {name} with {vram} VRAM.")

def checkOumi():
    try:
        import oumi
        logger.info(f"Oumi installed.")
    except ImportError:
        logger.error("Error - Oumi is not installed. Run `pip install oumi` first.")
        sys.exit(1)

def runTraining(model_size:str):
    config_path=CONFIGS[model_size]
    output_dir=f"models/{'main' if model_size=='large' else 'small'}-slm"
    print("="*50)
    print(f"\n Starting fine-tuning {model_size.upper()} model.")
    print(f"\n Config - {config_path}")
    print(f"\n Output - {output_dir}\n")
    print(f"="*50)

    cmd=["oumi","train","-c",config_path]
    logger.info("Running Oumi")
    result=subprocess.run(cmd,check=False)

    if result.returncode==0:
        logger.info(f"[OK] {model_size.upper()} model training complete.")
        logger.info(f"Output saved to {output_dir}")
    else :
        logger.error(f"Failed with exit code {result.returncode}")
        sys.exit(result.returncode)

def nextSteps():
    print("\n"+"="*50)
    print("\n Fine tuning complete.")
    print("\n"+"="*50)
    print("""
1. Open config.py and update the model paths:
 
     SMALL_MODEL_NAME = "./models/small-slm"
     LARGE_MODEL_NAME = "./models/main-slm"
 
2. Run the agent in text mode to test:
 
     python main.py --text
 
3. Try queries like:
     - "Where is my order 12345?"
     - "Cancel my order and give me a refund"
     - "What is your return policy?"
""")
    
if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--model",
        choices=["large", "small", "both"],
        default="both",
        help="Which model to fine-tune (default: both)"
    )
    args = parser.parse_args()
 
    # Pre-flight
    print("\nRunning pre-flight checks...\n")
    checkDataset()
    checkGPU()
    checkOumi()
    print()
 
    # Train
    if args.model == "both":
        runTraining("large")
        runTraining("small")
    else:
        runTraining(args.model)
 
    nextSteps()