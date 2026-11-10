# Hasil latih model intent

## Data

- Data latih: 613 kalimat (setelah duplikat dibuang).
- Per sumber: massive 238, synthetic 375.
- Per intent: `cari_resep` 116, `pakai_kulkas` 54, `info_resep` 51, `substitusi_bahan` 53, `bantuan` 60, `di_luar_topik` 279.
- Data uji (ditulis tim, tidak dipakai saat latih): 0 kalimat.

## Model

- Fitur: kata, pasangan kata, dan potongan 3-5 huruf per kata, dibobot TF-IDF.
- Algoritma: Logistic Regression (multinomial, `class_weight=balanced`).
- C terpilih: 3 (dari [1, 3, 10, 30, 100]; C terkecil yang skornya paling jauh 0.01 di bawah skor terbaik).
- Ambang keyakinan: 0.25. Di bawah ambang, aplikasi meminta pengguna memperjelas pertanyaan.
- Jumlah fitur: 4898.

## Validasi silang 5-fold (data latih)

Prediksi di bawah ambang dihitung sebagai `di_luar_topik`.

| Metode | Akurasi | Macro F1 |
|---|---|---|
| Model | 0.920 | 0.911 |
| Baseline kata kunci | 0.832 | 0.787 |

### Model per intent

| Intent | Precision | Recall | F1 | Jumlah |
|---|---|---|---|---|
| `cari_resep` | 0.89 | 0.90 | 0.89 | 116 |
| `pakai_kulkas` | 0.92 | 0.91 | 0.92 | 54 |
| `info_resep` | 0.86 | 0.94 | 0.90 | 51 |
| `substitusi_bahan` | 0.92 | 0.92 | 0.92 | 53 |
| `bantuan` | 0.94 | 0.85 | 0.89 | 60 |
| `di_luar_topik` | 0.94 | 0.94 | 0.94 | 279 |

### Baseline per intent

| Intent | Precision | Recall | F1 | Jumlah |
|---|---|---|---|---|
| `cari_resep` | 0.87 | 0.91 | 0.89 | 116 |
| `pakai_kulkas` | 0.96 | 0.80 | 0.87 | 54 |
| `info_resep` | 0.62 | 0.65 | 0.63 | 51 |
| `substitusi_bahan` | 1.00 | 0.83 | 0.91 | 53 |
| `bantuan` | 0.92 | 0.40 | 0.56 | 60 |
| `di_luar_topik` | 0.80 | 0.93 | 0.86 | 279 |

### Confusion matrix model

| Asli \ Tebakan | cari | kulkas | info | subst | bantuan | luar |
|---|---|---|---|---|---|---|
| `cari_resep` | 104 | 4 | 3 | 2 | 0 | 3 |
| `pakai_kulkas` | 3 | 49 | 0 | 1 | 0 | 1 |
| `info_resep` | 2 | 0 | 48 | 0 | 0 | 1 |
| `substitusi_bahan` | 1 | 0 | 0 | 49 | 0 | 3 |
| `bantuan` | 0 | 0 | 0 | 0 | 51 | 9 |
| `di_luar_topik` | 7 | 0 | 5 | 1 | 3 | 263 |

Catatan: data latih memuat banyak kalimat yang mirip satu sama lain, jadi angka validasi silang
cenderung lebih tinggi daripada pemakaian nyata. Angka yang jujur adalah hasil data uji di bawah.

## Data uji

Belum ada data uji.
