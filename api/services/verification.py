"""
Reusable vehicle verification pipeline.

Routers can call this service with an image path regardless of where the
image came from: upload, local webcam capture, or future Raspberry Pi camera.
"""

import time

from api.engine.vehicle import compute_access_decision
from api.schemas import (
    AccessDecision,
    BoundingBox,
    PlateComponents,
    PipelineResponse,
    PipelineResult,
    ScoreBreakdown,
    VehicleInfo,
)


def run_vehicle_verification(
    image_path: str,
    image_name: str,
    anpr_engine,
    ocr_engine,
    vehicle_classifier,
    confidence: float = 0.25,
    registered_color: str = "",
    nearest_only: bool = True,
) -> PipelineResponse:
    """Run detect -> OCR -> color -> score on a local image path."""
    if not anpr_engine or not anpr_engine.is_loaded:
        raise RuntimeError("ANPR model not loaded")

    start = time.perf_counter()

    crops = anpr_engine.detect_and_crop(
        image_path,
        conf=confidence,
        nearest_only=nearest_only,
    )

    if not crops:
        elapsed_ms = (time.perf_counter() - start) * 1000
        denied = compute_access_decision(0.0, False)
        return PipelineResponse(
            success=True,
            image_name=image_name,
            results=[
                PipelineResult(
                    plate_text="",
                    plate_confidence=0.0,
                    ocr_confidence=0.0,
                    vehicle=VehicleInfo(),
                    access=AccessDecision(**denied),
                    score_breakdown=ScoreBreakdown(**denied["breakdown"]),
                )
            ],
            processing_time_ms=round(elapsed_ms, 2),
        )

    vehicle_color = "unknown"
    if vehicle_classifier:
        vehicle_color = vehicle_classifier.detect_color(image_path, crops[0]["bbox"])

    results = []
    for crop_data in crops:
        ocr_result = {"text": "", "confidence": 0.0}
        if ocr_engine and ocr_engine.is_loaded:
            ocr_result = ocr_engine.read_text(crop_data["crop"])

        expected_color = registered_color.strip()
        if expected_color:
            color_match = vehicle_color.lower() == expected_color.lower()
        else:
            color_match = vehicle_color != "unknown"

        decision = compute_access_decision(
            plate_confidence=crop_data["confidence"],
            color_match=color_match,
        )

        results.append(
            PipelineResult(
                plate_text=ocr_result.get("text", ""),
                plate_confidence=crop_data["confidence"],
                ocr_confidence=ocr_result.get("confidence", 0.0),
                plate=PlateComponents(**ocr_result.get("plate", {})),
                bbox=BoundingBox(**crop_data["bbox"]),
                vehicle=VehicleInfo(color=vehicle_color),
                access=AccessDecision(**decision),
                score_breakdown=ScoreBreakdown(**decision["breakdown"]),
            )
        )

    elapsed_ms = (time.perf_counter() - start) * 1000
    return PipelineResponse(
        success=True,
        image_name=image_name,
        results=results,
        processing_time_ms=round(elapsed_ms, 2),
    )
