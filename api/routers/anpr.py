"""
SmartPark API - ANPR Router (License Plate Detection)

Endpoints:
  POST /anpr/detect  → Detect license plates in an image
"""

import os
import uuid
from fastapi import APIRouter, UploadFile, File, HTTPException, Query

from api.schemas import ANPRResponse, BatchANPRResponse
from api.config import UPLOAD_DIR, MAX_UPLOAD_SIZE_MB

router = APIRouter(prefix="/anpr", tags=["ANPR - Plate Detection"])

# Engine instance (initialized in main.py via lifespan)
_engine = None


def set_engine(engine):
    global _engine
    _engine = engine


@router.post(
    "/detect",
    response_model=ANPRResponse,
    summary="Detect license plates",
    description="Upload an image to detect license plate bounding boxes and confidence scores.",
)
async def detect_plates(
    file: UploadFile = File(..., description="Image file (JPEG/PNG)"),
    confidence: float = Query(0.25, ge=0.01, le=1.0, description="Confidence threshold"),
):
    """Detect license plates in uploaded image."""
    if _engine is None or not _engine.is_loaded:
        raise HTTPException(status_code=503, detail="ANPR model not loaded")

    # Validate file type
    if file.content_type not in ["image/jpeg", "image/png", "image/jpg"]:
        raise HTTPException(status_code=400, detail="Only JPEG/PNG images accepted")

    # Validate file size
    contents = await file.read()
    if len(contents) > MAX_UPLOAD_SIZE_MB * 1024 * 1024:
        raise HTTPException(status_code=400, detail=f"File too large (max {MAX_UPLOAD_SIZE_MB}MB)")

    # Save temporarily
    ext = os.path.splitext(file.filename)[1] or ".jpg"
    temp_path = UPLOAD_DIR / f"{uuid.uuid4().hex}{ext}"
    try:
        with open(temp_path, "wb") as f:
            f.write(contents)

        # Run detection
        result = _engine.detect(str(temp_path), conf=confidence)

        return ANPRResponse(
            success=True,
            image_name=file.filename,
            detections=result["detections"],
            count=result["count"],
            inference_time_ms=result["inference_time_ms"],
            model_type=result.get("model_type", "unknown"),
        )
    finally:
        temp_path.unlink(missing_ok=True)


@router.post(
    "/detect-batch",
    response_model=BatchANPRResponse,
    summary="Batch detect license plates",
    description="Upload multiple images to detect license plates in all of them.",
)
async def detect_plates_batch(
    files: list[UploadFile] = File(..., description="Multiple image files (JPEG/PNG)"),
    confidence: float = Query(0.25, ge=0.01, le=1.0, description="Confidence threshold"),
):
    """Batch license plate detection on multiple images."""
    if _engine is None or not _engine.is_loaded:
        raise HTTPException(status_code=503, detail="ANPR model not loaded")

    import time
    start = time.perf_counter()
    results = []

    for file in files:
        if file.content_type not in ["image/jpeg", "image/png", "image/jpg"]:
            results.append(ANPRResponse(
                success=False, image_name=file.filename,
                detections=[], count=0, inference_time_ms=0, model_type="error",
            ))
            continue

        contents = await file.read()
        ext = os.path.splitext(file.filename)[1] or ".jpg"
        temp_path = UPLOAD_DIR / f"{uuid.uuid4().hex}{ext}"
        try:
            with open(temp_path, "wb") as f:
                f.write(contents)
            result = _engine.detect(str(temp_path), conf=confidence)
            results.append(ANPRResponse(
                success=True,
                image_name=file.filename,
                detections=result["detections"],
                count=result["count"],
                inference_time_ms=result["inference_time_ms"],
                model_type=result.get("model_type", "unknown"),
            ))
        except Exception as e:
            results.append(ANPRResponse(
                success=False, image_name=file.filename,
                detections=[], count=0, inference_time_ms=0, model_type="error",
            ))
        finally:
            temp_path.unlink(missing_ok=True)

    elapsed_ms = (time.perf_counter() - start) * 1000
    return BatchANPRResponse(
        success=True, total_files=len(files),
        results=results, total_processing_time_ms=round(elapsed_ms, 2),
    )
