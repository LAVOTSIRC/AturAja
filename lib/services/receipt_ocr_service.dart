import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';


class ReceiptOcrResult {
  final String merchant;
  final int? total;
  final DateTime? date;
  final List<ReceiptItem> items;
  final String rawText;

  const ReceiptOcrResult({
    required this.merchant,
    required this.total,
    required this.date,
    this.items = const <ReceiptItem>[],
    required this.rawText,
  });

  /// Mengembalikan true jika gambar mengandung informasi keuangan/struk yang
  /// valid (terdapat nominal total atau daftar item belanja bernominal).
  bool get hasFinancialInfo =>
      (total != null && total! > 0) || items.isNotEmpty;
}

class ReceiptItem {
  final String name;
  final int amount;

  /// true = biaya tambahan (pajak, service charge, tip, dll)
  /// false = produk / menu belanja biasa
  final bool isCharge;

  const ReceiptItem({
    required this.name,
    required this.amount,
    this.isCharge = false,
  });
}

class ReceiptOcrException implements Exception {
  final String message;
  /// true = gambar bukan struk / foto blur — retry tidak akan membantu
  final bool isGuardrailError;
  /// true = error sementara dari AI (sibuk/jaringan) — retry mungkin membantu
  final bool isRetryable;

  const ReceiptOcrException(
    this.message, {
    this.isGuardrailError = false,
    this.isRetryable = false,
  });

  @override
  String toString() => message;
}

// ── Hybrid OCR service (ML Kit + Gemini) ─────────────────────────────────────

/// Alur kerja dua tahap:
///   1. ML Kit (on-device) → mengekstrak teks mentah dari foto secara lokal.
///   2. Gemini via Firebase AI → mem-parse teks mentah menjadi JSON terstruktur.
///
/// Pendekatan ini jauh lebih andal karena ML Kit khusus OCR dan tidak
/// memerlukan koneksi internet, sedangkan Gemini hanya perlu memahami teks.
class ReceiptOcrService {
  static const Duration _geminiTimeout = Duration(seconds: 30);
  static const int _maxAttempts = 2;
  static const int _maxOcrChars = 1500;
  static const int _minReceiptChars = 15;
  static const int _minDigitCount = 4;

  ReceiptOcrService({
    FirebaseAI? firebaseAI,
    String modelName = 'gemini-3.5-flash-lite',
  })  : _firebaseAI = firebaseAI ?? FirebaseAI.googleAI(),
        _preferredModelName = modelName,
        _textRecognizer = TextRecognizer(
          script: TextRecognitionScript.latin,
        );

  final FirebaseAI _firebaseAI;
  final String _preferredModelName;
  final TextRecognizer _textRecognizer;

  static final Schema _itemSchema = Schema.object(
    properties: {
      'name': Schema.string(nullable: true),
      'amount': Schema.integer(nullable: true),
      'is_charge': Schema.boolean(nullable: true),
    },
    optionalProperties: ['name', 'amount', 'is_charge'],
  );

  static final Schema _receiptSchema = Schema.object(
    properties: {
      'merchant': Schema.string(nullable: true),
      'total': Schema.integer(nullable: true),
      'date': Schema.string(nullable: true),
      'items': Schema.array(items: _itemSchema, nullable: true),
      'raw_text': Schema.string(nullable: true),
    },
    optionalProperties: ['merchant', 'total', 'date', 'items', 'raw_text'],
  );

