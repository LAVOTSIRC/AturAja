import 'package:flutter/material.dart';

import '../data/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/theme_scope.dart';
import '../widgets/common.dart';

class TaskScreen extends StatefulWidget {
  const TaskScreen({super.key});

  @override
  State<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen> {
  late List<TaskItem> list = List.of(sampleTasks);

  void _showMessage(String message) {
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(message)));
  }

  void _toggle(int id) {
    setState(() {
      list = list
          .map((TaskItem t) => t.id == id ? t.copyWith(done: !t.done) : t)
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = ThemeScope.of(context).colors;
    final List<TaskItem> pending = list.where((TaskItem t) => !t.done).toList();
    final List<TaskItem> done = list.where((TaskItem t) => t.done).toList();
    final int pct = list.isEmpty
        ? 0
        : ((done.length / list.length) * 100).round();

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
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tugas',
                            style: AppTypography.titleLarge(c.text),
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            '${pending.length} belum selesai',
                            style: AppTypography.meta(c.textMuted),
                          ),
                        ],
                      ),
                    ),
                    const ThemeToggleSwitch(),
                    const SizedBox(width: AppSpacing.xs),
                    PressableScale(
                      onTap: () => _showMessage(
                        'Penambahan tugas belum tersedia pada mode simulasi.',
                      ),
                      semanticLabel: 'Tambah tugas',
                      tooltip: 'Tambah tugas',
                      child: Container(
                        constraints: const BoxConstraints(
                          minHeight: AppSpacing.target,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                        ),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: c.blue,
                          borderRadius: BorderRadius.circular(AppSpacing.sm),
                        ),
                        child: Text(
                          '+ Tambah',
                          style: AppTypography.button(c.onAccent),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.xs,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                child: AppCard(
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
                            'Progress Minggu Ini',
                            style: AppTypography.label(c.text),
                          ),
                          Text(
                            '${done.length}/${list.length} selesai',
                            style: AppTypography.label(c.blue)
                                .copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppSpacing.huge),
                        child: LinearProgressIndicator(
                          value: pct / 100,
                          minHeight: AppSpacing.progressMedium,
                          backgroundColor: c.surfaceHigh,
                          valueColor: AlwaysStoppedAnimation<Color>(c.blue),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '$pct% — ${pct < 50 ? 'Ayo semangat!' : 'Luar biasa, terus!'}',
                        style: AppTypography.micro(c.textMuted),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionLabel('Belum Selesai'),
                    if (list.isEmpty)
                      const AppEmptyState(
                        icon: Icons.task_alt_outlined,
                        title: 'Belum ada tugas',
                        message: 'Tugas yang kamu tambahkan akan muncul di daftar ini.',
                      )
                    else if (pending.isEmpty)
                      const AppEmptyState(
                        icon: Icons.celebration_outlined,
                        title: 'Semua tugas selesai',
                        message: 'Tidak ada tugas yang menunggu saat ini.',
                        accent: null,
                      )
                    else
                      Column(
                        children: pending
                            .map(
                              (TaskItem t) => Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.xs,
                                ),
                                child: _pendingTile(c, t),
                              ),
                            )
                            .toList(),
                      ),
                  ],
                ),
              ),
              if (done.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionLabel('Selesai'),
                      Column(
                        children: done
                            .map(
                              (TaskItem t) => Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.xs,
                                ),
                                child: _doneTile(c, t),
                              ),
                            )
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

  Widget _pendingTile(AppColors c, TaskItem t) {
    return PressableScale(
      onTap: () => _toggle(t.id),
      semanticLabel: '${t.title}. Belum selesai. Ketuk untuk menandai selesai.',
      tooltip: 'Tandai selesai',
      child: AppCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        background: t.urgent ? c.expenseDim : c.surface,
        borderColor: t.urgent ? c.expense.withValues(alpha: 0.5) : c.border,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: AppSpacing.target,
              height: AppSpacing.target,
              child: Center(
                child: Container(
                  width: AppSpacing.checkbox,
                  height: AppSpacing.checkbox,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: t.urgent ? c.expense : c.textMuted,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(AppSpacing.xs),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.title, style: AppTypography.label(c.text)),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(t.sub, style: AppTypography.meta(c.textMuted)),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: AppSpacing.sm,
                        color: t.urgent ? c.expense : c.textMuted,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        t.deadline,
                        style:
                            AppTypography.micro(
                              t.urgent ? c.expense : c.textMuted,
                            ).copyWith(
                              fontWeight: t.urgent
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                      ),
                      if (t.urgent) ...[
                        const SizedBox(width: AppSpacing.xs),
                        Pill(
                          text: 'Mendesak',
                          color: c.expense,
                          background: c.expenseDim,
                        ),
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

  Widget _doneTile(AppColors c, TaskItem t) {
    return PressableScale(
      onTap: () => _toggle(t.id),
      selected: true,
      semanticLabel: '${t.title}. Selesai. Ketuk untuk membuka kembali tugas.',
      tooltip: 'Buka kembali tugas',
      child: AppCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            SizedBox(
              width: AppSpacing.target,
              height: AppSpacing.target,
              child: Center(
                child: Container(
                  width: AppSpacing.checkbox,
                  height: AppSpacing.checkbox,
                  decoration: BoxDecoration(
                    color: c.success,
                    borderRadius: BorderRadius.circular(AppSpacing.xs),
                  ),
                  child: Icon(
                    Icons.check,
                    size: AppSpacing.md,
                    color: c.onAccent,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.title,
                    style: AppTypography.label(c.textSub)
                        .copyWith(decoration: TextDecoration.lineThrough),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(t.sub, style: AppTypography.meta(c.textMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
