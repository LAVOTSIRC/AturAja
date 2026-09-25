import 'package:flutter/material.dart';

import '../data/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/theme_scope.dart';
import '../utils/format.dart';
import '../utils/icons.dart';
import '../widgets/common.dart';
import 'category_detail_screen.dart';

class _CategorySlice {
  final String label;
  final int pct;
  final Color color;
  final int amount;
  final String catKey; // filter key

  const _CategorySlice(this.label, this.pct, this.color, this.amount, this.catKey);
}

class FinanceScreen extends StatefulWidget {
  final VoidCallback onScan;

  const FinanceScreen({super.key, required this.onScan});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  late List<TransactionItem> _transactions;

  @override
  void initState() {
    super.initState();
    _transactions = List.from(sampleTransactions);
  }

  List<TransactionItem> _transactionsForCategory(String catKey) {
    if (catKey == 'other') {
      return _transactions
          .where((t) =>
              t.cat != 'food' &&
              t.cat != 'entertainment' &&
              t.cat != 'transport' &&
              t.cat != 'income')
          .toList();
    }
    return _transactions.where((t) => t.cat == catKey).toList();
  }

  void _showAddIncomeModal() {
    _showAddTransactionModal(isIncome: true);
  }

  void _showAddExpenseModal() {
    _showAddTransactionModal(isIncome: false);
  }

