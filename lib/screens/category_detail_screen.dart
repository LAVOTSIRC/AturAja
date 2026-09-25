import 'package:flutter/material.dart';

import '../data/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/theme_scope.dart';
import '../utils/format.dart';
import '../utils/icons.dart';
import '../widgets/common.dart';

class CategoryDetailScreen extends StatefulWidget {
  final String categoryLabel;
  final Color categoryColor;
  final List<TransactionItem> transactions;

  const CategoryDetailScreen({
    super.key,
    required this.categoryLabel,
    required this.categoryColor,
    required this.transactions,
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
        onEdit: (updated) {
          setState(() {
            final idx = _transactions.indexWhere((x) => x.id == updated.id);
            if (idx != -1) _transactions[idx] = updated;
          });
        },
        onDelete: () {
          setState(() {
            _transactions.removeWhere((x) => x.id == t.id);
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = ThemeScope.of(context).colors;
    final int total = _transactions.fold(0, (sum, t) => sum + t.amount.abs());

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  PressableScale(
                    onTap: () => Navigator.of(context).pop(),
                    semanticLabel: 'Kembali',
                    tooltip: 'Kembali',
                    child: Container(
                      width: AppSpacing.target,
                      height: AppSpacing.target,
                      decoration: BoxDecoration(
                        color: c.surface,
                        border: Border.all(color: c.border),
                        borderRadius: BorderRadius.circular(AppSpacing.sm),
                      ),
                      child: Icon(
                        Icons.arrow_back,
                        size: AppSpacing.iconSmall,
                        color: c.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
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
                  Container(
                    width: AppSpacing.sm,
                    height: AppSpacing.sm,
                    decoration: BoxDecoration(
                      color: widget.categoryColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _transactions.isEmpty
                  ? const AppEmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: 'Tidak ada transaksi',
                      message: 'Tidak ada transaksi dalam kategori ini.',
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
                          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                          child: _CategoryTransactionRow(
                            t: t,
                            categoryColor: widget.categoryColor,
                            onTap: () => _showTransactionDetail(t),
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

class _CategoryTransactionRow extends StatelessWidget {
  final TransactionItem t;
  final Color categoryColor;
  final VoidCallback onTap;

  const _CategoryTransactionRow({
    required this.t,
    required this.categoryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final AppColors c = ThemeScope.of(context).colors;
    final bool isExpense = t.amount < 0;
    return PressableScale(
      onTap: onTap,
      semanticLabel: 'Detail transaksi ${t.label}',
      tooltip: 'Lihat detail',
      child: AppCard(
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isExpense ? '-' : '+'}${formatRupiah(t.amount)}',
                  style: AppTypography.label(isExpense ? c.expense : c.success)
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
      ),
    );
  }
}

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
            // Title + amount
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
                      Text(
                        transaction.label,
                        style: AppTypography.title(c.text),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        '${transaction.date} · ${transaction.time}',
                        style: AppTypography.meta(c.textMuted),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${isExpense ? '-' : '+'}${formatRupiah(transaction.amount)}',
                  style: AppTypography.display(isExpense ? c.expense : c.success),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            // Category chip
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
                      Icon(Icons.label_outline, size: AppSpacing.sm, color: c.textSub),
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
            // Receipt image section
            Text('Foto Struk', style: AppTypography.overline(c.textMuted)),
            const SizedBox(height: AppSpacing.xs),
            if (transaction.receiptImagePath != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.md),
                child: Image.asset(
                  transaction.receiptImagePath!,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (ctx2, obj, st) => _receiptPlaceholder(c, hasImage: true),
                ),
              )
            else
              _receiptPlaceholder(c, hasImage: false),
            const SizedBox(height: AppSpacing.lg),
            // Action buttons
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
                      constraints: const BoxConstraints(minHeight: AppSpacing.target),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: c.blue,
                        borderRadius: BorderRadius.circular(AppSpacing.sm),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit_outlined, size: AppSpacing.iconSmall, color: c.onAccent),
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
                      constraints: const BoxConstraints(minHeight: AppSpacing.target),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: c.expenseDim,
                        borderRadius: BorderRadius.circular(AppSpacing.sm),
                        border: Border.all(color: c.expense),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.delete_outline, size: AppSpacing.iconSmall, color: c.expense),
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

  Widget _receiptPlaceholder(AppColors c, {required bool hasImage}) {
    return Container(
      width: double.infinity,
      height: 140,
      decoration: BoxDecoration(
        color: c.surfaceHigh,
        borderRadius: BorderRadius.circular(AppSpacing.md),
        border: Border.all(color: c.border, style: BorderStyle.solid),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasImage ? Icons.broken_image_outlined : Icons.receipt_long_outlined,
            size: AppSpacing.iconLarge,
            color: c.textMuted,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            hasImage ? 'Foto struk tidak dapat ditampilkan' : 'Tidak ada foto struk',
            style: AppTypography.caption(c.textMuted),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, AppColors c) {
    final labelCtrl = TextEditingController(text: transaction.label);
    final amountCtrl = TextEditingController(text: transaction.amount.abs().toString());

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
              decoration: InputDecoration(labelText: 'Deskripsi'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              style: AppTypography.body(c.text),
              decoration: InputDecoration(labelText: 'Nominal'),
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
              final newAmount = int.tryParse(amountCtrl.text) ?? transaction.amount.abs();
              final updated = transaction.copyWith(
                label: labelCtrl.text.trim().isEmpty ? transaction.label : labelCtrl.text.trim(),
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
