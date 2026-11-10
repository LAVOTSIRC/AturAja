import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/id_generator.dart';
import '../data/models.dart';
import '../providers/app_provider.dart';
import '../services/brain_dump_ai_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/theme_scope.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import 'finance_screen.dart';

enum FinanceNoteKind {
  income(label: 'Catatan Keuangan', icon: Icons.savings_outlined),
  expense(label: 'Catatan Pengeluaran', icon: Icons.shopping_bag_outlined);

  const FinanceNoteKind({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

const List<String> incomeCategoryLabels = [
  'Gaji',
  'Kiriman',
  'Freelance',
  'Lainnya',
];

const Map<String, String> expenseCategoryKeys = {
  'Makan & Minum': 'food',
  'Hiburan': 'entertainment',
  'Transport': 'transport',
  'Belanja': 'belanja',
  'Lainnya': 'other',
};

const Map<String, List<String>> incomeKeywords = {
  'Gaji': ['gaji', 'salary', 'bayar kerja'],
  'Kiriman': ['kirim', 'orang tua', 'ibu', 'ayah', 'transfer masuk', 'dibayar'],
  'Freelance': ['freelance', 'proyek', 'honor', 'bonus', 'komisi'],
};

const Map<String, List<String>> expenseKeywords = {
  'Makan & Minum': [
    'makan',
    'minum',
    'kopi',
    'batagor',
    'resto',
    'cafe',
    'warung',
    'nasi',
    'mie',
    'snack',
    'cemilan',
    'susu',
    'roti',
  ],
  'Hiburan': [
    'hiburan',
    'film',
    'movie',
    'nonton',
    'konser',
    'game',
    'steam',
    'spotify',
    'netflix',
    'musik',
  ],
  'Transport': [
    'transport',
    'bensin',
    'gojek',
    'grab',
    'ojek',
    'mobil',
    'parkir',
    'tol',
    'kereta',
    'bus',
    'taksi',
    'listrik',
    'pln',
    'token',
    'pulsa',
  ],
  'Belanja': [
    'belanja',
    'supermarket',
    'indomaret',
    'alfamart',
    'tokopedia',
    'shopee',
    'lazada',
    'sayur',
    'buah',
    'dada ayam',
  ],
};

int? parseBrainDumpAmount(String raw) {
  final RegExpMatch? match = RegExp(
    r'(\d+(?:[.,\s]\d+)*)\s*(ribu|rb|juta|jt|k)?',
    caseSensitive: false,
  ).firstMatch(raw);
  if (match == null) {
    return null;
  }

  final String token = match.group(1)!.replaceAll(' ', '');
  final String unit = (match.group(2) ?? '').toLowerCase();
  if (unit.isEmpty) {
    return int.tryParse(token.replaceAll(RegExp('[.,]'), ''));
  }

  final double base = double.tryParse(token.replaceAll(',', '.')) ?? 0;
  if (base <= 0) {
    return null;
  }
  if (unit == 'k' || unit == 'rb' || unit == 'ribu') {
    return (base * 1000).round();
  }
  return (base * 1000000).round();
}

String detectIncomeCategory(String text) {
  final String lower = text.toLowerCase();
  for (final MapEntry<String, List<String>> entry in incomeKeywords.entries) {
    if (entry.value.any(lower.contains)) {
      return entry.key;
    }
  }
  return 'Lainnya';
}

String detectExpenseCategory(String text) {
  final String lower = text.toLowerCase();
  for (final MapEntry<String, List<String>> entry in expenseKeywords.entries) {
    if (entry.value.any(lower.contains)) {
      return entry.key;
    }
  }
  return 'Lainnya';
}

class BrainDumpFinanceScreen extends StatefulWidget {
  const BrainDumpFinanceScreen({super.key});

  @override
  State<BrainDumpFinanceScreen> createState() => _BrainDumpFinanceScreenState();
}

class _BrainDumpFinanceScreenState extends State<BrainDumpFinanceScreen> {
  static const List<String> incomeSuggestions = [
    'Gaji bulan ini 4.500.000',
    'Ibu kirim 500rb untuk kos',
    'Honor proyek desain 1.2jt',
  ];

  static const List<String> expenseSuggestions = [
    'Bayar kos 650rb',
    'Makan batagor 15k',
    'Bensin motor 29k',
    'Belanja sayur 120rb',
  ];

  final TextEditingController dumpController = TextEditingController();

  bool isProcessing = false;
  bool hasPreview = false;
  List<BrainDumpItem> parsedItems = const <BrainDumpItem>[];
  String? errorMessage;

  @override
  void dispose() {
    dumpController.dispose();
    super.dispose();
  }

  Future<void> _processBrainDump() async {
    final String text = dumpController.text.trim();
    if (text.isEmpty) {
      setState(() => errorMessage = 'Tuliskan isi brain dump terlebih dahulu.');
      return;
    }
    if (text.length < 5) {
      setState(
        () => errorMessage =
            'Isi brain dump terlalu pendek (minimal 5 karakter).',
      );
      return;
    }
    final int? localAmount = parseBrainDumpAmount(text);
    if (localAmount == null || localAmount <= 0) {
      setState(
        () => errorMessage =
            'Nominal belum terdeteksi. Contoh: "650rb", "15k", atau "1.200.000".',
      );
      return;
    }
    setState(() {
      isProcessing = true;
      errorMessage = null;
      hasPreview = false;
    });

    try {
      final List<BrainDumpItem> items = await BrainDumpAiService().parse(text);
      final List<BrainDumpItem> validItems = items
          .where(
            (BrainDumpItem item) =>
                (item.type == BrainDumpItemType.income ||
                    item.type == BrainDumpItemType.expense) &&
                item.amount != null &&
                item.amount! > 0,
          )
          .toList();
      final List<int> localAmounts = _localAmounts(text);
      if (validItems.length == localAmounts.length) {
        for (int index = 0; index < validItems.length; index++) {
          final BrainDumpItem item = validItems[index];
          validItems[index] = BrainDumpItem(
            type: item.type,
            title: item.title,
            description: item.description,
            amount: localAmounts[index],
            category: item.category,
            dueDate: item.dueDate,
            dueTime: item.dueTime,
          );
        }
      }
      if (validItems.isEmpty) {
        throw const BrainDumpAiException(
          'Nominal belum terdeteksi. Contoh: "650rb", "15k", atau "1.200.000".',
        );
      }
      if (validItems.any(
        (BrainDumpItem item) => item.amount! > kMaxTransactionAmount,
      )) {
        throw BrainDumpAiException(
          'Salah satu nominal melebihi maksimal '
          '${formatRupiah(kMaxTransactionAmount)}.',
        );
      }
      if (!mounted) {
        return;
      }

      setState(() {
        isProcessing = false;
        parsedItems = validItems;
        hasPreview = true;
      });
    } on BrainDumpAiException catch (error) {
      if (!mounted) {
        return;
      }
      final List<BrainDumpItem> fallbackItems = _localItems(text);
      setState(() {
        isProcessing = false;
        parsedItems = fallbackItems;
        hasPreview = fallbackItems.isNotEmpty;
        errorMessage = fallbackItems.isEmpty
            ? error.message
            : 'Gemini gagal, memakai hasil lokal: ${error.message}';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      final List<BrainDumpItem> fallbackItems = _localItems(text);
      setState(() {
        isProcessing = false;
        parsedItems = fallbackItems;
        hasPreview = fallbackItems.isNotEmpty;
        errorMessage = fallbackItems.isEmpty
            ? 'Brain dump gagal diproses: $error'
            : 'Gemini gagal, memakai hasil lokal: $error';
      });
    }
  }

  List<BrainDumpItem> _localItems(String text) {
    final List<BrainDumpItem> items = <BrainDumpItem>[];
    final RegExp amountPattern = RegExp(
      r'(\d+(?:[.,]\d+)*)\s*(ribu|rb|juta|jt|k)?',
      caseSensitive: false,
    );
    for (final RegExpMatch match in amountPattern.allMatches(text)) {
      final int? amount = parseBrainDumpAmount(match.group(0)!);
      if (amount == null || amount <= 0 || amount > kMaxTransactionAmount) {
        continue;
      }
      final String before = text.substring(0, match.start);
      final String segment = before.split(RegExp(r'\b(dan|terus|lalu)\b')).last
          .trim();
      final String lower = segment.toLowerCase();
      final bool income = lower.contains('dapat') ||
          lower.contains('transfer') ||
          lower.contains('kirim') ||
          lower.contains('bayar utang') ||
          lower.contains('dibayar');
      final String title = segment.isEmpty
          ? (income ? 'Pemasukan' : 'Pengeluaran')
          : segment;
      items.add(
        BrainDumpItem(
          type: income ? BrainDumpItemType.income : BrainDumpItemType.expense,
          title: title,
          amount: amount,
          category: income
              ? detectIncomeCategory(segment)
              : detectExpenseCategory(segment),
        ),
      );
    }
    return items;
  }

  List<int> _localAmounts(String text) {
    return RegExp(
      r'(\d+(?:[.,]\d+)*)\s*(ribu|rb|juta|jt|k)?',
      caseSensitive: false,
    )
        .allMatches(text)
        .map((RegExpMatch match) => parseBrainDumpAmount(match.group(0)!))
        .whereType<int>()
        .where((int amount) => amount > 0)
        .toList();
  }

  String _categoryKey(BrainDumpItem item) {
    if (item.type == BrainDumpItemType.income) {
      return switch (item.category) {
        'Gaji' || 'Kiriman' || 'Freelance' => item.category!.toLowerCase(),
        _ => 'income',
      };
    }
    return expenseCategoryKeys[item.category] ?? 'other';
  }

  void _save() {
    if (parsedItems.isEmpty) {
      setState(() => errorMessage = 'Belum ada hasil brain dump untuk disimpan.');
      return;
    }

    final List<TransactionItem> notes = parsedItems.indexed.map((
      (int, BrainDumpItem) entry,
    ) {
      final BrainDumpItem item = entry.$2;
      return TransactionItem(
        id: newDocumentId(),
        label: item.title,
        amount: item.type == BrainDumpItemType.income
            ? item.amount!
            : -item.amount!,
        cat: _categoryKey(item),
        time: TimeOfDay.now().format(context),
        date: 'Hari ini',
      );
    }).toList();

    HapticFeedback.lightImpact();
    final AppProvider app = context.read<AppProvider>();
    for (final TransactionItem note in notes) {
      app.addTransaction(note);
    }
    Navigator.of(context).pop(notes);
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = ThemeScope.of(context).colors;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Kembali',
        ),
        title: Text(
          'Brain Dump Keuangan',
          style: AppTypography.titleLarge(c.text),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (errorMessage != null) ...[
                      AppErrorMessage(message: errorMessage!),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    if (hasPreview) _previewBody(c) else _inputBody(c),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _inputBody(AppColors c) {
    const Color accent = Colors.deepPurple;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: c.ai.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      size: AppSpacing.iconSmall,
                      color: c.ai,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI Brain Dump Keuangan',
                          style: AppTypography.label(c.text)
                              .copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          'Tuliskan pemasukan dan pengeluaran sekaligus — AI akan memisahkan setiap transaksi.',
                          style: AppTypography.caption(c.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: dumpController,
                autofocus: true,
                maxLines: 4,
                maxLength: 300,
                style: AppTypography.bodyLarge(c.text),
                onChanged: (_) {
                  if (errorMessage != null) {
                    setState(() => errorMessage = null);
                  }
                },
                decoration: _inputDecoration(
                  c,
                  hintText:
                      'Contoh: Ayah transfer 500rb lalu bayar parkir 2k',
                ).copyWith(counterText: ''),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'CONTOH BRAIN DUMP',
                style: AppTypography.overline(c.textMuted),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: <String>[
                  ...incomeSuggestions,
                  ...expenseSuggestions,
                ].map((String suggestion) {
                  return PressableScale(
                    onTap: () => setState(() {
                      dumpController.text = suggestion;
                      errorMessage = null;
                    }),
                    semanticLabel: 'Gunakan contoh $suggestion',
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: c.surfaceHigh,
                        borderRadius: BorderRadius.circular(AppSpacing.huge),
                        border: Border.all(color: c.border),
                      ),
                      child: Text(
                        suggestion,
                        style: AppTypography.caption(c.textSub),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.lg),
              PressableScale(
                onTap: isProcessing ? null : _processBrainDump,
                semanticLabel: 'Proses Brain Dump Keuangan dengan AI',
                child: Container(
                  width: double.infinity,
                  height: AppSpacing.target,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(AppSpacing.md),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isProcessing) ...[
                        SizedBox(
                          width: AppSpacing.iconSmall,
                          height: AppSpacing.iconSmall,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: c.onAccent,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          'Memproses...',
                          style: AppTypography.button(c.onAccent),
                        ),
                      ] else ...[
                        Icon(
                          Icons.auto_awesome_rounded,
                          size: AppSpacing.iconSmall,
                          color: c.onAccent,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          'Proses Brain Dump',
                          style: AppTypography.button(c.onAccent),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: AppSpacing.iconSmall - 4,
              color: c.textMuted,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                'Gemini akan memisahkan semua pemasukan dan pengeluaran. '
                'Periksa hasilnya sebelum disimpan.',
                style: AppTypography.meta(c.textMuted),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _previewBody(AppColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.auto_awesome_rounded,
              size: AppSpacing.iconSmall,
              color: c.ai,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                'Periksa hasil AI sebelum disimpan',
                style: AppTypography.label(c.text)
                    .copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...parsedItems.map((BrainDumpItem item) {
                final bool income = item.type == BrainDumpItemType.income;
                final Color accent = income ? c.success : c.expense;
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: c.surfaceHigh,
                      borderRadius: BorderRadius.circular(AppSpacing.sm),
                      border: Border.all(color: c.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              income
                                  ? Icons.south_west_rounded
                                  : Icons.north_east_rounded,
                              color: accent,
                              size: AppSpacing.iconSmall,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: Text(
                                item.title,
                                style: AppTypography.label(c.text).copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              income ? '+' : '-',
                              style: AppTypography.label(accent).copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '${item.amount}',
                              style: AppTypography.label(accent).copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        if (item.category != null)
                          Padding(
                            padding: const EdgeInsets.only(
                              left: AppSpacing.iconSmall + AppSpacing.xs,
                            ),
                            child: Text(
                              item.category!,
                              style: AppTypography.meta(c.textMuted),
                            ),
                          ),
                        if (item.description != null)
                          Padding(
                            padding: const EdgeInsets.only(
                              top: AppSpacing.xs,
                              left: AppSpacing.iconSmall + AppSpacing.xs,
                            ),
                            child: Text(
                              item.description!,
                              style: AppTypography.caption(c.textSub),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        PressableScale(
          onTap: _save,
          semanticLabel: 'Simpan semua catatan keuangan',
          child: Container(
            width: double.infinity,
            height: AppSpacing.target,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.blue,
              borderRadius: BorderRadius.circular(AppSpacing.md),
            ),
            child: Text(
              'Simpan Semua Catatan',
              style: AppTypography.button(c.onAccent),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: () => setState(() {
              hasPreview = false;
              errorMessage = null;
            }),
            style: TextButton.styleFrom(
              minimumSize: const Size(
                AppSpacing.targetCompact,
                AppSpacing.target,
              ),
              foregroundColor: c.textMuted,
            ),
            child: Text(
              'Ubah brain dump lagi',
              style: AppTypography.label(c.textMuted),
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(AppColors c, {required String hintText}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: AppTypography.body(c.textMuted),
      filled: true,
      fillColor: c.surfaceHigh.withValues(alpha: 0.6),
      contentPadding: const EdgeInsets.all(AppSpacing.sm),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.md),
        borderSide: BorderSide(color: c.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.md),
        borderSide: BorderSide(color: c.blue, width: 1.5),
      ),
    );
  }
}
