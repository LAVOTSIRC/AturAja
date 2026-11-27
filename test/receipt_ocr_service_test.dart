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

  group('ReceiptOcrService.parseLocally', () {
    test('pairs receipt product names with quantity and price lines', () {
      final ReceiptOcrResult result = ReceiptOcrService.parseLocally(
        'TOKO\nNo.0-3\n'
        '1. Indomie Goreng\n1 lusin x 36,000    Rp 36.000\n'
        '2. Fruit Tea Apple\n1 500 ml x 7,000    Rp 7.000\n'
        '3. Belfood Sosis Bakar\n1 x 27,000\nRp 27.000',
      );
      expect(result.items.map((item) => item.name), [
        'Indomie Goreng',
        'Fruit Tea Apple',
        'Belfood Sosis Bakar',
      ]);
      expect(result.items.map((item) => item.amount), [36000, 7000, 27000]);
      expect(result.total, 70000);
    });

    test('membaca total, item, tanggal, dan toko tanpa Gemini', () {
      final ReceiptOcrResult result = ReceiptOcrService.parseLocally(
        'INDOMARET 24 JAM\n'
        'Cimory 2.000\n'
        'Frestea Madu 8.000\n'
        'PPN 1.000\n'
        'TOTAL 29.000\n'
        'Tunai 30.000\n'
        'Kembalian 1.000\n'
        '12/11/2026\n',
      );

      expect(result.merchant, 'INDOMARET 24 JAM');
      expect(result.total, 29000);
      expect(result.date, DateTime(2026, 11, 12));
      expect(result.items, hasLength(3));
      expect(result.items.first.name, 'Cimory');
      expect(result.items.first.amount, 2000);
      expect(result.items.last.isCharge, isTrue);
      expect(result.usedLocalFallback, isTrue);
    });

    test('mempertahankan 30 item dan memakai total akhir', () {
      final ReceiptOcrResult result = ReceiptOcrService.parseLocally(
        <String>[
          'TOKO CAMPURAN',
          'Susu 10.000',
          'Parkir 5.000',
          for (int i = 0; i < 28; i++) 'Sabun 2.000',
          'SUBTOTAL 71.000',
          'PPN 1.000',
          'GRAND TOTAL 72.000',
          'TUNAI 80.000',
        ].join('\n'),
      );

      expect(result.items, hasLength(31));
      expect(result.total, 72000);
      expect(result.items.take(3).map((item) => item.categoryKey), <String?>[
        'food',
        'transport',
        'belanja',
      ]);
    });

    test('menjumlah item bila tidak ada total eksplisit', () {
      final ReceiptOcrResult result = ReceiptOcrService.parseLocally(
        'WARUNG\nNasi 15000\nTeh 5000\n',
      );
      expect(result.total, 20000);
    });
  });

  group('ReceiptOcrService.appCheckMessage', () {
    test('memberi petunjuk debug token untuk error attestation', () {
      expect(
        ReceiptOcrService.appCheckMessage('App attestation failed'),
        contains('Firebase App Check'),
      );
    });

    test('mengembalikan null untuk error lain', () {
      expect(ReceiptOcrService.appCheckMessage('high demand'), isNull);
    });
  });
}
