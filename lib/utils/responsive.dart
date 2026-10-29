import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

class Responsive {
  static Size size(BuildContext context) => MediaQuery.sizeOf(context);

  static double width(BuildContext context) => size(context).width;

  static double height(BuildContext context) => size(context).height;

  static bool isCompact(BuildContext context) => width(context) < 360;

  static double scale(BuildContext context) =>
      (width(context) / 390).clamp(0.85, 1.4);

  static double navHeight(BuildContext context) =>
      (AppSpacing.navHeight * scale(context)).clamp(56, 76);

  static EdgeInsets pagePadding(BuildContext context) {
    final double screenWidth = width(context);
    final double horizontal = screenWidth >= 900
        ? AppSpacing.xxl
        : (screenWidth < 360 ? AppSpacing.sm : AppSpacing.md);
    return EdgeInsets.symmetric(horizontal: horizontal);
  }

  static double contentMaxWidth(BuildContext context) {
    final double screenWidth = width(context);
    return screenWidth > 720 ? 720 : screenWidth;
  }
}
