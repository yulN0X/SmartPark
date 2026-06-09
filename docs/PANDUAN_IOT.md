op# Panduan IoT SmartPark — Assembly & Simulasi Hardware

Panduan lengkap merakit, mengonfigurasi, dan menjalankan sistem IoT SmartPark.
Laptop/Mac berperan sebagai **Brain** (ANPR + OCR engine), sementara **ESP32-CAM** berfungsi sebagai **kamera + controller** di setiap gate.

---

## Daftar Isi

1. [Arsitektur Sistem](#1-arsitektur-sistem)
2. [Daftar Komponen & Estimasi Biaya](#2-daftar-komponen--estimasi-biaya)
3. [Mengenal ESP32-CAM AI-Thinker](#3-mengenal-esp32-cam-ai-thinker)
4. [Pin Mapping ESP32-CAM](#4-pin-mapping-esp32-cam)
5. [Wiring Diagram](#5-wiring-diagram)
6. [Assembly Step-by-Step](#6-assembly-step-by-step)
7. [Flash Firmware ke ESP32-CAM](#7-flash-firmware-ke-esp32-cam)
8. [Menjalankan Sistem End-to-End](#8-menjalankan-sistem-end-to-end)
9. [Device Simulator (Tanpa Hardware)](#9-device-simulator-tanpa-hardware)
10. [Troubleshooting Hardware](#10-troubleshooting-hardware)
11. [Transisi ke Raspberry Pi (Produksi)](#11-transisi-ke-raspberry-pi-produksi)

---

## 1. Arsitektur Sistem

### Mode Development (Laptop sebagai Brain)

```
┌──────────────────────────────────────────────────────────────────┐
│                       LAPTOP / MAC (BRAIN)                       │
│                                                                  │
│   ┌──────────────────────────────────────────────────────────┐  │
│   │              SmartPark API (FastAPI :8000)                │  │
│   │                                                          │  │
│   │   ┌──────────┐  ┌──────────┐  ┌───────────────────────┐│  │
│   │   │  ANPR     │  │  OCR     │  │  Verification         ││  │
│   │   │  Engine   │  │  Engine  │  │  Pipeline             ││  │
│   │   │ (YOLOv8)  │  │(FastOCR) │  │  (Scoring + Decision) ││  │
│   │   └──────────┘  └──────────┘  └───────────────────────┘│  │
│   │                                                          │  │
│   │   Endpoint utama:                                        │  │
│   │   • POST /device/process-image ← foto dari ESP32-CAM    │  │
│   └──────────────────────────────────────────────────────────┘  │
└──────────────────────────────┬───────────────────────────────────┘
                               │
                         WiFi (HTTP)
                    Image upload + JSON response
                               │
      ┌────────────────────────┴──────────────────────────┐
      │                                                    │
      ▼                                                    ▼
┌──────────────────────────┐    ┌──────────────────────────┐
│  ESP32-CAM #1            │    │  ESP32-CAM #2            │
│  GATE MASUK (Entry)      │    │  GATE KELUAR (Exit)      │
│                          │    │                          │
│  ┌─────────┐ ┌────────┐ │    │  ┌─────────┐ ┌────────┐ │
│  │ OV2640  │ │ Flash  │ │    │  │ OV2640  │ │ Flash  │ │
│  │ Camera  │ │ LED    │ │    │  │ Camera  │ │ LED    │ │
│  │(built-in)│ │(GPIO 4)│ │    │  │(built-in)│ │(GPIO 4)│ │
│  └─────────┘ └────────┘ │    │  └─────────┘ └────────┘ │
│                          │    │                          │
│  ┌─────────┐ ┌────────┐ │    │  ┌─────────┐ ┌────────┐ │
│  │ HC-SR04 │ │ IR     │ │    │  │ HC-SR04 │ │ IR     │ │
│  │ Sensor  │ │Obstacle│ │    │  │ Sensor  │ │Obstacle│ │
│  │(deteksi)│ │(tutup) │ │    │  │(deteksi)│ │(tutup) │ │
│  └─────────┘ └────────┘ │    │  └─────────┘ └────────┘ │
│                          │    │                          │
│  ┌─────────┐             │    │  ┌─────────┐             │
│  │ Servo   │             │    │  │ Servo   │             │
│  │ SG90    │             │    │  │ SG90    │             │
│  │(palang) │             │    │  │(palang) │             │
│  └─────────┘             │    │  └─────────┘             │
└──────────────────────────┘    └──────────────────────────┘
```

### Alur Data Detail (Per Gate)

```
  ┌──────────┐   kendaraan    ┌────────────────────────────────┐
  │ HC-SR04  │──────────────→│  ESP32-CAM                      │
  │(deteksi) │  jarak < 30cm │                                  │
  └──────────┘               │  1. Flash LED ON (GPIO 4)        │
                              │  2. Kamera OV2640 capture JPEG   │
                              │  3. Flash LED OFF                │
                              │  4. Upload foto ke API           │
                              │     POST /device/process-image   │
                              └──────────┬─────────────────────┘
                                         │ HTTP multipart
                                         ▼
                              ┌──────────────────────┐
                              │  Laptop API          │
                              │  ANPR + OCR Pipeline │
                              └──────────┬───────────┘
                                         │ JSON response
                                         ▼
                              ┌──────────────────────────────────┐
                              │  ESP32-CAM parse response        │
                              │                                  │
                              │  action == "OPEN_GATE"?          │
                              │  ├─ YES → Servo 90° (buka)      │
                              │  │        LED status: ON         │
                              │  │                               │
                              │  └─ NO  → Servo tetap 0°        │
                              │           Gate tetap tutup       │
                              └──────────┬───────────────────────┘
                                         │
                                    Jika gate terbuka:
                                         │
  ┌──────────┐   kendaraan    ┌──────────┴───────────────┐
  │ IR       │──────────────→│  Kendaraan lewat?          │
  │ Obstacle │  melewati     │  IR detect → clear         │
  │ Sensor   │  gate         │  → Servo 0° (tutup gate)   │
  └──────────┘               └──────────────────────────┘
```

### Perbedaan dari Arsitektur Sebelumnya

| Aspek | Sebelumnya (ESP32 DevKit) | Sekarang (ESP32-CAM) |
|---|---|---|
| **Kamera** | Webcam laptop | OV2640 built-in di ESP32-CAM |
| **Pengambilan gambar** | API capture dari laptop | ESP32-CAM capture + upload |
| **Endpoint API** | `/device/trigger` | `/device/process-image` |
| **Pencahayaan plat** | Tidak ada | Flash LED built-in (GPIO 4) |
| **Penutupan gate** | Timer (5 detik) | IR sensor otomatis |
| **LCD** | LCD I2C 16x2 | Tidak dipakai (pin terbatas) |
| **Buzzer** | Active buzzer | Tidak dipakai (pin terbatas) |
| **LED status** | LED merah + hijau eksternal | LED onboard GPIO 33 |

> 💡 ESP32-CAM AI-Thinker memiliki **GPIO terbatas** karena banyak pin dipakai kamera & SD card. Dengan 4 sensor/aktuator (HC-SR04, IR, Servo, Flash LED) sudah optimal.

---

## 2. Daftar Komponen & Estimasi Biaya

### Komponen Per Gate (×2 untuk Entry + Exit)

| No | Komponen | Spesifikasi | Qty | Harga (IDR) |
|:--:|---|---|:---:|---:|
| 1 | **ESP32-CAM AI-Thinker** | Kamera OV2640 + WiFi + Flash LED | 2 | 75.000 × 2 |
| 2 | **ESP32-CAM-MB Programmer** | USB programmer untuk flash firmware | 1 | 25.000 |
| 3 | **HC-SR04 Ultrasonic** | Sensor jarak (2cm–400cm), deteksi kendaraan | 2 | 12.000 × 2 |
| 4 | **IR Obstacle Sensor** | E18-D80NK / IR Obstacle Avoidance, penutupan gate | 2 | 15.000 × 2 |
| 5 | **Servo SG90** | Micro servo 180° untuk palang mini | 2 | 15.000 × 2 |
| 6 | **Power Supply 5V 2A** | Adaptor supply stabil untuk ESP32-CAM + servo | 2 | 25.000 × 2 |

### Komponen Pendukung

| No | Komponen | Spesifikasi | Qty | Harga (IDR) |
|:--:|---|---|:---:|---:|
| 7 | **Breadboard kecil** | 400 tie-point | 1–2 | 15.000 |
| 8 | **Kabel Jumper** | M-M dan M-F, 20cm | Secukupnya | 12.000 × 2 |
| 9 | **Bahan palang mini** | Stik es krim / akrilik / karton tebal | 2 | 5.000 |
| 10 | **Dudukan servo** | 3D print / akrilik / kardus tebal / bracket | 2 | 10.000 × 2 |
| 11 | **LED putih kecil** | 5mm, pencahayaan plat (opsional) | 2 | 1.000 |
| 12 | **Resistor 220Ω** | Untuk LED putih (opsional) | 2 | 500 |
| 13 | **Miniatur kendaraan** | Atau plat nomor print untuk demo | 1–2 | 15.000 |
| 14 | **Resistor 1kΩ + 2kΩ** | Pembagi tegangan ECHO HC-SR04 ke 3.3V | 2 pasang | 1.000 |
| 15 | **DC jack screw terminal** | Memudahkan sambung adaptor 5V ke breadboard | 1–2 | 5.000 |

### Ringkasan Biaya

| Kategori | Total |
|---|---:|
| **Komponen Utama (×2 gate)** | ~Rp 359.000 |
| **Komponen Pendukung** | ~Rp 96.000 |
| **Total Estimasi** | **~Rp 455.000** |

> 💡 **Catatan pencahayaan**: Flash LED built-in ESP32-CAM (GPIO 4) sudah cukup terang untuk menerangi plat nomor saat pengambilan gambar. LED putih eksternal bersifat **opsional** sebagai pencahayaan tambahan.

---

## 3. Mengenal ESP32-CAM AI-Thinker

### Spesifikasi

| Fitur | Detail |
|---|---|
| **MCU** | ESP32-S (Dual-core 240MHz, 520KB SRAM) |
| **PSRAM** | 4MB (untuk buffer kamera resolusi tinggi) |
| **Kamera** | OV2640 (max 1600×1200, JPEG output) |
| **Flash LED** | LED putih terang pada GPIO 4 |
| **LED Onboard** | LED merah kecil pada GPIO 33 (active LOW) |
| **WiFi** | 802.11 b/g/n 2.4GHz |
| **USB** | Tidak ada — perlu **ESP32-CAM-MB** programmer |
| **SD Card** | Slot MicroSD (kita tidak pakai) |
| **GPIO tersedia** | Terbatas — banyak dipakai kamera & SD |

### Tampilan Board

```
                ┌────────────────────────────┐
                │     ┌──────┐               │
                │     │OV2640│ ← Kamera      │
                │     │Camera│               │
                │     └──────┘               │
                │                            │
                │  [Flash LED]  ← GPIO 4     │
                │                            │
   GND ────────┤ GND                    5V ├──────── 5V
   GPIO 12 ────┤ IO12                  GND ├──────── GND
   GPIO 13 ────┤ IO13                  IO15├──────── GPIO 15
   GPIO 15 ────┤ IO15                  IO14├──────── GPIO 14
   GPIO 14 ────┤ IO14                  IO2 ├──────── GPIO 2
   GPIO 2 ─────┤ IO2                   IO4 ├──────── GPIO 4 (Flash)
   GPIO 4 ─────┤ IO4                 3V3  ├──────── 3.3V
                │                            │
                │     [Antena WiFi]          │
                │                            │
                │  ┌─────────────────────┐  │
                │  │  ESP32-CAM-MB       │  │
                │  │  Programmer         │  │
                │  │  [USB Micro Port]   │  │
                │  └─────────────────────┘  │
                └────────────────────────────┘
```

### Pin yang Digunakan oleh Kamera OV2640

Pin-pin ini **TIDAK BISA dipakai** untuk peripheral lain:

```
GPIO 0  → XCLK (camera clock, juga boot mode)
GPIO 5  → D0 (camera data)
GPIO 18 → D1
GPIO 19 → D2
GPIO 21 → D3
GPIO 36 → D4
GPIO 39 → D5
GPIO 34 → D6
GPIO 35 → D7
GPIO 25 → VSYNC
GPIO 23 → HREF
GPIO 22 → PCLK
GPIO 26 → SIOD (I2C data kamera)
GPIO 27 → SIOC (I2C clock kamera)
GPIO 32 → PWDN (power down kamera)
```

### Pin yang Tersedia (Tanpa SD Card)

Jika **SD card tidak digunakan** (kita tidak pakai), GPIO berikut **bisa dipakai**:

| GPIO | Status | Catatan |
|:----:|---|---|
| **2** | ✅ Tersedia | Strapping pin, harus LOW/float saat boot |
| **4** | ⚡ Flash LED | Built-in flash LED, bisa dipakai sebagai output |
| **12** | ⚠️ Hati-hati | Strapping pin (flash voltage). HARUS LOW saat boot! |
| **13** | ✅ Tersedia | Aman dipakai |
| **14** | ✅ Tersedia | Aman dipakai |
| **15** | ✅ Tersedia | Strapping pin (debug log), aman setelah boot |
| **33** | ⚡ Onboard LED | LED merah kecil, active LOW |

> ⚠️ **GPIO 12 PENTING**: Jika GPIO 12 bernilai HIGH saat boot, ESP32 gagal start (salah set flash voltage ke 1.8V). Pastikan **tidak ada sensor/komponen** yang men-pull HIGH pada GPIO 12 saat power-on. Kita **tidak memakai GPIO 12** untuk menghindari masalah ini.

---

## 4. Pin Mapping ESP32-CAM

### Per Gate (Entry dan Exit Identik)

| GPIO | Komponen | Fungsi | Tipe | Catatan |
|:----:|---|---|---|---|
| **4** | Flash LED | Pencahayaan plat saat capture | Output | Built-in di ESP32-CAM |
| **14** | HC-SR04 TRIG | Trigger pulse ultrasonik | Output | Aman, tidak ada boot issue |
| **15** | HC-SR04 ECHO | Echo pulse input | Input | Aman setelah boot |
| **13** | Servo SG90 | PWM signal palang gate | Output | Aman |
| **2** | IR Obstacle Sensor | Deteksi kendaraan lewat gate | Input | Active LOW saat obstacle |
| **33** | LED Onboard | Indikator status (merah) | Output | Active LOW (built-in) |

### Diagram Visual

```
                       ESP32-CAM AI-Thinker
                    ┌─────────────────────────┐
                    │   [OV2640 Camera]        │
                    │   [Flash LED = GPIO 4]   │
                    │                          │
   HC-SR04 TRIG ←──┤ GPIO 14                  │
   HC-SR04 ECHO → R1/R2 → GPIO 15            │
   Servo SG90   ←──┤ GPIO 13                  │
   IR Obstacle  →──┤ GPIO 2                   │
                    │ GPIO 33 → LED onboard    │
                    │                          │
              5V ──┤ 5V                       │
             GND ──┤ GND                      │
                    │                          │
                    │  [ESP32-CAM-MB]          │
                    │  [USB Micro Port]        │
                    └─────────────────────────┘
```

---

## 5. Wiring Diagram

### Urutan Power dari Adaptor ke Breadboard

Untuk pemula, rakit **jalur power dulu** sebelum kabel sinyal. Jangan colok adaptor ke listrik saat memasang atau memindahkan jumper.

```
Adaptor 5V 2A
┌──────────────┐
│ +5V / merah  ├────────── rail merah breadboard (+)
│ GND / hitam  ├────────── rail biru breadboard (-)
└──────────────┘

Rail merah breadboard (+5V) ──→ pin 5V ESP32-CAM, VCC sensor, VCC servo
Rail biru breadboard (GND)  ──→ pin GND ESP32-CAM, GND sensor, GND servo
```

Checklist power sebelum adaptor dinyalakan:
- Pastikan kabel **+5V adaptor** masuk ke rail merah breadboard.
- Pastikan kabel **GND adaptor** masuk ke rail biru breadboard.
- Hubungkan pin **5V ESP32-CAM** ke rail merah, bukan ke pin **3V3**.
- Hubungkan pin **GND ESP32-CAM** ke rail biru.
- Jika breadboard memiliki rail power yang terputus di tengah, sambungkan rail merah kiri-kanan dan rail biru kiri-kanan dengan jumper pendek.
- Untuk 2 gate, paling aman gunakan **1 adaptor 5V 2A per gate**. Jika memakai 1 adaptor untuk 2 gate, gunakan minimal **5V 5A** dan jangan membalik polaritas.

> ⚠️ Jangan hubungkan 5V ke pin 3V3 ESP32-CAM. Pin 3V3 bukan tempat masuk adaptor 5V.

### HC-SR04 Ultrasonic Sensor (Deteksi Kendaraan Mendekat)

```
HC-SR04             ESP32-CAM / Breadboard
┌───────┐
│ VCC   │────────── rail +5V
│ TRIG  │────────── GPIO 14
│ ECHO  │── R1 1kΩ ─┬── GPIO 15
│ GND   │────────── rail GND
└───────┘           │
                    R2 2kΩ
                    │
                 rail GND
```

Posisi: **di depan gate**, menghadap arah datang kendaraan.

> ⚠️ **Pembagi tegangan ECHO wajib dipakai** untuk versi aman pemula. HC-SR04 biasanya mengeluarkan sinyal ECHO 5V, sedangkan GPIO ESP32 bekerja di 3.3V. R1 1kΩ dipasang dari ECHO ke GPIO 15, lalu R2 2kΩ dari GPIO 15 ke GND.

### IR Obstacle Sensor (Auto-Close Gate)

```
IR Obstacle         ESP32-CAM / Breadboard
┌───────┐
│ VCC   │────────── rail +5V (atau 3.3V, cek spec sensor)
│ OUT   │────────── GPIO 2
│ GND   │────────── rail GND
└───────┘
```

Posisi: **di belakang gate** (setelah palang), mendeteksi kendaraan yang sudah melewati gate.

Output:
- **HIGH** = tidak ada obstacle (kosong)
- **LOW** = ada obstacle terdeteksi (kendaraan lewat)

> Potensiometer pada sensor IR bisa diputar untuk mengatur jarak deteksi.

### Servo SG90 (Palang Gate)

```
SG90 Servo          ESP32-CAM / Breadboard
┌───────────┐
│ Merah     │────── rail +5V
│ Coklat    │────── rail GND
│ Oranye    │────── GPIO 13
└───────────┘
```

Warna kabel servo standar:
- **Merah** = VCC (5V)
- **Coklat/Hitam** = GND
- **Oranye/Kuning** = Signal (PWM)

> ⚠️ Servo **harus** mengambil 5V dari rail adaptor/breadboard, bukan dari USB programmer. USB tidak cukup arus untuk ESP32-CAM + kamera + servo.

### Wiring Lengkap (1 Gate)

```
                              ┌──────────────────────────┐
                              │       ESP32-CAM           │
    Power Supply              │      AI-Thinker           │
    5V 2A                     │                           │
    ┌──────┐                  │   [OV2640 Camera]         │
    │ +5V  ├──────────────────┤ 5V                        │
    │ GND  ├──┬───────────────┤ GND                       │
    └──────┘  │               │                           │
              │               │   [Flash LED = GPIO 4]    │
              │               │    (pencahayaan plat      │
              │               │     saat capture)         │
              │               │                           │
    ┌──────────┐              │                           │
    │ HC-SR04  │              │                           │
    │          ├── VCC ───────┤ 5V                        │
    │          ├── TRIG ──────┤ GPIO 14                   │
    │          ├── ECHO ─R1/R2┤ GPIO 15                   │
    │          ├── GND ───┬───┤ GND                       │
    └──────────┘          │   │                           │
                          │   │                           │
    ┌──────────┐          │   │                           │
    │ IR       │          │   │                           │
    │ Obstacle │          │   │                           │
    │          ├── VCC ───┼───┤ 5V                        │
    │          ├── OUT ───┼───┤ GPIO 2                    │
    │          ├── GND ───┤   │                           │
    └──────────┘          │   │                           │
                          │   │                           │
    ┌──────────┐          │   │                           │
    │ Servo    │          │   │                           │
    │ SG90     │          │   │                           │
    │          ├── VCC ───┼───┤ 5V                        │
    │          ├── Signal ┼───┤ GPIO 13                   │
    │          ├── GND ───┘   │                           │
    └──────────┘              │  GPIO 33 = LED onboard    │
                              │  (indikator status)       │
                              │                           │
                              │  [ESP32-CAM-MB]           │
                              │  [USB — hanya untuk flash]│
                              └──────────────────────────┘
```

> ⚠️ **Common Ground**: Semua komponen **HARUS** share GND yang sama. Power supply 5V 2A menyuplai ESP32-CAM, HC-SR04, IR sensor, dan servo sekaligus.

> ⚠️ Pada diagram besar, `ECHO ─R1/R2→ GPIO 15` berarti sinyal ECHO harus melewati pembagi tegangan 1kΩ + 2kΩ seperti diagram HC-SR04 di atas.

> ⚠️ **USB Programmer**: ESP32-CAM-MB dipasang **hanya saat flash firmware**. Setelah firmware di-upload, lepas programmer dan pakai power supply 5V 2A.

---

## 6. Assembly Step-by-Step

### Persiapan

1. ✅ ESP32-CAM AI-Thinker + MB Programmer
2. ✅ Breadboard kecil + kabel jumper
3. ✅ Arduino IDE terinstall
4. ✅ Power supply 5V 2A

### Langkah Assembly

#### Step 1: Test ESP32-CAM Dasar

```
1. Pasang ESP32-CAM ke MB Programmer
2. Colokkan USB ke laptop
3. Di Arduino IDE, pilih board "AI Thinker ESP32-CAM"
4. Upload sketch Blink LED (GPIO 33):
     pinMode(33, OUTPUT);
     digitalWrite(33, LOW);  // LED ON (active LOW)
5. Jika LED merah kecil menyala → board OK ✅
```

#### Step 2: Test Kamera

```
1. Upload sketch CameraWebServer (contoh bawaan ESP32):
   File → Examples → ESP32 → Camera → CameraWebServer
2. Ubah model ke AI_THINKER
3. Set SSID dan password WiFi
4. Upload, buka Serial Monitor
5. Buka IP address yang muncul di browser
6. Jika bisa melihat stream kamera → kamera OK ✅
```

#### Step 3: Pasang HC-SR04

```
1. VCC → rail +5V breadboard
2. GND → rail GND breadboard
3. TRIG → GPIO 14
4. ECHO → resistor 1kΩ → titik tengah → GPIO 15
5. Titik tengah yang sama → resistor 2kΩ → rail GND
```

**Test**: Upload sketch baca jarak di Serial Monitor.

#### Step 4: Pasang IR Obstacle Sensor

```
1. VCC → rail +5V breadboard
2. GND → rail GND breadboard
3. OUT → GPIO 2
```

**Test**: Dekatkan tangan ke sensor, Serial Monitor tampilkan "Obstacle detected".

> 💡 Putar potensiometer pada sensor IR untuk mengatur jarak deteksi (5–80cm).

#### Step 5: Pasang Servo SG90

```
1. Merah (VCC) → rail +5V breadboard dari adaptor, BUKAN USB
2. Coklat (GND) → rail GND breadboard
3. Oranye (Signal) → GPIO 13
```

**Test**: Upload Servo sweep sketch, palang harus bergerak 0°–90°.

#### Step 6: Pasang Bahan Palang

```
1. Pasang servo arm (cross-shaped) ke servo
2. Tempelkan stik es krim / akrilik ke servo arm
3. Screw kecil untuk mengunci arm
4. Test: palang bergerak naik-turun dengan baik?
```

#### Step 7: Ganti Power ke Supply 5V 2A

```
1. Lepas ESP32-CAM dari MB Programmer
2. Pastikan adaptor 5V 2A masih OFF/belum dicolok listrik
3. Hubungkan rail +5V breadboard → pin 5V ESP32-CAM
4. Hubungkan rail GND breadboard → pin GND ESP32-CAM
5. Nyalakan adaptor 5V 2A
6. ESP32-CAM harus boot otomatis
```

> ⚠️ **JANGAN** power ESP32-CAM dari USB programmer DAN power supply bersamaan!

### Checklist Assembly (Per Gate)

- [ ] ESP32-CAM bisa di-flash via MB Programmer
- [ ] Kamera OV2640 mengambil gambar dengan benar
- [ ] Flash LED menyala saat GPIO 4 HIGH
- [ ] HC-SR04 membaca jarak (2–400cm)
- [ ] ECHO HC-SR04 melewati resistor 1kΩ + 2kΩ sebelum masuk GPIO 15
- [ ] IR Obstacle sensor mendeteksi objek
- [ ] Servo SG90 bergerak 0°–90°
- [ ] Semua GND terhubung common ground
- [ ] Power supply 5V 2A menyuplai semua komponen
- [ ] WiFi terhubung ke jaringan lokal

---

## 7. Flash Firmware ke ESP32-CAM

### Persiapan Arduino IDE

1. **Install Arduino IDE** (versi 2.x direkomendasikan)
   - Download: https://www.arduino.cc/en/software

2. **Install ESP32 Board Package**:
   ```
   File → Preferences → Additional Board Manager URLs:
   https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json
   ```
   Lalu: `Tools → Board → Board Manager → cari "esp32" → Install`

3. **Install Library yang Dibutuhkan** (`Tools → Manage Libraries`):
   - `ESP32Servo` by Kevin Harrington
   - `ArduinoJson` by Benoit Blanchon (versi 7.x)
   
   > Library `esp_camera.h` sudah include dari board package ESP32.

4. **Pilih Board**:
   ```
   Tools → Board → ESP32 Arduino → AI Thinker ESP32-CAM
   Tools → Partition Scheme → Huge APP (3MB No OTA / 1MB SPIFFS)
   Tools → Port → (pilih port COM/USB yang terdeteksi)
   ```

   > ⚠️ Pilih **Huge APP** partition karena firmware + kamera membutuhkan flash yang besar.

### Proses Flash

```
1. Pasang ESP32-CAM ke MB Programmer
2. Colok USB ke laptop
3. Buka firmware/esp32_entry_gate/esp32_entry_gate.ino
4. Edit konfigurasi:
   - WIFI_SSID → nama WiFi kamu
   - WIFI_PASSWORD → password WiFi
   - API_HOST → IP laptop/Raspberry Pi tanpa `http://` (lihat cara cari IP di bawah)
5. Klik Upload (→)
6. Jika gagal → tekan tombol IO0/BOOT pada ESP32-CAM, klik Upload, 
   lepaskan tombol setelah "Connecting..." muncul
7. Tunggu "Done uploading"
8. Tekan tombol RST untuk restart
9. Buka Serial Monitor (115200 baud)
10. Kirim huruf `h` di Serial Monitor untuk melihat command test
```

> ⚠️ Jangan isi `API_HOST` dengan `127.0.0.1` atau `localhost`. Untuk ESP32-CAM, alamat itu menunjuk ke ESP32-CAM sendiri, bukan ke laptop. Gunakan IP laptop pada WiFi yang sama, contoh `192.168.52.203`.

Command Serial yang tersedia di firmware:

| Command | Fungsi |
|---|---|
| `t` | Capture foto + upload manual ke API |
| `o` | Test buka servo/palang |
| `c` | Test tutup servo/palang |
| `d` | Baca jarak HC-SR04 sekali |
| `h` atau `?` | Tampilkan bantuan |

### Flash Gate Kedua

```
1. Buka firmware/esp32_exit_gate/esp32_exit_gate.ino
2. Edit konfigurasi yang sama (SSID, password, API host)
3. Upload ke ESP32-CAM kedua
```

### Cari IP Laptop

```bash
# macOS
ipconfig getifaddr en0

# Linux
hostname -I

# Windows
ipconfig | findstr IPv4
```

---

## 8. Menjalankan Sistem End-to-End

### Step 1: Jalankan API di Laptop

```bash
cd /Users/njul/Project/SmartPark

# Aktivasi virtual environment (jika ada)
source .venv/bin/activate

# Jalankan API
uvicorn api.main:app --reload --host 0.0.0.0 --port 8000
```

Pastikan API online:
```bash
curl http://localhost:8000/health
# Output: {"status":"ok","anpr_model_loaded":true,...}
```

### Step 2: Pastikan ESP32-CAM Terhubung WiFi

Buka Serial Monitor. Output yang diharapkan:

```
========================================
  SmartPark — Entry Gate Controller
  ESP32-CAM AI-Thinker
========================================

Initializing camera...
Camera OK — OV2640 ready
Connecting to WiFi...
Connected! IP: 192.168.1.xxx
Checking API... OK (v1.1.0)
Gate servo initialized (closed)
Waiting for vehicles...
```

### Step 3: Test Manual

Dari laptop, upload foto langsung ke API:

```bash
curl -X POST http://localhost:8000/device/process-image \
  -F "file=@foto test/plat_hitam.png" \
  -F "device_id=manual-test" \
  -F "gate_id=GATE-A-IN" \
  -F "gate_type=entry"
```

### Step 4: Test Full Flow dengan Hardware

```
1. Letakkan miniatur kendaraan / plat print di depan kamera ESP32-CAM
2. Dekatkan objek ke HC-SR04 (jarak < 30cm)
3. Serial Monitor menampilkan:

   >>> Vehicle detected at 15.3 cm
   Flash LED ON — capturing image...
   Image captured: 640x480 JPEG (23.4 KB)
   Flash LED OFF
   Uploading to API...
   HTTP 200 — 1847ms
   Action: OPEN_GATE
   Plate: B 1234 ABC
   Confidence: 0.92
   === GATE OPENING ===

4. Servo gate terbuka (90°)
5. LED onboard berkedip
6. Pindahkan objek melewati IR sensor (di belakang gate)
7. Serial Monitor menampilkan:

   IR sensor triggered — vehicle passed
   === GATE CLOSING ===

8. Servo gate tertutup (0°)
```

### Step 5: Buka IoT Gate Dashboard

Akses dashboard operator dari perangkat mana pun di WiFi yang sama:

```
http://<IP-LAPTOP>:8000/simulasi/iot-dashboard.html
```

> ⚠️ Pakai **IP LAN laptop**, bukan `localhost`, agar bisa dibuka dari HP/laptop lain
> dan agar `BASE` URL dashboard otomatis mengarah ke backend yang benar. Backend
> WAJIB dijalankan dengan `--host 0.0.0.0` (lihat Step 1).

Dashboard menampilkan: log kendaraan (plat, jam, confidence, keputusan), status
palang, statistik sesi, dan **live stream ESP32-CAM dengan bounding box + OCR**.

---

## 8b. Mode HYBRID — Live Stream + Bounding Box di Dashboard

ESP32-CAM (OV3660) berjalan dalam **3 jalur sekaligus** (firmware sudah mendukung):

```
①  LIVE STREAM   ESP32-CAM :81/stream ──MJPEG──> <img> di dashboard (feed langsung)
②  AUTO-REGISTER ESP32-CAM ──POST /device/register──> backend tahu IP + URL kamera
③  AUTO-SCAN     dashboard ──POST /device/scan?gate_id=──> backend tarik 1 frame
                 dari ESP32 :80/capture → ANPR+OCR → emit event (bbox)
                 → /device/events → box + OCR digambar di atas stream (~tiap 1.8s)
④  GATE TRIGGER  HC-SR04 → ESP32 capture → POST /device/process-image
                 → OPEN_GATE → servo buka → IR sensor → servo tutup
```

### Endpoint backend baru (sudah tersedia)

| Endpoint | Fungsi |
|---|---|
| `POST /device/register` | ESP32-CAM mendaftarkan IP + URL stream/capture saat boot |
| `GET /device/cameras` | Dashboard menemukan kamera yang sudah registrasi |
| `POST /device/scan?gate_id=GATE-A-IN` | Backend tarik 1 frame dari kamera → ANPR live |
| `GET /device/events?since=N` | Feed event (plat, keputusan, bbox) untuk dashboard |

### Langkah pakai

1. **Flash firmware** `esp32_entry_gate` & `esp32_exit_gate` (lihat Step 7). Pastikan
   `API_HOST` = IP laptop, dan WiFi benar. Firmware otomatis OV3660/OV2640.
2. **Nyalakan ESP32-CAM.** Di Serial Monitor akan muncul:
   ```
   Stream server started on port 81
   Live stream : http://192.168.1.50:81/stream
   Snapshot    : http://192.168.1.50/capture
   Register: HTTP/1.1 200 OK
   ```
3. **Cek stream langsung** (opsional): buka `http://192.168.1.50:81/stream` di browser.
4. **Di dashboard**, klik tombol **ESP32-CAM**. Dashboard otomatis menemukan kamera
   yang sudah registrasi (atau minta URL stream manual bila belum). Live feed muncul,
   dan bounding box + hasil OCR digambar di atasnya tiap ~1.8 detik.
5. **Trigger gate**: dekatkan kendaraan/plat ke HC-SR04 (<30cm) → ESP32 capture →
   palang terbuka bila plat terdaftar (DIIZINKAN), lalu IR menutup palang.

### Catatan performa (ESP32-CAM AI-Thinker)

- Mode hybrid memakai kamera untuk stream **dan** capture bersamaan → board bekerja
  keras. Default frame size **SVGA 800×600** (seimbang antara mulus & detail plat).
- Jika stream patah-patah: turunkan ke `FRAMESIZE_VGA` di `initCamera()`.
- Jika OCR kurang akurat: naikkan ke `FRAMESIZE_XGA`/`SXGA` (stream lebih berat).
- Auto-scan menarik frame tiap 1.8s; backend tidak menyimpan frame live (anti penuh disk).
- `processGatePipeline` di dashboard punya **dedup per-plat 8 detik** supaya scan
  kontinu tidak menagih/membuka sesi berulang untuk kendaraan yang sama.

---

## 9. Device Simulator (Tanpa Hardware)

Untuk testing tanpa ESP32-CAM fisik, gunakan simulator Python:

```bash
# Interactive mode (menu)
python scripts/device_simulator.py

# Upload foto langsung
python scripts/device_simulator.py --image "foto test/plat_hitam.png"

# Trigger sekali (simulasi sensor)
python scripts/device_simulator.py --once --gate GATE-A-IN --type entry

# Auto-trigger setiap 10 detik
python scripts/device_simulator.py --auto --interval 10
```

---

## 10. Troubleshooting Hardware

### ESP32-CAM Tidak Mau Di-flash

```
Masalah: "Failed to connect to ESP32"
Solusi:
1. Pastikan memakai ESP32-CAM-MB programmer
2. Tekan dan tahan tombol IO0/BOOT pada ESP32-CAM
3. Klik Upload di Arduino IDE
4. Lepaskan tombol setelah "Connecting..." muncul
5. Setelah upload selesai, tekan RST untuk restart
6. Ganti kabel USB jika masih gagal
```

### Kamera Gagal Initialize

```
Masalah: "Camera init failed with error 0x..."
Solusi:
1. Pastikan board dipilih "AI Thinker ESP32-CAM"
2. Pastikan partition scheme "Huge APP"
3. Cek kamera terpasang dengan benar (konektor ribbon)
4. Tekan konektor kamera dengan hati-hati
5. Restart ESP32-CAM
```

### Foto Terlalu Gelap

```
Masalah: Kamera capture terlalu gelap, plat tidak terlihat
Solusi:
1. Flash LED sudah menyala saat capture? Cek Serial Monitor
2. Arahkan kamera langsung ke plat nomor
3. Jarak ideal kamera ke plat: 15–50cm
4. Jika masih gelap, tambahkan LED putih eksternal:
   GPIO xx → R220Ω → LED putih → GND
```

### HC-SR04 Selalu Return 0 atau -1

```
Masalah: Sensor tidak membaca jarak
Solusi:
1. Pastikan VCC terhubung ke 5V, bukan 3.3V
2. Cek TRIG (GPIO 14) dan ECHO (GPIO 15) tidak tertukar
3. Pastikan tidak ada objek < 2cm dari sensor
4. Coba ganti sensor
```

### IR Sensor Tidak Merespons

```
Masalah: IR obstacle sensor tidak mendeteksi objek
Solusi:
1. Cek LED indikator pada sensor — menyala saat terhalang?
2. Putar potensiometer untuk atur sensitivitas
3. Pastikan OUT terhubung ke GPIO 2
4. Cek apakah sensor butuh 3.3V atau 5V (lihat datasheet)
```

### Servo Bergetar / Tidak Stabil

```
Masalah: Servo bergetar atau tidak bergerak
Solusi:
1. WAJIB pakai power supply 5V 2A — USB tidak cukup arus!
2. Servo butuh ~500mA, ESP32-CAM butuh ~300mA saat capture
3. Tambahkan kapasitor 100µF antara VCC dan GND servo
4. Pastikan GND servo sama dengan GND ESP32-CAM
```

### ESP32-CAM Restart Terus (Boot Loop)

```
Masalah: ESP32-CAM restart berulang kali
Solusi:
1. Jangan pakai GPIO 12! Jika HIGH saat boot → crash
2. Cek power supply cukup (5V 2A minimum)
3. Pastikan tidak ada short circuit
4. Flash ulang firmware
```

### WiFi Sering Putus

```
Masalah: Koneksi WiFi tidak stabil
Solusi:
1. Gunakan WiFi 2.4GHz (ESP32 tidak support 5GHz)
2. Dekatkan ESP32-CAM ke router
3. Firmware sudah include auto-reconnect
4. Antena ESP32-CAM kecil — pastikan tidak terhalang metal
```

---

## 11. Transisi ke Raspberry Pi (Produksi)

```
Mode Development (sekarang)       →    Mode Production (nanti)
─────────────────────────          ─────────────────────────
Laptop = Brain (ANPR + OCR)       Raspberry Pi = Brain (ANPR + OCR)
ESP32-CAM = Kamera + Controller   ESP32-CAM = Kamera + Controller
WiFi = ESP32-CAM → Laptop         WiFi = ESP32-CAM → RPi
API jalan di laptop               API jalan di Docker di RPi
```

### Yang Berubah

| Komponen | Development | Production |
|---|---|---|
| **Brain** | Laptop/Mac | Raspberry Pi 5 |
| **API** | `uvicorn` langsung | Docker container |
| **Network** | WiFi → Laptop | WiFi → RPi (atau Ethernet) |
| **Power** | USB + PSU 5V 2A | PSU 5V 3A (RPi) + PSU 5V 2A (ESP32-CAM) |

### Yang TIDAK Berubah

- ✅ ESP32-CAM firmware (hanya ubah `API_HOST` ke IP Raspberry Pi)
- ✅ API endpoints dan response format
- ✅ Wiring semua sensor, servo, kamera
- ✅ Alur sistem (sensor → capture → upload → API → gate)
- ✅ IR sensor auto-close gate

Lihat juga: [RASPBERRY_PI_SETUP.md](./RASPBERRY_PI_SETUP.md) untuk deployment di Raspberry Pi.

---

> 📝 **Catatan**: Panduan ini menggunakan **ESP32-CAM AI-Thinker** sebagai kamera + controller, dan **laptop/Mac sebagai Brain** yang menjalankan SmartPark API. Migrasi ke Raspberry Pi hanya membutuhkan perubahan `API_HOST` di firmware.
