import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/theme_scope.dart';
import 'common.dart';

class RoastingToast extends StatelessWidget {
  final VoidCallback onClose;

  const RoastingToast({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final AppColors c = ThemeScope.of(context).colors;
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
        0,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: c.roastBg,
        border: Border.all(color: c.warning.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(AppSpacing.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.local_fire_department_outlined,
            size: AppSpacing.iconSmall,
            color: c.warning,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ROASTING AI',
                  style: AppTypography.overline(
                    c.warning,
                  ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.8),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'Bro, lu habis duit buat Spotify & kopi tapi Laporan Praktikum belum kelar? Prioritas lu dimana bestie?',
                  style: AppTypography.caption(c.textSub).copyWith(height: 1.5),
                ),
              ],
            ),
          ),
          PressableScale(
            onTap: onClose,
            semanticLabel: 'Tutup roasting',
            tooltip: 'Tutup',
            child: SizedBox(
              width: AppSpacing.target,
              height: AppSpacing.target,
              child: Icon(
                Icons.close,
                size: AppSpacing.iconSmall,
                color: c.textSub,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
