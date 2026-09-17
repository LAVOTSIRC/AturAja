import 'package:flutter/material.dart';
import '../theme/theme_scope.dart';
import '../widgets/quick_add_modal.dart';
import 'finance_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'scan_screen.dart';
import 'task_screen.dart';

/// Root shell holding the bottom navigation, floating action buttons and
/// the four main tabs (Beranda, Keuangan, Tugas, Profil).
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int tab = 0;

  void _openQuickAdd() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const QuickAddModal(),
    );
  }

  void _openScan() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ScanScreen(), fullscreenDialog: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = ThemeScope.of(context).colors;

    final screens = [
      HomeScreen(onAdd: _openQuickAdd, onScan: _openScan),
      const FinanceScreen(),
      const TaskScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: c.bg,
      body: Stack(
        children: [
          IndexedStack(index: tab, children: screens),
          Positioned(
            bottom: 24,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: _openScan,
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: c.surface,
                      border: Border.all(color: c.border),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 16, offset: Offset(0, 4))],
                    ),
                    child: Icon(Icons.document_scanner_outlined, size: 19, color: c.blue),
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _openQuickAdd,
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: c.blue,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: c.blue.withValues(alpha: 0.4), blurRadius: 24, offset: const Offset(0, 4))],
                    ),
                    child: const Icon(Icons.add, size: 24, color: Colors.black),
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
            height: 62,
            child: Row(
              children: [
                _navItem(c, 0, Icons.home_outlined, 'Beranda'),
                _navItem(c, 1, Icons.account_balance_wallet_outlined, 'Keuangan'),
                _navItem(c, 2, Icons.task_alt_outlined, 'Tugas'),
                _navItem(c, 3, Icons.person_outline, 'Profil'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(dynamic c, int index, IconData icon, String label) {
    final active = tab == index;
    final activeColor = c.blue;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => tab = index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: active ? activeColor : c.textMuted),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: active ? activeColor : c.textMuted)),
          ],
        ),
      ),
    );
  }
}
