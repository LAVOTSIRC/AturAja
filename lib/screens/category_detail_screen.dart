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

// ── Helpers (mirrored from finance_screen) ────────────────────────────────────

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
const int _kMaxAmount = 999999999;

// ── Screen ────────────────────────────────────────────────────────────────────

class CategoryDetailScreen extends StatefulWidget {
  final String categoryLabel;
  final Color categoryColor;
  final List<TransactionItem> transactions;
  final void Function(TransactionItem updated)? onTransactionUpdated;
  final void Function(int id)? onTransactionDeleted;
  final void Function(TransactionItem restored)? onTransactionRestored;

  const CategoryDetailScreen({
    super.key,
    required this.categoryLabel,
    required this.categoryColor,
    required this.transactions,
    this.onTransactionUpdated,
    this.onTransactionDeleted,
    this.onTransactionRestored,
  });

  @override
  State<CategoryDetailScreen> createState() => _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends State<CategoryDetailScreen> {
  late List<TransactionItem> _transactions;

  @override
  void initState() {
    super.initState();
    _transactions = List.from(widget.transactions);
  }

  void _showTransactionDetail(TransactionItem t) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TransactionDetailSheet(
        transaction: t,
        categoryColor: widget.categoryColor,
        onEdit: (updated) {
          setState(() {
            final idx = _transactions.indexWhere((x) => x.id == updated.id);
            if (idx != -1) _transactions[idx] = updated;
          });
          widget.onTransactionUpdated?.call(updated);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Perubahan pada "${updated.label}" disimpan'),
              duration: const Duration(seconds: 2),
            ),
          );
        },
        onDelete: () {
          final removedIndex =
              _transactions.indexWhere((x) => x.id == t.id);
          setState(() => _transactions.removeWhere((x) => x.id == t.id));
          widget.onTransactionDeleted?.call(t.id);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('"${t.label}" dihapus dari riwayat'),
              action: SnackBarAction(
                label: 'Urungkan',
                onPressed: () {
                  setState(() {
                    final insertIndex =
                        removedIndex.clamp(0, _transactions.length);
                    _transactions.insert(insertIndex, t);
                  });
                  widget.onTransactionRestored?.call(t);
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
    final int total =
        _transactions.fold(0, (sum, t) => sum + t.amount.abs());

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ───────────────────────────────────────────────
            Container(
              color: c.surface,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Row(
                children: [
                  // Back button
                  PressableScale(
                    onTap: () => Navigator.of(context).pop(),
                    semanticLabel: 'Kembali',
                    tooltip: 'Kembali',
                    child: Container(
                      width: AppSpacing.target,
                      height: AppSpacing.target,
                      decoration: BoxDecoration(
                        color: c.surfaceHigh,
                        border: Border.all(color: c.border),
                        borderRadius: BorderRadius.circular(AppSpacing.sm),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: AppSpacing.iconSmall,
                        color: c.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  // Category color dot
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: widget.categoryColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  // Title + subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.categoryLabel,
                          style: AppTypography.title(c.text),
                        ),
                        Text(
                          '${_transactions.length} transaksi · ${formatRupiah(total)}',
                          style: AppTypography.meta(c.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Divider
            Container(height: 1, color: c.border),

            // ── List ─────────────────────────────────────────────────
            Expanded(
              child: _transactions.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: AppEmptyState(
                          icon: Icons.receipt_long_outlined,
                          title: 'Tidak ada transaksi',
                          message:
                              'Belum ada transaksi di kategori ${widget.categoryLabel}.',
                          accent: widget.categoryColor,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.sm,
                        AppSpacing.md,
                        AppSpacing.xxl,
                      ),
                      itemCount: _transactions.length,
                      itemBuilder: (context, index) {
                        final t = _transactions[index];
                        return Padding(
                          padding:
                              const EdgeInsets.only(bottom: AppSpacing.xs),
                          child: PressableScale(
                            onTap: () => _showTransactionDetail(t),
                            semanticLabel: 'Detail transaksi ${t.label}',
                            tooltip: 'Lihat detail',
                            child: _TransactionRow(
                              t: t,
                              categoryColor: widget.categoryColor,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Transaction row ───────────────────────────────────────────────────────────

class _TransactionRow extends StatelessWidget {
  final TransactionItem t;
  final Color categoryColor;

  const _TransactionRow({required this.t, required this.categoryColor});

  @override
  Widget build(BuildContext context) {
    final AppColors c = ThemeScope.of(context).colors;
    final bool isExpense = t.amount < 0;
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          // Icon box
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
          // Label + meta
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
                Row(
                  children: [
                    Text(
                      '${t.date} · ${t.time}',
                      style: AppTypography.micro(c.textMuted),
                    ),
                    if (t.receiptImagePath != null) ...[
                      const SizedBox(width: AppSpacing.xs),
                      Icon(
                        Icons.receipt_outlined,
                        size: AppSpacing.sm,
                        color: c.blue,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Amount + chevron
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isExpense ? '-' : '+'}${formatRupiah(t.amount.abs())}',
                style:
                    AppTypography.label(isExpense ? c.expense : c.success)
                        .copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: AppSpacing.xxs),
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

// ── Detail bottom sheet ───────────────────────────────────────────────────────

class _TransactionDetailSheet extends StatefulWidget {
  final TransactionItem transaction;
  final Color categoryColor;
  final void Function(TransactionItem updated) onEdit;
  final VoidCallback onDelete;

  const _TransactionDetailSheet({
    required this.transaction,
    required this.categoryColor,
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
        text: widget.transaction.amount.abs().toString());
    _selectedCategory = _catLabel(widget.transaction.cat);
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (_labelCtrl.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Deskripsi wajib diisi.');
      return;
    }
    final rawAmount =
        int.tryParse(_amountCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''));
    if (rawAmount == null || rawAmount <= 0) {
      setState(() => _errorMessage = 'Nominal harus lebih dari Rp0.');
      return;
    }
    if (rawAmount > _kMaxAmount) {
      setState(() => _errorMessage =
          'Nominal maksimal ${formatRupiah(_kMaxAmount)}.');
      return;
    }
    final isExpense = widget.transaction.amount < 0;
    final resolvedCat = widget.transaction.cat == 'income'
        ? 'income'
        : _catKey(_selectedCategory);
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

            // Header
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
                      isExpense ? c.expense : c.success),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // Badges
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
                  decoration: BoxDecoration(
                    color: c.surfaceHigh,
                    borderRadius: BorderRadius.circular(AppSpacing.huge),
                    border: Border.all(color: c.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.label_outline,
                          size: AppSpacing.sm, color: c.textSub),
                      const SizedBox(width: AppSpacing.xxs),
                      Text(_catLabel(widget.transaction.cat),
                          style: AppTypography.meta(c.textSub)),
                    ],
                  ),
                ),
                if (widget.transaction.consumtive) ...[
                  const SizedBox(width: AppSpacing.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
                    decoration: BoxDecoration(
                      color: c.warningDim,
                      borderRadius: BorderRadius.circular(AppSpacing.huge),
                      border: Border.all(color: c.warning),
                    ),
                    child: Text('konsumtif',
                        style: AppTypography.micro(c.warning)),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Divider
            Container(height: 1, color: c.border),
            const SizedBox(height: AppSpacing.md),

            // Edit section title
            Text('Ubah Detail', style: AppTypography.overline(c.textMuted)),
            const SizedBox(height: AppSpacing.xs),

            // Description field
            TextField(
              controller: _labelCtrl,
              maxLength: 60,
              onChanged: (_) {
                if (_errorMessage != null) {
                  setState(() => _errorMessage = null);
                }
              },
              style: AppTypography.body(c.text),
              decoration: const InputDecoration(
                labelText: 'Deskripsi',
              ),
            ),

            // Amount field
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

            // Category chips
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
                        horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
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
                      style: AppTypography.label(
                        active
                            ? (isExpense ? c.expense : c.success)
                            : c.textSub,
                      ).copyWith(
                          fontWeight:
                              active ? FontWeight.w600 : FontWeight.w400),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.md),

            // Receipt section
            Text('Foto Struk', style: AppTypography.overline(c.textMuted)),
            const SizedBox(height: AppSpacing.xs),
            if (widget.transaction.receiptImagePath != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.md),
                child: Image.asset(
                  widget.transaction.receiptImagePath!,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (ctx2, obj, st) => _receiptPlaceholder(c),
                ),
              )
            else
              _receiptPlaceholder(c),
            const SizedBox(height: AppSpacing.lg),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: PressableScale(
                    onTap: _save,
                    semanticLabel: 'Simpan perubahan',
                    tooltip: 'Simpan',
                    child: Container(
                      constraints: const BoxConstraints(
                          minHeight: AppSpacing.target),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: c.blue,
                        borderRadius: BorderRadius.circular(AppSpacing.sm),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_rounded,
                              size: AppSpacing.iconSmall, color: c.onAccent),
                          const SizedBox(width: AppSpacing.xs),
                          Text('Simpan',
                              style: AppTypography.button(c.onAccent)),
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
                          minHeight: AppSpacing.target),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: c.expenseDim,
                        borderRadius: BorderRadius.circular(AppSpacing.sm),
                        border: Border.all(color: c.expense),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.delete_outline,
                              size: AppSpacing.iconSmall, color: c.expense),
                          const SizedBox(width: AppSpacing.xs),
                          Text('Hapus',
                              style: AppTypography.button(c.expense)),
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

  Widget _receiptPlaceholder(AppColors c) {
    return Container(
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
          Icon(Icons.receipt_long_outlined,
              size: AppSpacing.iconLarge, color: c.textMuted),
          const SizedBox(height: AppSpacing.xxs),
          Text('Tidak ada foto struk',
              style: AppTypography.caption(c.textMuted)),
        ],
      ),
    );
  }
}
