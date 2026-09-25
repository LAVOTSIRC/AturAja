import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/theme_scope.dart';
import '../widgets/common.dart';

class _SettingItem {
  final IconData icon;
  final String label;
  final String sub;
  final bool destructive;

  const _SettingItem(
    this.icon,
    this.label,
    this.sub, {
    this.destructive = false,
  });
}

class _ProfileDraft {
  final String fullName;
  final String nim;
  final String program;

  const _ProfileDraft({
    required this.fullName,
    required this.nim,
    required this.program,
  });
}

class _StatItem {
  final IconData icon;
  final String value;
  final String label;

  const _StatItem(this.icon, this.value, this.label);
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  static const stats = [
    _StatItem(Icons.task_alt_outlined, '12', 'Tugas Selesai'),
    _StatItem(Icons.savings_outlined, '874rb', 'Total Hemat'),
    _StatItem(Icons.local_fire_department_outlined, '7 hari', 'Streak'),
  ];

  static const settings = [
    _SettingItem(Icons.notifications_none, 'Notifikasi & Roasting AI', 'Aktif'),
    _SettingItem(Icons.cloud_outlined, 'Cadangan Cloud', 'Sinkron 10 mnt lalu'),
    _SettingItem(
      Icons.credit_card_outlined,
      'Limit Anggaran',
      'Rp1.200.000/bulan',
    ),
    _SettingItem(Icons.psychology_outlined, 'Simulasi NLP', 'Model lokal v2.1'),
    _SettingItem(Icons.lock_outline, 'Privasi & Keamanan', ''),
  ];

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String fullName = 'M Zidan Ruriano A.G';
  String nim = '241401063';
  String program = 'Ilmu Komputer';
  String avatarLabel = 'ZR';
  bool loggedOut = false;

  String _initialsFromName(String value) {
    final List<String> parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((String part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return '?';
    }
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return '${parts.first.substring(0, 1)}${parts[1].substring(0, 1)}'
        .toUpperCase();
  }

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
      builder: (_) =>
          _EditProfileSheet(fullName: fullName, nim: nim, program: program),
    );

    if (!mounted || draft == null) {
      return;
    }
    setState(() {
      fullName = draft.fullName;
      nim = draft.nim;
      program = draft.program;
      avatarLabel = _initialsFromName(draft.fullName);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profil berhasil diperbarui.')),
    );
  }

  String _settingDescription(_SettingItem item) {
    switch (item.label) {
      case 'Notifikasi & Roasting AI':
        return 'Preferensi notifikasi dan roasting AI dapat diatur pada halaman ini.';
      case 'Cadangan Cloud':
        return 'Pilihan sinkronisasi dan cadangan data lokal akan tersedia di sini.';
      case 'Limit Anggaran':
        return 'Batas pengeluaran bulanan dapat disesuaikan dari halaman Keuangan.';
      case 'Simulasi NLP':
        return 'Pengaturan simulasi pemrosesan bahasa lokal akan tersedia di sini.';
      case 'Privasi & Keamanan':
        return 'Kelola izin, data lokal, dan keamanan akun dari halaman ini.';
      default:
        return 'Fitur ini sedang disiapkan.';
    }
  }

