import 'dart:async';
import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart';

enum BrainDumpItemType {
  income,
  expense,
  task,
  schedule,
  unknown;

  static BrainDumpItemType fromValue(Object? value) {
    return switch (value) {
      'income' => BrainDumpItemType.income,
      'expense' => BrainDumpItemType.expense,
      'task' => BrainDumpItemType.task,
      'schedule' => BrainDumpItemType.schedule,
      _ => BrainDumpItemType.unknown,
    };
  }
}

class BrainDumpItem {
  final BrainDumpItemType type;
  final String title;
  final String? description;
  final int? amount;
  final String? category;
  final String? transactionDate;
  final String? dueDate;
  final String? dueTime;

  const BrainDumpItem({
    required this.type,
    required this.title,
    this.description,
    this.amount,
    this.category,
    this.transactionDate,
    this.dueDate,
    this.dueTime,
  });

  bool get isFinance =>
      type == BrainDumpItemType.income || type == BrainDumpItemType.expense;

  bool get isTask =>
      type == BrainDumpItemType.task ||
      type == BrainDumpItemType.schedule ||
      type == BrainDumpItemType.unknown;

  BrainDumpItem copyWith({
    BrainDumpItemType? type,
    String? title,
    String? description,
    int? amount,
    String? category,
    String? transactionDate,
    String? dueDate,
    String? dueTime,
    bool clearDescription = false,
    bool clearAmount = false,
    bool clearCategory = false,
    bool clearDueDate = false,
    bool clearDueTime = false,
  }) {
    return BrainDumpItem(
      type: type ?? this.type,
      title: title ?? this.title,
      description: clearDescription ? null : (description ?? this.description),
      amount: clearAmount ? null : (amount ?? this.amount),
      category: clearCategory ? null : (category ?? this.category),
      transactionDate: transactionDate ?? this.transactionDate,
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      dueTime: clearDueTime ? null : (dueTime ?? this.dueTime),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'type': type.name,
    'title': title,
    if (description != null) 'description': description,
    if (amount != null) 'amount': amount,
    if (category != null) 'category': category,
    if (transactionDate != null) 'transaction_date': transactionDate,
    if (dueDate != null) 'due_date': dueDate,
    if (dueTime != null) 'due_time': dueTime,
  };

  factory BrainDumpItem.fromJson(Map<String, dynamic> json) {
    final Object? rawAmount = json['amount'];
    final int? amount = rawAmount is num ? rawAmount.toInt() : null;
    final String title = (json['title'] as String? ?? '').trim();
    if (title.isEmpty) {
      throw const FormatException('Hasil AI tidak memiliki judul item.');
    }

    return BrainDumpItem(
      type: BrainDumpItemType.fromValue(json['type']),
      title: title,
      description: _nullableString(json['description']),
      amount: amount,
      category: _nullableString(json['category']),
      transactionDate: _nullableString(json['transaction_date']),
      dueDate: _nullableString(json['due_date']),
      dueTime: _nullableString(json['due_time']),
    );
  }

  static String? _nullableString(Object? value) {
    if (value is! String) {
      return null;
    }
    final String result = value.trim();
    return result.isEmpty ? null : result;
  }
}

class BrainDumpAiException implements Exception {
  final String message;

  const BrainDumpAiException(this.message);

  @override
  String toString() => message;
}

class BrainDumpAiService {
  static const int maxInputLength = 5000;
  static const Duration _requestTimeout = Duration(seconds: 15);
  static const int _maxAttempts = 2;

  BrainDumpAiService({FirebaseAI? firebaseAI})
    : _firebaseAI = firebaseAI ?? FirebaseAI.googleAI();

  final FirebaseAI _firebaseAI;

  static final Schema _itemSchema = Schema.object(
    properties: {
      'type': Schema.enumString(
        enumValues: ['income', 'expense', 'task', 'schedule', 'unknown'],
      ),
      'title': Schema.string(),
      'description': Schema.string(nullable: true),
      'amount': Schema.integer(nullable: true, minimum: 0),
      'category': Schema.string(nullable: true),
      'transaction_date': Schema.string(nullable: true),
      'due_date': Schema.string(nullable: true),
      'due_time': Schema.string(nullable: true),
    },
    optionalProperties: [
      'description',
      'amount',
      'category',
      'transaction_date',
      'due_date',
      'due_time',
    ],
  );

