"""
Prototype device router.

Use this while Raspberry Pi 5 is not available:
ESP32 sends a sensor trigger, this API captures from the laptop/PC camera,
then the existing SmartPark verification pipeline processes the image.
"""

import functools
import os
import threading
import urllib.error
import urllib.request
import uuid
from datetime import datetime, timezone
from pathlib import Path

import anyio
import cv2
from fastapi import APIRouter, File, Form, HTTPException, Query, UploadFile

from api.config import (
    CAPTURE_DIR,
    DEVICE_CAMERA_INDEX,
    DEVICE_GATE_OPEN_SECONDS,
    DEVICE_SAVE_CAPTURES,
    MAX_UPLOAD_SIZE_MB,
)
from api.schemas import (
    CameraInfo,
    CameraListResponse,
    CameraRegisterRequest,
    CaptureInfo,
    DeviceCommand,
    DeviceStatusResponse,
    DeviceTriggerRequest,
    DeviceTriggerResponse,
    ScanResponse,
)
from api.services.camera import CameraCaptureError, capture_local_frame
from api.services.verification import run_vehicle_verification

router = APIRouter(prefix="/device", tags=["Prototype Device Integration"])

_anpr_engine = None
_ocr_engine = None
_vehicle_classifier = None

IMAGE_CONTENT_TYPES = {
    "image/jpeg",
    "image/jpg",
    "image/png",
    "application/octet-stream",
}


def set_engines(anpr_engine, ocr_engine, vehicle_classifier):
    global _anpr_engine, _ocr_engine, _vehicle_classifier
    _anpr_engine = anpr_engine
    _ocr_engine = ocr_engine
    _vehicle_classifier = vehicle_classifier


# In-memory event log powering the IoT dashboard realtime bridge (GET /device/events).
# Each gate trigger appends one event; the dashboard polls this with ?since=<last_id>.
_EVENTS: list[dict] = []
_EVENTS_LOCK = threading.Lock()
_EVENT_SEQ = 0
_MAX_EVENTS = 200


def _image_size(image_path) -> tuple[int, int]:
    """Return (width, height) of the captured image, or (0, 0) if unreadable."""
    image = cv2.imread(str(image_path))
    if image is None:
        return (0, 0)
    height, width = image.shape[:2]
    return (width, height)


def _emit_event(
    *,
    device_id: str,
    gate_id: str,
    gate_type: str,
    sensor: str,
    pipeline_response,
    command: DeviceCommand,
    image_path,
    image_width: int,
    image_height: int,
    saved: bool,
) -> dict:
    """Record one gate event for the dashboard to pick up on its next poll."""
    global _EVENT_SEQ
    result = pipeline_response.results[0] if pipeline_response.results else None
    bbox = result.bbox.model_dump() if (result and result.bbox) else None
    thumb = f"/captures/{Path(image_path).name}" if saved else None

    with _EVENTS_LOCK:
        _EVENT_SEQ += 1
        event = {
            "id": _EVENT_SEQ,
            "ts": datetime.now(timezone.utc).isoformat(),
            "device_id": device_id,
            "gate_id": gate_id,
            "gate_type": gate_type,
            "sensor": sensor,
            "plate": result.plate_text if result else "",
            "plate_confidence": result.plate_confidence if result else 0.0,
            "ocr_confidence": result.ocr_confidence if result else 0.0,
            "decision": result.access.decision if result else "DENIED",
            "command": command.action,
            "bbox": bbox,
            "image_width": image_width,
            "image_height": image_height,
            "thumb": thumb,
        }
        _EVENTS.append(event)
        if len(_EVENTS) > _MAX_EVENTS:
            del _EVENTS[: len(_EVENTS) - _MAX_EVENTS]
    return event


# In-memory registry of ESP32-CAM streaming cameras, keyed by gate_id.
# An ESP32-CAM calls POST /device/register on boot; the dashboard reads
# GET /device/cameras to show the live stream and drive POST /device/scan.
_CAMERAS: dict[str, dict] = {}
_CAMERAS_LOCK = threading.Lock()
_SCAN_TIMEOUT_S = 6.0


def _derive_camera_urls(ip: str, stream_url: str, capture_url: str) -> tuple[str, str]:
    """Fill in default ESP32-CAM stream/capture URLs from the IP when not given."""
    ip = ip.strip()
    stream = stream_url.strip() or f"http://{ip}:81/stream"
    capture = capture_url.strip() or f"http://{ip}/capture"
    return stream, capture


