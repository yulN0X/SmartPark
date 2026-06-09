# 🚗 SmartPark

**Sistem Parkir Cerdas Berbasis Computer Vision**

SmartPark adalah sistem parkir otomatis yang menggunakan ANPR (Automatic Number Plate Recognition) untuk mendeteksi dan mengenali plat nomor kendaraan Indonesia secara real-time.

---

## ✨ Fitur

- 🔍 **ANPR Detection** — Deteksi plat nomor menggunakan YOLOv8
- 📝 **OCR** — Pengenalan karakter plat nomor khusus kendaraan (FastPlateOCR)
- 🎨 **Color Detection** — Klasifikasi warna kendaraan
- 🚙 **Vehicle Classification** — Identifikasi tipe kendaraan
- 📊 **Confidence Scoring** — Sistem skor berbobot untuk keputusan akses
- 🐳 **Docker Ready** — Satu perintah untuk menjalankan
- 🍓 **Raspberry Pi Compatible** — Dioptimasi untuk edge deployment

---

## 🏗 Arsitektur Sistem

```
┌────────────┐     ┌──────────────────────────────────┐     ┌──────────┐
│   Kamera   │────→│         SmartPark API             │────→│   Gate   │
│            │     │  ┌──────┐  ┌─────┐  ┌──────────┐ │     │ Barrier  │
└────────────┘     │  │ ANPR │→ │ OCR │→ │ Scoring  │ │     └──────────┘
                   │  │(YOLO)│  │     │  │ Decision │ │
                   │  └──────┘  └─────┘  └──────────┘ │
                   └──────────────────────────────────┘
                                  ↕
                   ┌──────────────────────────────────┐
                   │          iOS App                   │
                   │  GPS · E-Wallet · Parking Status  │
                   └──────────────────────────────────┘
```

---

## 🚀 Quick Start

### Docker (Recommended)

```bash
# Pull image
docker pull yuln0x/smartpark-api:latest

# Run
docker run -d -p 8000:8000 --name smartpark yuln0x/smartpark-api:latest

# Open API docs
open http://localhost:8000/docs
```

### Local Development

```bash
# Clone
git clone https://github.com/yuln0x/SmartPark.git
cd SmartPark

# Install dependencies
pip install -r requirements.txt

# Run API
uvicorn api.main:app --reload --port 8000
```

---

## 📡 API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/` | API info |
| `GET` | `/health` | Health check |
| `POST` | `/anpr/detect` | Detect license plates |
| `POST` | `/ocr/read` | Detect + OCR (full image) |
| `POST` | `/ocr/read-cropped` | OCR on cropped plate |
| `POST` | `/color/detect` | Vehicle color detection |
| `POST` | `/pipeline/verify` | Full pipeline: ANPR + OCR + Color + Score |
| `GET` | `/device/status` | Prototype device integration status |
| `POST` | `/device/trigger` | ESP32 sensor trigger + local camera capture |
| `POST` | `/device/process-image` | Process image from ESP32-CAM/phone/manual upload |

### Example

```bash
# Detect license plate
curl -X POST http://localhost:8000/anpr/detect \
  -F "file=@car_photo.jpg"

# Full pipeline
curl -X POST http://localhost:8000/pipeline/verify \
  -F "file=@car_photo.jpg"
```

---

## 📦 Project Structure

