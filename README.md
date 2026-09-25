# AturAja

AturAja adalah aplikasi mobile untuk membantu mahasiswa mengatur tugas,
keuangan, dan rutinitas harian dalam satu tempat. Project ini dibuat dengan
Flutter dan saat ini menggunakan data lokal/dummy untuk kebutuhan demonstrasi.

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

Project tidak membutuhkan API key, database, akun cloud, atau file `.env`.

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
detik, kemudian masuk ke `MainShell`. Navigasi utama terdiri dari tab Home,
Keuangan, Tugas, dan Profil.

> Catatan: screen login tersedia sebagai alur simulasi setelah logout dari
> Profil, tetapi bukan screen pertama saat aplikasi dijalankan.

## Command Run

| Command                                   | Kegunaan                                                       |
| ----------------------------------------- | -------------------------------------------------------------- |
| `flutter pub get`                         | Mengunduh dependency project.                                  |
| `flutter run`                             | Menjalankan aplikasi pada device/emulator aktif.               |
| `flutter run -d <device_id>`              | Menjalankan aplikasi pada device tertentu.                     |
| `flutter analyze`                         | Memeriksa error dan lint Dart/Flutter.                         |
| `flutter test`                            | Menjalankan widget test.                                       |
| `flutter build apk --debug`               | Membuat APK debug.                                             |
| `flutter build apk --release`             | Membuat APK release dengan signing debug untuk kebutuhan demo. |
| `dart run tool/generate_splash_icon.dart` | Membuat ulang asset icon splash Android 12+.                   |

Jika asset splash diubah, jalankan juga generator splash berikut sebelum build:

```bash
dart run flutter_native_splash:create
```

## Dummy Data

Semua data demo didefinisikan di `lib/data/models.dart` dan state akan kembali
ke kondisi awal ketika aplikasi dimulai ulang.

### Data keuangan

- Saldo tersisa: `Rp856.000`.
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

### 1. Menambah transaksi cepat

1. Buka tab **Home**.
2. Pilih **Catat** untuk membuka form transaksi cepat.
3. Masukkan nominal dan deskripsi transaksi, lalu simpan.
4. Untuk input berbasis kalimat, pilih **Brain Dump**.

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

### 4. Simulasi scan struk

1. Dari Home pilih **Scan Struk** atau tombol scan pada bagian bawah layar.
2. Pilih **Proses foto struk** untuk menjalankan simulasi pemrosesan lokal.
3. Konfirmasi nominal default `Rp28.500`, atau ubah ke angka positif lain.
4. Pilih konfirmasi untuk menutup screen scan.

Fitur ini belum menggunakan kamera atau OCR sungguhan; area kamera dan proses
pembacaan struk hanya mensimulasikan jeda pemrosesan.

### 5. Pengaturan Profil

Dari tab **Profil**, skenario yang tersedia adalah:

- Mengaktifkan/nonaktifkan notifikasi deadline, limit anggaran, dan Roasting AI.
- Menjalankan sinkronisasi cloud simulasi.
- Mengubah limit anggaran.
- Mengaktifkan/nonaktifkan kunci biometrik.
- Membuka simulasi NLP.
- Menguji alur logout dan login demo.
- Mengubah tema Dark/Light melalui toggle tema.

Login hanya melakukan validasi format email dan password minimal enam karakter;
tidak ada autentikasi server.
