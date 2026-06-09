"""
SmartPark API - Configuration
"""

import os
from pathlib import Path

# === Paths ===
BASE_DIR = Path(__file__).resolve().parent.parent
MODEL_DIR = BASE_DIR / "models"
UPLOAD_DIR = BASE_DIR / "uploads"
CAPTURE_DIR = UPLOAD_DIR / "captures"
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)
CAPTURE_DIR.mkdir(parents=True, exist_ok=True)
MODEL_DIR.mkdir(parents=True, exist_ok=True)

# === Model Weights ===
# Local development defaults to PyTorch. Docker edge deployment overrides this
# with /app/models/best.onnx to avoid shipping PyTorch on Raspberry Pi.
ANPR_MODEL_PATH = Path(os.getenv("SMARTPARK_ANPR_MODEL_PATH", str(MODEL_DIR / "best.pt")))
# Fallback to pretrained YOLOv8n if best.pt not available (for testing)
ANPR_FALLBACK_MODEL = "yolov8n.pt"

# === ANPR Settings ===
ANPR_CONFIDENCE_THRESHOLD = 0.25
ANPR_IMAGE_SIZE = 640
ANPR_NMS_THRESHOLD = 0.45

# === OCR Settings ===
# FastPlateOCR uses ONNX Runtime and a compact license-plate-specific model.
# Set both custom paths when switching to an Indonesian fine-tuned model.
OCR_MODEL_NAME = os.getenv("SMARTPARK_OCR_MODEL", "cct-xs-v2-global-model")
OCR_MODEL_PATH = os.getenv("SMARTPARK_OCR_MODEL_PATH", "")
OCR_PLATE_CONFIG_PATH = os.getenv("SMARTPARK_OCR_CONFIG_PATH", "")
OCR_CACHE_DIR = Path(os.getenv("SMARTPARK_OCR_CACHE_DIR", str(MODEL_DIR / "fast_plate_ocr")))
OCR_DEVICE = os.getenv("SMARTPARK_OCR_DEVICE", "cpu")
OCR_RETRY_CONFIDENCE_THRESHOLD = float(os.getenv("SMARTPARK_OCR_RETRY_CONFIDENCE", "0.75"))

# === Decision Scoring Weights ===
SCORE_WEIGHT_PLATE = 0.70
SCORE_WEIGHT_COLOR = 0.30

# === Thresholds ===
THRESHOLD_HIGH = 0.85
THRESHOLD_MEDIUM = 0.60

# === API Settings ===
API_TITLE = "SmartPark API"
API_VERSION = "1.1.0"
API_DESCRIPTION = "ANPR & OCR API for Smart Parking System"
MAX_UPLOAD_SIZE_MB = 10

# === Prototype Device Settings ===
# Used while Raspberry Pi 5 is not available. The backend runs on a
# laptop/PC, ESP32 sends a trigger, and the backend captures from the
# local camera before running the normal verification pipeline.
DEVICE_CAMERA_INDEX = int(os.getenv("SMARTPARK_CAMERA_INDEX", "0"))
DEVICE_CAPTURE_WARMUP_FRAMES = int(os.getenv("SMARTPARK_CAMERA_WARMUP_FRAMES", "5"))
DEVICE_SAVE_CAPTURES = os.getenv("SMARTPARK_SAVE_CAPTURES", "true").lower() in {
    "1",
    "true",
    "yes",
    "on",
}
DEVICE_GATE_OPEN_SECONDS = float(os.getenv("SMARTPARK_GATE_OPEN_SECONDS", "5"))
