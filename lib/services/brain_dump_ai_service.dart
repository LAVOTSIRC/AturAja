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
  final String? dueDate;
  final String? dueTime;

  const BrainDumpItem({
    required this.type,
    required this.title,
    this.description,
    this.amount,
    this.category,
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
      'due_date': Schema.string(nullable: true),
      'due_time': Schema.string(nullable: true),
    },
    optionalProperties: [
      'description',
      'amount',
      'category',
      'due_date',
      'due_time',
    ],
  );

  static final List<SafetySetting> _permissiveSafetySettings = <SafetySetting>[
    SafetySetting(HarmCategory.harassment, HarmBlockThreshold.none, null),
    SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.none, null),
    SafetySetting(
      HarmCategory.sexuallyExplicit,
      HarmBlockThreshold.none,
      null,
    ),
    SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.none, null),
  ];

  late final GenerativeModel _model = _firebaseAI.generativeModel(
    model: 'gemini-3.5-flash-lite',
    safetySettings: _permissiveSafetySettings,
    generationConfig: GenerationConfig(
      responseMimeType: 'application/json',
      responseSchema: Schema.object(
        properties: {
          'items': Schema.array(items: _itemSchema, minItems: 1, maxItems: 10),
        },
      ),
      temperature: 0.1,
      maxOutputTokens: 1200,
    ),
    systemInstruction: Content.system(
      'Kamu adalah parser Brain Dump pintar yang sangat tangguh dan toleran untuk aplikasi AturAja mahasiswa. '
      'JANGAN PERNAH MENOLAK input pengguna meskipun kalimatnya tidak lengkap, singkatan, typo, gaul, '
      'curhat emosional, marah-marah, atau mengandung kata-kata kasar/umpatan/tidak sopan (seperti anjing, bangsat, goblok, tai, sialan, brengsek, dll). '
      'Jika ada kata kasar, umpatan, atau kalimat tidak jelas, abaikan dan bersihkan kata kasarnya, '
      'lalu langsung pikirkan sendiri maksud inti perintah pengguna untuk mengubahnya menjadi judul dan deskripsi Tugas atau Keuangan yang sopan, rapi, dan jelas. '
      'Jika data keuangan tidak memiliki nominal eksplisit (misal hanya "beli makan sialan" atau "bayar parkir"), '
      'perkirakan nominal wajar dalam rupiah untuk mahasiswa di Indonesia (misal makan/minum 15000, kopi/jajan 12000, parkir 2000, bensin 25000, laundry 20000, kos 650000, belanja 50000, lainnya 10000) agar tetap menjadi item keuangan yang valid. '
      'Jika kalimat sangat singkat atau tidak jelas apakah keuangan atau tugas, ubah menjadi item task (tugas) yang masuk akal sesuai konteks mahasiswa. '
      'Ekstrak semua aktivitas Keuangan (pemasukan/income & pengeluaran/expense) '
      'maupun Tugas/Jadwal (task/schedule) dari teks Bahasa Indonesia, termasuk '
      'jika pengguna mencampurkan keuangan dan tugas dalam satu kalimat sekaligus. '
      'Urutkan item Keuangan (income/expense) terlebih dahulu, lalu diikuti item '
      'Tugas/Jadwal (task/schedule). '
      'Kembalikan hanya JSON sesuai schema. '
      'Gunakan amount sebagai integer rupiah tanpa simbol untuk income/expense. '
      'Gunakan due_date format YYYY-MM-DD dan due_time format 24 jam HH:mm '
      'jika tanggal atau jam disebutkan. Konversi keterangan waktu Bahasa '
      'Indonesia ke 24 jam: "jam 6 pagi" = "06:00", "jam 12 siang" = '
      '"12:00", "jam 3 sore" = "15:00", "jam 8 malam" = "20:00", '
      '"jam 7.30" = "07:30". Setiap item bertipe task atau schedule wajib '
      'memiliki due_date dan due_time. Jika tanggal tidak disebut, pakai '
      'tanggal referensi hari ini dari pesan pengguna. Jika jam tidak disebut, '
      'pakai jam referensi (pukul) dari pesan pengguna. Tanggal referensi '
      'juga dipakai untuk menafsirkan tanggal relatif seperti hari ini, besok, '
      'lusa, atau tanggal N bulan ini. '
      'Buat title yang singkat, sopan, dan spesifik. '
      'Buat description sebagai kalimat Bahasa Indonesia yang lengkap, sopan, rapi, '
      'dan merangkum aktivitas, tanggal, serta waktu yang disebutkan tanpa menyalin kata kasar. '
      'Kategori transaksi: Makan & Minum, Hiburan, Transport, Belanja, '
      'Gaji, Kiriman, Freelance, atau Lainnya. '
      'Kategori tugas: Tugas Kuliah, Pribadi, Laundry, Olahraga, '
      'Organisasi, Keuangan, atau Lainnya.',
    ),
  );

  Future<List<BrainDumpItem>> parse(String text) async {
    final String input = text.trim();
    if (input.isEmpty) {
      throw const BrainDumpAiException(
        'Tuliskan isi brain dump terlebih dahulu.',
      );
    }
    if (input.length > 1000) {
      throw const BrainDumpAiException(
        'Brain dump terlalu panjang (maksimal 1000 karakter).',
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
      throw BrainDumpAiException('Hasil perbaikan AI tidak dapat dibaca: $error');
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
    if (rawItems is! List || rawItems.isEmpty) {
      throw const BrainDumpAiException('Tidak ada item yang terdeteksi.');
    }

    return rawItems.map((dynamic item) {
      if (item is! Map) {
        throw const FormatException('Item hasil AI bukan object JSON.');
      }
      return BrainDumpItem.fromJson(Map<String, dynamic>.from(item));
    }).toList();
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
                '"06:00". Untuk tugas/jadwal tanpa tanggal atau jam, isi '
                'due_date dengan $referenceDate dan due_time dengan '
                '$referenceTime. Parse atau perbaiki brain dump berikut dan '
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
