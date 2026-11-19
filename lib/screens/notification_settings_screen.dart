import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/routes.dart';
import '../data/roasting_intensity.dart';
import '../providers/settings_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/theme_scope.dart';
import '../widgets/common.dart';

class NotificationSettingsScreen extends StatelessWidget {
  final SettingsController settings;
  final Future<bool> Function(bool value)? onDeadlineChanged;
  final Future<bool> Function(bool value)? onBudgetAlertsChanged;
  final Future<bool> Function(bool value)? onBudgetRoastingChanged;
  final Future<bool> Function(bool value)? onDeadlineRoastingChanged;
  final Future<bool> Function(bool value)? onDailyRoastingChanged;
  final Future<void> Function(int hour, int minute)? onDailyTimeChanged;

  const NotificationSettingsScreen({
    super.key,
    required this.settings,
    this.onDeadlineChanged,
    this.onBudgetAlertsChanged,
    this.onBudgetRoastingChanged,
    this.onDeadlineRoastingChanged,
    this.onDailyRoastingChanged,
    this.onDailyTimeChanged,
  });

  Future<void> _pickDailyTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: settings.dailyRoastingHour,
        minute: settings.dailyRoastingMinute,
      ),
      helpText: 'Pilih waktu Daily Roasting',
      builder: (BuildContext context, Widget? child) {
        final MediaQueryData data = MediaQuery.of(context);
        return MediaQuery(
          data: data.copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    if (picked == null) {
      return;
    }
    final Future<void> Function(int hour, int minute)? handler =
        onDailyTimeChanged;
    if (handler != null) {
      await handler(picked.hour, picked.minute);
      return;
    }
    settings.setDailyRoastingTime(picked.hour, picked.minute);
  }

  Future<void> _applyToggle(
    BuildContext context, {
    required Future<bool> Function(bool value)? handler,
    required ValueChanged<bool> fallback,
    required bool value,
  }) async {
    if (handler == null) {
      fallback(value);
      return;
    }
    final bool applied = await handler(value);
    if (!applied && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Izin notifikasi diperlukan. Aktifkan izin notifikasi AturAja '
            'di pengaturan perangkat.',
          ),
        ),
      );
    }
  }

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
                  onChanged: (bool value) => _applyToggle(
                    context,
                    handler: onDeadlineChanged,
                    fallback: settings.setDeadlineNotifications,
                    value: value,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                const SectionLabel('Peringatan Anggaran'),
                _NotificationToggleCard(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Budget Alert',
                  subtitle: 'Peringatan saat pengeluaran mendekati limit.',
                  value: settings.budgetAlertsEnabled,
                  onChanged: (bool value) => _applyToggle(
                    context,
                    handler: onBudgetAlertsChanged,
                    fallback: settings.setBudgetAlerts,
                    value: value,
                  ),
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
                const SizedBox(height: AppSpacing.md),
                const SectionLabel('Notifikasi Roasting Otomatis'),
                _NotificationToggleCard(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Budget Roasting',
                  subtitle:
                      'Roasting saat pengeluaran mencapai 80% dan 100% '
                      'anggaran bulanan.',
                  value: settings.budgetRoastingEnabled,
                  enabled:
                      settings.roastingAiEnabled &&
                      settings.budgetAlertsEnabled,
                  disabledReason: settings.roastingAiEnabled
                      ? 'Aktifkan Budget Alert terlebih dahulu agar Budget '
                            'Roasting dapat dikirim.'
                      : 'Aktifkan Roasting AI untuk memakai fitur ini.',
                  onChanged: (bool value) => _applyToggle(
                    context,
                    handler: onBudgetRoastingChanged,
                    fallback: settings.setBudgetRoasting,
                    value: value,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                _NotificationToggleCard(
                  icon: Icons.alarm_outlined,
                  title: 'Deadline Roasting',
                  subtitle:
                      'Roasting saat pengingat deadline tugas dijadwalkan.',
                  value: settings.deadlineRoastingEnabled,
                  enabled:
                      settings.roastingAiEnabled &&
                      settings.deadlineNotificationsEnabled,
                  disabledReason: settings.roastingAiEnabled
                      ? 'Aktifkan Deadline Tugas terlebih dahulu agar Deadline '
                            'Roasting dapat dikirim.'
                      : 'Aktifkan Roasting AI untuk memakai fitur ini.',
                  onChanged: (bool value) => _applyToggle(
                    context,
                    handler: onDeadlineRoastingChanged,
                    fallback: settings.setDeadlineRoasting,
                    value: value,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                _NotificationToggleCard(
                  icon: Icons.wb_sunny_outlined,
                  title: 'Daily Roasting',
                  subtitle:
                      'Ringkasan aktivitas yang dikirim sekali sehari sesuai '
                      'waktu pilihanmu.',
                  value: settings.dailyRoastingEnabled,
                  enabled: settings.roastingAiEnabled,
                  disabledReason:
                      'Aktifkan Roasting AI untuk memakai fitur ini.',
                  onChanged: (bool value) => _applyToggle(
                    context,
                    handler: onDailyRoastingChanged,
                    fallback: settings.setDailyRoasting,
                    value: value,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                _DailyRoastingTimeCard(
                  enabled: settings.roastingAiEnabled,
                  timeLabel: settings.dailyRoastingTimeLabel,
                  dailyEnabled: settings.dailyRoastingEnabled,
                  onTap: () => _pickDailyTime(context),
                ),
                const SizedBox(height: AppSpacing.md),
                const SectionLabel('Intensitas Roasting'),
                _RoastingIntensitySelector(
                  selected: settings.roastingIntensity,
                  enabled: settings.roastingAiEnabled,
                  onChanged: settings.setRoastingIntensity,
                ),
                const SizedBox(height: AppSpacing.md),
                const SectionLabel('Pratinjau Roasting'),
                _RoastingPreviewCard(intensity: settings.roastingIntensity),
                if (kDebugMode) ...[
                  const SizedBox(height: AppSpacing.lg),
                  const SectionLabel('Alat Pengembang'),
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: Material(
                      color: c.transparent,
                      child: ListTile(
                        leading: Icon(Icons.bug_report, color: c.blue),
                        title: Text(
                          'Notification Diagnostics',
                          style: AppTypography.label(c.text),
                        ),
                        subtitle: Text(
                          'Uji notifikasi langsung, deadline, budget, roasting AI & pantau status izin Android.',
                          style: AppTypography.meta(c.textMuted),
                        ),
                        trailing: Icon(Icons.chevron_right, color: c.textMuted),
                        onTap: () => context.push(AppRoutes.notificationDiagnostics),
                      ),
                    ),
                  ),
                ],
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
  final bool enabled;
  final String? disabledReason;
  final ValueChanged<bool> onChanged;

  const _NotificationToggleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.disabledReason,
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
          onChanged: enabled ? onChanged : null,
          secondary: Icon(icon, color: enabled ? c.blue : c.textMuted),
          title: Text(
            title,
            style: AppTypography.label(enabled ? c.text : c.textMuted),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(subtitle, style: AppTypography.meta(c.textMuted)),
              if (!enabled && disabledReason != null) ...[
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  disabledReason!,
                  style: AppTypography.micro(c.textMuted).copyWith(height: 1.4),
                ),
              ],
            ],
          ),
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

class _DailyRoastingTimeCard extends StatelessWidget {
  final bool enabled;
  final bool dailyEnabled;
  final String timeLabel;
  final VoidCallback onTap;

  const _DailyRoastingTimeCard({
    required this.enabled,
    required this.dailyEnabled,
    required this.timeLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final AppColors c = ThemeScope.of(context).colors;
    final String subtitle = enabled
        ? (dailyEnabled
              ? 'Dikirim setiap hari pukul $timeLabel waktu lokal.'
              : 'Daily Roasting nonaktif. Waktu pilihanmu tetap tersimpan.')
        : 'Aktifkan Roasting AI untuk mengatur waktu Daily Roasting.';
    return AppCard(
      padding: EdgeInsets.zero,
      child: Material(
        color: c.transparent,
        child: ListTile(
          enabled: enabled,
          onTap: enabled ? onTap : null,
          leading: Icon(
            Icons.schedule_outlined,
            color: enabled ? c.blue : c.textMuted,
          ),
          title: Text(
            'Waktu Daily Roasting',
            style: AppTypography.label(enabled ? c.text : c.textMuted),
          ),
          subtitle: Text(subtitle, style: AppTypography.meta(c.textMuted)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                timeLabel,
                style: AppTypography.label(enabled ? c.blue : c.textMuted)
                    .copyWith(fontWeight: FontWeight.w600),
              ),
              if (enabled) ...[
                const SizedBox(width: AppSpacing.xxs),
                Icon(
                  Icons.chevron_right,
                  size: AppSpacing.iconSmall,
                  color: c.textMuted,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RoastingIntensitySelector extends StatelessWidget {
  final RoastingIntensity selected;
  final bool enabled;
  final ValueChanged<RoastingIntensity> onChanged;

  const _RoastingIntensitySelector({
    required this.selected,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final AppColors c = ThemeScope.of(context).colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (
                int index = 0;
                index < RoastingIntensity.values.length;
                index++
              ) ...[
                if (index > 0)
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: c.border.withValues(alpha: 0.5),
                  ),
                _RoastingIntensityTile(
                  intensity: RoastingIntensity.values[index],
                  selected: selected == RoastingIntensity.values[index],
                  enabled: enabled,
                  onTap: () => onChanged(RoastingIntensity.values[index]),
                ),
              ],
            ],
          ),
        ),
        if (!enabled) ...[
          const SizedBox(height: AppSpacing.xs),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
            child: Text(
              'Aktifkan Roasting AI untuk menerapkan intensitas ini. '
              'Pilihanmu tetap tersimpan.',
              style: AppTypography.meta(c.textMuted),
            ),
          ),
        ],
      ],
    );
  }
}

class _RoastingIntensityTile extends StatelessWidget {
  final RoastingIntensity intensity;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _RoastingIntensityTile({
    required this.intensity,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final AppColors c = ThemeScope.of(context).colors;
    return PressableScale(
      onTap: enabled ? onTap : null,
      semanticLabel: 'Intensitas ${intensity.label}. ${intensity.description}',
      selected: selected,
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        color: selected ? c.blueDim : c.transparent,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xxs),
              child: Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: AppSpacing.iconMedium,
                color: selected ? c.blue : c.textMuted,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    intensity.label,
                    style: AppTypography.label(selected ? c.blue : c.text)
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    intensity.description,
                    style: AppTypography.meta(c.textMuted)
                        .copyWith(height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoastingPreviewCard extends StatelessWidget {
  final RoastingIntensity intensity;

  const _RoastingPreviewCard({required this.intensity});

  @override
  Widget build(BuildContext context) {
    final AppColors c = ThemeScope.of(context).colors;
    return AppCard(
      background: c.roastBg,
      borderColor: c.warning.withValues(alpha: 0.5),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.local_fire_department_outlined,
                size: AppSpacing.iconSmall,
                color: c.warning,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'CONTOH GAYA ${intensity.label.toUpperCase()}',
                style: AppTypography.overline(c.warning)
                    .copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.8),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: Text(
              intensity.preview,
              key: ValueKey<RoastingIntensity>(intensity),
              style: AppTypography.caption(c.textSub).copyWith(height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
