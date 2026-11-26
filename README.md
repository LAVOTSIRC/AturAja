# AturAja

AturAja adalah aplikasi Flutter untuk membantu mahasiswa mengelola tugas, jadwal, dan keuangan pribadi. Aplikasi memiliki target Android dan iOS. Panduan menjalankan proyek di bawah berfokus pada Android.

## Fitur

| Fitur | Yang bisa dilakukan |
| --- | --- |
| Home | Melihat ringkasan tugas dan keuangan, serta membuka Tambah Tugas, Scan Struk, dan Brain Dump. |
| Tugas | Menambah, mengedit, menghapus, dan menandai tugas selesai. Tugas dapat dicari dan difilter berdasarkan status serta kategori. Tenggat mendukung tanggal dan jam. |
| Keuangan | Mencatat pemasukan dan pengeluaran, melihat rincian per kategori, serta mengatur batas anggaran bulanan. |
| Scan Struk | Mengambil foto atau memilih gambar dari galeri. ML Kit membaca teks di perangkat, lalu Gemini melalui Firebase AI menstrukturkan hasilnya. Parser lokal tersedia sebagai cadangan. Hasil dapat dikoreksi sebelum dicatat. |
| Brain Dump | Mengubah catatan bebas menjadi beberapa transaksi, tugas, atau jadwal. Hasil Gemini dapat disunting sebelum disimpan. Parser lokal tersedia jika permintaan AI gagal. Jadwal disimpan sebagai tugas. |
| Simulasi NLP | Mencoba klasifikasi teks berdasarkan kata kunci melalui layar tersendiri di pengaturan. |
| Notifikasi | Mengatur pengingat tenggat, peringatan anggaran pada 80% dan 100%, serta pesan Roasting untuk anggaran, tenggat, dan ringkasan harian. |
| Akun dan privasi | Mendaftar dan masuk dengan email serta kata sandi, masuk dengan Google, mengubah profil, mengatur PIN atau biometrik, mengekspor data JSON/CSV, dan menghapus akun. |
| Cadangan cloud | Mengatur pencadangan otomatis, memulai sinkronisasi manual, dan melihat status sinkronisasi. |

## Menjalankan di Android

Proyek mendeklarasikan Dart `^3.13.2` dan menggunakan Android SDK Platform 37 untuk kompilasi. Siapkan Flutter SDK yang menyertakan versi Dart yang kompatibel, Android SDK, JDK 17, dan perangkat Android atau emulator.

1. Periksa lingkungan dan pasang dependency dari root proyek.

   ```bash
   flutter doctor
   flutter pub get
   ```

2. Siapkan konfigurasi Firebase Android, Google Sign-In, dan App Check sesuai [panduan setup kolaborasi](SETUP_KOLABORASI.md).
3. Pilih perangkat dan jalankan aplikasi.

   ```bash
   flutter devices
   flutter run
   ```

Setelah splash screen, aplikasi membuka layar masuk atau tab Home sesuai sesi Firebase. Empat tab utama adalah Home, Keuangan, Tugas, dan Profil.

## Struktur proyek

| Lokasi | Isi |
| --- | --- |
| [lib/main.dart](lib/main.dart) | Inisialisasi Firebase, App Check, notifikasi, tema, dan provider. |
| [lib/config/](lib/config/) | Routing dengan GoRouter dan pengalihan berdasarkan sesi. |
| [lib/screens/](lib/screens/), [lib/widgets/](lib/widgets/) | Layar, form, modal, dan komponen antarmuka. |
| [lib/providers/](lib/providers/) | State aplikasi, sesi, pengaturan, dan tema dengan Provider dan ChangeNotifier. |
| [lib/data/](lib/data/) | Model, serialisasi, penyimpanan lokal, dan repository Firestore. |
| [lib/services/](lib/services/) | Autentikasi, AI, kamera, OCR, notifikasi, kunci aplikasi, dan ekspor. |
| [lib/theme/](lib/theme/), [lib/utils/](lib/utils/) | Tema Material 3, tipografi, validasi, format, dan parsing jadwal. |
| [android/](android/), [ios/](ios/) | Host native Kotlin dan Swift, konfigurasi build, ikon, dan splash screen. |
| [assets/](assets/), [tool/](tool/), [test/](test/) | Gambar dan font, alat pembuatan aset, serta tes. |

Dependency langsung dideklarasikan di [pubspec.yaml](pubspec.yaml). Versi yang terkunci tersedia di [pubspec.lock](pubspec.lock).

## Penyimpanan dan sinkronisasi

SharedPreferences menyimpan snapshot JSON per UID Firebase, termasuk tugas, transaksi, profil, pengaturan, dan tema. Akun baru dimulai dari data kosong. Data contoh untuk state guest didefinisikan di [lib/data/models.dart](lib/data/models.dart).

Cloud Firestore menyinkronkan tugas, transaksi, dan profil serta menyediakan cache offline di sisi SDK. Pengaturan dan tema disimpan lokal. Data cloud memakai struktur berikut.

```text
users/{uid}/
├── profile/main
├── tasks/{taskId}
├── transactions/{transactionId}
└── meta/state
```

[Aturan Firestore](firestore.rules) membatasi akses berdasarkan UID pemilik dan juga menyediakan jalur `settings/{documentId}` yang belum dipakai untuk sinkronisasi pengaturan. Sinkronisasi manual mengunggah data lokal dan mempertahankan dokumen cloud dengan ID lain. Foto struk berada di direktori dokumen aplikasi. Firestore menyimpan path sebagai bagian dari transaksi, sehingga file fotonya tetap di perangkat asal.

## Perintah pengembangan

Jalankan dari root proyek, kecuali saat mengikuti perintah khusus platform di panduan setup.

| Perintah | Kegunaan |
| --- | --- |
| `flutter analyze` | Memeriksa kode Dart dan lint. |
| `flutter test` | Menjalankan tes Dart dan widget. |
| `flutter build apk --debug` | Membuat APK debug. |
| `flutter build apk --release` | Membuat APK rilis. Build memakai signing debug jika `android/key.properties` belum tersedia. |
| `dart run tool/generate_splash_icon.dart` | Membuat ulang aset splash Android 12 ke atas. |
| `dart run flutter_native_splash:create` | Membuat ulang splash native. |
| `dart run flutter_launcher_icons` | Membuat ulang ikon aplikasi. |

Tes aturan Firestore dijalankan lewat emulator. Perintahnya tersedia di [panduan setup kolaborasi](SETUP_KOLABORASI.md#tes-aturan-firestore).