def _fetch_jpeg(url: str) -> bytes:
    """Pull a single JPEG frame from an ESP32-CAM /capture URL."""
    request = urllib.request.Request(url, headers={"User-Agent": "SmartPark/1.0"})
    with urllib.request.urlopen(request, timeout=_SCAN_TIMEOUT_S) as response:
        return response.read()


def _build_command(gate_type: str, pipeline_response) -> DeviceCommand:
    """Translate prototype pipeline output into a simple gate command."""
    first_result = pipeline_response.results[0] if pipeline_response.results else None
    if first_result and first_result.access.decision in {"GRANTED", "GRANTED_WITH_LOG"}:
        return DeviceCommand(
            action="OPEN_GATE",
            gate_open_seconds=DEVICE_GATE_OPEN_SECONDS,
            reason=first_result.access.action,
        )

    if gate_type == "entry":
        return DeviceCommand(
            action="MANUAL_REQUIRED",
            gate_open_seconds=0.0,
            reason="Prototype entry verification failed; use manual fallback.",
        )

    return DeviceCommand(
        action="KEEP_CLOSED",
        gate_open_seconds=0.0,
        reason="Prototype exit verification failed; gate remains closed.",
    )


def _capture_info(
    image_name: str,
    image_path: Path,
    camera_index: int,
    captured_at: str,
    saved: bool,
) -> CaptureInfo:
    return CaptureInfo(
        image_name=image_name,
        image_path=str(image_path) if saved else "",
        camera_index=camera_index,
        captured_at=captured_at,
        saved=saved,
    )


def _build_response(
    *,
    device_id: str,
    gate_id: str,
    gate_type: str,
    sensor: str,
    capture: CaptureInfo,
    command: DeviceCommand,
    pipeline_response,
) -> DeviceTriggerResponse:
    return DeviceTriggerResponse(
        success=True,
        device_id=device_id,
        gate_id=gate_id,
        gate_type=gate_type,
        sensor=sensor,
        capture=capture,
        command=command,
        pipeline=pipeline_response,
    )


@router.get(
    "/status",
    response_model=DeviceStatusResponse,
    summary="Show prototype device integration settings",
)
async def device_status():
    return DeviceStatusResponse(
        mode="laptop-camera-prototype",
        camera_index=DEVICE_CAMERA_INDEX,
        save_captures=DEVICE_SAVE_CAPTURES,
        gate_open_seconds=DEVICE_GATE_OPEN_SECONDS,
        endpoints={
            "esp32_trigger": "POST /device/trigger",
            "image_upload": "POST /device/process-image",
            "pipeline_upload": "POST /pipeline/verify",
            "camera_register": "POST /device/register",
            "camera_list": "GET /device/cameras",
            "live_scan": "POST /device/scan",
            "event_feed": "GET /device/events",
        },
    )


@router.get(
    "/events",
    summary="Poll recent gate events for the IoT dashboard",
    description=(
        "Returns gate events recorded since the given id. The IoT dashboard "
        "polls this every ~1.5s to render real-time triggers (plate, decision, "
        "bounding box). Pass ?since=<last_id> to fetch only new events."
    ),
)
async def device_events(since: int = Query(0, ge=0, description="Return events with id greater than this")):
    with _EVENTS_LOCK:
        events = [event for event in _EVENTS if event["id"] > since]
        last_id = _EVENTS[-1]["id"] if _EVENTS else 0
    return {"events": events, "last_id": last_id}


@router.post(
    "/register",
    response_model=CameraInfo,
    summary="ESP32-CAM announces its stream/capture URLs",
    description=(
        "An ESP32-CAM calls this on boot so the dashboard can show its live "
        "MJPEG stream and the backend can pull frames for live ANPR via /device/scan."
    ),
)
async def register_camera(req: CameraRegisterRequest):
    stream_url, capture_url = _derive_camera_urls(req.ip, req.stream_url, req.capture_url)
    info = {
        "device_id": req.device_id,
        "gate_id": req.gate_id,
        "gate_type": req.gate_type,
        "ip": req.ip,
        "stream_url": stream_url,
        "capture_url": capture_url,
        "last_seen": datetime.now(timezone.utc).isoformat(),
    }
    with _CAMERAS_LOCK:
        _CAMERAS[req.gate_id] = info
    return CameraInfo(**info, online=True)


@router.get(
    "/cameras",
    response_model=CameraListResponse,
    summary="List registered ESP32-CAM streaming cameras",
)
async def list_cameras():
    with _CAMERAS_LOCK:
        cameras = [CameraInfo(**cam, online=True) for cam in _CAMERAS.values()]
    return CameraListResponse(cameras=cameras)


