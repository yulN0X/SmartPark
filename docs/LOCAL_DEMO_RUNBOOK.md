# Runbook Demo Lokal ParkirBoss + SmartPark

Panduan ini menjalankan sistem lengkap dari awal: backend akun/parkir, backend ANPR, aplikasi iPhone, ESP32-CAM gate masuk/keluar, GPS, dan dashboard web.

## 1. Arsitektur dan port

```text
iPhone Flutter ───────────────► ParkirBoss API :8080
                                     │
ESP32-CAM entry/exit ────────► SmartPark API :8000
                                     │
                                     └──► ParkirBoss API :8080
```

- **ParkirBoss API (`:8080`)** adalah sumber data utama untuk akun, kendaraan, saldo, GPS, sesi parkir, dan transaksi.
- **SmartPark API (`:8000`)** menerima foto dari ESP32-CAM, menjalankan ANPR/OCR, lalu meminta keputusan gate ke ParkirBoss API.
- Hanya trigger fisik ESP32-CAM ke `POST /device/process-image` yang dapat membuat sesi dan mengembalikan `OPEN_GATE` ke servo.
- Dashboard live scan dan upload foto adalah **visual-only** (`SCAN_ONLY`); jangan gunakan keduanya untuk menguji palang atau membuat sesi parkir.

## 2. Prasyarat

- Laptop, iPhone, ESP32-CAM entry, dan ESP32-CAM exit berada pada Wi-Fi yang sama. ESP32-CAM hanya mendukung Wi-Fi 2,4 GHz.
- Python 3.11+ dan Flutter SDK tersedia.
- Arduino IDE dengan board **AI Thinker ESP32-CAM**, library `ESP32Servo`, dan `ArduinoJson` 7.x.
- Backend laptop harus dapat diakses memakai IP LAN, bukan `localhost` atau `127.0.0.1` dari ESP32/iPhone.
- Servo memakai catu daya 5 V eksternal. GND catu servo dan GND ESP32-CAM harus tersambung bersama.
- Sinyal `ECHO` HC-SR04 harus melalui pembagi tegangan/level shifter ke 3,3 V sebelum masuk ESP32-CAM.

Cari IP LAN laptop:

```bash
ipconfig getifaddr en0
```

Gunakan hasilnya sebagai `<IP_LAPTOP>` pada seluruh langkah berikut.

## 3. Jalankan ParkirBoss API (`:8080`)

Terminal 1:

```bash
cd "/Users/patruddd/Documents/Sem 6/Proyek Sains Data/SmartPark/ParkirBoss/parkirboss-api"
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

Salin `.env.example` menjadi `.env`, lalu isi minimal:

```dotenv
DATABASE_URL=sqlite:///./parkirboss.db
SECRET_KEY=ganti_dengan_kunci_acak_yang_panjang
MIN_ANPR_CONFIDENCE=0.40
```

Generate nilai `SECRET_KEY` bila diperlukan:

```bash
python -c "import secrets; print(secrets.token_urlsafe(64))"
```

Jalankan API:

```bash
python -m uvicorn main:app --host 0.0.0.0 --port 8080
```

Verifikasi dari laptop:

```bash
curl http://127.0.0.1:8080/
```

## 4. Jalankan SmartPark API / ANPR (`:8000`)

Terminal 2:

```bash
cd "/Users/patruddd/Documents/Sem 6/Proyek Sains Data/SmartPark"
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
PARKIRBOSS_API_URL=http://127.0.0.1:8080/api \
  python -m uvicorn api.main:app --host 0.0.0.0 --port 8000
