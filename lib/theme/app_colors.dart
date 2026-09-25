import 'package:flutter/material.dart';

class AppColors {
  final Color bg;
  final Color shell;
  final Color surface;
  final Color surfaceHigh;
  final Color border;
  final Color borderAccent;
  final Color text;
  final Color textSub;
  final Color textMuted;
  final Color onSurface;
  final Color onAccent;
  final Color onAlert;
  final Color focus;
  final Color blue;
  final Color blueDim;
  final Color teal;
  final Color tealDim;
  final Color red;
  final Color redDim;
  final Color amber;
  final Color amberDim;
  final Color pink;
  final Color pinkDim;
  final Color navBg;
  final Color cardBg;
  final Color urgentBg;
  final Color roastBg;
  final Color transparent;
  final Color toggleTrack;
  final Color shadow;
  final Color shadowStrong;
  final Color splashStart;
  final Color splashMid;
  final Color splashEnd;
  final Color splashGlow;
  final Color splashAccent;
  final Color splashAccentSoft;
  final Color splashText;

  const AppColors({
    required this.bg,
    required this.shell,
    required this.surface,
    required this.surfaceHigh,
    required this.border,
    required this.borderAccent,
    required this.text,
    required this.textSub,
    required this.textMuted,
    required this.onSurface,
    required this.onAccent,
    required this.onAlert,
    required this.focus,
    required this.blue,
    required this.blueDim,
    required this.teal,
    required this.tealDim,
    required this.red,
    required this.redDim,
    required this.amber,
    required this.amberDim,
    required this.pink,
    required this.pinkDim,
    required this.navBg,
    required this.cardBg,
    required this.urgentBg,
    required this.roastBg,
    required this.transparent,
    required this.toggleTrack,
    required this.shadow,
    required this.shadowStrong,
    required this.splashStart,
    required this.splashMid,
    required this.splashEnd,
    required this.splashGlow,
    required this.splashAccent,
    required this.splashAccentSoft,
    required this.splashText,
  });

  Color get primary => blue;
  Color get primaryDim => blueDim;
  Color get success => teal;
  Color get successDim => tealDim;
  Color get expense => red;
  Color get expenseDim => redDim;
  Color get warning => amber;
  Color get warningDim => amberDim;
  Color get ai => pink;
  Color get aiDim => pinkDim;

  static const dark = AppColors(
    bg: Color(0xFF101114),
    shell: Color(0xFF101114),
    surface: Color(0xFF14243F),
    surfaceHigh: Color(0xFF1E3557),
    border: Color(0x8000E5FF),
    borderAccent: Color(0xB300E5FF),
    text: Color(0xFFF5F8FC),
    textSub: Color(0xFFB7C8DD),
    textMuted: Color(0xFF91A6C0),
    onSurface: Color(0xFFF5F8FC),
    onAccent: Color(0xFF06111F),
    onAlert: Color(0xFFFFFFFF),
    focus: Color(0xFF00E5FF),
    blue: Color(0xFF00E5FF),
    blueDim: Color(0x3300E5FF),
    teal: Color(0xFF2BD9A8),
    tealDim: Color(0x332BD9A8),
    red: Color(0xFFFF6B7F),
    redDim: Color(0x26FF6B7F),
    amber: Color(0xFFFFC24D),
    amberDim: Color(0x40FFC24D),
    pink: Color(0xFFFF6FB3),
    pinkDim: Color(0x33FF6FB3),
    navBg: Color(0xFF101114),
    cardBg: Color(0xFF14243F),
    urgentBg: Color(0xFFB4233E),
    roastBg: Color(0xFF241A08),
    transparent: Color(0x00000000),
    toggleTrack: Color(0xFF1E3557),
    shadow: Color(0x33000000),
    shadowStrong: Color(0x59000000),
    splashStart: Color(0xFF070F1C),
    splashMid: Color(0xFF0D2550),
    splashEnd: Color(0xFF0A4878),
    splashGlow: Color(0x2E00CFFF),
    splashAccent: Color(0xFF00CFFF),
    splashAccentSoft: Color(0xB300CFFF),
    splashText: Color(0xFFFFFFFF),
  );

  static const light = AppColors(
    bg: Color(0xFFEEF2F7),
    shell: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    surfaceHigh: Color(0xFFDDE7F2),
    border: Color(0xCC0A6F9B),
    borderAccent: Color(0xFF006D9E),
    text: Color(0xFF0D1F44),
    textSub: Color(0xFF345A85),
    textMuted: Color(0xFF4F6882),
    onSurface: Color(0xFF0D1F44),
    onAccent: Color(0xFFFFFFFF),
    onAlert: Color(0xFFFFFFFF),
    focus: Color(0xFF006D9E),
    blue: Color(0xFF006D9E),
    blueDim: Color(0x26006D9E),
    teal: Color(0xFF007450),
    tealDim: Color(0x26007450),
    red: Color(0xFFB4233E),
    redDim: Color(0x26B4233E),
    amber: Color(0xFF7A4A00),
    amberDim: Color(0x267A4A00),
    pink: Color(0xFFA62B76),
    pinkDim: Color(0x26A62B76),
    navBg: Color(0xFFFFFFFF),
    cardBg: Color(0xFFFFFFFF),
    urgentBg: Color(0xFFB4233E),
    roastBg: Color(0xFFFFFBEA),
    transparent: Color(0x00000000),
    toggleTrack: Color(0xFFDDE9F8),
    shadow: Color(0x1F000000),
    shadowStrong: Color(0x40000000),
    splashStart: Color(0xFF070F1C),
    splashMid: Color(0xFF0D2550),
    splashEnd: Color(0xFF0A4878),
    splashGlow: Color(0x2E00CFFF),
    splashAccent: Color(0xFF00CFFF),
    splashAccentSoft: Color(0xB300CFFF),
    splashText: Color(0xFFFFFFFF),
  );
}
