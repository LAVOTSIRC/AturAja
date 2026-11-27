import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;

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

// ── Hybrid OCR service (Gemini Vision-First + ML Kit fallback) ───────────────

/// Alur kerja Vision-First:
///   1. Gemini Vision (multimodal) → kirim gambar langsung ke Firebase AI.
///   2. ML Kit + parseLocally → fallback jika Firebase AI tidak tersedia/error.
class ReceiptOcrService {
  static const Duration _geminiTimeout = Duration(seconds: 25);
  static const int _maxOcrChars = 12000;
  static const int _minReceiptChars = 15;
  static const int _minDigitCount = 4;
  static const int _maxImageSide = 1600;

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
  static Future<ReceiptOcrResult> Function(String imagePath)? debugScanImageOverride;

  @visibleForTesting
  static Future<String> Function(String imagePath)? debugExtractTextOverride;

  @visibleForTesting
  static Future<ReceiptOcrResult> Function(String ocrText)? debugParseTextOverride;

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
    optionalProperties: ['name', 'amount', 'is_charge', 'is_discount', 'category'],
  );

  static final Schema _receiptSchema = Schema.object(
    properties: {
      'is_valid_receipt': Schema.boolean(nullable: true),
      'rejection_reason': Schema.string(nullable: true),
      'merchant': Schema.string(nullable: true),
      'total': Schema.integer(nullable: true),
      'date': Schema.string(nullable: true),
      'items': Schema.array(items: _itemSchema, nullable: true),
      'raw_text': Schema.string(nullable: true),
    },
    optionalProperties: [
      'is_valid_receipt', 'rejection_reason', 'merchant', 'total', 'date', 'items', 'raw_text',
    ],
  );

  static final List<SafetySetting> _permissiveSafetySettings = <SafetySetting>[
    SafetySetting(HarmCategory.harassment, HarmBlockThreshold.none, null),
    SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.none, null),
    SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.none, null),
    SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.none, null),
  ];

  // System instruction untuk jalur Vision (Gemini menerima gambar)
  static const String _systemInstruction =
      'Kamu adalah AI parser spesialis struk belanja Indonesia '
      '(Indomaret, Alfamart, Superindo, toko kelontong, restoran, apotek, e-wallet, marketplace, dll).\n'
      'Kamu menerima GAMBAR FOTO STRUK langsung.\n'
      'Tugasmu adalah memeriksa gambar dan mengembalikan JSON persis sesuai schema:\n'
      '{\n'
      '  "is_valid_receipt": true,\n'
      '  "rejection_reason": null,\n'
      '  "merchant": "Nama Toko",\n'
      '  "total": 38000,\n'
      '  "date": "2026-11-27",\n'
      '  "items": [\n'
      '    {"name": "Susu Cimory", "amount": 8000, "category": "food", "is_charge": false, "is_discount": false},\n'
      '    {"name": "Frestea Madu", "amount": 6000, "category": "food", "is_charge": false, "is_discount": false},\n'
      '    {"name": "Diskon Member", "amount": 2000, "category": "other", "is_charge": false, "is_discount": true},\n'
      '    {"name": "PPN 11%", "amount": 3000, "category": "other", "is_charge": true, "is_discount": false}\n'
      '  ],\n'
      '  "raw_text": "INDOMARET · 27/11/2026"\n'
      '}\n\n'
      'FOKUS AREA STRUK (SANGAT PENTING):\n'
      '- Jika foto memuat layar monitor, meja, buku, atau objek lain di sekitar struk, '
      '  FOKUS HANYA pada kertas/area struk utama.\n'
      '- ABAIKAN semua teks background di luar struk (seperti teks web di pinggir layar, watermark "designed by freepik", iklan, dll).\n'
      '- is_valid_receipt: false HANYA jika sama sekali tidak ada struk/nota di gambar.\n\n'
      'ATURAN MERCHANT & TANGGAL:\n'
      '1. merchant: Nama toko/usaha di bagian atas/header struk (mis. "Karis Jaya Shop", "Indomaret"). '
      '   JANGAN pernah mengisi merchant dengan angka/harga (mis. "7 000"), alamat ("Jl. ..."), '
      '   nomor telepon, NPWP, nama kasir, atau teks watermark.\n'
      '2. date: Format WAJIB ISO YYYY-MM-DD. Konversi dari format apa pun (DD/MM/YYYY, '
      '   DD-MM-YYYY, DD Bulan YYYY, YYYY-MM-DD). Jika tidak ada tanggal, kembalikan null.\n\n'
      'ATURAN ITEMS (MENDUKUNG SEMUA TEMPLATE STRUK):\n'
      '3. Template multi-baris: jika nama produk di baris atas dan qty+harga di baris bawah:\n'
      '   - "1. Indomie Goreng\\n1 lusin x 36,000   Rp 36.000" → name: "Indomie Goreng", amount: 36000.\n'
      '   - "PPG\\n500.000  X1  500.000" → name: "PPG", amount: 500000.\n'
      '4. Template 1-baris / multi-kolom ("2x Nasi Goreng  25.000  50.000"): '
      '   selalu gunakan HARGA SUBTOTAL BARIS paling kanan (50000), bukan harga satuan.\n'
      '5. PRODUK / MENU biasa → is_charge: false, is_discount: false.\n'
      '6. DISKON / potongan / voucher / promo / hemat / cashback → '
      '   is_discount: true, is_charge: false, amount POSITIF.\n'
      '7. PAJAK (PPN/PPh/VAT/PB1) / Service Charge / Biaya Admin / Ongkir → '
      '   is_charge: true, is_discount: false, amount POSITIF.\n'
      '8. JANGAN PERNAH memasukkan baris berikut sebagai item:\n'
      '   - Tanggal/hari/jam (mis. "Sabtu, 16 November 2019", "13:56:30"), nomor telepon, NPWP, ID struk.\n'
      '   - Pembayaran & ringkasan: ITEMS: (subtotal jumlah item, mis. "ITEMS: 12  181,823"),\n'
      '     BEFORE ROUNDING, AFTER ROUNDING, TUNAI, CASH, BAYAR, QRIS, DEBIT, KREDIT, KEMBALI, KEMBALIAN,\n'
      '     BCA, MANDIRI, BRI, BNI, GOPAY, OVO, DANA, SHOPEEPAY, TRANSFER,\n'
      '     ANDA HEMAT, TOTAL ITEM, TOTAL QTY, SUBTOTAL, SUB TOTAL, GRAND TOTAL, TOTAL, JUMLAH,\n'
      '     DPP, NO STRUK, NO KASIR, REF, TRACE, APPROVAL, EDC.\n'
      '9. category WAJIB salah satu: food, entertainment, transport, belanja, other.\n'
      '   food=makanan&minuman, transport=parkir/BBM/ojek, entertainment=hiburan, '
      '   belanja=barang non-makanan, other=pajak/biaya/diskon.\n\n'
      'TOLERANSI OCR: "0" bisa "O", "l" bisa "1", spasi tidak konsisten.\n'
      'Jangan kembalikan items kosong jika ada daftar produk yang terlihat.';

  // System instruction untuk jalur teks (ML Kit → Gemini text mode)
  static const String _systemInstructionText =
      'Kamu adalah AI parser spesialis struk belanja Indonesia.\n'
      'Kamu menerima TEKS OCR mentah dari foto struk.\n'
      'Tugasmu adalah mem-parse teks dan mengembalikan JSON sesuai schema:\n'
      '{\n'
      '  "is_valid_receipt": true, "rejection_reason": null,\n'
      '  "merchant": "Nama Toko", "total": 38000, "date": "2026-11-27",\n'
      '  "items": [\n'
      '    {"name": "Susu Cimory", "amount": 8000, "category": "food", "is_charge": false, "is_discount": false},\n'
      '    {"name": "Diskon Member", "amount": 2000, "category": "other", "is_charge": false, "is_discount": true},\n'
      '    {"name": "PPN 11%", "amount": 1760, "category": "other", "is_charge": true, "is_discount": false}\n'
      '  ],\n'
      '  "raw_text": "INDOMARET · 27/11/2026"\n'
      '}\n\n'
      'Aturan: merchant=nama toko (bukan alamat/NPWP), date=YYYY-MM-DD, '
      'amount=subtotal baris (bukan satuan), diskon→is_discount:true is_charge:false, '
      'pajak→is_charge:true is_discount:false, '
      'ABAIKAN: TUNAI/QRIS/KEMBALI/DEBIT/BCA/GOPAY/TOTAL/SUBTOTAL/DPP/NPWP.\n'
      'category: food/entertainment/transport/belanja/other.\n'
      'Jangan kembalikan items kosong jika ada daftar produk.';

  GenerativeModel? _createModel(
    FirebaseAI firebaseAI,
    String modelName, {
    bool useSchema = true,
    String? systemInstruction,
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
      systemInstruction: Content.system(systemInstruction ?? _systemInstruction),
    );
  }

  // ── JALUR UTAMA: Gemini Vision ───────────────────────────────────────────

  /// Jalur utama: kirim gambar langsung ke Gemini Vision.
  /// Fallback otomatis ke ML Kit + parseLocally jika Firebase AI tidak tersedia.
  Future<ReceiptOcrResult> scanReceiptImage(String imagePath) async {
    final Future<ReceiptOcrResult> Function(String)? scanOverride = debugScanImageOverride;
    if (scanOverride != null) return scanOverride(imagePath);

    final File file = File(imagePath);
    if (!file.existsSync()) {
      throw const ReceiptOcrException('File gambar tidak ditemukan. Coba ambil foto lagi.');
    }

    final FirebaseAI? firebaseAI = _firebaseAI;
    if (firebaseAI == null) return _mlKitFallback(imagePath);

    // Resize & normalisasi
    final Uint8List imageBytes;
    try {
      imageBytes = await _resizeAndNormalize(imagePath);
    } catch (e) {
      if (kDebugMode) debugPrint('[ReceiptOcrService] Gagal resize: $e');
      return _mlKitFallback(imagePath);
    }

    final String userPrompt =
        'Analisis foto struk ini dan kembalikan JSON sesuai schema. '
        'Periksa apakah gambar merupakan struk belanja yang valid, '
        'lalu ekstrak semua informasi keuangan yang terlihat.';

    final List<String> modelsToTry = <String>[
      _preferredModelName,
      if (_preferredModelName != 'gemini-3.5-flash') 'gemini-3.5-flash',
    ];

    FirebaseAIException? lastFirebaseError;
    Object? lastError;

    for (final String modelName in modelsToTry) {
      for (final bool useSchema in <bool>[true, false]) {
        final GenerativeModel? model = _createModel(
          firebaseAI,
          modelName,
          useSchema: useSchema,
        );
        if (model == null) continue;

        try {
          if (kDebugMode) {
            debugPrint('[ReceiptOcrService] Vision: $modelName (schema=$useSchema) ...');
          }

          final GenerateContentResponse response = await model
              .generateContent([
                Content.multi([
                  TextPart(userPrompt),
                  InlineDataPart('image/jpeg', imageBytes),
                ]),
              ])
              .timeout(_geminiTimeout);

          if (kDebugMode) {
            debugPrint('[ReceiptOcrService] Vision response: ${response.text}');
          }

          final _ParsedResponse? parsed = _tryParseResponseFull(response.text);
          if (parsed == null) continue;

          if (parsed.isValidReceipt == false) {
            throw ReceiptOcrException(
              parsed.rejectionReason ??
                  'Gambar ini bukan struk keuangan yang valid.\n'
                      'Pastikan memotret struk belanja yang memuat item dan harga.',
              isGuardrailError: true,
            );
          }

          final ReceiptOcrResult result = parsed.result;

          // Jika metadata bagus tapi items kosong, gabungkan dengan ML Kit
          if (result.items.isEmpty && result.hasFinancialInfo) {
            try {
              final ReceiptOcrResult localResult = await _mlKitFallback(imagePath);
              if (localResult.items.isNotEmpty) {
                return _sanitizeResult(ReceiptOcrResult(
                  merchant: result.merchant.isNotEmpty ? result.merchant : localResult.merchant,
                  total: result.total ?? localResult.total,
                  date: result.date ?? localResult.date,
                  items: localResult.items,
                  rawText: result.rawText.isNotEmpty ? result.rawText : localResult.rawText,
                  usedLocalFallback: localResult.usedLocalFallback,
                ));
              }
            } catch (_) {}
          }

          return _sanitizeResult(result);
        } on ReceiptOcrException {
          rethrow;
        } on TimeoutException catch (e) {
          lastError = e;
          if (kDebugMode) debugPrint('[ReceiptOcrService] Timeout $modelName, fallback ML Kit');
          break;
        } on FirebaseAIException catch (e) {
          lastFirebaseError = e;
          if (kDebugMode) {
            debugPrint('[ReceiptOcrService] FirebaseAIException ($modelName, schema=$useSchema): ${e.message}');
          }
          if (appCheckMessage(e.message) != null) break;
        } catch (e) {
          lastError = e;
          if (appCheckMessage(e.toString()) != null) break;
          if (kDebugMode) debugPrint('[ReceiptOcrService] Error ($modelName, schema=$useSchema): $e');
        }
      }
      if (lastError is TimeoutException) break;
      if (lastFirebaseError != null && appCheckMessage(lastFirebaseError.message) != null) break;
    }

    // Semua model Vision gagal → fallback ML Kit
    try {
      final ReceiptOcrResult fallback = await _mlKitFallback(imagePath);
      if (fallback.hasFinancialInfo) return fallback;
    } catch (fallbackError) {
      if (kDebugMode) debugPrint('[ReceiptOcrService] ML Kit fallback gagal: $fallbackError');
    }

    final String? checkMsg = appCheckMessage(
      lastError?.toString() ?? lastFirebaseError?.message ?? '',
    );
    if (checkMsg != null) throw ReceiptOcrException(checkMsg);

    if (lastFirebaseError != null) {
      final bool retry = _isTransient(lastFirebaseError);
      throw ReceiptOcrException(
        retry
            ? 'AI sedang sibuk. Coba scan ulang beberapa saat lagi.'
            : 'AI gagal memproses struk: ${lastFirebaseError.message}',
        isRetryable: retry,
      );
    }

    throw const ReceiptOcrException(
      'Informasi keuangan tidak terdeteksi pada struk ini.\n'
      'Pastikan foto memperlihatkan seluruh struk dengan jelas.',
    );
  }

  // ── Resize & normalisasi ─────────────────────────────────────────────────

  static Future<Uint8List> _resizeAndNormalize(String imagePath) async {
    final Uint8List rawBytes = await File(imagePath).readAsBytes();
    final img.Image? decoded = img.decodeImage(rawBytes);
    if (decoded == null) {
      throw const ReceiptOcrException('Gambar tidak dapat dibaca / format tidak didukung.');
    }

    img.Image oriented = img.bakeOrientation(decoded);

    if (oriented.width > _maxImageSide || oriented.height > _maxImageSide) {
      final double scale = _maxImageSide /
          (oriented.width > oriented.height ? oriented.width : oriented.height);
      oriented = img.copyResize(
        oriented,
        width: (oriented.width * scale).round(),
        height: (oriented.height * scale).round(),
        interpolation: img.Interpolation.linear,
      );
    }

    return Uint8List.fromList(img.encodeJpg(oriented, quality: 85));
  }

  // ── Fallback: ML Kit + Gemini text ──────────────────────────────────────

  Future<ReceiptOcrResult> _mlKitFallback(String imagePath) async {
    final String text = await extractText(imagePath);
    if (kDebugMode) {
      debugPrint('[ReceiptOcrService] ML Kit fallback (${text.length} chars)');
    }
    return parseText(text);
  }

  static ReceiptOcrResult _withFallback(ReceiptOcrResult r) => ReceiptOcrResult(
    merchant: r.merchant,
    total: r.total,
    date: r.date,
    items: r.items,
    rawText: r.rawText,
    usedLocalFallback: true,
  );

  // ── API kompatibilitas lama ──────────────────────────────────────────────

  Future<ReceiptOcrResult> recognizeFile(String imagePath) =>
      scanReceiptImage(imagePath);

  Future<String> extractText(String imagePath) async {
    final Future<String> Function(String)? extractOverride = debugExtractTextOverride;
    if (extractOverride != null) return extractOverride(imagePath);

    final File file = File(imagePath);
    if (!file.existsSync()) {
      throw const ReceiptOcrException('File gambar tidak ditemukan. Coba ambil foto lagi.');
    }

    final String text;
    try {
      final InputImage inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText result = await _textRecognizer.processImage(inputImage);
      text = _reconstructLines(result);
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
    final Future<ReceiptOcrResult> Function(String)? parseOverride = debugParseTextOverride;
    if (parseOverride != null) return parseOverride(ocrText);

    final ReceiptOcrResult localResult = parseLocally(ocrText);
    final FirebaseAI? firebaseAI = _firebaseAI;
    if (firebaseAI == null) return _withFallback(localResult);

    final String trimmedText = ocrText.length > _maxOcrChars
        ? ocrText.substring(0, _maxOcrChars)
        : ocrText;

    final String userPrompt =
        'Parse struk berikut dan kembalikan JSON sesuai schema.\n\n'
        '=== TEKS OCR STRUK ===\n$trimmedText\n=== AKHIR TEKS ===';

    final List<String> modelsToTry = <String>[
      _preferredModelName,
      if (_preferredModelName != 'gemini-3.5-flash') 'gemini-3.5-flash',
    ];

    for (final String modelName in modelsToTry) {
      final GenerativeModel? model = _createModel(
        firebaseAI,
        modelName,
        systemInstruction: _systemInstructionText,
      );
      if (model == null) continue;

      try {
        if (kDebugMode) debugPrint('[ReceiptOcrService] Text parse: $modelName ...');
        final GenerateContentResponse response = await model
            .generateContent([Content.text(userPrompt)])
            .timeout(_geminiTimeout);

        final _ParsedResponse? parsed = _tryParseResponseFull(response.text);
        if (parsed == null) continue;

        final ReceiptOcrResult result = _sanitizeResult(parsed.result);
        if (result.items.isEmpty && localResult.items.isNotEmpty) {
          return _sanitizeResult(ReceiptOcrResult(
            merchant: result.merchant.isNotEmpty ? result.merchant : localResult.merchant,
            total: result.total ?? localResult.total,
            date: result.date ?? localResult.date,
            items: localResult.items,
            rawText: result.rawText.isNotEmpty ? result.rawText : localResult.rawText,
            usedLocalFallback: true,
          ));
        }
        return result.items.isEmpty && localResult.items.isNotEmpty
            ? _withFallback(localResult)
            : result;
      } on TimeoutException {
        break;
      } on FirebaseAIException catch (e) {
        if (appCheckMessage(e.message) != null) break;
      } catch (_) {}
    }

    return _withFallback(localResult);
  }

  // ── Rekonstruksi baris berbasis bounding box ─────────────────────────────

  @visibleForTesting
  static String reconstructLines(RecognizedText result) => _reconstructLines(result);

  @visibleForTesting
  static String reconstructLineBoxes(
    List<ReceiptTextBox> boxes, {
    String fallbackText = '',
  }) {
    if (boxes.isEmpty) return fallbackText;

    final List<ReceiptTextBox> sorted = List<ReceiptTextBox>.of(boxes)
      ..sort((a, b) => a.top.compareTo(b.top));

    final double avgHeight =
        sorted.fold(0.0, (s, l) => s + (l.bottom - l.top)) / sorted.length;
    final double groupThreshold = avgHeight > 0 ? avgHeight * 0.5 : 10.0;

    final List<List<ReceiptTextBox>> groups = [];
    for (final line in sorted) {
      bool added = false;
      for (final group in groups) {
        final double groupCenter =
            group.fold(0.0, (s, l) => s + (l.top + l.bottom) / 2) /
                group.length;
        if (((line.top + line.bottom) / 2 - groupCenter).abs() <=
            groupThreshold) {
          group.add(line);
          added = true;
          break;
        }
      }
      if (!added) groups.add([line]);
    }

    final StringBuffer sb = StringBuffer();
    for (final group in groups) {
      group.sort((a, b) => a.left.compareTo(b.left));
      sb.writeln(group.map((l) => l.text).join('  '));
    }
    return sb.toString().trim();
  }

  static String _reconstructLines(RecognizedText result) {
    final List<ReceiptTextBox> allLines = [];
    for (final block in result.blocks) {
      for (final line in block.lines) {
        final rect = line.boundingBox;
        allLines.add(ReceiptTextBox(
          text: line.text,
          top: rect.top.toDouble(),
          bottom: rect.bottom.toDouble(),
          left: rect.left.toDouble(),
        ));
      }
    }
    return reconstructLineBoxes(allLines, fallbackText: result.text);
  }

  // ── Parse response JSON ──────────────────────────────────────────────────

  static _ParsedResponse? _tryParseResponseFull(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;

    String clean = raw.trim();
    if (clean.startsWith('```')) {
      final int nl = clean.indexOf('\n');
      final int last = clean.lastIndexOf('```');
      if (nl != -1 && last > nl) clean = clean.substring(nl + 1, last).trim();
    }

    final dynamic decoded;
    try {
      decoded = jsonDecode(clean);
    } catch (_) {
      return null;
    }
    if (decoded is! Map) return null;

    final Map<String, dynamic> data = Map<String, dynamic>.from(decoded);

    final bool? isValid = data['is_valid_receipt'] is bool
        ? data['is_valid_receipt'] as bool
        : null;
    final String? rejectionReason = _str(data['rejection_reason']);
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

    if (isValid != false && !result.hasFinancialInfo) {
      return null;
    }

    return _ParsedResponse(
      isValidReceipt: isValid,
      rejectionReason: rejectionReason,
      result: result,
    );
  }

  @visibleForTesting
  static ReceiptOcrResult? tryParseResponse(String? raw) =>
      _tryParseResponseFull(raw)?.result;

  static bool _isDiscount(String label) => RegExp(
    r'^(?:diskon|discount|potongan|voucher|promo|hemat|disc|pot\.|cashback|rebate|free)\b',
    caseSensitive: false,
  ).hasMatch(label.trim());

  static List<ReceiptItem> _parseItems(dynamic raw) {
    if (raw is! List) return const <ReceiptItem>[];
    final List<ReceiptItem> result = <ReceiptItem>[];
    for (final dynamic item in raw) {
      if (item is! Map) continue;
      final String? name = _str(item['name']);
      final int? amount = _int(item['amount']);
      if (name != null && name.isNotEmpty && amount != null && amount > 0) {
        final bool isCharge = item['is_charge'] == true;
        final bool isDiscount = item['is_discount'] == true || _isDiscount(name);
        result.add(ReceiptItem(
          name: name,
          amount: amount,
          isCharge: isCharge || isDiscount,
          isDiscount: isDiscount,
          categoryKey: receiptExpenseCategory(
            name,
            suggestedKey: item['category'] is String ? item['category'] as String : null,
          ),
        ));
      }
    }
    return result;
  }

  // ── Parse tanggal ────────────────────────────────────────────────────────

  @visibleForTesting
  static DateTime? parseDate(String? raw) => _parseDate(raw);

  static DateTime? _parseDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final String s = raw.trim();

    // 1. ISO langsung
    final DateTime? iso = DateTime.tryParse(s);
    if (iso != null && _isValidYear(iso.year)) return iso;

    // 2. YYYY[-/.]MM[-/.]DD (prioritas tinggi, cegah ambiguitas tahun)
    final RegExpMatch? ymdMatch = RegExp(r'\b(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})\b').firstMatch(s);
    if (ymdMatch != null) {
      final DateTime? dt = _makeDate(
        int.parse(ymdMatch.group(1)!),
        int.parse(ymdMatch.group(2)!),
        int.parse(ymdMatch.group(3)!),
      );
      if (dt != null) return dt;
    }

    // 3. DD[-/.]MM[-/.]YYYY atau DD[-/.]MM[-/.]YY
    final RegExpMatch? dmyMatch = RegExp(r'\b(\d{1,2})[-/.](\d{1,2})[-/.](\d{2,4})\b').firstMatch(s);
    if (dmyMatch != null) {
      int year = int.parse(dmyMatch.group(3)!);
      if (year < 100) year += 2000;
      final DateTime? dt = _makeDate(
        year,
        int.parse(dmyMatch.group(2)!),
        int.parse(dmyMatch.group(1)!),
      );
      if (dt != null) return dt;
    }

    // 4. "27 November 2026" / "27 Nov 2026"
    final RegExpMatch? textMatch = RegExp(r'\b(\d{1,2})\s+([A-Za-z]{3,})\s+(\d{4})\b').firstMatch(s);
    if (textMatch != null) {
      final int? month = _monthFromName(textMatch.group(2)!);
      if (month != null) {
        final DateTime? dt = _makeDate(
          int.parse(textMatch.group(3)!),
          month,
          int.parse(textMatch.group(1)!),
        );
        if (dt != null) return dt;
      }
    }

    return null;
  }

  static bool _isValidYear(int year) {
    final int now = DateTime.now().year;
    return year >= 2000 && year <= now + 1;
  }

  static DateTime? _makeDate(int year, int month, int day) {
    if (!_isValidYear(year) || month < 1 || month > 12 || day < 1 || day > 31) return null;
    try {
      final DateTime dt = DateTime(year, month, day);
      return (dt.year == year && dt.month == month && dt.day == day) ? dt : null;
    } catch (_) {
      return null;
    }
  }

  static int? _monthFromName(String name) {
    const Map<String, int> months = {
      'jan': 1, 'januari': 1, 'january': 1,
      'feb': 2, 'februari': 2, 'february': 2,
      'mar': 3, 'maret': 3, 'march': 3,
      'apr': 4, 'april': 4,
      'mei': 5, 'may': 5,
      'jun': 6, 'juni': 6, 'june': 6,
      'jul': 7, 'juli': 7, 'july': 7,
      'agu': 8, 'agus': 8, 'agustus': 8, 'aug': 8, 'august': 8,
      'sep': 9, 'sept': 9, 'september': 9,
      'okt': 10, 'oktober': 10, 'oct': 10, 'october': 10,
      'nov': 11, 'november': 11,
      'des': 12, 'desember': 12, 'dec': 12, 'december': 12,
    };
    return months[name.toLowerCase()];
  }

  static String? _str(dynamic value) {
    if (value is! String) return null;
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static int? _int(dynamic value) {
    if (value is int) return value > 0 ? value : null;
    if (value is double) return value > 0 ? value.toInt() : null;
    if (value is String) return _parseRupiahAmount(value);
    return null;
  }

  // ── Parser nominal rupiah ────────────────────────────────────────────────

  @visibleForTesting
  static int? parseRupiahAmount(String raw) => _parseRupiahAmount(raw);

  static int? _parseRupiahAmount(String raw) {
    String s = raw.trim();
    s = s.replaceAll(RegExp(r'^[Rr][Pp]\.?\s*'), '');
    // Hapus trailing POS flag (A, B, *, (P))
    s = s.replaceAll(RegExp(r'\s+[A-Z*]\s*$'), '');
    s = s.replaceAll(RegExp(r'\s+\(P\)\s*$'), '');
    s = s.trim();
    if (s.isEmpty) return null;

    // Tangani desimal sen di akhir (,00 atau .00) → potong sebelum parse
    final RegExpMatch? decimalEnd = RegExp(r'^([\d.,]+)[,.](\d{2})$').firstMatch(s);
    if (decimalEnd != null) {
      s = decimalEnd.group(1)!;
    }

    // Tolak nomor telepon / ID yang diawali '0' tanpa pemisah ribuan (mis. 0812345678)
    if (RegExp(r'^0\d{5,}$').hasMatch(s)) return null;

    // Tentukan pemisah ribuan
    final bool hasDotThousands = RegExp(r'\d\.\d{3}(?!\d)').hasMatch(s);
    final bool hasCommaThousands = RegExp(r'\d,\d{3}(?!\d)').hasMatch(s);

    if (hasDotThousands) {
      s = s.replaceAll('.', '').replaceAll(',', '');
    } else if (hasCommaThousands) {
      s = s.replaceAll(',', '').replaceAll('.', '');
    } else {
      s = s.replaceAll(RegExp(r'[^0-9]'), '');
    }

    if (s.isEmpty) return null;
    final int? result = int.tryParse(s);
    if (result == null || result <= 0) return null;
    // Batas wajar nominal struk harian (< 100 juta) agar nomor rekening/ID tidak lolos
    if (result >= 100000000) return null;
    return result;
  }

  // ── App Check error message ──────────────────────────────────────────────

  static String? appCheckMessage(String message) {
    final String lower = message.toLowerCase();
    final bool appCheckRelated =
        lower.contains('app check') ||
        lower.contains('appcheck') ||
        lower.contains('app_check') ||
        lower.contains('too many attempts') ||
        lower.contains('attestation') ||
        (lower.contains('403') && (lower.contains('permission') || lower.contains('denied')));
    if (!appCheckRelated) return null;
    return 'Akses Gemini sedang ditolak oleh Firebase App Check, dan teks '
        'yang terbaca belum cukup untuk membuat transaksi. Gunakan foto yang '
        'lebih jelas atau tambahkan item secara manual.';
  }

  // ── Sanitasi universal (berlaku untuk hasil Gemini maupun lokal) ─────────

  static final RegExp _invalidMerchantPattern = RegExp(
    r'(?:telp|telepon|hp\b|wa\b|npwp|freepik|designed\s+by|deiged\s+by|scribd|slideshare|canva|http|www\.|\.com|'
    r'struk|nota|invoice|total|tanggal|terima\s*kasih|terimakasih|kritik|saran|'
    r'^jl\.?\s|^jalan\s|^no\.?\s|\d{4}-\d{2}-\d{2}|\d{1,2}[/-]\d{1,2}[/-]\d{2,4})',
    caseSensitive: false,
  );

  static final RegExp _invalidItemNamePattern = RegExp(
    r'(?:^(?:no\.?\s*(?:telp|telepon|hp|wa|fax|struk|nota|order|ref|meja)|'
    r'telp|telepon|hp\.?\s*\d|cp\.?\s*\d|npwp|designed\s+by|deiged\s+by|freepik|scribd|'
    r'items?\s*:|before\s+rounding|after\s+rounding|'
    r'(?:senin|selasa|rabu|kamis|jumat|sabtu|minggu)\b)|'
    r'\b(?:sub\s*total|grand\s+total|total\s+belanja|total\s+bayar|total\s+akhir|'
    r'total\s+tagihan|total\s+qty|total\s+item|tunai|kembalian|kembali|uang\s+kembali|'
    r'qris|anda\s+hemat|dpp|non\s+tunai|approval|ref\s*no)\b|'
    r'^(?:total|jumlah|bayar|change|cash|debit|kredit|bca|mandiri|bri|bni|gopay|ovo|dana|shopeepay|transfer|edc|card)\b)',
    caseSensitive: false,
  );

  static bool _isValidMerchantName(String text) {
    final String s = text.trim();
    if (s.length < 3) return false;
    // Harus punya minimal 3 huruf (menolak "7 000", "No.0-3", dll)
    if (RegExp(r'[A-Za-z]').allMatches(s).length < 3) return false;
    // Tolak jika dominan angka
    final int letters = RegExp(r'[A-Za-z]').allMatches(s).length;
    final int digits = RegExp(r'\d').allMatches(s).length;
    if (digits > letters) return false;
    if (_invalidMerchantPattern.hasMatch(s)) return false;
    return true;
  }

  static ReceiptOcrResult _sanitizeResult(ReceiptOcrResult result) {
    final String cleanMerchant = _isValidMerchantName(result.merchant)
        ? result.merchant.trim()
        : '';

    final int? refTotal = result.total;
    final List<ReceiptItem> cleanItems = <ReceiptItem>[];
    for (final ReceiptItem item in result.items) {
      final String name = item.name.trim();
      if (RegExp(r'[A-Za-z]{2,}').allMatches(name).isEmpty) continue;
      if (_invalidItemNamePattern.hasMatch(name)) continue;
      if (name.toLowerCase().contains('freepik') ||
          name.toLowerCase().contains('no. telp') ||
          name.toLowerCase().contains('telepon')) {
        continue;
      }
      // Jika total struk diketahui dan ada satu item nyasar > 5x total (mis. nomor HP), buang
      if (refTotal != null && refTotal > 0 && item.amount > refTotal * 5) {
        continue;
      }
      cleanItems.add(item);
    }

    int? cleanTotal = result.total;
    if ((cleanTotal == null || cleanTotal <= 0) && cleanItems.isNotEmpty) {
      cleanTotal = cleanItems.fold<int>(0, (int s, ReceiptItem i) => s + i.netAmount);
    }

    return ReceiptOcrResult(
      merchant: cleanMerchant,
      total: cleanTotal,
      date: result.date,
      items: cleanItems,
      rawText: result.rawText,
      usedLocalFallback: result.usedLocalFallback,
    );
  }

  // ── Parser lokal ─────────────────────────────────────────────────────────

  static ReceiptOcrResult parseLocally(String text) {
    final List<String> lines = text
        .split(RegExp(r'\r?\n'))
        .map((String line) => line.trim())
        .where((String line) => line.isNotEmpty)
        .toList();

    // Deteksi merchant (prioritaskan baris header yang valid sebagai nama toko)
    String merchant = '';
    for (final String line in lines.take(10)) {
      final String cleaned = line
          .replaceAll(RegExp(r'[^A-Za-z0-9 &.\-]'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (!_isValidMerchantName(cleaned)) continue;
      merchant = cleaned.toUpperCase();
      break;
    }

    // ── Deteksi total (cek word boundary agar "Item : 4  TOTAL :Rp 37.000" juga terbaca) ──
    final RegExp finalTotal = RegExp(
      r'\b(?:grand\s+total|total(?:\s+(?:akhir|bayar|tagihan|belanja))?|jumlah\s+tagihan)\b',
      caseSensitive: false,
    );
    int? total;
    for (final String line in lines.reversed) {
      if (!finalTotal.hasMatch(line)) continue;
      total = _lastAmount(line);
      if (total != null) break;
    }

    // ── Segmentasi 3 Zona: Header -> Body (Daftar Item) -> Summary/Footer ──
    // Zona Footer/Summary dimulai saat ketemu TOTAL / TUNAI / KEMBALI / TERIMA KASIH
    final RegExp footerStartLine = RegExp(
      r'\b(?:total(?:\s+(?:akhir|bayar|tagihan|belanja))?|grand\s+total|'
      r'tunai|kembali|kembalian|uang\s+kembali|qris|terima\s*kasih|terimakasih)\b',
      caseSensitive: false,
    );

    // Baris metadata yang masih bagian dari Header (jangan ambil item sebelum/pada baris ini)
    final RegExp headerMetaLine = RegExp(
      r'(?:^(?:jl\.?|jalan\b|hp\.?\b|cp\.?\b|telp|telepon|trans\s*:|kassa\s*:|kasir\s*:|cashier\s*:|no\.?\s*(?:struk|nota|order|telp)|npwp)|'
      r'\b(?:hp|cp|telp)\.?\s*0\d{2,4}[\s\-]?\d{3,5}[\s\-]?\d{3,5}\b|'
      r'\b08\d{2}[\s\-]?\d{3,4}[\s\-]?\d{3,5}\b)',
      caseSensitive: false,
    );

    // Filter baris non-item (berlaku di mana saja dalam baris untuk kata pembayaran/summary)
    final RegExp summaryLine = RegExp(
      r'(?:^(?:sub\s*total|total|jumlah|grand\s+total|tunai|bayar|kembalian|kembali|change|cash|'
      r'qris|debit|kredit|anda\s+hemat|total\s+item|total\s+qty|items?\s*:|qty\s*:|before\s+rounding|after\s+rounding|dpp|non\s+tunai|'
      r'bca|mandiri|bri|bni|gopay|ovo|dana|shopeepay|transfer|edc|card|'
      r'approval|ref\s*no|trace|npwp|telp|telepon|hp\b|cp\b|trans\s*:|kassa\s*:|kasir\s*:|'
      r'no\.?\s*(?:telp|telepon|hp|wa|fax|struk|kasir|order)|'
      r'terima\s*kasih|terimakasih|link\s+kritik|kritik\s+dan\s+saran|designed\s+by|deiged\s+by)\b|'
      r'\b(?:total|tunai|kembalian|kembali|sub\s*total|grand\s+total|qris|anda\s+hemat|before\s+rounding)\b)',
      caseSensitive: false,
    );
    const List<String> chargeWords = <String>[
      'ppn', 'pb1', 'pajak', 'tax', 'vat', 'service', 'admin', 'ongkir',
      'diskon', 'potongan', 'disc', 'tip', 'gratuity', 'rounding', 'pembulatan',
    ];

    final RegExp numberedItem = RegExp(r'^\d+[.)]\s+(?=[A-Za-z])');
    // Kuantitas mendukung semua variasi:
    // - "1 lusin x 36,000  Rp 36.000"
    // - "1,00 X @14.500  :  14.500"
    // - "500.000  X1  500.000"
    // - "DULU  1 500 ml x 7,000"
    final RegExp quantityLine = RegExp(
      r'(?:^|\s)(?:[\d.,]+(?:\s+[A-Za-z0-9]+){0,2}\s*[x×]\s*@?\s*[\d.,]+|[\d.,]+\s*[x×]\d+\b)',
      caseSensitive: false,
    );
    final RegExp priceSuffix = RegExp(
      r'(?:\s+|^|:)(?:rp\.?\s*)?-?\d[\d.,]*\s*$',
      caseSensitive: false,
    );
    final RegExp barcodePrefix = RegExp(r'^\d{8,13}\s+');
    final RegExp leadingQtyPrefix = RegExp(r'^\d+\s*[x×]\s+', caseSensitive: false);
    final RegExp textDateLine = RegExp(
      r'\b\d{1,2}\s+(?:jan|januari|january|feb|februari|february|mar|maret|march|apr|april|mei|may|jun|juni|june|jul|juli|july|agu|agus|agustus|aug|august|sep|sept|september|okt|oktober|oct|october|nov|november|des|desember|dec|december)\s+\d{4}\b',
      caseSensitive: false,
    );
    final RegExp phoneOrTimeLine = RegExp(
      r'(?:^\d{1,2}:\d{2}(?::\d{2})?\b|\b08\d{2}[\s\-]?\d{3,4}[\s\-]?\d{3,5}\b|\b\+?628\d{7,12}\b|freepik|scribd|e-receipt|https?://)',
      caseSensitive: false,
    );

    // Cari batas akhir Header: jika ada baris tanggal/TRANS/KASSA/Hp di 12 baris awal,
    // semua baris sampai baris metadata terakhir tersebut dianggap Header (tidak diambil sebagai item).
    int bodyStartIndex = 0;
    final int headerScanLimit = lines.length < 12 ? lines.length : 12;
    for (int i = 0; i < headerScanLimit; i++) {
      final String l = lines[i];
      if (headerMetaLine.hasMatch(l) ||
          textDateLine.hasMatch(l) ||
          RegExp(r'\d{1,2}[/.\-]\d{1,2}[/.\-]\d{2,4}').hasMatch(l) ||
          RegExp(r'\d{4}[/.\-]\d{1,2}[/.\-]\d{1,2}').hasMatch(l) ||
          RegExp(r'^\d{1,2}:\d{2}').hasMatch(l)) {
        bodyStartIndex = i + 1;
      }
    }

    String? pendingName;
    final List<ReceiptItem> items = <ReceiptItem>[];
    for (int idx = bodyStartIndex; idx < lines.length; idx++) {
      String line = lines[idx].replaceFirst(barcodePrefix, '');

      // Begitu masuk zona Summary/Footer (TOTAL, TUNAI, KEMBALI, TERIMA KASIH), hentikan ekstraksi item
      // (kecuali "Sub Total" karena PPN/Service Charge sering berada setelah Sub Total)
      if (!RegExp(r'\bsub\s*total\b', caseSensitive: false).hasMatch(line) &&
          footerStartLine.hasMatch(line)) {
        break;
      }

      if (summaryLine.hasMatch(line) ||
          headerMetaLine.hasMatch(line) ||
          phoneOrTimeLine.hasMatch(line) ||
          textDateLine.hasMatch(line) ||
          RegExp(r'\d{1,2}[/.\-]\d{1,2}[/.\-]\d{2,4}').hasMatch(line) ||
          RegExp(r'\d{4}[/.\-]\d{1,2}[/.\-]\d{1,2}').hasMatch(line) ||
          RegExp(r'\d{14,}').hasMatch(line)) {
        pendingName = null;
        continue;
      }

      final String itemLine = line.replaceFirst(numberedItem, '');
      final String cleanedLine = itemLine.replaceAll(RegExp(r'\s+[A-Z*]\s*$'), '');
      final int? amount = priceSuffix.hasMatch(cleanedLine) ? _lastAmount(cleanedLine) : null;
      if (amount == null || amount <= 0) {
        final String candidate = itemLine.trim();
        pendingName = RegExp(r'^[A-Za-z]{2,}').hasMatch(candidate) ? candidate : null;
        continue;
      }

      String inlineName = cleanedLine.replaceFirst(priceSuffix, '').trim();
      final bool isQtyLine = quantityLine.hasMatch(cleanedLine);
      final bool separatePrice = (isQtyLine && pendingName != null) || inlineName.isEmpty;

      String? name = separatePrice ? pendingName : inlineName;
      pendingName = null;

      if (name == null) continue;
      name = name.replaceFirst(leadingQtyPrefix, '').trim();
      name = name.replaceAll(RegExp(r'\s+(?:rp\.?\s*)?\d[\d.,]*$'), '').trim();
      name = name.replaceFirst(RegExp(r'^[A-Z]{2,5}\s{2,}(?=\d+[.)]\s)'), '').replaceFirst(numberedItem, '').trim();

      if (!RegExp(r'[A-Za-z]{2,}').hasMatch(name)) continue;
      final String lower = name.toLowerCase();
      final bool isNegativeRounding =
          (lower.contains('rounding') || lower.contains('pembulatan')) &&
              RegExp(r'-\s*\d[\d.,]*\s*$').hasMatch(cleanedLine);
      final bool disc = _isDiscount(name) || isNegativeRounding;
      items.add(ReceiptItem(
        name: name,
        amount: amount,
        isCharge: disc || chargeWords.any(lower.contains),
        isDiscount: disc,
        categoryKey: receiptExpenseCategory(name),
      ));
    }

    if ((total == null || total <= 0) && items.isNotEmpty) {
      total = items.fold<int>(0, (int sum, ReceiptItem item) => sum + item.netAmount);
    }

    final DateTime? date = _findDateInLines(lines);
    return _sanitizeResult(ReceiptOcrResult(
      merchant: merchant,
      total: total,
      date: date,
      items: items,
      rawText: lines.take(3).join(' | '),
      usedLocalFallback: true,
    ));
  }

  static int? _lastAmount(String line) {
    final RegExpMatch? match = RegExp(r'(\d[\d.,]*)\s*$').firstMatch(line.trim());
    if (match == null) return null;
    return _parseRupiahAmount(match.group(1)!);
  }

  static DateTime? _findDateInLines(List<String> lines) {
    for (final String line in lines) {
      // YYYY[-/.]MM[-/.]DD (prioritas)
      final RegExpMatch? ymdMatch = RegExp(r'\b(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})\b').firstMatch(line);
      if (ymdMatch != null) {
        final DateTime? dt = _makeDate(
          int.parse(ymdMatch.group(1)!),
          int.parse(ymdMatch.group(2)!),
          int.parse(ymdMatch.group(3)!),
        );
        if (dt != null) return dt;
      }

      // DD[-/.]MM[-/.]YYYY
      final RegExpMatch? dmyMatch = RegExp(r'\b(\d{1,2})[-/.](\d{1,2})[-/.](\d{2,4})\b').firstMatch(line);
      if (dmyMatch != null) {
        int year = int.parse(dmyMatch.group(3)!);
        if (year < 100) year += 2000;
        final DateTime? dt = _makeDate(year, int.parse(dmyMatch.group(2)!), int.parse(dmyMatch.group(1)!));
        if (dt != null) return dt;
      }

      // "27 November 2026"
      final RegExpMatch? textMatch = RegExp(r'\b(\d{1,2})\s+([A-Za-z]{3,})\s+(\d{4})\b').firstMatch(line);
      if (textMatch != null) {
        final int? month = _monthFromName(textMatch.group(2)!);
        if (month != null) {
          final DateTime? dt = _makeDate(int.parse(textMatch.group(3)!), month, int.parse(textMatch.group(1)!));
          if (dt != null) return dt;
        }
      }
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

  bool isResultSuspicious(ReceiptOcrResult result) {
    if (result.items.isEmpty) return true;
    final bool hasProduct = result.items.any((i) => !i.isCharge);
    if (!hasProduct) return true;

    if (result.total != null && result.total! > 0) {
      final int itemSum = result.items.fold(0, (int s, ReceiptItem i) => s + i.netAmount);
      if (itemSum > 0) {
        final double ratio = (result.total! - itemSum).abs() / itemSum;
        if (ratio > 0.05 && (result.total! - itemSum).abs() > 1000) return true;
      }
    }

    return false;
  }

  Future<void> close() async {
    await _textRecognizer.close();
  }
}

// ── Data classes ─────────────────────────────────────────────────────────────

@visibleForTesting
class ReceiptTextBox {
  final String text;
  final double top;
  final double bottom;
  final double left;

  const ReceiptTextBox({
    required this.text,
    required this.top,
    required this.bottom,
    required this.left,
  });
}

class _ParsedResponse {
  final bool? isValidReceipt;
  final String? rejectionReason;
  final ReceiptOcrResult result;

  _ParsedResponse({
    required this.isValidReceipt,
    required this.rejectionReason,
    required this.result,
  });
}
