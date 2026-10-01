# Catatan penambahan dan perlindungan desain

Pemeriksaan 30 September 2026. Folder referensi `D:/develop/StudioProjects/QuickRecipe-main` tidak diedit. 17 file lib sesuai hash SHA-256 yang diambil sebelum penambahan. 3 aset asli identik pada folder kerja.

## File Dart baru pada tahap Fridge/koleksi/AI

- `lib/additions/ai_access.dart`
- `lib/additions/collection_screens.dart`
- `lib/additions/fridge_screen.dart`
- `lib/additions/kitchen_repository.dart`
- `lib/additions/recipe_matches_screen.dart`
- `lib/additions/shared.dart`

## File Dart yang disambungkan pada tahap ini

- `lib/main.dart`
- `lib/Provider/quantity.dart`
- `lib/views/app_main_screen.dart`
- `lib/views/favorite_screen.dart`
- `lib/views/my_app_home_screen.dart`
- `lib/views/recipe_detail_screen.dart`
- `lib/views/step_screen.dart`
- `lib/views/view_all_items.dart`
- `lib/Widgets/banner.dart`
- `lib/Widgets/food_items_display.dart`

Perubahan file lama hanya untuk sambungan repository/rute/aksi/state, Favorite, tombol Explore/mahkota, reset porsi dan padding responsif tombol detail. Header, banner, kartu, logo, warna dan navigasi bawah menggunakan desain sumber awal. File lama tidak identik byte-per-byte pada folder kerja karena fitur baru harus dihubungkan; folder referensi tetap asli.

## Penambahan tahap sebelumnya yang dipertahankan

- services/account_repository.dart, Provider/profile_provider.dart, views/account_gate.dart, views/profile_screen.dart.
- Sambungan Firebase Auth pada signin_screen.dart/signup_screen.dart, Favorite per UID pada favorite_provider.dart, dan konfigurasi firebase.json/firestore.rules.
- tools/seed_recipes.json, tools/seed_firestore.py, tools/test_seed_firestore.py; 18 resep tambahan, dua resep lama tidak ditimpa.
- firebase_auth 5.7.0 di pubspec.yaml dan lockfile; deklarasi aset diperbaiki.

## Uji dan dokumen

- test/kitchen_model_test.dart, test/kitchen_widget_test.dart, test/support/fake_kitchen.dart, test/analysis_options.yaml.
- tools/verify_firestore_access.py, tools/package_source.py.
- README.md, docs/UTS_BRIEF.md, docs/TEST_MATRIX.md, docs/DEMO_GUIDE.md dan bukti docs/evidence.

Tidak ada package runtime baru untuk Fridge/koleksi/AI. Provider dan cloud_firestore memakai dependency yang sudah tersedia. Tidak ada perubahan di folder referensi dan tidak ada migrasi/hapus resep lama.
