"""
SmartPark API - OCR Router (License Plate Text Recognition)

Endpoints:
  POST /ocr/read          → Detect plate + extract text (full pipeline)
  POST /ocr/read-cropped  → Extract text from pre-cropped plate image
"""

import os
import uuid
from fastapi import APIRouter, UploadFile, File, HTTPException, Query

from api.schemas import OCRResponse, OCRResult, BoundingBox, BatchOCRResponse, PlateComponents
from api.config import UPLOAD_DIR, MAX_UPLOAD_SIZE_MB

router = APIRouter(prefix="/ocr", tags=["OCR - Plate Text Recognition"])

# Engine instances (initialized in main.py via lifespan)
_anpr_engine = None
_ocr_engine = None


def set_engines(anpr_engine, ocr_engine):
    global _anpr_engine, _ocr_engine
    _anpr_engine = anpr_engine
    _ocr_engine = ocr_engine


async def _save_upload(file: UploadFile) -> tuple[bytes, str]:
    """Validate and save uploaded file. Returns (contents, temp_path)."""
    if file.content_type not in ["image/jpeg", "image/png", "image/jpg"]:
        raise HTTPException(status_code=400, detail="Only JPEG/PNG images accepted")

    contents = await file.read()
    if len(contents) > MAX_UPLOAD_SIZE_MB * 1024 * 1024:
        raise HTTPException(status_code=400, detail=f"File too large (max {MAX_UPLOAD_SIZE_MB}MB)")

    ext = os.path.splitext(file.filename)[1] or ".jpg"
    temp_path = UPLOAD_DIR / f"{uuid.uuid4().hex}{ext}"
    with open(temp_path, "wb") as f:
        f.write(contents)
    return contents, str(temp_path)


@router.post(
    "/read",
    response_model=OCRResponse,
    summary="Detect plate + OCR",
    description="Upload a full image. Detects plates first, then runs OCR on each detected plate.",
)
async def read_plate(
    file: UploadFile = File(..., description="Full image with vehicle"),
    confidence: float = Query(0.25, ge=0.01, le=1.0, description="Detection confidence threshold"),
    nearest_only: bool = Query(True, description="Only process the plate closest to camera"),
):
    """Full pipeline: detect plates → crop → OCR."""
    if not _anpr_engine or not _anpr_engine.is_loaded:
        raise HTTPException(status_code=503, detail="ANPR model not loaded")
    if not _ocr_engine or not _ocr_engine.is_loaded:
        raise HTTPException(status_code=503, detail="OCR engine not loaded")

    _, temp_path = await _save_upload(file)
    import time
    start = time.perf_counter()

    try:
        # Step 1: Detect and crop plates
        crops = _anpr_engine.detect_and_crop(temp_path, conf=confidence, nearest_only=nearest_only)

        # Step 2: OCR on each crop
        plates = []
        for crop_data in crops:
            ocr_result = _ocr_engine.read_text(crop_data["crop"])
            bbox = crop_data["bbox"]
            plates.append(OCRResult(
                plate_text=ocr_result["text"],
                ocr_confidence=ocr_result["confidence"],
                plate=PlateComponents(**ocr_result.get("plate", {})),
                bbox=BoundingBox(**bbox),
            ))

        elapsed_ms = (time.perf_counter() - start) * 1000

        return OCRResponse(
            success=True,
            image_name=file.filename,
            plates=plates,
            count=len(plates),
            processing_time_ms=round(elapsed_ms, 2),
        )
    finally:
        from pathlib import Path
        Path(temp_path).unlink(missing_ok=True)


@router.post(
    "/read-cropped",
    response_model=OCRResponse,
    summary="OCR on cropped plate",
    description="Upload a pre-cropped plate image. Runs OCR directly (no detection step).",
)
async def read_cropped_plate(
    file: UploadFile = File(..., description="Cropped plate image"),
):
    """OCR only on a pre-cropped plate image (skips detection)."""
    if not _ocr_engine or not _ocr_engine.is_loaded:
        raise HTTPException(status_code=503, detail="OCR engine not loaded")

    _, temp_path = await _save_upload(file)
    import time
    start = time.perf_counter()

    try:
        ocr_result = _ocr_engine.read_from_image_path(temp_path)
        elapsed_ms = (time.perf_counter() - start) * 1000

        plates = []
        if ocr_result["text"]:
            plates.append(OCRResult(
                plate_text=ocr_result["text"],
                ocr_confidence=ocr_result["confidence"],
                plate=PlateComponents(**ocr_result.get("plate", {})),
                bbox=None,
            ))

        return OCRResponse(
            success=True,
            image_name=file.filename,
            plates=plates,
            count=len(plates),
            processing_time_ms=round(elapsed_ms, 2),
        )
    finally:
        from pathlib import Path
        Path(temp_path).unlink(missing_ok=True)


@router.post(
    "/read-batch",
    response_model=BatchOCRResponse,
    summary="Batch detect + OCR",
    description="Upload multiple images. Detects plates and runs OCR on each.",
)
async def read_plate_batch(
    files: list[UploadFile] = File(..., description="Multiple image files"),
    confidence: float = Query(0.25, ge=0.01, le=1.0, description="Detection confidence threshold"),
    nearest_only: bool = Query(True, description="Only process the plate closest to camera"),
):
    """Batch pipeline: detect plates → crop → OCR for multiple images."""
    if not _anpr_engine or not _anpr_engine.is_loaded:
        raise HTTPException(status_code=503, detail="ANPR model not loaded")
    if not _ocr_engine or not _ocr_engine.is_loaded:
        raise HTTPException(status_code=503, detail="OCR engine not loaded")

    import time
    from pathlib import Path
    start = time.perf_counter()
    results = []

    for file in files:
        if file.content_type not in ["image/jpeg", "image/png", "image/jpg"]:
            results.append(OCRResponse(
                success=False, image_name=file.filename, plates=[], count=0, processing_time_ms=0,
            ))
            continue

        contents = await file.read()
        ext = os.path.splitext(file.filename)[1] or ".jpg"
        temp_path = UPLOAD_DIR / f"{uuid.uuid4().hex}{ext}"
        file_start = time.perf_counter()
        try:
            with open(temp_path, "wb") as f:
                f.write(contents)

            crops = _anpr_engine.detect_and_crop(str(temp_path), conf=confidence, nearest_only=nearest_only)
            plates = []
            for crop_data in crops:
                ocr_result = _ocr_engine.read_text(crop_data["crop"])
                bbox = crop_data["bbox"]
                plates.append(OCRResult(
                    plate_text=ocr_result["text"],
                    ocr_confidence=ocr_result["confidence"],
                    plate=PlateComponents(**ocr_result.get("plate", {})),
                    bbox=BoundingBox(**bbox),
                ))

            file_ms = (time.perf_counter() - file_start) * 1000
            results.append(OCRResponse(
                success=True, image_name=file.filename,
                plates=plates, count=len(plates), processing_time_ms=round(file_ms, 2),
            ))
        except Exception:
            results.append(OCRResponse(
                success=False, image_name=file.filename, plates=[], count=0, processing_time_ms=0,
            ))
        finally:
            Path(temp_path).unlink(missing_ok=True)

    elapsed_ms = (time.perf_counter() - start) * 1000
    return BatchOCRResponse(
        success=True, total_files=len(files),
        results=results, total_processing_time_ms=round(elapsed_ms, 2),
    )
