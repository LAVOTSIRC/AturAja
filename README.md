# AturAja

AturAja adalah aplikasi mobile untuk membantu mahasiswa mengatur tugas,
keuangan, dan rutinitas harian dalam satu tempat. Project ini dibuat dengan
Flutter, memakai penyimpanan lokal sebagai cache, sinkronisasi data ke Cloud
Firestore, dan autentikasi Firebase untuk login email/password serta Google
Sign-In.

## Setup

### Prasyarat

- Flutter SDK dengan Dart SDK `3.13.2` atau yang kompatibel.
- Android Studio atau perangkat Android/emulator untuk menjalankan target Android.
- VS Code atau IDE lain yang mendukung Flutter.
- Untuk target iOS, gunakan macOS dengan Xcode.

Pastikan instalasi Flutter sudah terbaca:

```bash
flutter doctor
```

### Instalasi project

Clone atau buka folder project, kemudian jalankan:

```bash
flutter pub get
```

Project menggunakan Firebase untuk Gemini AI Logic. Konfigurasi aplikasi
Firebase dibuat oleh FlutterFire CLI; tidak ada Gemini secret key atau file
`.env` yang perlu ditambahkan ke source code.

### Setup Firebase AI Logic

Setelah project Firebase dibuat dan dihubungkan:

```bash
firebase login
dart pub global activate flutterfire_cli
flutterfire configure
flutter pub get
```

Pilih project Firebase `aturaja-ai` dan platform Android/iOS. Pastikan
`com.aturaja.app` dipilih sebagai Android application ID.

Di Firebase Console, aktifkan **AI Logic > Gemini Developer API**. Daftarkan
aplikasi Android dan iOS pada **App Check**. Saat menjalankan build debug,
Firebase App Check memakai debug provider; token debug yang muncul di log
aplikasi harus didaftarkan pada Firebase Console sebelum request Gemini diuji.
Build release memakai Play Integrity untuk Android dan App Attest untuk iOS.

### Konfigurasi Firebase

1. Pastikan project Firebase `aturaja-ai` digunakan dan aplikasi Android
   didaftarkan dengan package name `com.aturaja.app`.
2. Aktifkan provider **Email/Password** dan **Google** di Firebase Authentication.
3. Tambahkan SHA-1 debug ke project Firebase. Untuk mendapatkan SHA-1:
   `cd android && ./gradlew signingReport` (Windows: `gradlew.bat signingReport`).
4. Pastikan `google-services.json` tersedia di
   `android/app/google-services.json`.
   File ini harus memuat `oauth_client` bertipe web (`client_type: 3`) agar
   Google Sign-In Android dapat meminta ID token. Jika belum ada, tambahkan
   aplikasi web pada project Firebase lalu unduh ulang file konfigurasi.
5. Jalankan `flutter pub get` setelah mengambil perubahan dependency.
6. Buat database **Cloud Firestore** mode Native di region `asia-southeast2`
   untuk project `aturaja-ai`.
7. Deploy aturan dan indeks Firestore dari root project:

   ```bash
   firebase use aturaja-ai
   firebase deploy --only firestore:rules,firestore:indexes
   ```

Tanpa langkah tersebut, build Android akan gagal pada plugin Google Services dan
aplikasi tidak dapat melakukan autentikasi. File `env.json` tidak digunakan pada
modul autentikasi ini. File hasil generate seperti
`android/app/google-services.json` dan `lib/firebase_options.dart` bersifat
environment-specific dan tidak di-commit; masing-masing developer perlu
menyiapkannya secara lokal.

### Struktur data Firestore

Data disimpan di bawah dokumen pengguna yang hanya bisa diakses pemiliknya:

```text
users/{uid}/
  profile/main
  settings/app        # disiapkan; pengaturan saat ini masih lokal
  tasks/{taskId}
  transactions/{transactionId}
  meta/state
```

ID dokumen memakai String. Data lokal lama yang masih memakai ID angka
dipertahankan lewat field `legacyId` saat migrasi. Migrasi lokal ke cloud hanya
berjalan sekali, yaitu ketika dokumen `profile/main` dan `meta/state` belum ada.
Tugas dan transaksi menyimpan `createdAt` serta `updatedAt` memakai
`serverTimestamp()` Firestore. Persistence offline Firestore juga diaktifkan.

