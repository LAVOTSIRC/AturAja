import 'package:flutter/material.dart';

import '../data/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/theme_scope.dart';
import '../widgets/common.dart';

enum TaskFilter { all, pending, urgent, done }

enum TaskInputMode { manual, brainDump }

const List<String> availableCategories = [
  'Tugas Kuliah',
  'Pribadi',
  'Laundry',
  'Olahraga',
  'Organisasi',
  'Keuangan',
  'Lainnya',
];

IconData categoryIcon(String category) {
  switch (category) {
    case 'Tugas Kuliah':
      return Icons.menu_book_rounded;
    case 'Pribadi':
      return Icons.person_outline_rounded;
    case 'Laundry':
      return Icons.local_laundry_service_rounded;
    case 'Olahraga':
      return Icons.fitness_center_rounded;
    case 'Organisasi':
      return Icons.groups_rounded;
    case 'Keuangan':
      return Icons.account_balance_wallet_rounded;
    case 'Lainnya':
    default:
      return Icons.label_outline_rounded;
  }
}

class TaskScreen extends StatefulWidget {
  final List<TaskItem>? tasks;
  final VoidCallback? onAddTask;
  final ValueChanged<int>? onToggleTask;
  final ValueChanged<TaskItem>? onSaveTask;

  const TaskScreen({
    super.key,
    this.tasks,
    this.onAddTask,
    this.onToggleTask,
    this.onSaveTask,
  });

  @override
  State<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen> {
  late List<TaskItem> list;
  TaskFilter activeFilter = TaskFilter.all;
  String selectedCategoryFilter = 'Semua';

  @override
  void initState() {
    super.initState();
    list = widget.tasks != null ? List.of(widget.tasks!) : List.of(sampleTasks);
  }

  @override
  void didUpdateWidget(TaskScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tasks != null && widget.tasks != oldWidget.tasks) {
      setState(() {
        list = List.of(widget.tasks!);
      });
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    final AppColors c = ThemeScope.of(context).colors;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.info_outline_rounded,
              color: isError ? c.expense : c.blue,
              size: AppSpacing.iconSmall,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(child: Text(message, style: AppTypography.label(c.text))),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.surface,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.md),
          side: BorderSide(color: isError ? c.expense : c.border, width: 1.5),
        ),
        margin: const EdgeInsets.all(AppSpacing.md),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _toggleDone(int id) {
    setState(() {
      list = list.map((TaskItem t) {
        if (t.id == id) {
          final updated = t.copyWith(done: !t.done);
          _showMessage(
            updated.done
                ? 'Tugas "${t.title}" ditandai selesai! 🎉'
                : 'Tugas "${t.title}" dibuka kembali.',
          );
          return updated;
        }
        return t;
      }).toList();
    });
    widget.onToggleTask?.call(id);
  }

  void _saveTask(TaskItem task) {
    setState(() {
      final index = list.indexWhere((t) => t.id == task.id);
      if (index >= 0) {
        list[index] = task;
        _showMessage('Tugas "${task.title}" berhasil diperbarui.');
      } else {
        list.insert(0, task);
        _showMessage('Tugas baru "${task.title}" berhasil ditambahkan.');
      }
    });
    widget.onSaveTask?.call(task);
  }

  void _deleteTask(int id) {
    final task = list.firstWhere((t) => t.id == id, orElse: () => list.first);
    setState(() {
      list.removeWhere((t) => t.id == id);
    });
    _showMessage('Tugas "${task.title}" telah dihapus.', isError: true);
  }

