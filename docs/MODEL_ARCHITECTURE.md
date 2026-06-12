# Bagian Pemodelan
## Sistem Parkir Cerdas Berbasis Computer Vision

---

## 1. Arsitektur Model

### 1.1 Gambaran Umum Pipeline

Sistem parkir cerdas yang dikembangkan menggunakan arsitektur pipeline multi-tahap yang memproses citra masukan dari kamera gerbang parkir hingga menghasilkan keputusan akses:

```
Citra Input → Deteksi Plat (YOLO) → OCR Plat Nomor → Ekstraksi Fitur Visual → Skoring & Keputusan
```

### 1.2 Modul Deteksi (YOLO)

Modul pertama menggunakan model berbasis YOLO (*You Only Look Once*) untuk mendeteksi keberadaan plat nomor kendaraan pada citra. YOLO dipilih berdasarkan pertimbangan teknis berikut:

- **Efisiensi inferensi**: YOLO merupakan detektor *single-stage* yang melakukan prediksi *bounding box* dan klasifikasi dalam satu *forward pass*, berbeda dengan detektor *two-stage* seperti Faster R-CNN yang memerlukan *region proposal* terpisah.
- **Kesesuaian untuk *real-time***: Latensi inferensi YOLO pada resolusi standar (640×640) berada pada orde milidetik, memenuhi kebutuhan respons waktu-nyata di gerbang parkir.
- **Trade-off akurasi vs. kecepatan**: Model YOLO varian kecil (misalnya YOLOv8n atau YOLOv8s) mengorbankan sebagian akurasi deteksi pada objek berukuran kecil demi kecepatan inferensi yang lebih tinggi. Pada konteks deteksi plat nomor — di mana objek target relatif kecil dalam *frame* — pemilihan varian model menjadi pertimbangan kritis.

Model menerima citra RGB sebagai input dan menghasilkan *bounding box* beserta *confidence score* untuk setiap plat nomor yang terdeteksi.

### 1.3 Modul OCR

Setelah *bounding box* plat nomor diperoleh, area plat di-*crop* dan diteruskan ke modul OCR (*Optical Character Recognition*) untuk mengekstraksi teks karakter pada plat. Modul ini berfungsi sebagai penghubung antara deteksi visual dan verifikasi identitas kendaraan terhadap basis data. Akurasi OCR sangat dipengaruhi oleh kualitas hasil *cropping*, resolusi area plat, serta kondisi pencahayaan.

### 1.4 Modul Ekstraksi Fitur Visual

Modul ini mengekstraksi fitur tambahan dari citra kendaraan secara keseluruhan:
- **Warna kendaraan** — klasifikasi kasar (*coarse classification*)
- **Tipe kendaraan** — klasifikasi kasar (mobil, motor, truk, dsb.)

Fitur-fitur ini berfungsi sebagai sinyal pendukung dalam mekanisme verifikasi multi-faktor.

### 1.5 Modul Skoring dan Keputusan

Modul akhir mengintegrasikan seluruh sinyal dari modul sebelumnya melalui sistem *confidence scoring* berbobot untuk menghasilkan keputusan akses gerbang. Detail mekanisme ini disajikan pada Subbagian 5.

---

## 2. Persiapan Data

### 2.1 Pembagian Dataset

Dataset yang digunakan adalah dataset plat nomor kendaraan Indonesia dengan pembagian sebagai berikut:

| Split       | Jumlah Citra | Proporsi |
|-------------|:------------:|:--------:|
| Training    | 800          | 80%      |
| Validation  | 100          | 10%      |
| Test        | 100          | 10%      |

Pembagian 80/10/10 mengikuti konvensi umum dalam *deep learning* untuk dataset berukuran terbatas. Set validasi digunakan untuk pemantauan *overfitting* selama pelatihan, sedangkan set tes disisihkan untuk evaluasi akhir yang objektif.

### 2.2 Format Anotasi

Anotasi menggunakan format standar YOLO, di mana setiap citra memiliki file `.txt` berpasangan dengan format:

```
<class_id> <x_center> <y_center> <width> <height>
```

Seluruh koordinat dinormalisasi terhadap dimensi citra (rentang [0, 1]). Dataset ini menggunakan satu kelas (`class_id = 0`) yang merepresentasikan plat nomor kendaraan. Beberapa citra memiliki lebih dari satu anotasi, mengindikasikan keberadaan multiple plat nomor dalam satu *frame*.

Contoh anotasi aktual dari dataset:

```
0 0.590774 0.714782 0.104167 0.034722
```

Baris di atas menunjukkan plat nomor dengan pusat pada (59.08%, 71.48%) dari dimensi citra, dengan lebar 10.42% dan tinggi 3.47% — konsisten dengan proporsi geometris plat nomor standar Indonesia yang bersifat horizontal dan berukuran relatif kecil terhadap keseluruhan citra.