@router.post(
    "/scan",
    response_model=ScanResponse,
    summary="Pull one frame from an ESP32-CAM and run ANPR live",
    description=(
        "Backend fetches a single JPEG from the camera's /capture URL (resolved "
        "from gate_id via the registry, or passed explicitly), runs ANPR+OCR, and "
        "emits a gate event with the bounding box. The dashboard calls this on an "
        "interval to draw live boxes over the MJPEG stream."
    ),
)
async def scan_camera(
    gate_id: str = Query("", description="Registered gate to scan (uses its /capture URL)"),
    camera_url: str = Query("", description="Explicit ESP32-CAM /capture URL (overrides gate_id)"),
    confidence: float = Query(0.25, ge=0.01, le=1.0),
    registered_color: str = Query("", description="Expected vehicle color from DB (optional)"),
    nearest_only: bool = Query(True),
    sensor: str = Query("auto-scan", description="Sensor label recorded on the event"),
):
    if not _anpr_engine or not _anpr_engine.is_loaded:
        raise HTTPException(status_code=503, detail="ANPR model not loaded")

    # Resolve the capture URL + gate metadata from the registry when possible.
    gate_type = "entry"
    device_id = "esp32cam-scan"
    resolved_gate = gate_id or "GATE-A-IN"
    url = camera_url.strip()
    with _CAMERAS_LOCK:
        cam = _CAMERAS.get(gate_id) if gate_id else None
    if cam:
        gate_type = cam["gate_type"]
        device_id = cam["device_id"]
        resolved_gate = cam["gate_id"]
        if not url:
            url = cam["capture_url"]
    if not url:
        raise HTTPException(
            status_code=404,
            detail=f"No camera_url and no registered camera for gate_id '{gate_id}'",
        )

    try:
        jpeg = await anyio.to_thread.run_sync(_fetch_jpeg, url)
    except (urllib.error.URLError, OSError, ValueError) as exc:
        raise HTTPException(status_code=502, detail=f"Cannot fetch frame from {url}: {exc}") from exc
    if not jpeg:
        raise HTTPException(status_code=502, detail="Camera returned an empty frame")

    image_name = f"scan_{uuid.uuid4().hex}.jpg"
    image_path = CAPTURE_DIR / image_name
    try:
        CAPTURE_DIR.mkdir(parents=True, exist_ok=True)
        with open(image_path, "wb") as f:
            f.write(jpeg)

        pipeline_response = await anyio.to_thread.run_sync(
            functools.partial(
                run_vehicle_verification,
                image_path=str(image_path),
                image_name=image_name,
                anpr_engine=_anpr_engine,
                ocr_engine=_ocr_engine,
                vehicle_classifier=_vehicle_classifier,
                confidence=confidence,
                registered_color=registered_color,
                nearest_only=nearest_only,
            )
        )

        command = _build_command(gate_type, pipeline_response)
        img_w, img_h = await anyio.to_thread.run_sync(_image_size, image_path)
        # Live-stream frames are not persisted (the dashboard shows the MJPEG feed);
        # the event still carries the bbox for the overlay.
        event = _emit_event(
            device_id=device_id,
            gate_id=resolved_gate,
            gate_type=gate_type,
            sensor=sensor,
            pipeline_response=pipeline_response,
            command=command,
            image_path=image_path,
            image_width=img_w,
            image_height=img_h,
            saved=False,
        )

        return ScanResponse(
            success=True,
            gate_id=resolved_gate,
            gate_type=gate_type,
            event_id=event["id"],
            source_url=url,
            pipeline=pipeline_response,
        )
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    finally:
        image_path.unlink(missing_ok=True)


