import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../data/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/theme_scope.dart';
import '../widgets/common.dart';
import 'brain_dump_finance_screen.dart';
import 'finance_screen.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'scan_screen.dart';
import 'task_screen.dart';

class MainShell extends StatefulWidget {
  final AppStore? store;

  const MainShell({super.key, this.store});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int tab = 0;
  late final AppStore _store;
  late final bool _ownsStore;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _ownsStore = widget.store == null;
    _store = widget.store ?? AppStore.inMemory();
    _pageController = PageController(initialPage: tab);
  }

  @override
  void dispose() {
    if (_ownsStore) {
      _store.dispose();
    }
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

  Future<void> _openBrainDump() async {
    final TransactionItem? note = await Navigator.of(context)
        .push<TransactionItem>(
          MaterialPageRoute(builder: (_) => const BrainDumpFinanceScreen()),
        );
    if (note == null || !mounted) {
      return;
    }
    _store.transactionsChanged();
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(
          note.amount >= 0
              ? 'Catatan keuangan "${note.label}" dicatat.'
              : 'Catatan pengeluaran "${note.label}" dicatat.',
        ),
      ),
    );
  }

  void _openTaskAdd() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TaskFormScreen(onSave: _saveTask)),
    );
  }

  void _saveTask(TaskItem task) {
    final bool isUpdate = _store.tasks.any((item) => item.id == task.id);
    _store.upsertTask(task);
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
    _store.toggleTask(id);
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
            MaterialPageRoute(builder: (_) => MainShell(store: widget.store)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = ThemeScope.of(context).colors;
    return AnimatedBuilder(
      animation: _store,
      builder: (BuildContext context, Widget? child) {
        final List<Widget> screens = [
          HomeScreen(
            onScan: _openScan,
            onAddTask: _openTaskAdd,
            onBrainDump: _openBrainDump,
            userName: _store.profile.fullName,
          ),
          FinanceScreen(
            onScan: _openScan,
            onTransactionsChanged: _store.transactionsChanged,
          ),
          TaskScreen(
            tasks: _store.tasks,
            onAddTask: _openTaskAdd,
            onToggleTask: _toggleTask,
            onSaveTask: _saveTask,
          ),
          ProfileScreen(
            settings: _store.settings,
            initialProfile: _store.profile,
            onProfileChanged: _store.updateProfile,
            onLogout: _logout,
          ),
        ];

        return Scaffold(
          backgroundColor: c.shell,
          body: PageView(
            controller: _pageController,
            onPageChanged: (index) => setState(() => tab = index),
            children: screens,
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
      },
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
