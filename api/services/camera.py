"""Local camera capture helpers for prototype device mode."""

import uuid
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path

import cv2

from api.config import CAPTURE_DIR, DEVICE_CAMERA_INDEX, DEVICE_CAPTURE_WARMUP_FRAMES


class CameraCaptureError(RuntimeError):
    """Raised when the local camera cannot produce a frame."""


@dataclass
class CameraCapture:
    image_name: str
    image_path: Path
    camera_index: int
    captured_at: str


def capture_local_frame(camera_index: int | None = None) -> CameraCapture:
    """Capture a single JPEG frame from the configured local camera."""
    index = DEVICE_CAMERA_INDEX if camera_index is None else camera_index
    CAPTURE_DIR.mkdir(parents=True, exist_ok=True)

    cap = cv2.VideoCapture(index)
    if not cap.isOpened():
        cap.release()
        raise CameraCaptureError(f"Camera index {index} cannot be opened")

    frame = None
    try:
        warmup_frames = max(1, DEVICE_CAPTURE_WARMUP_FRAMES)
        for _ in range(warmup_frames):
            ok, candidate = cap.read()
            if ok and candidate is not None:
                frame = candidate

        if frame is None:
            raise CameraCaptureError(f"Camera index {index} did not return a frame")

        captured_at = datetime.now(timezone.utc).isoformat()
        image_name = f"capture_{uuid.uuid4().hex}.jpg"
        image_path = CAPTURE_DIR / image_name

        if not cv2.imwrite(str(image_path), frame):
            raise CameraCaptureError(f"Failed to write capture to {image_path}")

        return CameraCapture(
            image_name=image_name,
            image_path=image_path,
            camera_index=index,
            captured_at=captured_at,
        )
    finally:
        cap.release()
