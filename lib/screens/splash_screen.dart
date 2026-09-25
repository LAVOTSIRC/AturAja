import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/theme_scope.dart';
import 'main_shell.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final AnimationController _dotsController;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2900),
    );
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 100 / 2900),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 2100 / 2900),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 700 / 2900),
    ]).animate(_controller);

    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.88, end: 1.0),
        weight: 100 / 2900,
      ),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 2100 / 2900),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.04),
        weight: 700 / 2900,
      ),
    ]).animate(_controller);

    _controller.forward();
    _controller.addStatusListener((AnimationStatus status) {
      if (status == AnimationStatus.completed) {
        Navigator.of(
          context,
        ).pushReplacement(MaterialPageRoute(builder: (_) => const MainShell()));
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _dotsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = ThemeScope.of(context).colors;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: const Alignment(-0.6, -1),
            end: const Alignment(0.6, 1),
            colors: [c.splashStart, c.splashMid, c.splashEnd],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (BuildContext context, Widget? child) {
            return Opacity(
              opacity: _opacity.value,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Transform.scale(
                          scale: _scale.value,
                          child: Container(
                            width: AppSpacing.splashHalo,
                            height: AppSpacing.splashHalo,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [c.splashGlow, c.transparent],
                              ),
                            ),
                          ),
                        ),
                        Transform.scale(
                          scale: _scale.value,
                          child: Container(
                            width: AppSpacing.splashLogo,
                            height: AppSpacing.splashLogo,
                            margin: const EdgeInsets.only(
                              bottom: AppSpacing.xxl,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(
                                AppSpacing.xxl,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: c.splashAccentSoft,
                                  blurRadius: AppSpacing.xxxl,
                                ),
                                BoxShadow(
                                  color: c.shadowStrong,
                                  blurRadius: AppSpacing.xxl,
                                  offset: const Offset(0, AppSpacing.xs),
                                ),
                              ],
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Image.asset(
                              'assets/images/maketh1.jpg',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    Transform.scale(
                      scale: _scale.value,
                      child: Column(
                        children: [
                          Text.rich(
                            TextSpan(
                              style: AppTypography.heroLarge(c.splashText)
                                  .copyWith(
                                    shadows: [
                                      Shadow(
                                        color: c.splashAccentSoft,
                                        blurRadius: AppSpacing.xxl,
                                      ),
                                    ],
                                  ),
                              children: [
                                const TextSpan(text: 'Atur'),
                                TextSpan(
                                  text: 'Aja',
                                  style: AppTypography.heroLarge(
                                    c.splashAccent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'KELOLA · CATAT · ATUR',
                            style: AppTypography.label(c.splashText).copyWith(
                              letterSpacing: 2,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.splashFooter),
                    Semantics(
                      liveRegion: true,
                      label: 'Memuat aplikasi',
                      child: _LoadingDots(
                        mainController: _controller,
                        dotsController: _dotsController,
                        colors: [c.blue, c.warning, c.blue],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LoadingDots extends StatelessWidget {
  final AnimationController mainController;
  final AnimationController dotsController;
  final List<Color> colors;

  const _LoadingDots({
    required this.mainController,
    required this.dotsController,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([mainController, dotsController]),
      builder: (BuildContext context, Widget? child) {
        final double milliseconds = mainController.value * 2900;
        final bool holding = milliseconds > 100 && milliseconds < 2200;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (int index) {
            final double phase = (dotsController.value + index * 0.2) % 1.0;
            final double amount = holding
                ? (math.sin(phase * math.pi * 2) * 0.5 + 0.5)
                : 0.0;
            final double scale = 1.0 + amount * 0.4;
            final double opacity = holding ? 0.5 + amount * 0.5 : 0.3;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
              child: Opacity(
                opacity: opacity,
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    width: AppSpacing.xs,
                    height: AppSpacing.xs,
                    decoration: BoxDecoration(
                      color: colors[index],
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