  Future<void> _openSetting(_SettingItem item) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(item.label),
        content: Text(_settingDescription(item)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final AppColors c = ThemeScope.of(context).colors;
    final bool? shouldLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Keluar dari AturAja?'),
        content: const Text('Yakin ingin keluar? Sesi lokal akan diakhiri.'),
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
    setState(() => loggedOut = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Anda telah keluar dari akun.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = ThemeScope.of(context).colors;
    if (loggedOut) {
      return _buildLoggedOut(c);
    }

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
              _buildStats(c),
              const SizedBox(height: AppSpacing.md),
              _buildSettings(c),
            ],
          ),
        ),
      ),
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
            const SizedBox(height: AppSpacing.xxs),
            Text(
              nim.isEmpty || program.isEmpty ? nim : '$nim · $program',
              style: AppTypography.meta(c.textMuted),
            ),
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

  Widget _buildStats(AppColors c) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: ProfileScreen.stats
            .map(
              (_StatItem stat) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xxs,
                  ),
                  child: AppCard(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                      horizontal: AppSpacing.xs,
                    ),
                    child: Column(
                      children: [
                        Icon(
                          stat.icon,
                          size: AppSpacing.iconSmall,
                          color: c.blue,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          stat.value,
                          style: AppTypography.bodyLarge(c.text)
                              .copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          stat.label,
                          textAlign: TextAlign.center,
                          style: AppTypography.micro(c.textMuted)
                              .copyWith(height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildSettings(AppColors c) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('Pengaturan'),
          ...ProfileScreen.settings.map(
            (_SettingItem item) =>
                _buildSettingTile(c, item, onTap: () => _openSetting(item)),
          ),
          const SizedBox(height: AppSpacing.md),
          Divider(color: c.border, thickness: 1),
          const SizedBox(height: AppSpacing.xs),
          _buildSettingTile(
            c,
            const _SettingItem(Icons.logout, 'Keluar', '', destructive: true),
            onTap: _confirmLogout,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile(
    AppColors c,
    _SettingItem item, {
    required VoidCallback onTap,
  }) {
    final Color accent = item.destructive ? c.expense : c.blue;
    final Color background = item.destructive
        ? c.expenseDim.withValues(alpha: 0.4)
        : c.cardBg;
    final String semanticLabel = item.sub.isEmpty
        ? item.label
        : '${item.label}. ${item.sub}';

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
                          if (item.sub.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              item.sub,
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

  Widget _buildLoggedOut(AppColors c) {
    return Container(
      color: c.bg,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: AppSpacing.iconLarge,
                  color: c.blue,
                ),
                const SizedBox(height: AppSpacing.md),
                Text('Sesi berakhir', style: AppTypography.titleLarge(c.text)),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Silakan masuk kembali untuk melanjutkan.',
                  textAlign: TextAlign.center,
                  style: AppTypography.body(c.textSub),
                ),
                const SizedBox(height: AppSpacing.lg),
                PressableScale(
                  onTap: () => setState(() => loggedOut = false),
                  semanticLabel: 'Masuk lagi',
                  tooltip: 'Masuk lagi',
                  child: Container(
                    constraints: const BoxConstraints(
                      minHeight: AppSpacing.target,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.sm,
                    ),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: c.blue,
                      borderRadius: BorderRadius.circular(AppSpacing.sm),
                    ),
                    child: Text(
                      'Masuk lagi',
                      style: AppTypography.button(c.onAccent),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EditProfileSheet extends StatefulWidget {
  final String fullName;
  final String nim;
  final String program;

  const _EditProfileSheet({
    required this.fullName,
    required this.nim,
    required this.program,
  });

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final TextEditingController nameController;
  late final TextEditingController nimController;
  late final TextEditingController programController;
  String? nameError;
  String? nimError;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.fullName);
    nimController = TextEditingController(text: widget.nim);
    programController = TextEditingController(text: widget.program);
  }

  @override
  void dispose() {
    nameController.dispose();
    nimController.dispose();
    programController.dispose();
    super.dispose();
  }

  void _save() {
    final String name = nameController.text.trim();
    final String nim = nimController.text.trim();
    final String program = programController.text.trim();
    final String? nextNameError = name.isEmpty
        ? 'Nama tidak boleh kosong.'
        : null;
    final String? nextNimError = RegExp(r'^\d+$').hasMatch(nim)
        ? null
        : 'NIM harus berupa angka.';

    if (nextNameError != null || nextNimError != null) {
      setState(() {
        nameError = nextNameError;
        nimError = nextNimError;
      });
      return;
    }

    Navigator.of(context)
        .pop(_ProfileDraft(fullName: name, nim: nim, program: program));
  }

  void _clearNameError() {
    if (nameError != null) {
      setState(() => nameError = null);
    }
  }

  void _clearNimError() {
    if (nimError != null) {
      setState(() => nimError = null);
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
                'Perbarui informasi yang ditampilkan di profil.',
                style: AppTypography.caption(c.textSub),
              ),
              const SizedBox(height: AppSpacing.md),
              _profileField(
                controller: nameController,
                label: 'Nama Lengkap',
                hint: 'Contoh: M Zidan Ruriano A.G',
                errorText: nameError,
                textInputAction: TextInputAction.next,
                onChanged: (_) => _clearNameError(),
              ),
              const SizedBox(height: AppSpacing.sm),
              _profileField(
                controller: nimController,
                label: 'NIM',
                hint: 'Masukkan NIM',
                errorText: nimError,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                onChanged: (_) => _clearNimError(),
              ),
              const SizedBox(height: AppSpacing.sm),
              _profileField(
                controller: programController,
                label: 'Program Studi',
                hint: 'Contoh: Ilmu Komputer',
                textInputAction: TextInputAction.done,
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
    String? errorText,
    TextInputType? keyboardType,
    ValueChanged<String>? onChanged,
  }) {
    final AppColors c = ThemeScope.of(context).colors;
    return TextField(
      controller: controller,
      textCapitalization: TextCapitalization.words,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: errorText,
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
