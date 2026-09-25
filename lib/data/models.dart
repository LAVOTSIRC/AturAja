class TransactionItem {
  final int id;
  final String label;
  final int amount; // negative = expense, positive = income
  final String cat;
  final String time;
  final String date;
  final bool consumtive;
  final String? receiptImagePath;

  const TransactionItem({
    required this.id,
    required this.label,
    required this.amount,
    required this.cat,
    required this.time,
    this.date = 'Hari ini',
    this.consumtive = false,
    this.receiptImagePath,
  });

  TransactionItem copyWith({
    int? id,
    String? label,
    int? amount,
    String? cat,
    String? time,
    String? date,
    bool? consumtive,
    String? receiptImagePath,
    bool clearReceipt = false,
  }) {
    return TransactionItem(
      id: id ?? this.id,
      label: label ?? this.label,
      amount: amount ?? this.amount,
      cat: cat ?? this.cat,
      time: time ?? this.time,
      date: date ?? this.date,
      consumtive: consumtive ?? this.consumtive,
      receiptImagePath: clearReceipt
          ? null
          : (receiptImagePath ?? this.receiptImagePath),
    );
  }
}

class TaskItem {
  final int id;
  final String title;
  final List<String> categories;
  final String description;
  final String deadline;
  final DateTime? dueDate;
  final bool done;

  TaskItem({
    required this.id,
    required this.title,
    List<String>? categories,
    String? sub,
    this.description = '',
    required this.deadline,
    this.dueDate,
    this.done = false,
  }) : categories =
           categories ??
           (sub != null && sub.isNotEmpty ? [sub] : const ['Tugas Kuliah']);

  /// Formatted category list string for displays
  String get sub => categories.isNotEmpty ? categories.join(', ') : 'Pribadi';

  /// Calculates if task is overdue (past deadline)
  bool get isOverdue {
    if (done) return false;
    if (dueDate != null) {
      return dueDate!.isBefore(DateTime.now());
    }
    return false;
  }

  /// Automatically calculates if task is urgent (< 24 hours remaining)
  bool get urgent {
    if (done || isOverdue) return false;
    if (dueDate != null) {
      final now = DateTime.now();
      final diff = dueDate!.difference(now);
      return diff.inHours < 24 && diff.inHours >= 0;
    }
    final lower = deadline.toLowerCase();
    return lower.contains('hari ini') ||
        lower.contains('besok') ||
        lower.contains('23:59') ||
        lower.contains('08:00') ||
        lower.contains('1 hari') ||
        lower.contains('jam');
  }

  TaskItem copyWith({
    int? id,
    String? title,
    List<String>? categories,
    String? sub,
    String? description,
    String? deadline,
    DateTime? dueDate,
    bool? done,
  }) => TaskItem(
    id: id ?? this.id,
    title: title ?? this.title,
    categories: categories ?? (sub != null ? [sub] : this.categories),
    description: description ?? this.description,
    deadline: deadline ?? this.deadline,
    dueDate: dueDate ?? this.dueDate,
    done: done ?? this.done,
  );
}

final List<TransactionItem> transactionStore = [
  TransactionItem(
    id: 1,
    label: 'Batagor depan kampus',
    amount: -15000,
    cat: 'food',
    time: '10:42',
    date: 'Hari ini',
  ),
  TransactionItem(
    id: 2,
    label: 'Spotify Premium',
    amount: -54990,
    cat: 'entertainment',
    time: '09:00',
    date: 'Hari ini',
    consumtive: true,
  ),
  TransactionItem(
    id: 3,
    label: 'Kiriman Orang Tua',
    amount: 500000,
    cat: 'income',
    time: '08:30',
    date: 'Hari ini',
  ),
  TransactionItem(
    id: 4,
    label: 'Grab Food',
    amount: -45000,
    cat: 'food',
    time: '13:15',
    date: 'Kemarin',
    consumtive: true,
  ),
  TransactionItem(
    id: 5,
    label: 'Kopi Kenangan',
    amount: -29000,
    cat: 'entertainment',
    time: '07:50',
    date: 'Kemarin',
    consumtive: true,
  ),
];

final DateTime _now = DateTime.now();

