# QuickRecipe — Paket UTS

## Persona utama (fiktif)

Rani, 20 tahun, mahasiswa yang tinggal di kos dan memasak untuk satu atau dua orang. Ia ingin menemukan menu sederhana dari bahan yang tersedia, menghindari bahan kedaluwarsa, dan menyimpan resep untuk digunakan lagi. Hambatan: waktu singkat, layar ponsel kecil, koneksi tidak selalu stabil, serta jumlah bahan terbatas.

## Tiga alur demonstrasi

1. Masuk akun → Home → cari resep → detail → atur porsi → Start Cooking → Next/Back → Finish Cooking → pesan selesai. Favorite dapat digunakan untuk menyimpan resep.
2. Fridge → tambah bahan (nama, jumlah, satuan, kelompok, tanggal; catatan opsional) → simpan ke Firestore → edit jumlah → Find recipes → lihat bahan tersedia/kurang → detail resep → kembali → hapus bahan dengan konfirmasi.
3. Favorite atau Fridge → ikon folder → buat koleksi → pilih resep → simpan → detail koleksi → edit nama/isi → keluarkan resep → hapus koleksi dengan konfirmasi. Menghapus koleksi tidak menghapus resep katalog.

Tambahan: tombol bulat berlogo aplikasi membuka AI dari setiap rute, termasuk login. Tombol dapat digeser dan disembunyikan pada dialog serta halaman AI. Halaman AI hanya pratinjau: tidak mengirim pesan ke model, tidak mengarang jawaban, dan tidak menyimpan percakapan.

## Peta layar

| Layar | Akses | Fungsi |
|---|---|---|
| Sign In | Sesi belum login | Login akun Firebase |
| Sign Up | Tautan Sign Up | Buat akun dan profil |
| Home | Setelah login | Cari/filter resep |
| View All | Explore atau View all | Daftar seluruh resep |
| Recipe Detail | Kartu resep | Bahan, porsi, Favorite, mulai memasak |
| Cooking Steps | Start Cooking | Langkah Back/Next/Finish |
| Favorite | Tab Favorite | Daftar favorit per akun |
| Profile | Ikon profil Home | Lihat email, edit nama, logout |
| Fridge | Tab Fridge | Daftar/edit/hapus bahan, demo state |
| Ingredient Form | Add ingredient/Edit | Enam input dengan validasi |
| Recipe Matches | Find recipes | Hasil berdasarkan bahan belum kedaluwarsa |
| Collections | Ikon folder Favorite/Fridge | Daftar/hapus folder resep |
| Collection Form | Create/Edit | Nama, catatan, pencarian, checkbox resep |
| Collection Details | Pilih koleksi | Baca isi dan buka detail resep |
| AI Preview | Tombol logo | Pratinjau UI chatbot |

## Model dan relasi data

- Firebase Auth: UID sebagai identitas akun, email/password dikelola Firebase; password tidak disimpan di Firestore.
- `Complete-Flutter-App/{recipeId}`: 20 resep yang sudah diisi. Field lama tetap: name, category, image, cal, time, ingredientsName, ingredientsAmount, step. Resep tambahan memiliki categoryId. Dua resep awal masih memakai isi placeholder; tidak diubah tanpa persetujuan.
- `App-Category/{categoryId}`: Breakfast, Lunch, Dinner, Snack, Dessert; All hanya filter tambahan.
- `users/{uid}`: name, email, createdAt, updatedAt.
- `users/{uid}/favorites/{recipeId}`: recipeId → katalog, createdAt. Data Favorite bersama versi awal dipertahankan tetapi tidak diatribusikan ke akun sembarangan.
- `users/{uid}/fridge/{itemId}`: name, ingredientId (nama bahan yang dinormalisasi), amount, unit, categoryId, expiry (`YYYY-MM-DD`), notes, updatedAt. categoryId mengacu ke lima kelompok bahan pada foodGroups.
- `users/{uid}/collections/{collectionId}`: name, notes, recipeIds (maksimal 100 ID unik → katalog), updatedAt. Array disimpan pada satu dokumen supaya penghapusan koleksi tidak menyisakan subdokumen.

Pencocokan resep menggunakan nama bahan yang dinormalisasi, termasuk alias Indonesia/Inggris. Ini tidak menghitung kecukupan gram atau menganggap nasi matang sama dengan beras. Bahan kedaluwarsa dikeluarkan dari hasil. Jumlah porsi masih menggunakan logika halaman detail asli.

## Arsitektur dan state

UI baru berada di `lib/additions`. `KitchenRepository` memisahkan UI dari Firestore; implementasi Firebase membaca server dan menulis transaksi. Form membuat ID sekali per pembukaan, memblokir submit/navigasi kembali saat simpan, dan menampilkan pesan kegagalan tanpa mengosongkan input. Menyimpan kembali setelah koneksi gagal tidak membuat ID baru.

`FridgeDemoRepository` menyimulasikan jeda, hasil kosong, dan kegagalan untuk demonstrasi. Mode demo tidak menulis ke database. Try again memuat data Firestore nyata; Exit demo mengembalikan daftar. Tidak ada database lokal baru. Cache SDK Firestore bila aktif merupakan perilaku SDK, bukan sumber penyimpanan aplikasi tambahan.

Provider mengelola sesi/profil/Favorite dan menyuntikkan repository sesuai UID. Form menggunakan state lokal untuk input yang belum disimpan; data final tetap di Firestore.

## Prinsip UI/HCI

Warna, ikon/logo, bentuk kartu, dan layout halaman lama dipertahankan. Komponen baru memakai constants.dart, radius 12 untuk field/tombol, radius 20 untuk kartu, serta label/error spesifik. Form bisa digulir ketika keyboard muncul. Dialog konfirmasi melindungi penghapusan; snackbar menunjukkan hasil simpan/hapus. Halaman AI secara jelas membedakan pratinjau dari layanan aktif.

## Kontribusi

- Teman pembuat frontend awal: desain asli, Home, banner, kartu, detail, langkah memasak, navigasi bawah, tampilan autentikasi, Favorite dan porsi awal.
- Pengembangan lanjutan bersama Codex: integrasi Auth, profil/Favorite per akun, seed resep, Fridge, koleksi, pencocokan, pratinjau AI, state/validasi tambahan, pengujian dan dokumentasi.
- Nama/NIM anggota dan pembagian nilai individu harus diisi oleh kelompok berdasarkan kontribusi sebenarnya; tidak dibuat-buat.

## Batas dan pekerjaan eksternal

Firestore rules telah dipublikasikan dan lolos 36 pemeriksaan live termasuk isolasi akun. Uji UI end-to-end pada emulator tertahan masalah sertifikat jaringan; checklist perangkat masih harus dituntaskan. UI AI sengaja belum memiliki backend sesuai scope UTS. Video dan presentasi anggota perlu direkam/dilakukan kelompok. Dokumen pengujian membedakan uji otomatis dan pemeriksaan manual yang belum dikerjakan.
