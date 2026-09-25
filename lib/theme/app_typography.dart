import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTypography {
  static const double font10 = 10;
  static const double font11 = 11;
  static const double font12 = 12;
  static const double font13 = 13;
  static const double font14 = 14;
  static const double font16 = 16;
  static const double font18 = 18;
  static const double font22 = 22;
  static const double font30 = 30;
  static const double font36 = 36;

  static TextStyle heroLarge(Color color) => TextStyle(
    fontSize: font36,
    fontWeight: FontWeight.w800,
    color: color,
    letterSpacing: -0.5,
  );

  static TextStyle hero(Color color) => TextStyle(
    fontSize: font30,
    fontWeight: FontWeight.w700,
    color: color,
    letterSpacing: -0.5,
  );

  static TextStyle display(Color color) =>
      TextStyle(fontSize: font22, fontWeight: FontWeight.w700, color: color);

  static TextStyle titleLarge(Color color) =>
      TextStyle(fontSize: font18, fontWeight: FontWeight.w700, color: color);

  static TextStyle title(Color color) =>
      TextStyle(fontSize: font16, fontWeight: FontWeight.w700, color: color);

  static TextStyle bodyLarge(Color color) =>
      TextStyle(fontSize: font16, fontWeight: FontWeight.w500, color: color);

  static TextStyle body(Color color) =>
      TextStyle(fontSize: font14, fontWeight: FontWeight.w400, color: color);

  static TextStyle label(Color color) =>
      TextStyle(fontSize: font13, fontWeight: FontWeight.w500, color: color);

  static TextStyle button(Color color) =>
      TextStyle(fontSize: font14, fontWeight: FontWeight.w600, color: color);

  static TextStyle caption(Color color) =>
      TextStyle(fontSize: font12, fontWeight: FontWeight.w400, color: color);

  static TextStyle meta(Color color) =>
      TextStyle(fontSize: font11, fontWeight: FontWeight.w400, color: color);

  static TextStyle micro(Color color) =>
      TextStyle(fontSize: font10, fontWeight: FontWeight.w500, color: color);

  static TextStyle overline(Color color) => TextStyle(
    fontSize: font10,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.1,
    color: color,
  );

  static TextTheme apply(TextTheme base, Color color) => base.copyWith(
    displayLarge: base.displayLarge?.copyWith(fontSize: font36, color: color),
    headlineLarge: base.headlineLarge?.copyWith(fontSize: font30, color: color),
    titleLarge: base.titleLarge?.copyWith(fontSize: font18, color: color),
    titleMedium: base.titleMedium?.copyWith(fontSize: font16, color: color),
    bodyLarge: base.bodyLarge?.copyWith(fontSize: font16, color: color),
    bodyMedium: base.bodyMedium?.copyWith(fontSize: font14, color: color),
    bodySmall: base.bodySmall?.copyWith(fontSize: font12, color: color),
    labelLarge: base.labelLarge?.copyWith(fontSize: font14, color: color),
    labelMedium: base.labelMedium?.copyWith(fontSize: font13, color: color),
    labelSmall: base.labelSmall?.copyWith(fontSize: font12, color: color),
  );

  static TextStyle mono(Color color) =>
      GoogleFonts.robotoMono(fontSize: font12, color: color, height: 1.8);
}
