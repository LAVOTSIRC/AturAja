import 'package:flutter/material.dart';

import '../data/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/theme_scope.dart';
import '../utils/format.dart';
import '../utils/icons.dart';
import '../widgets/common.dart';
import '../widgets/quick_add_modal.dart';
import '../widgets/roasting_toast.dart';

class HomeScreen extends StatefulWidget {
  final ValueChanged<QuickAddMode> onAdd;
  final VoidCallback onScan;
  final VoidCallback onAddTask;

  const HomeScreen({
    super.key,
    required this.onAdd,
    required this.onScan,
    required this.onAddTask,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool showRoast = false;

  static const int balance = 856000;
  static const int spent = 143990;
  static const int budget = 1200000;

  void _showMessage(String message) {
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(message)));
  }

  List<_QuickActionData> get quickActions => [
    _QuickActionData(
      Icons.edit_note_outlined,
      'Catat',
      () => widget.onAdd(QuickAddMode.quick),
      isEmphasized: true,
    ),
    _QuickActionData(Icons.camera_alt_outlined, 'Scan Struk', widget.onScan),
    _QuickActionData(
      Icons.psychology_outlined,
      'Brain Dump',
      () => widget.onAdd(QuickAddMode.brain),
    ),
    _QuickActionData(Icons.add_task_outlined, 'Tambah Tugas', widget.onAddTask),
  ];

  void _showTransactionDetail(TransactionItem t) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TransactionDetailSheet(transaction: t),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = ThemeScope.of(context).colors;
    final int pct = ((spent / budget) * 100).round();
    final List<TransactionItem> recent = sampleTransactions.take(4).toList();

