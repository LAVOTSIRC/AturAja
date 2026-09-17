import 'package:flutter/material.dart';
import '../theme/theme_scope.dart';

/// Playful AI "roasting" notification banner shown at the top of Home.
class RoastingToast extends StatelessWidget {
  final VoidCallback onClose;
  const RoastingToast({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final c = ThemeScope.of(context).colors;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: c.roastBg,
        border: Border.all(color: c.amber.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.local_fire_department_outlined, size: 20, color: c.amber),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ROASTING AI',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: c.amber, letterSpacing: 0.8),
                ),
                const SizedBox(height: 4),
                Text(
                  'Bro, lu habis duit buat Spotify & kopi tapi Laporan Praktikum belum kelar? Prioritas lu dimana bestie?',
                  style: TextStyle(fontSize: 12, color: c.textSub, height: 1.5),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onClose,
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Icon(Icons.close, size: 18, color: c.textSub.withValues(alpha: 0.7)),
            ),
          ),
        ],
      ),
    );
  }
}
