# SmartPark — Simulasi Web

Dua simulasi web bergaya app **ParkirBoss** (neo-brutalist, ungu) untuk
mendemokan sistem SmartPark tanpa harus menjalankan app Flutter.

| File | Untuk apa | Sifat |
|------|-----------|-------|
| `iot-dashboard.html` | Dashboard operator gate — monitor perangkat **IoT** (ESP32 + kamera) secara real-time | **REAL** (terhubung backend & hardware) |
| `integrasi.html` | Demo **integrasi sistem** end-to-end untuk dosen | **HYBRID**: ANPR+OCR real, sisanya simulasi |

---

## Cara menjalankan

Kedua halaman butuh diakses lewat **http://localhost** (bukan klik file langsung),
karena browser hanya mengizinkan akses kamera di konteks aman (`localhost`/https).
Backend FastAPI sudah otomatis menyajikan folder `simulasi/`.

### 1. Jalankan backend

```bash
cd SmartPark
# (opsional) aktifkan venv yang punya deps ML: ultralytics, easyocr, opencv
python -m uvicorn api.main:app --reload --port 8000
```

> **Penting untuk ANPR real:** endpoint `/pipeline/verify` & `/device/*` butuh
> model ML aktif (`ultralytics` + `easyocr`/`torch` + `opencv`). Tanpa itu,
> backend tetap menyala tapi deteksi plat tidak jalan. Pasang dengan
> `pip install -r requirements.txt`.

### 2. Buka di browser

| Simulasi | URL |
|----------|-----|
| IoT Gate Dashboard | http://localhost:8000/simulasi/iot-dashboard.html |
| Integrasi Sistem (dosen) | http://localhost:8000/simulasi/integrasi.html |

Klik **⚙** di kanan atas bila perlu mengubah Base URL backend
(mis. IP LAN Raspberry Pi).

---

## 1. IoT Gate Dashboard (`iot-dashboard.html`)

Monitor operator gate. Terhubung ke backend nyata:

- **Live camera** — feed mewakili kamera gate (RPi5 / ESP32-CAM). Klik
  *Aktifkan Kamera* untuk pakai kamera komputer sebagai kamera gate.
- **Log kendaraan** — setiap event muncul otomatis: plat, **jam**, confidence,
  warna, keputusan (DIIZINKAN / DITOLAK), perintah palang.
- **Status palang** + statistik sesi (total / granted / ditolak / avg conf).

Sumber event (di-poll tiap 2 detik dari `GET /device/events`):
1. **ESP32 asli** mengirim `POST /device/trigger` → backend menangkap frame
   kamera → ANPR+OCR → event tercatat → muncul di dashboard.
2. **Tombol di dashboard** (untuk uji tanpa hardware):
   - `Sensor Trigger` → `POST /device/trigger` (kamera sisi device/server)
   - `Tangkap dari Feed` → `POST /device/process-image` (snapshot webcam)

Jika backend/hardware belum siap, dashboard tetap tampil dalam mode `OFFLINE`.

## 2. Simulasi Integrasi Sistem (`integrasi.html`) — untuk dosen

Fokus dosen: **ANPR+OCR yang REAL** memakai kamera device dosen. Sisanya
(DB lookup, GPS, palang, sesi, saldo, tracking) **disimulasikan** mengikuti
alur di `INTEGRASI_SISTEM.md`.

**Langkah demo:**
1. Klik **Aktifkan Kamera** lalu arahkan ke plat nomor (atau pilih *foto contoh*).
2. Tab **① Alur Masuk** → **Pindai Plat Masuk**:
   frame dikirim ke `/pipeline/verify` (deteksi asli) → DB lookup → cek GPS →
   palang buka → **sesi parkir dimulai** (biaya berjalan di app ParkirBoss kanan).
3. Tab **② Alur Keluar** → **Pindai Plat Keluar**:
   deteksi ulang → cari sesi aktif → cek GPS → **cek saldo** →
   **saldo dipotong** + struk muncul. Jika saldo kurang → muncul peringatan
   "SALDO TIDAK CUKUP" (tombol **Top Up** untuk menambah saldo).
4. Panel **Tracking** menampilkan kendaraan bergerak gate → slot parkir → gate keluar.

> Tarif demo: **Rp 3.000/jam**, waktu dipercepat (1 detik ≈ 1 menit parkir)
> agar biaya & pemotongan saldo terlihat cepat. Tekan **Reset** untuk mengulang.

---

## Berkas

```
simulasi/
├── iot-dashboard.html      # Simulasi 1 (IoT, real)
├── integrasi.html          # Simulasi 2 (integrasi, hybrid — untuk dosen)
├── assets/
│   ├── theme.css           # design token app (ungu neo-brutalist)
│   ├── app-shell.css       # komponen tiruan layar app ParkirBoss
│   └── samples/            # foto plat contoh (fallback bila tanpa kamera)
└── README.md
```

Perubahan backend pendukung: endpoint `GET /device/events` (log event in-memory
untuk dashboard) dan mount static `/simulasi` di `api/main.py`.