```

`PARKIRBOSS_API_URL` memakai `127.0.0.1` karena kedua API berjalan di laptop yang sama. Jangan gunakan alamat ini pada firmware ESP32-CAM.

Verifikasi:

```bash
curl http://127.0.0.1:8000/health
```

Buka dashboard pada laptop:

```text
http://<IP_LAPTOP>:8000/simulasi/iot-dashboard.html
```

## 5. Jalankan aplikasi iPhone

Terminal 3:

```bash
cd "/Users/patruddd/Documents/Sem 6/Proyek Sains Data/SmartPark/ParkirBoss/parkirboss-app"
flutter pub get
flutter run --dart-define=API_BASE_URL=http://<IP_LAPTOP>:8080/api
```

Pada iPhone:

1. Login atau buat akun.
2. Top up saldo.
3. Tambahkan kendaraan dengan plat yang akan dibaca kamera, misalnya `B 120 RKC`.
4. Izinkan **Camera** dan **Location While Using the App**.
5. Biarkan aplikasi terbuka ketika pengujian gate berlangsung agar GPS heartbeat dikirim.

## 6. Kalibrasi koordinat GPS gate

ESP32-CAM tidak mempunyai GPS. Backend membandingkan koordinat GPS iPhone dengan koordinat tetap `GATE-A-IN` dan `GATE-A-OUT` pada database.

Saat iPhone berada di samping gate entry, ambil latitude/longitude dari log Flutter atau database, lalu set koordinat gate. Contoh SQLite:

```bash
cd "/Users/patruddd/Documents/Sem 6/Proyek Sains Data/SmartPark"
sqlite3 ParkirBoss/parkirboss-api/parkirboss.db \
  "UPDATE gate_locations
   SET latitude=<LAT_ENTRY>, longitude=<LON_ENTRY>, radius_meters=15
   WHERE id='GATE-A-IN';"
```

Ulangi di lokasi gate exit:

```bash
sqlite3 ParkirBoss/parkirboss-api/parkirboss.db \
  "UPDATE gate_locations
   SET latitude=<LAT_EXIT>, longitude=<LON_EXIT>, radius_meters=15
   WHERE id='GATE-A-OUT';"
```

Cek konfigurasi:

```bash
sqlite3 -header -column ParkirBoss/parkirboss-api/parkirboss.db \
  "SELECT id, latitude, longitude, radius_meters FROM gate_locations;"
```

## 7. Konfigurasi dan flash ESP32-CAM

Ubah Wi-Fi dan IP server pada kedua firmware. Nilai `API_HOST` harus sama dengan IP LAN laptop.

| Firmware | File | Gate ID | Gate type |
|---|---|---|---|
| Entry | `firmware/esp32_entry_gate/esp32_entry_gate.ino` | `GATE-A-IN` | `entry` |
| Exit | `firmware/esp32_exit_gate/esp32_exit_gate.ino` | `GATE-A-OUT` | `exit` |

Contoh konfigurasi di **kedua** file:

```cpp
const char* WIFI_SSID     = "NAMA_WIFI_2_4GHZ";
const char* WIFI_PASSWORD = "PASSWORD_WIFI";
const char* API_HOST      = "<IP_LAPTOP>";
const int   API_PORT      = 8000;
const char* API_PATH      = "/device/process-image";
```

Untuk exit, pastikan tetap:

```cpp
const char* GATE_ID   = "GATE-A-OUT";
const char* GATE_TYPE = "exit";
```

Arduino IDE:

```text
Board            : AI Thinker ESP32-CAM
Partition Scheme : Huge APP (3MB No OTA / 1MB SPIFFS)
PSRAM            : Enabled
Serial Monitor   : 115200 baud
```

Flash masing-masing firmware. Setelah boot, firmware menjalankan self-test servo buka lalu tutup; amankan palang dan area sekitarnya sebelum memberi daya.

## 8. Uji servo dan jaringan sebelum kendaraan

Pada Serial Monitor tiap ESP32-CAM:

| Perintah | Hasil yang diharapkan |
|---|---|
| `o` | Servo membuka. Jika gagal, periksa catu 5 V, GND bersama, kabel sinyal GPIO 13, dan arah sudut servo. |
| `c` | Servo menutup. |
| `d` | Jarak dari HC-SR04 tercetak. |
| `r` | Kamera mendaftar ulang ke SmartPark API. |
| `t` | Capture foto dan menguji alur API dari ESP32-CAM. |

Untuk pengujian `t` atau HC-SR04, cari output berikut:

```text
HTTP status: 200
Action: OPEN_GATE
Gate OPENING: 90 -> 0 derajat
```

Jika `o` gagal, API tidak perlu diperiksa lagi: masalah berada pada wiring/catu daya servo. Jika `o` berhasil tetapi `t` tidak menghasilkan `OPEN_GATE`, periksa keputusan backend pada bagian troubleshooting.

## 9. Urutan uji end-to-end

### Masuk

1. Jalankan kedua API dan buka aplikasi iPhone.
2. Pastikan kendaraan terdaftar dan GPS iPhone berada dalam radius gate entry.
3. Letakkan kendaraan di depan HC-SR04 entry sampai sensor memicu ESP32-CAM.
4. ESP32-CAM capture dan mengirim foto ke `/device/process-image`.
5. Bila plat, GPS, dan kendaraan valid, respons `OPEN_GATE` diterima ESP32-CAM dan servo entry membuka.
6. Setelah kendaraan melewati IR sensor, palang menutup.
7. Periksa sesi aktif di aplikasi iPhone atau API:

```bash
curl -H "Authorization: Bearer <TOKEN>" \
  http://<IP_LAPTOP>:8080/api/parking/active