  void _openTaskDetailScreen(TaskItem task) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TaskDetailScreen(
          task: task,
          onToggleDone: () {
            _toggleDone(task.id);
          },
          onEdit: () {
            _openTaskFormScreen(taskToEdit: task);
          },
          onDelete: () {
            _confirmDeleteTask(task);
          },
        ),
      ),
    );
  }

  void _confirmDeleteTask(TaskItem task) {
    final AppColors c = ThemeScope.of(context).colors;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.md),
          side: BorderSide(color: c.border),
        ),
        title: Text('Hapus Tugas?', style: AppTypography.titleLarge(c.text)),
        content: Text(
          'Apakah kamu yakin ingin menghapus tugas "${task.title}"? Tindakan ini tidak dapat dibatalkan.',
          style: AppTypography.body(c.textSub),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('Batal', style: AppTypography.button(c.textMuted)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _deleteTask(task.id);
            },
            child: Text('Hapus', style: AppTypography.button(c.expense)),
          ),
        ],
      ),
    );
  }

  void _openTaskFormScreen({TaskItem? taskToEdit}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TaskFormScreen(
          taskToEdit: taskToEdit,
          onSave: (savedTask) {
            _saveTask(savedTask);
          },
        ),
      ),
    );
  }

  List<TaskItem> get _filteredList {
    return list.where((t) {
      // 1. Status Filter
      bool matchesStatus = true;
      switch (activeFilter) {
        case TaskFilter.pending:
          matchesStatus = !t.done;
          break;
        case TaskFilter.urgent:
          matchesStatus = t.urgent && !t.done;
          break;
        case TaskFilter.done:
          matchesStatus = t.done;
          break;
        case TaskFilter.all:
          matchesStatus = true;
          break;
      }

      // 2. Category Filter
      bool matchesCategory = true;
      if (selectedCategoryFilter != 'Semua') {
        matchesCategory = t.categories.contains(selectedCategoryFilter);
      }

      return matchesStatus && matchesCategory;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = ThemeScope.of(context).colors;
    final List<TaskItem> pending = list.where((TaskItem t) => !t.done).toList();
    final List<TaskItem> done = list.where((TaskItem t) => t.done).toList();
    final int pct = list.isEmpty
        ? 0
        : ((done.length / list.length) * 100).round();

    final filtered = _filteredList;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: AppSpacing.screenBottom),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - AppSpacing.screenBottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
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
                            onTap: _openTaskFormScreen,
                            semanticLabel: 'Tambah tugas baru',
                            tooltip: 'Tambah tugas baru',
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
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.sm,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: c.blue.withValues(alpha: 0.25),
                                    blurRadius: AppSpacing.xs,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.add_rounded,
                                    size: AppSpacing.iconSmall,
                                    color: c.onAccent,
                                  ),
                                  const SizedBox(width: AppSpacing.xxs),
                                  Text(
                                    'Tambah',
                                    style: AppTypography.button(c.onAccent),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Progress Card
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
                              borderRadius: BorderRadius.circular(
                                AppSpacing.huge,
                              ),
                              child: LinearProgressIndicator(
                                value: list.isEmpty ? 0 : pct / 100,
                                minHeight: AppSpacing.progressMedium,
                                backgroundColor: c.surfaceHigh,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  pct == 100 ? c.teal : c.blue,
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              list.isEmpty
                                  ? 'Belum ada aktivitas tugas — Tambahkan tugas pertamamu!'
                                  : pct == 100
                                  ? 'Luar biasa! Semua tugas minggu ini tuntas! 🎉'
                                  : done.isEmpty
                                  ? 'Belum ada tugas selesai minggu ini. Mari tuntaskan 1 tugas hari ini!'
                                  : '$pct% — ${pct < 50 ? 'Ayo semangat, selesaikan tugasmu!' : 'Hampir selesai, teruskan!'}',
                              style: AppTypography.micro(c.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Dropdown Filter Bar
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.xs,
                      ),
                      child: _buildFilterDropdowns(c),
                    ),

                    const SizedBox(height: AppSpacing.xs),

                    // Task List Area
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SectionLabel(_getFilterSectionTitle()),
                          if (filtered.isEmpty)
                            _buildEmptyStateForFilter()
                          else
                            Column(
                              children: filtered
                                  .map(
                                    (TaskItem t) => Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: AppSpacing.xs,
                                      ),
                                      child: _taskTile(c, t),
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
            );
          },
        ),
      ),
    );
  }

  /// Compact Dropdown Filter Bar with Crisp Heights and No Clipping
  Widget _buildFilterDropdowns(AppColors c) {
    final int pendingCount = list.where((t) => !t.done).length;
    final int urgentCount = list.where((t) => t.urgent && !t.done).length;
    final int doneCount = list.where((t) => t.done).length;

    final bool hasActiveFilter =
        activeFilter != TaskFilter.all || selectedCategoryFilter != 'Semua';

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xs),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: c.surfaceHigh.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(AppSpacing.md),
          border: Border.all(color: c.border, width: 1.0),
        ),
        child: Row(
          children: [
            // 1. Status Dropdown
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs + 2,
                ),
                alignment: Alignment.center,
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<TaskFilter>(
                    value: activeFilter,
                    isExpanded: true,
                    borderRadius: BorderRadius.circular(AppSpacing.md),
                    dropdownColor: c.surface,
                    icon: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: activeFilter != TaskFilter.all
                          ? c.blue
                          : c.textMuted,
                    ),
                    style: AppTypography.caption(c.text).copyWith(
                      fontWeight: activeFilter != TaskFilter.all
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                    onChanged: (TaskFilter? newValue) {
                      if (newValue != null) {
                        setState(() => activeFilter = newValue);
                      }
                    },
                    items: [
                      DropdownMenuItem(
                        value: TaskFilter.all,
                        child: Text('Semua Status (${list.length})'),
                      ),
                      DropdownMenuItem(
                        value: TaskFilter.pending,
                        child: Text('Belum Selesai ($pendingCount)'),
                      ),
                      DropdownMenuItem(
                        value: TaskFilter.urgent,
                        child: Text('Mendesak <24j ($urgentCount)'),
                      ),
                      DropdownMenuItem(
                        value: TaskFilter.done,
                        child: Text('Selesai ($doneCount)'),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Vertical Divider Line
            Container(width: 1.5, height: 24, color: c.border),

            // 2. Category Dropdown
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs + 2,
                ),
                alignment: Alignment.center,
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedCategoryFilter,
                    isExpanded: true,
                    borderRadius: BorderRadius.circular(AppSpacing.md),
                    dropdownColor: c.surface,
                    icon: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: selectedCategoryFilter != 'Semua'
                          ? c.blue
                          : c.textMuted,
                    ),
                    style: AppTypography.caption(c.text).copyWith(
                      fontWeight: selectedCategoryFilter != 'Semua'
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() => selectedCategoryFilter = newValue);
                      }
                    },
                    items: [
                      DropdownMenuItem(
                        value: 'Semua',
                        child: Text('Semua Kategori (${list.length})'),
                      ),
                      ...availableCategories.map((cat) {
                        final count = list
                            .where((t) => t.categories.contains(cat))
                            .length;
                        return DropdownMenuItem(
                          value: cat,
                          child: Text('$cat ($count)'),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),

            // Reset Filter Button if Active
            if (hasActiveFilter) ...[
              Container(width: 1.5, height: 24, color: c.border),
              PressableScale(
                onTap: () {
                  setState(() {
                    activeFilter = TaskFilter.all;
                    selectedCategoryFilter = 'Semua';
                  });
                },
                semanticLabel: 'Reset Filter',
                tooltip: 'Reset Filter',
                child: SizedBox(
                  width: 38,
                  height: 38,
                  child: Center(
                    child: Icon(
                      Icons.refresh_rounded,
                      size: AppSpacing.iconSmall,
                      color: c.blue,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getFilterSectionTitle() {
    String title = '';
    switch (activeFilter) {
      case TaskFilter.pending:
        title = 'Belum Selesai';
        break;
      case TaskFilter.urgent:
        title = 'Mendesak (<24 Jam)';
        break;
      case TaskFilter.done:
        title = 'Selesai';
        break;
      case TaskFilter.all:
        title = 'Daftar Tugas';
        break;
    }

    if (selectedCategoryFilter != 'Semua') {
      title += ' • $selectedCategoryFilter';
    }
    return title;
  }

  Widget _buildEmptyStateForFilter() {
    if (selectedCategoryFilter != 'Semua') {
      return AppEmptyState(
        icon: categoryIcon(selectedCategoryFilter),
        title: 'Tidak ada tugas "$selectedCategoryFilter"',
        message:
            'Tidak ditemukan tugas untuk kategori $selectedCategoryFilter pada status ini. Coba ubah filter atau tambah tugas baru.',
      );
    }

    switch (activeFilter) {
      case TaskFilter.pending:
        return const AppEmptyState(
          icon: Icons.celebration_outlined,
          title: 'Semua tugas selesai',
          message: 'Luar biasa! Tidak ada tugas yang menunggu saat ini.',
        );
      case TaskFilter.urgent:
        return const AppEmptyState(
          icon: Icons.verified_outlined,
          title: 'Tidak ada tugas mendesak',
          message: 'Semua tugas memiliki tenggat waktu lebih dari 24 jam.',
        );
      case TaskFilter.done:
        return const AppEmptyState(
          icon: Icons.task_outlined,
          title: 'Belum ada tugas selesai',
          message: 'Belum ada aktivitas tugas selesai. Selesaikan tugasmu untuk melihatnya di sini.',
        );
      case TaskFilter.all:
        return const AppEmptyState(
          icon: Icons.task_alt_outlined,
          title: 'Belum ada aktivitas tugas',
          message: 'Kamu belum memiliki tugas tersimpan. Klik "+ Tambah" di atas untuk membuat tugas pertamamu!',
        );
    }
  }

  Widget _taskTile(AppColors c, TaskItem t) {
    final bool isUrgent = t.urgent;
    final bool isOverdue = t.isOverdue;

    // Determine status color indicator
    Color statusAccentColor = c.blue;
    if (t.done) {
      statusAccentColor = c.teal;
    } else if (isOverdue) {
      statusAccentColor = c.expense;
    } else if (isUrgent) {
      statusAccentColor = c.amber;
    }

    return PressableScale(
      onTap: () => _openTaskDetailScreen(t),
      semanticLabel:
          '${t.title}. ${t.done ? 'Selesai' : 'Belum selesai'}. Ketuk untuk membuka halaman detail.',
      tooltip: 'Buka detail tugas',
      child: AppCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        background: c.surface,
        borderColor: !t.done && (isOverdue || isUrgent)
            ? statusAccentColor.withValues(alpha: 0.6)
            : c.border,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Checkbox with Status Badge Circle Dot
            Stack(
              clipBehavior: Clip.none,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _toggleDone(t.id),
                  child: SizedBox(
                    width: AppSpacing.targetCompact,
                    height: AppSpacing.targetCompact,
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: AppSpacing.checkbox,
                        height: AppSpacing.checkbox,
                        decoration: BoxDecoration(
                          color: t.done ? c.success : c.transparent,
                          border: Border.all(
                            color: t.done
                                ? c.success
                                : (isOverdue
                                      ? c.expense
                                      : (isUrgent ? c.amber : c.textMuted)),
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(AppSpacing.xs),
                        ),
                        child: t.done
                            ? Icon(
                                Icons.check_rounded,
                                size: AppSpacing.md,
                                color: c.onAccent,
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
                if (!t.done && (isOverdue || isUrgent))
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: isOverdue ? c.expense : c.amber,
                        shape: BoxShape.circle,
                        border: Border.all(color: c.surface, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: AppSpacing.xxs),

            // Main Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.title,
                      style: AppTypography.label(t.done ? c.textSub : c.text)
                          .copyWith(
                            decoration: t.done
                                ? TextDecoration.lineThrough
                                : null,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),

                    // Multi-category Badges
                    Wrap(
                      spacing: AppSpacing.xxs,
                      runSpacing: 2,
                      children: t.categories.map((cat) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xs - 2,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: c.blueDim,
                            borderRadius: BorderRadius.circular(
                              AppSpacing.huge,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(categoryIcon(cat), size: 10, color: c.blue),
                              const SizedBox(width: 2),
                              Text(
                                cat,
                                style: AppTypography.micro(c.blue)
                                    .copyWith(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: AppSpacing.xs),

                    Row(
                      children: [
                        Icon(
                          isOverdue
                              ? Icons.warning_amber_rounded
                              : Icons.access_time_rounded,
                          size: AppSpacing.sm,
                          color: t.done
                              ? c.textMuted
                              : (isOverdue
                                    ? c.expense
                                    : (isUrgent ? c.amber : c.textMuted)),
                        ),
                        const SizedBox(width: AppSpacing.xxs),
                        Text(
                          t.deadline,
                          style:
                              AppTypography.micro(
                                t.done
                                    ? c.textMuted
                                    : (isOverdue
                                          ? c.expense
                                          : (isUrgent ? c.amber : c.textMuted)),
                              ).copyWith(
                                fontWeight: !t.done && (isOverdue || isUrgent)
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                        ),
                        if (!t.done && isOverdue) ...[
                          const SizedBox(width: AppSpacing.xs),
                          Pill(
                            text: '⚠️ Terlewat',
                            color: c.expense,
                            background: c.expenseDim,
                          ),
                        ] else if (!t.done && isUrgent) ...[
                          const SizedBox(width: AppSpacing.xs),
                          Pill(
                            text: 'Mendesak (<24j)',
                            color: c.amber,
                            background: c.amberDim,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Chevron Indicator
            SizedBox(
              height: AppSpacing.targetCompact,
              child: Center(
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: AppSpacing.iconSmall,
                  color: c.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dedicated Full-Screen Page for Task Details
class TaskDetailScreen extends StatefulWidget {
  final TaskItem task;
  final VoidCallback onToggleDone;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const TaskDetailScreen({
    super.key,
    required this.task,
    required this.onToggleDone,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  late TaskItem currentTask;

  @override
  void initState() {
    super.initState();
    currentTask = widget.task;
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = ThemeScope.of(context).colors;
    final bool isUrgent = currentTask.urgent;
    final bool isOverdue = currentTask.isOverdue;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: c.text),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Kembali',
        ),
        title: Text('Detail Tugas', style: AppTypography.titleLarge(c.text)),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(Icons.edit_outlined, color: c.blue),
            onPressed: () {
              Navigator.of(context).pop();
              widget.onEdit();
            },
            tooltip: 'Edit Tugas',
          ),
          IconButton(
            icon: Icon(Icons.delete_outline_rounded, color: c.expense),
            onPressed: () {
              Navigator.of(context).pop();
              widget.onDelete();
            },
            tooltip: 'Hapus Tugas',
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status & Urgent / Overdue Badges
                    Row(
                      children: [
                        Pill(
                          text: currentTask.done ? 'Selesai' : 'Belum Selesai',
                          color: currentTask.done ? c.teal : c.blue,
                          background: currentTask.done ? c.tealDim : c.blueDim,
                        ),
                        if (!currentTask.done && isOverdue) ...[
                          const SizedBox(width: AppSpacing.xs),
                          Pill(
                            text: '⚠️ Terlewat (Overdue)',
                            color: c.expense,
                            background: c.expenseDim,
                          ),
                        ] else if (!currentTask.done && isUrgent) ...[
                          const SizedBox(width: AppSpacing.xs),
                          Pill(
                            text: '🔥 Mendesak (< 24 Jam)',
                            color: c.amber,
                            background: c.amberDim,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Title
                    Text(
                      currentTask.title,
                      style: AppTypography.hero(c.text).copyWith(
                        decoration: currentTask.done
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    // Categories Card
                    AppCard(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'KATEGORI',
                            style: AppTypography.overline(c.textMuted),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Wrap(
                            spacing: AppSpacing.xs,
                            runSpacing: AppSpacing.xs,
                            children: currentTask.categories.map((cat) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm,
                                  vertical: AppSpacing.xs,
                                ),
                                decoration: BoxDecoration(
                                  color: c.blueDim,
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.huge,
                                  ),
                                  border: Border.all(color: c.blue),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      categoryIcon(cat),
                                      size: AppSpacing.sm,
                                      color: c.blue,
                                    ),
                                    const SizedBox(width: AppSpacing.xxs),
                                    Text(
                                      cat,
                                      style: AppTypography.label(
                                        c.blue,
                                      ).copyWith(fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // Deadline Card
                    AppCard(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      background: c.surface,
                      borderColor: !currentTask.done && (isOverdue || isUrgent)
                          ? (isOverdue ? c.expense : c.amber)
                          : c.border,
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.xs),
                            decoration: BoxDecoration(
                              color:
                                  !currentTask.done && (isOverdue || isUrgent)
                                  ? (isOverdue ? c.expenseDim : c.amberDim)
                                  : c.blueDim,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isOverdue
                                  ? Icons.warning_amber_rounded
                                  : Icons.access_time_filled_rounded,
                              size: AppSpacing.iconSmall,
                              color:
                                  !currentTask.done && (isOverdue || isUrgent)
                                  ? (isOverdue ? c.expense : c.amber)
                                  : c.blue,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'TENGGAT WAKTU',
                                  style: AppTypography.overline(
                                    !currentTask.done && (isOverdue || isUrgent)
                                        ? (isOverdue ? c.expense : c.amber)
                                        : c.textMuted,
                                  ),
                                ),
                                Text(
                                  currentTask.deadline,
                                  style: AppTypography.label(
                                    !currentTask.done && (isOverdue || isUrgent)
                                        ? (isOverdue ? c.expense : c.amber)
                                        : c.text,
                                  ).copyWith(fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // Description Section
                    SectionLabel('DESKRIPSI & CATATAN TUGAS'),
                    AppCard(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(minHeight: 120),
                        child: Text(
                          currentTask.description.trim().isNotEmpty
                              ? currentTask.description
                              : 'Tidak ada catatan tambahan untuk tugas ini.',
                          style: AppTypography.bodyLarge(
                            currentTask.description.trim().isNotEmpty
                                ? c.text
                                : c.textMuted,
                          ).copyWith(height: 1.6),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Action Bar
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: c.surface,
                border: Border(top: BorderSide(color: c.border)),
              ),
              child: PressableScale(
                onTap: () {
                  setState(() {
                    currentTask = currentTask.copyWith(done: !currentTask.done);
                  });
                  widget.onToggleDone();
                },
                semanticLabel: currentTask.done
                    ? 'Tandai belum selesai'
                    : 'Tandai selesai',
                child: Container(
                  width: double.infinity,
                  height: AppSpacing.target,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: currentTask.done ? c.surfaceHigh : c.teal,
                    borderRadius: BorderRadius.circular(AppSpacing.sm),
                    border: currentTask.done
                        ? Border.all(color: c.border)
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        currentTask.done
                            ? Icons.undo_rounded
                            : Icons.check_circle_rounded,
                        size: AppSpacing.iconMedium,
                        color: currentTask.done ? c.text : c.onAccent,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        currentTask.done
                            ? 'Buka Kembali Tugas'
                            : 'Tandai Sebagai Selesai',
                        style: AppTypography.button(
                          currentTask.done ? c.text : c.onAccent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dedicated Full-Screen Page for Creating or Editing a Task with AI Brain Dump
class TaskFormScreen extends StatefulWidget {
  final TaskItem? taskToEdit;
  final ValueChanged<TaskItem> onSave;

  const TaskFormScreen({super.key, this.taskToEdit, required this.onSave});

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  late TaskInputMode inputMode;
  late final TextEditingController titleController;
  late final TextEditingController deadlineController;
  late final TextEditingController descriptionController;
  late final TextEditingController brainDumpController;

  late List<String> selectedCategories;
  bool isDropdownExpanded = false;
  bool isProcessingBrainDump = false;
  DateTime? selectedDueDate;
  String? errorMessage;

  static const List<String> brainDumpSuggestions = [
    'Besok jam 08:00 Quiz Kalkulus untuk Tugas Kuliah dan Pribadi',
    'Ambil laundry & cuci sepatu hari ini jam 18:00',
    'Rapat evaluasi BEM lusa jam 19:00 untuk Organisasi',
    'Jogging 5km di lapangan kampus besok jam 16:30',
  ];

  static const List<String> deadlinePresets = [
    'Hari ini, 23:59',
    'Besok, 08:00',
    '3 hari lagi',
    'Minggu depan',
  ];

  @override
  void initState() {
    super.initState();
    final t = widget.taskToEdit;
    inputMode = TaskInputMode.manual;
    titleController = TextEditingController(text: t?.title ?? '');
    deadlineController = TextEditingController(
      text: t?.deadline ?? 'Hari ini, 23:59',
    );
    descriptionController = TextEditingController(text: t?.description ?? '');
    brainDumpController = TextEditingController();
    selectedCategories = List.of(t?.categories ?? ['Tugas Kuliah']);
    selectedDueDate =
        t?.dueDate ?? DateTime.now().add(const Duration(hours: 12));
  }

  @override
  void dispose() {
    titleController.dispose();
    deadlineController.dispose();
    descriptionController.dispose();
    brainDumpController.dispose();
    super.dispose();
  }

  void _toggleCategory(String category) {
    setState(() {
      if (selectedCategories.contains(category)) {
        if (selectedCategories.length > 1) {
          selectedCategories.remove(category);
        } else {
          errorMessage = 'Pilih minimal 1 kategori untuk tugas ini!';
        }
      } else {
        selectedCategories.add(category);
        errorMessage = null;
      }
    });
  }

  Future<void> _processBrainDump() async {
    final text = brainDumpController.text.trim();
    if (text.isEmpty) {
      setState(() {
        errorMessage = 'Tuliskan catatan brain dump terlebih dahulu.';
      });
      return;
    }

    if (text.length < 5) {
      setState(() {
        errorMessage = 'Isi brain dump terlalu pendek (minimal 5 karakter).';
      });
      return;
    }

    setState(() {
      isProcessingBrainDump = true;
      errorMessage = null;
    });

    await Future<void>.delayed(const Duration(milliseconds: 600));

    final lower = text.toLowerCase();

    // 1. Auto detect categories
    final List<String> detectedCategories = [];
    if (lower.contains('kalkulus') ||
        lower.contains('quiz') ||
        lower.contains('tugas') ||
        lower.contains('laporan') ||
        lower.contains('praktikum') ||
        lower.contains('kuliah')) {
      detectedCategories.add('Tugas Kuliah');
    }
    if (lower.contains('laundry') || lower.contains('cuci')) {
      detectedCategories.add('Laundry');
    }
    if (lower.contains('jogging') ||
        lower.contains('gym') ||
        lower.contains('olahraga') ||
        lower.contains('fitness')) {
      detectedCategories.add('Olahraga');
    }
    if (lower.contains('bem') ||
        lower.contains('rapat') ||
        lower.contains('organisasi') ||
        lower.contains('proker')) {
      detectedCategories.add('Organisasi');
    }
    if (lower.contains('bayar') ||
        lower.contains('kos') ||
        lower.contains('uang')) {
      detectedCategories.add('Keuangan');
    }
    if (detectedCategories.isEmpty || lower.contains('pribadi')) {
      detectedCategories.add('Pribadi');
    }

    // 2. Auto detect deadline
    final now = DateTime.now();
    DateTime detectedDueDate = now.add(const Duration(hours: 12));
    String detectedDeadlineStr = 'Hari ini, 23:59';

    if (lower.contains('besok')) {
      if (lower.contains('08:00') || lower.contains('jam 8')) {
        detectedDeadlineStr = 'Besok, 08:00';
        detectedDueDate = DateTime(now.year, now.month, now.day + 1, 8, 0);
      } else {
        detectedDeadlineStr = 'Besok, 23:59';
        detectedDueDate = DateTime(now.year, now.month, now.day + 1, 23, 59);
      }
    } else if (lower.contains('lusa')) {
      detectedDeadlineStr = '2 hari lagi';
      detectedDueDate = now.add(const Duration(days: 2));
    } else if (lower.contains('hari ini')) {
      if (lower.contains('18:00') || lower.contains('jam 6')) {
        detectedDeadlineStr = 'Hari ini, 18:00';
        detectedDueDate = DateTime(now.year, now.month, now.day, 18, 0);
      } else {
        detectedDeadlineStr = 'Hari ini, 23:59';
        detectedDueDate = DateTime(now.year, now.month, now.day, 23, 59);
      }
    }

    // 3. Extract title & description
    String extractedTitle = text;
    if (text.length > 50) {
      extractedTitle = '${text.substring(0, 47)}...';
    }

    setState(() {
      isProcessingBrainDump = false;
      titleController.text = extractedTitle;
      selectedCategories = detectedCategories;
      deadlineController.text = detectedDeadlineStr;
      selectedDueDate = detectedDueDate;
      descriptionController.text = text;
      inputMode = TaskInputMode.manual; // Switch back to preview manual form
    });

    if (mounted) {
      final AppColors c = ThemeScope.of(context).colors;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                color: c.blue,
                size: AppSpacing.iconSmall,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'Brain dump berhasil diproses! Periksa detail tugas di bawah.',
                  style: AppTypography.label(c.text),
                ),
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: c.surface,
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.md),
            side: BorderSide(color: c.border, width: 1.5),
          ),
          margin: const EdgeInsets.all(AppSpacing.md),
        ),
      );
    }
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDueDate ?? now,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 365)),
    );

    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(selectedDueDate ?? now),
    );

    if (!mounted) return;

    final time = pickedTime ?? const TimeOfDay(hour: 23, minute: 59);
    final finalDateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      time.hour,
      time.minute,
    );

    final String dayStr = pickedDate.day == now.day
        ? 'Hari ini'
        : '${pickedDate.day}/${pickedDate.month}/${pickedDate.year}';
    final String timeStr =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

    setState(() {
      selectedDueDate = finalDateTime;
      deadlineController.text = '$dayStr, $timeStr';
    });
  }

  void _applyPreset(String preset) {
    final now = DateTime.now();
    DateTime calculatedDate;

    if (preset.contains('Hari ini')) {
      calculatedDate = DateTime(now.year, now.month, now.day, 23, 59);
    } else if (preset.contains('Besok')) {
      calculatedDate = DateTime(now.year, now.month, now.day + 1, 8, 0);
    } else if (preset.contains('3 hari')) {
      calculatedDate = now.add(const Duration(days: 3));
    } else {
      calculatedDate = now.add(const Duration(days: 7));
    }

    setState(() {
      selectedDueDate = calculatedDate;
      deadlineController.text = preset;
    });
  }

  bool _isCalculatedUrgent() {
    if (selectedDueDate != null) {
      final diff = selectedDueDate!.difference(DateTime.now());
      return diff.inHours < 24 && diff.inHours >= 0;
    }
    final lower = deadlineController.text.toLowerCase();
    return lower.contains('hari ini') ||
        lower.contains('besok') ||
        lower.contains('23:59') ||
        lower.contains('08:00');
  }

  void _submit() {
    final title = titleController.text.trim();
    if (title.isEmpty) {
      setState(() {
        errorMessage = 'Judul tugas wajib diisi.';
      });
      return;
    }

    if (title.length < 4) {
      setState(() {
        errorMessage = 'Judul tugas terlalu pendek (minimal 4 karakter).';
      });
      return;
    }

    if (title.length > 100) {
      setState(() {
        errorMessage = 'Judul tugas terlalu panjang (maksimal 100 karakter).';
      });
      return;
    }

    if (selectedCategories.isEmpty) {
      setState(() {
        errorMessage = 'Pilih minimal 1 kategori untuk tugas ini!';
      });
      return;
    }

    final deadline = deadlineController.text.trim();
    if (deadline.isEmpty) {
      setState(() {
        errorMessage = 'Tenggat waktu tidak boleh kosong.';
      });
      return;
    }

    final description = descriptionController.text.trim();

    final TaskItem task = TaskItem(
      id: widget.taskToEdit?.id ?? DateTime.now().millisecondsSinceEpoch,
      title: title,
      categories: selectedCategories,
      description: description,
      deadline: deadline,
      dueDate: selectedDueDate,
      done: widget.taskToEdit?.done ?? false,
    );

    widget.onSave(task);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = ThemeScope.of(context).colors;
    final bool isEditing = widget.taskToEdit != null;
    final bool isUrgentAuto = _isCalculatedUrgent();

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: c.text),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Batal',
        ),
        title: Text(
          isEditing ? 'Edit Tugas' : 'Tambah Tugas Baru',
          style: AppTypography.titleLarge(c.text),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Mode Switcher Tabs
            if (!isEditing) ...[
              Container(
                margin: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  0,
                ),
                padding: const EdgeInsets.all(AppSpacing.xxs),
                decoration: BoxDecoration(
                  color: c.surfaceHigh,
                  borderRadius: BorderRadius.circular(AppSpacing.md),
                  border: Border.all(color: c.border),
                ),
                child: Row(
                  children: [
                    _inputModeTab(
                      c,
                      mode: TaskInputMode.manual,
                      icon: Icons.edit_note_rounded,
                      label: 'Form Manual',
                    ),
                    const SizedBox(width: AppSpacing.xxs),
                    _inputModeTab(
                      c,
                      mode: TaskInputMode.brainDump,
                      icon: Icons.psychology_rounded,
                      label: 'AI Brain Dump',
                    ),
                  ],
                ),
              ),
            ],

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (errorMessage != null) ...[
                      AppErrorMessage(message: errorMessage!),
                      const SizedBox(height: AppSpacing.md),
                    ],

                    // AI Brain Dump Body
                    if (!isEditing && inputMode == TaskInputMode.brainDump) ...[
                      AppCard(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(AppSpacing.xs),
                                  decoration: BoxDecoration(
                                    color: c.blueDim,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.auto_awesome_rounded,
                                    size: AppSpacing.iconSmall,
                                    color: c.blue,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'AI Brain Dump Tugas',
                                        style: AppTypography.label(
                                          c.text,
                                        ).copyWith(fontWeight: FontWeight.w700),
                                      ),
                                      Text(
                                        'Tuliskan tugas secara bebas — AI akan memilah Judul, Kategori, dan Tenggat secara otomatis!',
                                        style: AppTypography.caption(
                                          c.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.md),
                            TextField(
                              controller: brainDumpController,
                              maxLines: 4,
                              maxLength: 300,
                              autofocus: true,
                              style: AppTypography.bodyLarge(c.text),
                              decoration: _cleanInputDecoration(
                                c,
                                hintText: 'Contoh: Besok jam 08:00 ada Quiz Kalkulus untuk Tugas Kuliah dan kumpulkan laporan praktikum...',
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),

                            // Brain Dump Suggestions
                            Text(
                              'CONTOH BRAIN DUMP',
                              style: AppTypography.overline(c.textMuted),
                            ),
                            const SizedBox(height: AppSpacing.xxs),
                            Wrap(
                              spacing: AppSpacing.xs,
                              runSpacing: AppSpacing.xs,
                              children: brainDumpSuggestions.map((suggestion) {
                                return PressableScale(
                                  onTap: () {
                                    setState(() {
                                      brainDumpController.text = suggestion;
                                      errorMessage = null;
                                    });
                                  },
                                  semanticLabel: 'Gunakan contoh $suggestion',
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.sm,
                                      vertical: AppSpacing.xs - 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: c.surfaceHigh,
                                      borderRadius: BorderRadius.circular(
                                        AppSpacing.huge,
                                      ),
                                      border: Border.all(color: c.border),
                                    ),
                                    child: Text(
                                      suggestion,
                                      style: AppTypography.caption(c.textSub),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),

                            const SizedBox(height: AppSpacing.lg),

                            // Process Button
                            PressableScale(
                              onTap: isProcessingBrainDump
                                  ? null
                                  : _processBrainDump,
                              semanticLabel: 'Proses Brain Dump dengan AI',
                              child: Container(
                                width: double.infinity,
                                height: AppSpacing.target,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: c.blue,
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.md,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: c.blue.withValues(alpha: 0.3),
                                      blurRadius: AppSpacing.xs,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (isProcessingBrainDump) ...[
                                      SizedBox(
                                        width: AppSpacing.iconSmall,
                                        height: AppSpacing.iconSmall,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: c.onAccent,
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.xs),
                                      Text(
                                        'Memproses...',
                                        style: AppTypography.button(c.onAccent),
                                      ),
                                    ] else ...[
                                      Icon(
                                        Icons.auto_awesome_rounded,
                                        size: AppSpacing.iconSmall,
                                        color: c.onAccent,
                                      ),
                                      const SizedBox(width: AppSpacing.xs),
                                      Text(
                                        'Proses Brain Dump ✨',
                                        style: AppTypography.button(c.onAccent),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      // Input Judul Tugas Card
                      AppCard(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _formLabel(c, 'JUDUL TUGAS *'),
                                Text(
                                  '${titleController.text.length}/100',
                                  style: AppTypography.micro(c.textMuted),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.xxs),
                            TextField(
                              controller: titleController,
                              autofocus: !isEditing,
                              maxLength: 100,
                              style: AppTypography.title(c.text),
                              decoration: _cleanInputDecoration(
                                c,
                                hintText: 'misal: Laporan Praktikum Modul 4',
                              ).copyWith(counterText: ''),
                              onChanged: (_) {
                                if (errorMessage != null) {
                                  setState(() => errorMessage = null);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Multi-Select Category Dropdown Card
                      AppCard(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _formLabel(
                                  c,
                                  'KATEGORI (BISA PILIH LEBIH DARI 1)',
                                ),
                                Text(
                                  '${selectedCategories.length} dipilih',
                                  style: AppTypography.micro(c.blue)
                                      .copyWith(fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.xs),

                            // Dropdown Selector Trigger Field
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  isDropdownExpanded = !isDropdownExpanded;
                                });
                              },
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(AppSpacing.sm),
                                decoration: BoxDecoration(
                                  color: c.surfaceHigh.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.md,
                                  ),
                                  border: Border.all(
                                    color: isDropdownExpanded
                                        ? c.blue
                                        : c.border,
                                    width: isDropdownExpanded ? 1.5 : 1.0,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Wrap(
                                        spacing: AppSpacing.xs,
                                        runSpacing: AppSpacing.xxs,
                                        children: selectedCategories.map((cat) {
                                          return Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: AppSpacing.xs + 2,
                                              vertical: AppSpacing.xxs,
                                            ),
                                            decoration: BoxDecoration(
                                              color: c.blueDim,
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    AppSpacing.huge,
                                                  ),
                                              border: Border.all(color: c.blue),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  categoryIcon(cat),
                                                  size: 12,
                                                  color: c.blue,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  cat,
                                                  style:
                                                      AppTypography.caption(
                                                        c.blue,
                                                      ).copyWith(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                ),
                                                const SizedBox(width: 4),
                                                GestureDetector(
                                                  onTap: () =>
                                                      _toggleCategory(cat),
                                                  child: Icon(
                                                    Icons.close_rounded,
                                                    size: 14,
                                                    color: c.blue,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                    Icon(
                                      isDropdownExpanded
                                          ? Icons.keyboard_arrow_up_rounded
                                          : Icons.keyboard_arrow_down_rounded,
                                      color: c.blue,
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Expandable Multi-Select Category Menu
                            if (isDropdownExpanded) ...[
                              const SizedBox(height: AppSpacing.sm),
                              Container(
                                padding: const EdgeInsets.all(AppSpacing.xs),
                                decoration: BoxDecoration(
                                  color: c.surfaceHigh,
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.md,
                                  ),
                                  border: Border.all(color: c.border),
                                ),
                                child: Column(
                                  children: availableCategories.map((cat) {
                                    final bool isSelected = selectedCategories
                                        .contains(cat);
                                    return InkWell(
                                      onTap: () => _toggleCategory(cat),
                                      borderRadius: BorderRadius.circular(
                                        AppSpacing.xs,
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: AppSpacing.sm,
                                          vertical: AppSpacing.xs + 2,
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              categoryIcon(cat),
                                              size: AppSpacing.iconSmall,
                                              color: isSelected
                                                  ? c.blue
                                                  : c.textMuted,
                                            ),
                                            const SizedBox(
                                              width: AppSpacing.xs,
                                            ),
                                            Expanded(
                                              child: Text(
                                                cat,
                                                style:
                                                    AppTypography.body(
                                                      isSelected
                                                          ? c.text
                                                          : c.textSub,
                                                    ).copyWith(
                                                      fontWeight: isSelected
                                                          ? FontWeight.w600
                                                          : FontWeight.w400,
                                                    ),
                                              ),
                                            ),
                                            AnimatedContainer(
                                              duration: const Duration(
                                                milliseconds: 150,
                                              ),
                                              width: AppSpacing.checkbox - 4,
                                              height: AppSpacing.checkbox - 4,
                                              decoration: BoxDecoration(
                                                color: isSelected
                                                    ? c.blue
                                                    : c.transparent,
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      AppSpacing.xxs,
                                                    ),
                                                border: Border.all(
                                                  color: isSelected
                                                      ? c.blue
                                                      : c.textMuted,
                                                  width: 1.5,
                                                ),
                                              ),
                                              child: isSelected
                                                  ? Icon(
                                                      Icons.check_rounded,
                                                      size: 14,
                                                      color: c.onAccent,
                                                    )
                                                  : null,
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Input Tenggat Waktu Card
                      AppCard(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _formLabel(c, 'TENGGAT WAKTU *'),
                            const SizedBox(height: AppSpacing.xxs),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: deadlineController,
                                    style: AppTypography.bodyLarge(c.text),
                                    decoration: _cleanInputDecoration(
                                      c,
                                      hintText: 'misal: Besok, 08:00',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                PressableScale(
                                  onTap: _pickDateTime,
                                  tooltip: 'Pilih Tanggal & Jam',
                                  semanticLabel: 'Buka Pemilih Kalender',
                                  child: Container(
                                    height: 48,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.sm,
                                    ),
                                    decoration: BoxDecoration(
                                      color: c.blueDim,
                                      borderRadius: BorderRadius.circular(
                                        AppSpacing.md,
                                      ),
                                      border: Border.all(color: c.blue),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.calendar_month_rounded,
                                          size: AppSpacing.iconSmall,
                                          color: c.blue,
                                        ),
                                        const SizedBox(width: AppSpacing.xxs),
                                        Text(
                                          'Pilih',
                                          style: AppTypography.label(c.blue),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),

                            // Presets
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: deadlinePresets.map((preset) {
                                  final bool isSelected =
                                      deadlineController.text == preset;
                                  return Padding(
                                    padding: const EdgeInsets.only(
                                      right: AppSpacing.xs,
                                    ),
                                    child: PressableScale(
                                      onTap: () => _applyPreset(preset),
                                      semanticLabel: 'Pilih tenggat $preset',
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: AppSpacing.sm,
                                          vertical: AppSpacing.xs,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? c.blueDim
                                              : c.surfaceHigh,
                                          borderRadius: BorderRadius.circular(
                                            AppSpacing.huge,
                                          ),
                                          border: Border.all(
                                            color: isSelected
                                                ? c.blue
                                                : c.border,
                                          ),
                                        ),
                                        child: Text(
                                          preset,
                                          style:
                                              AppTypography.caption(
                                                isSelected ? c.blue : c.textSub,
                                              ).copyWith(
                                                fontWeight: isSelected
                                                    ? FontWeight.w600
                                                    : FontWeight.w400,
                                              ),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),

                            if (isUrgentAuto) ...[
                              const SizedBox(height: AppSpacing.md),
                              Container(
                                padding: const EdgeInsets.all(AppSpacing.sm),
                                decoration: BoxDecoration(
                                  color: c.expenseDim,
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.md,
                                  ),
                                  border: Border.all(color: c.expense),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.local_fire_department_rounded,
                                      size: AppSpacing.iconSmall,
                                      color: c.expense,
                                    ),
                                    const SizedBox(width: AppSpacing.xs),
                                    Expanded(
                                      child: Text(
                                        'Tugas ini otomatis ditandai Mendesak karena tenggat waktu kurang dari 24 jam.',
                                        style: AppTypography.caption(
                                          c.expense,
                                        ).copyWith(fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Input Deskripsi Card
                      AppCard(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _formLabel(c, 'DESKRIPSI / CATATAN DETAIL'),
                                Text(
                                  '${descriptionController.text.length}/500',
                                  style: AppTypography.micro(c.textMuted),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.xxs),
                            TextField(
                              controller: descriptionController,
                              maxLines: 5,
                              minLines: 3,
                              maxLength: 500,
                              style: AppTypography.bodyLarge(c.text),
                              decoration: _cleanInputDecoration(
                                c,
                                hintText: 'Tuliskan instruksi, catatan penting, atau detail tugas di sini...',
                              ).copyWith(counterText: ''),
                              onChanged: (_) => setState(() {}),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Bottom Save Action Bar
            if (inputMode == TaskInputMode.manual) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: c.surface,
                  border: Border(top: BorderSide(color: c.border)),
                ),
                child: PressableScale(
                  onTap: _submit,
                  semanticLabel: isEditing
                      ? 'Simpan perubahan'
                      : 'Tambah tugas',
                  child: Container(
                    width: double.infinity,
                    height: AppSpacing.target,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: c.blue,
                      borderRadius: BorderRadius.circular(AppSpacing.md),
                      boxShadow: [
                        BoxShadow(
                          color: c.blue.withValues(alpha: 0.3),
                          blurRadius: AppSpacing.xs,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      isEditing ? 'Simpan Perubahan' : 'Tambah Tugas',
                      style: AppTypography.button(c.onAccent),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _inputModeTab(
    AppColors c, {
    required TaskInputMode mode,
    required IconData icon,
    required String label,
  }) {
    final bool isSelected = inputMode == mode;
    return Expanded(
      child: PressableScale(
        onTap: () {
          setState(() {
            inputMode = mode;
            errorMessage = null;
          });
        },
        selected: isSelected,
        semanticLabel: 'Mode $label',
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: AppSpacing.targetCompact,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? c.blue : c.transparent,
            borderRadius: BorderRadius.circular(AppSpacing.sm),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: AppSpacing.iconSmall - 2,
                color: isSelected ? c.onAccent : c.textSub,
              ),
              const SizedBox(width: AppSpacing.xxs),
              Text(
                label,
                style: AppTypography.label(isSelected ? c.onAccent : c.textSub)
                    .copyWith(
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _formLabel(AppColors c, String text) {
    return Text(text, style: AppTypography.overline(c.textMuted));
  }

  InputDecoration _cleanInputDecoration(
    AppColors c, {
    required String hintText,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: AppTypography.body(c.textMuted),
      filled: true,
      fillColor: c.surfaceHigh.withValues(alpha: 0.6),
      contentPadding: const EdgeInsets.all(AppSpacing.sm),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.md),
        borderSide: BorderSide(color: c.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.md),
        borderSide: BorderSide(color: c.blue, width: 1.5),
      ),
    );
  }
}
