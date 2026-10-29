import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'config/routes.dart';
import 'providers/app_provider.dart';
import 'providers/settings_provider.dart';
import 'theme/app_colors.dart';
import 'theme/app_spacing.dart';
import 'theme/app_typography.dart';
import 'theme/theme_scope.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final AppProvider app = await AppProvider.loadPersistent();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppProvider>.value(value: app),
        ChangeNotifierProvider<ThemeController>.value(value: app.theme),
        ChangeNotifierProvider<SettingsController>.value(value: app.settings),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  final String initialLocation;

  const MyApp({super.key, this.initialLocation = AppRoutes.splash});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final GoRouter _router = createAppRouter(
    initialLocation: widget.initialLocation,
  );

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

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
      fontFamily: AppTypography.fontFamily,
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
    final ThemeController theme = context.watch<ThemeController>();
    final AppColors c = theme.colors;
    final Brightness brightness = theme.isDark
        ? Brightness.dark
        : Brightness.light;

    return ThemeScope(
      controller: theme,
      child: MaterialApp.router(
        title: 'AturAja',
        debugShowCheckedModeBanner: false,
        theme: _theme(c, brightness),
        routerConfig: _router,
      ),
    );
  }
}
