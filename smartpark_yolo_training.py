"""
SmartPark - License Plate Detection using YOLOv8
=================================================
Complete training pipeline for Kaggle environment.
Dataset: Indonesian License Plate Dataset (800/100/100 split)

Usage on Kaggle:
  1. Upload this script as a Kaggle notebook
  2. Upload dataset as a Kaggle dataset
  3. Enable GPU accelerator (Settings → Accelerator → GPU T4 x2)
  4. Run all cells
"""

# ============================================================
# SECTION 1: ENVIRONMENT SETUP
# ============================================================

# --- Run this cell first in Kaggle ---
# !pip install ultralytics -q
# !pip install easyocr -q  # For Section 8 (OCR extension)

import os
import sys
import yaml
import glob
import shutil
import random
import numpy as np
from pathlib import Path

# Ultralytics
from ultralytics import YOLO

# Visualization
import matplotlib.pyplot as plt
import matplotlib.patches as patches
from PIL import Image

print(f"Python: {sys.version}")
print("Setup complete.")


# ============================================================
# SECTION 2: DATASET CONFIGURATION
# ============================================================

# --- Path Configuration ---
# For LOCAL development:
DATASET_ROOT = Path("/Users/njul/Project/SmartPark/Indonesian License Plate Dataset")

# For KAGGLE: uncomment the line below and comment the one above
# DATASET_ROOT = Path("/kaggle/input/indonesian-license-plate-dataset")

# Output directory for training results
# LOCAL:
OUTPUT_DIR = Path("/Users/njul/Project/SmartPark/runs")
# KAGGLE: OUTPUT_DIR = Path("/kaggle/working/runs")

OUTPUT_DIR.mkdir(parents=True, exist_ok=True)


def validate_dataset(root: Path) -> dict:
    """Validate dataset structure and return statistics."""
    stats = {}
    for split in ["train", "val", "test"]:
        img_dir = root / "images" / split
        lbl_dir = root / "labels" / split

        images = sorted(glob.glob(str(img_dir / "*.jpg")))
        labels = sorted(glob.glob(str(lbl_dir / "*.txt")))

        # Check image-label pairing
        img_stems = {Path(f).stem for f in images}
        lbl_stems = {Path(f).stem for f in labels}
        unpaired_imgs = img_stems - lbl_stems
        unpaired_lbls = lbl_stems - img_stems

        # Count annotations
        total_annotations = 0
        classes_found = set()
        for lf in labels:
            with open(lf) as f:
                for line in f:
                    parts = line.strip().split()
                    if len(parts) == 5:
                        total_annotations += 1
                        classes_found.add(int(parts[0]))

        stats[split] = {
            "images": len(images),
            "labels": len(labels),
            "annotations": total_annotations,
            "classes": sorted(classes_found),
            "unpaired_images": len(unpaired_imgs),
            "unpaired_labels": len(unpaired_lbls),
        }

        status = "✓" if len(unpaired_imgs) == 0 and len(unpaired_lbls) == 0 else "⚠"
        print(f"  {status} {split:5s}: {len(images):4d} images, {len(labels):4d} labels, "
              f"{total_annotations:5d} annotations, classes={sorted(classes_found)}")

    return stats


print("Validating dataset...")
dataset_stats = validate_dataset(DATASET_ROOT)


def create_data_yaml(dataset_root: Path, output_path: Path) -> Path:
    """Create data.yaml for YOLO training."""
    data_config = {
        "path": str(dataset_root),
        "train": "images/train",
        "val": "images/val",
        "test": "images/test",
        "nc": 1,
        "names": ["license_plate"],
    }

    yaml_path = output_path / "data.yaml"
    with open(yaml_path, "w") as f:
        yaml.dump(data_config, f, default_flow_style=False)

    print(f"\ndata.yaml written to: {yaml_path}")
    print(f"  path:  {data_config['path']}")
    print(f"  nc:    {data_config['nc']}")
    print(f"  names: {data_config['names']}")
    return yaml_path


