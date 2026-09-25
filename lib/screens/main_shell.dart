import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/theme_scope.dart';
import '../widgets/common.dart';
import '../widgets/quick_add_modal.dart';
import 'finance_screen.dart';
import 'home_screen.dart';
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
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: tab);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    setState(() => tab = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _openQuickAdd({bool startInBrainDump = false}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: ThemeScope.of(context).colors.transparent,
      builder: (_) => QuickAddModal(startInBrainDump: startInBrainDump),
    );
  }

  void _openScan() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ScanScreen(),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = ThemeScope.of(context).colors;
    final List<Widget> screens = [
      HomeScreen(
        onAdd: () => _openQuickAdd(),
        onScan: _openScan,
        onBrainDump: () => _openQuickAdd(startInBrainDump: true),
      ),
      FinanceScreen(onScan: _openScan),
      const TaskScreen(),
      const ProfileScreen(),
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
