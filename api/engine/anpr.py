"""
SmartPark - ANPR Engine (Plate Detection using YOLO)

Development can use the trained PyTorch model through Ultralytics. Docker edge
deployment uses the exported ONNX model through OpenCV DNN so Raspberry Pi 5
does not need the large PyTorch runtime.
"""

import time
from pathlib import Path

import cv2
import numpy as np

from api.config import (
    ANPR_CONFIDENCE_THRESHOLD,
    ANPR_FALLBACK_MODEL,
    ANPR_IMAGE_SIZE,
    ANPR_MODEL_PATH,
    ANPR_NMS_THRESHOLD,
)


class ANPREngine:
    """License plate detector supporting Ultralytics and OpenCV ONNX."""

    def __init__(self):
        self.model = None
        self.model_path = None
        self.model_backend = ""
        self.using_trained_model = False
        self.class_names = {0: "license_plate"}
        self._load_model()

    def _load_model(self):
        """Load trained ONNX/PT model, with COCO fallback for local testing."""
        if ANPR_MODEL_PATH.exists():
            self.model_path = str(ANPR_MODEL_PATH)
            self.using_trained_model = True
            print(f"[ANPR] Loading trained model: {ANPR_MODEL_PATH}")
        else:
            self.model_path = ANPR_FALLBACK_MODEL
            self.using_trained_model = False
            print(f"[ANPR] WARNING: trained model not found: {ANPR_MODEL_PATH}")
            print(f"[ANPR] Using COCO fallback: {ANPR_FALLBACK_MODEL}")
            print("[ANPR] COCO fallback detects vehicles, NOT license plates!")

        if Path(self.model_path).suffix.lower() == ".onnx":
            self.model_backend = "opencv_onnx"
            self.model = cv2.dnn.readNetFromONNX(self.model_path)
        else:
            self.model_backend = "ultralytics"
            try:
                from ultralytics import YOLO
            except ImportError as exc:
                raise RuntimeError(
                    "Ultralytics is required for PT models. "
                    "Use SMARTPARK_ANPR_MODEL_PATH=models/best.onnx for edge deployment."
                ) from exc
            self.model = YOLO(self.model_path)
            self.class_names = self.model.names

        print(f"[ANPR] Model loaded. Backend: {self.model_backend}")
        print(f"[ANPR] Classes: {self.class_names}")
        print(f"[ANPR] Using trained plate model: {self.using_trained_model}")

    @property
    def is_loaded(self) -> bool:
        return self.model is not None

    @staticmethod
    def _letterbox(image: np.ndarray, imgsz: int) -> tuple[np.ndarray, float, tuple[int, int]]:
        """Resize with YOLO-style padding while preserving image aspect ratio."""
        height, width = image.shape[:2]
        scale = min(imgsz / width, imgsz / height)
        resized_w = int(round(width * scale))
        resized_h = int(round(height * scale))
        resized = cv2.resize(image, (resized_w, resized_h), interpolation=cv2.INTER_LINEAR)

        pad_w = imgsz - resized_w
        pad_h = imgsz - resized_h
        left = pad_w // 2
        right = pad_w - left
        top = pad_h // 2
        bottom = pad_h - top

        padded = cv2.copyMakeBorder(
            resized,
            top,
            bottom,
            left,
            right,
            cv2.BORDER_CONSTANT,
            value=(114, 114, 114),
        )
        return padded, scale, (left, top)

    def _detect_onnx(self, image_path: str, conf: float, imgsz: int) -> list[dict]:
        image = cv2.imread(image_path)
        if image is None:
            return []

        input_image, scale, (pad_x, pad_y) = self._letterbox(image, imgsz)
        blob = cv2.dnn.blobFromImage(
            input_image,
            scalefactor=1 / 255.0,
            size=(imgsz, imgsz),
            swapRB=True,
            crop=False,
        )
        self.model.setInput(blob)
        output = self.model.forward()

        predictions = np.squeeze(output)
        if predictions.ndim != 2:
            return []
        if predictions.shape[0] < predictions.shape[1]:
            predictions = predictions.T

        boxes = []
        scores = []
        class_ids = []
        for row in predictions:
            class_scores = row[4:]
            if class_scores.size == 0:
                continue
            class_id = int(np.argmax(class_scores))
            score = float(class_scores[class_id])
            if score < conf:
                continue

            center_x, center_y, width, height = row[:4]
            if max(abs(center_x), abs(center_y), abs(width), abs(height)) <= 2.0:
                center_x, center_y, width, height = row[:4] * imgsz
            x = float(center_x - width / 2)
            y = float(center_y - height / 2)
            boxes.append([x, y, float(width), float(height)])
            scores.append(score)
            class_ids.append(class_id)

        indices = cv2.dnn.NMSBoxes(boxes, scores, conf, ANPR_NMS_THRESHOLD)
        if len(indices) == 0:
            return []

        image_h, image_w = image.shape[:2]
        detections = []
        for index in np.array(indices).flatten():
            x, y, width, height = boxes[index]
            x1 = max(0.0, min(float(image_w), (x - pad_x) / scale))
            y1 = max(0.0, min(float(image_h), (y - pad_y) / scale))
            x2 = max(0.0, min(float(image_w), (x + width - pad_x) / scale))
            y2 = max(0.0, min(float(image_h), (y + height - pad_y) / scale))
            class_id = class_ids[index]
            detections.append({
                "bbox": {"x1": x1, "y1": y1, "x2": x2, "y2": y2},
                "confidence": scores[index],
                "class_id": class_id,
                "class_name": self.class_names.get(class_id, f"class_{class_id}"),
            })
        return detections

    def _detect_ultralytics(self, image_path: str, conf: float, imgsz: int) -> list[dict]:
        results = self.model.predict(
            source=image_path,
            conf=conf,
            imgsz=imgsz,
            verbose=False,
        )

        detections = []
        if results[0].boxes is not None:
            for box in results[0].boxes:
                x1, y1, x2, y2 = box.xyxy[0].cpu().numpy().tolist()
                class_id = int(box.cls[0].cpu().numpy())
                detections.append({
                    "bbox": {"x1": x1, "y1": y1, "x2": x2, "y2": y2},
                    "confidence": float(box.conf[0].cpu().numpy()),
                    "class_id": class_id,
                    "class_name": self.class_names.get(class_id, f"class_{class_id}"),
                })
        return detections

    def detect(
        self,
        image_path: str,
        conf: float | None = None,
        imgsz: int | None = None,
    ) -> dict:
        """Detect license plates in an image."""
        conf = conf or ANPR_CONFIDENCE_THRESHOLD
        imgsz = imgsz or ANPR_IMAGE_SIZE

        start = time.perf_counter()
        if self.model_backend == "opencv_onnx":
            detections = self._detect_onnx(image_path, conf, imgsz)
        else:
            detections = self._detect_ultralytics(image_path, conf, imgsz)
        elapsed_ms = (time.perf_counter() - start) * 1000

        if self.using_trained_model:
            model_type = "trained_onnx" if self.model_backend == "opencv_onnx" else "trained"
        else:
            model_type = "coco_fallback"

        return {
            "detections": detections,
            "count": len(detections),
            "inference_time_ms": round(elapsed_ms, 2),
            "model_type": model_type,
        }

    def detect_and_crop(
        self,
        image_path: str,
        conf: float | None = None,
        nearest_only: bool = False,
    ) -> list[dict]:
        """
        Detect plates and return padded crop arrays for OCR.

        When nearest_only is true, keep only the largest plate bounding box,
        which is normally the vehicle closest to the gate camera.
        """
        result = self.detect(image_path, conf=conf)
        image = cv2.imread(image_path)
        if image is None:
            return []

        image_h, image_w = image.shape[:2]
        crops = []
        for detection in result["detections"]:
            bbox = detection["bbox"]
            x1, y1 = int(bbox["x1"]), int(bbox["y1"])
            x2, y2 = int(bbox["x2"]), int(bbox["y2"])

            pad_x = int((x2 - x1) * 0.10)
            pad_y = int((y2 - y1) * 0.15)
            x1 = max(0, x1 - pad_x)
            y1 = max(0, y1 - pad_y)
            x2 = min(image_w, x2 + pad_x)
            y2 = min(image_h, y2 + pad_y)

            crop = image[y1:y2, x1:x2]
            if crop.size > 0:
                crops.append({
                    "crop": crop,
                    "bbox": {
                        "x1": float(x1),
                        "y1": float(y1),
                        "x2": float(x2),
                        "y2": float(y2),
                    },
                    "confidence": detection["confidence"],
                    "class_name": detection["class_name"],
                    "area": (x2 - x1) * (y2 - y1),
                })

        if nearest_only and len(crops) > 1:
            crops = [max(crops, key=lambda item: item["area"])]

        for crop in crops:
            crop.pop("area", None)
        return crops