DATA_YAML = create_data_yaml(DATASET_ROOT, OUTPUT_DIR)


# ============================================================
# SECTION 3: MODEL INITIALIZATION
# ============================================================
"""
Model choice: YOLOv8n (nano)
- 3.2M parameters — lightweight enough for edge deployment
- ~6.5 GFLOPs — fast inference on Raspberry Pi / Jetson
- Pretrained on COCO (80 classes, 330K images)
- Transfer learning: backbone features (edges, textures, shapes)
  transfer well to license plate detection
  
For higher accuracy at the cost of speed, use:
  yolov8s.pt (11.2M params) or yolov8m.pt (25.9M params)
"""

model = YOLO("yolov8n.pt")  # Downloads pretrained weights automatically
print(f"\nModel loaded: YOLOv8n")
print(f"  Parameters: {sum(p.numel() for p in model.model.parameters()):,}")


# ============================================================
# SECTION 4: TRAINING PIPELINE
# ============================================================

# --- Training Hyperparameters ---
TRAIN_CONFIG = {
    "data": str(DATA_YAML),
    "epochs": 80,           # 80 epochs for 800 images is a good starting point
    "batch": 16,            # Fits in Kaggle GPU memory (T4: 16GB)
    "imgsz": 640,           # Standard YOLO input size
    "patience": 15,         # Early stopping: stop if no improvement for 15 epochs
    "optimizer": "AdamW",   # AdamW with weight decay
    "lr0": 0.001,           # Initial learning rate
    "lrf": 0.01,            # Final LR = lr0 * lrf (cosine decay)
    "weight_decay": 0.0005,

    # Augmentation (built-in YOLO augmentations)
    "hsv_h": 0.015,         # Hue augmentation
    "hsv_s": 0.7,           # Saturation augmentation
    "hsv_v": 0.4,           # Value/brightness augmentation
    "degrees": 5.0,         # Rotation ±5°
    "translate": 0.1,       # Translation ±10%
    "scale": 0.3,           # Scale ±30%
    "flipud": 0.0,          # No vertical flip (plates are never upside down)
    "fliplr": 0.5,          # Horizontal flip 50%
    "mosaic": 1.0,          # Mosaic augmentation (4 images combined)
    "mixup": 0.1,           # Mixup augmentation 10%

    # Output
    "project": str(OUTPUT_DIR),
    "name": "smartpark_plate_detection",
    "exist_ok": True,
    "verbose": True,
    "seed": 42,
}


def train_model(model: YOLO, config: dict):
    """Train the YOLO model with the given configuration."""
    print("\n" + "=" * 60)
    print("STARTING TRAINING")
    print("=" * 60)
    print(f"  Epochs:    {config['epochs']}")
    print(f"  Batch:     {config['batch']}")
    print(f"  Image:     {config['imgsz']}x{config['imgsz']}")
    print(f"  Optimizer: {config['optimizer']}")
    print(f"  LR:        {config['lr0']} → {config['lr0'] * config['lrf']}")
    print(f"  Patience:  {config['patience']} (early stopping)")
    print("=" * 60)

    results = model.train(**config)
    return results


# >>> UNCOMMENT THE LINE BELOW TO START TRAINING <<<
# train_results = train_model(model, TRAIN_CONFIG)


# ============================================================
# SECTION 5: VALIDATION & EVALUATION
# ============================================================

def evaluate_model(model_path: str, data_yaml: str):
    """Run validation and extract metrics."""
    model = YOLO(model_path)
    results = model.val(data=data_yaml, imgsz=640, batch=16, verbose=True)

    # Extract metrics
    metrics = {
        "mAP50": results.box.map50,          # mAP @ IoU 0.5
        "mAP50_95": results.box.map,          # mAP @ IoU 0.5:0.95
        "precision": results.box.mp,          # Mean precision
        "recall": results.box.mr,             # Mean recall
    }

    print("\n" + "=" * 50)
    print("EVALUATION RESULTS")
    print("=" * 50)
    print(f"  mAP@0.5:      {metrics['mAP50']:.4f}")
    print(f"  mAP@0.5:0.95: {metrics['mAP50_95']:.4f}")
    print(f"  Precision:     {metrics['precision']:.4f}")
    print(f"  Recall:        {metrics['recall']:.4f}")
    print("=" * 50)

    return metrics


