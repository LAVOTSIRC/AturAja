import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/theme_scope.dart';
import 'common.dart';

enum _QuickAddMode { quick, brain }

class QuickAddModal extends StatefulWidget {
  final bool startInBrainDump;

  const QuickAddModal({super.key, this.startInBrainDump = false});

  @override
  State<QuickAddModal> createState() => _QuickAddModalState();
}

class _QuickAddModalState extends State<QuickAddModal> {
  late _QuickAddMode mode;
  final TextEditingController inputController = TextEditingController();
  final TextEditingController brainController = TextEditingController();
  bool isProcessing = false;
  String? errorMessage;

  static const suggestions = ['15k batagor', '29k kopi', '54990 spotify'];

  @override
  void initState() {
    super.initState();
    mode = widget.startInBrainDump ? _QuickAddMode.brain : _QuickAddMode.quick;
  }

  @override
  void dispose() {
    inputController.dispose();
    brainController.dispose();
    super.dispose();
  }

  void _setMode(_QuickAddMode nextMode) {
    if (isProcessing) {
      return;
    }
    setState(() {
      mode = nextMode;
      errorMessage = null;
    });
  }

  void _submitQuick() {
    if (inputController.text.trim().isEmpty) {
      setState(
        () => errorMessage = 'Isi nominal dan deskripsi terlebih dahulu.',
      );
      return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _processBrainDump() async {
    if (isProcessing) {
      return;
    }
    final String value = brainController.text.trim();
    if (value.isEmpty) {
      setState(() => errorMessage = 'Tuliskan isi brain dump terlebih dahulu.');
      return;
    }

    setState(() {
      isProcessing = true;
      errorMessage = null;
    });

    try {
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (value.length < 8) {
        throw StateError('detail belum lengkap');
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        isProcessing = false;
        errorMessage = 'Brain dump belum bisa diproses. Tambahkan detail yang lebih lengkap.';
      });
    }
  }

  void _clearError() {
    if (errorMessage != null) {
      setState(() => errorMessage = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = ThemeScope.of(context).colors;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppSpacing.lg),
          ),
          border: Border.all(color: c.border),
        ),
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
              Container(
                padding: const EdgeInsets.all(AppSpacing.xxs),
                decoration: BoxDecoration(
                  color: c.surfaceHigh,
                  borderRadius: BorderRadius.circular(AppSpacing.sm),
                ),
                child: Row(
                  children: [
                    _modeButton(
                      c,
                      _QuickAddMode.quick,
                      Icons.edit_note_outlined,
                      'Catat Cepat',
                    ),
                    const SizedBox(width: AppSpacing.xxs),
                    _modeButton(
                      c,
                      _QuickAddMode.brain,
                      Icons.psychology_outlined,
                      'Brain Dump',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (mode == _QuickAddMode.quick) _quickBody(c) else _brainBody(c),
              if (errorMessage != null) ...[
                const SizedBox(height: AppSpacing.sm),
                AppErrorMessage(message: errorMessage!),
              ],
              const SizedBox(height: AppSpacing.xs),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: isProcessing
                      ? null
                      : () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(
                      AppSpacing.targetCompact,
                      AppSpacing.target,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    foregroundColor: c.textMuted,
                  ),
                  child: Text('Batal', style: AppTypography.label(c.textMuted)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modeButton(
    AppColors c,
    _QuickAddMode modeValue,
    IconData icon,
    String label,
  ) {
    final bool active = mode == modeValue;
    return Expanded(
      child: PressableScale(
        onTap: () => _setMode(modeValue),
        enabled: !isProcessing,
        selected: active,
        semanticLabel: 'Pilih mode $label',
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          constraints: const BoxConstraints(minHeight: AppSpacing.target),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: active ? c.blue : c.transparent,
            borderRadius: BorderRadius.circular(AppSpacing.sm),
            border: Border.all(
              color: active ? c.onAccent : c.transparent,
              width: 1.5,
            ),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: AppSpacing.iconSmall - 4,
                color: active ? c.onAccent : c.textSub,
              ),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption(active ? c.onAccent : c.textSub)
                      .copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quickBody(AppColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            style: AppTypography.caption(c.textSub),
            children: [
              const TextSpan(text: 'Contoh: '),
              TextSpan(
                text: '"15k batagor"',
                style: AppTypography.caption(c.blue),
              ),
              const TextSpan(text: ' atau '),
              TextSpan(
                text: '"29000 kopi"',
                style: AppTypography.caption(c.blue),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: inputController,
                autofocus: true,
                onChanged: (_) => _clearError(),
                onSubmitted: (_) => _submitQuick(),
                decoration: InputDecoration(
                  labelText: 'Nominal dan deskripsi transaksi',
                  hintText: 'nominal + deskripsi...',
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
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            PressableScale(
              onTap: _submitQuick,
              semanticLabel: 'Simpan pengeluaran',
              tooltip: 'Simpan pengeluaran',
              child: Container(
                constraints: const BoxConstraints(minHeight: AppSpacing.target),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.blue,
                  borderRadius: BorderRadius.circular(AppSpacing.sm),
                ),
                child: Text('Catat', style: AppTypography.button(c.onAccent)),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: suggestions.map((String suggestion) {
            return PressableScale(
              onTap: () => setState(() {
                inputController.text = suggestion;
                errorMessage = null;
              }),
              semanticLabel: 'Gunakan contoh $suggestion',
              tooltip: 'Gunakan contoh',
              child: Container(
                constraints: const BoxConstraints(
                  minHeight: AppSpacing.targetCompact,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: c.surfaceHigh,
                  border: Border.all(color: c.border),
                  borderRadius: BorderRadius.circular(AppSpacing.huge),
                ),
                child: Text(suggestion, style: AppTypography.meta(c.textSub)),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _brainBody(AppColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ceritakan apa saja — simulasi AI akan memilah ke tugas, jadwal, atau pengeluaran.',
          style: AppTypography.caption(c.textSub),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: brainController,
          autofocus: true,
          maxLines: 4,
          onChanged: (_) => _clearError(),
          decoration: InputDecoration(
            labelText: 'Isi brain dump',
            hintText: 'Contoh: Besok ada quiz kalkulus jam 8, perlu bayar kos 500rb...',
            hintStyle: AppTypography.label(c.textMuted),
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
          style: AppTypography.label(c.text).copyWith(height: 1.6),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Icon(
              Icons.auto_awesome,
              size: AppSpacing.iconSmall - 8,
              color: c.ai,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                'Simulasi lokal mendeteksi jadwal, tugas & pengeluaran',
                style: AppTypography.meta(c.ai),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (isProcessing) ...[
          AppProcessingState(message: 'Memproses brain dump...', color: c.ai),
        ] else
          SizedBox(
            width: double.infinity,
            child: PressableScale(
              onTap: _processBrainDump,
              semanticLabel: 'Proses brain dump dengan AI simulasi',
              tooltip: 'Proses brain dump',
              child: Container(
                constraints: const BoxConstraints(minHeight: AppSpacing.target),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.ai,
                  borderRadius: BorderRadius.circular(AppSpacing.sm),
                ),
                child: Text(
                  'Proses dengan AI',
                  style: AppTypography.button(c.onAccent),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
