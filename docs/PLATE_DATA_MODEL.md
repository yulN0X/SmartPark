# Model Data Plat Nomor

SmartPark menyimpan plat sebagai komponen terpisah sekaligus sebagai nilai
kanonik. Pemisahan komponen membantu lookup database, sedangkan nilai kanonik
mencegah hasil pencarian ambigu.

## Format Response OCR

Contoh hasil OCR:

```json
{
  "plate_text": "B 1308 RFO",
  "plate": {
    "raw_text": "B1308RFO",
    "normalized_plate": "B 1308 RFO",
    "prefix_letters": "B",
    "middle_numbers": "1308",
    "suffix_letters": "RFO",
    "plate_type": "standard",
    "is_valid": true
  }
}
```

`plate_text` dipertahankan untuk kompatibilitas client. Untuk kode baru, pakai
objek `plate`.

## Struktur Database Kendaraan

Rekomendasi kolom pada tabel `vehicles`:

```sql
CREATE TABLE vehicles (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id),
  plate_prefix VARCHAR(2) NOT NULL,
  plate_number VARCHAR(5) NOT NULL,
  plate_suffix VARCHAR(3) NOT NULL DEFAULT '',
  plate_normalized VARCHAR(16) NOT NULL UNIQUE,
  plate_type VARCHAR(16) NOT NULL DEFAULT 'standard',
  color VARCHAR(32),
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_vehicles_plate_components
  ON vehicles (plate_prefix, plate_number, plate_suffix);
```

Contoh data:

| plate_prefix | plate_number | plate_suffix | plate_normalized |
|---|---|---|---|
| `B` | `1308` | `RFO` | `B 1308 RFO` |
| `AB` | `1377` | `MY` | `AB 1377 MY` |

## Urutan Verifikasi

1. Jalankan YOLO untuk mendapatkan crop plat.
2. Jalankan FastPlateOCR pada crop.
3. Normalisasi hasil OCR ke objek `plate`.
4. Tolak lookup otomatis jika `plate.is_valid == false`.
5. Cari exact match berdasarkan `plate_normalized`.
6. Jika exact match tidak ditemukan, cari kandidat berdasarkan komponen untuk
   mode review/manual.

Contoh lookup exact:

```sql
SELECT *
FROM vehicles
WHERE plate_normalized = 'B 1308 RFO'
  AND is_active = TRUE;
```

## Aturan Keamanan

Fuzzy matching berguna untuk menampilkan kandidat ketika OCR tertukar karakter
seperti `O/0`, `B/8`, atau `G/6`. Namun fuzzy match tidak boleh langsung membuka
gate, terutama pada gate keluar. Gunakan hasil fuzzy sebagai:

- saran koreksi pada operator,
- kandidat untuk foto ulang,
- dasar manual review,
- data evaluasi untuk fine-tuning OCR.

Gate otomatis hanya boleh terbuka setelah exact match pada nilai kanonik atau
setelah verifikasi tambahan yang eksplisit.

## Konfigurasi OCR

Default runtime memakai model XS agar ringan di Raspberry Pi 5:

```text
SMARTPARK_OCR_MODEL=cct-xs-v2-global-model
SMARTPARK_OCR_DEVICE=cpu
```

Untuk model hasil fine-tuning sendiri:

```text
SMARTPARK_OCR_MODEL_PATH=/app/models/custom_ocr.onnx
SMARTPARK_OCR_CONFIG_PATH=/app/models/custom_ocr_plate_config.yaml
```

Dockerfile mengunduh dan menyimpan model default ketika image dibangun. Device
target cukup menarik Docker image dan tidak perlu mengunduh model OCR saat
container pertama dinyalakan.
