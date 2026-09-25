import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/theme_scope.dart';

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
    final AppColors c = ThemeScope.of(context).colors;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: background ?? c.cardBg,
        border: Border.all(color: borderColor ?? c.border),
        borderRadius: BorderRadius.circular(AppSpacing.md),
        boxShadow: glow
            ? [
                BoxShadow(
                  color: c.blue.withValues(alpha: 0.12),
                  blurRadius: AppSpacing.sm,
                  spreadRadius: -2,
                ),
              ]
            : null,
      ),
      child: child,
    );
  }
}

class SectionLabel extends StatelessWidget {
  final String text;

  const SectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final AppColors c = ThemeScope.of(context).colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text(
        text.toUpperCase(),
        style: AppTypography.overline(c.textMuted),
      ),
    );
  }
}

class Pill extends StatelessWidget {
  final String text;
  final Color color;
  final Color background;

  const Pill({
    super.key,
    required this.text,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppSpacing.huge),
      ),
      child: Text(text, style: AppTypography.micro(color)),
    );
  }
}

class PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final String? tooltip;
  final String? semanticLabel;
  final bool selected;
  final bool enabled;
  final bool excludeSemantics;
  final double minWidth;
  final double minHeight;

  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.tooltip,
    this.semanticLabel,
    this.selected = false,
    this.enabled = true,
    this.excludeSemantics = false,
    this.minWidth = AppSpacing.target,
    this.minHeight = AppSpacing.target,
  });

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  bool get _interactive => widget.enabled && widget.onTap != null;

  void _setPressed(bool pressed) {
    if (!mounted || _pressed == pressed) {
      return;
    }
    setState(() => _pressed = pressed);
  }

  void _handleTap() {
    if (_interactive) {
      widget.onTap!();
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget result = ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: widget.minWidth,
        minHeight: widget.minHeight,
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _interactive ? _handleTap : null,
        onTapDown: _interactive ? (_) => _setPressed(true) : null,
        onTapUp: _interactive ? (_) => _setPressed(false) : null,
        onTapCancel: _interactive ? () => _setPressed(false) : null,
        child: Opacity(
          opacity: _interactive ? 1 : 0.5,
          child: AnimatedScale(
            scale: _pressed ? 0.97 : 1,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
            child: widget.child,
          ),
        ),
      ),
    );

    if (widget.tooltip != null) {
      result = Tooltip(message: widget.tooltip!, child: result);
    }

    return Semantics(
      button: _interactive,
      enabled: _interactive,
      selected: widget.selected,
      label: widget.semanticLabel,
      onTap: _interactive ? _handleTap : null,
      excludeSemantics: widget.excludeSemantics,
      child: result,
    );
  }
}

class ThemeToggleSwitch extends StatelessWidget {
  const ThemeToggleSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeController controller = ThemeScope.of(context);
    final AppColors c = controller.colors;
    final bool isDark = controller.isDark;
    return PressableScale(
      onTap: controller.toggle,
      tooltip: 'Ganti tema',
      semanticLabel: isDark ? 'Aktifkan tema terang' : 'Aktifkan tema gelap',
      selected: isDark,
      child: SizedBox(
        width: AppSpacing.target,
        height: AppSpacing.target,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: AppSpacing.switchWidth,
            height: AppSpacing.switchHeight,
            padding: const EdgeInsets.all(AppSpacing.xxs),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.huge),
              color: isDark ? c.toggleTrack : c.surfaceHigh,
              border: Border.all(color: c.border),
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              alignment: isDark ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: AppSpacing.iconSmall,
                height: AppSpacing.iconSmall,
                decoration: BoxDecoration(
                  color: isDark ? c.blue : c.onSurface,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: c.shadow,
                      blurRadius: AppSpacing.xxs,
                      offset: const Offset(0, AppSpacing.xxs),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool showDot;
  final String tooltip;
  final String semanticLabel;

  const CircleIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.semanticLabel,
    this.onTap,
    this.showDot = false,
  });

  @override
  Widget build(BuildContext context) {
    final AppColors c = ThemeScope.of(context).colors;
    final String accessibleLabel = showDot
        ? '$semanticLabel. Ada notifikasi baru'
        : semanticLabel;
    final String accessibleTooltip = showDot
        ? '$tooltip, notifikasi baru'
        : tooltip;
    return PressableScale(
      onTap: onTap,
      tooltip: accessibleTooltip,
      semanticLabel: accessibleLabel,
      child: Container(
        width: AppSpacing.target,
        height: AppSpacing.target,
        decoration: BoxDecoration(
          color: c.surface,
          border: Border.all(color: c.border),
          borderRadius: BorderRadius.circular(AppSpacing.sm),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, size: AppSpacing.iconSmall, color: c.onSurface),
            if (showDot)
              Positioned(
                top: AppSpacing.xs,
                right: AppSpacing.xs,
                child: Container(
                  width: AppSpacing.xs,
                  height: AppSpacing.xs,
                  decoration: BoxDecoration(
                    color: c.expense,
                    shape: BoxShape.circle,
                    border: Border.all(color: c.bg, width: AppSpacing.xxs),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Color? accent;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final AppColors c = ThemeScope.of(context).colors;
    final Color color = accent ?? c.blue;
    return Semantics(
      container: true,
      label: '$title. $message',
      child: SizedBox(
        width: double.infinity,
        child: AppCard(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            children: [
              Icon(icon, size: AppSpacing.iconLarge, color: color),
              const SizedBox(height: AppSpacing.sm),
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppTypography.label(c.text),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTypography.meta(c.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AppErrorMessage extends StatelessWidget {
  final String message;

  const AppErrorMessage({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final AppColors c = ThemeScope.of(context).colors;
    return Semantics(
      liveRegion: true,
      label: message,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: c.expenseDim,
          borderRadius: BorderRadius.circular(AppSpacing.md),
          border: Border.all(color: c.expense),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.error_outline,
              size: AppSpacing.iconSmall,
              color: c.expense,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(message, style: AppTypography.caption(c.text)),
            ),
          ],
        ),
      ),
    );
  }
}

class AppProcessingState extends StatelessWidget {
  final String message;
  final Color color;

  const AppProcessingState({
    super.key,
    required this.message,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final AppColors c = ThemeScope.of(context).colors;
    return Semantics(
      liveRegion: true,
      label: message,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: AppSpacing.iconSmall,
              height: AppSpacing.iconSmall,
              child: CircularProgressIndicator(
                strokeWidth: AppSpacing.xxs,
                color: color,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(message, style: AppTypography.label(c.textSub)),
          ],
        ),
      ),
    );
  }
}
