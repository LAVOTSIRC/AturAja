import 'package:flutter/material.dart';

import '../providers/app_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/theme_scope.dart';
import '../widgets/common.dart';

class CloudBackupScreen extends StatefulWidget {
  final AppProvider app;

  const CloudBackupScreen({super.key, required this.app});

  @override
  State<CloudBackupScreen> createState() => _CloudBackupScreenState();
}

class _CloudBackupScreenState extends State<CloudBackupScreen> {
  Future<void> _syncNow() async {
    final AppProvider app = widget.app;
    if (!app.canUseCloud) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Masuk ke akun terlebih dahulu untuk mencadangkan data.',
          ),
        ),
      );
      return;
    }
    try {
      await app.syncCloudNow();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cadangan cloud berhasil disinkronkan.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyinkronkan cloud: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppProvider app = widget.app;
    return SettingsDetailScaffold(
      title: 'Cadangan Cloud',
      child: AnimatedBuilder(
        animation: app,
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
                              color: app.cloudError == null
                                  ? c.successDim
                                  : c.expenseDim,
                              borderRadius: BorderRadius.circular(
                                AppSpacing.sm,
                              ),
                            ),
                            child: Icon(
                              app.cloudError == null
                                  ? Icons.cloud_done_outlined
                                  : Icons.cloud_off_outlined,
                              size: AppSpacing.iconSmall,
                              color: app.cloudError == null
                                  ? c.success
                                  : c.expense,
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
                                  app.cloudSyncStatus,
                                  style: AppTypography.label(c.text),
                                ),
                                if (app.hasPendingCloudWrites &&
                                    !app.isCloudSyncing) ...[  
                                  const SizedBox(height: AppSpacing.xxs),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.upload_outlined,
                                        size: 13,
                                        color: c.textMuted,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Perubahan menunggu dikirim',
                                        style: AppTypography.meta(c.textMuted),
                                      ),
                                    ],
                                  ),
                                ],
                                if (app.cloudError != null) ...[
                                  const SizedBox(height: AppSpacing.xxs),
                                  Text(
                                    app.cloudError!,
                                    style: AppTypography.meta(c.expense),
                                  ),
                                ],
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
                          value: app.settings.autoBackupEnabled,
                          onChanged: app.settings.setAutoBackup,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'Auto-backup',
                            style: AppTypography.label(c.text),
                          ),
                          subtitle: Text(
                            'Cadangkan otomatis setiap ada perubahan data.',
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
                  child: app.isCloudSyncing
                      ? AppProcessingState(
                          message: 'Menyinkronkan data ke cloud...',
                          color: c.blue,
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Unggah seluruh data lokal ke Firestore. Data cloud yang sudah ada tidak dihapus.',
                              style: AppTypography.meta(c.textMuted),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            SizedBox(
                              width: double.infinity,
                              child: PressableScale(
                                onTap: app.canUseCloud ? _syncNow : null,
                                semanticLabel: 'Sinkronkan cloud sekarang',
                                tooltip: 'Sinkronkan sekarang',
                                child: Container(
                                  constraints: const BoxConstraints(
                                    minHeight: AppSpacing.target,
                                  ),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: app.canUseCloud
                                        ? c.blue
                                        : c.surfaceHigh,
                                    borderRadius: BorderRadius.circular(
                                      AppSpacing.sm,
                                    ),
                                  ),
                                  child: Text(
                                    'Sinkronkan Sekarang',
                                    style: AppTypography.button(
                                      app.canUseCloud
                                          ? c.onAccent
                                          : c.textMuted,
                                    ),
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
