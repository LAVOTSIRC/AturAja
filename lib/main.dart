import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'theme/theme_scope.dart';

void main() {
  runApp(MyApp(controller: ThemeController()));
}

class MyApp extends StatelessWidget {
  final ThemeController controller;
  const MyApp({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ThemeScope(
      controller: controller,
      child: MaterialApp(
        title: 'AturAja',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true),
        home: const SplashScreen(),
      ),
    );
  }
}
