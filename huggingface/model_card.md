---
language:
- id
license: mit
library_name: ultralytics
pipeline_tag: object-detection
tags:
- yolov8
- anpr
- license-plate-detection
- indonesia
- computer-vision
- smartpark
model-index:
- name: SmartPark ANPR YOLOv8
  results:
  - task:
      type: object-detection
    dataset:
      name: Indonesian License Plate
      type: custom
    metrics:
    - name: mAP@0.5
      type: map_50
      value: 0.9829
    - name: mAP@0.5:0.95
      type: map
      value: 0.7097
    - name: Precision
      type: precision
      value: 0.9652
    - name: Recall
      type: recall
      value: 0.9340
---

# SmartPark ANPR — YOLOv8 License Plate Detection

Model deteksi plat nomor kendaraan Indonesia menggunakan YOLOv8n dengan transfer learning.

## Model Description

- **Architecture**: YOLOv8n (nano) — 3.2M parameters
- **Base Model**: YOLOv8n pretrained on COCO (330K images, 80 classes)
- **Fine-tuned on**: Indonesian License Plate Dataset (800 training images)
- **Task**: Single-class object detection (license plate)
- **Input**: RGB image (640×640)
- **Output**: Bounding box + confidence score

## Training Details

| Parameter      | Value                          |
|----------------|:------------------------------:|
| Epochs         | 80                             |
| Batch Size     | 16                             |
| Image Size     | 640×640                        |
| Optimizer      | AdamW                          |
| Learning Rate  | 0.001 → 0.00001 (cosine decay)|
| Early Stopping | patience=15                    |
| Augmentation   | Mosaic, MixUp, HSV, Flip      |

## Evaluation

Evaluated on the local test split (`runs/data.yaml`, 100 images / 197 plate instances):

| Metric | Value |
|---|---:|
| mAP@0.5 | 0.9829 |
| mAP@0.5:0.95 | 0.7097 |
| Precision | 0.9652 |
| Recall | 0.9340 |

Additional end-to-end verification on 5 external Google-sourced test photos:

| Stage | Result |
|---|---:|
| Plate detected | 5/5 |
| OCR produced text | 5/5 |
| Exact OCR match with FastPlateOCR XS | 5/5 |
| Average OCR similarity | 1.000 |

This means the plate detector and lightweight FastPlateOCR baseline are suitable for prototype demos. A larger ESP32-CAM capture set is still required before production use because OCR quality depends heavily on crop quality, lighting, and plate angle.

## Usage

### Quick Start (Python)

```python
from ultralytics import YOLO

# Load model
model = YOLO("best.pt")

# Run inference
results = model.predict("car_image.jpg", conf=0.25)

# Get detections
for box in results[0].boxes:
    x1, y1, x2, y2 = box.xyxy[0].tolist()
    confidence = box.conf[0].item()
    print(f"Plate at ({x1:.0f}, {y1:.0f}, {x2:.0f}, {y2:.0f}) conf={confidence:.2f}")
```

### With Hugging Face Hub

```python
from huggingface_hub import hf_hub_download
from ultralytics import YOLO

# Download model
model_path = hf_hub_download(
    repo_id="yuln0x/smartpark-anpr-yolov8",
    filename="best.pt"
)

# Load and run
model = YOLO(model_path)
results = model.predict("test_image.jpg")
```

### Docker (Recommended)

```bash
# Pull and run SmartPark API
docker run -d -p 8000:8000 yuln0x/smartpark-api:latest

# Test detection via API
curl -X POST http://localhost:8000/anpr/detect \
  -F "file=@car_photo.jpg"
```

## Available Formats

| Format   | File         | Size     | Use Case                    |
|----------|:------------:|:--------:|:---------------------------:|
| PyTorch  | `best.pt`    | ~6.2 MB  | Training, fine-tuning       |
| ONNX     | `best.onnx`  | ~12.4 MB | Cross-platform deployment   |

## System Architecture

Model ini merupakan bagian dari sistem **SmartPark** — Smart Parking System berbasis Computer Vision:

```
Camera → ANPR (this model) → OCR → Database Lookup → Gate Control
```

### Full Pipeline

1. **ANPR Detection** (model ini) — Deteksi lokasi plat nomor
2. **OCR** (FastPlateOCR + ONNX Runtime) — Ekstraksi dan normalisasi teks plat
3. **Color Detection** — Klasifikasi warna kendaraan
4. **Vehicle Type** — Klasifikasi tipe kendaraan
5. **Scoring** — Confidence scoring berbobot untuk keputusan akses

## Deployment

### Raspberry Pi

Model dioptimasi untuk edge deployment:
- YOLOv8n dipilih karena ringan (3.2M params)
- ONNX format tersedia untuk inferensi lebih cepat
- Target latency: <500ms per frame pada Raspberry Pi 4

### Docker Hub

Image Docker tersedia di Docker Hub:
```bash
docker pull yuln0x/smartpark-api:latest
```

## Limitations

- Dataset terbatas (800 training images)
- Performa menurun pada pencahayaan buruk
- OCR accuracy tergantung resolusi plat pada gambar
- Belum dioptimasi untuk plat nomor non-standar

## License

MIT License
