"""
Computer Vision service: ANPR (YOLOv8) + OCR (EasyOCR)
Loads the trained YOLOv8 model to detect license plate bounding boxes,
then uses EasyOCR to read the text from the cropped region.
"""

import os
import re
import cv2
import numpy as np
from pathlib import Path
from ultralytics import YOLO
import easyocr

from services.plate import normalize_plate

# ── Model paths ──────────────────────────────────────────────────────
# Search order: YOLO_MODEL_PATH env → ./models/best.pt → SmartPark root
_CANDIDATES = [
    Path(os.environ.get("YOLO_MODEL_PATH", "")),                       # explicit env
    Path(__file__).resolve().parent.parent / "models" / "best.pt",      # parkirboss-api/models/
    Path(__file__).resolve().parent.parent.parent / "models" / "best.pt", # ParkirBoss/models/
    Path(__file__).resolve().parent.parent.parent.parent / "models" / "best.pt",  # SmartPark/models/
]
YOLO_WEIGHTS: Path | None = None
for _p in _CANDIDATES:
    if _p and _p.is_file():
        YOLO_WEIGHTS = _p
        break
if YOLO_WEIGHTS:
    print(f"[VISION] Model found: {YOLO_WEIGHTS}")
else:
    print(f"[VISION] WARNING: No YOLO model found. Searched: {[str(p) for p in _CANDIDATES if str(p)]}")

# ── Lazy-loaded singletons ───────────────────────────────────────────
_yolo_model = None
_ocr_reader = None


def _get_yolo():
    global _yolo_model
    if _yolo_model is None:
        if YOLO_WEIGHTS is None:
            raise RuntimeError(
                "YOLO model not found. Set YOLO_MODEL_PATH env var or place "
                "best.pt in the models/ directory."
            )
        print(f"[VISION] Loading YOLOv8 from {YOLO_WEIGHTS}")
        _yolo_model = YOLO(str(YOLO_WEIGHTS))
    return _yolo_model


def _get_ocr():
    global _ocr_reader
    if _ocr_reader is None:
        print("[VISION] Initialising EasyOCR (en, id) …")
        _ocr_reader = easyocr.Reader(["en"], gpu=False)
    return _ocr_reader


# ── Pre-processing helpers ───────────────────────────────────────────

def _preprocess_plate(crop: np.ndarray) -> np.ndarray:
    """Enhance plate crop for OCR: grayscale → resize → threshold."""
    gray = cv2.cvtColor(crop, cv2.COLOR_BGR2GRAY)
    # Resize so the plate text is roughly 40-60 px tall
    h, w = gray.shape
    if h < 60:
        scale = 60 / h
        gray = cv2.resize(gray, None, fx=scale, fy=scale, interpolation=cv2.INTER_CUBIC)
    # Bilateral filter to reduce noise while keeping edges
    gray = cv2.bilateralFilter(gray, 11, 17, 17)
    # Adaptive threshold for varying lighting
    thresh = cv2.adaptiveThreshold(
        gray, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, cv2.THRESH_BINARY, 31, 10
    )
    return thresh


def _clean_plate_text(raw: str) -> str:
    """
    Normalise raw OCR output into a canonical Indonesian plate format.
    Delegates to the shared ``normalize_plate()`` function so every
    component in the system uses the exact same logic.
    """
    # Light pre-clean: remove OCR artefacts but keep alphanumerics
    text = raw.upper().strip()
    text = re.sub(r"[^A-Z0-9 ]", "", text)
    text = re.sub(r"\s+", " ", text).strip()
    # Canonical normalization (strips spaces → "B1234ABC")
    return normalize_plate(text)


# ── Public API ───────────────────────────────────────────────────────

def detect_plate(image_bytes: bytes) -> dict:
    """
    Full pipeline: image bytes → plate number string.

    Returns
    -------
    dict with keys:
        success : bool
        plate   : str | None     – cleaned plate text (e.g. "B 1234 ABC")
        raw_ocr : str | None     – raw OCR output before cleaning
        confidence : float | None – YOLO detection confidence
        bbox    : list | None    – [x1, y1, x2, y2]
    """
    # Decode image
    nparr = np.frombuffer(image_bytes, np.uint8)
    img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
    if img is None:
        return {"success": False, "plate": None, "raw_ocr": None,
                "confidence": None, "bbox": None, "error": "Cannot decode image"}

    # ① YOLOv8 detection
    model = _get_yolo()
    results = model.predict(img, conf=0.25, verbose=False)

    if len(results) == 0 or len(results[0].boxes) == 0:
        return {"success": False, "plate": None, "raw_ocr": None,
                "confidence": None, "bbox": None, "error": "No plate detected"}

    # Take the highest-confidence detection
    boxes = results[0].boxes
    best_idx = boxes.conf.argmax().item()
    conf = float(boxes.conf[best_idx])
    x1, y1, x2, y2 = [int(v) for v in boxes.xyxy[best_idx].tolist()]

    # Crop plate region (with small padding)
    h, w = img.shape[:2]
    pad = 5
    x1 = max(0, x1 - pad)
    y1 = max(0, y1 - pad)
    x2 = min(w, x2 + pad)
    y2 = min(h, y2 + pad)
    crop = img[y1:y2, x1:x2]

    # ② Pre-process + OCR
    processed = _preprocess_plate(crop)
    reader = _get_ocr()
    ocr_results = reader.readtext(processed, detail=0, paragraph=True)

    if not ocr_results:
        # Fallback: try on the raw crop
        ocr_results = reader.readtext(crop, detail=0, paragraph=True)

    raw_text = " ".join(ocr_results) if ocr_results else ""
    plate = _clean_plate_text(raw_text)

    if not plate:
        return {"success": False, "plate": None, "raw_ocr": raw_text,
                "confidence": conf, "bbox": [x1, y1, x2, y2],
                "error": "OCR could not read plate text"}

    return {
        "success": True,
        "plate": plate,
        "raw_ocr": raw_text,
        "confidence": conf,
        "bbox": [x1, y1, x2, y2],
    }
