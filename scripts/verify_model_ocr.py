"""
Verify SmartPark ANPR + OCR on a folder of images.

This script is meant for project reports and demo preparation:
- validates YOLO plate detection on arbitrary test photos,
- runs FastPlateOCR on the detected plate crop,
- writes JSON, CSV, and Markdown summaries.

Usage:
  python scripts/verify_model_ocr.py --images "foto test" --output runs/verification
"""

import argparse
import csv
import json
from difflib import SequenceMatcher
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from api.engine.anpr import ANPREngine
from api.engine.ocr import OCREngine


IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".bmp", ".webp"}


def iter_images(image_dir: Path) -> list[Path]:
    return sorted(
        path
        for path in image_dir.iterdir()
        if path.is_file() and path.suffix.lower() in IMAGE_EXTENSIONS
    )


def quality_flags(plate_confidence: float, ocr_confidence: float, plate_text: str) -> list[str]:
    flags = []
    if plate_confidence == 0:
        flags.append("NO_PLATE")
    elif plate_confidence < 0.5:
        flags.append("LOW_DETECTION_CONF")

    if not plate_text:
        flags.append("EMPTY_OCR")
    elif ocr_confidence < 0.45:
        flags.append("LOW_OCR_CONF")

    return flags or ["OK"]


def normalize_plate(text: str) -> str:
    return "".join(ch for ch in text.upper() if ch.isalnum())


def plate_similarity(predicted: str, expected: str) -> float | None:
    if not expected:
        return None
    return SequenceMatcher(None, normalize_plate(predicted), normalize_plate(expected)).ratio()


