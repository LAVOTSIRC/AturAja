import 'package:flutter/material.dart';
import '../data/models.dart';
import '../theme/theme_scope.dart';
import '../utils/format.dart';
import '../utils/icons.dart';
import '../widgets/common.dart';
import '../widgets/roasting_toast.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onAdd;
  final VoidCallback onScan;

  const HomeScreen({super.key, required this.onAdd, required this.onScan});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool showRoast = false;

  static const int balance = 856000;
  static const int spent = 143990;
  static const int budget = 1200000;

  late final quickActions = [
    _QuickActionData(Icons.edit_note_outlined, 'Catat', widget.onAdd),
    _QuickActionData(Icons.camera_alt_outlined, 'Scan Struk', widget.onScan),
    _QuickActionData(Icons.psychology_outlined, 'Brain Dump', widget.onAdd),
    _QuickActionData(Icons.bar_chart_outlined, 'Anggaran', () {}),
  ];

  @override
  Widget build(BuildContext context) {
    final c = ThemeScope.of(context).colors;
    final pct = ((spent / budget) * 100).round();
    final recent = sampleTransactions.take(4).toList();

    return Container(
      color: c.bg,
      child: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Selamat pagi', style: TextStyle(fontSize: 11, color: c.textMuted)),
                              const SizedBox(height: 2),
                              Text('Zidan Ruriano',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.text)),
                            ],
                          ),
                        ),
                        const ThemeToggleSwitch(),
                        const SizedBox(width: 8),
                        CircleIconButton(
                          icon: Icons.notifications_none,
                          showDot: true,
                          onTap: () => setState(() => showRoast = true),
                        ),
                      ],
                    ),
                  ),
                  if (showRoast) RoastingToast(onClose: () => setState(() => showRoast = false)),
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: c.surface,
                      border: Border.all(color: c.border),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Saldo Tersisa', style: TextStyle(fontSize: 11, color: c.textSub)),
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(formatRupiah(balance),
                              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: c.text, letterSpacing: -0.5)),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.account_balance_wallet_outlined, size: 13, color: c.textSub),
                                const SizedBox(width: 6),
                                Text('Pengeluaran bulan ini', style: TextStyle(fontSize: 11, color: c.textSub)),
                              ],
                            ),
                            Text('$pct%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.text)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(
                            value: pct / 100,
                            minHeight: 3,
                            backgroundColor: c.surfaceHigh,
                            valueColor: AlwaysStoppedAnimation(pct > 70 ? c.red : Colors.white),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${formatRupiah(spent)} dipakai', style: TextStyle(fontSize: 10, color: c.textMuted)),
                            Text('Limit ${formatRupiah(budget)}', style: TextStyle(fontSize: 10, color: c.textMuted)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionLabel('Aksi Cepat'),
                        Row(
                          children: [
                            for (var i = 0; i < quickActions.length; i++) ...[
                              if (i > 0) const SizedBox(width: 8),
                              _quickAction(c, quickActions[i]),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: c.urgentBg,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.report_problem_outlined, size: 18, color: Colors.white),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('2 tugas deadline hari ini',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                                SizedBox(height: 2),
                                Text('Laporan Algoritma · Quiz Kalkulus',
                                    style: TextStyle(fontSize: 11, color: Color(0xE6FFFFFF))),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, size: 18, color: Colors.white),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const SectionLabel('Transaksi Hari Ini'),
                            TextButton(
                              onPressed: () {},
                              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                              child: Text('Lihat semua', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.blue)),
                            ),
                          ],
                        ),
                        Column(
                          children: recent
                              .map((t) => Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: _TransactionRow(t: t),
                                  ))
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

  Widget _quickAction(dynamic c, _QuickActionData action) {
    return Expanded(
      child: GestureDetector(
        onTap: action.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
          decoration: BoxDecoration(
            color: c.surface,
            border: Border.all(color: c.border),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: c.blue.withValues(alpha: 0.08), blurRadius: 10, spreadRadius: -4)],
          ),
          child: Column(
            children: [
              Icon(action.icon, size: 20, color: c.blue),
              const SizedBox(height: 8),
              Text(action.label, textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: c.textSub, height: 1.2)),
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
  const _QuickActionData(this.icon, this.label, this.onTap);
}

class _TransactionRow extends StatelessWidget {
  final TransactionItem t;
  const _TransactionRow({required this.t});

  @override
  Widget build(BuildContext context) {
    final c = ThemeScope.of(context).colors;
    final isExpense = t.amount < 0;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isExpense ? c.redDim : c.tealDim,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(transactionIcon(t), size: 18, color: isExpense ? c.red : c.teal),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: c.text)),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(t.time, style: TextStyle(fontSize: 10, color: c.textMuted)),
                    if (t.consumtive) ...[
                      const SizedBox(width: 6),
                      Pill(text: 'konsumtif', color: c.amber, background: c.amberDim),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Row(
            children: [
              Icon(isExpense ? Icons.arrow_downward : Icons.arrow_upward, size: 12, color: isExpense ? c.red : c.teal),
              const SizedBox(width: 2),
              Text(
                '${isExpense ? '-' : '+'}${formatRupiah(t.amount)}',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isExpense ? c.red : c.teal),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
