import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/theme_scope.dart';
import '../utils/snackbar_helper.dart';
import '../utils/validators.dart';
import '../widgets/common.dart';

typedef RegisterCallback = Future<void> Function({
  required String email,
  required String password,
});

class RegisterScreen extends StatefulWidget {
  final RegisterCallback onRegister;
  final VoidCallback onLogin;

  const RegisterScreen({
    super.key,
    required this.onRegister,
    required this.onLogin,
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmationController = TextEditingController();

  String? emailError;
  String? passwordError;
  String? confirmationError;
  bool obscurePassword = true;
  bool obscureConfirmation = true;
  bool submitting = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    confirmationController.dispose();
    super.dispose();
  }

  void _clearEmailError() {
    if (emailError != null) {
      setState(() => emailError = null);
    }
  }

  void _clearPasswordError() {
    if (passwordError != null) {
      setState(() => passwordError = null);
    }
  }

  void _clearConfirmationError() {
    if (confirmationError != null) {
      setState(() => confirmationError = null);
    }
  }

  bool _validate() {
    final String? nextEmailError = validateEmail(emailController.text);
    final String? nextPasswordError = validatePassword(passwordController.text);
    final String? nextConfirmationError = validatePasswordConfirmation(
      confirmationController.text,
      passwordController.text,
    );
    setState(() {
      emailError = nextEmailError;
      passwordError = nextPasswordError;
      confirmationError = nextConfirmationError;
    });
    return nextEmailError == null &&
        nextPasswordError == null &&
        nextConfirmationError == null;
  }

  Future<void> _submit() async {
    if (submitting || !_validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => submitting = true);
    try {
      await widget.onRegister(
        email: emailController.text.trim(),
        password: passwordController.text,
      );
      if (!mounted) {
        return;
      }
      showSuccessSnackBar(context, 'Akun berhasil dibuat. Selamat datang!');
    } on AuthFailure catch (error) {
      if (mounted) {
        showErrorSnackBar(context, error.message);
      }
    } catch (_) {
      if (mounted) {
        showErrorSnackBar(
          context,
          'Gagal membuat akun. Periksa koneksi lalu coba lagi.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = ThemeScope.of(context).colors;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.xxl,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight:
                      constraints.maxHeight - AppSpacing.md - AppSpacing.xxl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        PressableScale(
                          onTap: widget.onLogin,
                          semanticLabel: 'Kembali ke halaman masuk',
                          tooltip: 'Kembali',
                          child: Icon(
                            Icons.arrow_back_rounded,
                            color: c.text,
                            size: AppSpacing.iconMedium,
                          ),
                        ),
                        const ThemeToggleSwitch(),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _buildBrand(c),
                    const SizedBox(height: AppSpacing.xl),
                    _buildForm(c),
                    const SizedBox(height: AppSpacing.lg),
                    _buildLoginLink(c),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBrand(AppColors c) {
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
            Icons.person_add_alt_1_rounded,
            size: AppSpacing.iconLarge,
            color: c.blue,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Buat akun AturAja',
          textAlign: TextAlign.center,
          style: AppTypography.hero(c.text),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Satu akun untuk mengatur tugas dan keuanganmu.',
          textAlign: TextAlign.center,
          style: AppTypography.body(c.textSub),
        ),
      ],
    );
  }

  Widget _buildForm(AppColors c) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Daftar', style: AppTypography.titleLarge(c.text)),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Gunakan email aktif dan kata sandi yang aman.',
            style: AppTypography.caption(c.textMuted),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            onChanged: (_) => _clearEmailError(),
            style: AppTypography.body(c.text),
            decoration: InputDecoration(
              labelText: 'Email',
              hintText: 'nama@kampus.id',
              prefixIcon: Icon(
                Icons.alternate_email_rounded,
                size: AppSpacing.iconSmall,
                color: c.textMuted,
              ),
              errorText: emailError,
              errorMaxLines: 2,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: passwordController,
            obscureText: obscurePassword,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newPassword],
            onChanged: (_) => _clearPasswordError(),
            style: AppTypography.body(c.text),
            decoration: InputDecoration(
              labelText: 'Kata sandi',
              hintText: 'Minimal 6 karakter',
              prefixIcon: Icon(
                Icons.lock_outline_rounded,
                size: AppSpacing.iconSmall,
                color: c.textMuted,
              ),
              errorText: passwordError,
              errorMaxLines: 2,
              suffixIcon: _buildPasswordToggle(
                c,
                obscure: obscurePassword,
                onTap: () => setState(() => obscurePassword = !obscurePassword),
                label: obscurePassword
                    ? 'Tampilkan kata sandi'
                    : 'Sembunyikan kata sandi',
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: confirmationController,
            obscureText: obscureConfirmation,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.newPassword],
            onChanged: (_) => _clearConfirmationError(),
            onSubmitted: (_) => _submit(),
            style: AppTypography.body(c.text),
            decoration: InputDecoration(
              labelText: 'Konfirmasi kata sandi',
              hintText: 'Ulangi kata sandi',
              prefixIcon: Icon(
                Icons.lock_reset_rounded,
                size: AppSpacing.iconSmall,
                color: c.textMuted,
              ),
              errorText: confirmationError,
              errorMaxLines: 2,
              suffixIcon: _buildPasswordToggle(
                c,
                obscure: obscureConfirmation,
                onTap: () =>
                    setState(() => obscureConfirmation = !obscureConfirmation),
                label: obscureConfirmation
                    ? 'Tampilkan konfirmasi kata sandi'
                    : 'Sembunyikan konfirmasi kata sandi',
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          PressableScale(
            onTap: submitting ? null : _submit,
            enabled: !submitting,
            semanticLabel: 'Daftar akun AturAja',
            tooltip: 'Daftar',
            child: Container(
              constraints: const BoxConstraints(minHeight: AppSpacing.target),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: submitting ? c.surfaceHigh : c.blue,
                borderRadius: BorderRadius.circular(AppSpacing.sm),
                boxShadow: submitting
                    ? null
                    : [
                        BoxShadow(
                          color: c.blue.withValues(alpha: 0.3),
                          blurRadius: AppSpacing.lg,
                          offset: const Offset(0, AppSpacing.xxs),
                        ),
                      ],
              ),
              child: submitting
                  ? SizedBox(
                      width: AppSpacing.iconMedium,
                      height: AppSpacing.iconMedium,
                      child: CircularProgressIndicator(
                        strokeWidth: AppSpacing.progressThin,
                        color: c.onAccent,
                      ),
                    )
                  : Text('Daftar', style: AppTypography.button(c.onAccent)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordToggle(
    AppColors c, {
    required bool obscure,
    required VoidCallback onTap,
    required String label,
  }) {
    return PressableScale(
      onTap: onTap,
      semanticLabel: label,
      tooltip: label,
      minWidth: AppSpacing.iconBox,
      minHeight: AppSpacing.iconBox,
      child: Padding(
        padding: const EdgeInsets.only(right: AppSpacing.xs),
        child: Icon(
          obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          size: AppSpacing.iconSmall,
          color: c.textMuted,
        ),
      ),
    );
  }

  Widget _buildLoginLink(AppColors c) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Sudah punya akun?', style: AppTypography.caption(c.textSub)),
        PressableScale(
          onTap: widget.onLogin,
          semanticLabel: 'Masuk ke akun yang sudah ada',
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.sm,
            ),
            child: Text(
              'Masuk',
              style: AppTypography.caption(c.blue)
                  .copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}