@router.post(
    "/trigger",
    response_model=DeviceTriggerResponse,
    summary="Receive ESP32 sensor trigger and capture from local camera",
    description=(
        "ESP32 sends JSON when a vehicle is detected. The backend captures "
        "one frame from the configured laptop/PC camera and runs the existing "
        "ANPR + OCR + scoring pipeline."
    ),
)
async def trigger_device(request: DeviceTriggerRequest):
    if not _anpr_engine or not _anpr_engine.is_loaded:
        raise HTTPException(status_code=503, detail="ANPR model not loaded")

    try:
        capture = await anyio.to_thread.run_sync(capture_local_frame, request.camera_index)
    except CameraCaptureError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc

    should_keep_capture = DEVICE_SAVE_CAPTURES
    try:
        pipeline_response = await anyio.to_thread.run_sync(
            functools.partial(
                run_vehicle_verification,
                image_path=str(capture.image_path),
                image_name=capture.image_name,
                anpr_engine=_anpr_engine,
                ocr_engine=_ocr_engine,
                vehicle_classifier=_vehicle_classifier,
                confidence=request.confidence,
                registered_color=request.registered_color,
                nearest_only=request.nearest_only,
            )
        )

        command = _build_command(request.gate_type, pipeline_response)
        img_w, img_h = await anyio.to_thread.run_sync(_image_size, capture.image_path)
        _emit_event(
            device_id=request.device_id,
            gate_id=request.gate_id,
            gate_type=request.gate_type,
            sensor=request.sensor,
            pipeline_response=pipeline_response,
            command=command,
            image_path=capture.image_path,
            image_width=img_w,
            image_height=img_h,
            saved=should_keep_capture,
        )

        return _build_response(
            device_id=request.device_id,
            gate_id=request.gate_id,
            gate_type=request.gate_type,
            sensor=request.sensor,
            capture=_capture_info(
                image_name=capture.image_name,
                image_path=capture.image_path,
                camera_index=capture.camera_index,
                captured_at=capture.captured_at,
                saved=should_keep_capture,
            ),
            command=command,
            pipeline_response=pipeline_response,
        )
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    finally:
        if not should_keep_capture:
            capture.image_path.unlink(missing_ok=True)


@router.post(
    "/process-image",
    response_model=DeviceTriggerResponse,
    summary="Process an image sent by ESP32-CAM, phone, or manual upload",
    description=(
        "Alternative to /device/trigger when the image is captured outside "
        "the backend, for example from ESP32-CAM or a phone used as a test camera."
    ),
)
async def process_device_image(
    file: UploadFile = File(..., description="Vehicle image from device/camera"),
    device_id: str = Form("manual-camera"),
    gate_id: str = Form("GATE-A-IN"),
    gate_type: str = Form("entry"),
    sensor: str = Form("camera-upload"),
    registered_color: str = Form(""),
    confidence: float = Form(0.25),
    nearest_only: bool = Form(True),
):
    if gate_type not in {"entry", "exit"}:
        raise HTTPException(status_code=400, detail="gate_type must be entry or exit")
    if confidence < 0.01 or confidence > 1.0:
        raise HTTPException(status_code=400, detail="confidence must be between 0.01 and 1.0")
    if file.content_type not in IMAGE_CONTENT_TYPES:
        raise HTTPException(status_code=400, detail="Only JPEG/PNG images accepted")
    if not _anpr_engine or not _anpr_engine.is_loaded:
        raise HTTPException(status_code=503, detail="ANPR model not loaded")

    contents = await file.read()
    if len(contents) > MAX_UPLOAD_SIZE_MB * 1024 * 1024:
        raise HTTPException(status_code=400, detail=f"File too large (max {MAX_UPLOAD_SIZE_MB}MB)")

    ext = os.path.splitext(file.filename or "")[1] or ".jpg"
    image_name = f"device_{uuid.uuid4().hex}{ext}"
    image_path = CAPTURE_DIR / image_name
    captured_at = datetime.now(timezone.utc).isoformat()
    should_keep_capture = DEVICE_SAVE_CAPTURES

    try:
        CAPTURE_DIR.mkdir(parents=True, exist_ok=True)
        with open(image_path, "wb") as f:
            f.write(contents)

        pipeline_response = await anyio.to_thread.run_sync(
            functools.partial(
                run_vehicle_verification,
                image_path=str(image_path),
                image_name=file.filename or image_name,
                anpr_engine=_anpr_engine,
                ocr_engine=_ocr_engine,
                vehicle_classifier=_vehicle_classifier,
                confidence=confidence,
                registered_color=registered_color,
                nearest_only=nearest_only,
            )
        )

        command = _build_command(gate_type, pipeline_response)
        img_w, img_h = await anyio.to_thread.run_sync(_image_size, image_path)
        _emit_event(
            device_id=device_id,
            gate_id=gate_id,
            gate_type=gate_type,
            sensor=sensor,
            pipeline_response=pipeline_response,
            command=command,
            image_path=image_path,
            image_width=img_w,
            image_height=img_h,
            saved=should_keep_capture,
        )

        return _build_response(
            device_id=device_id,
            gate_id=gate_id,
            gate_type=gate_type,
            sensor=sensor,
            capture=_capture_info(
                image_name=image_name,
                image_path=image_path,
                camera_index=-1,
                captured_at=captured_at,
                saved=should_keep_capture,
            ),
            command=command,
            pipeline_response=pipeline_response,
        )
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    finally:
        if not should_keep_capture:
            image_path.unlink(missing_ok=True)
