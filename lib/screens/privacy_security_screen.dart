import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/models.dart';
import '../providers/app_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../services/app_lock_service.dart';
import '../services/auth_service.dart';
import '../services/data_export_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/theme_scope.dart';
import '../widgets/common.dart';

class PrivacySecurityScreen extends StatefulWidget {
  final SettingsController settings;
  final AppProvider? app;
  final AuthProvider? auth;
  final AppLockService? appLockService;
  final DataExportService? exportService;

  const PrivacySecurityScreen({
    super.key,
    required this.settings,
    this.app,
    this.auth,
    this.appLockService,
    this.exportService,
  });

  @override
  State<PrivacySecurityScreen> createState() => _PrivacySecurityScreenState();
}

class _PrivacySecurityScreenState extends State<PrivacySecurityScreen> {
  bool isExporting = false;
  bool isDeleting = false;
  late final AppLockService _appLockService =
      widget.appLockService ?? AppLockService();
  late final DataExportService _exportService =
      widget.exportService ?? DataExportService();

  @override
  void initState() {
    super.initState();
    _ensureLockCredential();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _ensureLockCredential() async {
    if (!widget.settings.biometricLockEnabled) {
      return;
    }
    final bool hasPin = await _appLockService.hasPin();
    if (!hasPin && mounted) {
      widget.settings.setBiometricLock(false);
    }
  }

  Future<void> _changePin() async {
    final bool hasPin = await _appLockService.hasPin();
    if (!mounted) {
      return;
    }
    if (hasPin) {
      final bool? verified = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) =>
            _VerifyPinDialog(service: _appLockService),
      );
      if (!mounted || verified != true) {
        return;
      }
    }

