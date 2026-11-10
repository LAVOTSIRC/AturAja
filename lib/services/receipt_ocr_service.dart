import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class ReceiptOcrResult {
  final String merchant;
  final int? total;
  final DateTime? date;
  final String rawText;

  const ReceiptOcrResult({
    required this.merchant,
    required this.total,
    required this.date,
    required this.rawText,
  });
}

class ReceiptOcrException implements Exception {
  final String message;

  const ReceiptOcrException(this.message);

  @override
  String toString() => message;
}

class ReceiptParser {
  static ReceiptOcrResult parse(String rawText, {DateTime? referenceDate}) {
    final List<String> lines = rawText
        .split(RegExp(r'[\r\n]+'))
        .map((String line) => line.trim())
        .where((String line) => line.isNotEmpty)
        .toList();
    final DateTime baseDate = referenceDate ?? DateTime.now();

    return ReceiptOcrResult(
      merchant: _merchant(lines),
      total: _total(lines),
      date: _date(rawText, baseDate),
      rawText: rawText,
    );
  }

  static String _merchant(List<String> lines) {
    for (final String line in lines.take(5)) {
      final String normalized = line.toLowerCase();
      if (_containsDate(normalized) ||
          normalized.contains('total') ||
          normalized.contains('kasir') ||
          normalized.contains('telp') ||
          _extractAmount(line) != null) {
        continue;
      }
      final String cleaned = line.replaceAll(
        RegExp(
          r'[^A-Za-z0-9 &.'
          '-]',
        ),
        '',
      );
      if (cleaned.length >= 2) {
        return cleaned;
      }
    }
    return '';
  }

  static int? _total(List<String> lines) {
    final List<String> priorityLines = lines
        .where(
          (String line) => RegExp(
            r'\b(grand\s*total|total\s*bayar|total|amount\s*due|jumlah)\b',
            caseSensitive: false,
          ).hasMatch(line),
        )
        .toList();
    for (final String line in <String>[
      ...priorityLines.reversed,
      ...lines.reversed,
    ]) {
      final int? amount = _extractAmount(line);
      if (amount != null && (priorityLines.isNotEmpty || amount > 0)) {
        return amount;
      }
    }
    return null;
  }

  static int? _extractAmount(String line) {
    final Iterable<RegExpMatch> matches = RegExp(
      r'(?:rp\.?\s*)?(\d[\d\s.,]*)',
      caseSensitive: false,
    ).allMatches(line);
    int? result;
    for (final RegExpMatch match in matches) {
      final String value = match.group(1)!.trim();
      final int? parsed = _parseAmount(value);
      if (parsed != null) {
        result = parsed;
      }
    }
    return result;
  }

  static int? _parseAmount(String value) {
    final String compact = value.replaceAll(' ', '');
    if (compact.isEmpty || !RegExp(r'^\d[\d.,]*$').hasMatch(compact)) {
      return null;
    }
    String digits = compact;
    if (compact.contains('.') && compact.contains(',')) {
      final int lastDot = compact.lastIndexOf('.');
      final int lastComma = compact.lastIndexOf(',');
      final int separator = lastDot > lastComma ? lastDot : lastComma;
      final int decimalLength = compact.length - separator - 1;
      digits = decimalLength <= 2
          ? compact.substring(0, separator).replaceAll(RegExp(r'[.,]'), '')
          : compact.replaceAll(RegExp(r'[.,]'), '');
    } else if (compact.contains('.') || compact.contains(',')) {
      final String separator = compact.contains('.') ? '.' : ',';
      final List<String> parts = compact.split(separator);
      digits = parts.length == 2 && parts.last.length <= 2
          ? parts.first.replaceAll(separator, '')
          : compact.replaceAll(separator, '');
    }
    return int.tryParse(digits);
  }

  static DateTime? _date(String text, DateTime referenceDate) {
    final RegExp numericDate = RegExp(
      r'\b(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})\b',
    );
    final RegExpMatch? match = numericDate.firstMatch(text);
    if (match != null) {
      final int day = int.parse(match.group(1)!);
      final int month = int.parse(match.group(2)!);
      final int rawYear = int.parse(match.group(3)!);
      final int year = rawYear < 100 ? 2000 + rawYear : rawYear;
      return _validDate(year, month, day);
    }

    final RegExp monthDate = RegExp(
      r'\b(\d{1,2})\s+'
      r'(jan|feb|mar|apr|mei|may|jun|jul|agu|aug|sep|okt|oct|nov|des|dec)'
      r'(?:\s+(\d{4}))?\b',
      caseSensitive: false,
    );
    final RegExpMatch? monthMatch = monthDate.firstMatch(text);
    if (monthMatch != null) {
      const Map<String, int> months = <String, int>{
        'jan': 1,
        'feb': 2,
        'mar': 3,
        'apr': 4,
        'mei': 5,
        'may': 5,
        'jun': 6,
        'jul': 7,
        'agu': 8,
        'aug': 8,
        'sep': 9,
        'okt': 10,
        'oct': 10,
        'nov': 11,
        'des': 12,
        'dec': 12,
      };
      final int? month = months[monthMatch.group(2)!.toLowerCase()];
      final int year =
          int.tryParse(monthMatch.group(3) ?? '') ?? referenceDate.year;
      return month == null
          ? null
          : _validDate(year, month, int.parse(monthMatch.group(1)!));
    }
    return null;
  }

  static bool _containsDate(String value) =>
      RegExp(r'\b\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\b').hasMatch(value);

  static DateTime? _validDate(int year, int month, int day) {
    final DateTime date = DateTime(year, month, day);
    return date.year == year && date.month == month && date.day == day
        ? date
        : null;
  }
}

class ReceiptOcrService {
  ReceiptOcrService({TextRecognizer? recognizer})
    : _recognizer =
          recognizer ?? TextRecognizer(script: TextRecognitionScript.latin);

  final TextRecognizer _recognizer;

  Future<ReceiptOcrResult> recognizeFile(String imagePath) async {
    try {
      final RecognizedText recognized = await _recognizer.processImage(
        InputImage.fromFilePath(imagePath),
      );
      final ReceiptOcrResult result = ReceiptParser.parse(recognized.text);
      if (result.total == null &&
          result.merchant.isEmpty &&
          result.date == null) {
        throw const ReceiptOcrException(
          'Teks struk tidak terbaca. Silakan isi data secara manual.',
        );
      }
      return result;
    } on ReceiptOcrException {
      rethrow;
    } catch (error) {
      throw ReceiptOcrException(
        'OCR gagal membaca foto struk. Silakan isi data secara manual. ($error)',
      );
    }
  }

  Future<void> close() => _recognizer.close();
}