final List<TaskItem> sampleTasks = [
  TaskItem(
    id: 1,
    title: 'Laporan Praktikum Pemrograman Web (Modul 5)',
    categories: const ['Tugas Kuliah'],
    description: 'Buat REST API backend dengan Laravel/Express dan frontend React/Flutter. Sertakan file SQL database, Postman collection, dan screenshot hasil run.',
    deadline: 'Hari ini, 23:59',
    dueDate: DateTime(_now.year, _now.month, _now.day, 23, 59),
  ),
  TaskItem(
    id: 2,
    title: 'Quiz Bab 4 Probabilitas & Statistik',
    categories: const ['Tugas Kuliah', 'Pribadi'],
    description: 'Pelajari distribusi Normal, Binomial, dan Regresi Linear. Siapkan kalkulator saintifik dan kertas HVS sebelum quiz dibuka di portal LMS kampus.',
    deadline: 'Besok, 08:00',
    dueDate: _now.add(const Duration(hours: 18)),
  ),
  TaskItem(
    id: 3,
    title: 'Ambil Laundry Sehari Selesai & Cuci Sepatu',
    categories: const ['Laundry', 'Pribadi'],
    description: 'Ambil 4.5 kg baju bersih di Laundry Kilat Express depan gang. Jangan lupa bayar Rp28.000 via QRIS dan minta nota transaksi.',
    deadline: 'Hari ini, 18:00',
    dueDate: DateTime(_now.year, _now.month, _now.day, 18, 0),
  ),
  TaskItem(
    id: 4,
    title: 'Latihan Routine Calisthenics & Jogging 5KM',
    categories: const ['Olahraga', 'Pribadi'],
    description: 'Target lari 5 km keliling lapangan gelanggang olahraga kampus dilanjutkan push-up 4 set dan pull-up 3 set untuk menjaga kebugaran tubuh.',
    deadline: 'Besok, 16:30',
    dueDate: _now.add(const Duration(hours: 26)),
  ),
  TaskItem(
    id: 5,
    title: 'Bayar Uang Kos Bulan Ini & Token Listrik PLN',
    categories: const ['Keuangan', 'Pribadi'],
    description: 'Transfer uang sewa kamar kos Rp650.000 ke rekening Ibu Kos + Beli token listrik PLN Rp50.000 di aplikasi mobile banking.',
    deadline: '2 hari lagi, 12:00',
    dueDate: _now.add(const Duration(days: 2)),
  ),
  TaskItem(
    id: 6,
    title: 'Rapat Pleno BEM & Penyusunan Proposal Event',
    categories: const ['Organisasi', 'Tugas Kuliah'],
    description: 'Rapat kerja gabungan divisi Acara dan Humas di Sekretariat BEM Lt.2. Agenda utama pembahasan sponsorship dan timeline Dies Natalis.',
    deadline: '3 hari lagi',
    dueDate: _now.add(const Duration(days: 3)),
  ),
  TaskItem(
    id: 7,
    title: 'Belanja Sembako & Meal Prep Mingguan Hemat',
    categories: const ['Pribadi', 'Keuangan'],
    description: 'Belanja dada ayam, telur, sayur mayur, dan buah di Pasar Tradisional terdekat untuk stok makanan hemat seminggu anak kos.',
    deadline: 'Sabtu, 09:00',
    dueDate: _now.add(const Duration(days: 4)),
  ),
  TaskItem(
    id: 8,
    title: 'Riset Topik Skripsi & Review 3 Jurnal SINTA 2',
    categories: const ['Tugas Kuliah', 'Pribadi'],
    description: 'Cari dan rangkum 3 jurnal penelitian terbaru tentang penerapan Machine Learning/AI pada Aplikasi Mobile. Siapkan draft latar belakang.',
    deadline: 'Minggu depan',
    dueDate: _now.add(const Duration(days: 7)),
  ),
  TaskItem(
    id: 9,
    title: 'Diskusi Kelompok Makalah Kewirausahaan Digital',
    categories: const ['Tugas Kuliah', 'Organisasi'],
    description: 'Brainstorming ide bisnis Startup Digital bersama tim di Co-Working Space perpustakaan. Finalisasi slide presentasi Canva.',
    deadline: 'Selesai',
    dueDate: _now.add(const Duration(days: -1)),
    done: true,
  ),
  TaskItem(
    id: 10,
    title: 'Pengisian Form KRS & Verifikasi Dosen Pembimbing',
    categories: const ['Tugas Kuliah', 'Keuangan'],
    description: 'Konsultasi KRS matakuliah semester 5 dengan Dosen Pembimbing Akademik, cetak lembar persetujuan, dan unggah ke Portal Akademik Kampus.',
    deadline: 'Selesai',
    dueDate: _now.add(const Duration(days: -2)),
    done: true,
  ),
];