    final String? pin = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => const _ChangePinDialog(),
    );
    if (!mounted || pin == null) {
      return;
    }

    try {
      await _appLockService.savePin(pin);
      widget.settings.markPinUpdated();
      if (!mounted) {
        return;
      }
      _showMessage('PIN aplikasi berhasil diperbarui.');
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showMessage('PIN gagal disimpan. Coba lagi di perangkat ini.');
    }
  }

  Future<void> _toggleAppLock(bool value) async {
    if (!value) {
      widget.settings.setBiometricLock(false);
      return;
    }

    try {
      final bool hasPin = await _appLockService.hasPin();
      if (!mounted) {
        return;
      }
      if (!hasPin) {
        final String? pin = await showDialog<String>(
          context: context,
          builder: (BuildContext dialogContext) =>
              const _ChangePinDialog(title: 'Buat PIN aplikasi'),
        );
        if (!mounted || pin == null) {
          widget.settings.setBiometricLock(false);
          return;
        }
        await _appLockService.savePin(pin);
        widget.settings.markPinUpdated();
      }
      widget.settings.setBiometricLock(true);
      if (!mounted) {
        return;
      }
      _showMessage(
        'Kunci aplikasi aktif. PIN atau biometrik diminta saat aplikasi '
        'dibuka kembali.',
      );
    } catch (_) {
      widget.settings.setBiometricLock(false);
      if (!mounted) {
        return;
      }
      _showMessage('Kunci aplikasi tidak dapat diaktifkan di perangkat ini.');
    }
  }

  Future<void> _exportData() async {
    final AppProvider? app = widget.app;
    if (isExporting || app == null) {
      return;
    }
    setState(() => isExporting = true);
    try {
      final DataExportResult result = await _exportService.exportAndShare(
        tasks: app.tasks,
        transactions: app.transactions,
        profile: app.profile,
      );
      if (!mounted) {
        return;
      }
      _showMessage(
        result.shared
            ? 'Data berhasil disiapkan. Pilih aplikasi untuk menyimpan '
                  'atau membagikan file.'
            : 'File ekspor dibuat di ${result.folderPath}.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage('Gagal mengekspor data: $error');
    } finally {
      if (mounted) {
        setState(() => isExporting = false);
      }
    }
  }

  Future<void> _confirmDeleteAccount() async {
    if (isDeleting) {
      return;
    }
    final AppColors c = ThemeScope.of(context).colors;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Hapus akun AturAja?'),
        content: const Text(
          'Tindakan ini menghapus akun, data tugas, transaksi, profil, dan '
          'foto struk yang tersimpan. Tindakan ini tidak dapat dibatalkan.',
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

    final AppProvider? app = widget.app;
    final AuthProvider? auth = widget.auth;
    if (app == null || auth == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sesi akun tidak tersedia. Silakan masuk ulang.'),
        ),
      );
      return;
    }

    setState(() => isDeleting = true);
    try {
      await _deleteReceiptFiles(app.transactions);
      await app.deleteAllUserData();
      await app.clearLocalAccountData();
      await _appLockService.clearPin();
      await auth.deleteAccount();
      if (!mounted) {
        return;
      }
      _showMessage('Akun dan data berhasil dihapus.');
    } on AuthFailure catch (error) {
      if (!mounted) {
        return;
      }
      if (error.code == 'requires-recent-login') {
        _showMessage(
          'Data sudah dihapus, tetapi akun Firebase perlu login ulang. '
          'Silakan masuk kembali lalu ulangi hapus akun.',
        );
        await auth.signOut();
      } else {
        _showMessage(error.message);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage('Gagal menghapus akun: $error');
    } finally {
      if (mounted) {
        setState(() => isDeleting = false);
      }
    }
  }

  Future<void> _deleteReceiptFiles(List<TransactionItem> transactions) async {
    for (final TransactionItem transaction in transactions) {
      final String? path = transaction.receiptImagePath;
      if (path == null || path.trim().isEmpty) {
        continue;
      }
      try {
        final File file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {
        // File mungkin sudah dihapus atau berada di luar jangkauan aplikasi.
      }
    }
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
                      onChanged: isDeleting ? null : _toggleAppLock,
                      secondary: Icon(Icons.lock_outline, color: c.blue),
                      title: Text(
                        'Kunci aplikasi',
                        style: AppTypography.label(c.text),
                      ),
                      subtitle: Text(
                        'Minta PIN atau biometrik saat aplikasi dibuka kembali.',
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
                      onTap: isDeleting ? null : _changePin,
                      minTileHeight: AppSpacing.target,
                      leading: Icon(Icons.pin_outlined, color: c.blue),
                      title: Text(
                        'Ubah PIN',
                        style: AppTypography.label(c.text),
                      ),
                      subtitle: Text(
                        settings.pinWasUpdated
                            ? 'PIN telah diperbarui.'
                            : 'Atur PIN 4-6 digit untuk membuka aplikasi.',
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
                                : 'Bagikan salinan tugas, transaksi, dan profil '
                                      'dalam format JSON/CSV.',
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
                          onTap: isDeleting ? null : _confirmDeleteAccount,
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
                            isDeleting ? 'Menghapus akun dan data...' : 'Tindakan permanen dan tidak dapat dibatalkan.',
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
                              : Icon(Icons.chevron_right, color: c.expense),
                        ),
                      ],
                    ),
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

class _ChangePinDialog extends StatefulWidget {
  final String title;

  const _ChangePinDialog({this.title = 'Ubah PIN'});

  @override
  State<_ChangePinDialog> createState() => _ChangePinDialogState();
}

class _ChangePinDialogState extends State<_ChangePinDialog> {
  final TextEditingController pinController = TextEditingController();
  final TextEditingController confirmationController = TextEditingController();
  String? errorText;

  @override
  void dispose() {
    pinController.dispose();
    confirmationController.dispose();
    super.dispose();
  }

  void _save() {
    final String pin = pinController.text.trim();
    final String confirmation = confirmationController.text.trim();
    if (pin.length < 4 || pin.length > 6) {
      setState(() => errorText = 'PIN harus terdiri dari 4-6 digit.');
      return;
    }
    if (pin != confirmation) {
      setState(() => errorText = 'Konfirmasi PIN tidak cocok.');
      return;
    }
    Navigator.of(context).pop(pin);
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = ThemeScope.of(context).colors;
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
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
            decoration: const InputDecoration(
              labelText: 'PIN baru',
              counterText: '',
            ),
            style: AppTypography.body(c.text),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: confirmationController,
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
              labelText: 'Konfirmasi PIN',
              counterText: '',
              errorText: errorText,
            ),
            style: AppTypography.body(c.text),
          ),
        ],
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

class _VerifyPinDialog extends StatefulWidget {
  final AppLockService service;

  const _VerifyPinDialog({required this.service});

  @override
  State<_VerifyPinDialog> createState() => _VerifyPinDialogState();
}

class _VerifyPinDialogState extends State<_VerifyPinDialog> {
  final TextEditingController pinController = TextEditingController();
  bool isVerifying = false;
  String? errorText;

  @override
  void dispose() {
    pinController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (isVerifying) {
      return;
    }
    final String pin = pinController.text.trim();
    if (pin.isEmpty) {
      setState(() => errorText = 'Masukkan PIN saat ini.');
      return;
    }
    setState(() {
      isVerifying = true;
      errorText = null;
    });
    final bool valid = await widget.service.verifyPin(pin);
    if (!mounted) {
      return;
    }
    if (valid) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      isVerifying = false;
      errorText = 'PIN saat ini salah.';
      pinController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = ThemeScope.of(context).colors;
    return AlertDialog(
      title: const Text('Verifikasi PIN'),
      content: TextField(
        controller: pinController,
        autofocus: true,
        obscureText: true,
        keyboardType: TextInputType.number,
        maxLength: 6,
        enabled: !isVerifying,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onSubmitted: (_) => _verify(),
        decoration: InputDecoration(
          labelText: 'PIN saat ini',
          counterText: '',
          errorText: errorText,
        ),
        style: AppTypography.body(c.text),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Batal'),
        ),
        TextButton(
          onPressed: isVerifying ? null : _verify,
          child: const Text('Lanjut'),
        ),
      ],
    );
  }
}