```
SmartPark/
├── api/                          # FastAPI Backend
│   ├── main.py                   # App entry point
│   ├── config.py                 # Configuration
│   ├── schemas.py                # Pydantic schemas
│   ├── engine/                   # ML engines
│   │   ├── anpr.py               #   YOLO plate detection
│   │   ├── ocr.py                #   FastPlateOCR text extraction
│   │   ├── plate.py              #   Indonesian plate normalization
│   │   └── vehicle.py            #   Vehicle classification
│   └── routers/                  # API routes
│       ├── anpr.py               #   /anpr/*
│       ├── ocr.py                #   /ocr/*
│       ├── color.py              #   /color/*
│       └── pipeline.py           #   /pipeline/*
├── models/                       # Trained weights
│   ├── best.pt                   #   YOLOv8 (PyTorch)
│   └── best.onnx                 #   YOLOv8 (ONNX)
├── docs/                         # Documentation
│   ├── RASPBERRY_PI_SETUP.md     #   RPi deployment guide
│   ├── DEVICE_INTEGRATION.md     #   ESP32 + laptop camera prototype
│   ├── PANDUAN_IOT.md            #   ESP32-CAM wiring + assembly guide
│   ├── PLATE_DATA_MODEL.md       #   Struktur database plat nomor
│   └── DOCKER_HUB_GUIDE.md       #   Docker usage guide
├── firmware/                     # ESP32 prototype sketches
│   ├── esp32_entry_gate/         #   ESP32-CAM gate masuk
│   ├── esp32_exit_gate/          #   ESP32-CAM gate keluar
│   └── esp32_sensor_trigger/     #   Legacy ESP32 DevKit trigger
├── huggingface/                  # HF Hub cards
│   ├── dataset_card.md           #   Dataset README
│   └── model_card.md             #   Model README
├── scripts/                      # Utility scripts
│   ├── docker-build-push.sh      #   Multi-arch Docker build
│   └── upload_to_huggingface.py  #   Upload to HF Hub
├── Dockerfile                    # Docker image definition
├── docker-compose.yml            # Docker Compose config
├── requirements.txt              # Python dependencies
├── requirements-runtime.txt      # Lightweight Docker/Raspberry Pi runtime
└── smartpark_yolo_training.py    # Training pipeline (Kaggle)
```

---

## 🧠 Model

| Property | Value |
|----------|-------|
| **Architecture** | YOLOv8n (nano) |
| **Parameters** | 3.2M |
| **Training Data** | 800 images (Indonesian license plates) |
| **Input Size** | 640×640 |
| **Export Formats** | PyTorch (.pt), ONNX (.onnx) |

### Public Resources

| Resource | Platform | Link |
|----------|----------|------|
| **Dataset** | 🤗 Hugging Face | [smartpark-indonesian-license-plate](https://huggingface.co/datasets/yuln0x/smartpark-indonesian-license-plate) |
| **Model** | 🤗 Hugging Face | [smartpark-anpr-yolov8](https://huggingface.co/yuln0x/smartpark-anpr-yolov8) |
| **Docker Image** | 🐳 Docker Hub | [smartpark-api](https://hub.docker.com/r/yuln0x/smartpark-api) |

---

## 🍓 Raspberry Pi Deployment

SmartPark dirancang untuk berjalan di Raspberry Pi sebagai edge device:

```bash
# Di Raspberry Pi (64-bit OS):

# 1. Install Docker
curl -fsSL https://get.docker.com | sh

# 2. Pull & Run
docker run -d -p 8000:8000 --restart unless-stopped \
  yuln0x/smartpark-api:latest

# 3. Done! API ready at http://<rpi-ip>:8000
```

📖 Panduan lengkap: [docs/RASPBERRY_PI_SETUP.md](docs/RASPBERRY_PI_SETUP.md)

---

## 🛠 Tech Stack

| Component | Technology |
|-----------|-----------|
| **ML Model** | YOLOv8 (Ultralytics) |
| **OCR** | FastPlateOCR + ONNX Runtime |
| **Backend** | FastAPI + Uvicorn |
| **Container** | Docker (multi-arch) |
| **Mobile App** | SwiftUI (iOS) |
| **Edge Device** | Raspberry Pi 4/5 |

---

## 📄 Documentation

- [Bagian Pemodelan](Bagian_Pemodelan.md) — Detail arsitektur model dan strategi pelatihan
- [Integrasi Sistem](INTEGRASI_SISTEM.md) — Roadmap integrasi lengkap (database, gate logic, GPS)
- [Device Integration](docs/DEVICE_INTEGRATION.md) — ESP32 trigger + kamera laptop untuk prototype
- [Panduan IoT](docs/PANDUAN_IOT.md) — Wiring ESP32-CAM, adaptor, sensor, dan servo
- [Plate Data Model](docs/PLATE_DATA_MODEL.md) — Normalisasi OCR dan struktur tabel plat nomor
- [Raspberry Pi Setup](docs/RASPBERRY_PI_SETUP.md) — Panduan deployment di RPi
- [Docker Hub Guide](docs/DOCKER_HUB_GUIDE.md) — Cara menjalankan via Docker

---

## 📝 License

MIT License
