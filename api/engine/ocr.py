"""
SmartPark - OCR Engine (Indonesian License Plate Recognition)

Input: cropped plate image -> Output: normalized Indonesian plate components

FastPlateOCR is used instead of a generic document OCR engine. The global XS
model is lightweight enough for Raspberry Pi 5 CPU inference and can later be
replaced with an Indonesian fine-tuned ONNX model through environment variables.
"""

import time

import cv2
import numpy as np

from api.config import (
    OCR_CACHE_DIR,
    OCR_DEVICE,
    OCR_MODEL_NAME,
    OCR_MODEL_PATH,
    OCR_PLATE_CONFIG_PATH,
    OCR_RETRY_CONFIDENCE_THRESHOLD,
)
from api.engine.plate import clean_plate_text, parse_indonesian_plate


class OCREngine:
    """License plate OCR using FastPlateOCR + ONNX Runtime."""

    def __init__(self):
        self.reader = None
        self.model_name = OCR_MODEL_NAME
        self._load_engine()

    def _load_engine(self):
        """Initialize FastPlateOCR recognizer."""
        try:
            from fast_plate_ocr import LicensePlateRecognizer
            from fast_plate_ocr.inference import hub

            hub.MODEL_CACHE_DIR = OCR_CACHE_DIR

            if OCR_MODEL_PATH and OCR_PLATE_CONFIG_PATH:
                self.reader = LicensePlateRecognizer(
                    onnx_model_path=OCR_MODEL_PATH,
                    plate_config_path=OCR_PLATE_CONFIG_PATH,
                    device=OCR_DEVICE,
                )
                self.model_name = OCR_MODEL_PATH
            else:
                self.reader = LicensePlateRecognizer(
                    hub_ocr_model=OCR_MODEL_NAME,
                    device=OCR_DEVICE,
                )
                self.model_name = OCR_MODEL_NAME

            print(f"[OCR] FastPlateOCR loaded (model={self.model_name}, device={OCR_DEVICE})")
        except ImportError:
            print("[OCR] WARNING: fast-plate-ocr not installed.")
            print("[OCR] Run: pip install 'fast-plate-ocr[onnx]'")
            self.reader = None
        except Exception as exc:
            print(f"[OCR] WARNING: Failed to load FastPlateOCR: {exc}")
            self.reader = None

    @property
    def is_loaded(self) -> bool:
        return self.reader is not None

    def _convert_color_mode(self, crop: np.ndarray) -> np.ndarray:
        """Convert OpenCV BGR crop to the color mode expected by the model."""
        if self.reader.config.image_color_mode == "rgb":
            return cv2.cvtColor(crop, cv2.COLOR_BGR2RGB)
        return cv2.cvtColor(crop, cv2.COLOR_BGR2GRAY)

    def _make_variants(self, crop: np.ndarray) -> list[tuple[str, np.ndarray]]:
        """Create light retry variants without making Raspberry Pi inference heavy."""
        base = self._convert_color_mode(crop)
        variants = [("original", base)]

        if base.ndim == 2:
            gray = base
        else:
            gray = cv2.cvtColor(base, cv2.COLOR_RGB2GRAY)

        clahe = cv2.createCLAHE(clipLimit=2.5, tileGridSize=(8, 8)).apply(gray)
        sharpened = cv2.filter2D(
            base,
            -1,
            np.array([[0, -1, 0], [-1, 5, -1], [0, -1, 0]]),
        )

        if self.reader.config.image_color_mode == "rgb":
            clahe = cv2.cvtColor(clahe, cv2.COLOR_GRAY2RGB)

        variants.append(("grayscale_clahe", clahe))
        variants.append(("sharpened", sharpened))
        return variants

    def _run_ocr_on_image(self, image: np.ndarray) -> dict:
        """Run FastPlateOCR on a single crop variant."""
        try:
            prediction = self.reader.run_one(image, return_confidence=True)
            char_probs = prediction.char_probs
            confidence = float(np.mean(char_probs)) if char_probs is not None and len(char_probs) else 0.0
            return {
                "text": prediction.plate.strip().upper(),
                "confidence": round(confidence, 4),
            }
        except Exception as exc:
            return {"text": "", "confidence": 0.0, "error": str(exc)}

    def read_text(self, crop: np.ndarray, preprocess: bool = True) -> dict:
        """
        Read a plate crop, then normalize it into Indonesian plate components.

        The original crop is evaluated first. Additional variants are only used
        when confidence is low or the predicted text cannot be parsed safely.
        """
        if not self.is_loaded:
            return {"text": "", "confidence": 0.0, "error": "OCR engine not loaded"}
        if crop.size == 0:
            return {"text": "", "confidence": 0.0, "error": "Empty image"}

        start = time.perf_counter()
        variants = self._make_variants(crop) if preprocess else [("raw", self._convert_color_mode(crop))]
        all_attempts = []
        best = {
            "raw_text": "",
            "confidence": 0.0,
            "best_variant": "none",
            "plate": parse_indonesian_plate(""),
        }

        for index, (variant_name, image) in enumerate(variants):
            result = self._run_ocr_on_image(image)
            raw_text = result.get("text", "")
            confidence = float(result.get("confidence", 0.0))
            plate = parse_indonesian_plate(raw_text)
            attempt = {
                "variant": variant_name,
                "text": raw_text,
                "confidence": round(confidence, 4),
                "normalized_plate": plate["normalized_plate"],
                "is_valid": plate["is_valid"],
            }
            if result.get("error"):
                attempt["error"] = result["error"]
            all_attempts.append(attempt)

            best_is_valid = best["plate"]["is_valid"]
            should_replace = (
                (plate["is_valid"] and not best_is_valid)
                or (plate["is_valid"] == best_is_valid and confidence > best["confidence"])
            )
            if should_replace:
                best = {
                    "raw_text": raw_text,
                    "confidence": confidence,
                    "best_variant": variant_name,
                    "plate": plate,
                }

            # Keep Raspberry Pi latency low for a confident, parseable result.
            if index == 0 and plate["is_valid"] and confidence >= OCR_RETRY_CONFIDENCE_THRESHOLD:
                break

        elapsed_ms = (time.perf_counter() - start) * 1000
        return {
            "text": best["plate"]["normalized_plate"],
            "raw_text": best["raw_text"],
            "confidence": round(float(best["confidence"]), 4),
            "processing_time_ms": round(elapsed_ms, 2),
            "best_variant": best["best_variant"],
            "all_attempts": all_attempts,
            "plate": best["plate"],
            "ocr_model": self.model_name,
        }

    def read_from_image_path(self, image_path: str) -> dict:
        """Read text directly from an already-cropped plate image path."""
        crop = cv2.imread(image_path)
        if crop is None:
            return {"text": "", "confidence": 0.0, "error": f"Cannot read image: {image_path}"}
        return self.read_text(crop)


__all__ = ["OCREngine", "clean_plate_text", "parse_indonesian_plate"]
