import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/models.dart';
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

  FinanceNoteKind kind = FinanceNoteKind.income;

  final TextEditingController dumpController = TextEditingController();
  final TextEditingController amountController = TextEditingController();
  final TextEditingController labelController = TextEditingController();

  bool isProcessing = false;
  bool hasPreview = false;
  String selectedCategory = 'Gaji';
  String? errorMessage;

  bool get isIncome => kind == FinanceNoteKind.income;

  List<String> get categories =>
      isIncome ? incomeCategoryLabels : expenseCategoryKeys.keys.toList();

  List<String> get suggestions =>
      isIncome ? incomeSuggestions : expenseSuggestions;

  @override
  void dispose() {
    dumpController.dispose();
    amountController.dispose();
    labelController.dispose();
    super.dispose();
  }

  void _selectKind(FinanceNoteKind next) {
    if (next == kind) {
      return;
    }
    setState(() {
      kind = next;
      hasPreview = false;
      errorMessage = null;
      amountController.clear();
      labelController.clear();
    });
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

    final int? amount = parseBrainDumpAmount(text);
    if (amount == null || amount <= 0) {
      setState(
        () => errorMessage = 'Nominal belum terdeteksi. Contoh: "650rb", "15k", atau "1.200.000".',
      );
      return;
    }
    if (amount > kMaxTransactionAmount) {
      setState(
        () => errorMessage =
            'Nominal maksimal ${formatRupiah(kMaxTransactionAmount)}.',
      );
      return;
    }

    setState(() {
      isProcessing = true;
      errorMessage = null;
    });

    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) {
      return;
    }

    final String detectedCategory = isIncome
        ? detectIncomeCategory(text)
        : detectExpenseCategory(text);

    String label = text
        .replaceFirst(RegExp(r'\b(rp|idr)\b', caseSensitive: false), '')
        .replaceAll(
          RegExp(
            r'\d+(?:[.,\s]\d+)*\s*(ribu|rb|juta|jt|k)?',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .replaceAll(RegExp(r'^[\s,.:;-]+'), '')
        .trim();
    if (label.isEmpty) {
      label = detectedCategory;
    }

    setState(() {
      isProcessing = false;
      amountController.text = '$amount';
      labelController.text = label;
      selectedCategory = detectedCategory;
      hasPreview = true;
    });
  }

  void _save() {
    final int? amount = int.tryParse(
      amountController.text.replaceAll(RegExp('[^0-9]'), ''),
    );
    if (amount == null || amount <= 0) {
      setState(() => errorMessage = 'Isi nominal dengan angka yang valid.');
      return;
    }
    if (amount > kMaxTransactionAmount) {
      setState(
        () => errorMessage =
            'Nominal maksimal ${formatRupiah(kMaxTransactionAmount)}.',
      );
      return;
    }

    final String label = labelController.text.trim().isEmpty
        ? selectedCategory
        : labelController.text.trim();

    final TransactionItem note = TransactionItem(
      id: DateTime.now().millisecondsSinceEpoch,
      label: label,
      amount: isIncome ? amount : -amount,
      cat: isIncome ? 'income' : expenseCategoryKeys[selectedCategory]!,
      time: TimeOfDay.now().format(context),
      date: 'Hari ini',
    );

    HapticFeedback.lightImpact();
    transactionStore.insert(0, note);
    Navigator.of(context).pop(note);
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
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                0,
              ),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.xxs),
                decoration: BoxDecoration(
                  color: c.surfaceHigh,
                  borderRadius: BorderRadius.circular(AppSpacing.md),
                  border: Border.all(color: c.border),
                ),
                child: Row(
                  children: [
                    _kindTab(c, FinanceNoteKind.income),
                    const SizedBox(width: AppSpacing.xxs),
                    _kindTab(c, FinanceNoteKind.expense),
                  ],
                ),
              ),
            ),
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

  Widget _kindTab(AppColors c, FinanceNoteKind value) {
    final bool active = kind == value;
    final Color accent = value == FinanceNoteKind.income
        ? c.success
        : c.expense;
    return Expanded(
      child: PressableScale(
        onTap: () => _selectKind(value),
        selected: active,
        semanticLabel: 'Pilih mode ${value.label}',
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          constraints: const BoxConstraints(minHeight: AppSpacing.target),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: active ? accent : c.transparent,
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
                value.icon,
                size: AppSpacing.iconSmall - 4,
                color: active ? c.onAccent : c.textSub,
              ),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  value.label,
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

  Widget _inputBody(AppColors c) {
    final Color accent = isIncome ? c.success : c.expense;
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
                          'AI Brain Dump ${kind.label}',
                          style: AppTypography.label(c.text)
                              .copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          isIncome
                              ? 'Tuliskan pemasukan bebas — AI akan memilah Nominal, Sumber, dan Keterangan.'
                              : 'Tuliskan pengeluaran bebas — AI akan memilah Nominal, Kategori, dan Keterangan.',
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
                  hintText: isIncome
                      ? 'Contoh: Ibu kirim 500rb untuk uang kos bulan ini'
                      : 'Contoh: Bayar kos 650rb sama makan batagor 15k',
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
                children: suggestions.map((String suggestion) {
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
                'Simulasi lokal. Hasilnya bisa kamu perbaiki sebelum disimpan.',
                style: AppTypography.meta(c.textMuted),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _previewBody(AppColors c) {
    final Color accent = isIncome ? c.success : c.expense;
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
              _formLabel(c, 'NOMINAL *'),
              const SizedBox(height: AppSpacing.xxs),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                style: AppTypography.display(c.text),
                onChanged: (_) {
                  if (errorMessage != null) {
                    setState(() => errorMessage = null);
                  }
                },
                decoration: _inputDecoration(c, hintText: '0').copyWith(
                  counterText: '',
                  prefixText: 'Rp ',
                  prefixStyle: AppTypography.display(c.textMuted),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _formLabel(c, isIncome ? 'SUMBER' : 'KATEGORI'),
                  Text(
                    selectedCategory,
                    style: AppTypography.micro(accent)
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: categories.map((String cat) {
                  final bool active = selectedCategory == cat;
                  return GestureDetector(
                    onTap: () => setState(() => selectedCategory = cat),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      constraints: const BoxConstraints(
                        minHeight: AppSpacing.targetCompact,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: active
                            ? (isIncome ? c.successDim : c.expenseDim)
                            : c.surfaceHigh,
                        borderRadius: BorderRadius.circular(AppSpacing.huge),
                        border: Border.all(color: active ? accent : c.border),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        cat,
                        style: AppTypography.label(active ? accent : c.textSub)
                            .copyWith(
                              fontWeight: active
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.md),
              _formLabel(c, 'KETERANGAN'),
              const SizedBox(height: AppSpacing.xxs),
              TextField(
                controller: labelController,
                maxLines: 3,
                style: AppTypography.bodyLarge(c.text),
                decoration: _inputDecoration(
                  c,
                  hintText: 'misal: batagor depan kampus',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        PressableScale(
          onTap: _save,
          semanticLabel: isIncome
              ? 'Simpan catatan keuangan'
              : 'Simpan catatan pengeluaran',
          child: Container(
            width: double.infinity,
            height: AppSpacing.target,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(AppSpacing.md),
            ),
            child: Text(
              'Simpan ${kind.label}',
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

  Widget _formLabel(AppColors c, String text) {
    return Text(text, style: AppTypography.overline(c.textMuted));
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
