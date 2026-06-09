"""
SmartPark API - Color Detection Router

Endpoints:
  POST /color/detect  → Detect vehicle color from image + plate bounding box
"""

import os
import uuid
from fastapi import APIRouter, UploadFile, File, HTTPException, Query
from pydantic import BaseModel

from api.config import UPLOAD_DIR, MAX_UPLOAD_SIZE_MB

router = APIRouter(prefix="/color", tags=["Color - Vehicle Color Detection"])

# Engine instances
_anpr_engine = None
_vehicle_classifier = None


def set_engines(anpr_engine, vehicle_classifier):
    global _anpr_engine, _vehicle_classifier
    _anpr_engine = anpr_engine
    _vehicle_classifier = vehicle_classifier


# === Response schemas ===

class ColorResult(BaseModel):
    color: str
    plate_bbox: dict
    plate_confidence: float


class ColorResponse(BaseModel):
    success: bool
    image_name: str
    results: list[ColorResult]
    count: int
    processing_time_ms: float


@router.post(
    "/detect",
    response_model=ColorResponse,
    summary="Detect vehicle color",
    description=(
        "Upload an image to detect vehicle color. "
        "First detects the license plate to locate the vehicle, "
        "then analyzes the body area above the plate using HSV histogram."
    ),
)
async def detect_color(
    file: UploadFile = File(..., description="Image of vehicle"),
    confidence: float = Query(0.25, ge=0.01, le=1.0, description="Plate detection confidence"),
    nearest_only: bool = Query(True, description="Only process the plate closest to camera"),
):
    """Detect plate → use plate bbox to locate body → classify color via HSV."""
    if not _anpr_engine or not _anpr_engine.is_loaded:
        raise HTTPException(status_code=503, detail="ANPR model not loaded")
    if not _vehicle_classifier:
        raise HTTPException(status_code=503, detail="Vehicle classifier not loaded")

    # Validate file type
    if file.content_type not in ["image/jpeg", "image/png", "image/jpg"]:
        raise HTTPException(status_code=400, detail="Only JPEG/PNG images accepted")

    # Validate file size
    contents = await file.read()
    if len(contents) > MAX_UPLOAD_SIZE_MB * 1024 * 1024:
        raise HTTPException(status_code=400, detail=f"File too large (max {MAX_UPLOAD_SIZE_MB}MB)")

    ext = os.path.splitext(file.filename)[1] or ".jpg"
    temp_path = UPLOAD_DIR / f"{uuid.uuid4().hex}{ext}"

    import time
    start = time.perf_counter()

    try:
        with open(temp_path, "wb") as f:
            f.write(contents)

        temp_str = str(temp_path)

        # Step 1: Detect plates to get bounding boxes
        crops = _anpr_engine.detect_and_crop(temp_str, conf=confidence, nearest_only=nearest_only)

        if not crops:
            elapsed_ms = (time.perf_counter() - start) * 1000
            return ColorResponse(
                success=True,
                image_name=file.filename,
                results=[],
                count=0,
                processing_time_ms=round(elapsed_ms, 2),
            )

        # Step 2: Detect color for each detected plate's body area
        results = []
        for crop_data in crops:
            color = _vehicle_classifier.detect_color(temp_str, crop_data["bbox"])
            results.append(ColorResult(
                color=color,
                plate_bbox=crop_data["bbox"],
                plate_confidence=crop_data["confidence"],
            ))

        elapsed_ms = (time.perf_counter() - start) * 1000

        return ColorResponse(
            success=True,
            image_name=file.filename,
            results=results,
            count=len(results),
            processing_time_ms=round(elapsed_ms, 2),
        )
    finally:
        temp_path.unlink(missing_ok=True)
