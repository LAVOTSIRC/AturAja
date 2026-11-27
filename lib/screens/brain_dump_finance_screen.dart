import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/id_generator.dart';
import '../data/models.dart';
import '../providers/app_provider.dart';
import '../services/brain_dump_ai_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/theme_scope.dart';
import '../utils/expense_categories.dart';
import '../utils/format.dart';
import '../utils/task_schedule.dart';
import '../widgets/common.dart';
import 'finance_screen.dart';
import 'task_screen.dart';

enum FinanceNoteKind {
  income(label: 'Catatan Keuangan', icon: Icons.savings_outlined),
  expense(label: 'Catatan Pengeluaran', icon: Icons.shopping_bag_outlined);

  const FinanceNoteKind({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

class BrainDumpSaveResult {
  final List<TransactionItem> transactions;
  final List<TaskItem> tasks;

  const BrainDumpSaveResult({required this.transactions, required this.tasks});

  bool get isEmpty => transactions.isEmpty && tasks.isEmpty;

  String get summaryMessage {
    if (transactions.isNotEmpty && tasks.isNotEmpty) {
      return '${transactions.length} catatan keuangan dan ${tasks.length} tugas berhasil dicatat.';
    }
    if (transactions.isNotEmpty) {
      return '${transactions.length} catatan keuangan berhasil dicatat.';
    }
    if (tasks.isNotEmpty) {
      return '${tasks.length} tugas berhasil dicatat.';
    }
    return 'Catatan berhasil disimpan.';
  }
}

const List<String> incomeCategoryLabels = [
  'Gaji',
  'Kiriman',
  'Freelance',
  'Lainnya',
];

const List<String> expenseCategoryLabels = [
  'Makan & Minum',
  'Hiburan',
  'Transport',
  'Belanja',
  'Lainnya',
];

const Map<String, List<String>> incomeKeywords = {
  'Gaji': ['gaji', 'salary', 'bayar kerja'],
  'Kiriman': ['kirim', 'orang tua', 'ibu', 'ayah', 'transfer masuk', 'dibayar'],
  'Freelance': ['freelance', 'proyek', 'honor', 'bonus', 'komisi'],
};

const Map<String, List<String>> expenseKeywords = {
  'Makan & Minum': [
    'makan',
    'minum',
    'kopi',
    'batagor',
    'resto',
    'cafe',
    'warung',
    'nasi',
    'mie',
    'snack',
    'cemilan',
    'susu',
    'roti',
  ],
  'Hiburan': [
    'hiburan',
    'film',
    'movie',
    'nonton',
    'konser',
    'game',
    'steam',
    'spotify',
    'netflix',
    'musik',
  ],
  'Transport': [
    'transport',
    'bensin',
    'gojek',
    'grab',
    'ojek',
    'mobil',
    'parkir',
    'tol',
    'kereta',
    'bus',
    'taksi',
    'listrik',
    'pln',
    'token',
    'pulsa',
  ],
  'Belanja': [
    'belanja',
    'supermarket',
    'indomaret',
    'alfamart',
    'tokopedia',
    'shopee',
    'lazada',
    'sayur',
    'buah',
    'dada ayam',
  ],
};

const List<String> _taskIntentKeywords = [
  'tugas',
  'kumpul',
  'kumpulkan',
  'submit',
  'quiz',
  'kuis',
  'ujian',
  'uts',
  'uas',
  'praktikum',
  'laporan',
  'skripsi',
  'makalah',
  'presentasi',
  'kuliah',
  'kelas',
  'rapat',
  'meeting',
  'bem',
  'organisasi',
  'proker',
  'jogging',
  'joging',
  'olahraga',
  'gym',
  'lari',
  'fitness',
  'ambil laundry',
  'cuci baju',
  'cuci sepatu',
  'belajar',
  'revisi',
  'kerjakan',
  'nyicil',
  'jadwal',
];

const List<String> _financeIntentKeywords = [
  'beli',
  'bayar',
  'jajan',
  'belanja',
  'transfer',
  'kirim',
  'dapat',
  'gaji',
  'honor',
  'bonus',
  'topup',
  'top up',
  'ongkir',
  'parkir',
  'bensin',
  'makan',
  'minum',
  'ngopi',
  'kopi',
  'sewa',
];

const List<String> _rudeWords = [
  'anjing',
  'anjir',
  'anjay',
  'anjg',
  'anj',
  'bangsat',
  'bgst',
  'babi',
  'goblok',
  'goblog',
  'tolol',
  'bego',
  'bodoh',
  'tai',
  'tahi',
  'kampret',
  'sialan',
  'sial',
  'brengsek',
  'bajingan',
  'kontol',
  'memek',
  'asu',
  'jancok',
  'jancuk',
  'cok',
  'cuk',
  'fak',
  'fuck',
  'shit',
  'damn',
  'hell',
  'wtf',
  'kesel',
  'capek',
  'cape',
  'males',
  'muak',
  'gedeg',
  'banget',
  'parah',
];

/// Membersihkan kata-kata tidak sopan/umpatan dari teks agar judul dan deskripsi
/// menjadi sopan dan rapi tanpa menolak perintah pengguna.
String sanitizeBrainDumpText(String raw) {
  String cleaned = raw;
  for (final String word in _rudeWords) {
    cleaned = cleaned.replaceAll(
      RegExp('\\b${RegExp.escape(word)}\\b', caseSensitive: false),
      ' ',
    );
  }
  cleaned = cleaned
      .replaceAll(RegExp(r'[!@#$%^&*~`]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return cleaned;
}

int? parseBrainDumpAmount(String raw) {
  // Hapus pola jam seperti "jam 08:00", "pukul 19.30", "15:00" dan tanggal
  // seperti "2026-11-20" atau "12/11/2026" agar tidak salah terbaca sebagai nominal.
  final String cleaned = raw
      .replaceAll(
        RegExp(
          r'\b(?:jam|pukul|pk)\.?\s*\d{1,2}(?:[:.]\d{2})?\s*(?:pagi|siang|sore|malam)?\b',
          caseSensitive: false,
        ),
        ' ',
      )
      .replaceAll(
        RegExp(
          r'\b\d{1,2}[:.]\d{2}\s*(?:pagi|siang|sore|malam)?\b',
          caseSensitive: false,
        ),
        ' ',
      )
      .replaceAll(
        RegExp(
          r'\b\d{4}-\d{1,2}-\d{1,2}\b|\b\d{1,2}/\d{1,2}(?:/\d{2,4})?\b',
          caseSensitive: false,
        ),
        ' ',
      )
      .replaceAll(
        RegExp(
          r'\b(?:tanggal|bab|modul|semester|kelompok|sks|km|kg)\s*\d+\b',
          caseSensitive: false,
        ),
        ' ',
      )
      .replaceAll(
        RegExp(
          r'\b\d+\s*(?:hari|minggu|bulan|jam|menit|km|kg)\b',
          caseSensitive: false,
        ),
        ' ',
      );

  final RegExp amountRegex = RegExp(
    r'(?:rp\.?\s*)?(\d+(?:[.,]\d+)*)\s*(ribu|rb|juta|jt|k)\b|(?:rp\.?\s*)(\d+(?:[.,]\d+)*)\b|\b(\d{1,3}(?:[.,]\d{3})+|\d{3,})\b',
    caseSensitive: false,
  );

  final RegExpMatch? match = amountRegex.firstMatch(cleaned);
  if (match == null) {
    return null;
  }

  if (match.group(1) != null) {
    final String token = match.group(1)!.replaceAll(' ', '');
    final String unit = (match.group(2) ?? '').toLowerCase();
    final double base = double.tryParse(token.replaceAll(',', '.')) ?? 0;
    if (base <= 0) {
      return null;
    }
    if (unit == 'k' || unit == 'rb' || unit == 'ribu') {
      return (base * 1000).round();
    }
    return (base * 1000000).round();
  }

  final String rawDigits = (match.group(3) ?? match.group(4) ?? '').replaceAll(
    RegExp('[.,\\s]'),
    '',
  );
  final int? parsed = int.tryParse(rawDigits);
  if (parsed == null || parsed <= 0) {
    return null;
  }
  return parsed;
}

String detectIncomeCategory(String text) {
  final String lower = text.toLowerCase();
  for (final MapEntry<String, List<String>> entry in incomeKeywords.entries) {
    if (entry.value.any(lower.contains)) {
      return entry.key;
    }
  }
  return 'Lainnya';
}

String detectExpenseCategory(String text) {
  final String lower = text.toLowerCase();
  for (final MapEntry<String, List<String>> entry in expenseKeywords.entries) {
    if (entry.value.any(lower.contains)) {
      return entry.key;
    }
  }
  return 'Lainnya';
}

String detectTaskCategory(String text) {
  final String lower = text.toLowerCase();
  if (lower.contains('kalkulus') ||
      lower.contains('quiz') ||
      lower.contains('kuis') ||
      lower.contains('tugas') ||
      lower.contains('laporan') ||
      lower.contains('praktikum') ||
      lower.contains('kuliah') ||
      lower.contains('skripsi') ||
      lower.contains('makalah') ||
      lower.contains('ujian')) {
    return 'Tugas Kuliah';
  }
  if (lower.contains('laundry') || lower.contains('cuci')) {
    return 'Laundry';
  }
  if (lower.contains('jogging') ||
      lower.contains('joging') ||
      lower.contains('gym') ||
      lower.contains('olahraga') ||
      lower.contains('lari') ||
      lower.contains('fitness')) {
    return 'Olahraga';
  }
  if (lower.contains('bem') ||
      lower.contains('rapat') ||
      lower.contains('meeting') ||
      lower.contains('organisasi') ||
      lower.contains('proker')) {
    return 'Organisasi';
  }
  if (lower.contains('bayar') ||
      lower.contains('kos') ||
      lower.contains('uang') ||
      lower.contains('tagihan')) {
    return 'Keuangan';
  }
  return 'Pribadi';
}

class BrainDumpFinanceScreen extends StatefulWidget {
  const BrainDumpFinanceScreen({super.key});

  @override
  State<BrainDumpFinanceScreen> createState() => _BrainDumpFinanceScreenState();
}

class _BrainDumpFinanceScreenState extends State<BrainDumpFinanceScreen> {
  static const List<String> mixedSuggestions = [
    'Makan batagor 15k lalu besok jam 08:00 quiz kalkulus',
    'Ibu kirim 500rb untuk kos',
    'Belanja sayur 120rb',
    'Bensin 29k dan rapat BEM besok jam 19:00',
  ];

  final TextEditingController dumpController = TextEditingController();

  bool isProcessing = false;
  bool isRefining = false;
  int? refiningIndex;
  bool hasPreview = false;
  List<BrainDumpItem> parsedItems = <BrainDumpItem>[];
  String? errorMessage;
  String? infoMessage;

  @override
  void dispose() {
    dumpController.dispose();
    super.dispose();
  }

  /// Mengurutkan item Keuangan terlebih dahulu, lalu diikuti item Tugas.
  List<BrainDumpItem> _orderFinanceThenTasks(List<BrainDumpItem> items) {
    final List<BrainDumpItem> finance = <BrainDumpItem>[];
    final List<BrainDumpItem> tasks = <BrainDumpItem>[];
    for (final BrainDumpItem item in items) {
      if (item.isFinance) {
        finance.add(item);
      } else {
        tasks.add(item);
      }
    }
    return <BrainDumpItem>[...finance, ...tasks];
  }

  BrainDumpItem _normalizeItem(BrainDumpItem item, {String? sourceSegment}) {
    final String source = sourceSegment ?? item.title;
    final String sanitizedTitle = sanitizeBrainDumpText(item.title);
    if (item.isFinance) {
      final bool isIncome = item.type == BrainDumpItemType.income;
      final int? amount = item.amount;
      String category = (item.category ?? '').trim();
      final List<String> allowed = isIncome
          ? incomeCategoryLabels
          : expenseCategoryLabels;
      if (!allowed.contains(category)) {
        category = isIncome
            ? detectIncomeCategory(source)
            : detectExpenseCategory(source);
      }
      final String finalTitle = sanitizedTitle.isEmpty
          ? (isIncome ? 'Pemasukan $category' : 'Pengeluaran $category')
          : '${sanitizedTitle[0].toUpperCase()}${sanitizedTitle.substring(1)}';
      return item.copyWith(
        title: finalTitle,
        amount: amount,
        category: category,
      );
    }

    // Item Tugas / Jadwal
    final DateTime due = dueDateForBrainDump(
      aiDate: item.dueDate,
      aiTime: item.dueTime,
      sourceText: source,
    );
    final String isoDate =
        '${due.year.toString().padLeft(4, '0')}-'
        '${due.month.toString().padLeft(2, '0')}-'
        '${due.day.toString().padLeft(2, '0')}';
    final String hmTime = formatDueTimeLabel(due);

    String category = (item.category ?? '').trim();
    if (category.isEmpty ||
        !availableCategories.any(
          (String c) => category.toLowerCase().contains(c.toLowerCase()),
        )) {
      category = detectTaskCategory('${item.title} ${item.description ?? ''}');
    } else {
      final List<String> matched = category
          .split(',')
          .map((String e) => e.trim())
          .where(availableCategories.contains)
          .toList();
      category = matched.isEmpty
          ? detectTaskCategory(item.title)
          : matched.join(', ');
    }

    final String finalTitle = sanitizedTitle.isEmpty
        ? 'Tugas $category'
        : '${sanitizedTitle[0].toUpperCase()}${sanitizedTitle.substring(1)}';
    final String deadlineText = formatDeadline(due);
    final String sanitizedDesc = sanitizeBrainDumpText(item.description ?? '');
    final String description = sanitizedDesc.isNotEmpty
        ? sanitizedDesc
        : 'Jadwal $finalTitle pada ${deadlineText.toLowerCase()}.';

    return BrainDumpItem(
      type: item.type == BrainDumpItemType.schedule
          ? BrainDumpItemType.schedule
          : BrainDumpItemType.task,
      title: finalTitle,
      description: description,
      category: category,
      dueDate: isoDate,
      dueTime: hmTime,
    );
  }

  Future<void> _processBrainDump() async {
    final String text = dumpController.text.trim();
    if (text.isEmpty) {
      setState(() => errorMessage = 'Tuliskan isi brain dump terlebih dahulu.');
      return;
    }

    setState(() {
      isProcessing = true;
      errorMessage = null;
      infoMessage = null;
      hasPreview = false;
    });

    List<BrainDumpItem> items = <BrainDumpItem>[];
    bool usedLocal = false;
    try {
      items = (await BrainDumpAiService().parse(text))
          .map(_normalizeItem)
          .toList();
    } catch (_) {
      // Parser lokal juga menangani daftar jika Gemini gagal atau kosong.
    }
    if (!mounted) return;
    if (items.isEmpty) {
      items = _localItems(text);
      usedLocal = items.isNotEmpty;
    }
    setState(() {
      isProcessing = false;
      parsedItems = _orderFinanceThenTasks(items);
      hasPreview = items.isNotEmpty;
      if (items.isEmpty) {
        errorMessage =
            'Tidak ada transaksi, tugas, atau jadwal yang terdeteksi.';
      } else if (usedLocal) {
        infoMessage = 'Periksa hasil pembacaan lokal sebelum menyimpan.';
      }
    });
  }

  String? _transactionDate(String text) {
    final DateTime now = DateTime.now();
    final String lower = text.toLowerCase();
    final int? daysAgo = int.tryParse(
      RegExp(r'\b(\d+)\s+hari\s+(?:yang\s+)?lalu\b').firstMatch(lower)?[1] ??
          '',
    );
    final DateTime? date = switch (lower) {
      _ when daysAgo != null && daysAgo <= 36500 => DateTime(
        now.year,
        now.month,
        now.day - daysAgo,
      ),
      _
          when RegExp(r'\b(?:kemarin\s+lusa|dua\s+hari\s+(?:yang\s+)?lalu)\b')
              .hasMatch(lower) =>
        DateTime(now.year, now.month, now.day - 2),
      _ when RegExp(r'\bkemarin\b').hasMatch(lower) => DateTime(
        now.year,
        now.month,
        now.day - 1,
      ),
      _ => parseDueDate(text, now: now),
    };
    return date?.toIso8601String().split('T').first;
  }

  /// Membaca klausa transaksi dan tugas ketika Gemini tidak tersedia.
  List<BrainDumpItem> _localItems(String text) {
    final List<String> segments = text
        .split(
          RegExp(
            r'[;\n]+|(?<!\d)[.!?]\s+|,\s+|:\s*(?=[^\d\s])|'
            r'\b(?:terus|kemudian|selanjutnya|habis itu|setelah itu|sekalian)\s+|'
            r'\blalu\s+(?=(?:beli|bayar|revisi|kirim|ambil|kerjakan|besok|lusa|rapat|tugas)\b)|'
            r'\b(?:dan|serta|sama)\s+(?=(?:revisi|kirim|belajar|hubungi|beli|bayar|jajan|makan|minum|belanja|transfer|dapat|gaji|kumpul|kumpulkan|kerjakan|tugas|quiz|kuis|rapat|meeting|jogging|ambil|besok|lusa|hari ini|malam ini)\b)',
            caseSensitive: false,
          ),
        )
        .map(
          (String segment) => segment
              .replaceFirst(RegExp(r'^\s*(?:[-*?]\s*|\d+[.)]\s+)'), '')
              .trim(),
        )
        .where((String segment) => segment.isNotEmpty)
        .toList();
    BrainDumpItemType? groupType;
    String? groupDate;
    final List<BrainDumpItem> items = <BrainDumpItem>[];

    for (final String segment in segments) {
      final String cleanedSegment = sanitizeBrainDumpText(
        segment
            .replaceFirst(
              RegExp(
                r'^(?:dan|lalu|terus|kemudian|sama|juga|sekalian)\s+',
                caseSensitive: false,
              ),
              '',
            )
            .trim(),
      );
      final String effectiveSegment = cleanedSegment.isEmpty
          ? segment.trim()
          : cleanedSegment;
      if (effectiveSegment.isEmpty) {
        continue;
      }

      final String lower = effectiveSegment.toLowerCase();
      final int? explicitAmount = parseBrainDumpAmount(effectiveSegment);
      final Match? group = RegExp(
        r'^(?:(?:daftar|catatan|rekap)\s+)?(pengeluaran|pemasukan|belanja|tugas|jadwal)\b',
      ).firstMatch(lower);
      final String? lineDate = _transactionDate(effectiveSegment);
      if (group != null &&
          explicitAmount == null &&
          (lineDate != null ||
              lower.replaceFirst(RegExp(r'[:\s]+$'), '') == group[0])) {
        groupType = switch (group[1]) {
          'pemasukan' => BrainDumpItemType.income,
          'tugas' || 'jadwal' => BrainDumpItemType.task,
          _ => BrainDumpItemType.expense,
        };
        groupDate = lineDate;
        continue;
      }
      if (RegExp(r'^(?:sub\s*total|total|saldo|kembalian)\b').hasMatch(lower)) {
        continue;
      }
      if (lineDate != null &&
          RegExp(
            r'^(?:kemarin|hari ini|\d+\s+hari\s+(?:yang\s+)?lalu|\d{1,4}[-/]\d{1,2}[-/]\d{2,4})$',
          ).hasMatch(lower)) {
        groupDate = lineDate;
        continue;
      }

      final bool hasTaskWord = _taskIntentKeywords.any(lower.contains);
      final bool hasFinanceWord = _financeIntentKeywords.any(lower.contains);
      final bool hasSchedule = parseSchedule(effectiveSegment) != null;

      final bool isFuture = RegExp(
        r'\b(?:besok|lusa|minggu depan|nanti|akan|harus|belum|jangan lupa|rencana)\b',
      ).hasMatch(lower);
      final bool isCompleted = RegExp(
        r'\b(?:sudah|udah|tadi|kemarin|barusan)\b',
      ).hasMatch(lower);
      final bool isNegated = RegExp(
        r'\b(?:tidak jadi|nggak jadi|gak jadi|batal|tidak perlu|jangan catat)\b',
      ).hasMatch(lower);
      if (isNegated) continue;

      final bool hasAmountAndLabel =
          explicitAmount != null &&
          RegExp(r'[a-zA-Z]').hasMatch(effectiveSegment);
      final bool isFinanceGroup =
          groupType == BrainDumpItemType.expense ||
          groupType == BrainDumpItemType.income;
      final bool isFinanceSegment =
          !isFuture &&
          switch (groupType) {
            BrainDumpItemType.task => hasFinanceWord && isCompleted,
            _ =>
              (hasFinanceWord || hasAmountAndLabel) &&
                  (!hasTaskWord ||
                      isCompleted ||
                      (isFinanceGroup && hasAmountAndLabel)),
          };
      if (!isFinanceSegment &&
          !hasTaskWord &&
          !hasFinanceWord &&
          groupType != BrainDumpItemType.task &&
          !hasSchedule &&
          !RegExp(
            r'^(?:baca|tulis|buat|hubungi|kirim|siapkan|cek|urus|ambil|antar|ingat)\b',
          ).hasMatch(lower)) {
        continue;
      }

      if (isFinanceSegment) {
        final bool isIncome =
            groupType == BrainDumpItemType.income ||
            lower.contains('dapat') ||
            lower.contains('gaji') ||
            lower.contains('honor') ||
            lower.contains('bonus') ||
            lower.contains('kiriman') ||
            lower.contains('dikirim') ||
            lower.contains('ibu kirim') ||
            lower.contains('ayah kirim') ||
            lower.contains('ayah transfer') ||
            lower.contains('ibu transfer') ||
            lower.contains('transfer masuk') ||
            lower.contains('dibayar');

        final String category = isIncome
            ? detectIncomeCategory(effectiveSegment)
            : detectExpenseCategory(effectiveSegment);

        String title = cleanedSegment
            .replaceAll(
              RegExp(
                r'(?:rp\.?\s*)?\d+(?:[.,]\d+)*\s*(?:ribu|rb|juta|jt|k)?',
                caseSensitive: false,
              ),
              '',
            )
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        title = title
            .replaceAll(
              RegExp(r'^(?:untuk|buat|sebesar)\s+', caseSensitive: false),
              '',
            )
            .trim();
        if (title.isEmpty) {
          title = isIncome ? 'Pemasukan $category' : 'Pengeluaran $category';
        } else {
          title = '${title[0].toUpperCase()}${title.substring(1)}';
        }

        items.add(
          BrainDumpItem(
            type: isIncome
                ? BrainDumpItemType.income
                : BrainDumpItemType.expense,
            title: title,
            description: explicitAmount == null
                ? 'Isi nominal aktual sebelum menyimpan.'
                : null,
            amount: explicitAmount,
            category: category,
            transactionDate: lineDate ?? groupDate,
          ),
        );
        continue;
      }

      // Termasuk rencana pembayaran atau pembelian yang belum terjadi.
      final DateTime due =
          parseSchedule(effectiveSegment, useCurrentTimeAsDefault: true) ??
          dueAtCurrentTime();
      final String category = detectTaskCategory(effectiveSegment);
      String title = cleanedSegment
          .replaceAll(
            RegExp(
              r'\b(?:besok|lusa|hari ini|minggu depan|malam ini|pagi ini|siang ini|sore ini)\b',
              caseSensitive: false,
            ),
            '',
          )
          .replaceAll(
            RegExp(
              r'\b(?:jam|pukul|pk)\.?\s*\d{1,2}(?:[:.]\d{2})?\s*(?:pagi|siang|sore|malam)?\b',
              caseSensitive: false,
            ),
            '',
          )
          .replaceAll(
            RegExp(
              r'\b\d{1,2}:\d{2}\s*(?:pagi|siang|sore|malam)?\b',
              caseSensitive: false,
            ),
            '',
          )
          .replaceAll(
            RegExp(
              r'^(?:ada|harus|jangan lupa|tolong|mau|pengen|ingin)\s+',
              caseSensitive: false,
            ),
            '',
          )
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      if (title.isEmpty) {
        title = hasSchedule
            ? 'Jadwal kegiatan ($category)'
            : ' kerjakan tugas $category'.trim();
      } else if (title.length < 4 && !hasTaskWord) {
        title = 'Catatan kegiatan: $title';
      }
      title = '${title[0].toUpperCase()}${title.substring(1)}';

      final String isoDate =
          '${due.year.toString().padLeft(4, '0')}-'
          '${due.month.toString().padLeft(2, '0')}-'
          '${due.day.toString().padLeft(2, '0')}';
      final String hmTime = formatDueTimeLabel(due);
      final String deadlineLabel = formatDeadline(due);

      items.add(
        BrainDumpItem(
          type:
              hasSchedule &&
                  RegExp(r'\b(?:rapat|meeting|kelas|janji|pertemuan)\b')
                      .hasMatch(lower)
              ? BrainDumpItemType.schedule
              : BrainDumpItemType.task,
          title: title,
          description:
              'Jadwal ${title.toLowerCase()} pada ${deadlineLabel.toLowerCase()}.',
          category: category,
          dueDate: isoDate,
          dueTime: hmTime,
        ),
      );
    }

    return _orderFinanceThenTasks(items);
  }

  /// Memperbaiki item menggunakan AI atau fallback lokal cerdas bila offline.
  Future<void> _applyAiRefinement({
    required String instruction,
    int? targetIndex,
  }) async {
    if (parsedItems.isEmpty) {
      return;
    }
    setState(() {
      isRefining = true;
      refiningIndex = targetIndex;
      errorMessage = null;
      infoMessage = null;
    });

    try {
      if (targetIndex != null) {
        final BrainDumpItem current = parsedItems[targetIndex];
        final List<BrainDumpItem> refinedList = await BrainDumpAiService()
            .refineItems(
              currentItems: <BrainDumpItem>[current],
              instruction: instruction,
              originalPrompt: dumpController.text,
            );
        if (!mounted) return;
        final BrainDumpItem updated = _normalizeItem(refinedList.first);
        final List<BrainDumpItem> next = List<BrainDumpItem>.of(parsedItems);
        next[targetIndex] = updated;
        setState(() {
          isRefining = false;
          refiningIndex = null;
          parsedItems = _orderFinanceThenTasks(next);
          infoMessage = 'Item "${updated.title}" berhasil diperbaiki AI.';
        });
      } else {
        final List<BrainDumpItem> refinedList = await BrainDumpAiService()
            .refineItems(
              currentItems: parsedItems,
              instruction: instruction,
              originalPrompt: dumpController.text,
            );
        if (!mounted) return;
        final List<BrainDumpItem> normalized = refinedList
            .map(_normalizeItem)
            .toList();
        setState(() {
          isRefining = false;
          refiningIndex = null;
          parsedItems = _orderFinanceThenTasks(normalized);
          infoMessage = 'Semua item berhasil diperbaiki AI.';
        });
      }
    } catch (_) {
      if (!mounted) return;
      // Fallback perbaikan lokal cerdas berdasarkan instruksi pengguna
      final List<BrainDumpItem> next = List<BrainDumpItem>.of(parsedItems);
      if (targetIndex != null) {
        next[targetIndex] = _refineItemLocally(next[targetIndex], instruction);
      } else {
        for (int i = 0; i < next.length; i++) {
          next[i] = _refineItemLocally(next[i], instruction);
        }
      }
      setState(() {
        isRefining = false;
        refiningIndex = null;
        parsedItems = _orderFinanceThenTasks(next);
        infoMessage = targetIndex != null
            ? 'Item berhasil diperbaiki sesuai instruksi.'
            : 'Semua item berhasil disesuaikan sesuai instruksi.';
      });
    }
  }

  BrainDumpItem _refineItemLocally(BrainDumpItem item, String instruction) {
    final String clean = instruction.trim();
    if (clean.isEmpty) {
      return _normalizeItem(item);
    }
    final String lower = clean.toLowerCase();

    // Cek apakah instruksi mengubah tipe item menjadi tugas atau keuangan
    if (lower.contains('ubah jadi tugas') ||
        lower.contains('jadikan tugas') ||
        lower.contains('ini tugas')) {
      final DateTime due =
          parseSchedule(clean, useCurrentTimeAsDefault: true) ??
          dueAtCurrentTime();
      return _normalizeItem(
        BrainDumpItem(
          type: BrainDumpItemType.task,
          title: item.title,
          description: item.description,
          category: detectTaskCategory('$clean ${item.title}'),
          dueDate:
              '${due.year.toString().padLeft(4, '0')}-${due.month.toString().padLeft(2, '0')}-${due.day.toString().padLeft(2, '0')}',
          dueTime: formatDueTimeLabel(due),
        ),
        sourceSegment: clean,
      );
    }

    if (lower.contains('ubah jadi pemasukan') ||
        lower.contains('jadikan pemasukan') ||
        lower.contains('ini pemasukan')) {
      final int? amount = parseBrainDumpAmount(clean) ?? item.amount;
      return _normalizeItem(
        BrainDumpItem(
          type: BrainDumpItemType.income,
          title: item.title,
          amount: amount,
          category: detectIncomeCategory('$clean ${item.title}'),
        ),
        sourceSegment: clean,
      );
    }

    if (lower.contains('ubah jadi pengeluaran') ||
        lower.contains('jadikan pengeluaran') ||
        lower.contains('ini pengeluaran')) {
      final int? amount = parseBrainDumpAmount(clean) ?? item.amount;
      return _normalizeItem(
        BrainDumpItem(
          type: BrainDumpItemType.expense,
          title: item.title,
          amount: amount,
          category: detectExpenseCategory('$clean ${item.title}'),
        ),
        sourceSegment: clean,
      );
    }

    if (item.isFinance) {
      final int? newAmount = parseBrainDumpAmount(clean);
      String newCategory = item.category ?? 'Lainnya';
      final List<String> candidates = item.type == BrainDumpItemType.income
          ? incomeCategoryLabels
          : expenseCategoryLabels;
      for (final String cat in candidates) {
        if (lower.contains(cat.toLowerCase())) {
          newCategory = cat;
          break;
        }
      }

      String newTitle = item.title;
      final RegExpMatch? titleMatch = RegExp(
        r'(?:judul(?:nya)?|nama(?:nya)?|ganti|ubah)\s+(?:jadi|ke)?\s*["\x27]?([^"\x27,.]+)["\x27]?',
        caseSensitive: false,
      ).firstMatch(clean);
      if (titleMatch != null && titleMatch.group(1)!.trim().isNotEmpty) {
        final String candidateTitle = titleMatch.group(1)!.trim();
        if (parseBrainDumpAmount(candidateTitle) == null) {
          newTitle =
              '${candidateTitle[0].toUpperCase()}${candidateTitle.substring(1)}';
        }
      } else if (newAmount == null &&
          !candidates.any((String c) => lower.contains(c.toLowerCase()))) {
        newTitle = '${clean[0].toUpperCase()}${clean.substring(1)}';
      }

      return _normalizeItem(
        item.copyWith(
          title: newTitle,
          amount: newAmount ?? item.amount,
          category: newCategory,
        ),
      );
    } else {
      final DateTime? newSchedule = parseSchedule(clean);
      final DateTime currentDue = dueDateForBrainDump(
        aiDate: item.dueDate,
        aiTime: item.dueTime,
        sourceText: item.title,
      );
      final DateTime? parsedDate = parseDueDate(clean);
      final ClockTime? parsedTime = parseClockTime(clean);
      final DateTime mergedDue = DateTime(
        parsedDate?.year ?? currentDue.year,
        parsedDate?.month ?? currentDue.month,
        parsedDate?.day ?? currentDue.day,
        parsedTime?.hour ?? currentDue.hour,
        parsedTime?.minute ?? currentDue.minute,
      );
      final DateTime finalDue = (parsedDate != null || parsedTime != null)
          ? mergedDue
          : (newSchedule ?? currentDue);

      String newCategory = item.category ?? 'Pribadi';
      for (final String cat in availableCategories) {
        if (lower.contains(cat.toLowerCase())) {
          newCategory = cat;
          break;
        }
      }

      String newTitle = item.title;
      final RegExpMatch? titleMatch = RegExp(
        r'(?:judul(?:nya)?|nama(?:nya)?|ganti|ubah)\s+(?:jadi|ke)?\s*["\x27]?([^"\x27,.]+)["\x27]?',
        caseSensitive: false,
      ).firstMatch(clean);
      if (titleMatch != null && titleMatch.group(1)!.trim().isNotEmpty) {
        final String candidateTitle = titleMatch.group(1)!.trim();
        newTitle =
            '${candidateTitle[0].toUpperCase()}${candidateTitle.substring(1)}';
      }

      final String isoDate =
          '${finalDue.year.toString().padLeft(4, '0')}-'
          '${finalDue.month.toString().padLeft(2, '0')}-'
          '${finalDue.day.toString().padLeft(2, '0')}';
      final String hmTime = formatDueTimeLabel(finalDue);

      return _normalizeItem(
        item.copyWith(
          title: newTitle,
          category: newCategory,
          dueDate: isoDate,
          dueTime: hmTime,
          description:
              'Jadwal $newTitle pada ${formatDeadline(finalDue).toLowerCase()}.',
        ),
      );
    }
  }

  void _showAiRefineSheet({int? targetIndex}) {
    final AppColors c = ThemeScope.of(context).colors;
    final TextEditingController instructionCtrl = TextEditingController();
    final BrainDumpItem? targetItem = targetIndex != null
        ? parsedItems[targetIndex]
        : null;

    final List<String> quickPrompts = targetItem == null
        ? const <String>[
            'Rapikan semua judul dan deskripsi agar lebih jelas',
            'Sesuaikan kategori setiap item dengan tepat',
            'Ubah semua jadwal tugas menjadi besok jam 09:00',
          ]
        : targetItem.isFinance
        ? const <String>[
            'Ubah nominal jadi 25rb',
            'Ganti kategori jadi Makan & Minum',
            'Ubah jadi pemasukan',
          ]
        : const <String>[
            'Ubah jadwal jadi besok jam 08:00',
            'Ganti kategori jadi Tugas Kuliah',
            'Rapikan judul dan deskripsi tugas',
          ];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppSpacing.lg),
              ),
              border: Border.all(color: c.border),
            ),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.xxl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: AppSpacing.sheetHandleWidth,
                    height: AppSpacing.sheetHandleHeight,
                    margin: const EdgeInsets.only(bottom: AppSpacing.md),
                    decoration: BoxDecoration(
                      color: c.surfaceHigh,
                      borderRadius: BorderRadius.circular(AppSpacing.huge),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.xs),
                      decoration: BoxDecoration(
                        color: c.ai.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.auto_fix_high_rounded,
                        color: c.ai,
                        size: AppSpacing.iconSmall,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            targetItem == null
                                ? 'Minta AI Perbaiki Semua'
                                : 'Minta AI Perbaiki Item Ini',
                            style: AppTypography.title(c.text),
                          ),
                          if (targetItem != null)
                            Text(
                              targetItem.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.caption(c.textMuted),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: instructionCtrl,
                  autofocus: true,
                  maxLines: 3,
                  minLines: 2,
                  style: AppTypography.body(c.text),
                  decoration: _inputDecoration(
                    c,
                    hintText: targetItem == null
                        ? 'Contoh: Ubah nominal makan jadi 20rb dan tugas kalkulus jadi lusa jam 10 pagi...'
                        : targetItem.isFinance
                        ? 'Contoh: Ubah nominal jadi 50rb dan kategori Belanja...'
                        : 'Contoh: Ubah jadwalnya jadi besok jam 14:00 kategori Tugas Kuliah...',
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'SARAN INSTRUKSI CEPAT',
                  style: AppTypography.overline(c.textMuted),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: quickPrompts.map((String suggestion) {
                    return GestureDetector(
                      onTap: () => instructionCtrl.text = suggestion,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xxs + 2,
                        ),
                        decoration: BoxDecoration(
                          color: c.surfaceHigh,
                          borderRadius: BorderRadius.circular(AppSpacing.huge),
                          border: Border.all(color: c.border),
                        ),
                        child: Text(
                          suggestion,
                          style: AppTypography.caption(c.textSub),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppSpacing.lg),
                PressableScale(
                  onTap: () {
                    final String instruction = instructionCtrl.text.trim();
                    Navigator.of(sheetContext).pop();
                    _applyAiRefinement(
                      instruction: instruction,
                      targetIndex: targetIndex,
                    );
                  },
                  semanticLabel: 'Jalankan perbaikan AI',
                  child: Container(
                    width: double.infinity,
                    height: AppSpacing.target,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: c.ai,
                      borderRadius: BorderRadius.circular(AppSpacing.md),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.auto_awesome_rounded,
                          size: AppSpacing.iconSmall,
                          color: c.onAccent,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          targetItem == null
                              ? 'Perbaiki Semua dengan AI'
                              : 'Perbaiki Item dengan AI',
                          style: AppTypography.button(c.onAccent),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showManualEditSheet(int index) {
    final BrainDumpItem item = parsedItems[index];
    if (item.isFinance) {
      _showManualEditFinanceSheet(index, item);
    } else {
      _showManualEditTaskSheet(index, item);
    }
  }

  void _showManualEditFinanceSheet(int index, BrainDumpItem item) {
    final AppColors c = ThemeScope.of(context).colors;
    final TextEditingController titleCtrl = TextEditingController(
      text: item.title,
    );
    final TextEditingController amountCtrl = TextEditingController(
      text: item.amount?.toString() ?? '',
    );
    bool isIncome = item.type == BrainDumpItemType.income;
    List<String> categories = isIncome
        ? incomeCategoryLabels
        : expenseCategoryLabels;
    String selectedCategory = categories.contains(item.category)
        ? item.category!
        : categories.first;
    String? modalError;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext ctx, StateSetter setModalState) {
            categories = isIncome
                ? incomeCategoryLabels
                : expenseCategoryLabels;
            if (!categories.contains(selectedCategory)) {
              selectedCategory = categories.first;
            }
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppSpacing.lg),
                  ),
                  border: Border.all(color: c.border),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.xxl,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: AppSpacing.sheetHandleWidth,
                          height: AppSpacing.sheetHandleHeight,
                          margin: const EdgeInsets.only(bottom: AppSpacing.md),
                          decoration: BoxDecoration(
                            color: c.surfaceHigh,
                            borderRadius: BorderRadius.circular(
                              AppSpacing.huge,
                            ),
                          ),
                        ),
                      ),
                      Text(
                        'Edit Catatan Keuangan',
                        style: AppTypography.title(c.text),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (modalError != null) ...[
                        AppErrorMessage(message: modalError!),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      // Jenis Transaksi (Pemasukan / Pengeluaran)
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () =>
                                  setModalState(() => isIncome = false),
                              child: Container(
                                height: AppSpacing.targetCompact,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: !isIncome
                                      ? c.expenseDim
                                      : c.surfaceHigh,
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.sm,
                                  ),
                                  border: Border.all(
                                    color: !isIncome ? c.expense : c.border,
                                  ),
                                ),
                                child: Text(
                                  'Pengeluaran',
                                  style: AppTypography.label(
                                    !isIncome ? c.expense : c.textSub,
                                  ).copyWith(fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setModalState(() => isIncome = true),
                              child: Container(
                                height: AppSpacing.targetCompact,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isIncome
                                      ? c.successDim
                                      : c.surfaceHigh,
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.sm,
                                  ),
                                  border: Border.all(
                                    color: isIncome ? c.success : c.border,
                                  ),
                                ),
                                child: Text(
                                  'Pemasukan',
                                  style: AppTypography.label(
                                    isIncome ? c.success : c.textSub,
                                  ).copyWith(fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Judul / Keterangan',
                        style: AppTypography.meta(c.textMuted),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      TextField(
                        controller: titleCtrl,
                        style: AppTypography.body(c.text),
                        decoration: _inputDecoration(
                          c,
                          hintText: 'Contoh: Makan batagor',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Nominal (Rp)',
                        style: AppTypography.meta(c.textMuted),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      TextField(
                        controller: amountCtrl,
                        keyboardType: TextInputType.number,
                        style: AppTypography.body(c.text),
                        decoration: _inputDecoration(
                          c,
                          hintText: 'Contoh: 15000',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text('Kategori', style: AppTypography.meta(c.textMuted)),
                      const SizedBox(height: AppSpacing.xs),
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: categories.map((String cat) {
                          final bool active = selectedCategory == cat;
                          return GestureDetector(
                            onTap: () =>
                                setModalState(() => selectedCategory = cat),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: AppSpacing.xs,
                              ),
                              decoration: BoxDecoration(
                                color: active ? c.blueDim : c.surfaceHigh,
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.huge,
                                ),
                                border: Border.all(
                                  color: active ? c.blue : c.border,
                                ),
                              ),
                              child: Text(
                                cat,
                                style:
                                    AppTypography.caption(
                                      active ? c.blue : c.textSub,
                                    ).copyWith(
                                      fontWeight: active
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      PressableScale(
                        onTap: () {
                          final String newTitle = titleCtrl.text.trim();
                          final int? newAmount =
                              parseBrainDumpAmount(amountCtrl.text) ??
                              int.tryParse(
                                amountCtrl.text.replaceAll(
                                  RegExp('[^0-9]'),
                                  '',
                                ),
                              );
                          if (newTitle.isEmpty) {
                            setModalState(
                              () => modalError = 'Judul tidak boleh kosong.',
                            );
                            return;
                          }
                          if (newAmount == null ||
                              newAmount <= 0 ||
                              newAmount > kMaxTransactionAmount) {
                            setModalState(
                              () => modalError =
                                  'Masukkan Rp1 sampai ${formatRupiah(kMaxTransactionAmount)}.',
                            );
                            return;
                          }
                          final List<BrainDumpItem> next =
                              List<BrainDumpItem>.of(parsedItems);
                          next[index] = item.copyWith(
                            type: isIncome
                                ? BrainDumpItemType.income
                                : BrainDumpItemType.expense,
                            title: newTitle,
                            amount: newAmount,
                            category: selectedCategory,
                          );
                          Navigator.of(ctx).pop();
                          setState(() {
                            parsedItems = _orderFinanceThenTasks(next);
                            infoMessage =
                                'Catatan keuangan "$newTitle" berhasil diperbarui.';
                          });
                        },
                        semanticLabel: 'Simpan perubahan keuangan',
                        child: Container(
                          width: double.infinity,
                          height: AppSpacing.target,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: c.blue,
                            borderRadius: BorderRadius.circular(AppSpacing.md),
                          ),
                          child: Text(
                            'Simpan Perubahan',
                            style: AppTypography.button(c.onAccent),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showManualEditTaskSheet(int index, BrainDumpItem item) {
    final AppColors c = ThemeScope.of(context).colors;
    final TextEditingController titleCtrl = TextEditingController(
      text: item.title,
    );
    final TextEditingController descCtrl = TextEditingController(
      text: item.description ?? '',
    );
    DateTime selectedDue = dueDateForBrainDump(
      aiDate: item.dueDate,
      aiTime: item.dueTime,
      sourceText: item.title,
    );
    String selectedCategory = availableCategories.firstWhere(
      (String cat) => (item.category ?? '').contains(cat),
      orElse: () => 'Tugas Kuliah',
    );
    String? modalError;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext ctx, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppSpacing.lg),
                  ),
                  border: Border.all(color: c.border),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.xxl,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: AppSpacing.sheetHandleWidth,
                          height: AppSpacing.sheetHandleHeight,
                          margin: const EdgeInsets.only(bottom: AppSpacing.md),
                          decoration: BoxDecoration(
                            color: c.surfaceHigh,
                            borderRadius: BorderRadius.circular(
                              AppSpacing.huge,
                            ),
                          ),
                        ),
                      ),
                      Text('Edit Tugas', style: AppTypography.title(c.text)),
                      const SizedBox(height: AppSpacing.md),
                      if (modalError != null) ...[
                        AppErrorMessage(message: modalError!),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      Text(
                        'Judul Tugas',
                        style: AppTypography.meta(c.textMuted),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      TextField(
                        controller: titleCtrl,
                        style: AppTypography.body(c.text),
                        decoration: _inputDecoration(
                          c,
                          hintText: 'Contoh: Quiz Kalkulus',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text('Kategori', style: AppTypography.meta(c.textMuted)),
                      const SizedBox(height: AppSpacing.xs),
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: availableCategories.map((String cat) {
                          final bool active = selectedCategory == cat;
                          return GestureDetector(
                            onTap: () =>
                                setModalState(() => selectedCategory = cat),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: AppSpacing.xs,
                              ),
                              decoration: BoxDecoration(
                                color: active ? c.blueDim : c.surfaceHigh,
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.huge,
                                ),
                                border: Border.all(
                                  color: active ? c.blue : c.border,
                                ),
                              ),
                              child: Text(
                                cat,
                                style:
                                    AppTypography.caption(
                                      active ? c.blue : c.textSub,
                                    ).copyWith(
                                      fontWeight: active
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Tenggat Waktu',
                        style: AppTypography.meta(c.textMuted),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () async {
                                final DateTime now = DateTime.now();
                                final DateTime? picked = await showDatePicker(
                                  context: ctx,
                                  initialDate: selectedDue,
                                  firstDate: now.subtract(
                                    const Duration(days: 30),
                                  ),
                                  lastDate: DateTime(
                                    now.year + 2,
                                    now.month,
                                    now.day,
                                  ),
                                );
                                if (picked != null) {
                                  setModalState(() {
                                    selectedDue = DateTime(
                                      picked.year,
                                      picked.month,
                                      picked.day,
                                      selectedDue.hour,
                                      selectedDue.minute,
                                    );
                                  });
                                }
                              },
                              child: Container(
                                height: 44,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm,
                                ),
                                decoration: BoxDecoration(
                                  color: c.blueDim,
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.sm,
                                  ),
                                  border: Border.all(color: c.blue),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.calendar_month_rounded,
                                      size: AppSpacing.iconSmall,
                                      color: c.blue,
                                    ),
                                    const SizedBox(width: AppSpacing.xxs),
                                    Text(
                                      formatDueDateLabel(selectedDue),
                                      style: AppTypography.label(c.blue),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: GestureDetector(
                              onTap: () async {
                                final TimeOfDay? picked = await showTimePicker(
                                  context: ctx,
                                  initialTime: TimeOfDay.fromDateTime(
                                    selectedDue,
                                  ),
                                  builder:
                                      (BuildContext context, Widget? child) =>
                                          MediaQuery(
                                            data: MediaQuery.of(context)
                                                .copyWith(
                                                  alwaysUse24HourFormat: true,
                                                ),
                                            child: child!,
                                          ),
                                );
                                if (picked != null) {
                                  setModalState(() {
                                    selectedDue = DateTime(
                                      selectedDue.year,
                                      selectedDue.month,
                                      selectedDue.day,
                                      picked.hour,
                                      picked.minute,
                                    );
                                  });
                                }
                              },
                              child: Container(
                                height: 44,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm,
                                ),
                                decoration: BoxDecoration(
                                  color: c.blueDim,
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.sm,
                                  ),
                                  border: Border.all(color: c.blue),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.schedule_rounded,
                                      size: AppSpacing.iconSmall,
                                      color: c.blue,
                                    ),
                                    const SizedBox(width: AppSpacing.xxs),
                                    Text(
                                      formatDueTimeLabel(selectedDue),
                                      style: AppTypography.label(c.blue),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Deskripsi / Catatan',
                        style: AppTypography.meta(c.textMuted),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      TextField(
                        controller: descCtrl,
                        maxLines: 3,
                        minLines: 2,
                        style: AppTypography.body(c.text),
                        decoration: _inputDecoration(
                          c,
                          hintText: 'Tambahkan rincian tugas...',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      PressableScale(
                        onTap: () {
                          final String newTitle = titleCtrl.text.trim();
                          if (newTitle.isEmpty) {
                            setModalState(
                              () => modalError =
                                  'Judul tugas tidak boleh kosong.',
                            );
                            return;
                          }
                          final String isoDate =
                              '${selectedDue.year.toString().padLeft(4, '0')}-'
                              '${selectedDue.month.toString().padLeft(2, '0')}-'
                              '${selectedDue.day.toString().padLeft(2, '0')}';
                          final String hmTime = formatDueTimeLabel(selectedDue);
                          final List<BrainDumpItem> next =
                              List<BrainDumpItem>.of(parsedItems);
                          next[index] = BrainDumpItem(
                            type: BrainDumpItemType.task,
                            title: newTitle,
                            description: descCtrl.text.trim().isEmpty
                                ? null
                                : descCtrl.text.trim(),
                            category: selectedCategory,
                            dueDate: isoDate,
                            dueTime: hmTime,
                          );
                          Navigator.of(ctx).pop();
                          setState(() {
                            parsedItems = _orderFinanceThenTasks(next);
                            infoMessage =
                                'Tugas "$newTitle" berhasil diperbarui.';
                          });
                        },
                        semanticLabel: 'Simpan perubahan tugas',
                        child: Container(
                          width: double.infinity,
                          height: AppSpacing.target,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: c.blue,
                            borderRadius: BorderRadius.circular(AppSpacing.md),
                          ),
                          child: Text(
                            'Simpan Perubahan',
                            style: AppTypography.button(c.onAccent),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _deleteItem(int index) {
    final BrainDumpItem removed = parsedItems[index];
    final List<BrainDumpItem> next = List<BrainDumpItem>.of(parsedItems)
      ..removeAt(index);
    setState(() {
      parsedItems = next;
      if (parsedItems.isEmpty) {
        hasPreview = false;
      }
      infoMessage = 'Item "${removed.title}" dihapus dari daftar.';
    });
  }

  String _categoryKey(BrainDumpItem item) {
    if (item.type == BrainDumpItemType.income) {
      return switch (item.category) {
        'Gaji' || 'Kiriman' || 'Freelance' => item.category!.toLowerCase(),
        _ => 'income',
      };
    }
    return expenseCategoryKeys[item.category] ?? 'other';
  }

  void _save() {
    if (parsedItems.isEmpty) {
      setState(
        () => errorMessage = 'Belum ada hasil brain dump untuk disimpan.',
      );
      return;
    }

    final int invalidIndex = parsedItems.indexWhere(
      (BrainDumpItem item) =>
          item.isFinance &&
          ((item.amount ?? 0) <= 0 || item.amount! > kMaxTransactionAmount),
    );
    if (invalidIndex != -1) {
      final String title = parsedItems[invalidIndex].title;
      setState(
        () => errorMessage =
            'Edit nominal "$title". Masukkan Rp1 sampai ${formatRupiah(kMaxTransactionAmount)}.',
      );
      return;
    }

    final AppProvider app = context.read<AppProvider>();
    final List<TransactionItem> savedTransactions = <TransactionItem>[];
    final List<TaskItem> savedTasks = <TaskItem>[];

    // 1. Proses dan simpan bagian Keuangan terlebih dahulu
    for (final BrainDumpItem item in parsedItems.where(
      (BrainDumpItem e) => e.isFinance,
    )) {
      final int amount = item.amount!;
      final TransactionItem tx = TransactionItem(
        id: newDocumentId(),
        label: item.title,
        amount: item.type == BrainDumpItemType.income ? amount : -amount,
        cat: _categoryKey(item),
        time: TimeOfDay.now().format(context),
        date: _transactionDate(item.transactionDate ?? '') ?? 'Hari ini',
      );
      savedTransactions.add(tx);
    }

    unawaited(app.addTransactions(savedTransactions));

    // 2. Proses dan simpan bagian Tugas setelah Keuangan
    for (final BrainDumpItem item in parsedItems.where(
      (BrainDumpItem e) => !e.isFinance,
    )) {
      final DateTime due = dueDateForBrainDump(
        aiDate: item.dueDate,
        aiTime: item.dueTime,
        sourceText: item.title,
      );
      final List<String> cats = (item.category ?? '')
          .split(',')
          .map((String s) => s.trim())
          .where(availableCategories.contains)
          .toList();
      final List<String> finalCategories = cats.isEmpty
          ? <String>[detectTaskCategory(item.title)]
          : cats;
      final String deadline = formatDeadline(due);
      final TaskItem task = TaskItem(
        id: newDocumentId(),
        title: item.title,
        categories: finalCategories,
        description: (item.description ?? '').trim().isNotEmpty
            ? item.description!.trim()
            : 'Jadwal ${item.title} pada ${deadline.toLowerCase()}.',
        deadline: deadline,
        dueDate: due,
      );
      app.addTask(task);
      savedTasks.add(task);
    }

    HapticFeedback.lightImpact();
    Navigator.of(context).pop(
      BrainDumpSaveResult(transactions: savedTransactions, tasks: savedTasks),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = ThemeScope.of(context).colors;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Kembali',
        ),
        title: Text('AI Brain Dump', style: AppTypography.titleLarge(c.text)),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (errorMessage != null) ...[
                      AppErrorMessage(message: errorMessage!),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    if (infoMessage != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: c.blueDim,
                          borderRadius: BorderRadius.circular(AppSpacing.sm),
                          border: Border.all(color: c.blue),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.auto_awesome_rounded,
                              size: AppSpacing.iconSmall,
                              color: c.blue,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: Text(
                                infoMessage!,
                                style: AppTypography.caption(c.text),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    if (hasPreview) _previewBody(c) else _inputBody(c),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _inputBody(AppColors c) {
    const Color accent = Colors.deepPurple;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: c.ai.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      size: AppSpacing.iconSmall,
                      color: c.ai,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI Brain Dump Pintar',
                          style: AppTypography.label(c.text)
                              .copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          'Tulis catatan Keuangan, Tugas, atau campuran keduanya sekaligus — AI otomatis memilah Keuangan lalu Tugas.',
                          style: AppTypography.caption(c.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: dumpController,
                autofocus: true,
                maxLines: 4,
                maxLength: BrainDumpAiService.maxInputLength,
                style: AppTypography.bodyLarge(c.text),
                onChanged: (_) {
                  if (errorMessage != null || infoMessage != null) {
                    setState(() {
                      errorMessage = null;
                      infoMessage = null;
                    });
                  }
                },
                decoration: _inputDecoration(
                  c,
                  hintText: 'Contoh: Makan batagor 15k, ibu kirim 500rb, lalu besok jam 08:00 ada quiz kalkulus...',
                ).copyWith(counterText: ''),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'CONTOH BRAIN DUMP (KEUANGAN & TUGAS)',
                style: AppTypography.overline(c.textMuted),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: mixedSuggestions.map((String suggestion) {
                  return PressableScale(
                    onTap: () => setState(() {
                      dumpController.text = suggestion;
                      errorMessage = null;
                      infoMessage = null;
                    }),
                    semanticLabel: 'Gunakan contoh $suggestion',
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: c.surfaceHigh,
                        borderRadius: BorderRadius.circular(AppSpacing.huge),
                        border: Border.all(color: c.border),
                      ),
                      child: Text(
                        suggestion,
                        style: AppTypography.caption(c.textSub),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.lg),
              PressableScale(
                onTap: isProcessing ? null : _processBrainDump,
                semanticLabel: 'Proses Brain Dump dengan AI',
                child: Container(
                  width: double.infinity,
                  height: AppSpacing.target,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(AppSpacing.md),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isProcessing) ...[
                        SizedBox(
                          width: AppSpacing.iconSmall,
                          height: AppSpacing.iconSmall,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: c.onAccent,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          'Memproses...',
                          style: AppTypography.button(c.onAccent),
                        ),
                      ] else ...[
                        Icon(
                          Icons.auto_awesome_rounded,
                          size: AppSpacing.iconSmall,
                          color: c.onAccent,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          'Proses Brain Dump',
                          style: AppTypography.button(c.onAccent),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: AppSpacing.iconSmall - 4,
              color: c.textMuted,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                'AI akan memisahkan Keuangan terlebih dahulu lalu Tugas. '
                'Kamu bisa edit manual atau minta AI memperbaiki hasilnya sebelum disimpan.',
                style: AppTypography.meta(c.textMuted),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _previewBody(AppColors c) {
    final List<(int, BrainDumpItem)> financeEntries = parsedItems.indexed
        .where(((int, BrainDumpItem) entry) => entry.$2.isFinance)
        .toList();
    final List<(int, BrainDumpItem)> taskEntries = parsedItems.indexed
        .where(((int, BrainDumpItem) entry) => !entry.$2.isFinance)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.auto_awesome_rounded,
              size: AppSpacing.iconSmall,
              color: c.ai,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                'Periksa hasil AI sebelum disimpan',
                style: AppTypography.label(c.text)
                    .copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            PressableScale(
              onTap: isRefining ? null : () => _showAiRefineSheet(),
              semanticLabel: 'Perbaiki semua dengan AI',
              tooltip: 'Perbaiki semua dengan AI',
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xxs + 2,
                ),
                decoration: BoxDecoration(
                  color: c.ai.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppSpacing.huge),
                  border: Border.all(color: c.ai),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isRefining && refiningIndex == null) ...[
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: c.ai,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xxs),
                    ] else ...[
                      Icon(Icons.auto_fix_high_rounded, size: 14, color: c.ai),
                      const SizedBox(width: AppSpacing.xxs),
                    ],
                    Text(
                      'Perbaiki Semua (AI)',
                      style: AppTypography.micro(c.ai)
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Ketuk "Edit Manual" untuk mengubah sendiri, atau "Perbaiki AI" pada item tertentu maupun keseluruhan.',
          style: AppTypography.micro(c.textMuted),
        ),
        const SizedBox(height: AppSpacing.md),

        // 1. Bagian Keuangan (diurus pertama)
        if (financeEntries.isNotEmpty) ...[
          _sectionHeader(
            c,
            icon: Icons.account_balance_wallet_outlined,
            title: '1. BAGIAN KEUANGAN (${financeEntries.length})',
            color: c.success,
          ),
          const SizedBox(height: AppSpacing.xs),
          ...financeEntries.map(
            ((int, BrainDumpItem) entry) =>
                _buildFinancePreviewCard(c, entry.$1, entry.$2),
          ),
          const SizedBox(height: AppSpacing.md),
        ],

        // 2. Bagian Tugas (diurus setelah keuangan)
        if (taskEntries.isNotEmpty) ...[
          _sectionHeader(
            c,
            icon: Icons.task_alt_rounded,
            title:
                '${financeEntries.isNotEmpty ? '2. ' : ''}BAGIAN TUGAS (${taskEntries.length})',
            color: c.blue,
          ),
          const SizedBox(height: AppSpacing.xs),
          ...taskEntries.map(
            ((int, BrainDumpItem) entry) =>
                _buildTaskPreviewCard(c, entry.$1, entry.$2),
          ),
          const SizedBox(height: AppSpacing.md),
        ],

        const SizedBox(height: AppSpacing.sm),
        PressableScale(
          onTap: isRefining ? null : _save,
          semanticLabel: 'Simpan semua catatan',
          child: Container(
            width: double.infinity,
            height: AppSpacing.target,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.blue,
              borderRadius: BorderRadius.circular(AppSpacing.md),
            ),
            child: Text(
              'Simpan Semua Catatan',
              style: AppTypography.button(c.onAccent),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: () => setState(() {
              hasPreview = false;
              errorMessage = null;
              infoMessage = null;
            }),
            style: TextButton.styleFrom(
              minimumSize: const Size(
                AppSpacing.targetCompact,
                AppSpacing.target,
              ),
              foregroundColor: c.textMuted,
            ),
            child: Text(
              'Ubah brain dump lagi',
              style: AppTypography.label(c.textMuted),
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader(
    AppColors c, {
    required IconData icon,
    required String title,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: AppSpacing.iconSmall - 2, color: color),
        const SizedBox(width: AppSpacing.xxs),
        Text(
          title,
          style: AppTypography.overline(color)
              .copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.7),
        ),
      ],
    );
  }

  Widget _buildFinancePreviewCard(AppColors c, int index, BrainDumpItem item) {
    final bool income = item.type == BrainDumpItemType.income;
    final Color accent = income ? c.success : c.expense;
    final bool isItemRefining = isRefining && refiningIndex == index;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.sm),
        background: c.surface,
        borderColor: c.border,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: income ? c.successDim : c.expenseDim,
                    borderRadius: BorderRadius.circular(AppSpacing.xs),
                  ),
                  child: Icon(
                    income
                        ? Icons.south_west_rounded
                        : Icons.north_east_rounded,
                    color: accent,
                    size: AppSpacing.iconSmall,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: AppTypography.label(c.text)
                            .copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Pill(
                            text: income ? 'Pemasukan' : 'Pengeluaran',
                            color: accent,
                            background: income ? c.successDim : c.expenseDim,
                          ),
                          if (item.category != null) ...[
                            const SizedBox(width: AppSpacing.xxs),
                            Text(
                              '· ${item.category!}',
                              style: AppTypography.meta(c.textMuted),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      item.amount == null
                          ? 'Isi nominal'
                          : '${income ? '+' : '-'}${formatRupiah(item.amount!)}',
                      style: AppTypography.label(accent)
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                    // Tampilkan juga angka mentah untuk keterbacaan/test compatibility
                    Text(
                      item.amount?.toString() ?? 'Belum diisi',
                      style: AppTypography.micro(c.textMuted),
                    ),
                  ],
                ),
              ],
            ),
            if (item.transactionDate != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Tanggal transaksi: ${item.transactionDate}',
                style: AppTypography.caption(c.textSub),
              ),
            ],
            if (item.description != null &&
                item.description!.trim().isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(item.description!, style: AppTypography.caption(c.textSub)),
            ],
            const SizedBox(height: AppSpacing.xs),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.xs),
            _itemActionRow(c, index: index, isItemRefining: isItemRefining),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskPreviewCard(AppColors c, int index, BrainDumpItem item) {
    final DateTime due = dueDateForBrainDump(
      aiDate: item.dueDate,
      aiTime: item.dueTime,
      sourceText: item.title,
    );
    final String deadlineLabel = formatDeadline(due);
    final bool isItemRefining = isRefining && refiningIndex == index;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.sm),
        background: c.surface,
        borderColor: c.border,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: c.blueDim,
                    borderRadius: BorderRadius.circular(AppSpacing.xs),
                  ),
                  child: Icon(
                    Icons.task_alt_rounded,
                    color: c.blue,
                    size: AppSpacing.iconSmall,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: AppTypography.label(c.text)
                            .copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: AppSpacing.xxs,
                        runSpacing: 4,
                        children: [
                          Pill(
                            text: item.category ?? 'Tugas Kuliah',
                            color: c.blue,
                            background: c.blueDim,
                          ),
                          Pill(
                            text: deadlineLabel,
                            color: c.amber,
                            background: c.amberDim,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (item.description != null &&
                item.description!.trim().isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(item.description!, style: AppTypography.caption(c.textSub)),
            ],
            const SizedBox(height: AppSpacing.xs),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.xs),
            _itemActionRow(c, index: index, isItemRefining: isItemRefining),
          ],
        ),
      ),
    );
  }

  Widget _itemActionRow(
    AppColors c, {
    required int index,
    required bool isItemRefining,
  }) {
    return Row(
      children: [
        Expanded(
          child: PressableScale(
            onTap: isRefining ? null : () => _showManualEditSheet(index),
            semanticLabel: 'Edit manual item ${index + 1}',
            child: Container(
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.surfaceHigh,
                borderRadius: BorderRadius.circular(AppSpacing.xs),
                border: Border.all(color: c.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.edit_outlined, size: 14, color: c.text),
                  const SizedBox(width: 4),
                  Text(
                    'Edit Manual',
                    style: AppTypography.micro(c.text)
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: PressableScale(
            onTap: isRefining
                ? null
                : () => _showAiRefineSheet(targetIndex: index),
            semanticLabel: 'Perbaiki item ${index + 1} dengan AI',
            child: Container(
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.ai.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppSpacing.xs),
                border: Border.all(color: c.ai.withValues(alpha: 0.6)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isItemRefining) ...[
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: c.ai,
                      ),
                    ),
                    const SizedBox(width: 4),
                  ] else ...[
                    Icon(Icons.auto_fix_high_rounded, size: 14, color: c.ai),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    'Perbaiki AI',
                    style: AppTypography.micro(c.ai)
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        PressableScale(
          onTap: isRefining ? null : () => _deleteItem(index),
          semanticLabel: 'Hapus item ${index + 1}',
          tooltip: 'Hapus item',
          child: Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.expenseDim,
              borderRadius: BorderRadius.circular(AppSpacing.xs),
            ),
            child: Icon(
              Icons.delete_outline_rounded,
              size: 16,
              color: c.expense,
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(AppColors c, {required String hintText}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: AppTypography.body(c.textMuted),
      filled: true,
      fillColor: c.surfaceHigh.withValues(alpha: 0.6),
      contentPadding: const EdgeInsets.all(AppSpacing.sm),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.md),
        borderSide: BorderSide(color: c.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.md),
        borderSide: BorderSide(color: c.blue, width: 1.5),
      ),
    );
  }
}