  void _showAddTransactionModal({required bool isIncome}) {
    final AppColors c = ThemeScope.of(context).colors;
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    const incomeCategories = ['Gaji', 'Kiriman', 'Freelance', 'Lainnya'];
    const expenseCategories = ['Makan & Minum', 'Hiburan', 'Transport', 'Belanja', 'Lainnya'];
    final categories = isIncome ? incomeCategories : expenseCategories;
    String selectedCategory = categories.first;

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
                      Row(
                        children: [
                          Container(
                            width: AppSpacing.iconBox,
                            height: AppSpacing.iconBox,
                            decoration: BoxDecoration(
                              color: isIncome ? c.successDim : c.expenseDim,
                              borderRadius: BorderRadius.circular(AppSpacing.sm),
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
                            isIncome ? 'Tambah Pemasukan' : 'Tambah Pengeluaran',
                            style: AppTypography.title(c.text),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text('Nominal', style: AppTypography.meta(c.textMuted)),
                      const SizedBox(height: AppSpacing.xs),
                      TextField(
                        controller: amountCtrl,
                        autofocus: true,
                        keyboardType: TextInputType.number,
                        style: AppTypography.display(c.text),
                        decoration: InputDecoration(
                          hintText: '0',
                          prefixText: 'Rp ',
                          prefixStyle: AppTypography.display(c.textMuted),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text('Kategori', style: AppTypography.meta(c.textMuted)),
                      const SizedBox(height: AppSpacing.xs),
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: categories.map((cat) {
                          final bool active = selectedCategory == cat;
                          return GestureDetector(
                            onTap: () => setModalState(() => selectedCategory = cat),
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
                                borderRadius: BorderRadius.circular(AppSpacing.huge),
                                border: Border.all(
                                  color: active
                                      ? (isIncome ? c.success : c.expense)
                                      : c.border,
                                ),
                              ),
                              child: Text(
                                cat,
                                style: AppTypography.label(
                                  active
                                      ? (isIncome ? c.success : c.expense)
                                      : c.textSub,
                                ).copyWith(
                                  fontWeight:
                                      active ? FontWeight.w600 : FontWeight.w400,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Deskripsi (opsional)',
                        style: AppTypography.meta(c.textMuted),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      TextField(
                        controller: descCtrl,
                        style: AppTypography.body(c.text),
                        decoration: const InputDecoration(
                          hintText: 'Contoh: Makan siang di warteg',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      SizedBox(
                        width: double.infinity,
                        child: PressableScale(
                          onTap: () {
                            final rawAmount = int.tryParse(
                              amountCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''),
                            );
                            if (rawAmount == null || rawAmount <= 0) return;
                            final newId = DateTime.now().millisecondsSinceEpoch;
                            final catKey = isIncome
                                ? 'income'
                                : (selectedCategory == 'Makan & Minum'
                                    ? 'food'
                                    : selectedCategory == 'Hiburan'
                                        ? 'entertainment'
                                        : selectedCategory == 'Transport'
                                            ? 'transport'
                                            : 'other');
                            final newTransaction = TransactionItem(
                              id: newId,
                              label: descCtrl.text.trim().isEmpty
                                  ? selectedCategory
                                  : descCtrl.text.trim(),
                              amount: isIncome ? rawAmount : -rawAmount,
                              cat: catKey,
                              time: TimeOfDay.now().format(ctx),
                              date: 'Hari ini',
                            );
                            setState(() {
                              _transactions.insert(0, newTransaction);
                            });
                            Navigator.of(ctx).pop();
                          },
                          semanticLabel:
                              isIncome ? 'Simpan pemasukan' : 'Simpan pengeluaran',
                          tooltip: 'Simpan',
                          child: Container(
                            constraints:
                                const BoxConstraints(minHeight: AppSpacing.target),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isIncome ? c.success : c.expense,
                              borderRadius: BorderRadius.circular(AppSpacing.sm),
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
                          child: Text('Batal', style: AppTypography.label(c.textMuted)),
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
        },
        onDelete: () {
          setState(() => _transactions.removeWhere((x) => x.id == t.id));
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

    return Container(
      color: c.bg,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: AppSpacing.screenBottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ───────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.xs,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                    const ThemeToggleSwitch(),
                  ],
                ),
              ),
              // ── Action buttons ────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.xs,
                  AppSpacing.md,
                  AppSpacing.xs,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: PressableScale(
                        onTap: _showAddIncomeModal,
                        semanticLabel: 'Tambah pemasukan',
                        tooltip: 'Tambah pemasukan',
                        child: Container(
                          constraints:
                              const BoxConstraints(minHeight: AppSpacing.target),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: c.successDim,
                            borderRadius: BorderRadius.circular(AppSpacing.sm),
                            border: Border.all(color: c.success),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.add,
                                size: AppSpacing.iconSmall,
                                color: c.success,
                              ),
                              const SizedBox(width: AppSpacing.xxs),
                              Text(
                                'Pemasukan',
                                style: AppTypography.label(c.success)
                                    .copyWith(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: PressableScale(
                        onTap: _showAddExpenseModal,
                        semanticLabel: 'Tambah pengeluaran',
                        tooltip: 'Tambah pengeluaran',
                        child: Container(
                          constraints:
                              const BoxConstraints(minHeight: AppSpacing.target),
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
                                Icons.remove,
                                size: AppSpacing.iconSmall,
                                color: c.expense,
                              ),
                              const SizedBox(width: AppSpacing.xxs),
                              Text(
                                'Pengeluaran',
                                style: AppTypography.label(c.expense)
                                    .copyWith(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    PressableScale(
                      onTap: widget.onScan,
                      semanticLabel: 'Scan struk',
                      tooltip: 'Scan struk',
                      child: Container(
                        width: AppSpacing.target,
                        height: AppSpacing.target,
                        decoration: BoxDecoration(
                          color: c.blueDim,
                          borderRadius: BorderRadius.circular(AppSpacing.sm),
                          border: Border.all(color: c.blue),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.document_scanner_outlined,
                          size: AppSpacing.iconSmall,
                          color: c.blue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // ── Summary cards ─────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.xs,
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
              // ── Budget indicator ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Anggaran Bulan Ini',
                                style: AppTypography.label(c.text),
                              ),
                              Text(
                                'Rp1.200.000',
                                style: AppTypography.caption(c.blue)
                                    .copyWith(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(AppSpacing.huge),
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text.rich(
                                TextSpan(
                                  style: AppTypography.micro(c.textMuted),
                                  children: [
                                    const TextSpan(text: 'Terpakai: '),
                                    TextSpan(
                                      text: 'Rp325.990',
                                      style: AppTypography.micro(c.text)
                                          .copyWith(fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                'Sisa Rp874.010',
                                style: AppTypography.micro(c.success),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              // ── Category breakdown ────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionLabel('Breakdown Kategori'),
                    Column(
                      children: cats
                          .map(
                            (_CategorySlice slice) => Padding(
                              padding:
                                  const EdgeInsets.only(bottom: AppSpacing.xs),
                              child: PressableScale(
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => CategoryDetailScreen(
                                        categoryLabel: slice.label,
                                        categoryColor: slice.color,
                                        transactions:
                                            _transactionsForCategory(slice.catKey),
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
              const SizedBox(height: AppSpacing.md),
              // ── Transaction history ───────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionLabel('Riwayat Transaksi'),
                    if (_transactions.isEmpty)
                      const AppEmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: 'Belum ada transaksi',
                        message:
                            'Riwayat pengeluaran dan pemasukan akan muncul di sini.',
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
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
                  '${t.time} · ${t.cat}',
                  style: AppTypography.micro(c.textMuted),
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

// ── Transaction detail bottom sheet (for history rows) ────────────────────────

class _TransactionDetailSheet extends StatelessWidget {
  final TransactionItem transaction;
  final void Function(TransactionItem updated) onEdit;
  final VoidCallback onDelete;

  const _TransactionDetailSheet({
    required this.transaction,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final AppColors c = ThemeScope.of(context).colors;
    final bool isExpense = transaction.amount < 0;

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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                    transactionIcon(transaction),
                    size: AppSpacing.iconSmall,
                    color: isExpense ? c.expense : c.success,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(transaction.label, style: AppTypography.title(c.text)),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        '${transaction.date} · ${transaction.time}',
                        style: AppTypography.meta(c.textMuted),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${isExpense ? '-' : '+'}${formatRupiah(transaction.amount.abs())}',
                  style: AppTypography.display(isExpense ? c.expense : c.success),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
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
                      Text(transaction.cat, style: AppTypography.meta(c.textSub)),
                    ],
                  ),
                ),
                if (transaction.consumtive) ...[
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
            Text('Foto Struk', style: AppTypography.overline(c.textMuted)),
            const SizedBox(height: AppSpacing.xs),
            Container(
              width: double.infinity,
              height: 140,
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
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Tidak ada foto struk',
                    style: AppTypography.caption(c.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: PressableScale(
                    onTap: () {
                      Navigator.of(context).pop();
                      _showEditDialog(context, c);
                    },
                    semanticLabel: 'Edit transaksi',
                    tooltip: 'Edit',
                    child: Container(
                      constraints:
                          const BoxConstraints(minHeight: AppSpacing.target),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: c.blue,
                        borderRadius: BorderRadius.circular(AppSpacing.sm),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.edit_outlined,
                            size: AppSpacing.iconSmall,
                            color: c.onAccent,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text('Edit', style: AppTypography.button(c.onAccent)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: PressableScale(
                    onTap: () {
                      Navigator.of(context).pop();
                      onDelete();
                    },
                    semanticLabel: 'Hapus transaksi',
                    tooltip: 'Hapus',
                    child: Container(
                      constraints:
                          const BoxConstraints(minHeight: AppSpacing.target),
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

  void _showEditDialog(BuildContext context, AppColors c) {
    final labelCtrl = TextEditingController(text: transaction.label);
    final amountCtrl =
        TextEditingController(text: transaction.amount.abs().toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.md),
          side: BorderSide(color: c.border),
        ),
        title: Text('Edit Transaksi', style: AppTypography.title(c.text)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labelCtrl,
              style: AppTypography.body(c.text),
              decoration: const InputDecoration(labelText: 'Deskripsi'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              style: AppTypography.body(c.text),
              decoration: const InputDecoration(labelText: 'Nominal'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Batal', style: AppTypography.label(c.textMuted)),
          ),
          TextButton(
            onPressed: () {
              final newAmount =
                  int.tryParse(amountCtrl.text) ?? transaction.amount.abs();
              final updated = transaction.copyWith(
                label: labelCtrl.text.trim().isEmpty
                    ? transaction.label
                    : labelCtrl.text.trim(),
                amount: transaction.amount < 0 ? -newAmount : newAmount,
              );
              onEdit(updated);
              Navigator.of(ctx).pop();
            },
            child: Text('Simpan', style: AppTypography.label(c.blue)),
          ),
        ],
      ),
    );
  }
}
