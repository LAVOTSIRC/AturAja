import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/theme_scope.dart';
import '../widgets/common.dart';

class _SettingItem {
  final IconData icon;
  final String label;
  final String sub;

  const _SettingItem(this.icon, this.label, this.sub);
}

class _StatItem {
  final IconData icon;
  final String value;
  final String label;

  const _StatItem(this.icon, this.value, this.label);
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static const stats = [
    _StatItem(Icons.task_alt_outlined, '12', 'Tugas Selesai'),
    _StatItem(Icons.savings_outlined, '874rb', 'Total Hemat'),
    _StatItem(Icons.local_fire_department_outlined, '7 hari', 'Streak'),
  ];

  static const settings = [
    _SettingItem(Icons.notifications_none, 'Notifikasi & Roasting AI', 'Aktif'),
    _SettingItem(Icons.cloud_outlined, 'Cadangan Cloud', 'Sinkron 10 mnt lalu'),
    _SettingItem(
      Icons.credit_card_outlined,
      'Limit Anggaran',
      'Rp1.200.000/bulan',
    ),
    _SettingItem(Icons.psychology_outlined, 'Simulasi NLP', 'Model lokal v2.1'),
    _SettingItem(Icons.lock_outline, 'Privasi & Keamanan', ''),
  ];

  void _showSettingMessage(BuildContext context, _SettingItem item) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${item.label} belum tersedia pada mode simulasi.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = ThemeScope.of(context).colors;

    return Container(
      color: c.bg,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: AppSpacing.screenBottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.xs,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Profil', style: AppTypography.titleLarge(c.text)),
                    const ThemeToggleSwitch(),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Center(
                  child: Column(
                    children: [
                      Container(
                        width: AppSpacing.avatar,
                        height: AppSpacing.avatar,
                        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: c.surface,
                          border: Border.all(color: c.border),
                          borderRadius: BorderRadius.circular(AppSpacing.xl),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'ZR',
                          style: AppTypography.display(c.blue)
                              .copyWith(letterSpacing: -0.5),
                        ),
                      ),
                      Text(
                        'M Zidan Ruriano A.G',
                        style: AppTypography.title(c.text),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        '241401063 · Ilmu Komputer',
                        style: AppTypography.meta(c.textMuted),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Container(
                        constraints: const BoxConstraints(
                          minHeight: AppSpacing.targetCompact,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: c.successDim,
                          borderRadius: BorderRadius.circular(AppSpacing.huge),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: AppSpacing.xs,
                              height: AppSpacing.xs,
                              decoration: BoxDecoration(
                                color: c.success,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              'Mode Luring Aktif',
                              style: AppTypography.meta(c.success)
                                  .copyWith(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Row(
                  children: stats
                      .map(
                        (_StatItem stat) => Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.xxs,
                            ),
                            child: AppCard(
                              padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.sm,
                                horizontal: AppSpacing.xs,
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    stat.icon,
                                    size: AppSpacing.iconSmall,
                                    color: c.blue,
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    stat.value,
                                    style: AppTypography.bodyLarge(c.text)
                                        .copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: AppSpacing.xxs),
                                  Text(
                                    stat.label,
                                    textAlign: TextAlign.center,
                                    style: AppTypography.micro(c.textMuted)
                                        .copyWith(height: 1.3),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionLabel('Pengaturan'),
                    Column(
                      children: settings
                          .map(
                            (_SettingItem item) => Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.xxs,
                              ),
                              child: PressableScale(
                                onTap: () => _showSettingMessage(context, item),
                                semanticLabel: item.sub.isEmpty
                                    ? item.label
                                    : '${item.label}. ${item.sub}',
                                tooltip: item.label,
                                excludeSemantics: true,
                                child: AppCard(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.sm,
                                    vertical: AppSpacing.sm,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        item.icon,
                                        size: AppSpacing.iconSmall,
                                        color: c.blue,
                                      ),
                                      const SizedBox(width: AppSpacing.sm),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.label,
                                              style: AppTypography.label(
                                                c.text,
                                              ),
                                            ),
                                            if (item.sub.isNotEmpty) ...[
                                              const SizedBox(
                                                height: AppSpacing.xxs,
                                              ),
                                              Text(
                                                item.sub,
                                                style: AppTypography.micro(
                                                  c.textMuted,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        Icons.chevron_right,
                                        size: AppSpacing.md,
                                        color: c.textMuted,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
