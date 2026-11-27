import 'dart:async';

import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/theme_scope.dart';
import '../utils/snackbar_helper.dart';
import '../widgets/common.dart';

class VerifyEmailScreen extends StatefulWidget {
  final String email;
  final Future<bool> Function() onCheckVerified;
  final Future<void> Function() onResendEmail;
  final Future<void> Function() onSignOut;
  final int resendCooldownSeconds;

  const VerifyEmailScreen({
    super.key,
    required this.email,
    required this.onCheckVerified,
    required this.onResendEmail,
    required this.onSignOut,
    this.resendCooldownSeconds = 60,
  });

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen>
    with WidgetsBindingObserver {
  bool checking = false;
  bool resending = false;
  bool signingOut = false;
  int cooldownRemaining = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cooldownTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      unawaited(_checkVerified(silent: true));
    }
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    if (widget.resendCooldownSeconds <= 0) {
      return;
    }
    setState(() => cooldownRemaining = widget.resendCooldownSeconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (cooldownRemaining <= 1) {
        timer.cancel();
        setState(() => cooldownRemaining = 0);
      } else {
        setState(() => cooldownRemaining -= 1);
      }
    });
  }

  Future<void> _checkVerified({bool silent = false}) async {
    if (checking || signingOut) {
      return;
    }
    setState(() => checking = true);
    try {
      final bool verified = await widget.onCheckVerified();
      if (!mounted) {
        return;
      }
      if (verified) {
        showSuccessSnackBar(context, 'Email berhasil diverifikasi. Selamat datang!');
      } else if (!silent) {
        showErrorSnackBar(
          context,
          'Email belum terverifikasi. Klik link di inbox atau folder spam kamu lalu coba lagi.',
        );
      }
    } on AuthFailure catch (error) {
      if (mounted && !silent) {
        showErrorSnackBar(context, error.message);
      }
    } catch (_) {
      if (mounted && !silent) {
        showErrorSnackBar(
          context,
          'Gagal memeriksa status verifikasi. Periksa koneksi lalu coba lagi.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => checking = false);
      }
    }
  }

  Future<void> _resendEmail() async {
    if (resending || checking || signingOut || cooldownRemaining > 0) {
      return;
    }
    setState(() => resending = true);
    try {
      await widget.onResendEmail();
      if (!mounted) {
        return;
      }
      _startCooldown();
      showSuccessSnackBar(
        context,
        'Link verifikasi baru telah dikirim ke email kamu.',
      );
    } on AuthFailure catch (error) {
      if (mounted) {
        showErrorSnackBar(context, error.message);
      }
    } catch (_) {
      if (mounted) {
        showErrorSnackBar(
          context,
          'Gagal mengirim ulang email verifikasi. Coba beberapa saat lagi.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => resending = false);
      }
    }
  }

  Future<void> _signOut() async {
    if (signingOut) {
      return;
    }
    setState(() => signingOut = true);
    try {
      await widget.onSignOut();
    } catch (_) {
      if (mounted) {
        showErrorSnackBar(context, 'Gagal keluar. Silakan coba lagi.');
      }
    } finally {
      if (mounted) {
        setState(() => signingOut = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = ThemeScope.of(context).colors;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: c.bg,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.xl,
                  AppSpacing.md,
                  AppSpacing.xxl,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight:
                        constraints.maxHeight - AppSpacing.xl - AppSpacing.xxl,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(c),
                      const SizedBox(height: AppSpacing.xl),
                      _buildCard(c),
                      const SizedBox(height: AppSpacing.lg),
                      _buildSignOutLink(c),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AppColors c) {
    return Column(
      children: [
        Container(
          width: AppSpacing.huge,
          height: AppSpacing.huge,
          decoration: BoxDecoration(
            color: c.blueDim,
            borderRadius: BorderRadius.circular(AppSpacing.xl),
            border: Border.all(color: c.border),
          ),
          child: Icon(
            Icons.mark_email_unread_outlined,
            size: AppSpacing.iconLarge,
            color: c.blue,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Verifikasi email kamu',
          textAlign: TextAlign.center,
          style: AppTypography.hero(c.text),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Kami telah mengirim link verifikasi untuk memastikan alamat email kamu aktif dan valid.',
          textAlign: TextAlign.center,
          style: AppTypography.body(c.textSub),
        ),
      ],
    );
  }

  Widget _buildCard(AppColors c) {
    final bool canResend =
        !resending && !checking && !signingOut && cooldownRemaining == 0;
    final String resendLabel = cooldownRemaining > 0
        ? 'Kirim ulang dalam $cooldownRemaining dtk'
        : 'Kirim ulang email verifikasi';

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Alamat email tujuan', style: AppTypography.caption(c.textMuted)),
          const SizedBox(height: AppSpacing.xs),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: c.surfaceHigh,
              borderRadius: BorderRadius.circular(AppSpacing.sm),
              border: Border.all(color: c.border),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.alternate_email_rounded,
                  size: AppSpacing.iconSmall,
                  color: c.blue,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    widget.email.isEmpty ? '-' : widget.email,
                    style: AppTypography.body(c.text)
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Buka inbox atau folder Spam, klik link verifikasi dari AturAja, lalu tekan tombol di bawah ini.',
            style: AppTypography.caption(c.textSub),
          ),
          const SizedBox(height: AppSpacing.lg),
          PressableScale(
            onTap: checking ? null : () => _checkVerified(),
            enabled: !checking,
            semanticLabel: 'Saya sudah verifikasi email',
            tooltip: 'Saya sudah verifikasi',
            child: Container(
              constraints: const BoxConstraints(minHeight: AppSpacing.target),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: checking ? c.surfaceHigh : c.blue,
                borderRadius: BorderRadius.circular(AppSpacing.sm),
                boxShadow: checking
                    ? null
                    : [
                        BoxShadow(
                          color: c.blue.withValues(alpha: 0.3),
                          blurRadius: AppSpacing.lg,
                          offset: const Offset(0, AppSpacing.xxs),
                        ),
                      ],
              ),
              child: checking
                  ? SizedBox(
                      width: AppSpacing.iconMedium,
                      height: AppSpacing.iconMedium,
                      child: CircularProgressIndicator(
                        strokeWidth: AppSpacing.progressThin,
                        color: c.onAccent,
                      ),
                    )
                  : Text(
                      'Saya sudah verifikasi',
                      style: AppTypography.button(c.onAccent),
                    ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          PressableScale(
            onTap: canResend ? _resendEmail : null,
            enabled: canResend,
            semanticLabel: resendLabel,
            tooltip: 'Kirim ulang verifikasi',
            child: Container(
              constraints: const BoxConstraints(minHeight: AppSpacing.target),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.surfaceHigh,
                borderRadius: BorderRadius.circular(AppSpacing.sm),
                border: Border.all(color: c.border, width: 1.5),
              ),
              child: resending
                  ? SizedBox(
                      width: AppSpacing.iconMedium,
                      height: AppSpacing.iconMedium,
                      child: CircularProgressIndicator(
                        strokeWidth: AppSpacing.progressThin,
                        color: c.blue,
                      ),
                    )
                  : Text(
                      resendLabel,
                      style: AppTypography.button(
                        canResend ? c.text : c.textMuted,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignOutLink(AppColors c) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Salah memasukkan email?', style: AppTypography.caption(c.textSub)),
        PressableScale(
          onTap: signingOut ? null : _signOut,
          enabled: !signingOut,
          semanticLabel: 'Keluar dan gunakan akun lain',
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.sm,
            ),
            child: Text(
              'Gunakan akun lain',
              style: AppTypography.caption(c.blue)
                  .copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}
