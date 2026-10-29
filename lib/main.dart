import 'package:flutter/material.dart';

import 'data/app_store.dart';
import 'screens/splash_screen.dart';
import 'theme/app_colors.dart';
import 'theme/app_spacing.dart';
import 'theme/app_typography.dart';
import 'theme/theme_scope.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final AppStore store = await AppStore.loadPersistent();
  runApp(MyApp(controller: store.theme, store: store));
}

class MyApp extends StatelessWidget {
  final ThemeController controller;
  final AppStore? store;

  const MyApp({super.key, required this.controller, this.store});

  ThemeController get themeController => store?.theme ?? controller;

  ThemeData _theme(AppColors c, Brightness brightness) {
    final ColorScheme scheme =
        ColorScheme.fromSeed(
          seedColor: c.blue,
          brightness: brightness,
        ).copyWith(
          primary: c.blue,
          onPrimary: c.onAccent,
          secondary: c.success,
          onSecondary: c.onAccent,
          error: c.expense,
          onError: c.onAccent,
          surface: c.surface,
          onSurface: c.onSurface,
        );
    final TextTheme textTheme = AppTypography.apply(
      ThemeData(brightness: brightness).textTheme,
      c.text,
    );
    final OutlineInputBorder border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSpacing.sm),
      borderSide: BorderSide(color: c.border, width: 1.5),
    );
    final OutlineInputBorder focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSpacing.sm),
      borderSide: BorderSide(color: c.focus, width: 1.5),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.bg,
      textTheme: textTheme,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surfaceHigh,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        hintStyle: AppTypography.body(c.textMuted),
        labelStyle: AppTypography.body(c.textSub),
        border: border,
        enabledBorder: border,
        focusedBorder: focusedBorder,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.blue,
          minimumSize: const Size(AppSpacing.target, AppSpacing.target),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.surfaceHigh,
        contentTextStyle: AppTypography.body(c.text),
        actionTextColor: c.blue,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ThemeScope(
      controller: themeController,
      child: AnimatedBuilder(
        animation: themeController,
        builder: (BuildContext context, Widget? child) {
          final AppColors c = themeController.colors;
          final Brightness brightness = themeController.isDark
              ? Brightness.dark
              : Brightness.light;
          return MaterialApp(
            title: 'AturAja',
            debugShowCheckedModeBanner: false,
            theme: _theme(c, brightness),
            home: SplashScreen(store: store),
          );
        },
      ),
    );
  }
}
