import 'package:flutter/material.dart';
import '../theme/theme_scope.dart';

enum _QuickAddMode { quick, brain }

/// Bottom-sheet modal to quickly log an expense or "brain dump" a note.
class QuickAddModal extends StatefulWidget {
  const QuickAddModal({super.key});

  @override
  State<QuickAddModal> createState() => _QuickAddModalState();
}

class _QuickAddModalState extends State<QuickAddModal> {
  _QuickAddMode mode = _QuickAddMode.quick;
  final TextEditingController inputController = TextEditingController();

  static const suggestions = ['15k batagor', '29k kopi', '54990 spotify'];

  @override
  void dispose() {
    inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = ThemeScope.of(context).colors;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: c.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 3,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(color: c.surfaceHigh, borderRadius: BorderRadius.circular(99)),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(color: c.surfaceHigh, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  _modeButton(c, _QuickAddMode.quick, Icons.edit_note_outlined, 'Catat Cepat'),
                  const SizedBox(width: 3),
                  _modeButton(c, _QuickAddMode.brain, Icons.psychology_outlined, 'Brain Dump'),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (mode == _QuickAddMode.quick) _quickBody(c) else _brainBody(c),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Batal', style: TextStyle(color: c.textMuted, fontSize: 13)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _modeButton(dynamic c, _QuickAddMode m, IconData icon, String label) {
    final active = mode == m;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => mode = m),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? c.blue : null,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: active ? Colors.black : c.textSub),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: active ? Colors.black : c.textSub,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quickBody(dynamic c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            style: TextStyle(fontSize: 12, color: c.textSub),
            children: [
              const TextSpan(text: 'Contoh: '),
              TextSpan(text: '"15k batagor"', style: TextStyle(color: c.blue)),
              const TextSpan(text: ' atau '),
              TextSpan(text: '"29000 kopi"', style: TextStyle(color: c.blue)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: inputController,
                autofocus: true,
                onSubmitted: (_) => Navigator.of(context).pop(),
                decoration: InputDecoration(
                  hintText: 'nominal + deskripsi...',
                  hintStyle: TextStyle(color: c.textMuted, fontSize: 14),
                  filled: true,
                  fillColor: c.surfaceHigh,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: c.border, width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: c.borderAccent, width: 1.5),
                  ),
                ),
                style: TextStyle(color: c.text, fontSize: 14),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: c.blue, borderRadius: BorderRadius.circular(12)),
                child: const Text('Catat', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600, fontSize: 13)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: suggestions.map((h) {
            return GestureDetector(
              onTap: () => setState(() => inputController.text = h),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: c.surfaceHigh,
                  border: Border.all(color: c.border),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(h, style: TextStyle(fontSize: 11, color: c.textSub)),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _brainBody(dynamic c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ceritakan apa saja — AI akan memilah ke tugas, jadwal, atau pengeluaran.',
          style: TextStyle(fontSize: 12, color: c.textSub),
        ),
        const SizedBox(height: 10),
        TextField(
          autofocus: true,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'Contoh: Besok ada quiz kalkulus jam 8, perlu bayar kos 500rb...',
            hintStyle: TextStyle(color: c.textMuted, fontSize: 13),
            filled: true,
            fillColor: c.surfaceHigh,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: c.border, width: 1.5),
            ),
          ),
          style: TextStyle(color: c.text, fontSize: 13, height: 1.6),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.auto_awesome, size: 13, color: c.blue),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'NLP otomatis mendeteksi jadwal, tugas & pengeluaran',
                style: TextStyle(fontSize: 11, color: c.blue),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: c.blue, borderRadius: BorderRadius.circular(12)),
              child: const Text('Proses dengan AI', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600, fontSize: 13)),
            ),
          ),
        ),
      ],
    );
  }
}
