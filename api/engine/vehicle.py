"""
SmartPark - Vehicle Feature Extraction + Decision Scoring

Handles:
  1. Vehicle color detection (HSV histogram)
  2. Multi-signal confidence scoring (plate + color)
"""

import cv2
import numpy as np

from api.config import (
    SCORE_WEIGHT_PLATE,
    SCORE_WEIGHT_COLOR,
    THRESHOLD_HIGH,
    THRESHOLD_MEDIUM,
)


class VehicleClassifier:
    """Vehicle color classification."""

    def detect_color(self, image_path: str, plate_bbox: dict) -> str:
        """
        Detect vehicle color from the body area above the plate.

        Args:
            image_path: Full image path
            plate_bbox: dict with x1, y1, x2, y2

        Returns:
            Color string (e.g., 'black', 'white', 'red', ...)
        """
        img = cv2.imread(image_path)
        if img is None:
            return "unknown"

        h, w = img.shape[:2]
        x1, y1 = int(plate_bbox["x1"]), int(plate_bbox["y1"])
        x2, y2 = int(plate_bbox["x2"]), int(plate_bbox["y2"])

        # Sample body area: region above the plate
        plate_h = y2 - y1
        body_y1 = max(0, y1 - plate_h * 5)
        body_y2 = y1
        body_x1 = max(0, x1 - 20)
        body_x2 = min(w, x2 + 20)

        body_crop = img[int(body_y1):int(body_y2), int(body_x1):int(body_x2)]
        if body_crop.size == 0:
            return "unknown"

        hsv = cv2.cvtColor(body_crop, cv2.COLOR_BGR2HSV)
        avg_h = float(np.mean(hsv[:, :, 0]))
        avg_s = float(np.mean(hsv[:, :, 1]))
        avg_v = float(np.mean(hsv[:, :, 2]))

        if avg_s < 40 and avg_v > 180:
            return "white"
        elif avg_s < 40 and avg_v < 80:
            return "black"
        elif avg_s < 50:
            return "silver"
        elif avg_h < 10 or avg_h > 160:
            return "red"
        elif 10 <= avg_h < 25:
            return "orange"
        elif 25 <= avg_h < 35:
            return "yellow"
        elif 35 <= avg_h < 85:
            return "green"
        elif 85 <= avg_h < 130:
            return "blue"
        else:
            return "unknown"


def compute_access_decision(
    plate_confidence: float,
    color_match: bool,
) -> dict:
    """
    Compute weighted access decision score.

    Score = (plate × 0.70) + (color × 0.30)

    Returns:
        dict with score, decision, action, breakdown
    """
    color_score = 1.0 if color_match else 0.0

    score = (
        plate_confidence * SCORE_WEIGHT_PLATE
        + color_score * SCORE_WEIGHT_COLOR
    )

    if score >= THRESHOLD_HIGH:
        decision, action = "GRANTED", "Gate opens automatically"
    elif score >= THRESHOLD_MEDIUM:
        decision, action = "GRANTED_WITH_LOG", "Gate opens, logged for review"
    else:
        decision, action = "DENIED", "Fallback to manual verification"

    return {
        "score": round(score, 4),
        "decision": decision,
        "action": action,
        "breakdown": {
            "plate": round(plate_confidence * SCORE_WEIGHT_PLATE, 4),
            "color": round(color_score * SCORE_WEIGHT_COLOR, 4),
        },
    }
