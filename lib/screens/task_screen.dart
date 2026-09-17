import 'package:flutter/material.dart';
import '../data/models.dart';
import '../theme/theme_scope.dart';
import '../widgets/common.dart';

class TaskScreen extends StatefulWidget {
  const TaskScreen({super.key});

  @override
  State<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen> {
  late List<TaskItem> list = List.of(sampleTasks);

  void _toggle(int id) {
    setState(() {
      list = list.map((t) => t.id == id ? t.copyWith(done: !t.done) : t).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = ThemeScope.of(context).colors;
    final pending = list.where((t) => !t.done).toList();
    final done = list.where((t) => t.done).toList();
    final pct = ((done.length / list.length) * 100).round();

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
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Tugas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: c.text)),
                          const SizedBox(height: 2),
                          Text('${pending.length} belum selesai', style: TextStyle(fontSize: 11, color: c.textMuted)),
                        ],
                      ),
                    ),
                    const ThemeToggleSwitch(),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {},
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(color: c.blue, borderRadius: BorderRadius.circular(10)),
                        child: const Text('+ Tambah', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600, fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                child: AppCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Progress Minggu Ini', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: c.text)),
                          Text('${done.length}/${list.length} selesai', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.blue)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: pct / 100,
                          minHeight: 5,
                          backgroundColor: c.surfaceHigh,
                          valueColor: AlwaysStoppedAnimation(c.blue),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text('$pct% — ${pct < 50 ? "Ayo semangat!" : "Luar biasa, terus!"}',
                          style: TextStyle(fontSize: 10, color: c.textMuted)),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionLabel('Belum Selesai'),
                    Column(
                      children: pending
                          .map((t) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: _pendingTile(c, t),
                              ))
                          .toList(),
                    ),
                  ],
                ),
              ),
              if (done.isNotEmpty) ...[
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionLabel('Selesai'),
                      Column(
                        children: done
                            .map((t) => Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: _doneTile(c, t),
                                ))
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _pendingTile(dynamic c, TaskItem t) {
    return GestureDetector(
      onTap: () => _toggle(t.id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: t.urgent ? c.redDim : c.surface,
          border: Border.all(color: t.urgent ? c.red.withValues(alpha: 0.35) : c.border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 18,
              height: 18,
              margin: const EdgeInsets.only(top: 1),
              decoration: BoxDecoration(
                border: Border.all(color: t.urgent ? c.red : c.textMuted, width: 1.5),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: c.text)),
                  const SizedBox(height: 3),
                  Text(t.sub, style: TextStyle(fontSize: 11, color: c.textMuted)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 11, color: t.urgent ? c.red : c.textMuted),
                      const SizedBox(width: 6),
                      Text(t.deadline,
                          style: TextStyle(fontSize: 10, color: t.urgent ? c.red : c.textMuted, fontWeight: t.urgent ? FontWeight.w600 : FontWeight.w400)),
                      if (t.urgent) ...[
                        const SizedBox(width: 6),
                        Pill(text: 'Mendesak', color: c.red, background: c.redDim),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _doneTile(dynamic c, TaskItem t) {
    return GestureDetector(
      onTap: () => _toggle(t.id),
      child: Opacity(
        opacity: 0.45,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: c.surface,
            border: Border.all(color: c.border),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(color: c.teal, borderRadius: BorderRadius.circular(6)),
                child: const Icon(Icons.check, size: 11, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.title,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: c.textSub, decoration: TextDecoration.lineThrough)),
                    const SizedBox(height: 2),
                    Text(t.sub, style: TextStyle(fontSize: 11, color: c.textMuted)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
