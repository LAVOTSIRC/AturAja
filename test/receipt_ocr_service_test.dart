import 'package:flutter_test/flutter_test.dart';

import 'package:aturaja/services/receipt_ocr_service.dart';

void main() {
  test('parses Indonesian receipt with Rp total and numeric date', () {
    final ReceiptOcrResult result = ReceiptParser.parse(
      'INDOMARET\nAqua 600ml 5.000\nTOTAL BAYAR Rp 28.500\n10/11/2026',
    );

    expect(result.merchant, 'INDOMARET');
    expect(result.total, 28500);
    expect(result.date, DateTime(2026, 11, 10));
  });

  test('parses comma-separated total and month name date', () {
    final ReceiptOcrResult result = ReceiptParser.parse(
      'Warung Makan Sederhana\nTotal: 125,000\n5 Nov 2026',
    );

    expect(result.merchant, 'Warung Makan Sederhana');
    expect(result.total, 125000);
    expect(result.date, DateTime(2026, 11, 5));
  });

  test('uses the total line instead of the largest item line', () {
    final ReceiptOcrResult result = ReceiptParser.parse(
      'TOKO ABC\nBarang 100.000\nBarang 250.000\nGrand Total 350.000',
    );

    expect(result.total, 350000);
  });

  test('ignores receipt date and item quantity when reading a total', () {
    final ReceiptOcrResult result = ReceiptParser.parse(
      'Alfamart\n'
      'Cimory\n'
      '1x 2.000\n'
      'Cimory hazelnut\n'
      '1x 9.000\n'
      'AQUA 600 ML 1 5.000\n'
      'Tanggal 10/11/2026\n'
      'TOTAL BAYAR: Rp 28.500',
    );

    expect(result.merchant, 'Alfamart');
    expect(result.total, 28500);
    expect(result.date, DateTime(2026, 11, 10));
    expect(
      result.items.map((ReceiptItem item) => item.name),
      containsAll(<String>['Cimory', 'Cimory hazelnut']),
    );
  });

  test('accepts spaces and repeated separators from noisy OCR', () {
    final ReceiptOcrResult result = ReceiptParser.parse(
      'Warung\nTOTAL 28.. 500',
    );

    expect(result.total, 28500);
  });

  test('returns nullable fields when text is too incomplete', () {
    final ReceiptOcrResult result = ReceiptParser.parse('struk buram');

    expect(result.merchant, 'struk buram');
    expect(result.total, isNull);
    expect(result.date, isNull);
  });
}
