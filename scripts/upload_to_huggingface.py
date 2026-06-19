"""
SmartPark — Upload Dataset & Model to Hugging Face Hub
=======================================================

Prerequisites:
    pip install huggingface_hub

Usage:
    # Login first (one-time):
    huggingface-cli login

    # Upload dataset:
    python scripts/upload_to_huggingface.py --dataset --username yuln0x

    # Upload model:
    python scripts/upload_to_huggingface.py --model --username yuln0x

    # Upload both:
    python scripts/upload_to_huggingface.py --all --username yuln0x
"""

import argparse
import os
import sys
from pathlib import Path

try:
    from huggingface_hub import HfApi, create_repo
except ImportError:
    print("Error: huggingface_hub not installed.")
    print("Run: pip install huggingface_hub")
    sys.exit(1)


# === Configuration ===
PROJECT_ROOT = Path(__file__).resolve().parent.parent

DATASET_DIR = PROJECT_ROOT / "Indonesian License Plate Dataset"
MODEL_DIR = PROJECT_ROOT / "models"
TRAINING_SCRIPT = PROJECT_ROOT / "smartpark_yolo_training.py"
DATASET_CARD = PROJECT_ROOT / "huggingface" / "dataset_card.md"
MODEL_CARD = PROJECT_ROOT / "huggingface" / "model_card.md"

DATASET_REPO_NAME = "smartpark-indonesian-license-plate"
MODEL_REPO_NAME = "smartpark-anpr-yolov8"


def upload_dataset(api: HfApi, username: str):
    """Upload the Indonesian License Plate dataset to Hugging Face."""
    repo_id = f"{username}/{DATASET_REPO_NAME}"

    print(f"\n{'='*60}")
    print(f"  Uploading Dataset to: {repo_id}")
    print(f"{'='*60}\n")

    # Create dataset repository
    try:
        create_repo(
            repo_id=repo_id,
            repo_type="dataset",
            exist_ok=True,
            private=False,
        )
        print(f"  ✓ Repository created/exists: {repo_id}")
    except Exception as e:
        print(f"  ✗ Error creating repo: {e}")
        return False

    # Upload dataset card (README.md)
    if DATASET_CARD.exists():
        api.upload_file(
            path_or_fileobj=str(DATASET_CARD),
            path_in_repo="README.md",
            repo_id=repo_id,
            repo_type="dataset",
        )
        print("  ✓ Uploaded: README.md (dataset card)")

    # Upload images and labels
    if DATASET_DIR.exists():
        print("  ⏳ Uploading dataset files (this may take a few minutes)...")
        api.upload_folder(
            folder_path=str(DATASET_DIR),
            repo_id=repo_id,
            repo_type="dataset",
            commit_message="Upload Indonesian License Plate Dataset",
        )
        print("  ✓ Uploaded: all images and labels")
    else:
        print(f"  ✗ Dataset directory not found: {DATASET_DIR}")
        return False

    print(f"\n  ✅ Dataset available at: https://huggingface.co/datasets/{repo_id}")
    return True


def upload_model(api: HfApi, username: str):
    """Upload the trained ANPR model to Hugging Face."""
    repo_id = f"{username}/{MODEL_REPO_NAME}"

    print(f"\n{'='*60}")
    print(f"  Uploading Model to: {repo_id}")
    print(f"{'='*60}\n")

    # Create model repository
    try:
        create_repo(
            repo_id=repo_id,
            repo_type="model",
            exist_ok=True,
            private=False,
        )
        print(f"  ✓ Repository created/exists: {repo_id}")
    except Exception as e:
        print(f"  ✗ Error creating repo: {e}")
        return False

    # Upload model card (README.md)
    if MODEL_CARD.exists():
        api.upload_file(
            path_or_fileobj=str(MODEL_CARD),
            path_in_repo="README.md",
            repo_id=repo_id,
            repo_type="model",
        )
        print("  ✓ Uploaded: README.md (model card)")

    # Upload model weights
    model_files = {
        "best.pt": MODEL_DIR / "best.pt",
        "best.onnx": MODEL_DIR / "best.onnx",
    }

    for name, path in model_files.items():
        if path.exists():
            print(f"  ⏳ Uploading: {name} ({path.stat().st_size / 1024 / 1024:.1f} MB)...")
            api.upload_file(
                path_or_fileobj=str(path),
                path_in_repo=name,
                repo_id=repo_id,
                repo_type="model",
            )
            print(f"  ✓ Uploaded: {name}")
        else:
            print(f"  ⚠ Skipped (not found): {path}")

    # Upload training script
    if TRAINING_SCRIPT.exists():
        api.upload_file(
            path_or_fileobj=str(TRAINING_SCRIPT),
            path_in_repo="smartpark_yolo_training.py",
            repo_id=repo_id,
            repo_type="model",
        )
        print("  ✓ Uploaded: smartpark_yolo_training.py")

    # Upload training config (data.yaml)
    data_yaml = PROJECT_ROOT / "runs" / "data.yaml"
    if data_yaml.exists():
        api.upload_file(
            path_or_fileobj=str(data_yaml),
            path_in_repo="data.yaml",
            repo_id=repo_id,
            repo_type="model",
        )
        print("  ✓ Uploaded: data.yaml")

    print(f"\n  ✅ Model available at: https://huggingface.co/{repo_id}")
    return True


def main():
    parser = argparse.ArgumentParser(description="Upload SmartPark data to Hugging Face")
    parser.add_argument("--username", required=True, help="Hugging Face username")
    parser.add_argument("--dataset", action="store_true", help="Upload dataset")
    parser.add_argument("--model", action="store_true", help="Upload model")
    parser.add_argument("--all", action="store_true", help="Upload both dataset and model")
    args = parser.parse_args()

    if not (args.dataset or args.model or args.all):
        parser.error("Specify --dataset, --model, or --all")

    api = HfApi()

    # Check authentication
    try:
        whoami = api.whoami()
        print(f"Logged in as: {whoami['name']}")
    except Exception:
        print("Error: Not logged in to Hugging Face.")
        print("Run: huggingface-cli login")
        sys.exit(1)

    results = {}

    if args.dataset or args.all:
        results["dataset"] = upload_dataset(api, args.username)

    if args.model or args.all:
        results["model"] = upload_model(api, args.username)

    # Summary
    print(f"\n{'='*60}")
    print("  UPLOAD SUMMARY")
    print(f"{'='*60}")
    for key, success in results.items():
        status = "✅ Success" if success else "❌ Failed"
        print(f"  {key}: {status}")
    print(f"{'='*60}\n")


if __name__ == "__main__":
    main()
