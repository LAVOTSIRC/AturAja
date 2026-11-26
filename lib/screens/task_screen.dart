import 'package:flutter/material.dart';

import '../data/id_generator.dart';
import '../data/models.dart';
import '../services/brain_dump_ai_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/theme_scope.dart';
import '../utils/task_schedule.dart';
import '../widgets/common.dart';
import 'brain_dump_finance_screen.dart';

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
  final List<TaskItem> tasks;
  final String nextTaskId;
  final VoidCallback? onAddTask;
  final ValueChanged<String>? onToggleTask;
  final ValueChanged<TaskItem>? onSaveTask;
  final ValueChanged<String>? onDeleteTask;

  const TaskScreen({
    super.key,
    required this.tasks,
    required this.nextTaskId,
    this.onAddTask,
    this.onToggleTask,
    this.onSaveTask,
    this.onDeleteTask,
  });

  @override
  State<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen> {
  TaskFilter activeFilter = TaskFilter.all;
  String selectedCategoryFilter = 'Semua';
  String searchQuery = '';
  final TextEditingController searchController = TextEditingController();

  List<TaskItem> get list => widget.tasks;

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void _clearSearch() {
    searchController.clear();
    setState(() => searchQuery = '');
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

  void _toggleDone(String id) {
    final task = list.firstWhere((t) => t.id == id, orElse: () => list.first);
    final isDoneNow = !task.done;
    _showMessage(
      isDoneNow
          ? 'Tugas "${task.title}" ditandai selesai! 🎉'
          : 'Tugas "${task.title}" dibuka kembali.',
    );

    widget.onToggleTask?.call(id);
  }

  void _saveTask(TaskItem task) {
    final bool isUpdate = widget.tasks.any((t) => t.id == task.id);
    widget.onSaveTask?.call(task);
    _showMessage(
      isUpdate
          ? 'Tugas "${task.title}" berhasil diperbarui.'
          : 'Tugas baru "${task.title}" berhasil ditambahkan.',
    );
  }

  void _saveTasks(List<TaskItem> tasks) {
    for (final TaskItem task in tasks) {
      widget.onSaveTask?.call(task);
    }
    _showMessage('${tasks.length} tugas berhasil ditambahkan.');
  }

  void _deleteTask(String id) {
    final task = list.firstWhere((t) => t.id == id, orElse: () => list.first);
    widget.onDeleteTask?.call(id);
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
          nextTaskId: widget.nextTaskId,
          onSave: (savedTask) {
            _saveTask(savedTask);
          },
          onSaveMany: (savedTasks) {
            _saveTasks(savedTasks);
          },
        ),
      ),
    );
  }

  List<TaskItem> get _filteredList {
    final List<TaskItem> filtered = list.where((t) {
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

      // 3. Pencarian judul, kategori, atau deskripsi
      final String query = searchQuery.trim().toLowerCase();
      final bool matchesQuery =
          query.isEmpty ||
          t.title.toLowerCase().contains(query) ||
          t.description.toLowerCase().contains(query) ||
          t.categories.any(
            (String category) => category.toLowerCase().contains(query),
          );

      return matchesStatus && matchesCategory && matchesQuery;
    }).toList();
    filtered.sort((TaskItem a, TaskItem b) {
      if (a.done != b.done) {
        return a.done ? 1 : -1;
      }
      if (!a.done && a.urgent != b.urgent) {
        return a.urgent ? -1 : 1;
      }
      final DateTime? aDate = a.dueDate;
      final DateTime? bDate = b.dueDate;
      if (aDate != null && bDate != null) {
        return aDate.compareTo(bDate);
      }
      if (aDate != null) return -1;
      if (bDate != null) return 1;
      return a.id.compareTo(b.id);
    });
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = ThemeScope.of(context).colors;
    final List<TaskItem> pending = list.where((TaskItem t) => !t.done).toList();

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
                        AppSpacing.sm,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Tugas',
                                  style: AppTypography.titleLarge(c.text)
                                      .copyWith(
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.3,
                                      ),
                                ),
                                const SizedBox(height: AppSpacing.xxs),
                                Row(
                                  children: [
                                    Container(
                                      width: 7,
                                      height: 7,
                                      decoration: BoxDecoration(
                                        color: pending.isEmpty
                                            ? c.teal
                                            : c.amber,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.xxs),
                                    Text(
                                      pending.isEmpty
                                          ? 'Semua tugas selesai'
                                          : '${pending.length} tugas perlu diselesaikan',
                                      style: AppTypography.meta(c.textMuted),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
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
                                  AppSpacing.huge,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: c.blue.withValues(alpha: 0.25),
                                    blurRadius: AppSpacing.sm,
                                    offset: const Offset(0, 4),
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

                    // Progress penyelesaian tugas
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      child: _buildProgressCard(c),
                    ),

                    const SizedBox(height: AppSpacing.sm),

                    // Pencarian tugas
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      child: _buildSearchField(c),
                    ),

                    const SizedBox(height: AppSpacing.sm),

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
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.sm,
                              left: AppSpacing.xxs,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _getFilterSectionTitle(),
                                    style: AppTypography.caption(c.textSub)
                                        .copyWith(
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.8,
                                        ),
                                  ),
                                ),
                                Text(
                                  '${filtered.length} tugas',
                                  style: AppTypography.micro(c.textMuted),
                                ),
                              ],
                            ),
                          ),
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

  Widget _buildProgressCard(AppColors c) {
    final int total = list.length;
    final int done = list.where((TaskItem t) => t.done).length;
    final int percent = total == 0 ? 0 : ((done / total) * 100).round();
    final List<TaskItem> todayTasks = list
        .where((TaskItem t) => t.deadlineLabel.startsWith('Hari ini'))
        .toList();
    final int todayDone = todayTasks.where((TaskItem t) => t.done).length;
    final String note = total == 0
        ? 'Belum ada tugas — tambahkan tugas pertamamu!'
        : percent == 100
        ? 'Luar biasa! Semua tugas sudah selesai.'
        : todayTasks.isEmpty
        ? '$done dari $total tugas selesai. Tambahkan tugas untuk hari ini!'
        : '$todayDone/${todayTasks.length} tugas hari ini selesai — '
            '${percent < 50 ? 'ayo selesaikan satu tugas!' : 'hampir selesai, teruskan!'}';

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      background: c.surface,
      borderColor: c.border.withValues(alpha: 0.55),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: c.blueDim,
                  borderRadius: BorderRadius.circular(AppSpacing.sm),
                ),
                child: Icon(
                  Icons.trending_up_rounded,
                  color: c.blue,
                  size: AppSpacing.iconSmall,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Progress tugas',
                      style: AppTypography.label(
                        c.text,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      '$done dari $total tugas selesai',
                      style: AppTypography.micro(c.textMuted),
                    ),
                  ],
                ),
              ),
              Text(
                '$percent%',
                style: AppTypography.title(
                  c.blue,
                ).copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.huge),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : done / total,
              minHeight: AppSpacing.progressMedium,
              backgroundColor: c.surfaceHigh,
              valueColor: AlwaysStoppedAnimation<Color>(
                percent == 100 ? c.teal : c.blue,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(note, style: AppTypography.micro(c.textMuted)),
        ],
      ),
    );
  }

  Widget _buildSearchField(AppColors c) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      background: c.surface,
      borderColor: c.border.withValues(alpha: 0.55),
      child: Row(
        children: [
          Icon(
            Icons.search_rounded,
            color: c.textMuted,
            size: AppSpacing.iconSmall,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: TextField(
              controller: searchController,
              onChanged: (String value) =>
                  setState(() => searchQuery = value),
              style: AppTypography.body(c.text),
              decoration: InputDecoration(
                hintText: 'Cari tugas...',
                hintStyle: AppTypography.body(c.textMuted),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          if (searchQuery.isNotEmpty)
            PressableScale(
              onTap: _clearSearch,
              tooltip: 'Hapus pencarian',
              semanticLabel: 'Hapus pencarian',
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxs),
                child: Icon(
                  Icons.close_rounded,
                  color: c.textMuted,
                  size: AppSpacing.iconSmall,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Compact Dropdown Filter Bar with Crisp Heights and No Clipping
  Widget _buildFilterDropdowns(AppColors c) {
    final int pendingCount = list.where((t) => !t.done).length;
    final int urgentCount = list.where((t) => t.urgent && !t.done).length;
    final int doneCount = list.where((t) => t.done).length;

    final bool hasActiveFilter =
        activeFilter != TaskFilter.all ||
        selectedCategoryFilter != 'Semua' ||
        searchQuery.trim().isNotEmpty;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xs),
      background: c.surface,
      borderColor: c.border.withValues(alpha: 0.55),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: c.surfaceHigh.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(AppSpacing.sm),
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
                        child: Text('Status · Semua (${list.length})'),
                      ),
                      DropdownMenuItem(
                        value: TaskFilter.pending,
                        child: Text('Belum selesai ($pendingCount)'),
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
                        child: Text('Kategori · Semua (${list.length})'),
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
                    searchQuery = '';
                  });
                  searchController.clear();
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
    if (searchQuery.trim().isNotEmpty) {
      return AppEmptyState(
        icon: Icons.search_off_rounded,
        title: 'Tidak ada hasil untuk "$searchQuery"',
        message: 'Coba kata kunci lain atau hapus pencarian.',
      );
    }
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
    final List<String> visibleCategories = t.categories.take(2).toList();
    final int hiddenCategoryCount =
        t.categories.length - visibleCategories.length;

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
          vertical: AppSpacing.md,
        ),
        background: c.surface,
        borderColor: c.border.withValues(alpha: 0.5),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: statusAccentColor,
                  borderRadius: BorderRadius.circular(AppSpacing.huge),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
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
                        children: <Widget>[
                          ...visibleCategories.map((cat) {
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
                                  Icon(
                                    categoryIcon(cat),
                                    size: 10,
                                    color: c.blue,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    cat,
                                    style: AppTypography.micro(c.blue)
                                        .copyWith(fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            );
                          }),
                          if (hiddenCategoryCount > 0)
                            Pill(
                              text: '+$hiddenCategoryCount',
                              color: c.textMuted,
                              background: c.surfaceHigh,
                            ),
                        ],
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
                            t.deadlineLabel,
                            style:
                                AppTypography.micro(
                                  t.done
                                      ? c.textMuted
                                      : (isOverdue
                                            ? c.expense
                                            : (isUrgent
                                                  ? c.amber
                                                  : c.textMuted)),
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
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.xxl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status & Urgent / Overdue Badges
                    AppCard(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      background: c.surface,
                      borderColor: c.border.withValues(alpha: 0.55),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: AppSpacing.xs,
                            runSpacing: AppSpacing.xs,
                            children: [
                              Pill(
                                text: currentTask.done
                                    ? 'Selesai'
                                    : 'Belum selesai',
                                color: currentTask.done ? c.teal : c.blue,
                                background: currentTask.done
                                    ? c.tealDim
                                    : c.blueDim,
                              ),
                              if (!currentTask.done && isOverdue)
                                Pill(
                                  text: 'Terlewat',
                                  color: c.expense,
                                  background: c.expenseDim,
                                )
                              else if (!currentTask.done && isUrgent)
                                Pill(
                                  text: 'Mendesak <24 jam',
                                  color: c.amber,
                                  background: c.amberDim,
                                ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            currentTask.title,
                            style: AppTypography.hero(c.text).copyWith(
                              height: 1.15,
                              decoration: currentTask.done
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Categories Card
                    AppCard(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      background: c.surface,
                      borderColor: c.border.withValues(alpha: 0.55),
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
                      padding: const EdgeInsets.all(AppSpacing.md),
                      background: c.surface,
                      borderColor: !currentTask.done && (isOverdue || isUrgent)
                          ? (isOverdue ? c.expense : c.amber)
                          : c.border.withValues(alpha: 0.55),
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
                                  currentTask.deadlineLabel,
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
  final String nextTaskId;
  final ValueChanged<TaskItem> onSave;
  final ValueChanged<List<TaskItem>>? onSaveMany;
  final bool enableBrainDump;

  const TaskFormScreen({
    super.key,
    this.taskToEdit,
    required this.nextTaskId,
    required this.onSave,
    this.onSaveMany,
    this.enableBrainDump = false,
  });

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  late TaskInputMode inputMode;
  late final TextEditingController titleController;
  late final TextEditingController descriptionController;
  late final TextEditingController brainDumpController;

  late List<String> selectedCategories;
  bool isDropdownExpanded = false;
  bool isProcessingBrainDump = false;
  bool showBrainDumpPreview = false;
  List<TaskItem> brainDumpDrafts = <TaskItem>[];
  int? editingBrainDumpIndex;
  String? brainDumpFailure;
  DateTime? selectedDueDate;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    final TaskItem? t = widget.taskToEdit;
    inputMode = TaskInputMode.manual;
    titleController = TextEditingController(text: t?.title ?? '');
    descriptionController = TextEditingController(text: t?.description ?? '');
    brainDumpController = TextEditingController();
    selectedCategories = List.of(t?.categories ?? ['Tugas Kuliah']);
    // Tugas baru dimulai dari hari ini pukul 23:59. Tugas lama memakai dueDate
    // tersimpan, atau dibaca dari teks tenggat lamanya jika dueDate kosong.
    selectedDueDate = t == null
        ? _currentDueOrDefault()
        : (t.dueDate ?? parseSchedule(t.deadline));
  }

  @override
  void dispose() {
    titleController.dispose();
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
    final String text = brainDumpController.text.trim();
    if (text.isEmpty) {
      setState(() {
        errorMessage = 'Tuliskan catatan brain dump terlebih dahulu.';
      });
      return;
    }

    setState(() {
      isProcessingBrainDump = true;
      errorMessage = null;
    });

    List<BrainDumpItem>? aiItems;
    String? aiFailure;
    try {
      aiItems = await BrainDumpAiService().parse(text);
    } on BrainDumpAiException catch (error, stackTrace) {
      aiFailure = error.message;
      debugPrint('Brain Dump Gemini gagal: $error');
      debugPrintStack(stackTrace: stackTrace);
    } catch (error, stackTrace) {
      aiFailure = 'Kesalahan tidak terduga: $error';
      debugPrint('Brain Dump Gemini gagal: $error');
      debugPrintStack(stackTrace: stackTrace);
    }

    final List<TaskItem> drafts = <TaskItem>[];
    if (aiItems != null) {
      for (final BrainDumpItem item in aiItems) {
        if (!item.isTask) continue;
        final TaskItem? draft = _draftFromAiItem(item);
        if (draft != null) drafts.add(draft);
      }
    }
    if (drafts.isEmpty) {
      drafts.addAll(_localTaskDrafts(text));
    }
    if (drafts.isEmpty) {
      setState(() {
        isProcessingBrainDump = false;
        errorMessage = 'Tidak ada tugas yang bisa dibuat dari catatan ini.';
      });
      return;
    }

    setState(() {
      isProcessingBrainDump = false;
      brainDumpDrafts = drafts;
      showBrainDumpPreview = true;
      editingBrainDumpIndex = null;
      inputMode = TaskInputMode.brainDump;
      brainDumpFailure = aiFailure;
      errorMessage = null;
    });
  }

  TaskItem? _draftFromAiItem(BrainDumpItem item) {
    final String cleanTitle = sanitizeBrainDumpText(item.title);
    if (cleanTitle.isEmpty) return null;
    final DateTime dueDate = dueDateForBrainDump(
      aiDate: item.dueDate,
      aiTime: item.dueTime,
      sourceText: '${item.title} ${item.description ?? ''}',
    );
    final String title = _normalizeDraftTitle(cleanTitle, dueDate);
    final String cleanDescription = sanitizeBrainDumpText(item.description ?? '');
    return TaskItem(
      id: '',
      title: title,
      categories: _categoriesFromText(item.category),
      description: cleanDescription.isNotEmpty
          ? cleanDescription
          : 'Pada ${formatDeadline(dueDate).toLowerCase()}, ${title.toLowerCase()}.',
      deadline: formatDeadline(dueDate),
      dueDate: dueDate,
    );
  }

  List<TaskItem> _localTaskDrafts(String text) {
    final String sanitized = sanitizeBrainDumpText(text);
    final String effective = sanitized.isEmpty
        ? 'Selesaikan tugas hari ini'
        : sanitized;
    DateTime? inheritedDue;
    final List<TaskItem> drafts = <TaskItem>[];
    for (final String segment in _splitTaskSegments(effective)) {
      final String clean = segment.trim();
      if (clean.isEmpty) continue;
      final DateTime? explicitDue = parseSchedule(clean);
      final DateTime dueDate = explicitDue ?? inheritedDue ?? dueAtCurrentTime();
      inheritedDue ??= dueDate;
      final String title = _normalizeDraftTitle(
        _extractLocalTaskTitle(clean),
        dueDate,
      );
      drafts.add(
        TaskItem(
          id: '',
          title: title,
          categories: _detectTaskCategories(clean),
          description:
              'Jadwal ${title.toLowerCase()} pada ${formatDeadline(dueDate).toLowerCase()}.',
          deadline: formatDeadline(dueDate),
          dueDate: dueDate,
        ),
      );
    }
    return drafts;
  }

  List<String> _splitTaskSegments(String text) {
    final String normalized = text
        .replaceAll(RegExp(r'[\r\n]+'), '|')
        .replaceAll(
          RegExp(
            r'\s*(?:;|\bdan juga\b|\blalu\b|\bkemudian\b|\bserta\b)\s*',
            caseSensitive: false,
          ),
          '|',
        )
        .replaceAll(RegExp(r'\s+\bdan\b\s+', caseSensitive: false), '|');
    return normalized
        .split('|')
        .map((String part) => part.trim())
        .where((String part) => part.isNotEmpty)
        .toList();
  }

  String _extractLocalTaskTitle(String text) {
    String title = text
        .replaceFirst(
          RegExp(
            r'^(?:hari ini|besok|lusa)\s+jam\s+\d{1,2}(?::\d{2})?\s*(?:pagi|siang|sore|malam)?\s*',
            caseSensitive: false,
          ),
          '',
        )
        .replaceFirst(
          RegExp(
            r'^(?:jam|pukul)\s+\d{1,2}(?::\d{2})?\s*(?:pagi|siang|sore|malam)?\s*',
            caseSensitive: false,
          ),
          '',
        )
        .replaceFirst(
          RegExp(
            r'^(?:ada|tolong|jangan lupa|ingat|mohon|please|pls)\s+',
            caseSensitive: false,
          ),
          '',
        )
        .replaceFirst(
          RegExp(
            r'\s+(?:hari ini|besok|lusa|jam|pukul|tanggal)\b.*$',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
    if (title.isEmpty) title = text.trim();
    return title;
  }

  String _normalizeDraftTitle(String raw, DateTime dueDate) {
    String title = sanitizeBrainDumpText(raw).trim();
    final String normalized = title.toLowerCase();
    if ((normalized == 'jogging' || normalized == 'joging') &&
        dueDate.hour < 12) {
      title = 'Jogging pagi';
    }
    if (title.length < 4) {
      title = 'Tugas $title';
    }
    if (title.isNotEmpty) {
      title = '${title[0].toUpperCase()}${title.substring(1)}';
    }
    if (title.length > 100) {
      title = '${title.substring(0, 97)}...';
    }
    return title;
  }

  List<String> _categoriesFromText(String? raw) {
    final List<String> categories = raw == null
        ? <String>[]
        : raw
              .split(',')
              .map((String value) => value.trim())
              .where(availableCategories.contains)
              .toList();
    return categories.isEmpty ? const <String>['Pribadi'] : categories;
  }

  List<String> _detectTaskCategories(String text) {
    final String lower = text.toLowerCase();
    final List<String> detected = <String>[];
    if (lower.contains('kalkulus') ||
        lower.contains('quiz') ||
        lower.contains('kuis') ||
        lower.contains('tugas') ||
        lower.contains('laporan') ||
        lower.contains('praktikum') ||
        lower.contains('kuliah')) {
      detected.add('Tugas Kuliah');
    }
    if (lower.contains('laundry') || lower.contains('cuci')) {
      detected.add('Laundry');
    }
    if (lower.contains('jogging') ||
        lower.contains('gym') ||
        lower.contains('olahraga') ||
        lower.contains('fitness')) {
      detected.add('Olahraga');
    }
    if (lower.contains('bem') ||
        lower.contains('rapat') ||
        lower.contains('organisasi') ||
        lower.contains('proker')) {
      detected.add('Organisasi');
    }
    if (lower.contains('bayar') ||
        lower.contains('kos') ||
        lower.contains('uang')) {
      detected.add('Keuangan');
    }
    if (detected.isEmpty || lower.contains('pribadi')) {
      detected.add('Pribadi');
    }
    return detected;
  }

  void _editBrainDumpDraft(int index) {
    if (index < 0 || index >= brainDumpDrafts.length) return;
    final TaskItem draft = brainDumpDrafts[index];
    setState(() {
      editingBrainDumpIndex = index;
      inputMode = TaskInputMode.manual;
      titleController.text = draft.title;
      descriptionController.text = draft.description;
      selectedCategories = List<String>.of(draft.categories);
      selectedDueDate = draft.dueDate;
      errorMessage = null;
    });
  }

  void _deleteBrainDumpDraft(int index) {
    if (index < 0 || index >= brainDumpDrafts.length) return;
    setState(() {
      brainDumpDrafts.removeAt(index);
      if (editingBrainDumpIndex == index) {
        editingBrainDumpIndex = null;
      } else if (editingBrainDumpIndex != null &&
          editingBrainDumpIndex! > index) {
        editingBrainDumpIndex = editingBrainDumpIndex! - 1;
      }
    });
  }

  void _backToBrainDumpPreview() {
    setState(() {
      editingBrainDumpIndex = null;
      showBrainDumpPreview = true;
      inputMode = TaskInputMode.brainDump;
      errorMessage = null;
    });
  }

  void _restartBrainDump() {
    setState(() {
      brainDumpDrafts = <TaskItem>[];
      showBrainDumpPreview = false;
      editingBrainDumpIndex = null;
      inputMode = TaskInputMode.brainDump;
      brainDumpFailure = null;
      errorMessage = null;
    });
  }

  void _saveBrainDumpDrafts() {
    if (brainDumpDrafts.isEmpty) {
      setState(() {
        errorMessage = 'Belum ada tugas untuk disimpan.';
      });
      return;
    }
    final DateTime now = DateTime.now();
    for (final TaskItem draft in brainDumpDrafts) {
      final DateTime? dueDate = draft.dueDate;
      if (draft.title.trim().length < 4) {
        setState(() {
          errorMessage = 'Judul "$draft.title" terlalu pendek (minimal 4 karakter).';
        });
        return;
      }
      if (draft.categories.isEmpty) {
        setState(() {
          errorMessage = 'Pilih minimal 1 kategori untuk "$draft.title".';
        });
        return;
      }
      if (dueDate == null || dueDate.isBefore(now)) {
        setState(() {
          errorMessage = 'Tenggat "$draft.title" sudah lewat. Periksa kembali.';
        });
        return;
      }
    }

    final List<TaskItem> tasks = <TaskItem>[];
    for (int index = 0; index < brainDumpDrafts.length; index++) {
      final TaskItem draft = brainDumpDrafts[index];
      tasks.add(
        draft.copyWith(
          id: index == 0 ? widget.nextTaskId : newDocumentId(),
          deadline: formatDeadline(draft.dueDate!),
        ),
      );
    }
    if (widget.onSaveMany != null) {
      widget.onSaveMany!(tasks);
    } else {
      for (final TaskItem task in tasks) {
        widget.onSave(task);
      }
    }
    Navigator.of(context).pop();
  }

  /// Tenggat saat ini; jika belum dipilih, hari ini pukul 23:59.
  DateTime _currentDueOrDefault() {
    final DateTime now = DateTime.now();
    return selectedDueDate ??
        DateTime(now.year, now.month, now.day, defaultDueHour, defaultDueMinute);
  }

  void _setDueDate(DateTime value) {
    setState(() {
      selectedDueDate = value;
      errorMessage = null;
    });
  }

  /// Tenggat dianggap terlewat hanya jika baru dipilih/diubah. Tugas lama yang
  /// memang sudah lewat tetap bisa diedit tanpa mengubah tenggatnya.
  bool get _isDueDateInPast {
    final DateTime? due = selectedDueDate;
    if (due == null || !due.isBefore(DateTime.now())) {
      return false;
    }
    return widget.taskToEdit?.dueDate != due;
  }

  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();
    final DateTime current = _currentDueOrDefault();
    DateTime firstDate = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 30));
    DateTime lastDate = DateTime(now.year + 1, now.month, now.day);
    // initialDate wajib berada di antara firstDate dan lastDate, termasuk saat
    // mengedit tugas lama.
    if (current.isBefore(firstDate)) {
      firstDate = DateTime(current.year, current.month, current.day);
    }
    if (current.isAfter(lastDate)) {
      lastDate = DateTime(current.year, current.month, current.day);
    }

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (pickedDate == null || !mounted) return;

    _setDueDate(
      DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        current.hour,
        current.minute,
      ),
    );
  }

  Future<void> _pickTime() async {
    final DateTime current = _currentDueOrDefault();
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
      helpText: 'PILIH JAM TENGGAT',
      builder: (BuildContext context, Widget? child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (pickedTime == null || !mounted) return;

    _setDueDate(
      DateTime(
        current.year,
        current.month,
        current.day,
        pickedTime.hour,
        pickedTime.minute,
      ),
    );
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

    final DateTime? dueDate = selectedDueDate;
    // Tugas lama tanpa dueDate masih boleh disimpan dengan teks tenggat aslinya.
    final String deadline = dueDate != null
        ? formatDeadline(dueDate)
        : (widget.taskToEdit?.deadline ?? '');
    if (deadline.isEmpty) {
      setState(() {
        errorMessage = 'Pilih tanggal dan jam tenggat.';
      });
      return;
    }

    if (_isDueDateInPast) {
      setState(() {
        errorMessage =
            'Tenggat sudah lewat. Pilih tanggal atau jam yang akan datang.';
      });
      return;
    }

    final description = descriptionController.text.trim();

    final TaskItem task = TaskItem(
      id: widget.taskToEdit?.id ?? widget.nextTaskId,
      title: title,
      categories: selectedCategories,
      description: description,
      deadline: deadline,
      dueDate: dueDate,
      done: widget.taskToEdit?.done ?? false,
    );

    final int? draftIndex = editingBrainDumpIndex;
    if (draftIndex != null) {
      setState(() {
        brainDumpDrafts[draftIndex] = task.copyWith(
          id: brainDumpDrafts[draftIndex].id,
        );
        editingBrainDumpIndex = null;
        showBrainDumpPreview = true;
        inputMode = TaskInputMode.brainDump;
        errorMessage = null;
      });
      return;
    }

    widget.onSave(task);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = ThemeScope.of(context).colors;
    final bool isEditing = widget.taskToEdit != null;
    final bool isEditingDraft = editingBrainDumpIndex != null;
    final bool isPreviewing = showBrainDumpPreview && !isEditingDraft;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            isEditingDraft ? Icons.arrow_back_rounded : Icons.close_rounded,
            color: c.text,
          ),
          onPressed: () {
            if (isEditingDraft) {
              _backToBrainDumpPreview();
              return;
            }
            Navigator.of(context).pop();
          },
          tooltip: isEditingDraft ? 'Kembali ke pratinjau' : 'Batal',
        ),
        title: Text(
          isEditing
              ? 'Edit Tugas'
              : isEditingDraft
              ? 'Edit Hasil AI'
              : isPreviewing
              ? 'Pratinjau Tugas AI'
              : 'Tambah Tugas Baru',
          style: AppTypography.titleLarge(c.text),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Mode Switcher Tabs
            if (widget.enableBrainDump &&
                !isEditing && !isPreviewing && !isEditingDraft) ...[
              Container(
                margin: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  0,
                ),
                padding: const EdgeInsets.all(AppSpacing.xxs),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(AppSpacing.md),
                  border: Border.all(color: c.border.withValues(alpha: 0.55)),
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

                    if (isPreviewing) ...[
                      _buildBrainDumpPreview(c),
                    ] else if (!isEditing &&
                        inputMode == TaskInputMode.brainDump) ...[
                      AppCard(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        background: c.surface,
                        borderColor: c.ai.withValues(alpha: 0.55),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(AppSpacing.xs),
                                  decoration: BoxDecoration(
                                    color: c.aiDim,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.auto_awesome_rounded,
                                    size: AppSpacing.iconSmall,
                                    color: c.ai,
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
                            const SizedBox(height: AppSpacing.md),

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
                                  color: c.ai,
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
                        background: c.surface,
                        borderColor: c.border.withValues(alpha: 0.55),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _formLabel(c, 'JUDUL TUGAS *'),
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
                        background: c.surface,
                        borderColor: c.border.withValues(alpha: 0.55),
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
                        background: c.surface,
                        borderColor: c.border.withValues(alpha: 0.55),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _formLabel(c, 'TENGGAT WAKTU *'),
                            const SizedBox(height: AppSpacing.xxs),
                            Row(
                              children: [
                                Expanded(
                                  child: _scheduleTile(
                                    c,
                                    icon: Icons.calendar_month_rounded,
                                    label: selectedDueDate == null
                                        ? 'Pilih tanggal'
                                        : formatDueDateLabel(selectedDueDate!),
                                    onTap: _pickDate,
                                    tooltip: 'Pilih Tanggal',
                                    semanticLabel: 'Pilih tanggal tenggat',
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Expanded(
                                  child: _scheduleTile(
                                    c,
                                    icon: Icons.schedule_rounded,
                                    label: selectedDueDate == null
                                        ? 'Pilih jam'
                                        : formatDueTimeLabel(selectedDueDate!),
                                    onTap: _pickTime,
                                    tooltip: 'Pilih Jam',
                                    semanticLabel: 'Pilih jam tenggat',
                                  ),
                                ),
                              ],
                            ),
                            if (_isDueDateInPast) ...[
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                'Tenggat ini sudah lewat.',
                                style: AppTypography.caption(c.expense),
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
                            _formLabel(c, 'DESKRIPSI / CATATAN DETAIL'),
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
            if (inputMode == TaskInputMode.manual && !isPreviewing) ...[
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
                      : isEditingDraft
                      ? 'Simpan perubahan hasil AI'
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
                      isEditing
                          ? 'Simpan Perubahan'
                          : isEditingDraft
                          ? 'Simpan Perubahan AI'
                          : 'Tambah Tugas',
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

  Widget _buildBrainDumpPreview(AppColors c) {
    final int count = brainDumpDrafts.length;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      background: c.surface,
      borderColor: c.ai.withValues(alpha: 0.55),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.xs),
                decoration: BoxDecoration(
                  color: c.aiDim,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  size: AppSpacing.iconSmall,
                  color: c.ai,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Periksa hasil AI sebelum disimpan',
                      style: AppTypography.label(c.text)
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      count == 0
                          ? 'Semua tugas dihapus. Proses ulang atau isi manual.'
                          : '$count tugas ditemukan. Edit atau hapus dulu sebelum menyimpan.',
                      style: AppTypography.caption(c.textMuted),
                    ),
                    if (brainDumpFailure != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Mode offline: $brainDumpFailure',
                        style: AppTypography.caption(c.warning),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (count == 0) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: c.surfaceHigh,
                borderRadius: BorderRadius.circular(AppSpacing.md),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.task_alt_rounded,
                    size: AppSpacing.xl,
                    color: c.textMuted,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Belum ada tugas dalam pratinjau.',
                    style: AppTypography.label(c.textMuted),
                  ),
                ],
              ),
            ),
          ] else ...[
            ...brainDumpDrafts.indexed.map(
              ((int index, TaskItem draft) entry) =>
                  _buildBrainDumpDraftCard(c, entry.$1, entry.$2),
            ),
            const SizedBox(height: AppSpacing.sm),
            PressableScale(
              onTap: _saveBrainDumpDrafts,
              semanticLabel: 'Simpan $count tugas',
              child: Container(
                width: double.infinity,
                height: AppSpacing.target,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.ai,
                  borderRadius: BorderRadius.circular(AppSpacing.md),
                ),
                child: Text(
                  'Simpan $count Tugas',
                  style: AppTypography.button(c.onAccent),
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: PressableScale(
                  onTap: _restartBrainDump,
                  semanticLabel: 'Proses ulang brain dump',
                  child: Container(
                    height: AppSpacing.targetCompact,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: c.surfaceHigh,
                      borderRadius: BorderRadius.circular(AppSpacing.sm),
                      border: Border.all(color: c.border),
                    ),
                    child: Text(
                      'Proses Ulang',
                      style: AppTypography.micro(c.text)
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: PressableScale(
                  onTap: () {
                    setState(() {
                      showBrainDumpPreview = false;
                      editingBrainDumpIndex = null;
                      inputMode = TaskInputMode.manual;
                      errorMessage = null;
                    });
                  },
                  semanticLabel: 'Isi manual',
                  child: Container(
                    height: AppSpacing.targetCompact,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: c.surfaceHigh,
                      borderRadius: BorderRadius.circular(AppSpacing.sm),
                      border: Border.all(color: c.border),
                    ),
                    child: Text(
                      'Isi Manual',
                      style: AppTypography.micro(c.text)
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBrainDumpDraftCard(AppColors c, int index, TaskItem draft) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      background: c.surfaceHigh,
      borderColor: c.border.withValues(alpha: 0.7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.aiDim,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${index + 1}',
                  style: AppTypography.micro(c.ai)
                      .copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  draft.title,
                  style: AppTypography.label(c.text)
                      .copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              PressableScale(
                onTap: () => _deleteBrainDumpDraft(index),
                semanticLabel: 'Hapus tugas ${index + 1}',
                tooltip: 'Hapus tugas',
                child: Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.expenseDim,
                    borderRadius: BorderRadius.circular(AppSpacing.xs),
                  ),
                  child: Icon(
                    Icons.delete_outline_rounded,
                    size: 16,
                    color: c.expense,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xxs,
            runSpacing: 4,
            children: [
              ...draft.categories.map(
                (String category) => Pill(
                  text: category,
                  color: c.blue,
                  background: c.blueDim,
                ),
              ),
              Pill(
                text: draft.deadlineLabel,
                color: c.amber,
                background: c.amberDim,
              ),
            ],
          ),
          if (draft.description.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              draft.description,
              style: AppTypography.caption(c.textSub),
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.xs),
          PressableScale(
            onTap: () => _editBrainDumpDraft(index),
            semanticLabel: 'Edit tugas ${index + 1}',
            child: Container(
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(AppSpacing.xs),
                border: Border.all(color: c.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.edit_outlined, size: 14, color: c.text),
                  const SizedBox(width: 4),
                  Text(
                    'Edit Tugas Ini',
                    style: AppTypography.micro(c.text)
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ],
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
    final Color accent = mode == TaskInputMode.brainDump ? c.ai : c.blue;
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
            color: isSelected ? accent : c.transparent,
            borderRadius: BorderRadius.circular(AppSpacing.sm),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: AppSpacing.iconSmall - 2,
                color: isSelected ? c.onAccent : accent,
              ),
              const SizedBox(width: AppSpacing.xxs),
              Text(
                label,
                style: AppTypography.label(isSelected ? c.onAccent : accent)
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

  Widget _scheduleTile(
    AppColors c, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required String tooltip,
    required String semanticLabel,
  }) {
    return PressableScale(
      onTap: onTap,
      tooltip: tooltip,
      semanticLabel: semanticLabel,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        decoration: BoxDecoration(
          color: c.blueDim,
          borderRadius: BorderRadius.circular(AppSpacing.md),
          border: Border.all(color: c.blue),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: AppSpacing.iconSmall, color: c.blue),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.label(c.blue),
              ),
            ),
          ],
        ),
      ),
    );
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
