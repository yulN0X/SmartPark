# Rencana Perbaikan SmartPark

_Disusun: 9 Juni 2026 · Berdasarkan audit kode backend, app Flutter, dan struktur repo._

Rencana ini dibagi menjadi **5 fase**, diurut dari risiko paling tinggi ke paling rendah.
Kerjakan **Fase 0 lebih dulu sampai tuntas** sebelum menyentuh kode lain — fase ini melindungi
pekerjaanmu dan mencegah kebocoran rahasia.

Legenda effort: 🟢 cepat (<1 jam) · 🟡 sedang (beberapa jam) · 🔴 besar (1 hari+)

---

## Fase 0 — Pengamanan Dasar (lakukan HARI INI)

> Tujuan: project punya version control dan tidak ada rahasia yang bisa bocor.

- [ ] **Inisialisasi Git** 🟢
  - `git init` di root `SmartPark/`, lalu commit pertama.
  - Acceptance: `git log` menampilkan commit awal.
- [ ] **Buat `.gitignore` SEBELUM commit pertama** 🟢
  - Abaikan: `.env`, `*.env`, `venv/`, `.venv/`, `__pycache__/`, `*.pyc`,
    `parkirboss.db`, `*.zip`, `models/*.pt`, `models/*.onnx`, `models/best_saved_model/`,
    `.DS_Store`, `build/`, `ParkirBoss/parkirboss-app/build/`, `runs/`.
  - Acceptance: `git status` TIDAK menampilkan `.env`, `venv/`, atau file zip.
- [ ] **Keluarkan rahasia dari repo** 🟢
  - Pastikan `ParkirBoss/.env` dan `ParkirBoss/parkirboss-api/.env` tidak ter-track.
  - Buat `.env.example` (tanpa nilai asli) sebagai template untuk dokumentasi.
  - Acceptance: ada `.env.example`, `.env` asli hanya di lokal.
- [ ] **Hapus artefak besar dari tracking** 🟢
  - `models.zip` (44MB), `api.zip`, `yolov8n.pt` → jangan di-commit. Model sudah ada di Hugging Face.
  - Opsional: pasang **Git LFS** kalau bobot model memang harus ikut repo.

---

## Fase 1 — Keamanan & Konfigurasi

> Tujuan: tidak ada kredensial hardcoded, dan app bisa jalan di jaringan mana pun.

- [ ] **Pindahkan `SECRET_KEY` JWT ke environment** 🟢 — _Kritis_
  - File: `ParkirBoss/parkirboss-api/core/config.py`.
  - Hapus default `"supersecretkey_parkirboss2026"`. Wajib dibaca dari env;
    kalau kosong, aplikasi gagal start (fail-fast), bukan pakai default.
  - Generate kunci baru: `python -c "import secrets; print(secrets.token_urlsafe(64))"`.
  - Acceptance: app menolak start tanpa `SECRET_KEY` di env; tidak ada kunci di kode.
- [ ] **Perketat CORS** 🟢
  - File: `api/main.py` dan `ParkirBoss/parkirboss-api/main.py`.
  - Ganti `allow_origins=["*"]` (yang dipasangkan dengan `allow_credentials=True`)
    menjadi daftar origin eksplisit dari env (mis. `ALLOWED_ORIGINS`).
  - Acceptance: origin produksi di-whitelist; wildcard hanya untuk mode dev lokal.
- [ ] **Satukan & buat configurable base URL di Flutter** 🟡
  - File: `lib/core/network/api_client.dart` (hardcode IP LAN `10.161.143.249:8080`)
    dan `lib/core/constants/app_constants.dart` (`localhost:8000`) — keduanya bentrok.
  - Pakai SATU sumber, di-inject lewat `--dart-define` (mis. `API_BASE_URL`).
    Perbaiki komentar yang menyesatkan dan samakan port.
  - Acceptance: ganti server tanpa edit kode; tidak ada IP pribadi di sumber.
- [ ] **Simpan token di storage aman** 🟡
  - Ganti `SharedPreferences` untuk `access_token` dengan `flutter_secure_storage`
    (Keychain/Keystore). File: `lib/core/network/api_client.dart` + service auth.
  - Acceptance: token tidak lagi tersimpan plaintext.

---

## Fase 2 — Konsolidasi Arsitektur & Kebersihan Repo

> Tujuan: satu sumber kebenaran yang jelas, repo ringan.

