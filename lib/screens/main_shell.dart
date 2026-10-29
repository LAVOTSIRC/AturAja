import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/theme_scope.dart';
import '../utils/responsive.dart';
import '../widgets/common.dart';

class MainShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  final List<Widget> children;

  const MainShell({
    super.key,
    required this.navigationShell,
    required this.children,
  });

  void _onTabTapped(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = ThemeScope.of(context).colors;
    final int tab = navigationShell.currentIndex;

    return Scaffold(
      backgroundColor: c.shell,
      body: _SwipeableBranchView(
        navigationShell: navigationShell,
        children: children,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: c.navBg,
          border: Border(top: BorderSide(color: c.border)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: Responsive.navHeight(context),
            child: Row(
              children: <Widget>[
                _navItem(c, tab, 0, Icons.home_outlined, 'Beranda'),
                _navItem(
                  c,
                  tab,
                  1,
                  Icons.account_balance_wallet_outlined,
                  'Keuangan',
                ),
                _navItem(c, tab, 2, Icons.task_alt_outlined, 'Tugas'),
                _navItem(c, tab, 3, Icons.person_outline, 'Profil'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(
    AppColors c,
    int activeIndex,
    int index,
    IconData icon,
    String label,
  ) {
    final bool active = activeIndex == index;
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
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
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
        ),
      ),
    );
  }
}

/// Menampilkan seluruh branch Navigator dalam satu [PageView] agar perpindahan
/// tab bisa diikuti jari secara langsung (interaktif), bukan loncat setelah
/// gesture selesai. Halaman yang tidak aktif tetap disimpan agar state dan
/// posisi scroll tidak hilang.
class _SwipeableBranchView extends StatefulWidget {
  final StatefulNavigationShell navigationShell;
  final List<Widget> children;

  const _SwipeableBranchView({
    required this.navigationShell,
    required this.children,
  });

  @override
  State<_SwipeableBranchView> createState() => _SwipeableBranchViewState();
}

class _SwipeableBranchViewState extends State<_SwipeableBranchView> {
  late final PageController _pageController;
  late int _currentPage;
  int _animationToken = 0;
  int? _programmaticTarget;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.navigationShell.currentIndex;
    _pageController = PageController(initialPage: _currentPage);
  }

  @override
  void didUpdateWidget(covariant _SwipeableBranchView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final int target = widget.navigationShell.currentIndex;
    if (target != _currentPage) {
      _currentPage = target;
      _animateToPage(target);
    }
  }

  Future<void> _animateToPage(int target) async {
    final int token = ++_animationToken;
    if (!_pageController.hasClients) {
      _programmaticTarget = null;
      return;
    }

    _programmaticTarget = target;
    try {
      await _pageController.animateToPage(
        target,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    } finally {
      if (mounted && token == _animationToken) {
        _programmaticTarget = null;
        final double? page = _pageController.page;
        if (page != null) {
          final int settledPage = page.round();
          if (settledPage != _currentPage) {
            _currentPage = settledPage;
            widget.navigationShell.goBranch(settledPage);
          }
        }
      }
    }
  }

  void _onPageChanged(int index) {
    if (_programmaticTarget != null) {
      if (index == _programmaticTarget) {
        _programmaticTarget = null;
      }
      return;
    }
    if (index == _currentPage) {
      return;
    }

    _currentPage = index;
    widget.navigationShell.goBranch(index);
  }

  @override
  void dispose() {
    _animationToken++;
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView(
      controller: _pageController,
      allowImplicitScrolling: true,
      onPageChanged: _onPageChanged,
      children: <Widget>[
        for (int index = 0; index < widget.children.length; index++)
          _BranchPage(
            key: ValueKey<int>(index),
            active: index == widget.navigationShell.currentIndex,
            child: widget.children[index],
          ),
      ],
    );
  }
}

class _BranchPage extends StatefulWidget {
  final Widget child;
  final bool active;

  const _BranchPage({super.key, required this.child, required this.active});

  @override
  State<_BranchPage> createState() => _BranchPageState();
}

class _BranchPageState extends State<_BranchPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return TickerMode(enabled: widget.active, child: widget.child);
  }
}
