# Raspberry Pi Setup Guide — SmartPark API

Panduan lengkap untuk menjalankan SmartPark API di Raspberry Pi menggunakan Docker.

## Persyaratan Hardware

| Komponen | Minimum | Rekomendasi |
|---|---|---|
| **Raspberry Pi** | Pi 4 (4GB RAM) | Pi 5 (8GB RAM) |
| **Storage** | 16GB microSD | 32GB+ microSD (Class 10) |
| **OS** | Raspberry Pi OS Lite (64-bit) | Raspberry Pi OS (64-bit) |
| **Kamera** | USB Webcam | Pi Camera Module v3 |
| **Jaringan** | WiFi / Ethernet | Ethernet (lebih stabil) |

> ⚠️ **PENTING**: Gunakan OS **64-bit** (arm64). Docker image SmartPark tidak support 32-bit.

---

## Step 1: Install Raspberry Pi OS

1. Download [Raspberry Pi Imager](https://www.raspberrypi.com/software/)
2. Flash **Raspberry Pi OS (64-bit)** ke microSD
3. Enable SSH (opsional, untuk akses remote):
   - Di Imager, klik ⚙ Settings → Enable SSH
   - Set username/password

---

## Step 2: Install Docker

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker (official script)
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add user to docker group (supaya tidak perlu sudo)
sudo usermod -aG docker $USER

# Logout dan login kembali
exit
# ... login kembali ...

# Verifikasi
docker --version
docker run hello-world
```

---

## Step 3: Pull SmartPark API

```bash
# Pull image (ganti yuln0x dengan Docker Hub username)
docker pull yuln0x/smartpark-api:latest

# Verifikasi image
docker images
```

> 💡 Image ~1.5 GB. Download pertama memakan waktu 5-15 menit tergantung kecepatan internet.

---

## Step 4: Jalankan SmartPark API

### Cara Sederhana

```bash
docker run -d \
  --name smartpark \
  --restart unless-stopped \
  -p 8000:8000 \
  yuln0x/smartpark-api:latest
```

### Cek Status

```bash
# Lihat container berjalan
docker ps

# Lihat logs
docker logs smartpark

# Cek health
curl http://localhost:8000/health
```

### Output yang diharapkan:

```json
{
  "status": "ok",
  "anpr_model_loaded": true,
  "ocr_engine_loaded": true,
  "version": "1.1.0"
}
```

---

## Step 5: Test API

### Test dengan foto lokal

```bash
# Detect plat nomor
curl -X POST http://localhost:8000/anpr/detect \
  -F "file=@foto_mobil.jpg"

# Full pipeline (detect + OCR + color)
curl -X POST http://localhost:8000/pipeline/verify \
  -F "file=@foto_mobil.jpg"
```

### Test dari komputer lain (dalam jaringan yang sama)

```bash
# Cari IP Raspberry Pi
hostname -I
# Output contoh: 192.168.1.100

# Dari komputer lain:
curl http://192.168.1.100:8000/docs    # Swagger UI
curl http://192.168.1.100:8000/health  # Health check
```

---

## Step 6: Auto-Start on Boot

Container sudah diset `--restart unless-stopped`, artinya:
- ✅ Auto-start setelah reboot
- ✅ Auto-restart jika crash
- ❌ Tidak start jika di-stop manual

Untuk memastikan Docker service jalan saat boot:

```bash
sudo systemctl enable docker
```

---

## Step 7: Update Image

Jika model di-update dan Docker image baru di-push:

```bash
# Stop container lama
docker stop smartpark && docker rm smartpark

# Pull image terbaru
docker pull yuln0x/smartpark-api:latest

# Jalankan ulang
docker run -d \
  --name smartpark \
  --restart unless-stopped \
  -p 8000:8000 \
  yuln0x/smartpark-api:latest

# Bersihkan image lama
docker image prune -f
```

---

## Troubleshooting

### Container tidak mau start

```bash
# Lihat error logs
docker logs smartpark

# Kemungkinan masalah:
# - RAM tidak cukup (butuh min 2GB free)
# - Port 8000 sudah dipakai
```

### API lambat

```bash
# Cek resource usage
docker stats smartpark

# Tips optimisasi:
# - Gunakan ONNX model (lebih cepat di ARM)
# - Set image size lebih kecil (320 atau 416)
# - Matikan service lain yang tidak perlu
```

### Kamera tidak terdeteksi

```bash
# Cek device
ls /dev/video*

# Jika Pi Camera:
sudo raspi-config
# → Interface Options → Camera → Enable

# Jika USB Camera:
sudo apt install fswebcam
fswebcam test.jpg
```

### Out of Memory

```bash
# Tambah swap (temporary)
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# Permanent: edit /etc/fstab
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

---

## Arsitektur Deployment

```
┌──────────────────────────────────────────────────────┐
│                   Raspberry Pi                        │
│                                                       │
│  ┌─────────────┐    ┌──────────────────────────┐     │
│  │   Kamera     │───→│  Docker Container         │    │
│  │   (USB/CSI)  │    │  ┌────────────────────┐  │    │
│  └─────────────┘    │  │  SmartPark API      │  │    │
│                      │  │  - ANPR Engine      │  │    │
│  ┌─────────────┐    │  │  - OCR Engine       │  │    │
│  │   Sensor     │    │  │  - Color Detect     │  │    │
│  │   (IR/Ultra) │    │  │  - Pipeline         │  │    │
│  └─────────────┘    │  └────────────────────┘  │    │
│                      │        :8000              │    │
│                      └──────────────────────────┘    │
│                               │                       │
│                               ▼                       │
│  ┌──────────────────────────────────────────────┐    │
│  │  Gate Controller Script (Python)              │    │
│  │  - Sensor → Capture → API → Gate             │    │
│  └──────────────────────────────────────────────┘    │
│                               │                       │
│                               ▼                       │
│  ┌─────────────┐    ┌─────────────┐                  │
│  │  Gate        │    │  Display    │                  │
│  │  Barrier     │    │  (LCD)      │                  │
│  └─────────────┘    └─────────────┘                  │
│                                                       │
└───────────────────────────────┬───────────────────────┘
                                │ WiFi/Ethernet
                                ▼
                    ┌──────────────────┐
                    │  iOS App         │
                    │  (SmartPark)     │
                    │  - GPS Location  │
                    │  - Parking Status│
                    │  - E-Wallet      │
                    └──────────────────┘
```

---

## Performa Estimasi

| Raspberry Pi | Inference Time | RAM Usage |
|---|---|---|
| Pi 4 (4GB) | ~800-1200ms | ~1.5 GB |
| Pi 4 (8GB) | ~800-1200ms | ~1.5 GB |
| Pi 5 (8GB) | ~400-600ms | ~1.5 GB |

> 💡 **Tip**: Untuk performa lebih baik, gunakan ONNX model dan set `imgsz=416` (lebih kecil tapi lebih cepat).
