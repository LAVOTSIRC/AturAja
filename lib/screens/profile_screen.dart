import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/routes.dart';
import '../data/models.dart';
import '../providers/settings_provider.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/theme_scope.dart';
import '../utils/format.dart';
import '../utils/snackbar_helper.dart';
import '../widgets/common.dart';

enum _SettingsDestination { notifications, cloud, budget, nlp, privacy }

class _SettingItem {
  final IconData icon;
  final String label;
  final _SettingsDestination? destination;
  final bool destructive;

  const _SettingItem(
    this.icon,
    this.label,
    this.destination, {
    this.destructive = false,
  });
}

class _ProfileDraft {
  final String username;
  final String email;
  final String? currentPassword;
  final String? password;

  const _ProfileDraft({
    required this.username,
    required this.email,
    this.currentPassword,
    this.password,
  });
}

class ProfileScreen extends StatefulWidget {
  final SettingsController settings;
  final ProfileData? initialProfile;
  final ValueChanged<ProfileData>? onProfileChanged;
  final ValueChanged<String>? onPasswordChanged;
  final Future<void> Function({
    required String currentPassword,
    required String newPassword,
  })?
  onChangePassword;
  final bool canChangePassword;
  final Future<void> Function() onLogout;
  final String? cloudBackupStatus;

  const ProfileScreen({
    super.key,
    required this.settings,
    this.initialProfile,
    this.onProfileChanged,
    this.onPasswordChanged,
    this.onChangePassword,
    this.canChangePassword = true,
    required this.onLogout,
    this.cloudBackupStatus,
  });

  static const settingItems = [
    _SettingItem(
      Icons.notifications_none,
      'Notifikasi & Roasting AI',
      _SettingsDestination.notifications,
    ),
    _SettingItem(
      Icons.cloud_outlined,
      'Cadangan Cloud',
      _SettingsDestination.cloud,
    ),
    _SettingItem(
      Icons.credit_card_outlined,
      'Limit Anggaran',
      _SettingsDestination.budget,
    ),
    _SettingItem(
      Icons.psychology_outlined,
      'Simulasi NLP',
      _SettingsDestination.nlp,
    ),
    _SettingItem(
      Icons.lock_outline,
      'Privasi & Keamanan',
      _SettingsDestination.privacy,
    ),
  ];

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late String fullName;
  late String email;
  late String avatarLabel;

  @override
  void initState() {
    super.initState();
    _applyInitialProfile(widget.initialProfile);
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final ProfileData? previous = oldWidget.initialProfile;
    final ProfileData? current = widget.initialProfile;
    if (previous?.fullName != current?.fullName ||
        previous?.email != current?.email ||
        previous?.avatarLabel != current?.avatarLabel) {
      _applyInitialProfile(current);
    }
  }

  void _applyInitialProfile(ProfileData? initialProfile) {
    if (initialProfile == null) {
      fullName = ProfileData.initial.fullName;
      email = ProfileData.initial.email;
      avatarLabel = ProfileData.initial.avatarLabel;
      return;
    }
    email = initialProfile.email.trim();
    final String rawName = initialProfile.fullName.trim();
    if (rawName.isNotEmpty) {
      fullName = rawName;
    } else if (email.isNotEmpty) {
      final String derived = ProfileData.nameFromEmail(email);
      fullName = derived.isNotEmpty ? derived : 'Pengguna';
    } else {
      fullName = 'Pengguna';
    }
    final String rawAvatar = initialProfile.avatarLabel.trim();
    avatarLabel = rawAvatar.isNotEmpty
        ? rawAvatar
        : ProfileData.initialsFromName(fullName);
  }

  void _notifyProfileChanged() {
    widget.onProfileChanged?.call(
      ProfileData(fullName: fullName, email: email, avatarLabel: avatarLabel),
    );
  }

  String _initialsFromName(String value) => ProfileData.initialsFromName(value);

