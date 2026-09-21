# QuickRecipe — Backend

Direktori ini berisi seluruh konfigurasi dan kode backend untuk aplikasi QuickRecipe.

## Prasyarat

- **Node.js 20 LTS** — untuk Cloud Functions
- **Python 3.11+** — untuk seeding script
- **Firebase CLI** — `npm install -g firebase-tools`

## Firebase Project

- **Project ID:** `quickrecipe-00`
- **Region Cloud Functions:** `asia-southeast1` (Singapore)

## Setup Awal

```bash
# 1. Login Firebase
firebase login

# 2. Masuk ke folder backend
cd backend

# 3. Set project aktif
firebase use quickrecipe-00

# 4. Install dependencies Cloud Functions
cd functions && npm install
```

## Menjalankan Emulator (Development)

```bash
# Dari folder backend/
firebase emulators:start
```

Buka Emulator UI di: http://localhost:4000

Port emulator:
- Auth: 9099
- Firestore: 8080
- Functions: 5001
- UI: 4000

## Cloud Functions

### Set Secret GEMINI_API_KEY (untuk production nanti)

```bash
firebase functions:secrets:set GEMINI_API_KEY
```

## Script Python (Seeding)

### Download Service Account Key

1. Buka [Firebase Console](https://console.firebase.google.com/project/quickrecipe-00/settings/serviceaccounts/adminsdk)
2. Klik **Generate new private key**
3. Simpan file sebagai `backend/scripts/serviceAccountKey.json` (sudah ada di `.gitignore`, jangan di-commit)

### Jalankan Seeding

```bash
cd scripts
pip install -r requirements.txt
python seed_recipes.py
```

## Deploy ke Production (setelah upgrade ke Blaze)

```bash
# Dari folder backend/
firebase deploy --only firestore:rules,firestore:indexes,functions
```

## Catatan Penting

> ⚠️ **JANGAN modifikasi `firebase.json` di root repo** — file tersebut milik FlutterFire CLI dan bukan konfigurasi backend.

Semua perintah `firebase` harus dijalankan dari dalam folder `backend/`, bukan dari root repo.
