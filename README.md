# QuickRecipe

Banyak orang, terutama yang memasak untuk diri sendiri, sering bingung menentukan menu dari bahan yang kebetulan ada di rumah. Bahan yang tidak terpantau akhirnya terbuang, sementara resep yang cocok sulit dicari satu per satu. QuickRecipe dibuat untuk membantu mengatasi hal itu: aplikasi Android yang mencatat isi kulkas, mencarikan resep dari bahan yang tersedia, lalu memandu proses memasak langkah demi langkah.

## Fitur

- **Login demo**: tekan **Sign In** tanpa mengisi apa pun (Firebase Anonymous). **Sign Up** hanya simulasi form. Profil menyediakan edit nama dan Sign Out.
- **Home, pencarian, kategori, detail resep**: atur jumlah porsi dan ikuti langkah memasak satu per satu.
- **Favorite**: simpan resep favorit per pengguna.
- **Fridge**: tambah, ubah, dan hapus bahan (nama, jumlah, satuan, kelompok, catatan), dengan filter per kelompok. Tombol **Pakai bahan** memilih beberapa bahan dan mengurangi stok setelah konfirmasi. Stok nol tampil sebagai Habis.
- **Find recipes**: mencocokkan bahan yang stoknya lebih dari nol dengan resep, termasuk beberapa alias Indonesia/Inggris, dan menampilkan bahan yang tersedia dan yang kurang.
- **Koleksi**: kelompokkan resep ke folder bernama lewat ikon folder di Favorite/Fridge. Satu resep bisa masuk beberapa koleksi, dan menghapus koleksi tidak menghapus resep.
- **AI Preview**: tombol logo bulat yang bisa digeser menuju tampilan chatbot. Belum ada backend AI; percakapan tidak dikirim maupun disimpan.

## Tim

| Nama | NIM |
|---|---|
| Edric Roland Li | 241401079 |
| Yasmin Assyifa | 241401076 |
| Najla Az Zahra Tanjung | 241401133 |

## Menjalankan aplikasi

Membutuhkan Flutter (Dart ^3.13.2) dan Android SDK.

```powershell
flutter pub get
flutter run
```

Pilih perangkat Android dan pastikan terhubung ke internet (untuk Firebase dan gambar resep). Untuk membuat APK debug:

```powershell
flutter build apk --debug
```

Hasil: `build/app/outputs/flutter-apk/app-debug.apk`.

Konfigurasi Firebase client (`quickrecipe-00`) sudah ada di `android/app/google-services.json` dan `lib/firebase_options.dart`. Jangan menambahkan password, token, atau service-account JSON ke repository.

## Struktur proyek

| Folder | Isi |
|---|---|
| `lib/views`, `lib/Widgets` | Layar dan komponen UI |
| `lib/Provider`, `lib/services` | State (Provider) dan akses data akun |
| `lib/additions` | Fridge, Pakai bahan, pencocokan resep, koleksi, AI Preview, dan repository Firestore |
| `test/` | Uji unit dan widget |
| `tools/` | Skrip mengisi resep ke Firestore dan datanya |
| `firestore.rules` | Aturan akses Firestore |

## Data (Cloud Firestore)

| Path | Isi |
|---|---|
| `Complete-Flutter-App/{recipeId}` | Katalog resep (26 resep) |
| `App-Category/{categoryId}` | Kategori: Breakfast, Lunch, Dinner, Snack, Dessert (+ All untuk filter) |
| `users/{uid}` | Profil pengguna |
| `users/{uid}/favorites/{recipeId}` | Resep favorit |
| `users/{uid}/fridge/{itemId}` | Bahan di kulkas |
| `users/{uid}/stockOperations/{operationId}` | Penanda transaksi agar stok tidak berkurang dua kali |
| `users/{uid}/collections/{collectionId}` | Nama, catatan, dan daftar ID resep |

Data pengguna hanya bisa diakses oleh UID pemiliknya, sedangkan katalog resep hanya bisa dibaca oleh pengguna yang sudah login (lihat `firestore.rules`). Foto resep tambahan bersumber dari [TheMealDB](https://www.themealdb.com/api.php), dan nilai kalori hanyalah data contoh.

## Mengisi data resep

Skrip seed hanya menambah resep yang belum ada dan tidak menimpa dokumen lama:

```powershell
python tools/seed_firestore.py            # simulasi
python tools/seed_firestore.py --apply    # tulis ke Firestore
```

Untuk menulis dibutuhkan token Google OAuth berizin Firestore lewat environment `GOOGLE_OAUTH_ACCESS_TOKEN`, bukan token pengguna aplikasi.

## Pengujian

```powershell
flutter test
python -m unittest discover -s tools -p "test_*.py"
flutter analyze --no-fatal-infos
```
