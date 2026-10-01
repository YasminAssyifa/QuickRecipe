# Panduan demo dan video (target 9 menit)

Gunakan emulator/perangkat Android dengan internet. Daftarkan akun demonstrasi menggunakan Sign Up, lalu login. Hindari menampilkan password, token, pengaturan akun Google, atau data pribadi saat merekam.

| Waktu | Demonstrasi |
|---|---|
| 00:00–00:45 | Tujuan aplikasi dan persona mahasiswa kos |
| 00:45–02:30 | Alur 1: login, cari resep, detail, porsi, langkah memasak dan selesai |
| 02:30–04:45 | Alur 2: Fridge kosong, validasi input kosong, tambah bahan, edit, cari resep, hapus/batal |
| 04:45–06:15 | Alur 3: buat koleksi, pilih resep, edit isi/nama, hapus tanpa menghapus katalog |
| 06:15–07:15 | Menu tiga titik Fridge: Demo failed loading → indikator → Try again; Demo empty → Exit demo |
| 07:15–07:50 | Tombol logo AI, contoh pertanyaan, status pratinjau |
| 07:50–09:00 | Firestore UID/relasi ID, repository, hasil uji, pembagian kontribusi dan batas AI |

Screenshot yang dibutuhkan: Home asli + tombol AI, detail/porsi, langkah memasak, Fridge kosong, form error, Fridge berisi, hasil pencocokan, koleksi, detail koleksi, demo gagal + Try again, AI. Bukti yang dihasilkan otomatis ada pada docs/evidence; jangan menyebut screenshot dari versi UI lama sebagai bukti versi ini.

Sebelum presentasi, semua anggota perlu mencoba tiga alur sendiri dan dapat menjelaskan sumber data, UID, relasi recipeIds, validasi serta mengapa demo failure tidak merusak data. Isi nama/NIM dan kontribusi sebenarnya pada dokumen kelompok.

Buat ZIP dengan `python tools/package_source.py`. ZIP tidak berisi build, .dart_tool, token, file lokal IDE, maupun akun uji. Konfigurasi client Firebase berisi identifier proyek, bukan service-account credential. Jangan pernah memasukkan service-account JSON atau password.
