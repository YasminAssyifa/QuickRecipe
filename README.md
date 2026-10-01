# QuickRecipe — UTS

> Revisi aktif: poin 1–3 memakai login demo dengan Firebase Anonymous, yang sudah aktif di server beserta aturan profilnya. Tap Sign In tanpa kredensial; Sign Up hanya simulasi. Enam uji Auth/profil revisi ini lulus. Petunjuk Email/Password serta hasil 37 uji di bawah merupakan versi sebelumnya. Lihat [status tahap 1](docs/REVISION_STAGE_1.md).

Aplikasi resep Android dengan Firebase Authentication dan Cloud Firestore. Folder kerja melanjutkan desain teman dari `D:/develop/StudioProjects/QuickRecipe-main`; folder referensi tidak diubah. Rincian perubahan ada di [CHANGELOG](docs/CHANGELOG.md).

## Setup dan menjalankan

Diuji memakai Flutter 3.47.3, Dart 3.13.3, Android SDK dan Java dari Android Studio. `pubspec.yaml` memerlukan Dart ^3.13.2. Jalankan dari folder source yang telah diekstrak:

```powershell
flutter pub get
flutter devices
flutter run
```

Pilih perangkat Android. Koneksi internet diperlukan untuk autentikasi, data Firestore dan gambar resep. Gunakan **Sign Up** untuk membuat akun sendiri, lalu **Sign In**. Tidak ada akun/password bawaan. Profile menyediakan edit nama dan Sign Out; email mengikuti Firebase Authentication.

Konfigurasi client Firebase `quickrecipe-00` sudah tersedia pada `android/app/google-services.json` dan `lib/firebase_options.dart`. Konfigurasi client bukan kredensial admin. Jangan menambahkan password, ID token atau service-account JSON ke source.

Untuk APK debug:

```powershell
flutter build apk --debug
```

Hasil: `build/app/outputs/flutter-apk/app-debug.apk`. Platform yang menjadi target dan diuji build adalah Android; platform lain tidak dijanjikan siap.

## Fitur

- Home, pencarian, kategori, kartu, detail, pengaturan porsi, langkah memasak dan navigasi bawah memakai UI awal.
- Autentikasi Email/Password Firebase, profil dan Favorite per akun.
- **Fridge CRUD**: nama bahan, jumlah, satuan, kelompok, use-by date, catatan; validasi, proses simpan, konfirmasi hapus, pesan sukses dan retry.
- **Find recipes** mencocokkan nama bahan yang belum kedaluwarsa, termasuk beberapa alias Indonesia/Inggris. Menampilkan bahan tersedia/kurang. Tidak menghitung kecukupan berat bahan.
- **Collections CRUD** melalui ikon folder di Favorite/Fridge. Favorite adalah satu daftar cepat; koleksi adalah folder bernama yang dapat diisi beberapa ID resep. Satu resep bisa masuk beberapa koleksi; menghapus koleksi tidak menghapus resep.
- Tombol logo bulat menuju **AI Preview**, bisa digeser, tersedia lintas layar dan disembunyikan saat dialog/halaman AI. Sesuai scope, belum ada backend AI dan percakapan tidak dikirim/disimpan.
- Explore membuka daftar resep. Ikon mahkota menampilkan penjelasan bahwa fitur katalog tersedia tanpa premium.

## Data dan arsitektur

Firestore sudah berisi **20 resep**: 2 dokumen asli tidak ditimpa, 18 tambahan dari `tools/seed_recipes.json`. Ada **5 kategori nyata** (Breakfast, Lunch, Dinner, Snack, Dessert) dan satu dokumen All untuk filter. Dua resep asli masih berisi placeholder dari sumber awal; pilih resep tambahan untuk demo lengkap.

Provider mengelola sesi/profil/Favorite dan menyediakan repository berdasarkan UID. Model, repository dan UI baru terpisah di `lib/additions`. Penyimpanan final memakai Firestore; tidak ditambahkan SQLite, SharedPreferences atau database lokal. Cache internal SDK bukan database aplikasi tambahan.

| Path | Isi |
|---|---|
| Complete-Flutter-App/{recipeId} | Katalog resep, dibaca pengguna login |
| App-Category/{categoryId} | Referensi kategori resep |
| users/{uid} | Nama, email dan timestamp profil |
| users/{uid}/favorites/{recipeId} | ID resep favorit |
| users/{uid}/fridge/{itemId} | Bahan, jumlah, satuan, kelompok, tanggal, catatan |
| users/{uid}/collections/{collectionId} | Nama, catatan, array recipeIds unik |

Lima kelompok bahan disediakan sebagai referensi statis pada `foodGroups`; kategori resep tetap dibaca dari Firestore. Form menyimpan ID sekali, mengunci submit saat proses, dan mempertahankan input saat gagal. Transaksi melindungi update dokumen yang sudah dihapus. State form yang belum disimpan hanya berada di memori.

