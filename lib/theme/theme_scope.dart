import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Holds the current theme (dark/light) and notifies listeners on toggle.
class ThemeController extends ChangeNotifier {
  bool isDark = true;

  AppColors get colors => isDark ? AppColors.dark : AppColors.light;

  void toggle() {
    isDark = !isDark;
    notifyListeners();
  }
}

/// Makes [ThemeController] available to the whole widget tree below it.
class ThemeScope extends InheritedNotifier<ThemeController> {
  const ThemeScope({
    super.key,
    required ThemeController controller,
    required super.child,
  }) : super(notifier: controller);

  static ThemeController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ThemeScope>();
    assert(scope != null, 'No ThemeScope found in context');
    return scope!.notifier!;
  }
}
