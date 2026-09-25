import 'package:flutter/material.dart';

import '../data/settings_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/theme_scope.dart';
import '../widgets/common.dart';

class CloudBackupScreen extends StatefulWidget {
  final SettingsController settings;

  const CloudBackupScreen({super.key, required this.settings});

  @override
  State<CloudBackupScreen> createState() => _CloudBackupScreenState();
}

class _CloudBackupScreenState extends State<CloudBackupScreen> {
  Future<void> _syncNow() async {
    await widget.settings.syncCloud();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cadangan cloud berhasil disinkronkan.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final SettingsController settings = widget.settings;
    return SettingsDetailScaffold(
      title: 'Cadangan Cloud',
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
                  'Pantau dan sinkronkan data AturAja tanpa meninggalkan halaman ini.',
                  style: AppTypography.body(c.textSub),
                ),
                const SizedBox(height: AppSpacing.lg),
                const SectionLabel('Status Sinkronisasi'),
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: AppSpacing.iconBox,
                            height: AppSpacing.iconBox,
                            decoration: BoxDecoration(
                              color: c.successDim,
                              borderRadius: BorderRadius.circular(
                                AppSpacing.sm,
                              ),
                            ),
                            child: Icon(
                              Icons.cloud_done_outlined,
                              size: AppSpacing.iconSmall,
                              color: c.success,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Sinkron terakhir',
                                  style: AppTypography.meta(c.textMuted),
                                ),
                                const SizedBox(height: AppSpacing.xxs),
                                Text(
                                  settings.cloudSyncStatus,
                                  style: AppTypography.label(c.text),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Divider(color: c.border, height: 1),
                      Material(
                        color: c.transparent,
                        child: SwitchListTile(
                          value: settings.autoBackupEnabled,
                          onChanged: settings.setAutoBackup,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'Auto-backup',
                            style: AppTypography.label(c.text),
                          ),
                          subtitle: Text(
                            'Cadangkan otomatis saat aplikasi digunakan.',
                            style: AppTypography.meta(c.textMuted),
                          ),
                          secondary: Icon(Icons.sync, color: c.blue),
                          activeThumbColor: c.blue,
                          activeTrackColor: c.blueDim,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                const SectionLabel('Tindakan'),
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: settings.isCloudSyncing
                      ? AppProcessingState(
                          message: 'Menyinkronkan data ke cloud...',
                          color: c.blue,
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Periksa koneksi sebelum menyinkronkan seluruh data lokal.',
                              style: AppTypography.meta(c.textMuted),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            SizedBox(
                              width: double.infinity,
                              child: PressableScale(
                                onTap: _syncNow,
                                semanticLabel: 'Sinkronkan cloud sekarang',
                                tooltip: 'Sinkronkan sekarang',
                                child: Container(
                                  constraints: const BoxConstraints(
                                    minHeight: AppSpacing.target,
                                  ),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: c.blue,
                                    borderRadius: BorderRadius.circular(
                                      AppSpacing.sm,
                                    ),
                                  ),
                                  child: Text(
                                    'Sinkronkan Sekarang',
                                    style: AppTypography.button(c.onAccent),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