# After training completes, run:
BEST_MODEL = OUTPUT_DIR / "smartpark_plate_detection" / "weights" / "best.pt"

# >>> UNCOMMENT AFTER TRAINING <<<
# metrics = evaluate_model(str(BEST_MODEL), str(DATA_YAML))


# ============================================================
# SECTION 6: INFERENCE PIPELINE
# ============================================================

def run_inference(model_path: str, image_dir: Path, num_samples: int = 8, conf: float = 0.25):
    """Run inference on test images and visualize results."""
    model = YOLO(model_path)

    # Get test images
    test_images = sorted(glob.glob(str(image_dir / "*.jpg")))
    if not test_images:
        print("No test images found!")
        return

    # Random sample
    samples = random.sample(test_images, min(num_samples, len(test_images)))

    # Run predictions
    results = model.predict(source=samples, conf=conf, imgsz=640, verbose=False)

    # Visualize
    cols = 4
    rows = (len(samples) + cols - 1) // cols
    fig, axes = plt.subplots(rows, cols, figsize=(20, 5 * rows))
    axes = axes.flatten() if rows > 1 else [axes] if rows == 1 and cols == 1 else axes.flatten()

    for idx, (img_path, result) in enumerate(zip(samples, results)):
        ax = axes[idx]
        img = Image.open(img_path)
        ax.imshow(img)

        # Draw bounding boxes
        if result.boxes is not None:
            for box in result.boxes:
                x1, y1, x2, y2 = box.xyxy[0].cpu().numpy()
                conf_score = box.conf[0].cpu().numpy()

                rect = patches.Rectangle(
                    (x1, y1), x2 - x1, y2 - y1,
                    linewidth=2, edgecolor="lime", facecolor="none"
                )
                ax.add_patch(rect)
                ax.text(
                    x1, y1 - 5,
                    f"plate {conf_score:.2f}",
                    color="lime", fontsize=9, fontweight="bold",
                    bbox=dict(boxstyle="round,pad=0.2", facecolor="black", alpha=0.7),
                )

        ax.set_title(Path(img_path).name, fontsize=10)
        ax.axis("off")

    # Hide unused subplots
    for idx in range(len(samples), len(axes)):
        axes[idx].axis("off")

    plt.suptitle("License Plate Detection - Test Results", fontsize=16, fontweight="bold")
    plt.tight_layout()
    plt.savefig(OUTPUT_DIR / "inference_results.png", dpi=150, bbox_inches="tight")
    plt.show()
    print(f"\nResults saved to: {OUTPUT_DIR / 'inference_results.png'}")


# >>> UNCOMMENT AFTER TRAINING <<<
# run_inference(str(BEST_MODEL), DATASET_ROOT / "images" / "test")


# ============================================================
# SECTION 7: MODEL EXPORT
# ============================================================

def export_model(model_path: str):
    """Export model to various formats for deployment."""
    model = YOLO(model_path)

    # ONNX export (for cross-platform deployment)
    model.export(format="onnx", imgsz=640, simplify=True)
    print("Exported: best.onnx")

    # TFLite export (for Raspberry Pi / mobile)
    # model.export(format="tflite", imgsz=640)
    # print("Exported: best_float32.tflite")

    print(f"\nModel files location: {Path(model_path).parent}")
    print("  best.pt   — PyTorch weights (primary)")
    print("  best.onnx — ONNX format (cross-platform)")


# >>> UNCOMMENT AFTER TRAINING <<<
# export_model(str(BEST_MODEL))

