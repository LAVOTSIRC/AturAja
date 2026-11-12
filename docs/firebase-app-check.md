# Firebase App Check Setup

App Check melindungi Firebase dan Gemini dari permintaan yang bukan berasal dari
aplikasi AturAja. Konfigurasi ini harus dilakukan per lingkungan dan tidak boleh
menyimpan token atau kunci rahasia di repository.

## Debug build

1. Jalankan aplikasi debug di perangkat.
2. Cari token debug di Logcat:

   ```powershell
   adb logcat | Select-String "AppCheck"
   ```

3. Buka Firebase Console > App Check > Apps > AturAja Android.
4. Pilih **Manage debug tokens**, tambahkan token dari Logcat, lalu simpan.
5. Hentikan paksa aplikasi dan buka kembali. Permintaan Gemini seharusnya tidak
   lagi menghasilkan `App attestation failed`.

Token debug hanya berlaku untuk instalasi yang menghasilkannya. Jangan
menyalin token milik perangkat lain dan jangan commit token ke repository.

## Release build

1. Aktifkan **Play Integrity API** di Google Cloud Console.
2. Daftarkan aplikasi di Play Console dan pastikan paket
   `com.aturaja.app` beserta SHA-256 signing key produksi terdaftar.
3. Build release dengan keystore produksi. `android/app/build.gradle.kts`
   memakai `android/key.properties` jika file lokal itu tersedia.
4. Firebase Console > App Check > Apps > AturAja Android: pilih
   **Play Integrity** sebagai penyedia attestation.
5. Uji login email/Google dan satu permintaan AI dari build release.

`android/key.properties`, file keystore, `google-services.json`, dan
`lib/firebase_options.dart` diabaikan oleh Git. Minta file konfigurasi tersebut
kepada pemilik proyek.

## API key restriction

Di Google Cloud Console > APIs & Services > Credentials, batasi Android API key
ke aplikasi dengan nama paket `com.aturaja.app` dan SHA-1 debug/release yang
terdaftar. Batasi juga API yang boleh dipakai, misalnya Identity Toolkit,
Token Service, Firebase App Check, dan Gemini API yang digunakan proyek.