    return Container(
      color: c.bg,
      child: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: AppSpacing.screenBottom),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                                'Selamat pagi',
                                style: AppTypography.caption(c.textMuted),
                              ),
                              const SizedBox(height: AppSpacing.xxs),
                              Text(
                                'Zidan Ruriano',
                                style: AppTypography.title(c.text),
                              ),
                            ],
                          ),
                        ),
                        const ThemeToggleSwitch(),
                        const SizedBox(width: AppSpacing.xs),
                        CircleIconButton(
                          icon: Icons.notifications_none,
                          tooltip: 'Notifikasi',
                          semanticLabel: 'Buka notifikasi',
                          showDot: true,
                          onTap: () => setState(() => showRoast = true),
                        ),
                      ],
                    ),
                  ),
                  if (showRoast)
                    RoastingToast(
                      onClose: () => setState(() => showRoast = false),
                    ),
                  Container(
                    margin: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.xs,
                      AppSpacing.md,
                      0,
                    ),
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: c.surface,
                      border: Border.all(color: c.border),
                      borderRadius: BorderRadius.circular(AppSpacing.lg),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Saldo Tersisa',
                          style: AppTypography.meta(c.textSub),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: Text(
                            formatRupiah(balance),
                            style: AppTypography.hero(c.text),
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.account_balance_wallet_outlined,
                                  size: AppSpacing.iconSmall - 8,
                                  color: c.textSub,
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Text(
                                  'Pengeluaran bulan ini',
                                  style: AppTypography.meta(c.textSub),
                                ),
                              ],
                            ),
                            Text(
                              '$pct%',
                              style: AppTypography.meta(c.text)
                                  .copyWith(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppSpacing.huge),
                          child: LinearProgressIndicator(
                            value: pct / 100,
                            minHeight: AppSpacing.progressThin,
                            backgroundColor: c.surfaceHigh,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              pct > 70 ? c.expense : c.blue,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${formatRupiah(spent)} dipakai',
                              style: AppTypography.micro(c.textMuted),
                            ),
                            Text(
                              'Limit ${formatRupiah(budget)}',
                              style: AppTypography.micro(c.textMuted),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.sm,
                      AppSpacing.md,
                      0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionLabel('Aksi Cepat'),
                        Row(
                          children: [
                            for (int i = 0; i < quickActions.length; i++) ...[
                              if (i > 0) const SizedBox(width: AppSpacing.xs),
                              _quickAction(c, quickActions[i]),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.sm,
                      AppSpacing.md,
                      0,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: c.urgentBg,
                        borderRadius: BorderRadius.circular(AppSpacing.md),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.report_problem_outlined,
                            size: AppSpacing.iconSmall,
                            color: c.onAlert,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '2 tugas deadline hari ini',
                                  style: AppTypography.caption(c.onAlert)
                                      .copyWith(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: AppSpacing.xxs),
                                Text(
                                  'Laporan Algoritma · Quiz Kalkulus',
                                  style: AppTypography.meta(c.onAlert).copyWith(
                                    color: c.onAlert.withValues(alpha: 0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            size: AppSpacing.iconSmall,
                            color: c.onAlert,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.md,
                      AppSpacing.md,
                      0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const SectionLabel('Transaksi Hari Ini'),
                            SizedBox(
                              height: AppSpacing.target,
                              child: TextButton(
                                onPressed: () => _showMessage(
                                  'Riwayat lengkap akan segera tersedia.',
                                ),
                                style: TextButton.styleFrom(
                                  minimumSize: const Size(
                                    AppSpacing.target,
                                    AppSpacing.target,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.xs,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Lihat semua',
                                      style: AppTypography.caption(
                                        c.blue,
                                      ).copyWith(fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(width: AppSpacing.xxs),
                                    Icon(
                                      Icons.chevron_right,
                                      size: AppSpacing.iconSmall,
                                      color: c.blue,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (recent.isEmpty)
                          const AppEmptyState(
                            icon: Icons.receipt_long_outlined,
                            title: 'Belum ada transaksi',
                            message: 'Catat pengeluaran atau pemasukan pertamamu hari ini.',
                          )
                        else
                          Column(
                            children: recent
                                .map(
                                  (TransactionItem t) => Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: AppSpacing.xs,
                                    ),
                                    child: PressableScale(
                                      onTap: () => _showTransactionDetail(t),
                                      semanticLabel: 'Detail transaksi ${t.label}',
                                      tooltip: 'Lihat detail',
                                      child: _TransactionRow(t: t),
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
          ],
        ),
      ),
    );
  }

  Widget _quickAction(AppColors c, _QuickActionData action) {
    return Expanded(
      child: PressableScale(
        onTap: action.onTap,
        semanticLabel: action.label,
        tooltip: action.label,
        child: Container(
          constraints: const BoxConstraints(
            minHeight: AppSpacing.quickActionHeight,
          ),
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.sm,
            horizontal: AppSpacing.xxs,
          ),
          decoration: BoxDecoration(
            color: action.emphasized ? c.blue : c.surface,
            border: Border.all(color: action.emphasized ? c.blue : c.border),
            borderRadius: BorderRadius.circular(AppSpacing.sm),
            boxShadow: [
              BoxShadow(
                color: action.emphasized
                    ? c.blue.withValues(alpha: 0.24)
                    : c.blue.withValues(alpha: 0.08),
                blurRadius: AppSpacing.sm,
                spreadRadius: -4,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                action.icon,
                size: AppSpacing.iconSmall,
                color: action.emphasized ? c.onAccent : c.blue,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                action.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.label(
                  action.emphasized ? c.onAccent : c.textSub,
                ).copyWith(height: 1.2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionData {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool? _emphasized;

  bool get emphasized => _emphasized ?? false;

  const _QuickActionData(
    this.icon,
    this.label,
    this.onTap, {
    bool? isEmphasized,
  }) : _emphasized = isEmphasized;
}

class _TransactionRow extends StatelessWidget {
  final TransactionItem t;

  const _TransactionRow({required this.t});

  @override
  Widget build(BuildContext context) {
    final AppColors c = ThemeScope.of(context).colors;
    final bool isExpense = t.amount < 0;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.fabClearance,
        AppSpacing.sm,
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
                    Text(t.time, style: AppTypography.caption(c.textMuted)),
                    if (t.consumtive) ...[
                      const SizedBox(width: AppSpacing.xs),
                      Pill(
                        text: 'konsumtif',
                        color: c.warning,
                        background: c.warningDim,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Row(
            children: [
              Icon(
                isExpense ? Icons.arrow_downward : Icons.arrow_upward,
                size: AppSpacing.sm,
                color: isExpense ? c.expense : c.success,
              ),
              const SizedBox(width: AppSpacing.xxs),
              Text(
                '${isExpense ? '-' : '+'}${formatRupiah(t.amount)}',
                style: AppTypography.label(isExpense ? c.expense : c.success)
                    .copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: AppSpacing.xxs),
              Icon(Icons.chevron_right, size: AppSpacing.sm, color: c.textMuted),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Transaction detail bottom sheet ────────────────────────────────────────

class _TransactionDetailSheet extends StatelessWidget {
  final TransactionItem transaction;

  const _TransactionDetailSheet({required this.transaction});

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
            // Header
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
                  '${isExpense ? '-' : '+'}${formatRupiah(transaction.amount)}',
                  style: AppTypography.display(isExpense ? c.expense : c.success),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            // Category + consumtive badge
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
                    child: Text('konsumtif', style: AppTypography.micro(c.warning)),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            // Receipt section
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
            // Edit / Delete
            Row(
              children: [
                Expanded(
                  child: PressableScale(
                    onTap: () {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                        const SnackBar(content: Text('Fitur edit tersedia di tab Keuangan.')),
                      );
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
                    onTap: () => Navigator.of(context).pop(),
                    semanticLabel: 'Tutup',
                    tooltip: 'Tutup',
                    child: Container(
                      constraints: const BoxConstraints(minHeight: AppSpacing.target),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: c.surfaceHigh,
                        borderRadius: BorderRadius.circular(AppSpacing.sm),
                        border: Border.all(color: c.border),
                      ),
                      child: Text('Tutup', style: AppTypography.button(c.textSub)),
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
