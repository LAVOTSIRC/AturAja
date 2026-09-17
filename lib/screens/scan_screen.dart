import 'package:flutter/material.dart';
import '../theme/theme_scope.dart';
import '../widgets/common.dart';

enum _ScanStep { scan, confirm }

/// Full-screen "Scan Struk" flow: camera placeholder -> confirmation.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  _ScanStep step = _ScanStep.scan;
  final TextEditingController amountController = TextEditingController(text: '28500');

  @override
  void dispose() {
    amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = ThemeScope.of(context).colors;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: c.surface,
                        border: Border.all(color: c.border),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.close, size: 18, color: c.textSub),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('Scan Struk', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.text)),
                ],
              ),
            ),
            Expanded(
              child: step == _ScanStep.scan ? _scanBody(c) : _confirmBody(c),
            ),
          ],
        ),
      ),
    );
  }

  Widget _scanBody(dynamic c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 280),
              decoration: BoxDecoration(
                color: c.surface,
                border: Border.all(color: c.border),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(top: 12, left: 12, child: _corner(c, top: true, left: true)),
                  Positioned(top: 12, right: 12, child: _corner(c, top: true, left: false)),
                  Positioned(bottom: 12, left: 12, child: _corner(c, top: false, left: true)),
                  Positioned(bottom: 12, right: 12, child: _corner(c, top: false, left: false)),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 40, color: c.blue),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Arahkan kamera ke struk belanja',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, color: c.textMuted),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Vision AI akan membaca nominal secara otomatis dengan akurasi ≥85%',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: c.textSub, height: 1.6),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: () => setState(() => step = _ScanStep.confirm),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 13),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: c.teal, borderRadius: BorderRadius.circular(14)),
                child: const Text('Ambil Foto Struk',
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _corner(dynamic c, {required bool top, required bool left}) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        border: Border(
          top: top ? BorderSide(color: c.teal, width: 2) : BorderSide.none,
          bottom: !top ? BorderSide(color: c.teal, width: 2) : BorderSide.none,
          left: left ? BorderSide(color: c.teal, width: 2) : BorderSide.none,
          right: !left ? BorderSide(color: c.teal, width: 2) : BorderSide.none,
        ),
      ),
    );
  }

  Widget _confirmBody(dynamic c) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppCard(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(color: c.teal, shape: BoxShape.circle),
                      child: const Icon(Icons.check, size: 11, color: Colors.white),
                    ),
                    const SizedBox(width: 6),
                    Text('Struk terbaca — Akurasi 94%',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.teal)),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(color: c.surfaceHigh, borderRadius: BorderRadius.circular(10)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('INDOMARET · 13/09/2026', style: TextStyle(fontSize: 11, color: c.textSub, fontFamily: 'monospace', height: 1.8)),
                      Text('Aqua 600ml ......... 5.000', style: TextStyle(fontSize: 11, color: c.textSub, fontFamily: 'monospace', height: 1.8)),
                      Text('Roti Tawar ......... 12.500', style: TextStyle(fontSize: 11, color: c.textSub, fontFamily: 'monospace', height: 1.8)),
                      Text('Chitato ............ 11.000', style: TextStyle(fontSize: 11, color: c.textSub, fontFamily: 'monospace', height: 1.8)),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Container(height: 1, color: c.border),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('TOTAL .............. 28.500',
                            style: TextStyle(fontSize: 11, color: c.text, fontWeight: FontWeight.w600, fontFamily: 'monospace', height: 1.8)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Nominal', style: TextStyle(fontSize: 10, color: c.textMuted)),
                        const SizedBox(height: 2),
                        Text('Rp28.500', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: c.text)),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Kategori', style: TextStyle(fontSize: 10, color: c.textMuted)),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.shopping_cart_outlined, size: 15, color: c.blue),
                            const SizedBox(width: 5),
                            Text('Belanja', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.blue)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text('Koreksi nominal jika perlu', style: TextStyle(fontSize: 11, color: c.textMuted)),
          const SizedBox(height: 6),
          TextField(
            controller: amountController,
            keyboardType: TextInputType.number,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: c.text),
            decoration: InputDecoration(
              filled: true,
              fillColor: c.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: c.borderAccent, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 13),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: c.blue, borderRadius: BorderRadius.circular(14)),
                child: const Text('Konfirmasi & Catat',
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600, fontSize: 14)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => setState(() => step = _ScanStep.scan),
              child: Text('Scan Ulang', style: TextStyle(color: c.textSub, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }
}
