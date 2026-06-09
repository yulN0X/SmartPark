# Docker Hub Guide — SmartPark API

Panduan untuk dosen dan tim: cara menjalankan prototype SmartPark menggunakan Docker.

## Quick Start (3 Langkah)

### 1. Install Docker

- **Mac**: [Download Docker Desktop](https://www.docker.com/products/docker-desktop/)
- **Windows**: [Download Docker Desktop](https://www.docker.com/products/docker-desktop/)
- **Linux**:
  ```bash
  curl -fsSL https://get.docker.com -o get-docker.sh && sh get-docker.sh
  ```

### 2. Pull & Run

```bash
# Pull image SmartPark (ganti yuln0x)
docker pull yuln0x/smartpark-api:latest

# Jalankan
docker run -d -p 8000:8000 --name smartpark yuln0x/smartpark-api:latest
```

### 3. Buka API Docs

Buka browser: **http://localhost:8000/docs**

Anda akan melihat Swagger UI dengan semua endpoint yang bisa ditest langsung.

---

## API Endpoints

| Method | Endpoint | Deskripsi |
|---|---|---|
| `GET` | `/` | Info API |
| `GET` | `/health` | Status kesehatan sistem |
| `POST` | `/anpr/detect` | Deteksi plat nomor |
| `POST` | `/ocr/read` | Deteksi + OCR (full image) |
| `POST` | `/ocr/read-cropped` | OCR pada gambar plat yang sudah di-crop |
| `POST` | `/color/detect` | Deteksi warna kendaraan |
| `POST` | `/pipeline/verify` | Full pipeline: ANPR + OCR + Color + Scoring |
| `GET` | `/device/status` | Status integrasi device prototype |
| `POST` | `/device/trigger` | Trigger sensor ESP32 + capture kamera lokal |
| `POST` | `/device/process-image` | Proses foto dari ESP32-CAM/HP/Postman |

---

## Contoh Penggunaan

### Health Check

```bash
curl http://localhost:8000/health
```

Response:
```json
{
  "status": "ok",
  "anpr_model_loaded": true,
  "ocr_engine_loaded": true,
  "version": "1.1.0"
}
```

### Deteksi Plat Nomor

```bash
curl -X POST http://localhost:8000/anpr/detect \
  -F "file=@foto_mobil.jpg"
```

Response:
```json
{
  "detections": [
    {
      "bbox": {"x1": 245.3, "y1": 412.1, "x2": 398.7, "y2": 445.6},
      "confidence": 0.92,
      "class_id": 0,
      "class_name": "license_plate"
    }
  ],
  "count": 1,
  "inference_time_ms": 45.2,
  "model_type": "trained"
}
```

### Full Pipeline (Recommended)

```bash
curl -X POST http://localhost:8000/pipeline/verify \
  -F "file=@foto_mobil.jpg"
```

Response mencakup:
- Deteksi plat nomor (bounding box)
- Teks plat (OCR)
- Warna kendaraan
- Confidence score
- Keputusan akses (GRANTED / DENIED)

### ESP32-CAM / Prototype Device Upload

```bash
curl -X POST http://localhost:8000/device/process-image \
  -F "file=@foto_mobil.jpg" \
  -F "device_id=esp32cam-entry-1" \
  -F "gate_id=GATE-A-IN" \
  -F "gate_type=entry"
```

---

## Test dengan Postman

1. Download [Postman](https://www.postman.com/downloads/)
2. New Request → `POST` → `http://localhost:8000/pipeline/verify`
3. Tab **Body** → **form-data**
4. Key: `file`, Type: **File**, Value: pilih foto mobil
5. Klik **Send**

---

## Menghentikan Container

```bash
# Stop
docker stop smartpark

# Hapus container
docker rm smartpark

# Hapus image (opsional, untuk bersihkan disk)
docker rmi yuln0x/smartpark-api:latest
```

---

## FAQ

### Q: Berapa besar Docker image ini?
**A:** Ukuran final bergantung arsitektur image. Image mencakup model YOLO, FastPlateOCR ONNX, dan semua dependency runtime.

### Q: Apakah butuh GPU?
**A:** Tidak. Model YOLOv8n cukup ringan untuk CPU. GPU opsional untuk performa lebih cepat.

### Q: Bisa jalan di Raspberry Pi?
**A:** Ya! Image sudah di-build untuk arsitektur ARM64 (Raspberry Pi 4/5). Lihat `docs/RASPBERRY_PI_SETUP.md`.

### Q: Bagaimana jika model di-update?
**A:**
```bash
docker stop smartpark && docker rm smartpark
docker pull yuln0x/smartpark-api:latest
docker run -d -p 8000:8000 --name smartpark yuln0x/smartpark-api:latest
```
