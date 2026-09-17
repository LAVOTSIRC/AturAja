import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/theme_scope.dart';

/// A rounded surface card used throughout the app: solid deep-navy fill
/// with a thin, subtle cyan outline.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? background;
  final Color? borderColor;
  final bool glow;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.background,
    this.borderColor,
    this.glow = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = ThemeScope.of(context).colors;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: background ?? c.surface,
        border: Border.all(color: borderColor ?? c.border),
        borderRadius: BorderRadius.circular(16),
        boxShadow: glow
            ? [BoxShadow(color: c.blue.withValues(alpha: 0.12), blurRadius: 12, spreadRadius: -2)]
            : null,
      ),
      child: child,
    );
  }
}

/// Small uppercase section label, e.g. "AKSI CEPAT".
class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = ThemeScope.of(context).colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.1,
          color: c.textMuted,
        ),
      ),
    );
  }
}

/// A small colored pill/badge, e.g. "konsumtif" or "Mendesak".
class Pill extends StatelessWidget {
  final String text;
  final Color color;
  final Color background;
  const Pill({super.key, required this.text, required this.color, required this.background});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(99)),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

/// Dark / light theme toggle switch: a clean, minimal pill switch with no
/// emoji glyphs.
class ThemeToggleSwitch extends StatelessWidget {
  const ThemeToggleSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = ThemeScope.of(context);
    final c = controller.colors;
    final isDark = controller.isDark;
    return GestureDetector(
      onTap: controller.toggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 46,
        height: 26,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(99),
          color: isDark ? c.surfaceHigh : const Color(0xFFDDE9F8),
          border: Border.all(color: c.border),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          alignment: isDark ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: isDark ? c.blue : Colors.white,
              shape: BoxShape.circle,
              boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 4, offset: Offset(0, 1))],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small circular icon button used for the bell / close buttons.
class CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool showDot;
  const CircleIconButton({super.key, required this.icon, this.onTap, this.showDot = false});

  @override
  Widget build(BuildContext context) {
    final AppColors c = ThemeScope.of(context).colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: c.surface,
          border: Border.all(color: c.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, size: 19, color: c.textSub),
            if (showDot)
              Positioned(
                top: 7,
                right: 7,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: c.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: c.bg, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