Aturan keamanan Firestore diuji dengan emulator memakai perintah pada tabel
**Command Run**. Test tersebut memastikan pemilik bisa membaca/menulis datanya,
pengguna lain ditolak, pengguna tanpa login ditolak, dan dokumen dengan field
wajib yang tidak valid ditolak.

## Cara Menjalankan

1. Hubungkan perangkat fisik atau nyalakan emulator.
2. Cek perangkat yang tersedia:

   ```bash
   flutter devices
   ```

3. Jalankan aplikasi:

   ```bash
   flutter run
   ```

Saat dibuka, aplikasi menampilkan splash screen AturAja selama sekitar tiga
detik. Jika belum ada sesi Firebase, aplikasi menuju halaman login; setelah
login atau register, pengguna masuk ke `MainShell` dengan tab Home, Keuangan,
Tugas, dan Profil. Tab utama dapat diganti lewat bottom navigation atau dengan
swipe ke kiri/kanan. Sesi login dipulihkan dari Firebase saat aplikasi dibuka
ulang, dan logout akan mengakhiri sesi Firebase tersebut.

Gunakan tombol **Daftar** untuk membuat akun email/password baru, atau tombol
**Masuk dengan Google** untuk autentikasi Google pada perangkat Android.

## Command Run

| Command                                   | Kegunaan                                                       |
| ----------------------------------------- | -------------------------------------------------------------- |
| `flutter pub get`                         | Mengunduh dependency project.                                  |
| `flutter run`                             | Menjalankan aplikasi pada device/emulator aktif.               |
| `flutter run -d <device_id>`              | Menjalankan aplikasi pada device tertentu.                     |
| `flutter analyze`                         | Memeriksa error dan lint Dart/Flutter.                         |
| `flutter test`                            | Menjalankan seluruh test Dart/Flutter.                         |
| `npm --prefix test/rules install`         | Memasang dependency test aturan Firestore.                     |
| `firebase emulators:exec --only firestore --project demo-aturaja "npm --prefix test/rules test"` | Menguji `firestore.rules` di emulator. |
| `flutter build apk --debug`               | Membuat APK debug.                                             |
| `flutter build apk --release`             | Membuat APK release dengan signing debug untuk kebutuhan demo. |
| `dart run tool/generate_splash_icon.dart` | Membuat ulang asset icon splash Android 12+.                   |
| `dart run flutter_launcher_icons`         | Membuat ulang ikon aplikasi Android dan iOS dari logo AturAja. |

Jika asset splash diubah, jalankan juga generator splash berikut sebelum build:

```bash
dart run flutter_native_splash:create
```

## Dummy Data

Data demo awal didefinisikan di `lib/data/models.dart`. Setelah aplikasi
dijalankan pertama kali, perubahan tugas, transaksi, profil, pengaturan, dan
tema disimpan secara lokal melalui `SharedPreferences` dan tetap ada setelah
restart. Data lokal dipisahkan berdasarkan UID Firebase, jadi akun yang berbeda
tidak saling melihat tugas atau transaksi. Akun baru dimulai dari data kosong,
sedangkan data lama dari versi sebelumnya dimigrasikan ke akun pertama yang
masuk.

Tugas, transaksi, dan profil juga disinkronkan ke Cloud Firestore. Perubahan
lokal langsung ditulis ke Firestore saat auto-backup aktif, dan snapshot cloud
diterapkan kembali secara real-time. Tombol **Sinkronkan Sekarang** mengunggah
seluruh data lokal tanpa menghapus data cloud yang sudah ada. Status sinkron di
halaman Cadangan Cloud berasal dari metadata Firestore, bukan status simulasi.
Pengaturan dan tema tetap disimpan lokal. Status login tidak disimpan sebagai
flag lokal; sesi dikelola oleh Firebase Authentication.

### Data keuangan

- Saldo tersisa: `Rp356.010`.
- Pengeluaran bulan ini: `Rp143.990` dari limit `Rp1.200.000`.
- Transaksi contoh: Batagor depan kampus, Spotify Premium, Kiriman Orang Tua,
  Grab Food, dan Kopi Kenangan.
- Nilai negatif merepresentasikan pengeluaran, sedangkan nilai positif
  merepresentasikan pemasukan.

### Data tugas

Tersedia 10 tugas contoh, antara lain:

