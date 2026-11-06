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

  late final GenerativeModel _model = _firebaseAI.generativeModel(
    model: 'gemini-3.5-flash-lite',
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
      'Kamu adalah parser Brain Dump untuk aplikasi AturAja mahasiswa. '
      'Ekstrak semua aktivitas dari teks Bahasa Indonesia. '
      'Kembalikan hanya JSON sesuai schema. '
      'Gunakan amount sebagai integer rupiah tanpa simbol. '
      'Gunakan due_date format YYYY-MM-DD dan due_time format HH:mm jika '
      'tanggal atau jam disebutkan. Gunakan tanggal referensi yang diberikan '
      'di pesan pengguna untuk menafsirkan tanggal relatif. Jangan mengarang '
      'tanggal atau nominal. '
      'Buat title yang singkat tetapi spesifik, bukan hanya nama aktivitas '
      'yang terlalu umum. Contoh: "Jogging pagi", bukan "Jogging". '
      'Buat description sebagai kalimat Bahasa Indonesia yang lengkap, rapi, '
      'dan merangkum aktivitas, tanggal, serta waktu yang disebutkan. Jangan '
      'menyalin brain dump mentah apa adanya. '
      'Kategori transaksi: Makan & Minum, Hiburan, Transport, Belanja, '
      'Gaji, Kiriman, Freelance, atau Lainnya. '
      'Kategori tugas: Tugas Kuliah, Pribadi, Laundry, Olahraga, '
      'Organisasi, Keuangan, atau Lainnya.',
    ),
  );

  Future<List<BrainDumpItem>> parse(String text) async {
    final String input = text.trim();
    if (input.length < 5) {
      throw const BrainDumpAiException(
        'Brain dump minimal harus berisi 5 karakter.',
      );
    }
    if (input.length > 1000) {
      throw const BrainDumpAiException(
        'Brain dump terlalu panjang (maksimal 1000 karakter).',
      );
    }

    try {
      final GenerateContentResponse response = await _generateWithRetry(input);
      final String? raw = response.text;
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

      final List<BrainDumpItem> items = rawItems.map((dynamic item) {
        if (item is! Map) {
          throw const FormatException('Item hasil AI bukan object JSON.');
        }
        return BrainDumpItem.fromJson(Map<String, dynamic>.from(item));
      }).toList();

      return items;
    } on BrainDumpAiException {
      rethrow;
    } on FormatException catch (error) {
      throw BrainDumpAiException('Hasil Gemini tidak dapat dibaca: $error');
    } on FirebaseAIException catch (error) {
      throw BrainDumpAiException('Gemini gagal memproses brain dump: $error');
    }
  }

  Future<GenerateContentResponse> _generateWithRetry(String input) async {
    FirebaseAIException? lastError;
    final DateTime now = DateTime.now();
    final String referenceDate =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';

    for (int attempt = 1; attempt <= _maxAttempts; attempt++) {
      try {
        return await _model
            .generateContent([
              Content.text(
                'Tanggal hari ini adalah $referenceDate. '
                'Tafsirkan "tanggal N bulan ini" sebagai tanggal N pada '
                'bulan dan tahun tersebut. Tafsirkan "jam 6 pagi" sebagai '
                '"06:00". Parse brain dump berikut dan kembalikan JSON sesuai '
                'schema:\n$input',
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