### 2.3 Preprocessing

Tahapan *preprocessing* standar yang diterapkan:

1. **Resizing**: Citra di-*resize* ke resolusi tetap (umumnya 640×640 piksel untuk YOLO) dengan *letterboxing*.
2. **Normalisasi**: Nilai piksel dinormalisasi ke rentang [0, 1] melalui pembagian dengan 255.
3. **Konversi format warna**: Konversi dari BGR (OpenCV) ke RGB sesuai kebutuhan model.

### 2.4 Augmentasi Data

Mengingat ukuran dataset yang terbatas (800 citra pelatihan), teknik augmentasi yang lazim diterapkan:

- *Random horizontal flip*
- Variasi *brightness*, *contrast*, dan *saturation*
- *Mosaic augmentation* (penggabungan 4 citra — teknik bawaan YOLO)
- *Random scaling* dan *translation*

> **Catatan**: Teknik augmentasi spesifik yang diterapkan akan diintegrasikan setelah hasil pelatihan tersedia.

---

## 3. Strategi Pelatihan

### 3.1 Pendekatan Transfer Learning

Pelatihan dilakukan menggunakan *transfer learning*. Model YOLO yang telah dilatih pada dataset berskala besar (misalnya COCO, ~330.000 citra, 80 kelas) digunakan sebagai *pretrained backbone*. *Weight* awal dari *backbone* dipertahankan, sementara *head* deteksi di-*fine-tune* pada dataset plat nomor Indonesia.

Justifikasi:

1. **Keterbatasan data**: Dengan 800 citra, pelatihan *from scratch* akan menghasilkan *overfitting* parah karena jumlah parameter model jauh melebihi jumlah sampel.
2. **Pemanfaatan representasi visual umum**: *Pretrained backbone* telah mempelajari fitur visual fundamental yang bersifat *domain-agnostic*.
3. **Konvergensi lebih cepat**: Model mencapai performa baik dalam epoch yang lebih sedikit.

### 3.2 Konfigurasi Pelatihan

Pelatihan dilaksanakan pada lingkungan Kaggle (GPU NVIDIA Tesla P100 atau T4):

| Parameter     | Nilai Umum                         |
|---------------|:----------------------------------:|
| Epoch         | 50–100                             |
| Batch size    | 16                                 |
| Image size    | 640×640                            |
| Optimizer     | SGD atau AdamW                     |
| Learning rate | 0.01 (awal), *cosine decay*        |

> **Catatan**: Hiperparameter aktual akan diperbarui setelah pelatihan selesai.

### 3.3 Risiko Overfitting

Strategi mitigasi:

- **Early stopping**: Pelatihan dihentikan saat metrik validasi stagnan.
- **Augmentasi data**: Memperluas variasi data secara artifisial.
- **Regularisasi implisit**: *Pretrained weights* membatasi model agar tidak menyimpang terlalu jauh.
- **Pemantauan *loss* validasi**: Divergensi *training loss* vs. *validation loss* dipantau sebagai indikator.

---

## 4. Peningkatan Fitur (Verifikasi Multi-Sinyal)

### 4.1 Keterbatasan Deteksi Plat Tunggal

Mengandalkan plat nomor sebagai satu-satunya mekanisme identifikasi memiliki keterbatasan:

- Plat nomor dapat tertutup sebagian (*occlusion*).
- Pencahayaan buruk menurunkan akurasi OCR secara drastis.
- Plat nomor palsu tidak dapat dideteksi hanya dari pengenalan karakter.

### 4.2 Fitur Pendukung Tambahan

#### a. Warna Kendaraan (Klasifikasi Kasar)
Klasifikasi warna (hitam, putih, merah, biru, silver) berdasarkan analisis histogram warna atau model klasifikasi ringan. Berfungsi sebagai sinyal verifikasi silang terhadap data terdaftar.

#### b. Tipe Kendaraan (Klasifikasi Kasar)
Klasifikasi tipe (mobil, motor, truk, bus) menggunakan fitur visual keseluruhan kendaraan. Konsistensi dengan data registrasi menambah *confidence* identifikasi.

### 4.3 Peran sebagai Sinyal Pendukung

Kedua fitur diposisikan sebagai **sinyal pendukung**, bukan primer:

1. Klasifikasi kasar memiliki akurasi lebih rendah dibandingkan pengenalan plat.
2. Warna dan tipe bersifat non-unik.
3. Fungsi utamanya: **menurunkan *false positive rate*** saat OCR ambigu.

---

## 5. Mekanisme Keputusan

### 5.1 Sistem Confidence Scoring

Keputusan akses gerbang ditentukan melalui *confidence scoring* berbobot:

```
S = (C_plat × w₁) + (C_warna × w₂) + (C_tipe × w₃)
```

