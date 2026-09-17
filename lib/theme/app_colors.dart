import 'package:flutter/material.dart';

/// Color palette for the app: solid deep-navy cards on a near-black
/// background, with a single consistent cyan accent (no gradients).
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
  });

  static const dark = AppColors(
    bg: Color(0xFF101114),
    shell: Color(0xFF101114),
    surface: Color(0xFF14243F),
    surfaceHigh: Color(0xFF1E3557),
    border: Color(0x4700E5FF),
    borderAccent: Color(0x9900E5FF),
    text: Color(0xFFF5F8FC),
    textSub: Color(0xFF9FB4CE),
    textMuted: Color(0xFF5F7491),
    blue: Color(0xFF00E5FF),
    blueDim: Color(0x2600E5FF),
    teal: Color(0xFF2BD9A8),
    tealDim: Color(0x262BD9A8),
    red: Color(0xFFFF4D67),
    redDim: Color(0x26FF4D67),
    amber: Color(0xFFFFB020),
    amberDim: Color(0x33FFB020),
    pink: Color(0xFFFF52AA),
    pinkDim: Color(0x26FF52AA),
    navBg: Color(0xFF101114),
    cardBg: Color(0xFF14243F),
    urgentBg: Color(0xFFD6323F),
    roastBg: Color(0xFF1C1500),
  );

  static const light = AppColors(
    bg: Color(0xFFEEF2F7),
    shell: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    surfaceHigh: Color(0xFFE3EBF5),
    border: Color(0x33106EA8),
    borderAccent: Color(0x80106EA8),
    text: Color(0xFF0D1F44),
    textSub: Color(0xFF3A6090),
    textMuted: Color(0xFF7A9EBF),
    blue: Color(0xFF0A8FC0),
    blueDim: Color(0x1A0A8FC0),
    teal: Color(0xFF009E6E),
    tealDim: Color(0x1A009E6E),
    red: Color(0xFFD42B50),
    redDim: Color(0x1AD42B50),
    amber: Color(0xFFD4880A),
    amberDim: Color(0x1AD4880A),
    pink: Color(0xFFC0308A),
    pinkDim: Color(0x1AC0308A),
    navBg: Color(0xFFFFFFFF),
    cardBg: Color(0xFFFFFFFF),
    urgentBg: Color(0xFFD6323F),
    roastBg: Color(0xFFFFFBEA),
  );
}