# --- How to download from Kaggle ---
# Option 1: In Kaggle notebook, the output files are in /kaggle/working/
#   Go to: Output tab → Download "runs/" folder
#
# Option 2: Use Kaggle API:
#   from kaggle.api import KaggleApi
#   api = KaggleApi()
#   api.authenticate()
#   # Files in /kaggle/working/ are automatically saved as output


# ============================================================
# SECTION 8: FUTURE EXTENSIONS
# ============================================================

# --- 8A: OCR Integration ---
def extract_plate_text(model_path: str, image_path: str):
    """
    Detect plate → crop → OCR.
    Requires: pip install easyocr
    """
    import easyocr
    import cv2

    # Step 1: Detect plate
    model = YOLO(model_path)
    results = model.predict(source=image_path, conf=0.25, verbose=False)

    img = cv2.imread(image_path)
    reader = easyocr.Reader(["en"], gpu=True)

    plates = []
    if results[0].boxes is not None:
        for box in results[0].boxes:
            x1, y1, x2, y2 = map(int, box.xyxy[0].cpu().numpy())
            crop = img[y1:y2, x1:x2]

            # Step 2: OCR on cropped plate
            ocr_results = reader.readtext(crop)
            text = " ".join([r[1] for r in ocr_results])
            conf = float(box.conf[0].cpu().numpy())

            plates.append({
                "bbox": [x1, y1, x2, y2],
                "detection_conf": conf,
                "plate_text": text.strip(),
                "ocr_conf": np.mean([r[2] for r in ocr_results]) if ocr_results else 0.0,
            })

    return plates


# --- 8B: Vehicle Color Detection ---
def detect_vehicle_color(image_path: str, plate_bbox: list) -> str:
    """
    Coarse color classification from the area above the plate.
    Uses HSV histogram analysis — no additional model needed.
    """
    import cv2

    img = cv2.imread(image_path)
    h, w = img.shape[:2]
    x1, y1, x2, y2 = plate_bbox

    # Sample vehicle body: region above the plate
    body_y1 = max(0, y1 - (y2 - y1) * 5)
    body_y2 = y1
    body_x1 = max(0, x1 - 20)
    body_x2 = min(w, x2 + 20)
    body_crop = img[int(body_y1):int(body_y2), int(body_x1):int(body_x2)]

    if body_crop.size == 0:
        return "unknown"

    hsv = cv2.cvtColor(body_crop, cv2.COLOR_BGR2HSV)
    avg_h = np.mean(hsv[:, :, 0])
    avg_s = np.mean(hsv[:, :, 1])
    avg_v = np.mean(hsv[:, :, 2])

    # Coarse color mapping based on HSV ranges
    if avg_s < 40 and avg_v > 180:
        return "white"
    elif avg_s < 40 and avg_v < 80:
        return "black"
    elif avg_s < 50:
        return "silver/gray"
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


# --- 8C: Vehicle Type Classification ---
def classify_vehicle_type(image_path: str) -> dict:
    """
    Vehicle type classification using a pretrained YOLO model.
    Uses COCO-pretrained model which includes car, truck, bus, motorcycle.
    """
    coco_model = YOLO("yolov8n.pt")  # COCO-pretrained
    results = coco_model.predict(source=image_path, conf=0.3, verbose=False)

    # COCO vehicle class IDs: car=2, motorcycle=3, bus=5, truck=7
    vehicle_classes = {2: "car", 3: "motorcycle", 5: "bus", 7: "truck"}

    vehicles = []
    if results[0].boxes is not None:
        for box in results[0].boxes:
            cls_id = int(box.cls[0].cpu().numpy())
            if cls_id in vehicle_classes:
                vehicles.append({
                    "type": vehicle_classes[cls_id],
                    "confidence": float(box.conf[0].cpu().numpy()),
                })

    return vehicles[0] if vehicles else {"type": "unknown", "confidence": 0.0}


