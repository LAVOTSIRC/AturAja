# Panduan Setup Kolaborasi — AturAja

Dokumen ini ditujukan untuk anggota tim yang baru clone project dari GitHub dan
perlu menghubungkan ke Firebase project `aturaja-ai` agar aplikasi berjalan penuh
(Firestore, Auth, Gemini AI, App Check).

---

## Prasyarat

Pastikan semua tool berikut sudah terpasang dan terbaca dari terminal sebelum mulai:

| Tool | Versi minimum | Cek dengan |
| --- | --- | --- |
| Flutter SDK | 3.13.x atau lebih baru | `flutter --version` |
| Dart SDK | 3.13.2 atau lebih baru | `dart --version` |
| Android Studio | Versi stabil terbaru | Buka aplikasi |
| Java / JDK | 17 | `java -version` |
| Node.js | 18 LTS atau lebih baru | `node --version` |
| Firebase CLI | 13.x atau lebih baru | `firebase --version` |
| Git | — | `git --version` |

Jika Firebase CLI belum ada, install lewat npm:

```bash
npm install -g firebase-tools
```

---

## Langkah 1 — Clone & Install Dependency

```bash
git clone https://github.com/<username>/aturaja.git
cd aturaja
flutter pub get
```

Pastikan tidak ada error merah. Peringatan kuning tentang dependency boleh diabaikan.

---

## Langkah 2 — Login Firebase CLI & Set Project

```bash
firebase login
```

Login dengan akun Google yang **sudah diberi akses** ke Firebase project
`aturaja-ai` oleh pemilik project. Setelah login berhasil:

```bash
firebase use aturaja-ai
```

Verifikasi akun yang aktif:

```bash
firebase login:list
```

> **Jika muncul error 403 "Caller does not have required permission":**
> Minta pemilik project membukakan akses di
> https://console.developers.google.com/iam-admin/iam?project=aturaja-ai
> dan menambahkan email kamu dengan role **Firebase Admin** atau **Editor**.

---

## Langkah 3 — Dapatkan `google-services.json`

File ini **tidak ada di repo** (di-gitignore) karena memuat API key yang
bersifat rahasia. Setiap developer perlu mengunduhnya sendiri.

### 3a. Unduh dari Firebase Console

1. Buka https://console.firebase.google.com → pilih project **aturaja-ai**
2. Klik ikon **⚙ (Settings)** di sidebar → **Project settings**
3. Scroll ke bagian **"Your apps"** → pilih app Android (`com.aturaja.app`)
4. Klik tombol **"Download google-services.json"**
5. Pindahkan file yang diunduh ke:

   ```
   android/app/google-services.json
   ```

### 3b. Tambahkan SHA-1 Milikmu (Wajib untuk Google Sign-In)

Google Sign-In hanya bekerja jika SHA-1 debug keystore-mu sudah didaftarkan.

**Dapatkan SHA-1 debug keystore-mu:**

```bash
# Windows (dari folder android project)
cd android
gradlew.bat signingReport

# macOS / Linux
cd android
./gradlew signingReport
```

Cari output bertuliskan `Variant: debug` → salin nilai **SHA1**.

**Daftarkan ke Firebase Console:**

1. Firebase Console → ⚙ Project Settings → Your apps → `com.aturaja.app`
2. Scroll ke bagian **"SHA certificate fingerprints"**
3. Klik **"Add fingerprint"** → paste nilai SHA1 → **Save**
4. **Unduh ulang** `google-services.json` (SHA-1 baru harus masuk ke file ini)
5. Timpa file lama di `android/app/google-services.json`

> **Mengapa unduh ulang?** File `google-services.json` menyimpan daftar SHA-1
> yang diizinkan. Kalau SHA-1 baru belum ada di file, Google Sign-In akan gagal.

---

## Langkah 4 — Deploy Firestore Rules & Indexes

Pastikan aturan keamanan Firestore sudah diterapkan ke Firebase:

```bash
firebase deploy --only firestore:rules,firestore:indexes
```

Langkah ini hanya perlu dilakukan **sekali** per project (bukan per developer).
Kalau kawanmu sudah pernah melakukannya, kamu bisa lewati — tapi tidak ada
ruginya dijalankan ulang.

---

## Langkah 5 — Daftarkan Debug Token App Check

App Check memblokir semua request (Gemini AI dan Firestore) dari device/emulator
yang token debug-nya belum terdaftar. Ini harus dilakukan satu kali per
device/emulator.

### 5a. Jalankan App & Ambil Token dari Logcat

1. Hubungkan HP Android atau nyalakan emulator di Android Studio
2. Jalankan app dalam mode debug:

   ```bash
   flutter run
   ```

