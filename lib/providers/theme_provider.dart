import 'package:flutter/foundation.dart';

import '../theme/app_colors.dart';

class ThemeController extends ChangeNotifier {
  bool isDark;

  ThemeController({this.isDark = true});

  AppColors get colors => isDark ? AppColors.dark : AppColors.light;

  void setDark(bool value) {
    if (isDark == value) {
      return;
    }
    isDark = value;
    notifyListeners();
  }

  void toggle() => setDark(!isDark);

  Map<String, dynamic> toJson() => <String, dynamic>{'isDark': isDark};

  void applyJson(Map<String, dynamic> json) {
    setDark(json['isDark'] as bool? ?? isDark);
  }
}
