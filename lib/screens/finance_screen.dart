import 'package:flutter/material.dart';

import '../data/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/theme_scope.dart';
import '../utils/format.dart';
import '../utils/icons.dart';
import '../widgets/common.dart';

class _CategorySlice {
  final String label;
  final int pct;
  final Color color;
  final int amount;

  const _CategorySlice(this.label, this.pct, this.color, this.amount);
}

class FinanceScreen extends StatelessWidget {
  const FinanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppColors c = ThemeScope.of(context).colors;
    final List<_CategorySlice> cats = [
      _CategorySlice('Makan & Minum', 45, c.blue, 145000),
      _CategorySlice('Hiburan', 25, c.expense, 83990),
      _CategorySlice('Transport', 20, c.warning, 65000),
      _CategorySlice('Lainnya', 10, c.success, 32000),
    ];

    return Container(
      color: c.bg,
      child: SafeArea(
        child: SingleChildScrollView(
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
                        500000,
                        c.success,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: _summaryCard(
                        c,
                        Icons.call_made_outlined,
                        'Pengeluaran',
                        325990,
                        c.expense,
                      ),
                    ),
                  ],
                ),
              ),
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
                                      style: AppTypography.micro(
                                        c.text,
                                      ).copyWith(fontWeight: FontWeight.w700),
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
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.xs,
                              ),
                              child: _categoryCard(c, slice),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionLabel('Riwayat Transaksi'),
                    if (sampleTransactions.isEmpty)
                      const AppEmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: 'Belum ada transaksi',
                        message: 'Riwayat pengeluaran dan pemasukan akan muncul di sini.',
                      )
                    else
                      Column(
                        children: sampleTransactions
                            .map(
                              (TransactionItem t) => Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.xs,
                                ),
                                child: _historyRow(c, t),
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
          Text(
            '${isExpense ? '-' : '+'}${formatRupiah(t.amount)}',
            style: AppTypography.label(isExpense ? c.expense : c.success)
                .copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
