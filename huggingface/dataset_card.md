---
language:
- id
license: mit
task_categories:
- object-detection
tags:
- yolo
- license-plate
- anpr
- indonesia
- computer-vision
pretty_name: Indonesian License Plate Dataset
size_categories:
- n<1K
---

# Indonesian License Plate Dataset

Dataset plat nomor kendaraan Indonesia untuk deteksi objek (ANPR — Automatic Number Plate Recognition).

## Dataset Description

Dataset ini berisi citra kendaraan Indonesia dengan anotasi bounding box pada plat nomor, menggunakan format YOLO.

### Dataset Summary

| Split      | Jumlah Citra | Proporsi |
|------------|:------------:|:--------:|
| Training   | 800          | 80%      |
| Validation | 100          | 10%      |
| Test       | 100          | 10%      |

**Total**: 1.000 citra beranotasi

### Annotation Format

Format YOLO (normalized):
```
<class_id> <x_center> <y_center> <width> <height>
```

- `class_id`: 0 (license_plate)
- Koordinat dinormalisasi ke rentang [0, 1]

### Directory Structure

```
├── images/
│   ├── train/    (800 .jpg files)
│   ├── val/      (100 .jpg files)
│   └── test/     (100 .jpg files)
├── labels/
│   ├── train/    (800 .txt files)
│   ├── val/      (100 .txt files)
│   └── test/     (100 .txt files)
```

## Usage

### With Ultralytics YOLOv8

```python
from ultralytics import YOLO

# Train
model = YOLO("yolov8n.pt")
model.train(data="data.yaml", epochs=80, imgsz=640)

# Evaluate
metrics = model.val()
print(f"mAP@0.5: {metrics.box.map50:.4f}")
```

### data.yaml

```yaml
path: .
train: images/train
val: images/val
test: images/test
nc: 1
names:
  - license_plate
```

## Use Case

Dataset ini digunakan dalam project **SmartPark** — sistem parkir cerdas berbasis computer vision yang mendeteksi plat nomor kendaraan secara otomatis di gerbang parkir.

### Pipeline

```
Citra Input → Deteksi Plat (YOLO) → OCR → Verifikasi Database → Keputusan Akses
```

## Citation

Jika menggunakan dataset ini, silakan cantumkan referensi ke repository ini.

## License

MIT License
