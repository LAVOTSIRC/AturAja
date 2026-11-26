import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../utils/expense_categories.dart';

class ReceiptOcrResult {
  final String merchant;
  final int? total;
  final DateTime? date;
  final List<ReceiptItem> items;
  final String rawText;

  /// true jika struk dibaca oleh parser lokal karena Gemini/App Check tidak
  /// tersedia. Pengguna perlu melihat kembali hasilnya sebelum menyimpan.
  final bool usedLocalFallback;

  const ReceiptOcrResult({
    required this.merchant,
    required this.total,
    required this.date,
    this.items = const <ReceiptItem>[],
    required this.rawText,
    this.usedLocalFallback = false,
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
  final bool isDiscount;
  final String? categoryKey;

  int get netAmount => isDiscount ? -amount : amount;

  const ReceiptItem({
    required this.name,
    required this.amount,
    this.isCharge = false,
    this.isDiscount = false,
    this.categoryKey,
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
  static const int _maxOcrChars = 12000;
  static const int _minReceiptChars = 15;
  static const int _minDigitCount = 4;

  ReceiptOcrService({
    FirebaseAI? firebaseAI,
    String modelName = 'gemini-3.5-flash-lite',
  }) : _preferredModelName = modelName,
       _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin) {
    _firebaseAI = firebaseAI ?? _safeDefaultFirebaseAI();
  }

  static FirebaseAI? _safeDefaultFirebaseAI() {
    try {
      return FirebaseAI.googleAI();
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[ReceiptOcrService] Gemini tidak tersedia: $error');
      }
      return null;
    }
  }

  @visibleForTesting
  static Future<String> Function(String imagePath)? debugExtractTextOverride;

  @visibleForTesting
  static Future<ReceiptOcrResult> Function(String ocrText)?
  debugParseTextOverride;

  late final FirebaseAI? _firebaseAI;
  final String _preferredModelName;
  final TextRecognizer _textRecognizer;

  static final Schema _itemSchema = Schema.object(
    properties: {
      'name': Schema.string(nullable: true),
      'amount': Schema.integer(nullable: true),
      'category': Schema.enumString(
        enumValues: expenseCategoryKeys.values.toList(),
      ),
      'is_discount': Schema.boolean(nullable: true),
      'is_charge': Schema.boolean(nullable: true),
    },
    optionalProperties: [
      'name',
      'amount',
      'is_charge',
      'is_discount',
      'category',
    ],
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
      '2. total: Cari kata TOTAL AKHIR/GRAND TOTAL/JUMLAH TAGIHAN lalu ambil '
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
      '   Abaikan baris "kembalian" / "uang kembali" karena itu '
      'bukan biaya melainkan uang tunai yang dikembalikan.\n'
      '5. raw_text: Salin 2–3 baris pertama teks OCR sebagai ringkasan.\n'
      'Berikan category per baris sesuai barang atau jasa, bukan berdasarkan toko: '
      'food untuk makanan dan minuman, transport untuk parkir atau bahan bakar, '
      'entertainment untuk hiburan, belanja untuk barang nonmakanan, other untuk biaya umum. '
      'Contoh: susu ? food, sabun ? belanja, parkir ? transport. '
      'Gunakan harga akhir untuk seluruh kuantitas pada satu baris, bukan harga satuan. '
      'Jangan masukkan uang tunai, kembalian, subtotal, atau total sebagai item. '
      'Keluarkan diskon terpisah hanya jika belum tercermin pada harga akhir baris.\n'
      '6. PENTING: Jangan kembalikan items kosong jika ada daftar produk di teks.\n'
      '7. Toleran terhadap kesalahan OCR: angka "0" bisa terbaca "O", '
      '"l" bisa "1", spasi bisa tidak konsisten.';

  GenerativeModel? _createModel(
    FirebaseAI firebaseAI,
    String modelName, {
    bool useSchema = true,
  }) {
    return firebaseAI.generativeModel(
      model: modelName,
      safetySettings: _permissiveSafetySettings,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        responseSchema: useSchema ? _receiptSchema : null,
        temperature: 0.1,
        maxOutputTokens: 7000,
      ),
      systemInstruction: Content.system(_systemInstruction),
    );
  }

  Future<ReceiptOcrResult> recognizeFile(String imagePath) async {
    final String text = await extractText(imagePath);
    if (kDebugMode) {
      debugPrint(
        '[ReceiptOcrService] ML Kit text (${text.length} chars):\n$text',
      );
    }
    return parseText(text);
  }

  Future<String> extractText(String imagePath) async {
    final Future<String> Function(String path)? extractOverride =
        debugExtractTextOverride;
    if (extractOverride != null) {
      return extractOverride(imagePath);
    }

    final File file = File(imagePath);
    if (!file.existsSync()) {
      throw const ReceiptOcrException(
        'File gambar tidak ditemukan. Coba ambil foto lagi.',
      );
    }

    final String text;
    try {
      final InputImage inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText result = await _textRecognizer.processImage(
        inputImage,
      );
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
    final Future<ReceiptOcrResult> Function(String text)? parseOverride =
        debugParseTextOverride;
    if (parseOverride != null) {
      return parseOverride(ocrText);
    }

    final ReceiptOcrResult localResult = parseLocally(ocrText);
    final FirebaseAI? firebaseAI = _firebaseAI;
    if (firebaseAI == null) return localResult;

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

    attempts:
    for (final String modelName in modelsToTry) {
      for (final bool useSchema in <bool>[true, false]) {
        final GenerativeModel? model = _createModel(
          firebaseAI,
          modelName,
          useSchema: useSchema,
        );
        if (model == null) continue;

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
            if (result != null) {
              return result.items.isEmpty && localResult.items.isNotEmpty
                  ? localResult
                  : result;
            }
            break;
          } on TimeoutException catch (error) {
            lastError = error;
            break attempts;
          } on FirebaseAIException catch (error) {
            lastFirebaseError = error;
            if (kDebugMode) {
              debugPrint(
                '[ReceiptOcrService] FirebaseAIException ($modelName): ${error.message}',
              );
            }
            if (appCheckMessage(error.message) != null) break attempts;
            if (!_isTransient(error)) break;
            await Future<void>.delayed(const Duration(milliseconds: 800));
          } catch (error) {
            lastError = error;
            if (appCheckMessage(error.toString()) != null) break attempts;
            if (kDebugMode) {
              debugPrint('[ReceiptOcrService] Error ($modelName): $error');
            }
            break;
          }
        }
      }
    }

    if (localResult.hasFinancialInfo) {
      return localResult;
    }

    final String? checkMessage = appCheckMessage(
      lastError?.toString() ?? lastFirebaseError?.message ?? '',
    );
    if (checkMessage != null) throw ReceiptOcrException(checkMessage);
    if (lastFirebaseError != null) {
      final bool retry = _isTransient(lastFirebaseError);
      throw ReceiptOcrException(
        retry
            ? 'AI sedang sibuk. Coba scan ulang beberapa saat lagi.'
            : appCheckMessage(lastFirebaseError.message) ??
                  'AI gagal memproses struk: ${lastFirebaseError.message}',
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
      total = items.fold<int>(0, (int sum, ReceiptItem i) => sum + i.netAmount);
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

  static bool _isDiscount(String label) => RegExp(
    r'^(?:diskon|discount|potongan|voucher|promo)\b',
    caseSensitive: false,
  ).hasMatch(label.trim());

  List<ReceiptItem> _parseItems(dynamic raw) {
    if (raw is! List) return const <ReceiptItem>[];
    final List<ReceiptItem> result = <ReceiptItem>[];
    for (final dynamic item in raw) {
      if (item is! Map) continue;
      final String? name = _str(item['name']);
      final int? amount = _int(item['amount']);
      if (name != null && name.isNotEmpty && amount != null && amount > 0) {
        final bool isCharge = item['is_charge'] == true;
        final bool isDiscount =
            item['is_discount'] == true || _isDiscount(name);
        result.add(
          ReceiptItem(
            name: name,
            amount: amount,
            isCharge: isCharge || isDiscount,
            isDiscount: isDiscount,
            categoryKey: receiptExpenseCategory(
              name,
              suggestedKey: item['category'] is String
                  ? item['category'] as String
                  : null,
            ),
          ),
        );
      }
    }
    return result;
  }

  static DateTime? _parseDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return DateTime.parse(raw);
    } catch (_) {}

    final RegExp dmyRegex = RegExp(
      r'^(\d{1,2})[\/\-\.](\d{1,2})[\/\-\.](\d{4})$',
    );
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

  /// Pesan khusus untuk kegagalan App Check/Check attestation.
  static String? appCheckMessage(String message) {
    final String lower = message.toLowerCase();
    final bool appCheckRelated =
        lower.contains('app check') ||
        lower.contains('appcheck') ||
        lower.contains('app_check') ||
        lower.contains('too many attempts') ||
        lower.contains('attestation') ||
        (lower.contains('403') &&
            (lower.contains('permission') || lower.contains('denied')));
    if (!appCheckRelated) return null;
    return 'Akses Gemini sedang ditolak oleh Firebase App Check, dan teks '
        'yang terbaca belum cukup untuk membuat transaksi. Gunakan foto yang '
        'lebih jelas atau tambahkan item secara manual.';
  }

  /// Parser cadangan tanpa Gemini. Dipakai saat Firebase AI/App Check gagal
  /// sehingga pengguna tetap bisa menyimpan transaksi dari hasil OCR.
  static ReceiptOcrResult parseLocally(String text) {
    final List<String> lines = text
        .split(RegExp(r'\r?\n'))
        .map((String line) => line.trim())
        .where((String line) => line.isNotEmpty)
        .toList();

    String merchant = '';
    for (final String line in lines.take(8)) {
      final String cleaned = line
          .replaceAll(RegExp(r'[^A-Za-z0-9 &.\-]'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      final String lower = cleaned.toLowerCase();
      if (cleaned.length < 3 || RegExp(r'^\d+$').hasMatch(cleaned)) continue;
      if (lower.contains('struk') ||
          lower.contains('nota') ||
          lower.contains('invoice') ||
          lower.contains('total') ||
          lower.contains('tanggal') ||
          lower.contains('terima kasih')) {
        continue;
      }
      merchant = cleaned.toUpperCase();
      break;
    }

    final RegExp finalTotal = RegExp(
      r'^(?:grand\s+total|total(?:\s+(?:akhir|bayar|tagihan|belanja))?|jumlah\s+tagihan)\b',
      caseSensitive: false,
    );
    int? total;
    for (final String line in lines.reversed) {
      if (!finalTotal.hasMatch(line)) continue;
      total = _lastAmount(line);
      if (total != null) break;
    }

    final RegExp summaryLine = RegExp(
      r'^(?:sub\s*total|total|jumlah|grand\s+total|tunai|bayar|kembalian|change|cash|qris|debit)\b',
      caseSensitive: false,
    );
    const List<String> chargeWords = <String>[
      'ppn',
      'pajak',
      'tax',
      'vat',
      'service',
      'admin',
      'diskon',
      'potongan',
      'tip',
      'gratuity',
    ];

    final RegExp numberedItem = RegExp(r'^\d+[.)]\s+(?=[A-Za-z])');
    final RegExp quantityLine = RegExp(
      r'^\d+\s+.*?[x\u00d7]\s*\d',
      caseSensitive: false,
    );
    final RegExp priceSuffix = RegExp(
      r'(?:\s+|^)(?:rp\.?\s*)?-?\d[\d.,]*\s*$',
      caseSensitive: false,
    );
    String? pendingName;
    final List<ReceiptItem> items = <ReceiptItem>[];
    for (final String line in lines) {
      if (summaryLine.hasMatch(line) ||
          RegExp(r'\d{1,2}[/.\-]\d{1,2}[/.\-]\d{2,4}').hasMatch(line) ||
          RegExp(r'\d{9,}').hasMatch(line)) {
        pendingName = null;
        continue;
      }
      final String itemLine = line.replaceFirst(numberedItem, '');
      final int? amount = priceSuffix.hasMatch(itemLine)
          ? _lastAmount(itemLine)
          : null;
      if (amount == null || amount <= 0) {
        pendingName = RegExp(r'^[A-Za-z]').hasMatch(itemLine) ? itemLine : null;
        continue;
      }

      final String inlineName = itemLine.replaceFirst(priceSuffix, '').trim();
      final bool separatePrice =
          quantityLine.hasMatch(line) || inlineName.isEmpty;
      final String? name = separatePrice ? pendingName : inlineName;
      pendingName = null;
      if (name == null || !RegExp(r'[A-Za-z]').hasMatch(name)) continue;
      final String lower = name.toLowerCase();
      items.add(
        ReceiptItem(
          name: name,
          amount: amount,
          isCharge: _isDiscount(name) || chargeWords.any(lower.contains),
          isDiscount: _isDiscount(name),
          categoryKey: receiptExpenseCategory(name),
        ),
      );
    }

    if ((total == null || total <= 0) && items.isNotEmpty) {
      total = items.fold<int>(
        0,
        (int sum, ReceiptItem item) => sum + item.netAmount,
      );
    }

    final String? date = _findDateInLines(lines);
    return ReceiptOcrResult(
      merchant: merchant,
      total: total,
      date: _parseDate(date),
      items: items,
      rawText: lines.take(3).join(' | '),
      usedLocalFallback: true,
    );
  }

  static int? _lastAmount(String line) {
    final RegExpMatch? match = RegExp(r'(\d[\d.,]*)\s*$')
        .firstMatch(line.trim());
    if (match == null) return null;
    final String digits = match.group(1)!.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.isEmpty ? null : int.tryParse(digits);
  }

  static String? _findDateInLines(List<String> lines) {
    for (final String line in lines) {
      final RegExpMatch? match = RegExp(
        r'(\d{1,2})[/.\-](\d{1,2})[/.\-](\d{2,4})',
      ).firstMatch(line);
      if (match == null) continue;
      String year = match.group(3)!;
      if (year.length == 2) year = '20$year';
      return '${match.group(1)}-${match.group(2)}-$year';
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
      final int itemSum = result.items.fold(
        0,
        (int s, ReceiptItem i) => s + i.netAmount,
      );
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
