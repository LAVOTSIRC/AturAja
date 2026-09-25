import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/settings_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/theme_scope.dart';
import '../widgets/common.dart';
import '../widgets/quick_add_modal.dart';
import 'finance_screen.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'scan_screen.dart';
import 'task_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int tab = 0;
  List<TaskItem> tasks = List<TaskItem>.of(sampleTasks);
  int nextTaskId = sampleTasks.length + 1;
  late final SettingsController settings;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    settings = SettingsController();
    _pageController = PageController(initialPage: tab);
  }

  @override
  void dispose() {
    settings.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    setState(() => tab = index);
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _openQuickAdd(QuickAddMode mode) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: ThemeScope.of(context).colors.transparent,
      builder: (_) => QuickAddModal(initialMode: mode),
    );
  }

  void _openTaskAdd() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TaskFormScreen(onSave: _saveTask)),
    );
  }

  void _saveTask(TaskItem task) {
    final bool isUpdate = tasks.any((item) => item.id == task.id);
    setState(() {
      final index = tasks.indexWhere((item) => item.id == task.id);
      if (index >= 0) {
        tasks = [...tasks]..[index] = task;
      } else {
        tasks = [...tasks, task];
      }
    });
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(
          isUpdate
              ? 'Tugas berhasil diperbarui.'
              : 'Tugas berhasil ditambahkan.',
        ),
      ),
    );
  }

  void _toggleTask(int id) {
    setState(() {
      tasks = tasks
          .map(
            (TaskItem task) =>
                task.id == id ? task.copyWith(done: !task.done) : task,
          )
          .toList();
    });
  }

  void _openScan() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ScanScreen(),
        fullscreenDialog: true,
      ),
    );
  }

  void _logout() {
    final NavigatorState navigator = Navigator.of(context);
    navigator.pushReplacement(
      MaterialPageRoute(
        builder: (_) => LoginScreen(
          onLogin: () => navigator.pushReplacement(
            MaterialPageRoute(builder: (_) => const MainShell()),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = ThemeScope.of(context).colors;
    final List<Widget> screens = [
      HomeScreen(
        onAdd: _openQuickAdd,
        onScan: _openScan,
        onAddTask: _openTaskAdd,
      ),
      FinanceScreen(onScan: _openScan),
      TaskScreen(
        tasks: tasks,
        onAddTask: _openTaskAdd,
        onToggleTask: _toggleTask,
        onSaveTask: _saveTask,
      ),
      ProfileScreen(settings: settings, onLogout: _logout),
    ];

    return Scaffold(
      backgroundColor: c.shell,
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: (index) => setState(() => tab = index),
            children: screens,
          ),
          if (tab == 0)
            Positioned(
              bottom: AppSpacing.xl,
              right: AppSpacing.md,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  PressableScale(
                    onTap: _openScan,
                    semanticLabel: 'Scan struk',
                    tooltip: 'Scan struk',
                    child: Container(
                      width: AppSpacing.target,
                      height: AppSpacing.target,
                      decoration: BoxDecoration(
                        color: c.surface,
                        border: Border.all(color: c.border),
                        borderRadius: BorderRadius.circular(AppSpacing.sm),
                        boxShadow: [
                          BoxShadow(
                            color: c.shadow,
                            blurRadius: AppSpacing.md,
                            offset: const Offset(0, AppSpacing.xxs),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.document_scanner_outlined,
                        size: AppSpacing.iconSmall,
                        color: c.blue,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  PressableScale(
                    onTap: () => _openQuickAdd(QuickAddMode.quick),
                    semanticLabel: 'Tambah catatan',
                    tooltip: 'Tambah catatan',
                    child: Container(
                      width: AppSpacing.fabHeight,
                      height: AppSpacing.fabHeight,
                      decoration: BoxDecoration(
                        color: c.blue,
                        borderRadius: BorderRadius.circular(AppSpacing.md),
                        boxShadow: [
                          BoxShadow(
                            color: c.blue.withValues(alpha: 0.4),
                            blurRadius: AppSpacing.xl,
                            offset: const Offset(0, AppSpacing.xxs),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.add,
                        size: AppSpacing.iconMedium,
                        color: c.onAccent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: c.navBg,
          border: Border(top: BorderSide(color: c.border)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: AppSpacing.navHeight,
            child: Row(
              children: [
                _navItem(c, 0, Icons.home_outlined, 'Beranda'),
                _navItem(
                  c,
                  1,
                  Icons.account_balance_wallet_outlined,
                  'Keuangan',
                ),
                _navItem(c, 2, Icons.task_alt_outlined, 'Tugas'),
                _navItem(c, 3, Icons.person_outline, 'Profil'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(AppColors c, int index, IconData icon, String label) {
    final bool active = tab == index;
    return Expanded(
      child: PressableScale(
        onTap: () => _onTabTapped(index),
        selected: active,
        semanticLabel: label,
        tooltip: label,
        excludeSemantics: true,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          constraints: const BoxConstraints(minHeight: AppSpacing.navHeight),
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          decoration: BoxDecoration(
            color: active ? c.blueDim : c.transparent,
            borderRadius: BorderRadius.circular(AppSpacing.huge),
            border: Border.all(color: active ? c.borderAccent : c.transparent),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (active)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Center(
                    child: Container(
                      width: AppSpacing.lg,
                      height: AppSpacing.xxs,
                      decoration: BoxDecoration(
                        color: c.blue,
                        borderRadius: BorderRadius.circular(AppSpacing.huge),
                      ),
                    ),
                  ),
                ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: AppSpacing.iconMedium,
                    color: active ? c.blue : c.textMuted,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    label,
                    style: AppTypography.micro(active ? c.blue : c.textMuted)
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
