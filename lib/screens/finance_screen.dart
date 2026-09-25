import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/theme_scope.dart';
import '../utils/format.dart';
import '../utils/icons.dart';
import '../widgets/common.dart';
import 'category_detail_screen.dart';

// ── Helpers ──────────────────────────────────────────────────────────────────

String _catLabel(String cat) {
  switch (cat) {
    case 'food':
      return 'Makan & Minum';
    case 'entertainment':
      return 'Hiburan';
    case 'transport':
      return 'Transport';
    case 'income':
      return 'Pemasukan';
    default:
      return 'Lainnya';
  }
}

String _catKey(String displayName) {
  switch (displayName) {
    case 'Makan & Minum':
      return 'food';
    case 'Hiburan':
      return 'entertainment';
    case 'Transport':
      return 'transport';
    case 'Belanja':
      return 'belanja';
    default:
      return 'other';
  }
}

/// Maximum nominal allowed per transaction, to keep entries realistic.
const int kMaxTransactionAmount = 999999999;

// ── Data model ───────────────────────────────────────────────────────────────

class _CategorySlice {
  final String label;
  final int pct;
  final Color color;
  final int amount;
  final String catKey;

  const _CategorySlice(
    this.label,
    this.pct,
    this.color,
    this.amount,
    this.catKey,
  );
}

// ── Screen ───────────────────────────────────────────────────────────────────

class FinanceScreen extends StatefulWidget {
  final VoidCallback onScan;

  const FinanceScreen({super.key, required this.onScan});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  late List<TransactionItem> _transactions;

  static const int _budget = 1200000;
  static const int _spent = 325990;

  @override
  void initState() {
    super.initState();
    _transactions = transactionStore;
  }

  List<TransactionItem> _transactionsForCategory(String catKey) {
    if (catKey == 'other') {
      return _transactions
          .where(
            (t) =>
                t.cat != 'food' &&
                t.cat != 'entertainment' &&
                t.cat != 'transport' &&
                t.cat != 'income',
          )
          .toList();
    }
    return _transactions.where((t) => t.cat == catKey).toList();
  }

  void _showAddIncomeModal() => _showAddTransactionModal(isIncome: true);
  void _showAddExpenseModal() => _showAddTransactionModal(isIncome: false);

