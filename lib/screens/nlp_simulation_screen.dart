import 'package:flutter/material.dart';

import '../data/settings_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/theme_scope.dart';
import '../widgets/common.dart';

enum _NlpCategory { task, schedule, expense, unknown }

extension on _NlpCategory {
  String get label => switch (this) {
    _NlpCategory.task => 'Tugas',
    _NlpCategory.schedule => 'Jadwal',
    _NlpCategory.expense => 'Pengeluaran',
    _NlpCategory.unknown => 'Belum terdeteksi',
  };

  IconData get icon => switch (this) {
    _NlpCategory.task => Icons.task_alt_outlined,
    _NlpCategory.schedule => Icons.event_outlined,
    _NlpCategory.expense => Icons.payments_outlined,
    _NlpCategory.unknown => Icons.help_outline,
  };

  String get explanation => switch (this) {
    _NlpCategory.task => 'Kalimat memuat kata kerja atau indikator tugas.',
    _NlpCategory.schedule => 'Kalimat memuat penanda waktu atau jadwal.',
    _NlpCategory.expense => 'Kalimat memuat kata kunci transaksi keuangan.',
    _NlpCategory.unknown => 'Tambahkan kata seperti tugas, besok, atau bayar.',
  };
}

class NlpSimulationScreen extends StatefulWidget {
  final SettingsController settings;

  const NlpSimulationScreen({super.key, required this.settings});

  @override
  State<NlpSimulationScreen> createState() => _NlpSimulationScreenState();
}

class _NlpSimulationScreenState extends State<NlpSimulationScreen> {
  final TextEditingController inputController = TextEditingController();
  String? errorText;
  _NlpCategory? result;

  @override
  void dispose() {
    inputController.dispose();
    super.dispose();
  }

  bool _containsAny(String value, List<String> keywords) {
    return keywords.any(value.contains);
  }

  _NlpCategory _parse(String value) {
    final String text = value.toLowerCase();
    if (_containsAny(text, const [
      'tugas',
      'submit',
      'kerjakan',
      'todo',
      'revisi',
    ])) {
      return _NlpCategory.task;
    }
    if (_containsAny(text, const [
      'beli',
      'bayar',
      'jajan',
      'makan',
      'belanja',
      'uang',
      'rupiah',
    ])) {
      return _NlpCategory.expense;
    }
    if (_containsAny(text, const [
      'besok',
      'lusa',
      'jadwal',
      'meeting',
      'rapat',
      'jam',
      'hari',
    ])) {
      return _NlpCategory.schedule;
    }
    return _NlpCategory.unknown;
  }

  void _analyze() {
    final String value = inputController.text.trim();
    if (value.isEmpty) {
      setState(() {
        errorText = 'Tuliskan satu kalimat brain-dump terlebih dahulu.';
        result = null;
      });
      return;
    }
    setState(() {
      errorText = null;
      result = _parse(value);
    });
  }

  Color _resultColor(AppColors c) {
    return switch (result) {
      _NlpCategory.task => c.blue,
      _NlpCategory.schedule => c.success,
      _NlpCategory.expense => c.warning,
      _NlpCategory.unknown => c.textMuted,
      null => c.textMuted,
    };
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = ThemeScope.of(context).colors;
    return SettingsDetailScaffold(
      title: 'Simulasi NLP',
      child: AnimatedBuilder(
        animation: widget.settings,
        builder: (BuildContext context, Widget? child) {
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
                const SectionLabel('Model Aktif'),
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      Container(
                        width: AppSpacing.iconBox,
                        height: AppSpacing.iconBox,
                        decoration: BoxDecoration(
                          color: c.aiDim,
                          borderRadius: BorderRadius.circular(AppSpacing.sm),
                        ),
                        child: Icon(Icons.psychology_outlined, color: c.ai),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.settings.nlpModelStatus,
                              style: AppTypography.label(c.text),
                            ),
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              'Berjalan lokal di perangkat.',
                              style: AppTypography.meta(c.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                const SectionLabel('Coba Brain Dump'),
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: inputController,
                        minLines: 3,
                        maxLines: 5,
                        textCapitalization: TextCapitalization.sentences,
                        onChanged: (_) {
                          if (errorText != null) {
                            setState(() => errorText = null);
                          }
                        },
                        decoration: InputDecoration(
                          labelText: 'Contoh: Bayar makan besok',
                          errorText: errorText,
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      SizedBox(
                        width: double.infinity,
                        child: PressableScale(
                          onTap: _analyze,
                          semanticLabel: 'Deteksi kategori brain dump',
                          tooltip: 'Deteksi kategori',
                          child: Container(
                            constraints: const BoxConstraints(
                              minHeight: AppSpacing.target,
                            ),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: c.ai,
                              borderRadius: BorderRadius.circular(
                                AppSpacing.sm,
                              ),
                            ),
                            child: Text(
                              'Deteksi Kategori',
                              style: AppTypography.button(c.onAccent),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (result != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  const SectionLabel('Hasil Parsing'),
                  AppCard(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: AppSpacing.iconBox,
                          height: AppSpacing.iconBox,
                          decoration: BoxDecoration(
                            color: _resultColor(c).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(AppSpacing.sm),
                          ),
                          child: Icon(result!.icon, color: _resultColor(c)),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Kategori terdeteksi: ${result!.label}',
                                style: AppTypography.label(_resultColor(c)),
                              ),
                              const SizedBox(height: AppSpacing.xxs),
                              Text(
                                result!.explanation,
                                style: AppTypography.meta(c.textMuted),
                              ),
                            ],
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
