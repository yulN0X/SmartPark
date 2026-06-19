# Integrasi Device: ESP32-CAM + SmartPark API

Dokumen ini menjelaskan integrasi hardware SmartPark menggunakan **ESP32-CAM AI-Thinker** sebagai kamera + controller di setiap gate.

> 📘 **Panduan Lengkap**: Untuk assembly hardware, wiring diagram, dan step-by-step, lihat **[PANDUAN_IOT.md](./PANDUAN_IOT.md)**.

## Arsitektur

```
Laptop (Brain)                ESP32-CAM AI-Thinker (×2)
┌──────────────────┐          ┌────────────────────────────────┐
│ SmartPark API    │          │ OV2640 Camera (built-in)       │
│ ANPR + OCR       │◄── WiFi ─┤ Flash LED → pencahayaan plat  │
│ Scoring Engine   │          │ HC-SR04 → deteksi kendaraan    │
│                  │──────────►│ IR Obstacle → auto-close gate │
└──────────────────┘  JSON    │ Servo SG90 → palang gate       │
                              └────────────────────────────────┘
```

**Alur**:
1. HC-SR04 deteksi kendaraan mendekat
2. ESP32-CAM nyalakan flash LED + capture foto
3. Upload foto ke API via `POST /device/process-image`
4. API proses ANPR + OCR → kirim JSON response
5. ESP32-CAM buka/tutup gate servo berdasarkan response
6. IR obstacle sensor auto-close gate saat kendaraan lewat

## Jalankan API di Laptop/PC

```bash
pip install -r requirements.txt
uvicorn api.main:app --reload --host 0.0.0.0 --port 8000
```

Gunakan `--host 0.0.0.0` agar ESP32-CAM di jaringan WiFi yang sama bisa mengakses API.

Variabel environment yang tersedia:

| Env Var | Default | Fungsi |
|---|---:|---|
| `SMARTPARK_CAMERA_INDEX` | `0` | Index kamera OpenCV (untuk fallback webcam) |
| `SMARTPARK_SAVE_CAPTURES` | `true` | Simpan hasil capture ke `uploads/captures` |
| `SMARTPARK_GATE_OPEN_SECONDS` | `5` | Durasi instruksi buka gate pada response |

## Endpoint Utama

### 1. Cek status API

```bash
curl http://localhost:8000/health
```

### 2. Upload gambar dari ESP32-CAM (endpoint utama)

ESP32-CAM firmware mengirim foto hasil capture ke endpoint ini:

```bash
curl -X POST http://localhost:8000/device/process-image \
  -F "file=@foto test/plat_hitam.png" \
  -F "device_id=esp32cam-gate-entry-1" \
  -F "gate_id=GATE-A-IN" \
  -F "gate_type=entry"
```

Response berisi:

```json
{
  "command": {
    "action": "OPEN_GATE",
    "gate_open_seconds": 5.0,
    "reason": "Gate opens automatically"
  },
  "pipeline": {
    "results": [
      {
        "plate_text": "B 1234 ABC",
        "plate_confidence": 0.92,
        "access": {
          "decision": "GRANTED"
        }
      }
    ]
  }
}
```

### 3. Trigger sensor tanpa kamera (fallback)

Endpoint ini menggunakan webcam laptop (fallback jika kamera ESP32-CAM bermasalah):

```bash
curl -X POST http://localhost:8000/device/trigger \
  -H "Content-Type: application/json" \
  -d '{
    "device_id": "manual-test",
    "gate_id": "GATE-A-IN",
    "gate_type": "entry",
    "sensor": "ultrasonic",
    "distance_cm": 18.5
  }'
```

## Firmware ESP32-CAM

Tersedia 3 versi firmware:

| Firmware | Path | Board | Fungsi |
|---|---|---|---|
| **Entry Gate** | `firmware/esp32_entry_gate/` | AI Thinker ESP32-CAM | Kamera + servo + sensor gate masuk |
| **Exit Gate** | `firmware/esp32_exit_gate/` | AI Thinker ESP32-CAM | Kamera + servo + sensor gate keluar |
| **Sensor Trigger (Legacy)** | `firmware/esp32_sensor_trigger/` | ESP32 DevKit | Hanya kirim trigger sensor, tanpa kamera |

### Konfigurasi yang perlu diubah:

```cpp
const char* WIFI_SSID     = "NAMA_WIFI";
const char* WIFI_PASSWORD = "PASSWORD_WIFI";
const char* API_HOST      = "IP_LAPTOP";  // contoh: "192.168.52.203", tanpa "http://"
```

Jangan gunakan `127.0.0.1` atau `localhost` sebagai `API_HOST` di firmware. Dari sudut pandang ESP32-CAM, alamat itu berarti ESP32-CAM sendiri, bukan laptop yang menjalankan API.

### Board settings di Arduino IDE:

```
Board           : AI Thinker ESP32-CAM
Partition Scheme: Huge APP (3MB No OTA / 1MB SPIFFS)
```

### Command test lewat Serial Monitor:

| Command | Fungsi |
|---|---|
| `t` | Capture foto + upload manual ke API |
| `o` | Test buka servo/palang |
| `c` | Test tutup servo/palang |
| `d` | Baca jarak HC-SR04 sekali |
| `h` atau `?` | Tampilkan bantuan |

> Untuk wiring aman, pastikan ECHO HC-SR04 melewati pembagi tegangan 1kΩ + 2kΩ sebelum masuk GPIO 15. Detail lengkap ada di [PANDUAN_IOT.md](./PANDUAN_IOT.md).

### Cari IP laptop:

```bash
# macOS
ipconfig getifaddr en0

# Linux
hostname -I

# Windows
ipconfig | findstr IPv4
```

## Device Simulator (Tanpa Hardware)

```bash
# Interactive mode
python scripts/device_simulator.py

# Upload foto
python scripts/device_simulator.py --image "foto test/plat_hitam.png"

# Single trigger
python scripts/device_simulator.py --once --gate GATE-A-IN --type entry

# Auto-trigger setiap 10 detik
python scripts/device_simulator.py --auto --interval 10
```

## Alur Lanjutan (Raspberry Pi)

Setelah prototype berhasil, migrasi ke Raspberry Pi:

1. ESP32-CAM tetap capture + upload.
2. Raspberry Pi menjalankan SmartPark API (Docker).
3. Hanya ubah `API_HOST` di firmware ke IP Raspberry Pi.

> 📘 Lihat: [PANDUAN_IOT.md](./PANDUAN_IOT.md) untuk panduan assembly lengkap dan [RASPBERRY_PI_SETUP.md](./RASPBERRY_PI_SETUP.md) untuk deployment.
