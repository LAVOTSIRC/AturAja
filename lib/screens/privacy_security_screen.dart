import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/settings_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/theme_scope.dart';
import '../widgets/common.dart';

class PrivacySecurityScreen extends StatefulWidget {
  final SettingsController settings;

  const PrivacySecurityScreen({super.key, required this.settings});

  @override
  State<PrivacySecurityScreen> createState() => _PrivacySecurityScreenState();
}

class _PrivacySecurityScreenState extends State<PrivacySecurityScreen> {
  bool isExporting = false;
  bool isDeleting = false;

  Future<void> _changePin() async {
    final String? pin = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => const _ChangePinDialog(),
    );
    if (!mounted || pin == null) {
      return;
    }
    widget.settings.markPinUpdated();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('PIN berhasil diperbarui ke $pin.')));
  }

  Future<void> _exportData() async {
    if (isExporting) {
      return;
    }
    setState(() => isExporting = true);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) {
      return;
    }
    setState(() => isExporting = false);

    final AppColors c = ThemeScope.of(context).colors;
    final SettingsController settings = widget.settings;
    final String exportData = JsonEncoder.withIndent('  ').convert({
      'notifikasi': {
        'deadline_tugas': settings.deadlineNotificationsEnabled,
        'budget_alert': settings.budgetAlertsEnabled,
        'roasting_ai': settings.roastingAiEnabled,
      },
      'cloud': {
        'auto_backup': settings.autoBackupEnabled,
        'terakhir_sinkron': settings.lastSyncedAt?.toIso8601String(),
      },
      'limit_anggaran': settings.monthlyBudgetLimit,
      'model_nlp': settings.nlpModelStatus,
      'biometrik': settings.biometricLockEnabled,
    });

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Pratinjau Ekspor Data'),
        content: SizedBox(
          width: 360,
          child: SingleChildScrollView(
            child: SelectableText(
              exportData,
              style: AppTypography.mono(c.textSub),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteAccount() async {
    if (widget.settings.accountDeletionRequested || isDeleting) {
      return;
    }
    final AppColors c = ThemeScope.of(context).colors;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Hapus akun AturAja?'),
        content: const Text(
          'Tindakan ini menghapus akun dan data terkait. Tindakan ini tidak dapat dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: c.expense),
            child: const Text('Hapus Akun'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) {
      return;
    }

    setState(() => isDeleting = true);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) {
      return;
    }
    setState(() => isDeleting = false);
    widget.settings.requestAccountDeletion();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Permintaan hapus akun telah dicatat.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final SettingsController settings = widget.settings;
    return SettingsDetailScaffold(
      title: 'Privasi & Keamanan',
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
                const SectionLabel('Keamanan'),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Material(
                    color: c.transparent,
                    child: SwitchListTile(
                      value: settings.biometricLockEnabled,
                      onChanged: settings.setBiometricLock,
                      secondary: Icon(Icons.fingerprint, color: c.blue),
                      title: Text(
                        'Kunci biometrik',
                        style: AppTypography.label(c.text),
                      ),
                      subtitle: Text(
                        'Minta autentikasi biometrik saat membuka aplikasi.',
                        style: AppTypography.meta(c.textMuted),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.xs,
                      ),
                      activeThumbColor: c.blue,
                      activeTrackColor: c.blueDim,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                const SectionLabel('Akses'),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Material(
                    color: c.transparent,
                    child: ListTile(
                      onTap: _changePin,
                      minTileHeight: AppSpacing.target,
                      leading: Icon(Icons.pin_outlined, color: c.blue),
                      title: Text(
                        'Ubah PIN',
                        style: AppTypography.label(c.text),
                      ),
                      subtitle: Text(
                        settings.pinWasUpdated
                            ? 'PIN telah diperbarui.'
                            : 'Atur PIN 4–6 digit.',
                        style: AppTypography.meta(c.textMuted),
                      ),
                      trailing: Icon(Icons.chevron_right, color: c.textMuted),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                const SectionLabel('Data & Akun'),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Material(
                    color: c.transparent,
                    child: Column(
                      children: [
                        ListTile(
                          onTap: isExporting ? null : _exportData,
                          minTileHeight: AppSpacing.target,
                          leading: Icon(
                            Icons.file_download_outlined,
                            color: c.blue,
                          ),
                          title: Text(
                            'Ekspor data',
                            style: AppTypography.label(c.text),
                          ),
                          subtitle: Text(
                            isExporting
                                ? 'Menyiapkan data...'
                                : 'Unduh salinan data akun.',
                            style: AppTypography.meta(c.textMuted),
                          ),
                          trailing: isExporting
                              ? const SizedBox(
                                  width: AppSpacing.iconSmall,
                                  height: AppSpacing.iconSmall,
                                  child: CircularProgressIndicator(
                                    strokeWidth: AppSpacing.xxs,
                                  ),
                                )
                              : Icon(Icons.chevron_right, color: c.textMuted),
                        ),
                        Divider(color: c.border, height: 1),
                        ListTile(
                          onTap: settings.accountDeletionRequested
                              ? null
                              : _confirmDeleteAccount,
                          minTileHeight: AppSpacing.target,
                          leading: Icon(
                            Icons.delete_forever_outlined,
                            color: c.expense,
                          ),
                          title: Text(
                            'Hapus akun',
                            style: AppTypography.label(c.expense),
                          ),
                          subtitle: Text(
                            settings.accountDeletionRequested
                                ? 'Akun ditandai untuk dihapus.'
                                : isDeleting
                                ? 'Menghapus akun...'
                                : 'Tindakan permanen dan tidak dapat dibatalkan.',
                            style: AppTypography.meta(c.expense),
                          ),
                          trailing: isDeleting
                              ? SizedBox(
                                  width: AppSpacing.iconSmall,
                                  height: AppSpacing.iconSmall,
                                  child: CircularProgressIndicator(
                                    strokeWidth: AppSpacing.xxs,
                                    color: c.expense,
                                  ),
                                )
                              : Icon(
                                  Icons.chevron_right,
                                  color: settings.accountDeletionRequested
                                      ? c.textMuted
                                      : c.expense,
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (settings.accountDeletionRequested) ...[
                  const SizedBox(height: AppSpacing.md),
                  AppCard(
                    background: c.expenseDim,
                    borderColor: c.expense,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_outlined, color: c.expense),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Permintaan penghapusan akun sudah dicatat.',
                            style: AppTypography.label(c.expense),
                          ),
                        ),
                      ],
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

class _ChangePinDialog extends StatefulWidget {
  const _ChangePinDialog();

  @override
  State<_ChangePinDialog> createState() => _ChangePinDialogState();
}

class _ChangePinDialogState extends State<_ChangePinDialog> {
  final TextEditingController pinController = TextEditingController();
  String? errorText;

  @override
  void dispose() {
    pinController.dispose();
    super.dispose();
  }

  void _save() {
    final String pin = pinController.text.trim();
    if (pin.length < 4 || pin.length > 6) {
      setState(() => errorText = 'PIN harus terdiri dari 4–6 digit.');
      return;
    }
    Navigator.of(context).pop(pin);
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = ThemeScope.of(context).colors;
    return AlertDialog(
      title: const Text('Ubah PIN'),
      content: TextField(
        controller: pinController,
        autofocus: true,
        obscureText: true,
        keyboardType: TextInputType.number,
        maxLength: 6,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (_) {
          if (errorText != null) {
            setState(() => errorText = null);
          }
        },
        decoration: InputDecoration(
          labelText: 'PIN baru',
          errorText: errorText,
        ),
        style: AppTypography.body(c.text),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        TextButton(onPressed: _save, child: const Text('Simpan PIN')),
      ],
    );
  }
}