```

### Keluar

1. Pastikan session entry masih `ACTIVE`.
2. Trigger HC-SR04 exit dengan kendaraan yang sama.
3. Jika plat cocok dan saldo cukup, backend menghitung biaya, memotong saldo, menyelesaikan sesi, lalu mengirim `OPEN_GATE` ke ESP32-CAM exit.
4. Cek saldo dan riwayat pada aplikasi iPhone.

## 10. Troubleshooting

| Gejala | Penyebab umum | Tindakan |
|---|---|---|
| Plat terdeteksi tetapi sesi tidak aktif | GPS terlalu jauh, GPS kadaluarsa, atau plat belum terdaftar | Buka aplikasi, tunggu heartbeat, cek koordinat gate dan kendaraan. |
| Session aktif tetapi palang tidak bergerak | Session dibuat oleh dashboard scan, bukan trigger ESP32 fisik | Hapus sesi uji, jangan gunakan auto-scan dashboard untuk akses, trigger HC-SR04 atau `t`. |
| `OPEN_GATE` muncul tetapi servo tidak bergerak | Wiring/arus servo | Uji `o`; gunakan supply 5 V eksternal dan common ground. |
| ESP32 `CONNECTION_ERROR` | IP laptop/Wi-Fi/backend salah | Pastikan `API_HOST=<IP_LAPTOP>`, port 8000, Wi-Fi sama, dan API memakai `--host 0.0.0.0`. |
| `MANUAL_REQUIRED` | OCR membaca plat lain atau plat tidak terdaftar | Cek plat pada database dan kualitas/arah pencahayaan kamera. |
| `REVIEW` | Confidence ANPR di bawah ambang | Perbaiki frame kamera/pencahayaan atau kalibrasi `MIN_ANPR_CONFIDENCE`. |
| Exit menolak `Tidak ada sesi aktif` | Entry belum lewat alur fisik atau sesi sudah selesai | Jalankan entry fisik dahulu dan cek sesi `ACTIVE`. |
| Aplikasi iPhone tidak menampilkan sesi/saldo | API 8080 tidak dapat dijangkau atau token sudah lama | Pastikan URL build memakai IP laptop, login ulang, lalu cek API port 8080. |

## 11. Data audit cepat

Gunakan perintah berikut di laptop untuk melihat alasan keputusan terakhir:

```bash
sqlite3 -header -column ParkirBoss/parkirboss-api/parkirboss.db \
  "SELECT timestamp, plate, gate_id, gate_type, action, reason
   FROM gate_events
   ORDER BY timestamp DESC
   LIMIT 20;"
```

Lihat sesi dan transaksi:

```bash
sqlite3 -header -column ParkirBoss/parkirboss-api/parkirboss.db \
  "SELECT plate_number, status, entry_time, exit_time, total_cost
   FROM parking_sessions
   ORDER BY entry_time DESC;"
```

```bash
sqlite3 -header -column ParkirBoss/parkirboss-api/parkirboss.db \
  "SELECT type, amount, balance_after, description, created_at
   FROM transactions
   ORDER BY created_at DESC;"
```
