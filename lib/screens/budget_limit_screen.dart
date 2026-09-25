import 'package:flutter/material.dart';

import '../data/settings_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/theme_scope.dart';
import '../widgets/common.dart';

class BudgetLimitScreen extends StatefulWidget {
  final SettingsController settings;

  const BudgetLimitScreen({super.key, required this.settings});

  @override
  State<BudgetLimitScreen> createState() => _BudgetLimitScreenState();
}

class _BudgetLimitScreenState extends State<BudgetLimitScreen> {
  late final TextEditingController limitController;
  String? errorText;

  @override
  void initState() {
    super.initState();
    limitController = TextEditingController(
      text: widget.settings.monthlyBudgetLimit.toString(),
    );
  }

  @override
  void dispose() {
    limitController.dispose();
    super.dispose();
  }

  void _save() {
    final String rawValue = limitController.text.trim();
    if (rawValue.isEmpty) {
      setState(() => errorText = 'Limit anggaran tidak boleh kosong.');
      return;
    }

    final int? value = int.tryParse(rawValue);
    if (value == null) {
      setState(() => errorText = 'Masukkan limit berupa angka yang valid.');
      return;
    }
    if (value <= 0) {
      setState(() => errorText = 'Limit anggaran harus lebih besar dari nol.');
      return;
    }

    widget.settings.setMonthlyBudgetLimit(value);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = ThemeScope.of(context).colors;
    return SettingsDetailScaffold(
      title: 'Limit Anggaran',
      child: SingleChildScrollView(
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
              'Nilai ini penting dan hanya berubah setelah kamu menekan Simpan.',
              style: AppTypography.body(c.textSub),
            ),
            const SizedBox(height: AppSpacing.lg),
            const SectionLabel('Limit Bulanan'),
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: TextField(
                controller: limitController,
                keyboardType: TextInputType.number,
                autofocus: true,
                onChanged: (_) {
                  if (errorText != null) {
                    setState(() => errorText = null);
                  }
                },
                style: AppTypography.display(c.text),
                decoration: InputDecoration(
                  labelText: 'Batas pengeluaran per bulan',
                  hintText: 'Contoh: 1200000',
                  prefixText: 'Rp ',
                  errorText: errorText,
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
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
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
                    semanticLabel: 'Simpan limit anggaran',
                    tooltip: 'Simpan limit',
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
    );
  }
}