def load_ground_truth(path: Path | None) -> dict[str, str]:
    if path is None:
        return {}
    if not path.exists():
        raise SystemExit(f"Ground truth file not found: {path}")

    truth = {}
    with path.open(newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        if "image" not in reader.fieldnames or "expected_plate" not in reader.fieldnames:
            raise SystemExit("Ground truth CSV must contain image,expected_plate columns")
        for row in reader:
            truth[row["image"]] = row["expected_plate"]
    return truth


def verify_images(
    images_dir: Path,
    confidence: float,
    nearest_only: bool,
    ground_truth: dict[str, str],
) -> list[dict]:
    anpr = ANPREngine()
    ocr = OCREngine()

    rows = []
    for image_path in iter_images(images_dir):
        crops = anpr.detect_and_crop(
            str(image_path),
            conf=confidence,
            nearest_only=nearest_only,
        )

        if not crops:
            expected = ground_truth.get(image_path.name, "")
            rows.append(
                {
                    "image": image_path.name,
                    "expected_plate": expected,
                    "plate_count": 0,
                    "plate_confidence": 0.0,
                    "plate_text": "",
                    "raw_text": "",
                    "ocr_confidence": 0.0,
                    "best_variant": "",
                    "ocr_exact_match": False if expected else None,
                    "ocr_similarity": 0.0 if expected else None,
                    "bbox": None,
                    "flags": ["NO_PLATE", "EMPTY_OCR"],
                }
            )
            continue

        best = crops[0]
        ocr_result = ocr.read_text(best["crop"]) if ocr.is_loaded else {
            "text": "",
            "raw_text": "",
            "confidence": 0.0,
            "best_variant": "ocr_not_loaded",
        }

        plate_text = ocr_result.get("text", "")
        ocr_confidence = float(ocr_result.get("confidence", 0.0))
        plate_confidence = float(best.get("confidence", 0.0))
        expected = ground_truth.get(image_path.name, "")
        exact_match = None
        similarity = None
        if expected:
            exact_match = normalize_plate(plate_text) == normalize_plate(expected)
            similarity = plate_similarity(plate_text, expected)

        rows.append(
            {
                "image": image_path.name,
                "expected_plate": expected,
                "plate_count": len(crops),
                "plate_confidence": round(plate_confidence, 4),
                "plate_text": plate_text,
                "raw_text": ocr_result.get("raw_text", ""),
                "ocr_confidence": round(ocr_confidence, 4),
                "best_variant": ocr_result.get("best_variant", ""),
                "ocr_exact_match": exact_match,
                "ocr_similarity": round(similarity, 4) if similarity is not None else None,
                "bbox": best.get("bbox"),
                "flags": quality_flags(plate_confidence, ocr_confidence, plate_text),
            }
        )

    return rows


def write_outputs(rows: list[dict], output_dir: Path) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)

    json_path = output_dir / "model_ocr_verification.json"
    json_path.write_text(json.dumps(rows, indent=2), encoding="utf-8")

    csv_path = output_dir / "model_ocr_verification.csv"
    with csv_path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(
            f,
            fieldnames=[
                "image",
                "expected_plate",
                "plate_count",
                "plate_confidence",
                "plate_text",
                "raw_text",
                "ocr_confidence",
                "best_variant",
                "ocr_exact_match",
                "ocr_similarity",
                "bbox",
                "flags",
            ],
        )
        writer.writeheader()
        for row in rows:
            out = dict(row)
            out["bbox"] = json.dumps(out["bbox"])
            out["flags"] = ", ".join(out["flags"])
            writer.writerow(out)

    ok_count = sum(1 for row in rows if row["flags"] == ["OK"])
    detected_count = sum(1 for row in rows if row["plate_count"] > 0)
    ocr_text_count = sum(1 for row in rows if row["plate_text"])
    gt_rows = [row for row in rows if row.get("expected_plate")]
    exact_count = sum(1 for row in gt_rows if row.get("ocr_exact_match") is True)
    avg_similarity = None
    if gt_rows:
        avg_similarity = sum(float(row.get("ocr_similarity") or 0.0) for row in gt_rows) / len(gt_rows)

    md_path = output_dir / "MODEL_OCR_VERIFICATION.md"
    lines = [
        "# SmartPark Model + OCR Verification",
        "",
        "## Summary",
        "",
        f"- Images tested: {len(rows)}",
        f"- Plate detected: {detected_count}/{len(rows)}",
        f"- OCR produced text: {ocr_text_count}/{len(rows)}",
        f"- OK by heuristic: {ok_count}/{len(rows)}",
    ]
    if gt_rows:
        lines.extend([
            f"- Exact OCR match: {exact_count}/{len(gt_rows)}",
            f"- Average OCR similarity: {avg_similarity:.3f}",
        ])

    lines.extend([
        "",
        "## Results",
        "",
        "| Image | Expected | Plate Conf | OCR Text | Raw OCR | OCR Conf | Exact | Similarity | Variant | Flags |",
        "|---|---|---:|---|---|---:|---|---:|---|---|",
    ])

    for row in rows:
        flags = ", ".join(row["flags"])
        row_for_table = dict(row)
        row_for_table["flags"] = flags
        row_for_table["expected_plate"] = row_for_table.get("expected_plate") or "-"
        row_for_table["ocr_exact_match"] = (
            "-"
            if row_for_table.get("ocr_exact_match") is None
            else str(row_for_table["ocr_exact_match"])
        )
        row_for_table["ocr_similarity"] = (
            0.0
            if row_for_table.get("ocr_similarity") is None
            else row_for_table["ocr_similarity"]
        )
        lines.append(
            "| {image} | {expected_plate} | {plate_confidence:.4f} | {plate_text} | {raw_text} | "
            "{ocr_confidence:.4f} | {ocr_exact_match} | {ocr_similarity:.4f} | "
            "{best_variant} | {flags} |".format(
                **row_for_table,
            )
        )

    md_path.write_text("\n".join(lines) + "\n", encoding="utf-8")

    print(f"Wrote: {json_path}")
    print(f"Wrote: {csv_path}")
    print(f"Wrote: {md_path}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Verify SmartPark ANPR + OCR")
    parser.add_argument("--images", default="foto test", help="Folder containing test photos")
    parser.add_argument("--output", default="runs/verification", help="Output folder")
    parser.add_argument("--confidence", type=float, default=0.25, help="YOLO confidence threshold")
    parser.add_argument("--all-plates", action="store_true", help="Process all detections instead of nearest/largest only")
    parser.add_argument("--ground-truth", help="Optional CSV with image,expected_plate columns")
    args = parser.parse_args()

    images_dir = Path(args.images)
    output_dir = Path(args.output)

    if not images_dir.exists():
        raise SystemExit(f"Image folder not found: {images_dir}")

    ground_truth = load_ground_truth(Path(args.ground_truth) if args.ground_truth else None)
    rows = verify_images(
        images_dir=images_dir,
        confidence=args.confidence,
        nearest_only=not args.all_plates,
        ground_truth=ground_truth,
    )
    write_outputs(rows, output_dir)

    print("\nQuick summary:")
    for row in rows:
        flags = ", ".join(row["flags"])
        print(
            f"- {row['image']}: det={row['plate_confidence']:.3f}, "
            f"ocr={row['ocr_confidence']:.3f}, text='{row['plate_text']}', "
            f"expected='{row.get('expected_plate', '')}', flags={flags}"
        )


if __name__ == "__main__":
    main()