  static final List<SafetySetting> _permissiveSafetySettings = <SafetySetting>[
    SafetySetting(HarmCategory.harassment, HarmBlockThreshold.none, null),
    SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.none, null),
    SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.none, null),
    SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.none, null),
  ];

  late final GenerativeModel _model = _firebaseAI.generativeModel(
    model: 'gemini-3.5-flash-lite',
    safetySettings: _permissiveSafetySettings,
    generationConfig: GenerationConfig(
      responseMimeType: 'application/json',
      responseSchema: Schema.object(
        properties: {'items': Schema.array(items: _itemSchema, maxItems: 60)},
      ),
      temperature: 0.1,
      maxOutputTokens: 8192,
    ),
    systemInstruction: Content.system(
      'Ubah catatan bebas bahasa Indonesia menjadi draf AturAja. Baca seluruh '
      'konteks, termasuk bahasa gaul, singkatan, daftar, serta rujukan antarkalimat. '
      'Satu aktivitas atau transaksi independen menjadi satu item. Ekstrak semua '
      'item meskipun tercampur dalam satu kalimat; pertahankan urutan tiap jenis. '
      'Gabungkan konteks yang melengkapi item sama, dan jangan buat duplikat. '
      'Abaikan kutipan, percakapan, komentar, contoh, pembatalan, dan penyangkalan '
      'yang tidak diminta untuk dicatat. Jika tidak ada item, kembalikan items kosong. '
      'Catatan boleh seluruhnya expense, income, task, atau schedule. '
      'Judul kelompok seperti "pengeluaran kemarin:" memberi jenis dan tanggal '
      'untuk semua baris di bawahnya. Nama barang diikuti nominal (mis. "nasi 15k", '
      '"parkir 2000") sudah cukup sebagai satu transaksi meski tanpa kata beli. '
      'Baca daftar bernomor, bullet, tabel, dan daftar dipisah koma. '
      'Pisahkan setiap baris item, termasuk untuk tanggal yang sudah lewat. '
      'Contoh: "pengeluaran kemarin: nasi 15k, kopi 12k, pulsa 50k" '
      'menghasilkan tiga expense bertanggal kemarin dan tanpa tugas. '
      'Isi transaction_date YYYY-MM-DD memakai tanggal transaksi atau tanggal '
      'judul kelompok; hitung kata kemarin dan N hari lalu dari tanggal referensi. '
      'Jika tanggal transaksi tidak disebut, biarkan transaction_date null. '
      'expense adalah pengeluaran yang sudah terjadi atau diminta untuk dicatat. '
      'income adalah pemasukan yang sudah diterima atau diminta untuk dicatat. '
      'Rencana membeli, kewajiban membayar, atau janji transfer yang belum terjadi '
      'adalah task, walaupun nominal disebutkan. Pertemuan atau agenda pada waktu '
      'tertentu adalah schedule; pekerjaan yang harus selesai adalah task. '
      'Contoh: "udah bayar kos 650rb, besok bayar listrik 100rb, '
      'revisi bab 2 dan kirim slide Jumat jam 9" menghasilkan satu expense dan tiga task. '
      'Contoh: "tadi beli nasi 15rb sama kopi 12rb, ibu transfer 500rb, '
      'rapat BEM lusa jam 8 malam" menghasilkan dua expense, satu income, dan satu schedule. '
      'Jangan membuat transaksi tambahan dari total, saldo, atau rincian yang '
      'sudah termasuk dalam nominal item lain. Angka bab, jam, tanggal, kuantitas, '
      'dan nominal rencana tugas bukan nominal transaksi. Gunakan integer rupiah '
      'untuk transaksi. Jika nominal transaksi belum diketahui, biarkan amount null. '
      'Terapkan tanggal atau jam bersama hanya pada aktivitas yang dirujuk. '
      'Gunakan due_date YYYY-MM-DD dan due_time HH:mm untuk tugas dan jadwal jika diketahui. '
      'Isi judul dan deskripsi singkat dalam bahasa Indonesia. Pertahankan detail '
      'penting seperti nominal kewajiban dan konteks tugas tanpa menambah fakta. '
      'Kategori pengeluaran: Makan & Minum, Hiburan, Transport, Belanja, Lainnya. '
      'Kategori pemasukan: Gaji, Kiriman, Freelance, Lainnya. Kategori tugas: '
      'Tugas Kuliah, Pribadi, Laundry, Olahraga, Organisasi, Keuangan, Lainnya. '
      'Kembalikan hanya JSON sesuai schema.',
    ),
  );

  Future<List<BrainDumpItem>> parse(String text) async {
    final String input = text.trim();
    if (input.isEmpty) {
      throw const BrainDumpAiException(
        'Tuliskan isi brain dump terlebih dahulu.',
      );
    }
    if (input.length > maxInputLength) {
      throw const BrainDumpAiException(
        'Brain dump terlalu panjang (maksimal $maxInputLength karakter).',
      );
    }

    try {
      final GenerateContentResponse response = await _generateWithRetry(input);
      return _decodeItems(response.text);
    } on BrainDumpAiException {
      rethrow;
    } on FormatException catch (error) {
      throw BrainDumpAiException('Hasil Gemini tidak dapat dibaca: $error');
    } on FirebaseAIException catch (error) {
      throw BrainDumpAiException('Gemini gagal memproses brain dump: $error');
    }
  }

  /// Meminta AI memperbaiki seluruh atau sebagian daftar item berdasarkan
  /// instruksi pengguna.
  Future<List<BrainDumpItem>> refineItems({
    required List<BrainDumpItem> currentItems,
    required String instruction,
    String? originalPrompt,
  }) async {
    if (currentItems.isEmpty) {
      throw const BrainDumpAiException('Tidak ada item untuk diperbaiki.');
    }
    final String cleanInstruction = instruction.trim();
    final String currentJson = jsonEncode(
      currentItems.map((BrainDumpItem item) => item.toJson()).toList(),
    );
    final String prompt =
        'Daftar item saat ini (JSON):\n$currentJson\n\n'
        '${originalPrompt != null && originalPrompt.trim().isNotEmpty ? 'Teks brain dump awal: "${originalPrompt.trim()}"\n\n' : ''}'
        'Instruksi perbaikan dari pengguna: '
        '"${cleanInstruction.isEmpty ? 'Perbaiki dan rapikan judul, kategori, nominal, tanggal/jam, serta deskripsi agar lebih akurat dan jelas.' : cleanInstruction}"\n\n'
        'Kembalikan daftar item yang sudah diperbaiki sesuai schema JSON. '
        'Pertahankan jumlah dan urutan item kecuali instruksi meminta perubahan.';

    try {
      final GenerateContentResponse response = await _generateWithRetry(prompt);
      return _decodeItems(response.text);
    } on BrainDumpAiException {
      rethrow;
    } on FormatException catch (error) {
      throw BrainDumpAiException(
        'Hasil perbaikan AI tidak dapat dibaca: $error',
      );
    } on FirebaseAIException catch (error) {
      throw BrainDumpAiException('Gemini gagal memperbaiki item: $error');
    }
  }

  List<BrainDumpItem> _decodeItems(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      throw const BrainDumpAiException('Gemini tidak mengembalikan hasil.');
    }

    final dynamic decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const BrainDumpAiException('Format hasil Gemini tidak valid.');
    }
    final dynamic rawItems = decoded['items'];
    if (rawItems is! List) {
      throw const BrainDumpAiException('Tidak ada item yang terdeteksi.');
    }

    return rawItems
        .map((dynamic item) {
          if (item is! Map) {
            throw const FormatException('Item hasil AI bukan object JSON.');
          }
          return BrainDumpItem.fromJson(Map<String, dynamic>.from(item));
        })
        .where((BrainDumpItem item) => item.type != BrainDumpItemType.unknown)
        .toList();
  }

  Future<GenerateContentResponse> _generateWithRetry(String input) async {
    FirebaseAIException? lastError;
    final DateTime now = DateTime.now();
    final String referenceDate =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    final String referenceTime =
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';

    for (int attempt = 1; attempt <= _maxAttempts; attempt++) {
      try {
        return await _model
            .generateContent([
              Content.text(
                'Tanggal hari ini adalah $referenceDate pukul $referenceTime. '
                'Tafsirkan "tanggal N bulan ini" sebagai tanggal N pada '
                'bulan dan tahun tersebut. Tafsirkan "jam 6 pagi" sebagai '
                '"06:00". Gunakan tanggal dan jam referensi untuk '
                'menafsirkan waktu relatif. Parse atau perbaiki brain dump berikut dan '
                'kembalikan JSON sesuai schema:\n$input',
              ),
            ])
            .timeout(_requestTimeout);
      } on TimeoutException {
        throw const BrainDumpAiException(
          'Gemini terlalu lama merespons. Coba lagi atau gunakan mode offline.',
        );
      } on FirebaseAIException catch (error) {
        lastError = error;
        if (!_isTransient(error) || attempt == _maxAttempts) {
          rethrow;
        }
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    }

    throw lastError ?? const BrainDumpAiException('Gemini gagal merespons.');
  }

  bool _isTransient(FirebaseAIException error) {
    final String message = error.message.toLowerCase();
    return message.contains('high demand') ||
        message.contains('temporarily') ||
        message.contains('"status": "internal"') ||
        message.contains('internal server error') ||
        message.contains('http 500');
  }
}