- Laporan Praktikum Pemrograman Web.
- Quiz Bab 4 Probabilitas & Statistik.
- Ambil Laundry dan Cuci Sepatu.
- Latihan Calisthenics dan Jogging 5KM.
- Bayar uang kos dan token listrik.
- Rapat BEM, riset topik skripsi, serta tugas organisasi.

Data tugas memiliki kategori seperti `Tugas Kuliah`, `Pribadi`, `Laundry`,
`Olahraga`, `Keuangan`, dan `Organisasi`. Dua tugas contoh berstatus selesai;
tugas lain dipakai untuk memperagakan status mendesak dan deadline.

### Data pengaturan awal

- Tiga kategori notifikasi aktif.
- Limit anggaran bulanan: `Rp1.200.000`.
- Auto backup dan kunci biometrik aktif.
- Model NLP: `Model lokal v2.1`.

## Skenario Simulasi

### 1. Menambah transaksi

1. Buka tab **Keuangan**.
2. Pilih **Pemasukan** atau **Pengeluaran**.
3. Masukkan nominal, kategori, dan deskripsi, lalu simpan.
4. Untuk input berbasis kalimat, gunakan **Brain Dump** dari Home.

### 2. Menambah dan menyelesaikan tugas

1. Dari Home pilih **Tambah Tugas**, atau buka tab **Tugas**.
2. Isi judul, kategori, dan deadline, lalu pilih **Simpan Tugas**.
3. Buka tab **Tugas** untuk melihat tugas baru.
4. Tandai tugas sebagai selesai atau buka detailnya untuk mengedit.

### 3. Simulasi NLP / Brain Dump

Buka **Profil > Simulasi NLP**, masukkan satu kalimat, lalu pilih **Deteksi
Kategori**. Parser lokal mengenali kategori berdasarkan kata kunci:

| Kategori         | Contoh kata kunci                                              | Contoh input                |
| ---------------- | -------------------------------------------------------------- | --------------------------- |
| Tugas            | `tugas`, `submit`, `kerjakan`, `todo`, `revisi`                | `Submit tugas mobile besok` |
| Pengeluaran      | `beli`, `bayar`, `jajan`, `makan`, `belanja`, `uang`, `rupiah` | `Bayar makan siang`         |
| Jadwal           | `besok`, `lusa`, `jadwal`, `meeting`, `rapat`, `jam`, `hari`   | `Rapat organisasi besok`    |
| Belum terdeteksi | Tidak ada kata kunci di atas                                   | `Saya sedang santai`        |

Fitur ini adalah simulasi pencocokan kata kunci lokal, bukan integrasi model AI
eksternal.

### 4. Scan struk dengan kamera

1. Dari Home pilih **Scan Struk** atau tombol **Scan** di tab Keuangan.
2. Saat pertama kali digunakan, aplikasi meminta izin kamera. Setelah diizinkan,
   preview kamera langsung tampil di dalam halaman Scan tanpa membuka aplikasi
   kamera terpisah.
3. Arahkan kamera ke struk, lalu tekan tombol shutter. Foto hasil jepretan
   ditampilkan pada layar konfirmasi. OCR dan rincian struk masih disimulasikan;
   koreksi nominal jika diperlukan.
4. Pilih **Konfirmasi & Catat** untuk menyimpan transaksi beserta path foto.

Foto struk disimpan di cache aplikasi, sedangkan data transaksi dan path foto
disimpan di penyimpanan lokal. Jika izin kamera ditolak permanen, aplikasi
menyediakan tombol menuju pengaturan izin.

### 5. Pengaturan Profil

Dari tab **Profil**, skenario yang tersedia adalah:

- Mengaktifkan/nonaktifkan notifikasi deadline, limit anggaran, dan Roasting AI.
- Menjalankan sinkronisasi Cloud Firestore dan melihat status sinkron terakhir.
- Mengubah limit anggaran.
- Mengaktifkan/nonaktifkan kunci biometrik.
- Membuka simulasi NLP.
- Menguji alur logout Firebase dan masuk kembali dengan email/password atau
  Google Sign-In.
- Mengubah tema Dark/Light melalui toggle tema.

Autentikasi email/password dan Google Sign-In dijalankan melalui Firebase.
Pesan kesalahan umum seperti email belum terdaftar, kata sandi salah, atau
masalah koneksi ditampilkan dalam bahasa Indonesia.