di mana:
- C_plat = skor kepercayaan pengenalan plat nomor (0–1)
- C_warna = skor kesesuaian warna kendaraan (0–1)
- C_tipe = skor kesesuaian tipe kendaraan (0–1)
- w₁ + w₂ + w₃ = 1

Distribusi bobot berdasarkan reliabilitas sinyal:

| Sinyal       | Bobot (w) | Justifikasi                           |
|--------------|:---------:|---------------------------------------|
| Plat nomor   | 0.70      | Identifikator unik paling reliabel    |
| Warna        | 0.15      | Sinyal pendukung, non-unik            |
| Tipe         | 0.15      | Sinyal pendukung, non-unik            |

> Nilai bobot bersifat konfigurabel dan dapat dioptimasi melalui eksperimen empiris.

### 5.2 Keputusan Berbasis Threshold

| Rentang Skor     | Keputusan            | Tindakan Sistem                                   |
|:----------------:|:--------------------:|----------------------------------------------------|
| S ≥ 0.85         | **High confidence**  | Gerbang terbuka otomatis                           |
| 0.60 ≤ S < 0.85  | **Medium confidence**| Gerbang terbuka dengan pencatatan log untuk review |
| S < 0.60         | **Low confidence**   | Mekanisme *fallback* (verifikasi manual/petugas)   |

### 5.3 Penekanan pada Robustness

Desain mengutamakan **robustness** di atas akurasi sempurna:

- Ambang *medium confidence* memungkinkan akses meski identifikasi tidak sempurna, menghindari *false rejection* berlebihan.
- Pencatatan log pada keputusan *medium* untuk audit dan peningkatan iteratif.
- Mekanisme *fallback* menjamin kontinuitas layanan pada kondisi kegagalan.

---

## 6. Pendekatan Evaluasi

### 6.1 Penggunaan Set Validasi dan Tes

1. **Validasi (100 citra)**: Pemantauan performa dan pemilihan *checkpoint* terbaik selama pelatihan.
2. **Tes (100 citra)**: Evaluasi akhir objektif, tidak digunakan selama pelatihan.

### 6.2 Metrik Evaluasi

| Metrik            | Definisi                                                                 |
|-------------------|--------------------------------------------------------------------------|
| **mAP@0.5**       | *Mean Average Precision* pada IoU threshold 0.5                         |
| **mAP@0.5:0.95**  | mAP rata-rata pada rentang IoU 0.5–0.95 (metrik lebih ketat)            |
| **Precision**     | Proporsi deteksi positif yang benar terhadap seluruh deteksi positif     |
| **Recall**        | Proporsi objek sebenarnya yang berhasil terdeteksi                       |

### 6.3 Kebutuhan Data Tes Berlabel

Data tes dengan anotasi *ground truth* merupakan kebutuhan mutlak untuk evaluasi objektif. Dataset yang digunakan telah menyediakan anotasi format YOLO untuk seluruh split, sehingga evaluasi kuantitatif dapat dilaksanakan secara penuh.

---

## 7. Keterbatasan

1. **Ukuran dataset terbatas**: 800 citra pelatihan belum sepenuhnya merepresentasikan variasi plat nomor Indonesia (beragam format berdasarkan wilayah, jenis kendaraan, tahun pembuatan).

2. **Sensitivitas lingkungan**: Performa dipengaruhi oleh pencahayaan (malam, *glare*, *backlight*), oklusi parsial, dan sudut kamera tidak ideal.

3. **Ketidakakuratan OCR**: Karakter dengan kemiripan visual tinggi ("D"/"0", "I"/"1") serta kondisi plat aus menurunkan akurasi pengenalan.

4. **Kendala komputasi *real-time***: Deployment pada perangkat *edge* (Raspberry Pi) memerlukan optimisasi tambahan yang berpotensi menurunkan akurasi.

---

## 8. Pengembangan ke Depan

1. **Ekspansi dataset**: Pengumpulan data plat nomor Indonesia yang lebih beragam. Target minimal 5.000–10.000 citra.

2. **Fine-tuning model**: Eksplorasi arsitektur YOLO terbaru (YOLOv8, YOLOv9, YOLOv11) serta model OCR yang di-*fine-tune* untuk karakter plat Indonesia.

3. **Optimisasi *edge deployment***: Kuantisasi *post-training* (INT8), *knowledge distillation*, konversi ke format efisien (ONNX, TensorRT, TFLite). Target latensi di bawah 200ms per *frame* pada Raspberry Pi.

4. **Peningkatan fusi multi-sinyal**: Eksplorasi *learned fusion weights*, pendekatan *Bayesian*, dan adaptasi bobot dinamis berdasarkan kualitas citra.

---

> **Catatan akhir**: Seluruh penjelasan didasarkan pada desain sistem dan data yang tersedia. Hasil eksperimental (metrik mAP, precision, recall, serta hiperparameter aktual) akan diintegrasikan setelah pelatihan dan evaluasi selesai.
