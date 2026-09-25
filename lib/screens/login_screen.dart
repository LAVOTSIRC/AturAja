import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/theme_scope.dart';
import '../widgets/common.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onLogin;

  const LoginScreen({super.key, required this.onLogin});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  String? emailError;
  String? passwordError;
  bool obscurePassword = true;
  bool submitting = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
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

  bool _validate() {
    final String email = emailController.text.trim();
    final String password = passwordController.text;
    final String? nextEmailError = email.isEmpty
        ? 'Email tidak boleh kosong.'
        : (RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)
              ? null
              : 'Masukkan format email yang valid.');
    final String? nextPasswordError = password.isEmpty
        ? 'Kata sandi tidak boleh kosong.'
        : (password.length < 6 ? 'Kata sandi minimal 6 karakter.' : null);
    setState(() {
      emailError = nextEmailError;
      passwordError = nextPasswordError;
    });
    return nextEmailError == null && nextPasswordError == null;
  }

  Future<void> _submit() async {
    if (submitting || !_validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => submitting = true);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) {
      return;
    }
    widget.onLogin();
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
                      const Align(
                        alignment: Alignment.centerRight,
                        child: ThemeToggleSwitch(),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      _buildBrand(c),
                      const SizedBox(height: AppSpacing.xl),
                      _buildForm(c),
                      const SizedBox(height: AppSpacing.lg),
                      _buildDemoHint(c),
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
            Icons.checklist_rtl_rounded,
            size: AppSpacing.iconLarge,
            color: c.blue,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Masuk ke AturAja',
          textAlign: TextAlign.center,
          style: AppTypography.hero(c.text),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Kelola tugas, keuangan, dan rutinitas harianmu dalam satu tempat.',
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
          Text('Masuk', style: AppTypography.titleLarge(c.text)),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Gunakan akun yang terdaftar untuk melanjutkan.',
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
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onChanged: (_) => _clearPasswordError(),
            onSubmitted: (_) => _submit(),
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
              suffixIcon: _buildPasswordToggle(c),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          PressableScale(
            onTap: submitting ? null : _submit,
            enabled: !submitting,
            semanticLabel: 'Masuk ke AturAja',
            tooltip: 'Masuk',
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
                  : Text('Masuk', style: AppTypography.button(c.onAccent)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordToggle(AppColors c) {
    final String label = obscurePassword
        ? 'Tampilkan kata sandi'
        : 'Sembunyikan kata sandi';
    return PressableScale(
      onTap: () => setState(() => obscurePassword = !obscurePassword),
      semanticLabel: label,
      tooltip: label,
      minWidth: AppSpacing.iconBox,
      minHeight: AppSpacing.iconBox,
      child: Padding(
        padding: const EdgeInsets.only(right: AppSpacing.xs),
        child: Icon(
          obscurePassword
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined,
          size: AppSpacing.iconSmall,
          color: c.textMuted,
        ),
      ),
    );
  }

  Widget _buildDemoHint(AppColors c) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: c.blueDim,
        borderRadius: BorderRadius.circular(AppSpacing.md),
        border: Border.all(color: c.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: AppSpacing.iconSmall,
            color: c.blue,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              'Mode demo: gunakan email valid dan kata sandi minimal 6 karakter untuk masuk.',
              style: AppTypography.caption(c.textSub),
            ),
          ),
        ],
      ),
    );
  }
}
