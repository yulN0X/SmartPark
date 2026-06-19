"""
SmartPark API - Pydantic Schemas (Request/Response models)
"""

from pydantic import BaseModel, Field
from typing import Optional


# === ANPR (Plate Detection) ===

class BoundingBox(BaseModel):
    x1: float
    y1: float
    x2: float
    y2: float


class PlateDetection(BaseModel):
    bbox: BoundingBox
    confidence: float = Field(ge=0.0, le=1.0)
    class_id: int = 0
    class_name: str = "license_plate"  # actual name from model


class ANPRResponse(BaseModel):
    success: bool
    image_name: str
    detections: list[PlateDetection]
    count: int
    inference_time_ms: float
    model_type: str = "trained"  # "trained" or "coco_fallback"


# === OCR ===

class PlateComponents(BaseModel):
    raw_text: str = ""
    normalized_plate: str = ""
    prefix_letters: str = ""
    middle_numbers: str = ""
    suffix_letters: str = ""
    plate_type: str = "unknown"
    is_valid: bool = False


class OCRResult(BaseModel):
    plate_text: str
    ocr_confidence: float = Field(ge=0.0, le=1.0)
    plate: PlateComponents = Field(default_factory=PlateComponents)
    bbox: Optional[BoundingBox] = None


class OCRResponse(BaseModel):
    success: bool
    image_name: str
    plates: list[OCRResult]
    count: int
    processing_time_ms: float


# === Full Pipeline ===

class VehicleInfo(BaseModel):
    color: str = "unknown"


class ScoreBreakdown(BaseModel):
    plate: float
    color: float


class AccessDecision(BaseModel):
    score: float
    decision: str  # GRANTED, GRANTED_WITH_LOG, DENIED
    action: str


class PipelineResult(BaseModel):
    plate_text: str
    plate_confidence: float
    ocr_confidence: float
    plate: PlateComponents = Field(default_factory=PlateComponents)
    bbox: Optional[BoundingBox] = None  # plate box in original image pixels, for overlay drawing
    vehicle: VehicleInfo
    access: AccessDecision
    score_breakdown: ScoreBreakdown


class PipelineResponse(BaseModel):
    success: bool
    image_name: str
    results: list[PipelineResult]
    processing_time_ms: float


# === Prototype Device Integration ===

class DeviceTriggerRequest(BaseModel):
    device_id: str = Field(default="esp32-gate-1", description="ESP32/controller identifier")
    gate_id: str = Field(default="GATE-A-IN", description="Gate identifier")
    gate_type: str = Field(default="entry", pattern="^(entry|exit)$")
    sensor: str = Field(default="ultrasonic", description="Trigger source, e.g. ultrasonic or infrared")
    distance_cm: Optional[float] = Field(default=None, ge=0.0)
    registered_color: str = Field(default="", description="Expected vehicle color from database, optional")
    confidence: float = Field(default=0.25, ge=0.01, le=1.0)
    nearest_only: bool = True
    camera_index: Optional[int] = Field(default=None, ge=0)


class CaptureInfo(BaseModel):
    image_name: str
    image_path: str
    camera_index: int
    captured_at: str
    saved: bool


class DeviceCommand(BaseModel):
    action: str
    gate_open_seconds: float
    reason: str


class DeviceTriggerResponse(BaseModel):
    success: bool
    device_id: str
    gate_id: str
    gate_type: str
    sensor: str
    capture: CaptureInfo
    command: DeviceCommand
    pipeline: PipelineResponse


class DeviceStatusResponse(BaseModel):
    mode: str
    camera_index: int
    save_captures: bool
    gate_open_seconds: float
    endpoints: dict[str, str]


# === ESP32-CAM Streaming Camera Registry ===

class CameraRegisterRequest(BaseModel):
    """An ESP32-CAM announces its IP + stream/capture URLs on boot."""
    device_id: str = Field(default="esp32cam-gate-1")
    gate_id: str = Field(default="GATE-A-IN")
    gate_type: str = Field(default="entry", pattern="^(entry|exit)$")
    ip: str = Field(description="ESP32-CAM IP on the LAN, e.g. 192.168.1.50")
    stream_url: str = Field(default="", description="MJPEG stream URL; derived from ip if empty")
    capture_url: str = Field(default="", description="Single-JPEG URL; derived from ip if empty")


class CameraInfo(BaseModel):
    device_id: str
    gate_id: str
    gate_type: str
    ip: str
    stream_url: str
    capture_url: str
    last_seen: str
    online: bool = True


class CameraListResponse(BaseModel):
    cameras: list[CameraInfo]


class ScanResponse(BaseModel):
    success: bool
    gate_id: str
    gate_type: str
    event_id: int
    source_url: str
    pipeline: PipelineResponse


# === Batch Responses ===

class BatchANPRResponse(BaseModel):
    success: bool
    total_files: int
    results: list[ANPRResponse]
    total_processing_time_ms: float


class BatchOCRResponse(BaseModel):
    success: bool
    total_files: int
    results: list[OCRResponse]
    total_processing_time_ms: float


class BatchPipelineResponse(BaseModel):
    success: bool
    total_files: int
    results: list[PipelineResponse]
    total_processing_time_ms: float


# === Health Check ===

class HealthResponse(BaseModel):
    status: str
    anpr_model_loaded: bool
    ocr_engine_loaded: bool
    version: str
