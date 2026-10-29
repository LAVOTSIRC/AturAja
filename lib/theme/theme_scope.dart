import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/theme_provider.dart';

export '../providers/theme_provider.dart';

class ThemeScope extends StatelessWidget {
  final ThemeController controller;
  final Widget child;

  const ThemeScope({super.key, required this.controller, required this.child});

  static ThemeController of(BuildContext context) {
    final _ThemeNotifier? scope = context
        .dependOnInheritedWidgetOfExactType<_ThemeNotifier>();
    assert(scope != null, 'No ThemeScope found in context');
    return scope!.notifier!;
  }

  static ThemeController read(BuildContext context) {
    return Provider.of<ThemeController>(context, listen: false);
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ThemeController>.value(
      value: controller,
      child: _ThemeNotifier(notifier: controller, child: child),
    );
  }
}

class _ThemeNotifier extends InheritedNotifier<ThemeController> {
  const _ThemeNotifier({required super.notifier, required super.child});
}