- [ ] **Putuskan peran dua backend** 🟡 — _penting_
  - Saat ini `api/` (ANPR/OCR) dan `ParkirBoss/parkirboss-api/` (auth/wallet/gate)
    sama-sama punya logika gate. Tentukan: satukan, atau pisahkan tegas
    (mis. `api/` = ML service, `parkirboss-api/` = app/business service yang memanggilnya).
  - Tulis keputusan ini di README sebagai diagram arsitektur.
  - Acceptance: dokumen menjelaskan backend mana milik siapa, tanpa duplikasi logika.
- [ ] **Keluarkan `venv/` dari `ParkirBoss/parkirboss-api/`** 🟢
  - Hapus dari folder, andalkan `requirements.txt`. (Sudah di-ignore di Fase 0.)
- [ ] **Bersihkan file sampah** 🟢
  - Hapus semua `.DS_Store`, file kosong (`code-penting.txt`), dan duplikat `models/`.
- [ ] **Pisahkan dependency dev vs runtime** 🟢
  - Sudah ada `requirements-runtime.txt` (bagus). Pastikan `requirements.txt`
    di-pin dan tidak membawa dependensi berat yang tak perlu ke edge device.

---

## Fase 3 — Kualitas Kode & Testing

> Tujuan: logika keputusan akses terverifikasi otomatis dan tidak diam-diam rusak.

- [ ] **Unit test untuk logika inti** 🟡 — _prioritas tinggi_
  - Target utama: `api/engine/plate.py::parse_indonesian_plate()` (plat standar,
    militer, diplomatik CD, sementara, perbaikan OCR) dan
    `api/engine/vehicle.py::compute_access_decision()` (threshold & bobot skor).
  - Pakai `pytest`. Mulai dari ~15–20 kasus uji.
  - Acceptance: `pytest` hijau; cabang utama plate/scoring tercakup.
- [ ] **Test endpoint API** 🟡
  - Pakai `fastapi.testclient` untuk `/health`, `/pipeline/verify` (gambar valid &
    invalid, file kebesaran), dan jalur auth.
- [ ] **Ganti `print()` dengan modul `logging`** 🟢
  - Di `api/main.py`, `parkirboss-api/main.py`, dll. Level configurable lewat env.
- [ ] **Perbaiki blocking I/O di route async** 🟡
  - `cv2.imread`, `VideoCapture`, dan `_fetch_jpeg()` dipanggil langsung di
    `async def` (`api/routers/device.py`) → memblokir event loop.
  - Bungkus dengan `run_in_executor` / `anyio.to_thread`.
- [ ] **Tambahkan linter & formatter** 🟢
  - Python: `ruff` + `black`. Dart: `flutter analyze` + `dart format`.

---

## Fase 4 — Dokumentasi, CI & Polish

> Tujuan: orang lain (dan kamu di masa depan) bisa langsung paham dan menjalankan.

- [ ] **Perbaiki README** 🟢
  - Koreksi "Mobile App: SwiftUI (iOS)" → **Flutter**.
  - Tambah bagian "Cara setup `.env`" dan diagram dua-backend dari Fase 2.
- [ ] **Tambahkan CI sederhana (GitHub Actions)** 🟡
  - Jalankan `pytest` + `ruff` untuk backend dan `flutter analyze` saat push/PR.
  - Acceptance: badge CI hijau di README.
- [ ] **Ganti aset eksternal rapuh** 🟢
  - Gambar onboarding di `onboarding_screen.dart` menunjuk URL `googleusercontent.com`
    yang bisa mati kapan saja → pindahkan ke aset lokal `assets/`.
- [ ] **Tinjau node terisolasi dari graphify** 🟢
  - ~287 node lepas (script training/validasi). Pastikan masih relevan atau arsipkan.

---

## Urutan eksekusi yang disarankan

```
Fase 0 (hari 1)  →  Fase 1 (hari 1–2)  →  Fase 2 (hari 3)
        →  Fase 3 (hari 4–5)  →  Fase 4 (hari 6)
```

**Quick win paling berdampak (bisa langsung dikerjakan):**
`git init` + `.gitignore` → pindahkan `SECRET_KEY` ke env → satukan base URL Flutter →
tulis unit test `parse_indonesian_plate()`.

---

## Definisi "Selesai" untuk keseluruhan

1. Repo ber-Git, tanpa rahasia/venv/zip ter-track.
2. Tidak ada kredensial hardcoded; CORS dibatasi.
3. App Flutter jalan di jaringan lain tanpa edit kode.
4. `pytest` hijau menutupi logika plat & scoring.
5. README akurat + CI berjalan otomatis.