  static final List<SafetySetting> _permissiveSafetySettings = <SafetySetting>[
    SafetySetting(HarmCategory.harassment, HarmBlockThreshold.none, null),
    SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.none, null),
    SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.none, null),
    SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.none, null),
  ];

  static const String _systemInstruction =
      'Kamu adalah AI parser spesialis struk belanja Indonesia '
      '(Indomaret, Alfamart, Superindo, restoran, apotek, dll).\n'
      'Kamu menerima TEKS OCR mentah yang diekstrak dari foto struk.\n'
      'Tugasmu adalah mem-parse teks tersebut dan mengembalikan JSON persis:\n'
      '{\n'
      '  "merchant": "Nama Toko",\n'
      '  "total": 38000,\n'
      '  "date": "YYYY-MM-DD",\n'
      '  "items": [\n'
      '    {"name": "Cimory", "amount": 2000},\n'
      '    {"name": "Frestea Madu", "amount": 8000}\n'
      '  ],\n'
      '  "raw_text": "ringkasan teks struk"\n'
      '}\n\n'
      'Aturan Utama:\n'
      '1. merchant: Nama toko di bagian atas teks (mis. Indomaret, Alfamart).\n'
      '2. total: Cari kata TOTAL/JUMLAH/GRAND TOTAL/TUNAI/BAYAR lalu ambil '
      'angkanya sebagai integer rupiah (tanpa titik/koma, mis. 28500). '
      'Jika tidak ada total eksplisit, jumlahkan seluruh item.\n'
      '3. date: Format YYYY-MM-DD. Konversi dari format apa pun (DD/MM/YYYY, '
      'DD-MM-YYYY, dll) jika ditemukan.\n'
      '4. items: Ekstrak SEMUA baris yang memiliki nominal, termasuk:\n'
      '   - Produk/menu belanja biasa → is_charge: false\n'
      '   - Pajak (PPN, tax, VAT) → is_charge: true\n'
      '   - Service charge / biaya layanan → is_charge: true\n'
      '   - Tip / gratuity / admin fee → is_charge: true\n'
      '   - Diskon / potongan harga → is_charge: true (amount tetap positif)\n'
      '   ABAIKAN hanya baris "kembalian" / "uang kembali" karena itu '
      'bukan biaya melainkan uang tunai yang dikembalikan.\n'
      '5. raw_text: Salin 2–3 baris pertama teks OCR sebagai ringkasan.\n'
      '6. PENTING: Jangan kembalikan items kosong jika ada daftar produk di teks.\n'
      '7. Toleran terhadap kesalahan OCR: angka "0" bisa terbaca "O", '
      '"l" bisa "1", spasi bisa tidak konsisten.';

  GenerativeModel _createModel(String modelName, {bool useSchema = true}) {
    return _firebaseAI.generativeModel(
      model: modelName,
      safetySettings: _permissiveSafetySettings,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        responseSchema: useSchema ? _receiptSchema : null,
        temperature: 0.1,
        maxOutputTokens: 700,
      ),
      systemInstruction: Content.system(_systemInstruction),
    );
  }

  Future<ReceiptOcrResult> recognizeFile(String imagePath) async {
    final String text = await extractText(imagePath);
    if (kDebugMode) {
      debugPrint('[ReceiptOcrService] ML Kit text (${text.length} chars):\n$text');
    }
    return parseText(text);
  }

  Future<String> extractText(String imagePath) async {
    final File file = File(imagePath);
    if (!file.existsSync()) {
      throw const ReceiptOcrException(
        'File gambar tidak ditemukan. Coba ambil foto lagi.',
      );
    }

    final String text;
    try {
      final InputImage inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText result = await _textRecognizer.processImage(inputImage);
      text = result.text;
    } on ReceiptOcrException {
      rethrow;
    } catch (error) {
      if (kDebugMode) debugPrint('[ReceiptOcrService] ML Kit error: $error');
      throw ReceiptOcrException('Gagal membaca teks dari foto: $error');
    }

    if (text.trim().length < _minReceiptChars) {
      throw const ReceiptOcrException(
        'Foto tidak terbaca.\nPastikan struk terlihat jelas, terang, dan tidak buram.',
        isGuardrailError: true,
      );
    }

    final int digitCount = RegExp(r'\d').allMatches(text).length;
    if (digitCount < _minDigitCount) {
      throw const ReceiptOcrException(
        'Gambar ini tampaknya bukan struk keuangan.\n'
        'Pastikan kamu memotret struk belanja yang memuat item dan harga.',
        isGuardrailError: true,
      );
    }

    return text;
  }

  Future<ReceiptOcrResult> parseText(String ocrText) async {
    final List<String> modelsToTry = <String>[
      _preferredModelName,
      if (_preferredModelName != 'gemini-3.5-flash') 'gemini-3.5-flash',
      if (_preferredModelName != 'gemini-3.6-flash') 'gemini-3.6-flash',
    ];

    final String trimmedText = ocrText.length > _maxOcrChars
        ? ocrText.substring(0, _maxOcrChars)
        : ocrText;

    final String userPrompt =
        'Parse struk berikut dan kembalikan JSON sesuai schema.\n\n'
        '=== TEKS OCR STRUK ===\n'
        '$trimmedText\n'
        '=== AKHIR TEKS ===';

    FirebaseAIException? lastFirebaseError;
    Object? lastError;

    for (final String modelName in modelsToTry) {
      for (final bool useSchema in <bool>[true, false]) {
        final GenerativeModel model =
            _createModel(modelName, useSchema: useSchema);

        for (int attempt = 1; attempt <= _maxAttempts; attempt++) {
          try {
            if (kDebugMode) {
              debugPrint(
                '[ReceiptOcrService] Gemini $modelName '
                '(schema=$useSchema, attempt=$attempt)...',
              );
            }

            final GenerateContentResponse response = await model
                .generateContent([Content.text(userPrompt)])
                .timeout(_geminiTimeout);

            if (kDebugMode) {
              debugPrint(
                '[ReceiptOcrService] Gemini response: ${response.text}',
              );
            }

            final ReceiptOcrResult? result = _tryParseResponse(response.text);
            if (result != null) return result;
            break;
          } on TimeoutException {
            throw const ReceiptOcrException(
              'AI terlalu lama merespons. Pastikan koneksi internet aktif.',
            );
          } on FirebaseAIException catch (error) {
            lastFirebaseError = error;
            if (kDebugMode) {
              debugPrint(
                '[ReceiptOcrService] FirebaseAIException ($modelName): ${error.message}',
              );
            }
            if (!_isTransient(error)) break;
            await Future<void>.delayed(const Duration(milliseconds: 800));
          } catch (error) {
            lastError = error;
            if (kDebugMode) {
              debugPrint('[ReceiptOcrService] Error ($modelName): $error');
            }
            break;
          }
        }
      }
    }

    if (lastFirebaseError != null) {
      final bool retry = _isTransient(lastFirebaseError);
      throw ReceiptOcrException(
        retry
            ? 'AI sedang sibuk. Coba scan ulang beberapa saat lagi.'
            : 'AI gagal memproses struk: ${lastFirebaseError.message}',
        isRetryable: retry,
      );
    }
    if (lastError != null) {
      throw ReceiptOcrException(
        'Gagal memproses struk: $lastError',
        isRetryable: true,
      );
    }

    throw const ReceiptOcrException(
      'Informasi keuangan tidak terdeteksi pada struk ini.\n'
      'Pastikan foto memperlihatkan seluruh struk dengan jelas.',
    );
  }

  /// Returns [ReceiptOcrResult] on success, or null when no financial info is
  /// found — allowing the caller loop to try the next model/schema variant.
  ReceiptOcrResult? _tryParseResponse(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;

    String clean = raw.trim();
    if (clean.startsWith('```')) {
      final int nl = clean.indexOf('\n');
      final int last = clean.lastIndexOf('```');
      if (nl != -1 && last > nl) {
        clean = clean.substring(nl + 1, last).trim();
      }
    }

    final dynamic decoded;
    try {
      decoded = jsonDecode(clean);
    } catch (_) {
      return null;
    }

    if (decoded is! Map) return null;

    final Map<String, dynamic> data = Map<String, dynamic>.from(decoded);

    final String merchant = _str(data['merchant']) ?? '';
    int? total = _int(data['total']);
    final DateTime? date = _parseDate(_str(data['date']));
    final String rawText = _str(data['raw_text']) ?? '';
    final List<ReceiptItem> items = _parseItems(data['items']);

    if ((total == null || total <= 0) && items.isNotEmpty) {
      total = items.fold<int>(0, (int sum, ReceiptItem i) => sum + i.amount);
    }

    final ReceiptOcrResult result = ReceiptOcrResult(
      merchant: merchant,
      total: total,
      date: date,
      items: items,
      rawText: rawText,
    );

    return result.hasFinancialInfo ? result : null;
  }

  List<ReceiptItem> _parseItems(dynamic raw) {
    if (raw is! List) return const <ReceiptItem>[];
    final List<ReceiptItem> result = <ReceiptItem>[];
    for (final dynamic item in raw.take(25)) {
      if (item is! Map) continue;
      final String? name = _str(item['name']);
      final int? amount = _int(item['amount']);
      if (name != null && name.isNotEmpty && amount != null && amount > 0) {
        final bool isCharge = item['is_charge'] == true;
        result.add(ReceiptItem(name: name, amount: amount, isCharge: isCharge));
      }
    }
    return result;
  }

  DateTime? _parseDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return DateTime.parse(raw);
    } catch (_) {}

    final RegExp dmyRegex =
        RegExp(r'^(\d{1,2})[\/\-\.](\d{1,2})[\/\-\.](\d{4})$');
    final Match? match = dmyRegex.firstMatch(raw.trim());
    if (match != null) {
      final int day = int.parse(match.group(1)!);
      final int month = int.parse(match.group(2)!);
      final int year = int.parse(match.group(3)!);
      return DateTime(year, month, day);
    }
    return null;
  }

  String? _str(dynamic value) {
    if (value is! String) return null;
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  int? _int(dynamic value) {
    if (value is int) return value > 0 ? value : null;
    if (value is double) return value > 0 ? value.toInt() : null;
    if (value is String) {
      final String digits = value.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.isEmpty) return null;
      return int.tryParse(digits);
    }
    return null;
  }

  bool _isTransient(FirebaseAIException error) {
    final String msg = error.message.toLowerCase();
    return msg.contains('high demand') ||
        msg.contains('temporarily') ||
        msg.contains('internal server error') ||
        msg.contains('http 500') ||
        msg.contains('503') ||
        msg.contains('overloaded');
  }

  /// Mengembalikan true jika hasil analisis AI tampak tidak akurat
  /// sehingga pengguna perlu memeriksa ulang data sebelum menyimpan.
  bool isResultSuspicious(ReceiptOcrResult result) {
    // Tidak ada item → total tidak bisa diverifikasi
    if (result.items.isEmpty) return true;

    // Hanya ada biaya/pajak tanpa produk → mencurigakan
    final bool hasProduct = result.items.any((i) => !i.isCharge);
    if (!hasProduct) return true;

    // Perbedaan antara total dan jumlah item > 50% → kemungkinan ada yang terlewat
    if (result.total != null && result.total! > 0) {
      final int itemSum =
          result.items.fold(0, (int s, ReceiptItem i) => s + i.amount);
      if (itemSum > 0) {
        final double ratio = (result.total! - itemSum).abs() / itemSum;
        if (ratio > 0.5) return true;
      }
    }

    return false;
  }

  Future<void> close() async {
    await _textRecognizer.close();
  }
}