3. Di **Android Studio → Logcat**, filter dengan kata kunci:

   ```
   DebugAppCheckProvider
   ```

   Cari baris seperti ini:

   ```
   D/DebugAppCheckProvider: Enter this debug secret into the allow list in the
   Firebase Console for your project: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
   ```

4. Salin nilai UUID tersebut (format: `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`)

> **Alternatif lewat adb logcat (terminal):**
> ```bash
> adb logcat | findstr "DebugAppCheckProvider"   # Windows
> adb logcat | grep "DebugAppCheckProvider"      # macOS/Linux
> ```

### 5b. Daftarkan Token ke Firebase Console

1. Firebase Console → **App Check** (menu kiri bawah)
2. Klik tab **Apps** → pilih app Android
3. Klik **"⋮ (menu)** → **Manage debug tokens**
4. Klik **"Add debug token"**
5. Paste token UUID → beri nama yang mudah dikenali
   (contoh: `"Laptop Christein"` atau `"Emulator Zidan"`)
6. Klik **Save**

Setelah ini, Gemini AI dan Firestore akan menerima request dari device-mu.

---

## Langkah 6 — Jalankan Aplikasi

```bash
flutter run
```

Atau dari Android Studio: klik tombol **▶ Run** setelah memilih device.

Saat pertama kali berjalan, app akan membuka halaman login. Daftar akun baru
atau masuk dengan email yang sudah terdaftar. Data akan otomatis tersinkron
ke Firestore setelah login.

---

## Checklist Cepat

Centang satu per satu sebelum menyerah debugging:

- [ ] `flutter pub get` berhasil tanpa error
- [ ] `firebase login` → akun yang benar
- [ ] `firebase use aturaja-ai` → tidak muncul error permission
- [ ] `android/app/google-services.json` sudah ada
- [ ] SHA-1 sudah didaftarkan dan `google-services.json` sudah diunduh ulang
- [ ] `firebase deploy --only firestore:rules,firestore:indexes` sudah dijalankan
- [ ] Debug token App Check sudah didaftarkan untuk device/emulator ini
- [ ] App bisa login dan data muncul di halaman utama

---

## Troubleshooting Error Umum

### `PERMISSION_DENIED: Missing or insufficient permissions` (Firestore)

**Penyebab A:** Rules belum di-deploy.
```bash
firebase deploy --only firestore:rules,firestore:indexes
```

**Penyebab B:** Debug token App Check belum didaftarkan.
→ Ulangi Langkah 5.

**Penyebab C:** User belum login di app. Cek apakah halaman login muncul
dengan benar sebelum mengakses fitur cloud.

---

### `[firebase_app_check/unknown] code: 403 App attestation failed` (Gemini / AI)

Debug token App Check belum terdaftar untuk device/emulator ini.
→ Ulangi Langkah 5.

---

### `Google Sign-In gagal` atau `konfigurasi Google Sign-In belum benar`

SHA-1 debug keystore-mu belum didaftarkan atau `google-services.json` belum
diunduh ulang setelah SHA-1 ditambahkan.
→ Ulangi Langkah 3b dari awal.

---

### `Error 403 Caller does not have required permission` (Firebase CLI)

Akunmu belum punya IAM role yang cukup di Google Cloud.
→ Minta pemilik project (`aturaja-ai`) menambahkan emailmu di:
https://console.developers.google.com/iam-admin/iam?project=aturaja-ai
dengan role **Firebase Admin** atau **Editor**, lalu tunggu 1-2 menit.

---

### Build gagal: `google-services.json not found`

File belum ada di `android/app/`.
→ Ulangi Langkah 3a.

---

### `flutter pub get` gagal / dependency conflict

Pastikan versi Flutter SDK sesuai:
```bash
flutter --version   # harus 3.13.x atau lebih baru
flutter upgrade     # update jika perlu
flutter pub get
```

---

## Catatan Penting

- **Jangan commit** `android/app/google-services.json` dan
  `lib/firebase_options.dart` ke GitHub — keduanya sudah masuk `.gitignore`.
- Setiap developer dan setiap emulator baru memerlukan **debug token App Check
  tersendiri**.
- SHA-1 yang sudah didaftarkan developer lain **tidak perlu didaftarkan ulang**
  olehmu — tapi SHA-1 milikmu harus tetap ditambahkan.
- Jika berganti laptop atau install ulang Android Studio, ulangi Langkah 3b
  (SHA-1 baru) dan Langkah 5 (debug token baru).

---

## Kontak

Jika masih ada masalah setelah mengikuti semua langkah, hubungi:

- **Cristoval** — Cloud/Data Lead (Firebase, Firestore, Auth)
- **Christein** — Device/Security Lead (App Check, SHA-1)
- **Zidan** — AI/Document Lead (Gemini, OCR)