## Simulasi state UTS

Buka **Fridge → menu tiga titik (Demo scenarios)**:

1. **Demo: failed loading**: jeda sekitar 900 ms dan loading, lalu pesan gagal + **Try again**. Retry kembali membaca Firestore nyata.
2. **Demo: empty fridge**: tampilkan panduan daftar kosong; **Exit demo** kembali ke data nyata.
3. Dalam mode normal, Fridge/koleksi kosong menyediakan tombol menambah. Input kosong/salah menampilkan error spesifik.

`FridgeDemoRepository` menjadi sumber simulasi dan tidak menulis/menghapus data. Semua penyimpanan CRUD tetap Firestore sesuai keputusan proyek. Jika dosen meminta seluruh CRUD menggunakan repository simulasi tanpa jaringan, scope ini perlu disepakati kembali; implementasi saat ini memprioritaskan instruksi pemilik proyek memakai Firestore.

## Firebase dan aturan akses

Email/Password sudah aktif. `firestore.rules` telah dipublikasikan pada 30 September 2026. Uji REST langsung mengonfirmasi CRUD milik sendiri diizinkan, akses akun lain/anonim ditolak, serta katalog tidak bisa dibaca anonim. Write katalog dari aplikasi diblokir; pengisian resep merupakan tugas developer. Profile tidak menyediakan hapus akun pada scope ini.

Data Favorite global dari versi awal tidak dihapus atau dimigrasikan otomatis karena pemiliknya tidak diketahui. Akun versi baru menggunakan path UID sendiri.

Script seed menambah hanya ID/nama yang belum ada dan tidak menimpa dokumen asli:

```powershell
python tools/seed_firestore.py
python tools/seed_firestore.py --apply
```

Setelah rules diperketat, kedua perintah memerlukan akses yang sesuai. Untuk write gunakan `GOOGLE_OAUTH_ACCESS_TOKEN` berizin IAM Firestore melalui environment, bukan token pengguna aplikasi. Token tidak boleh disimpan di source. Script tidak mengubah rules dan tidak berjalan saat aplikasi dibuka. Resep sudah terisi; tidak perlu menjalankannya lagi untuk demo.

Foto tambahan bersumber dari TheMealDB (https://www.themealdb.com/api.php); sebagian merupakan ilustrasi makanan sejenis. Kalori adalah data simulasi, bukan perhitungan gizi.

## Dependency

Package runtime tambahan pada tahap integrasi: **firebase_auth 5.7.0**. Fridge/koleksi/AI tidak menambah package runtime. Versi resolved utama: firebase_core 3.15.2, cloud_firestore 5.6.12; Provider dan komponen visual tetap dari proyek awal. Versi lengkap reproducible ada pada pubspec.lock.

## Pengujian dan bukti

```powershell
flutter test
python -m unittest discover -s tools -p "test_*.py"
flutter analyze --no-fatal-infos
flutter build apk --debug
```

- 37 uji Flutter lulus (model, form, state, navigasi AI, pencegahan submit berulang, ukuran layar kecil/keyboard).
- 4 uji Python seed lulus.
- 36 pemeriksaan Firebase live lulus, termasuk registrasi/login, CRUD, isolasi UID dan jumlah katalog; seluruh akun/data uji sementara dibersihkan.
- Analyzer: tidak ada error/warning; 6 info lint dari source lama masih ada.
- Uji end-to-end Android sempat terhenti pada Firebase Auth karena `CertPathValidatorException: Trust anchor for certification path not found` di jaringan emulator. Ini **belum merupakan bukti tiga alur live Android lulus**. Lakukan checklist perangkat pada matriks memakai koneksi yang dipercaya perangkat.

Ulangi pemeriksaan akses live (membuat dan membersihkan dua akun sementara, tidak menyentuh data pengguna):

```powershell
python tools/verify_firestore_access.py --apply
```

Pada mesin ini, pengunduhan Gradle memerlukan truststore dari sertifikat Windows yang sudah dipercaya. Truststore hanya lokal dan tidak dimasukkan ZIP. Bila muncul PKIX pada mesin lain, perbaiki kepercayaan sertifikat jaringan/JDK; jangan menonaktifkan validasi TLS.

Lihat [matriks uji](docs/TEST_MATRIX.md), [persona/model/kontribusi](docs/UTS_BRIEF.md), [panduan video](docs/DEMO_GUIDE.md), dan [bukti](docs/evidence).

## Paket pengumpulan

```powershell
python tools/package_source.py
```

Hasil: `dist/QuickRecipe-UTS-source.zip`. Script mengecualikan build, .dart_tool, cache, local.properties, keystore, service-account dan file token/kredensial. Sertakan source ZIP ini, isi nama/NIM kontribusi sebenarnya, lalu rekam video 8–10 menit mengikuti panduan. Video, screenshot alur Android lengkap, dan kesiapan presentasi setiap anggota masih perlu dikerjakan kelompok.
