"""
SmartPark API - Full Pipeline Router

Endpoints:
  POST /pipeline/verify  → Full verification: detect → OCR → color → decision
"""

import os
import uuid
import time
import functools

import anyio
from fastapi import APIRouter, UploadFile, File, HTTPException, Query

from api.schemas import (
    PipelineResponse,
    PipelineResult,
    VehicleInfo,
    AccessDecision,
    ScoreBreakdown,
    BatchPipelineResponse,
)
from api.config import UPLOAD_DIR, MAX_UPLOAD_SIZE_MB
from api.engine.vehicle import compute_access_decision
from api.services.verification import run_vehicle_verification

router = APIRouter(prefix="/pipeline", tags=["Pipeline - Full Verification"])

# Engine instances
_anpr_engine = None
_ocr_engine = None
_vehicle_classifier = None


def set_engines(anpr_engine, ocr_engine, vehicle_classifier):
    global _anpr_engine, _ocr_engine, _vehicle_classifier
    _anpr_engine = anpr_engine
    _ocr_engine = ocr_engine
    _vehicle_classifier = vehicle_classifier


@router.post(
    "/verify",
    response_model=PipelineResponse,
    summary="Full vehicle verification",
    description=(
        "Complete pipeline: detect plate → OCR → vehicle color → "
        "weighted scoring → access decision. "
        "Optionally pass registered_color to match against DB."
    ),
)
async def verify_vehicle(
    file: UploadFile = File(..., description="Image of vehicle at gate"),
    confidence: float = Query(0.25, ge=0.01, le=1.0, description="Detection confidence"),
    registered_color: str = Query("", description="Expected vehicle color from DB (optional)"),
    nearest_only: bool = Query(True, description="Only process the plate closest to camera"),
):
    """End-to-end: detect → OCR → color → score → decide."""
    if not _anpr_engine or not _anpr_engine.is_loaded:
        raise HTTPException(status_code=503, detail="ANPR model not loaded")

    # Validate upload
    if file.content_type not in ["image/jpeg", "image/png", "image/jpg"]:
        raise HTTPException(status_code=400, detail="Only JPEG/PNG images accepted")

    contents = await file.read()
    if len(contents) > MAX_UPLOAD_SIZE_MB * 1024 * 1024:
        raise HTTPException(status_code=400, detail=f"File too large (max {MAX_UPLOAD_SIZE_MB}MB)")

    ext = os.path.splitext(file.filename)[1] or ".jpg"
    temp_path = UPLOAD_DIR / f"{uuid.uuid4().hex}{ext}"

    try:
        with open(temp_path, "wb") as f:
            f.write(contents)

        # Offload the CPU-bound ML pipeline so it never blocks the event loop.
        return await anyio.to_thread.run_sync(
            functools.partial(
                run_vehicle_verification,
                image_path=str(temp_path),
                image_name=file.filename,
                anpr_engine=_anpr_engine,
                ocr_engine=_ocr_engine,
                vehicle_classifier=_vehicle_classifier,
                confidence=confidence,
                registered_color=registered_color,
                nearest_only=nearest_only,
            )
        )
    finally:
        temp_path.unlink(missing_ok=True)


@router.post(
    "/verify-batch",
    response_model=BatchPipelineResponse,
    summary="Batch full verification",
    description="Upload multiple images for full pipeline verification on each.",
)
async def verify_vehicle_batch(
    files: list[UploadFile] = File(..., description="Multiple image files"),
    confidence: float = Query(0.25, ge=0.01, le=1.0, description="Detection confidence"),
    registered_color: str = Query("", description="Expected vehicle color from DB (optional)"),
    nearest_only: bool = Query(True, description="Only process the plate closest to camera"),
):
    """Batch end-to-end: detect → OCR → color → score → decide for multiple images."""
    if not _anpr_engine or not _anpr_engine.is_loaded:
        raise HTTPException(status_code=503, detail="ANPR model not loaded")

    start = time.perf_counter()
    all_results = []

    for file in files:
        if file.content_type not in ["image/jpeg", "image/png", "image/jpg"]:
            denied = compute_access_decision(0.0, False)
            all_results.append(PipelineResponse(
                success=False, image_name=file.filename,
                results=[PipelineResult(
                    plate_text="", plate_confidence=0.0, ocr_confidence=0.0,
                    vehicle=VehicleInfo(), access=AccessDecision(**denied),
                    score_breakdown=ScoreBreakdown(**denied["breakdown"]),
                )], processing_time_ms=0,
            ))
            continue

        contents = await file.read()
        if len(contents) > MAX_UPLOAD_SIZE_MB * 1024 * 1024:
            denied = compute_access_decision(0.0, False)
            all_results.append(PipelineResponse(
                success=False, image_name=file.filename,
                results=[PipelineResult(
                    plate_text="", plate_confidence=0.0, ocr_confidence=0.0,
                    vehicle=VehicleInfo(), access=AccessDecision(**denied),
                    score_breakdown=ScoreBreakdown(**denied["breakdown"]),
                )], processing_time_ms=0,
            ))
            continue

        ext = os.path.splitext(file.filename)[1] or ".jpg"
        temp_path = UPLOAD_DIR / f"{uuid.uuid4().hex}{ext}"

        try:
            with open(temp_path, "wb") as f:
                f.write(contents)

            all_results.append(run_vehicle_verification(
                image_path=str(temp_path),
                image_name=file.filename,
                anpr_engine=_anpr_engine,
                ocr_engine=_ocr_engine,
                vehicle_classifier=_vehicle_classifier,
                confidence=confidence,
                registered_color=registered_color,
                nearest_only=nearest_only,
            ))
        except Exception:
            denied = compute_access_decision(0.0, False)
            all_results.append(PipelineResponse(
                success=False, image_name=file.filename,
                results=[PipelineResult(
                    plate_text="", plate_confidence=0.0, ocr_confidence=0.0,
                    vehicle=VehicleInfo(), access=AccessDecision(**denied),
                    score_breakdown=ScoreBreakdown(**denied["breakdown"]),
                )], processing_time_ms=0,
            ))
        finally:
            temp_path.unlink(missing_ok=True)

    elapsed_ms = (time.perf_counter() - start) * 1000
    return BatchPipelineResponse(
        success=True, total_files=len(files),
        results=all_results, total_processing_time_ms=round(elapsed_ms, 2),
    )