  void _showAddTransactionModal({required bool isIncome}) {
    final AppColors c = ThemeScope.of(context).colors;
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    const incomeCategories = ['Gaji', 'Kiriman', 'Freelance', 'Lainnya'];
    const expenseCategories = [
      'Makan & Minum',
      'Hiburan',
      'Transport',
      'Belanja',
      'Lainnya',
    ];
    final categories = isIncome ? incomeCategories : expenseCategories;
    String selectedCategory = categories.first;
    String? errorMessage;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
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
                      // Handle
                      Center(
                        child: Container(
                          width: AppSpacing.sheetHandleWidth,
                          height: AppSpacing.sheetHandleHeight,
                          margin: const EdgeInsets.only(bottom: AppSpacing.md),
                          decoration: BoxDecoration(
                            color: c.surfaceHigh,
                            borderRadius: BorderRadius.circular(
                              AppSpacing.huge,
                            ),
                          ),
                        ),
                      ),
                      // Modal title
                      Row(
                        children: [
                          Container(
                            width: AppSpacing.iconBox,
                            height: AppSpacing.iconBox,
                            decoration: BoxDecoration(
                              color: isIncome ? c.successDim : c.expenseDim,
                              borderRadius: BorderRadius.circular(
                                AppSpacing.sm,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              isIncome
                                  ? Icons.call_received_outlined
                                  : Icons.call_made_outlined,
                              size: AppSpacing.iconSmall,
                              color: isIncome ? c.success : c.expense,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            isIncome
                                ? 'Tambah Pemasukan'
                                : 'Tambah Pengeluaran',
                            style: AppTypography.title(c.text),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      // Amount field
                      Text('Nominal', style: AppTypography.meta(c.textMuted)),
                      const SizedBox(height: AppSpacing.xs),
                      TextField(
                        controller: amountCtrl,
                        autofocus: true,
                        keyboardType: TextInputType.number,
                        onChanged: (_) {
                          if (errorMessage != null) {
                            setModalState(() => errorMessage = null);
                          }
                        },
                        style: AppTypography.display(c.text),
                        decoration: InputDecoration(
                          hintText: '0',
                          prefixText: 'Rp ',
                          prefixStyle: AppTypography.display(c.textMuted),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      // Category chips
                      Text('Kategori', style: AppTypography.meta(c.textMuted)),
                      const SizedBox(height: AppSpacing.xs),
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: categories.map((cat) {
                          final bool active = selectedCategory == cat;
                          return GestureDetector(
                            onTap: () =>
                                setModalState(() => selectedCategory = cat),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: AppSpacing.xs,
                              ),
                              decoration: BoxDecoration(
                                color: active
                                    ? (isIncome ? c.successDim : c.expenseDim)
                                    : c.surfaceHigh,
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.huge,
                                ),
                                border: Border.all(
                                  color: active
                                      ? (isIncome ? c.success : c.expense)
                                      : c.border,
                                ),
                              ),
                              child: Text(
                                cat,
                                style:
                                    AppTypography.label(
                                      active
                                          ? (isIncome ? c.success : c.expense)
                                          : c.textSub,
                                    ).copyWith(
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
                      // Description field
                      Text(
                        'Deskripsi (opsional)',
                        style: AppTypography.meta(c.textMuted),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      TextField(
                        controller: descCtrl,
                        maxLength: 60,
                        style: AppTypography.body(c.text),
                        decoration: const InputDecoration(
                          hintText: 'Contoh: Makan siang di warteg',
                        ),
                      ),
                      if (errorMessage != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        AppErrorMessage(message: errorMessage!),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      // Save button
                      SizedBox(
                        width: double.infinity,
                        child: PressableScale(
                          onTap: () {
                            final rawAmount = int.tryParse(
                              amountCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''),
                            );
                            if (rawAmount == null || rawAmount <= 0) {
                              setModalState(
                                () => errorMessage = 'Nominal wajib diisi dan harus lebih dari Rp0.',
                              );
                              return;
                            }
                            if (rawAmount > kMaxTransactionAmount) {
                              setModalState(
                                () => errorMessage =
                                    'Nominal maksimal ${formatRupiah(kMaxTransactionAmount)}.',
                              );
                              return;
                            }
                            final newId = DateTime.now().millisecondsSinceEpoch;
                            final resolvedCatKey = isIncome
                                ? 'income'
                                : _catKey(selectedCategory);
                            final newTransaction = TransactionItem(
                              id: newId,
                              label: descCtrl.text.trim().isEmpty
                                  ? selectedCategory
                                  : descCtrl.text.trim(),
                              amount: isIncome ? rawAmount : -rawAmount,
                              cat: resolvedCatKey,
                              time: TimeOfDay.now().format(ctx),
                              date: 'Hari ini',
                            );
                            HapticFeedback.lightImpact();
                            setState(() {
                              _transactions.insert(0, newTransaction);
                            });
                            Navigator.of(ctx).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  isIncome
                                      ? 'Pemasukan "${newTransaction.label}" dicatat'
                                      : 'Pengeluaran "${newTransaction.label}" dicatat',
                                ),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                          semanticLabel: isIncome
                              ? 'Simpan pemasukan'
                              : 'Simpan pengeluaran',
                          tooltip: 'Simpan',
                          child: Container(
                            constraints: const BoxConstraints(
                              minHeight: AppSpacing.target,
                            ),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isIncome ? c.success : c.expense,
                              borderRadius: BorderRadius.circular(
                                AppSpacing.sm,
                              ),
                            ),
                            child: Text(
                              'Simpan',
                              style: AppTypography.button(c.onAccent)
                                  .copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: Text(
                            'Batal',
                            style: AppTypography.label(c.textMuted),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showTransactionDetail(TransactionItem t) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TransactionDetailSheet(
        transaction: t,
        onEdit: (updated) {
          setState(() {
            final idx = _transactions.indexWhere((x) => x.id == updated.id);
            if (idx != -1) _transactions[idx] = updated;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Perubahan pada "${updated.label}" disimpan'),
              duration: const Duration(seconds: 2),
            ),
          );
        },
        onDelete: () {
          final removedIndex = _transactions.indexWhere((x) => x.id == t.id);
          setState(() => _transactions.removeWhere((x) => x.id == t.id));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('"${t.label}" dihapus dari riwayat'),
              action: SnackBarAction(
                label: 'Urungkan',
                onPressed: () {
                  setState(() {
                    final insertIndex = removedIndex.clamp(
                      0,
                      _transactions.length,
                    );
                    _transactions.insert(insertIndex, t);
                  });
                },
              ),
              duration: const Duration(seconds: 4),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = ThemeScope.of(context).colors;

    final List<_CategorySlice> cats = [
      _CategorySlice('Makan & Minum', 45, c.blue, 145000, 'food'),
      _CategorySlice('Hiburan', 25, c.expense, 83990, 'entertainment'),
      _CategorySlice('Transport', 20, c.warning, 65000, 'transport'),
      _CategorySlice('Lainnya', 10, c.success, 32000, 'other'),
    ];

    final int totalIncome = _transactions
        .where((t) => t.amount > 0)
        .fold(0, (sum, t) => sum + t.amount);
    final int totalExpense = _transactions
        .where((t) => t.amount < 0)
        .fold(0, (sum, t) => sum + t.amount.abs());

    final double usagePct = _spent / _budget;
    final Color budgetColor = usagePct < 0.70
        ? c.success
        : usagePct < 0.90
        ? c.warning
        : c.expense;

    return Container(
      color: c.bg,
      child: SafeArea(
        child: SingleChildScrollView(
          // No FAB anymore — just nav bar height + comfortable margin
          padding: const EdgeInsets.only(
            bottom: AppSpacing.navHeight + AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.xs,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Keuangan',
                            style: AppTypography.titleLarge(c.text),
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            'Ringkasan September 2026',
                            style: AppTypography.meta(c.textMuted),
                          ),
                        ],
                      ),
                    ),
                    // Theme toggle with label hint
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.remove_red_eye_outlined,
                              size: 14,
                              color: c.textMuted,
                            ),
                            const SizedBox(width: AppSpacing.xxs),
                            const ThemeToggleSwitch(),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text('Tema', style: AppTypography.micro(c.textMuted)),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Action buttons ────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.xs,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                child: Row(
                  children: [
                    // + Pemasukan (solid fill green, flex 42)
                    Expanded(
                      flex: 42,
                      child: PressableScale(
                        onTap: _showAddIncomeModal,
                        semanticLabel: 'Tambah pemasukan',
                        tooltip: 'Tambah pemasukan',
                        child: Container(
                          height: 50,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: c.success,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.add_rounded,
                                size: AppSpacing.iconSmall,
                                color: c.onAccent,
                              ),
                              const SizedBox(width: AppSpacing.xxs),
                              Text(
                                'Pemasukan',
                                style: AppTypography.label(c.onAccent)
                                    .copyWith(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    // – Pengeluaran (solid fill red, flex 42)
                    Expanded(
                      flex: 42,
                      child: PressableScale(
                        onTap: _showAddExpenseModal,
                        semanticLabel: 'Tambah pengeluaran',
                        tooltip: 'Tambah pengeluaran',
                        child: Container(
                          height: 50,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: c.expense,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.remove_rounded,
                                size: AppSpacing.iconSmall,
                                color: c.onAccent,
                              ),
                              const SizedBox(width: AppSpacing.xxs),
                              Text(
                                'Pengeluaran',
                                style: AppTypography.label(c.onAccent)
                                    .copyWith(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    // Scan Struk — outline, icon+label stacked, flex 16
                    Expanded(
                      flex: 16,
                      child: PressableScale(
                        onTap: widget.onScan,
                        semanticLabel: 'Scan struk',
                        tooltip: 'Scan struk',
                        child: Container(
                          height: 50,
                          constraints: const BoxConstraints(minWidth: 44),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: c.blueDim,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: c.blue, width: 1.5),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.document_scanner_outlined,
                                size: 16,
                                color: c.blue,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Scan',
                                style: AppTypography.micro(c.blue)
                                    .copyWith(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Summary cards ─────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _summaryCard(
                        c,
                        Icons.call_received_outlined,
                        'Pemasukan',
                        totalIncome > 0 ? totalIncome : 500000,
                        c.success,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: _summaryCard(
                        c,
                        Icons.call_made_outlined,
                        'Pengeluaran',
                        totalExpense > 0 ? totalExpense : 325990,
                        c.expense,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Budget indicator ──────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionLabel('Indikator Anggaran'),
                    AppCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Anggaran Bulan Ini',
                                style: AppTypography.label(c.text),
                              ),
                              Text(
                                formatRupiah(_budget),
                                style: AppTypography.caption(c.blue)
                                    .copyWith(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          // Overall usage bar
                          ClipRRect(
                            borderRadius: BorderRadius.circular(
                              AppSpacing.huge,
                            ),
                            child: LinearProgressIndicator(
                              value: usagePct.clamp(0.0, 1.0),
                              minHeight: AppSpacing.progressThin,
                              backgroundColor: c.surfaceHigh,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                budgetColor,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          // Segmented bar by category
                          ClipRRect(
                            borderRadius: BorderRadius.circular(
                              AppSpacing.huge,
                            ),
                            child: SizedBox(
                              height: AppSpacing.progressMedium,
                              child: Row(
                                children: cats
                                    .map(
                                      (_CategorySlice slice) => Expanded(
                                        flex: slice.pct,
                                        child: Container(
                                          margin: const EdgeInsets.symmetric(
                                            horizontal: AppSpacing.xxs,
                                          ),
                                          color: slice.color,
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          // Spent / Remaining row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text.rich(
                                TextSpan(
                                  style: AppTypography.micro(c.textMuted),
                                  children: [
                                    const TextSpan(text: 'Terpakai: '),
                                    TextSpan(
                                      text: formatRupiah(_spent),
                                      style: AppTypography.micro(
                                        c.text,
                                      ).copyWith(fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                usagePct > 1.0
                                    ? 'Lebih ${formatRupiah(_spent - _budget)}'
                                    : 'Sisa ${formatRupiah(_budget - _spent)}',
                                style: AppTypography.micro(budgetColor),
                              ),
                            ],
                          ),
                          if (usagePct > 1.0) ...[
                            const SizedBox(height: AppSpacing.xs),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: AppSpacing.xs,
                              ),
                              decoration: BoxDecoration(
                                color: c.expenseDim,
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.sm,
                                ),
                                border: Border.all(color: c.expense),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.warning_amber_rounded,
                                    size: AppSpacing.iconSmall,
                                    color: c.expense,
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                  Expanded(
                                    child: Text(
                                      'Anggaran bulan ini terlampaui ${formatRupiah(_spent - _budget)}',
                                      style: AppTypography.micro(
                                        c.expense,
                                      ).copyWith(fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.xs),
                          // Legend row
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.xxs,
                            children: cats.map((slice) {
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: slice.color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.xxs),
                                  Text(
                                    slice.label,
                                    style: AppTypography.micro(c.textMuted),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Category breakdown ────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionLabel('Breakdown Kategori'),
                    Column(
                      children: cats
                          .map(
                            (_CategorySlice slice) => Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.xs,
                              ),
                              child: PressableScale(
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => CategoryDetailScreen(
                                        categoryLabel: slice.label,
                                        categoryColor: slice.color,
                                        transactions: _transactionsForCategory(
                                          slice.catKey,
                                        ),
                                        onTransactionUpdated: (updated) {
                                          setState(() {
                                            final idx = _transactions
                                                .indexWhere(
                                                  (x) => x.id == updated.id,
                                                );
                                            if (idx != -1) {
                                              _transactions[idx] = updated;
                                            }
                                          });
                                        },
                                        onTransactionDeleted: (id) {
                                          setState(
                                            () => _transactions.removeWhere(
                                              (x) => x.id == id,
                                            ),
                                          );
                                        },
                                        onTransactionRestored: (item) {
                                          setState(
                                            () => _transactions.insert(0, item),
                                          );
                                        },
                                      ),
                                    ),
                                  );
                                },
                                semanticLabel:
                                    'Lihat detail kategori ${slice.label}',
                                tooltip: 'Lihat detail ${slice.label}',
                                child: _categoryCard(c, slice),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),

              // ── Transaction history ───────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionLabel('Riwayat Transaksi'),
                    if (_transactions.isEmpty)
                      const AppEmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: 'Belum ada transaksi',
                        message: 'Riwayat pengeluaran dan pemasukan akan muncul di sini.',
                      )
                    else
                      Column(
                        children: _transactions
                            .map(
                              (TransactionItem t) => Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.xs,
                                ),
                                child: PressableScale(
                                  onTap: () => _showTransactionDetail(t),
                                  semanticLabel: 'Detail transaksi ${t.label}',
                                  tooltip: 'Lihat detail',
                                  child: _historyRow(c, t),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryCard(
    AppColors c,
    IconData icon,
    String label,
    int value,
    Color color,
  ) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: AppSpacing.iconSmall, color: color),
          const SizedBox(height: AppSpacing.xs),
          Text(label, style: AppTypography.micro(c.textMuted)),
          const SizedBox(height: AppSpacing.xxs),
          Text(formatRupiah(value), style: AppTypography.title(color)),
        ],
      ),
    );
  }

  Widget _categoryCard(AppColors c, _CategorySlice slice) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(slice.label, style: AppTypography.label(c.text)),
                    Text(
                      formatRupiah(slice.amount),
                      style: AppTypography.label(slice.color)
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.huge),
                  child: LinearProgressIndicator(
                    value: slice.pct / 100,
                    minHeight: AppSpacing.progressThin,
                    backgroundColor: c.surfaceHigh,
                    valueColor: AlwaysStoppedAnimation<Color>(slice.color),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  '${slice.pct}% dari total pengeluaran',
                  style: AppTypography.micro(c.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Icon(
            Icons.chevron_right,
            size: AppSpacing.iconSmall,
            color: c.textMuted,
          ),
        ],
      ),
    );
  }

  Widget _historyRow(AppColors c, TransactionItem t) {
    final bool isExpense = t.amount < 0;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          Container(
            width: AppSpacing.iconBox,
            height: AppSpacing.iconBox,
            decoration: BoxDecoration(
              color: isExpense ? c.expenseDim : c.successDim,
              borderRadius: BorderRadius.circular(AppSpacing.sm),
            ),
            alignment: Alignment.center,
            child: Icon(
              transactionIcon(t),
              size: AppSpacing.iconSmall,
              color: isExpense ? c.expense : c.success,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.label(c.text),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  '${t.time} · ${_catLabel(t.cat)}',
                  style: AppTypography.caption(c.textMuted),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Text(
                '${isExpense ? '-' : '+'}${formatRupiah(t.amount.abs())}',
                style: AppTypography.label(isExpense ? c.expense : c.success)
                    .copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: AppSpacing.xxs),
              Icon(
                Icons.chevron_right,
                size: AppSpacing.sm,
                color: c.textMuted,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Transaction detail bottom sheet ──────────────────────────────────────────

class _TransactionDetailSheet extends StatefulWidget {
  final TransactionItem transaction;
  final void Function(TransactionItem updated) onEdit;
  final VoidCallback onDelete;

  const _TransactionDetailSheet({
    required this.transaction,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_TransactionDetailSheet> createState() =>
      _TransactionDetailSheetState();
}

class _TransactionDetailSheetState extends State<_TransactionDetailSheet> {
  late TextEditingController _labelCtrl;
  late TextEditingController _amountCtrl;
  late String _selectedCategory;
  String? _errorMessage;

  static const _expenseCats = [
    'Makan & Minum',
    'Hiburan',
    'Transport',
    'Belanja',
    'Lainnya',
  ];
  static const _incomeCats = ['Gaji', 'Kiriman', 'Freelance', 'Lainnya'];

  @override
  void initState() {
    super.initState();
    _labelCtrl = TextEditingController(text: widget.transaction.label);
    _amountCtrl = TextEditingController(
      text: widget.transaction.amount.abs().toString(),
    );
    _selectedCategory = _catLabel(widget.transaction.cat);
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  void _save(AppColors c) {
    if (_labelCtrl.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Deskripsi wajib diisi.');
      return;
    }
    final rawAmount = int.tryParse(
      _amountCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''),
    );
    if (rawAmount == null || rawAmount <= 0) {
      setState(() => _errorMessage = 'Nominal harus lebih dari Rp0.');
      return;
    }
    if (rawAmount > kMaxTransactionAmount) {
      setState(
        () => _errorMessage =
            'Nominal maksimal ${formatRupiah(kMaxTransactionAmount)}.',
      );
      return;
    }
    final isExpense = widget.transaction.amount < 0;
    final resolvedCat = isExpense
        ? _catKey(_selectedCategory)
        : (widget.transaction.cat == 'income'
              ? 'income'
              : _catKey(_selectedCategory));
    final updated = widget.transaction.copyWith(
      label: _labelCtrl.text.trim(),
      amount: isExpense ? -rawAmount : rawAmount,
      cat: resolvedCat,
    );
    HapticFeedback.lightImpact();
    widget.onEdit(updated);
    Navigator.of(context).pop();
  }

  Future<void> _confirmDelete(AppColors c) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.md),
          side: BorderSide(color: c.border),
        ),
        title: Text('Hapus transaksi?', style: AppTypography.title(c.text)),
        content: Text(
          'Transaksi "${widget.transaction.label}" akan dihapus dari riwayat.',
          style: AppTypography.body(c.textSub),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text('Batal', style: AppTypography.label(c.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text(
              'Hapus',
              style: AppTypography.label(c.expense)
                  .copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop();
      widget.onDelete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = ThemeScope.of(context).colors;
    final bool isExpense = widget.transaction.amount < 0;
    final List<String> cats = isExpense ? _expenseCats : _incomeCats;

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppSpacing.lg),
        ),
        border: Border.all(color: c.border),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xxl,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.md,
          0,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
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

            // Header — icon + label + amount
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: AppSpacing.iconBox,
                  height: AppSpacing.iconBox,
                  decoration: BoxDecoration(
                    color: isExpense ? c.expenseDim : c.successDim,
                    borderRadius: BorderRadius.circular(AppSpacing.sm),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    transactionIcon(widget.transaction),
                    size: AppSpacing.iconSmall,
                    color: isExpense ? c.expense : c.success,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.transaction.label,
                        style: AppTypography.title(c.text),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${widget.transaction.date} · ${widget.transaction.time}',
                        style: AppTypography.meta(c.textMuted),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${isExpense ? '-' : '+'}${formatRupiah(widget.transaction.amount.abs())}',
                  style: AppTypography.display(
                    isExpense ? c.expense : c.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Badges row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xxs,
                  ),
                  decoration: BoxDecoration(
                    color: c.surfaceHigh,
                    borderRadius: BorderRadius.circular(AppSpacing.huge),
                    border: Border.all(color: c.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.label_outline,
                        size: AppSpacing.sm,
                        color: c.textSub,
                      ),
                      const SizedBox(width: AppSpacing.xxs),
                      Text(
                        _catLabel(widget.transaction.cat),
                        style: AppTypography.meta(c.textSub),
                      ),
                    ],
                  ),
                ),
                if (widget.transaction.consumtive) ...[
                  const SizedBox(width: AppSpacing.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xxs,
                    ),
                    decoration: BoxDecoration(
                      color: c.warningDim,
                      borderRadius: BorderRadius.circular(AppSpacing.huge),
                      border: Border.all(color: c.warning),
                    ),
                    child: Text(
                      'konsumtif',
                      style: AppTypography.micro(c.warning),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Editable fields ──────────────────────────────────────
            Text('Edit Deskripsi', style: AppTypography.overline(c.textMuted)),
            const SizedBox(height: AppSpacing.xs),
            TextField(
              controller: _labelCtrl,
              maxLength: 60,
              onChanged: (_) {
                if (_errorMessage != null) {
                  setState(() => _errorMessage = null);
                }
              },
              style: AppTypography.body(c.text),
              decoration: const InputDecoration(labelText: 'Deskripsi'),
            ),
            Text('Nominal', style: AppTypography.overline(c.textMuted)),
            const SizedBox(height: AppSpacing.xs),
            TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              onChanged: (_) {
                if (_errorMessage != null) {
                  setState(() => _errorMessage = null);
                }
              },
              style: AppTypography.body(c.text),
              decoration: InputDecoration(
                labelText: 'Nominal',
                prefixText: 'Rp ',
                prefixStyle: AppTypography.body(c.textMuted),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: AppSpacing.xs),
              AppErrorMessage(message: _errorMessage!),
            ],
            const SizedBox(height: AppSpacing.sm),
            Text('Kategori', style: AppTypography.overline(c.textMuted)),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: cats.map((cat) {
                final bool active = _selectedCategory == cat;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = cat),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: active
                          ? (isExpense ? c.expenseDim : c.successDim)
                          : c.surfaceHigh,
                      borderRadius: BorderRadius.circular(AppSpacing.huge),
                      border: Border.all(
                        color: active
                            ? (isExpense ? c.expense : c.success)
                            : c.border,
                      ),
                    ),
                    child: Text(
                      cat,
                      style:
                          AppTypography.label(
                            active
                                ? (isExpense ? c.expense : c.success)
                                : c.textSub,
                          ).copyWith(
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

            // ── Receipt section ──────────────────────────────────────
            Text('Foto Struk', style: AppTypography.overline(c.textMuted)),
            const SizedBox(height: AppSpacing.xs),
            Container(
              width: double.infinity,
              height: 120,
              decoration: BoxDecoration(
                color: c.surfaceHigh,
                borderRadius: BorderRadius.circular(AppSpacing.md),
                border: Border.all(color: c.border),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: AppSpacing.iconLarge,
                    color: c.textMuted,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    'Tidak ada foto struk',
                    style: AppTypography.caption(c.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // ── Action buttons ───────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: PressableScale(
                    onTap: () => _save(c),
                    semanticLabel: 'Simpan perubahan',
                    tooltip: 'Simpan',
                    child: Container(
                      constraints: const BoxConstraints(
                        minHeight: AppSpacing.target,
                      ),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: c.blue,
                        borderRadius: BorderRadius.circular(AppSpacing.sm),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_rounded,
                            size: AppSpacing.iconSmall,
                            color: c.onAccent,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            'Simpan',
                            style: AppTypography.button(c.onAccent),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: PressableScale(
                    onTap: () => _confirmDelete(c),
                    semanticLabel: 'Hapus transaksi',
                    tooltip: 'Hapus',
                    child: Container(
                      constraints: const BoxConstraints(
                        minHeight: AppSpacing.target,
                      ),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: c.expenseDim,
                        borderRadius: BorderRadius.circular(AppSpacing.sm),
                        border: Border.all(color: c.expense),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.delete_outline,
                            size: AppSpacing.iconSmall,
                            color: c.expense,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text('Hapus', style: AppTypography.button(c.expense)),
                        ],
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
