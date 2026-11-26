import 'package:flutter_test/flutter_test.dart';

import 'package:aturaja/services/receipt_ocr_service.dart';

void main() {
  // ── ReceiptOcrResult ──────────────────────────────────────────────────────

  group('ReceiptOcrResult.hasFinancialInfo', () {
    test('returns true when total > 0', () {
      const ReceiptOcrResult result = ReceiptOcrResult(
        merchant: 'Indomaret',
        total: 28500,
        date: null,
        rawText: '',
      );
      expect(result.hasFinancialInfo, isTrue);
    });

    test('returns true when items list is non-empty even without total', () {
      const ReceiptOcrResult result = ReceiptOcrResult(
        merchant: 'Warung',
        total: null,
        date: null,
        items: <ReceiptItem>[ReceiptItem(name: 'Nasi goreng', amount: 15000)],
        rawText: '',
      );
      expect(result.hasFinancialInfo, isTrue);
    });

    test('returns false when total is null and items are empty', () {
      const ReceiptOcrResult result = ReceiptOcrResult(
        merchant: '',
        total: null,
        date: null,
        rawText: 'gambar bukan struk',
      );
      expect(result.hasFinancialInfo, isFalse);
    });

    test('returns false when total is 0', () {
      const ReceiptOcrResult result = ReceiptOcrResult(
        merchant: 'Toko',
        total: 0,
        date: null,
        rawText: '',
      );
      expect(result.hasFinancialInfo, isFalse);
    });
  });

  // ── ReceiptItem ───────────────────────────────────────────────────────────

  group('ReceiptItem', () {
    test('stores name and amount correctly', () {
      const ReceiptItem item = ReceiptItem(name: 'Aqua 600ml', amount: 5000);
      expect(item.name, 'Aqua 600ml');
      expect(item.amount, 5000);
    });
  });

  // ── ReceiptOcrException ───────────────────────────────────────────────────

  group('ReceiptOcrException', () {
    test('toString returns message', () {
      const ReceiptOcrException ex = ReceiptOcrException('Struk tidak terbaca');
      expect(ex.toString(), 'Struk tidak terbaca');
    });
  });

  // ── ReceiptOcrService instantiation ──────────────────────────────────────

  group('ReceiptOcrService', () {
    test('ReceiptOcrService class is importable and constructors exist', () {
      // Hanya memastikan class dapat diimpor dan tipe-nya ada.
      // Instansiasi nyata memerlukan Firebase app aktif (integration test).
      expect(ReceiptOcrService, isNotNull);
    });
  });
}
