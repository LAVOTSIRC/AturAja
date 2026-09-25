import 'package:flutter/material.dart';

import '../data/settings_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/theme_scope.dart';
import '../widgets/common.dart';

class NotificationSettingsScreen extends StatelessWidget {
  final SettingsController settings;

  const NotificationSettingsScreen({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    return SettingsDetailScaffold(
      title: 'Notifikasi & Roasting AI',
      child: AnimatedBuilder(
        animation: settings,
        builder: (BuildContext context, Widget? child) {
          final AppColors c = ThemeScope.of(context).colors;
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.xs,
              AppSpacing.md,
              AppSpacing.xxl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Perubahan langsung diterapkan tanpa tombol simpan tambahan.',
                  style: AppTypography.body(c.textSub),
                ),
                const SizedBox(height: AppSpacing.lg),
                const SectionLabel('Pengingat Tugas'),
                _NotificationToggleCard(
                  icon: Icons.task_alt_outlined,
                  title: 'Deadline Tugas',
                  subtitle: 'Pengingat sebelum tugas mencapai tenggat.',
                  value: settings.deadlineNotificationsEnabled,
                  onChanged: settings.setDeadlineNotifications,
                ),
                const SizedBox(height: AppSpacing.md),
                const SectionLabel('Peringatan Anggaran'),
                _NotificationToggleCard(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Budget Alert',
                  subtitle: 'Peringatan saat pengeluaran mendekati limit.',
                  value: settings.budgetAlertsEnabled,
                  onChanged: settings.setBudgetAlerts,
                ),
                const SizedBox(height: AppSpacing.md),
                const SectionLabel('Roasting AI'),
                _NotificationToggleCard(
                  icon: Icons.local_fire_department_outlined,
                  title: 'Roasting AI',
                  subtitle: 'Umpan balik motivation sesuai aktivitasmu.',
                  value: settings.roastingAiEnabled,
                  onChanged: settings.setRoastingAi,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _NotificationToggleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _NotificationToggleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final AppColors c = ThemeScope.of(context).colors;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Material(
        color: c.transparent,
        child: SwitchListTile(
          value: value,
          onChanged: onChanged,
          secondary: Icon(icon, color: c.blue),
          title: Text(title, style: AppTypography.label(c.text)),
          subtitle: Text(subtitle, style: AppTypography.meta(c.textMuted)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          activeThumbColor: c.blue,
          activeTrackColor: c.blueDim,
        ),
      ),
    );
  }
}
