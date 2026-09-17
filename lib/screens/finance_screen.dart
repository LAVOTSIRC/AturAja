import 'package:flutter/material.dart';
import '../data/models.dart';
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
    final c = ThemeScope.of(context).colors;
    final cats = [
      _CategorySlice('Makan & Minum', 45, c.blue, 145000),
      _CategorySlice('Hiburan', 25, c.red, 83990),
      _CategorySlice('Transport', 20, c.amber, 65000),
      _CategorySlice('Lainnya', 10, c.teal, 32000),
    ];

    return Container(
      color: c.bg,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Keuangan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: c.text)),
                          const SizedBox(height: 2),
                          Text('Ringkasan September 2026', style: TextStyle(fontSize: 11, color: c.textMuted)),
                        ],
                      ),
                    ),
                    const ThemeToggleSwitch(),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  children: [
                    Expanded(child: _summaryCard(c, Icons.call_received_outlined, 'Pemasukan', 500000, c.teal)),
                    const SizedBox(width: 8),
                    Expanded(child: _summaryCard(c, Icons.call_made_outlined, 'Pengeluaran', 325990, c.red)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionLabel('Indikator Anggaran'),
                    AppCard(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Anggaran Bulan Ini', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: c.text)),
                              Text('Rp1.200.000', style: TextStyle(fontSize: 12, color: c.blue, fontWeight: FontWeight.w600)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: SizedBox(
                              height: 8,
                              child: Row(
                                children: cats
                                    .map((slice) => Expanded(
                                          flex: slice.pct,
                                          child: Container(
                                            margin: const EdgeInsets.symmetric(horizontal: 1),
                                            color: slice.color,
                                          ),
                                        ))
                                    .toList(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text.rich(
                                TextSpan(
                                  style: TextStyle(fontSize: 10, color: c.textMuted),
                                  children: [
                                    const TextSpan(text: 'Terpakai: '),
                                    TextSpan(text: 'Rp325.990', style: TextStyle(color: c.text, fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              ),
                              Text('Sisa Rp874.010', style: TextStyle(fontSize: 10, color: c.teal)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionLabel('Breakdown Kategori'),
                    Column(
                      children: cats
                          .map((slice) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: _categoryCard(c, slice),
                              ))
                          .toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionLabel('Riwayat Transaksi'),
                    Column(
                      children: sampleTransactions
                          .map((t) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: _historyRow(c, t),
                              ))
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

  Widget _summaryCard(dynamic c, IconData icon, String label, int value, Color color) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 10, color: c.textMuted)),
          const SizedBox(height: 4),
          Text(formatRupiah(value), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }

  Widget _categoryCard(dynamic c, _CategorySlice slice) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(slice.label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: c.text)),
              Text(formatRupiah(slice.amount), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: slice.color)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: slice.pct / 100,
              minHeight: 3,
              backgroundColor: c.surfaceHigh,
              valueColor: AlwaysStoppedAnimation(slice.color),
            ),
          ),
          const SizedBox(height: 5),
          Text('${slice.pct}% dari total pengeluaran', style: TextStyle(fontSize: 10, color: c.textMuted)),
        ],
      ),
    );
  }

  Widget _historyRow(dynamic c, TransactionItem t) {
    final isExpense = t.amount < 0;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isExpense ? c.redDim : c.tealDim,
              borderRadius: BorderRadius.circular(11),
            ),
            alignment: Alignment.center,
            child: Icon(transactionIcon(t), size: 16, color: isExpense ? c.red : c.teal),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: c.text)),
                const SizedBox(height: 2),
                Text('${t.time} · ${t.cat}', style: TextStyle(fontSize: 10, color: c.textMuted)),
              ],
            ),
          ),
          Text(
            '${isExpense ? '-' : '+'}${formatRupiah(t.amount)}',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isExpense ? c.red : c.teal),
          ),
        ],
      ),
    );
  }
}