# --- 8D: Multi-Signal Verification (Confidence Scoring) ---
def compute_access_score(plate_conf: float, color_match: bool, type_match: bool) -> dict:
    """
    Weighted confidence scoring for gate access decision.
    S = (plate × 0.70) + (color × 0.15) + (type × 0.15)
    """
    w_plate, w_color, w_type = 0.70, 0.15, 0.15

    score = (
        plate_conf * w_plate
        + (1.0 if color_match else 0.0) * w_color
        + (1.0 if type_match else 0.0) * w_type
    )

    if score >= 0.85:
        decision = "GRANTED"
        action = "Gate opens automatically"
    elif score >= 0.60:
        decision = "GRANTED_WITH_LOG"
        action = "Gate opens, logged for review"
    else:
        decision = "DENIED"
        action = "Fallback to manual verification"

    return {
        "score": round(score, 4),
        "decision": decision,
        "action": action,
        "breakdown": {
            "plate": round(plate_conf * w_plate, 4),
            "color": round((1.0 if color_match else 0.0) * w_color, 4),
            "type": round((1.0 if type_match else 0.0) * w_type, 4),
        },
    }


# ============================================================
# FULL PIPELINE EXAMPLE (run after training)
# ============================================================
def full_pipeline_demo(model_path: str, test_image: str):
    """
    End-to-end demo: detect plate → OCR → color → type → decision.
    """
    print("=" * 60)
    print("SMARTPARK - Full Pipeline Demo")
    print("=" * 60)

    # 1. Plate detection + OCR
    plates = extract_plate_text(model_path, test_image)
    if not plates:
        print("No plate detected. → DENIED (manual check)")
        return

    plate = plates[0]
    print(f"  Plate text:     {plate['plate_text']}")
    print(f"  Detection conf: {plate['detection_conf']:.3f}")
    print(f"  OCR conf:       {plate['ocr_conf']:.3f}")

    # 2. Vehicle color
    color = detect_vehicle_color(test_image, plate["bbox"])
    print(f"  Vehicle color:  {color}")

    # 3. Vehicle type
    vtype = classify_vehicle_type(test_image)
    print(f"  Vehicle type:   {vtype['type']} ({vtype['confidence']:.2f})")

    # 4. Scoring (simulated DB match)
    # In production: compare plate_text, color, type against registered DB
    registered_color = color  # Simulated match
    registered_type = vtype["type"]  # Simulated match

    result = compute_access_score(
        plate_conf=plate["detection_conf"],
        color_match=(color == registered_color),
        type_match=(vtype["type"] == registered_type),
    )

    print(f"\n  Score:    {result['score']}")
    print(f"  Decision: {result['decision']}")
    print(f"  Action:   {result['action']}")
    print(f"  Breakdown: {result['breakdown']}")
    print("=" * 60)


# >>> UNCOMMENT TO RUN FULL PIPELINE DEMO <<<
# full_pipeline_demo(
#     str(BEST_MODEL),
#     str(DATASET_ROOT / "images" / "test" / "test001.jpg")
# )


# ============================================================
# QUICK START SUMMARY
# ============================================================
print("""
╔══════════════════════════════════════════════════════════╗
║  SmartPark - Quick Start                                ║
╠══════════════════════════════════════════════════════════╣
║                                                          ║
║  1. Upload this script to Kaggle notebook                ║
║  2. Enable GPU (Settings → Accelerator → GPU T4)        ║
║  3. Upload dataset as Kaggle dataset                     ║
║  4. Update DATASET_ROOT to Kaggle path                   ║
║  5. Uncomment train_model() call → run training          ║
║  6. Uncomment evaluate_model() → check metrics           ║
║  7. Uncomment run_inference() → visualize results        ║
║  8. Download best.pt from Output tab                     ║
║                                                          ║
║  Expected training time: ~15-25 min (80 epochs, T4 GPU) ║
╚══════════════════════════════════════════════════════════╝
""")
 