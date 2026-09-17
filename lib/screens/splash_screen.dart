import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'main_shell.dart';

/// First screen shown when the app launches: fades/scales the AturAja logo
/// in, holds, then fades out into the main app shell.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final AnimationController _dotsController;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2900));
    _dotsController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);

    // 0 -> 100ms: fade/scale in. 100 -> 2200ms: hold. 2200 -> 2900ms: fade/scale out.
    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 100 / 2900),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 2100 / 2900),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 700 / 2900),
    ]).animate(_controller);

    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.88, end: 1.0), weight: 100 / 2900),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 2100 / 2900),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.04), weight: 700 / 2900),
    ]).animate(_controller);

    _controller.forward();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainShell()),
        );
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
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(-0.6, -1),
            end: Alignment(0.6, 1),
            colors: [Color(0xFF070F1C), Color(0xFF0D2550), Color(0xFF0A4878)],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
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
                            width: 200,
                            height: 200,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [Color(0x2E00CFFF), Colors.transparent],
                              ),
                            ),
                          ),
                        ),
                        Transform.scale(
                          scale: _scale.value,
                          child: Container(
                            width: 120,
                            height: 120,
                            margin: const EdgeInsets.only(bottom: 32),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: const [
                                BoxShadow(color: Color(0x5900CFFF), blurRadius: 40),
                                BoxShadow(color: Color(0x80000000), blurRadius: 32, offset: Offset(0, 8)),
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
                    const SizedBox(height: 32),
                    Transform.scale(
                      scale: _scale.value,
                      child: Column(
                        children: [
                          Text.rich(
                            const TextSpan(
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                                shadows: [Shadow(color: Color(0x8000CFFF), blurRadius: 30)],
                              ),
                              children: [
                                TextSpan(text: 'Atur', style: TextStyle(color: Colors.white)),
                                TextSpan(text: 'Aja', style: TextStyle(color: Color(0xFF00CFFF))),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'KELOLA · CATAT · ATUR',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xB300CFFF),
                              letterSpacing: 2,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 120),
                    _LoadingDots(mainController: _controller, dotsController: _dotsController),
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

/// Three pulsing dots shown during the splash "hold" phase, all driven by a
/// single shared repeating [AnimationController] (no per-dot timers).
class _LoadingDots extends StatelessWidget {
  final AnimationController mainController;
  final AnimationController dotsController;
  const _LoadingDots({required this.mainController, required this.dotsController});

  static const _colors = [Color(0xFF00CFFF), Color(0xFFF5A623), Color(0xFF00CFFF)];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([mainController, dotsController]),
      builder: (context, _) {
        final ms = mainController.value * 2900;
        final holding = ms > 100 && ms < 2200;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            // Stagger each dot's phase by 0.2 within the shared pulse cycle.
            final phase = (dotsController.value + i * 0.2) % 1.0;
            final t = holding ? (math.sin(phase * math.pi * 2) * 0.5 + 0.5) : 0.0;
            final scale = 1.0 + t * 0.4;
            final opacity = holding ? 0.5 + t * 0.5 : 0.3;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Opacity(
                opacity: opacity,
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(color: _colors[i], shape: BoxShape.circle),
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
