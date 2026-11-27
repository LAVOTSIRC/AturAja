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

    test('membersihkan prefix barcode, trailing POS flag, dan baris pembayaran', () {
      final ReceiptOcrResult result = ReceiptOcrService.parseLocally(
        'JL. SUDIRMAN NO. 10\n'
        'NPWP 01.234.567.8-901.000\n'
        'ALFAMART CABANG SUDIRMAN\n'
        '8991002101234 Susu Ultra 7.500 A\n'
        'Roti Tawar 12.500 *\n'
        'Diskon Member 2.000\n'
        'ANDA HEMAT 2.000\n'
        'QRIS 18.000\n'
        'KEMBALIAN 0\n'
        'TOTAL 18.000\n',
      );

      expect(result.merchant, 'ALFAMART CABANG SUDIRMAN');
      expect(result.items.map((e) => e.name), [
        'Susu Ultra',
        'Roti Tawar',
        'Diskon Member',
      ]);
      expect(result.items.map((e) => e.amount), [7500, 12500, 2000]);
      expect(result.items[2].isDiscount, isTrue);
      expect(result.total, 18000);
    });

    test('tahan banting terhadap No. Telp, noise background, watermark, dan template multi-baris', () {
      final ReceiptOcrResult result = ReceiptOcrService.parseLocally(
        '7 000\n'
        'deiged by freepik 4900\n'
        'Karis Jaya Shop\n'
        'Jl. Dr. Ir. H. Soekarno No.19\n'
        'No. Telp 0812345678\n'
        '16413520230802084636\n'
        '2023-08-02\n'
        '08:46:36\n'
        'No.0-3\n'
        '1. Indomie Goreng\n'
        '1 lusin x 36,000  Rp 36.000\n'
        '2. Fruit Tea Apple\n'
        'DULU  1 500 ml x 7,000  Rp 7.000\n'
        '3. Belfood Sosis Bakar\n'
        '1 x 27,000  Rp 27.000\n'
        'Total QTY : 14\n'
        'Sub Total  Rp 70.000\n'
        'Total  Rp 70.000\n'
        'Bayar (Cash)  Rp 70.000\n'
        'Kembalian  Rp 0\n',
      );

      expect(result.merchant, 'KARIS JAYA SHOP');
      expect(result.date, DateTime(2023, 8, 2));
      expect(result.total, 70000);
      expect(result.items.map((e) => e.name), [
        'Indomie Goreng',
        'Fruit Tea Apple',
        'Belfood Sosis Bakar',
      ]);
      expect(result.items.map((e) => e.amount), [36000, 7000, 27000]);
    });

    test('mendukung template 1-baris restoran dengan qty dan harga satuan', () {
      final ReceiptOcrResult result = ReceiptOcrService.parseLocally(
        'WARUNG NUSANTARA\n'
        '2x Nasi Goreng Spesial  25.000  50.000\n'
        '1x Es Teh Manis  5.000\n'
        'PB1 10%  5.500\n'
        'GRAND TOTAL  60.500\n',
      );

      expect(result.merchant, 'WARUNG NUSANTARA');
      expect(result.items.map((e) => e.name), [
        'Nasi Goreng Spesial',
        'Es Teh Manis',
        'PB1 10%',
      ]);
      expect(result.items.map((e) => e.amount), [50000, 5000, 5500]);
      expect(result.total, 60500);
    });

    test('mendukung template nama di atas lalu Harga X1 Subtotal di bawah dan mengabaikan tanggal teks', () {
      final ReceiptOcrResult result = ReceiptOcrService.parseLocally(
        'SCRIBD\n'
        'SURYA ELEKTRONIK\n'
        'Jl. Veteran Utara No.248B\n'
        'Telp. 0411 3628529\n'
        'Sabtu, 16 November 2019\n'
        '13:56:30\n'
        'PPG\n'
        '500.000  X1  500.000\n'
        'Pulse Sensor\n'
        '150.000  X1  150.000\n'
        'Pointer\n'
        '225.000  X1  225.000\n'
        'Total Belanja  Rp. 875.000\n'
        'Tunai  RP. 900.000\n'
        'Kembali  Rp. 25.000\n'
        'Terima Kasih\n',
      );

      expect(result.merchant, 'SURYA ELEKTRONIK');
      expect(result.date, DateTime(2019, 11, 16));
      expect(result.total, 875000);
      expect(result.items.map((e) => e.name), [
        'PPG',
        'Pulse Sensor',
        'Pointer',
      ]);
      expect(result.items.map((e) => e.amount), [500000, 150000, 225000]);
    });

    test('segmentasi 3 zona mengabaikan Hp di header, CP/NPWP di footer, dan membaca 1,00 X @14.500 : 14.500', () {
      final ReceiptOcrResult result = ReceiptOcrService.parseLocally(
        'UNGGUL MART ANTASARI\n'
        '~ MURAH DAN BERKAH ~\n'
        'JL. P. ANTASARI - TANJUNG REDEB\n'
        'Hp 0853 4830 2778\n'
        'BISA DELIVERY LHO...\n'
        'TRANS : 002-194709001\n'
        'KASSA : 002-IRGI  31.10.24 [19:47]\n'
        'FINNA ULEG SAMBAL UDANG 10\'SX15G/10\n'
        '1,00 X @14.500  :  14.500\n'
        'FINNA ULEG SAMBAL BAWANG 10\'SX20G/10\n'
        '1,00 X @14.500  :  14.500\n'
        'WALL\'S PADLE POP 55ML LEMON TEA/36\n'
        '1,00 X @3.000  :  3.000\n'
        'WALLS 57ML COOKIES & CREAM/42\n'
        '1,00 X @5.000  :  5.000\n'
        'Item : 4  TOTAL  :Rp  37.000\n'
        'TUNAI  :Rp  50.000\n'
        'Qty : 4  KEMBALI :Rp  13.000\n'
        '-== TERIMA KASIH ATAS KUNJUNGAN ANDA ==-\n'
        'CP. 0853 4845 5701\n'
        'NPWP. 061.332.005.0-727.000\n',
      );

      expect(result.merchant, 'UNGGUL MART ANTASARI');
      expect(result.date, DateTime(2024, 10, 31));
      expect(result.total, 37000);
      expect(result.items.map((e) => e.name), [
        'FINNA ULEG SAMBAL UDANG 10\'SX15G/10',
        'FINNA ULEG SAMBAL BAWANG 10\'SX20G/10',
        'WALL\'S PADLE POP 55ML LEMON TEA/36',
        'WALLS 57ML COOKIES & CREAM/42',
      ]);
      expect(result.items.map((e) => e.amount), [14500, 14500, 3000, 5000]);
    });

    test('mengabaikan ITEMS: 12 dan Before Rounding serta memperlakukan Rounding negatif sebagai pengurang (Solaria)', () {
      final ReceiptOcrResult result = ReceiptOcrService.parseLocally(
        'SOLARIA\n'
        'Date: 02 February 2025 12:57:10\n'
        'Receipt No.:073RC1022025/00133\n'
        'Chicken Cordon Bleu +  1  48,182\n'
        'Nasi Goreng Tom Yam  1  37,273\n'
        'EB AyamTeriyaki  1  23,637\n'
        'EB Mix Asam Manis  1  29,091\n'
        'Teh Manis Panas  4  32,728\n'
        'Es Batu  4  10,912\n'
        'ITEMS: 12  181,823\n'
        'Pb1 10%  18,182\n'
        'Before Rounding  200,005\n'
        'Rounding  -5\n'
        'Total  200,000\n'
        'BRI - Debit  200,000\n',
      );

      expect(result.merchant, 'SOLARIA');
      expect(result.date, DateTime(2025, 2, 2));
      expect(result.total, 200000);
      expect(
        result.items.any((e) => e.name.toUpperCase().contains('ITEMS')),
        isFalse,
      );
      expect(
        result.items.any((e) => e.name.toLowerCase().contains('before rounding')),
        isFalse,
      );
      final int netSum = result.items.fold<int>(0, (s, e) => s + e.netAmount);
      expect(netSum, 200000);
    });
  });

  group('ReceiptOcrService.reconstructLineBoxes', () {
    test('menggabungkan layout 2 kolom sejajar secara vertikal dan urut kiri-kanan', () {
      final String text = ReceiptOcrService.reconstructLineBoxes(
        const <ReceiptTextBox>[
          // Kolom kanan terdeteksi duluan atau terpisah blok
          ReceiptTextBox(text: '15.000', top: 100, bottom: 120, left: 250),
          ReceiptTextBox(text: '8.000', top: 132, bottom: 152, left: 255),
          // Kolom kiri
          ReceiptTextBox(text: 'Nasi Goreng', top: 102, bottom: 122, left: 20),
          ReceiptTextBox(text: 'Es Teh Manis', top: 130, bottom: 150, left: 20),
        ],
      );

      expect(text, 'Nasi Goreng  15.000\nEs Teh Manis  8.000');
    });
  });

  group('ReceiptOcrService.parseDate', () {
    test('mem-parse format YYYY-MM-DD, DD/MM/YYYY, dan bulan teks Indonesia', () {
      expect(ReceiptOcrService.parseDate('2026-11-12'), DateTime(2026, 11, 12));
      expect(ReceiptOcrService.parseDate('12/11/2026'), DateTime(2026, 11, 12));
      expect(ReceiptOcrService.parseDate('27 November 2026'), DateTime(2026, 11, 27));
      expect(ReceiptOcrService.parseDate('5 Agu 2025'), DateTime(2025, 8, 5));
      expect(ReceiptOcrService.parseDate('31/02/2026'), isNull);
    });
  });

  group('ReceiptOcrService.parseRupiahAmount', () {
    test('menangani desimal ,00 / .00 dan trailing POS flag', () {
      expect(ReceiptOcrService.parseRupiahAmount('15.000,00'), 15000);
      expect(ReceiptOcrService.parseRupiahAmount('15,000.00'), 15000);
      expect(ReceiptOcrService.parseRupiahAmount('Rp 12.500 A'), 12500);
      expect(ReceiptOcrService.parseRupiahAmount('8.000 *'), 8000);
    });
  });

  group('ReceiptOcrService.tryParseResponse & debugScanImageOverride', () {
    test('mem-parse JSON Gemini lengkap beserta is_discount dan is_charge', () {
      final ReceiptOcrResult? parsed = ReceiptOcrService.tryParseResponse(
        '```json\n'
        '{\n'
        '  "is_valid_receipt": true,\n'
        '  "merchant": "Superindo",\n'
        '  "total": 25000,\n'
        '  "date": "2026-11-10",\n'
        '  "items": [\n'
        '    {"name": "Apel", "amount": 20000, "category": "food", "is_charge": false, "is_discount": false},\n'
        '    {"name": "Promo Member", "amount": 2000, "category": "other", "is_charge": false, "is_discount": true},\n'
        '    {"name": "PPN", "amount": 7000, "category": "other", "is_charge": true, "is_discount": false}\n'
        '  ]\n'
        '}\n'
        '```',
      );

      expect(parsed, isNotNull);
      expect(parsed!.merchant, 'Superindo');
      expect(parsed.date, DateTime(2026, 11, 10));
      expect(parsed.total, 25000);
      expect(parsed.items, hasLength(3));
      expect(parsed.items[1].isDiscount, isTrue);
      expect(parsed.items[2].isCharge, isTrue);
    });

    test('scanReceiptImage mendukung debugScanImageOverride tanpa Firebase', () async {
      ReceiptOcrService.debugScanImageOverride = (_) async => const ReceiptOcrResult(
        merchant: 'Mock Store',
        total: 10000,
        date: null,
        items: <ReceiptItem>[ReceiptItem(name: 'Kopi', amount: 10000)],
        rawText: 'MOCK',
      );
      addTearDown(() => ReceiptOcrService.debugScanImageOverride = null);

      final ReceiptOcrService service = ReceiptOcrService(firebaseAI: null);
      final ReceiptOcrResult result = await service.scanReceiptImage('dummy.jpg');
      expect(result.merchant, 'Mock Store');
      expect(result.total, 10000);
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