  Future<void> _openAvatarOptions() async {
    final String? choice = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => SimpleDialog(
        title: const Text('Ubah avatar'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(dialogContext).pop('gallery'),
            child: const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.photo_library_outlined),
              title: Text('Pilih dari galeri'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(dialogContext).pop('default'),
            child: const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.account_circle_outlined),
              title: Text('Gunakan avatar bawaan'),
            ),
          ),
        ],
      ),
    );

    if (!mounted || choice == null) {
      return;
    }
    if (choice == 'default') {
      setState(() => avatarLabel = _initialsFromName(fullName));
      _notifyProfileChanged();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Avatar bawaan digunakan.')));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pemilih galeri akan segera tersedia.')),
    );
  }

  Future<void> _openEditProfile() async {
    final AppColors c = ThemeScope.of(context).colors;
    final _ProfileDraft? draft = await showModalBottomSheet<_ProfileDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.transparent,
      builder: (_) => _EditProfileSheet(
        username: fullName,
        email: email,
        canChangePassword: widget.canChangePassword,
        requireCurrentPassword: widget.onChangePassword != null,
      ),
    );

    if (!mounted || draft == null) {
      return;
    }
    setState(() {
      fullName = draft.username;
      email = draft.email;
      avatarLabel = _initialsFromName(draft.username);
    });
    _notifyProfileChanged();
    final String? newPassword = draft.password;
    if (newPassword != null && newPassword.isNotEmpty) {
      final Future<void> Function({
        required String currentPassword,
        required String newPassword,
      })?
      changePassword = widget.onChangePassword;
      if (changePassword != null) {
        try {
          await changePassword(
            currentPassword: draft.currentPassword ?? '',
            newPassword: newPassword,
          );
          if (!mounted) {
            return;
          }
          showSuccessSnackBar(
            context,
            'Profil dan kata sandi berhasil diperbarui.',
          );
          return;
        } on AuthFailure catch (error) {
          if (mounted) {
            showErrorSnackBar(context, error.message);
          }
          return;
        } catch (_) {
          if (mounted) {
            showErrorSnackBar(
              context,
              'Profil diperbarui, tetapi gagal mengubah kata sandi. Coba lagi.',
            );
          }
          return;
        }
      }
      widget.onPasswordChanged?.call(newPassword);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profil berhasil diperbarui.')),
    );
  }

  Future<void> _openSetting(_SettingItem item) async {
    final _SettingsDestination? selected = item.destination;
    if (selected == null) {
      return;
    }
    final String path = switch (selected) {
      _SettingsDestination.notifications => AppRoutes.notificationSettings,
      _SettingsDestination.cloud => AppRoutes.cloudBackup,
      _SettingsDestination.budget => AppRoutes.budgetLimit,
      _SettingsDestination.nlp => AppRoutes.nlpSimulation,
      _SettingsDestination.privacy => AppRoutes.privacySecurity,
    };

    final bool? saved = await context.push<bool>(path);
    if (selected == _SettingsDestination.budget && saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Limit anggaran berhasil diperbarui.')),
      );
    }
  }

  Future<void> _confirmLogout() async {
    final AppColors c = ThemeScope.of(context).colors;
    final bool? shouldLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Keluar dari AturAja?'),
        content: const Text(
          'Yakin ingin keluar? Sesi akan diakhiri dan kamu perlu masuk kembali.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: c.expense),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (!mounted || shouldLogout != true) {
      return;
    }
    try {
      await widget.onLogout();
    } catch (_) {
      if (mounted) {
        showErrorSnackBar(context, 'Gagal keluar. Silakan coba lagi.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = ThemeScope.of(context).colors;
    return AnimatedBuilder(
      animation: widget.settings,
      builder: (BuildContext context, Widget? child) {
        return Container(
          color: c.bg,
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: AppSpacing.screenBottom),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(c),
                  _buildProfileSummary(c),
                  const SizedBox(height: AppSpacing.md),
                  _buildSettings(c),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(AppColors c) {
    return Padding(
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
    );
  }

  Widget _buildProfileSummary(AppColors c) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Center(
        child: Column(
          children: [
            _buildAvatar(c),
            const SizedBox(height: AppSpacing.sm),
            _buildName(c),
            if (email.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xxs),
              Text(email, style: AppTypography.meta(c.textMuted)),
            ],
            const SizedBox(height: AppSpacing.xs),
            _buildStatus(c),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(AppColors c) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: AppSpacing.avatar,
          height: AppSpacing.avatar,
          decoration: BoxDecoration(
            color: c.surface,
            border: Border.all(color: c.border),
            borderRadius: BorderRadius.circular(AppSpacing.xl),
          ),
          alignment: Alignment.center,
          child: Text(
            avatarLabel,
            style: AppTypography.display(c.blue).copyWith(letterSpacing: -0.5),
          ),
        ),
        Positioned(
          right: -4,
          bottom: -4,
          child: PressableScale(
            minWidth: 32,
            minHeight: 32,
            onTap: _openAvatarOptions,
            semanticLabel: 'Ubah avatar',
            tooltip: 'Ubah avatar',
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: c.blue,
                shape: BoxShape.circle,
                border: Border.all(color: c.bg, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: c.shadow,
                    blurRadius: AppSpacing.xs,
                    offset: const Offset(0, AppSpacing.xxs),
                  ),
                ],
              ),
              child: Icon(Icons.edit, size: 16, color: c.onAccent),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildName(AppColors c) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            fullName,
            textAlign: TextAlign.center,
            style: AppTypography.title(c.text),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        PressableScale(
          onTap: _openEditProfile,
          semanticLabel: 'Edit profil',
          tooltip: 'Edit profil',
          child: Icon(Icons.edit_outlined, color: c.blue),
        ),
      ],
    );
  }

  Widget _buildStatus(AppColors c) {
    return Container(
      constraints: const BoxConstraints(minHeight: AppSpacing.targetCompact),
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
            decoration: BoxDecoration(color: c.success, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            'Mode Luring Aktif',
            style: AppTypography.meta(c.success)
                .copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  String _settingStatus(_SettingItem item) {
    final SettingsController settings = widget.settings;
    return switch (item.destination) {
      _SettingsDestination.notifications => settings.notificationStatus,
      _SettingsDestination.cloud =>
        widget.cloudBackupStatus ?? settings.cloudBackupStatus,
      _SettingsDestination.budget =>
        settings.monthlyBudgetLimit == 0
            ? 'Nonaktif (opsional)'
            : '${formatRupiah(settings.monthlyBudgetLimit)}/bulan',
      _SettingsDestination.nlp => settings.nlpModelStatus,
      _SettingsDestination.privacy => settings.privacyStatus,
      null => '',
    };
  }

  Widget _buildSettings(AppColors c) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('Pengaturan'),
          ...ProfileScreen.settingItems.map((_SettingItem item) {
            final String subtitle = _settingStatus(item);
            return _buildSettingTile(
              c,
              item,
              subtitle: subtitle,
              onTap: () => _openSetting(item),
            );
          }),
          const SizedBox(height: AppSpacing.md),
          Divider(color: c.border, thickness: 1),
          const SizedBox(height: AppSpacing.xs),
          _buildSettingTile(
            c,
            const _SettingItem(Icons.logout, 'Keluar', null, destructive: true),
            subtitle: '',
            onTap: _confirmLogout,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile(
    AppColors c,
    _SettingItem item, {
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final Color accent = item.destructive ? c.expense : c.blue;
    final Color background = item.destructive
        ? c.expenseDim.withValues(alpha: 0.4)
        : c.cardBg;
    final String semanticLabel = subtitle.isEmpty
        ? item.label
        : '${item.label}. $subtitle';

    return Padding(
      padding: EdgeInsets.only(bottom: item.destructive ? 0 : AppSpacing.xxs),
      child: Tooltip(
        message: item.label,
        child: Semantics(
          button: true,
          label: semanticLabel,
          excludeSemantics: true,
          child: Material(
            color: background,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.md),
              side: BorderSide(
                color: item.destructive
                    ? c.expense.withValues(alpha: 0.5)
                    : c.border,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppSpacing.md),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Icon(item.icon, size: AppSpacing.iconSmall, color: accent),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.label,
                            style: AppTypography.label(
                              item.destructive ? c.expense : c.text,
                            ),
                          ),
                          if (subtitle.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              subtitle,
                              style: AppTypography.micro(c.textMuted),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: AppSpacing.md,
                      color: item.destructive ? c.expense : c.textMuted,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EditProfileSheet extends StatefulWidget {
  final String username;
  final String email;
  final bool canChangePassword;
  final bool requireCurrentPassword;

  const _EditProfileSheet({
    required this.username,
    required this.email,
    this.canChangePassword = true,
    this.requireCurrentPassword = false,
  });

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final TextEditingController usernameController;
  late final TextEditingController emailController;
  late final TextEditingController currentPasswordController;
  late final TextEditingController passwordController;
  String? usernameError;
  String? emailError;
  String? currentPasswordError;
  String? passwordError;
  bool obscureCurrentPassword = true;
  bool obscurePassword = true;

  @override
  void initState() {
    super.initState();
    usernameController = TextEditingController(text: widget.username);
    emailController = TextEditingController(text: widget.email);
    currentPasswordController = TextEditingController();
    passwordController = TextEditingController();
  }

  @override
  void dispose() {
    usernameController.dispose();
    emailController.dispose();
    currentPasswordController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void _save() {
    final String username = usernameController.text.trim();
    final String email = emailController.text.trim();
    final String currentPassword = currentPasswordController.text;
    final String password = widget.canChangePassword
        ? passwordController.text
        : '';

    final String? nextUsernameError = username.isEmpty
        ? 'Username tidak boleh kosong.'
        : null;
    final String? nextEmailError = email.isEmpty
        ? 'Email tidak boleh kosong.'
        : (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)
              ? 'Masukkan format email yang valid.'
              : null);
    final String? nextCurrentPasswordError =
        (widget.canChangePassword &&
            widget.requireCurrentPassword &&
            password.isNotEmpty &&
            currentPassword.isEmpty)
        ? 'Masukkan password saat ini untuk mengganti password.'
        : null;
    final String? nextPasswordError =
        (password.isNotEmpty && password.length < 6)
        ? 'Password minimal 6 karakter.'
        : null;

    if (nextUsernameError != null ||
        nextEmailError != null ||
        nextCurrentPasswordError != null ||
        nextPasswordError != null) {
      setState(() {
        usernameError = nextUsernameError;
        emailError = nextEmailError;
        currentPasswordError = nextCurrentPasswordError;
        passwordError = nextPasswordError;
      });
      return;
    }

    Navigator.of(context).pop(
      _ProfileDraft(
        username: username,
        email: email,
        currentPassword: currentPassword.isEmpty ? null : currentPassword,
        password: password.isEmpty ? null : password,
      ),
    );
  }

  void _clearUsernameError() {
    if (usernameError != null) {
      setState(() => usernameError = null);
    }
  }

  void _clearEmailError() {
    if (emailError != null) {
      setState(() => emailError = null);
    }
  }

  void _clearCurrentPasswordError() {
    if (currentPasswordError != null) {
      setState(() => currentPasswordError = null);
    }
  }

  void _clearPasswordError() {
    if (passwordError != null) {
      setState(() => passwordError = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = ThemeScope.of(context).colors;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Material(
        color: c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppSpacing.lg),
          ),
          side: BorderSide(color: c.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.xxl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: AppSpacing.sheetHandleWidth,
                  height: AppSpacing.sheetHandleHeight,
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: c.surfaceHigh,
                    borderRadius: BorderRadius.circular(AppSpacing.huge),
                  ),
                ),
              ),
              Text('Edit Profil', style: AppTypography.titleLarge(c.text)),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Atur username, email, dan password akunmu.',
                style: AppTypography.caption(c.textSub),
              ),
              const SizedBox(height: AppSpacing.md),
              _profileField(
                controller: usernameController,
                label: 'Username',
                hint: 'Contoh: M Zidan Ruriano A.G',
                errorText: usernameError,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                onChanged: (_) => _clearUsernameError(),
              ),
              const SizedBox(height: AppSpacing.sm),
              _profileField(
                controller: emailController,
                label: 'Email',
                hint: 'Contoh: zidan@aturaja.id',
                errorText: emailError,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                onChanged: (_) => _clearEmailError(),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (widget.canChangePassword) ...[
                if (widget.requireCurrentPassword) ...[
                  _profileField(
                    controller: currentPasswordController,
                    label: 'Password Saat Ini (Opsional)',
                    hint: 'Diisi jika ingin mengubah password',
                    errorText: currentPasswordError,
                    obscureText: obscureCurrentPassword,
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => _clearCurrentPasswordError(),
                    suffixIcon: IconButton(
                      onPressed: () => setState(
                        () => obscureCurrentPassword = !obscureCurrentPassword,
                      ),
                      icon: Icon(
                        obscureCurrentPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: AppSpacing.iconSmall,
                        color: c.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                _profileField(
                  controller: passwordController,
                  label: 'Password Baru (Opsional)',
                  hint: 'Kosongkan jika tidak ingin mengubah password',
                  errorText: passwordError,
                  obscureText: obscurePassword,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => _clearPasswordError(),
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => obscurePassword = !obscurePassword),
                    icon: Icon(
                      obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: AppSpacing.iconSmall,
                      color: c.textMuted,
                    ),
                  ),
                ),
              ] else
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: c.blueDim,
                    borderRadius: BorderRadius.circular(AppSpacing.sm),
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
                          'Akun ini masuk dengan Google. Kata sandi dikelola melalui akun Google kamu.',
                          style: AppTypography.caption(c.textSub),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(
                          AppSpacing.target,
                          AppSpacing.target,
                        ),
                        foregroundColor: c.textMuted,
                      ),
                      child: Text(
                        'Batal',
                        style: AppTypography.label(c.textMuted),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: PressableScale(
                      onTap: _save,
                      semanticLabel: 'Simpan perubahan profil',
                      tooltip: 'Simpan profil',
                      child: Container(
                        constraints: const BoxConstraints(
                          minHeight: AppSpacing.target,
                        ),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: c.blue,
                          borderRadius: BorderRadius.circular(AppSpacing.sm),
                        ),
                        child: Text(
                          'Simpan',
                          style: AppTypography.button(c.onAccent),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _profileField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required TextInputAction textInputAction,
    TextCapitalization textCapitalization = TextCapitalization.none,
    bool obscureText = false,
    Widget? suffixIcon,
    String? errorText,
    TextInputType? keyboardType,
    ValueChanged<String>? onChanged,
  }) {
    final AppColors c = ThemeScope.of(context).colors;
    return TextField(
      controller: controller,
      textCapitalization: textCapitalization,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: errorText,
        suffixIcon: suffixIcon,
        hintStyle: AppTypography.body(c.textMuted),
        filled: true,
        fillColor: c.surfaceHigh,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.sm),
          borderSide: BorderSide(color: c.border, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.sm),
          borderSide: BorderSide(color: c.focus, width: 1.5),
        ),
      ),
      style: AppTypography.body(c.text),
    );
  }
}
