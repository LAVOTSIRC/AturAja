// Basic smoke test for the AturAja app: verifies the splash screen shows
// the app name on launch.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bruh/main.dart';
import 'package:bruh/screens/home_screen.dart';
import 'package:bruh/screens/main_shell.dart';
import 'package:bruh/theme/theme_scope.dart';
import 'package:bruh/widgets/quick_add_modal.dart';

void main() {
  testWidgets('Splash screen shows the AturAja logo text', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MyApp(controller: ThemeController()));

    expect(find.textContaining('Atur'), findsWidgets);
    expect(find.textContaining('Aja'), findsWidgets);
  });

  testWidgets('Home quick actions invoke matching callbacks', (
    WidgetTester tester,
  ) async {
    QuickAddMode? selectedMode;
    int scanCount = 0;
    int taskCount = 0;
    await tester.pumpWidget(
      ThemeScope(
        controller: ThemeController(),
        child: MaterialApp(
          home: HomeScreen(
            onAdd: (QuickAddMode mode) => selectedMode = mode,
            onScan: () => scanCount++,
            onAddTask: () => taskCount++,
          ),
        ),
      ),
    );

    expect(find.text('Catat'), findsOneWidget);
    expect(find.text('Scan Struk'), findsOneWidget);
    expect(find.text('Brain Dump'), findsOneWidget);
    expect(find.text('Tambah Tugas'), findsOneWidget);
    expect(find.text('Anggaran'), findsNothing);

    await tester.tap(find.text('Catat'));
    expect(selectedMode, QuickAddMode.quick);
    await tester.tap(find.text('Scan Struk'));
    expect(scanCount, 1);
    await tester.tap(find.text('Brain Dump'));
    expect(selectedMode, QuickAddMode.brain);
    await tester.tap(find.text('Tambah Tugas'));
    expect(taskCount, 1);
  });

  testWidgets('QuickAddModal defaults to quick mode', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ThemeScope(
        controller: ThemeController(),
        child: const MaterialApp(home: Scaffold(body: QuickAddModal())),
      ),
    );

    expect(find.text('Nominal dan deskripsi transaksi'), findsOneWidget);
    expect(find.text('Isi brain dump'), findsNothing);
  });

  testWidgets('QuickAddModal respects brain initial mode', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ThemeScope(
        controller: ThemeController(),
        child: const MaterialApp(
          home: Scaffold(body: QuickAddModal(initialMode: QuickAddMode.brain)),
        ),
      ),
    );

    expect(find.text('Isi brain dump'), findsOneWidget);
    expect(find.text('Nominal dan deskripsi transaksi'), findsNothing);
  });

  testWidgets('Quick add task updates the shared task list', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ThemeScope(
        controller: ThemeController(),
        child: const MaterialApp(home: MainShell()),
      ),
    );

    await tester.tap(find.text('Tambah Tugas'));
    await tester.pumpAndSettle();
    final Finder fields = find.byType(TextField);
    expect(fields, findsNWidgets(3));
    await tester.enterText(fields.at(0), 'Submit laporan');
    await tester.enterText(fields.at(1), 'Akademik');
    await tester.enterText(fields.at(2), 'Besok, 08:00');
    await tester.tap(find.text('Simpan Tugas'));
    await tester.pumpAndSettle();

    expect(find.text('Tugas berhasil ditambahkan.'), findsOneWidget);
    await tester.tap(find.text('Tugas'));
    await tester.pumpAndSettle();
    expect(find.text('Submit laporan'), findsOneWidget);
  });
}
