# Revisi tahap 1: poin 1–3

- Sign In menerima tombol langsung tanpa verifikasi email/password. Input form tidak dikirim sebagai kredensial.
- Sign Up memvalidasi form untuk demonstrasi, kembali ke Sign In, dan menampilkan keterangan bahwa tidak ada akun sungguhan dibuat. Nama hanya disiapkan dalam memori untuk profil demo baru.
- Penyimpanan memakai UID Firebase Anonymous. Sign Out kembali ke halaman masuk; identitas anonim SDK dipertahankan agar data instalasi yang sama dapat dibuka kembali. Ini bukan logout keamanan atau akun pribadi. Penghapusan data aplikasi/reinstall dapat menghilangkan akses ke UID tersebut.
- Counter nama profil disembunyikan; batas panjang tetap 60 karakter. Email tidak diperlukan pada profil demo.
- Area bahan detail mendapat ruang bawah tambahan untuk tombol Start Cooking dan navigasi Android.

## Konfigurasi server

Anonymous sudah diaktifkan pada Firebase Authentication. Penyesuaian firestore.rules untuk profil anonim dengan email kosong sudah dipublikasikan pada 1 Oktober 2026. Aturan tetap membatasi data pengguna berdasarkan UID. Email/Password yang sudah ada tetap aktif, tetapi layar aplikasi sekarang menggunakan alur demo anonim.

## Pemeriksaan

Enam uji khusus Auth/profil lulus, termasuk Sign Up tetap di halaman masuk, Sign In tanpa input, dan masuk kembali setelah Sign Out. Suite lengkap terhenti karena memori komputer; drive C juga penuh. Uji khusus berhasil setelah direktori sementara untuk proses pengujian dialihkan ke .dart_tool/stage1_temp pada drive D. Hasil 37 uji pada dokumentasi sebelumnya berasal dari versi sebelum revisi demo.

Analisis statis file yang diubah selesai tanpa error/warning; terdapat tiga info lint lama pada halaman detail resep.

Pemeriksaan live dengan dua akun anonim sementara: 32 pemeriksaan lulus, mencakup autentikasi anonim, baca katalog, CRUD Fridge/koleksi/Favorite sesuai UID dan penolakan akses lintas UID. Akun dan dokumen sementara dibersihkan. Bukti: docs/evidence/anonymous-access.txt. Uji ini tidak membuat dokumen profil induk; pemeriksaan visual end-to-end aplikasi Android tetap diperlukan.

Poin 4–12 belum dikerjakan pada tahap ini.
