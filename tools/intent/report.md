# Hasil latih model intent

## Data

- Data latih: 726 kalimat (setelah duplikat dibuang).
- Per sumber: massive 238, synthetic 488.
- Per intent: `cari_resep` 149, `pakai_kulkas` 54, `info_resep` 51, `substitusi_bahan` 53, `daftar_belanja` 40, `rencana_menu` 40, `bantuan` 60, `di_luar_topik` 279.
- Data uji (ditulis tim, tidak dipakai saat latih): 0 kalimat.

## Model

- Fitur: kata, pasangan kata, dan potongan 3-5 huruf per kata, dibobot TF-IDF.
- Algoritma: Logistic Regression (multinomial, `class_weight=balanced`).
- C terpilih: 10 (dari [1, 3, 10, 30, 100]; C terkecil yang skornya paling jauh 0.01 di bawah skor terbaik).
- Ambang keyakinan: 0.35. Di bawah ambang, aplikasi meminta pengguna memperjelas pertanyaan.
- Jumlah fitur: 5326.

## Validasi silang 5-fold (data latih)

Prediksi di bawah ambang dihitung sebagai `di_luar_topik`.

| Metode | Akurasi | Macro F1 |
|---|---|---|
| Model | 0.888 | 0.876 |
| Baseline kata kunci | 0.798 | 0.758 |

### Model per intent

| Intent | Precision | Recall | F1 | Jumlah |
|---|---|---|---|---|
| `cari_resep` | 0.91 | 0.83 | 0.87 | 149 |
| `pakai_kulkas` | 0.92 | 0.89 | 0.91 | 54 |
| `info_resep` | 0.88 | 0.88 | 0.88 | 51 |
| `substitusi_bahan` | 0.92 | 0.83 | 0.87 | 53 |
| `daftar_belanja` | 0.86 | 0.75 | 0.80 | 40 |
| `rencana_menu` | 0.86 | 0.90 | 0.88 | 40 |
| `bantuan` | 0.94 | 0.83 | 0.88 | 60 |
| `di_luar_topik` | 0.87 | 0.96 | 0.91 | 279 |

### Baseline per intent

| Intent | Precision | Recall | F1 | Jumlah |
|---|---|---|---|---|
| `cari_resep` | 0.79 | 0.87 | 0.82 | 149 |
| `pakai_kulkas` | 0.90 | 0.80 | 0.84 | 54 |
| `info_resep` | 0.62 | 0.65 | 0.63 | 51 |
| `substitusi_bahan` | 0.98 | 0.83 | 0.90 | 53 |
| `daftar_belanja` | 0.93 | 0.68 | 0.78 | 40 |
| `rencana_menu` | 0.92 | 0.55 | 0.69 | 40 |
| `bantuan` | 0.92 | 0.40 | 0.56 | 60 |
| `di_luar_topik` | 0.76 | 0.92 | 0.83 | 279 |

### Confusion matrix model

| Asli \ Tebakan | cari | kulkas | info | subst | belanja | menu | bantuan | luar |
|---|---|---|---|---|---|---|---|---|
| `cari_resep` | 124 | 1 | 2 | 3 | 0 | 3 | 1 | 15 |
| `pakai_kulkas` | 3 | 48 | 0 | 0 | 1 | 0 | 0 | 2 |
| `info_resep` | 2 | 0 | 45 | 0 | 1 | 0 | 0 | 3 |
| `substitusi_bahan` | 0 | 0 | 1 | 44 | 0 | 0 | 0 | 8 |
| `daftar_belanja` | 2 | 2 | 2 | 0 | 30 | 2 | 0 | 2 |
| `rencana_menu` | 1 | 1 | 0 | 0 | 0 | 36 | 1 | 1 |
| `bantuan` | 0 | 0 | 0 | 0 | 0 | 0 | 50 | 10 |
| `di_luar_topik` | 4 | 0 | 1 | 1 | 3 | 1 | 1 | 268 |

Catatan: data latih memuat banyak kalimat yang mirip satu sama lain, jadi angka validasi silang
cenderung lebih tinggi daripada pemakaian nyata. Angka yang jujur adalah hasil data uji di bawah.

## Data uji

Belum ada data uji.
