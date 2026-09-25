// Basic smoke test for the AturAja app: verifies the splash screen shows
// the app name on launch.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bruh/data/settings_controller.dart';
import 'package:bruh/main.dart';
import 'package:bruh/screens/home_screen.dart';
import 'package:bruh/screens/main_shell.dart';
import 'package:bruh/screens/profile_screen.dart';
import 'package:bruh/theme/theme_scope.dart';
import 'package:bruh/widgets/quick_add_modal.dart';

Future<void> pumpProfile(
  WidgetTester tester,
  SettingsController settings,
) async {
  await tester.pumpWidget(
    ThemeScope(
      controller: ThemeController(),
      child: MaterialApp(
        home: Scaffold(body: ProfileScreen(settings: settings)),
      ),
    ),
  );
}

Future<void> openProfileSetting(WidgetTester tester, String label) async {
  final Finder row = find.text(label);
  await tester.ensureVisible(row);
  await tester.pumpAndSettle();
  await tester.tap(row);
  await tester.pumpAndSettle();
}

Future<void> returnFromSetting(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Kembali'));
  await tester.pumpAndSettle();
}

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

  testWidgets('FAB actions are contextual across tabs', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ThemeScope(
        controller: ThemeController(),
        child: const MaterialApp(home: MainShell()),
      ),
    );

    expect(find.byTooltip('Scan struk'), findsOneWidget);
    expect(find.byTooltip('Tambah catatan'), findsOneWidget);

    await tester.tap(find.byTooltip('Tugas'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Scan struk'), findsNothing);
    expect(find.byTooltip('Tambah catatan'), findsOneWidget);

    await tester.tap(find.byTooltip('Profil'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Scan struk'), findsNothing);
    expect(find.byTooltip('Tambah catatan'), findsNothing);
  });

  testWidgets('Profile setting rows navigate to five detail screens', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ThemeScope(
        controller: ThemeController(),
        child: const MaterialApp(home: MainShell()),
      ),
    );
    await tester.tap(find.byTooltip('Profil'));
    await tester.pumpAndSettle();

    const List<List<String>> routes = [
      ['Notifikasi & Roasting AI', 'Notifikasi & Roasting AI'],
      ['Cadangan Cloud', 'Cadangan Cloud'],
      ['Limit Anggaran', 'Limit Anggaran'],
      ['Simulasi NLP', 'Simulasi NLP'],
      ['Privasi & Keamanan', 'Privasi & Keamanan'],
    ];

    for (final List<String> route in routes) {
      await openProfileSetting(tester, route[0]);
      expect(find.text(route[1]), findsOneWidget);
      expect(find.byTooltip('Kembali'), findsOneWidget);
      await returnFromSetting(tester);
    }
  });

  testWidgets('Notification toggle updates the Profile preview', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ThemeScope(
        controller: ThemeController(),
        child: const MaterialApp(home: MainShell()),
      ),
    );
    await tester.tap(find.byTooltip('Profil'));
    await tester.pumpAndSettle();
    await openProfileSetting(tester, 'Notifikasi & Roasting AI');

    expect(find.byType(Switch), findsNWidgets(3));
    await tester.tap(find.byType(Switch).first);
    await tester.pump();
    await returnFromSetting(tester);

    expect(find.text('2 dari 3 kategori aktif'), findsOneWidget);
  });

  testWidgets('Cloud sync shows progress and updates the Profile preview', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ThemeScope(
        controller: ThemeController(),
        child: const MaterialApp(home: MainShell()),
      ),
    );
    await tester.tap(find.byTooltip('Profil'));
    await tester.pumpAndSettle();
    await openProfileSetting(tester, 'Cadangan Cloud');

    await tester.tap(find.byType(Switch));
    await tester.pump();
    await tester.tap(find.text('Sinkronkan Sekarang'));
    await tester.pump();
    expect(find.text('Menyinkronkan data ke cloud...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsWidgets);

    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();
    expect(find.text('Baru saja'), findsOneWidget);
    expect(find.text('Cadangan cloud berhasil disinkronkan.'), findsOneWidget);
    await returnFromSetting(tester);
    expect(find.text('Baru saja · Manual'), findsOneWidget);
  });

  testWidgets('Budget limit validates and saves only after confirmation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ThemeScope(
        controller: ThemeController(),
        child: const MaterialApp(home: MainShell()),
      ),
    );
    await tester.tap(find.byTooltip('Profil'));
    await tester.pumpAndSettle();
    await openProfileSetting(tester, 'Limit Anggaran');

    final Finder field = find.byType(TextField);
    await tester.enterText(field, '');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Simpan'));
    await tester.tap(find.text('Simpan'));
    await tester.pump();
    expect(find.text('Limit anggaran tidak boleh kosong.'), findsOneWidget);

    await tester.enterText(field, '-5');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Simpan'));
    await tester.tap(find.text('Simpan'));
    await tester.pump();
    expect(
      find.text('Limit anggaran harus lebih besar dari nol.'),
      findsOneWidget,
    );

    await tester.enterText(field, '2000000');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Simpan'));
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(find.text('Rp2.000.000/bulan'), findsOneWidget);
    expect(find.text('Limit anggaran berhasil diperbarui.'), findsOneWidget);

    await openProfileSetting(tester, 'Limit Anggaran');
    await tester.enterText(find.byType(TextField), '3000000');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(find.text('Rp2.000.000/bulan'), findsOneWidget);
  });

  testWidgets('NLP simulation detects tasks, schedules, and expenses', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ThemeScope(
        controller: ThemeController(),
        child: const MaterialApp(home: MainShell()),
      ),
    );
    await tester.tap(find.byTooltip('Profil'));
    await tester.pumpAndSettle();
    await openProfileSetting(tester, 'Simulasi NLP');

    final Finder field = find.byType(TextField);
    await tester.ensureVisible(find.text('Deteksi Kategori'));
    await tester.tap(find.text('Deteksi Kategori'));
    await tester.pump();
    expect(
      find.text('Tuliskan satu kalimat brain-dump terlebih dahulu.'),
      findsOneWidget,
    );

    const List<List<String>> cases = [
      ['Kerjakan tugas laporan', 'Kategori terdeteksi: Tugas'],
      ['Rapat besok jam 10', 'Kategori terdeteksi: Jadwal'],
      ['Beli makan 25000', 'Kategori terdeteksi: Pengeluaran'],
    ];
    for (final List<String> item in cases) {
      await tester.enterText(field, item[0]);
      await tester.ensureVisible(find.text('Deteksi Kategori'));
      await tester.tap(find.text('Deteksi Kategori'));
      await tester.pump();
      expect(find.text(item[1]), findsOneWidget);
    }
  });

  testWidgets('Privacy actions protect destructive and sensitive operations', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ThemeScope(
        controller: ThemeController(),
        child: const MaterialApp(home: MainShell()),
      ),
    );
    await tester.tap(find.byTooltip('Profil'));
    await tester.pumpAndSettle();

    await openProfileSetting(tester, 'Privasi & Keamanan');
    await tester.tap(find.byType(Switch));
    await tester.pump();
    await returnFromSetting(tester);
    expect(find.text('Biometrik nonaktif'), findsOneWidget);

    await openProfileSetting(tester, 'Privasi & Keamanan');
    await tester.tap(find.text('Ubah PIN'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '12');
    await tester.tap(find.widgetWithText(TextButton, 'Simpan PIN'));
    await tester.pump();
    expect(find.text('PIN harus terdiri dari 4–6 digit.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '1234');
    await tester.tap(find.widgetWithText(TextButton, 'Simpan PIN'));
    await tester.pumpAndSettle();
    expect(find.text('PIN telah diperbarui.'), findsOneWidget);

    await tester.ensureVisible(find.text('Ekspor data'));
    await tester.tap(find.text('Ekspor data'));
    await tester.pump();
    expect(find.text('Menyiapkan data...'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    expect(find.text('Pratinjau Ekspor Data'), findsOneWidget);
    await tester.tap(find.text('Tutup'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Hapus akun'));
    await tester.tap(find.text('Hapus akun'));
    await tester.pumpAndSettle();
    expect(find.text('Hapus akun AturAja?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Batal'));
    await tester.pumpAndSettle();
    expect(
      find.text('Permintaan penghapusan akun sudah dicatat.'),
      findsNothing,
    );

    await tester.tap(find.text('Hapus akun'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Hapus Akun'));
    await tester.pump();
    expect(find.text('Menghapus akun...'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    expect(find.text('Permintaan hapus akun telah dicatat.'), findsOneWidget);
    expect(
      find.text('Permintaan penghapusan akun sudah dicatat.'),
      findsOneWidget,
    );
  });

  testWidgets('Profile edit validates and updates the displayed identity', (
    WidgetTester tester,
  ) async {
    final SettingsController settings = SettingsController();
    addTearDown(settings.dispose);
    await pumpProfile(tester, settings);

    await tester.tap(find.byTooltip('Edit profil'));
    await tester.pumpAndSettle();
    final Finder fields = find.byType(TextField);
    expect(fields, findsNWidgets(3));

    await tester.enterText(fields.at(0), '');
    await tester.enterText(fields.at(1), 'abc');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Simpan'));
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(find.text('Nama tidak boleh kosong.'), findsOneWidget);
    expect(find.text('NIM harus berupa angka.'), findsOneWidget);

    await tester.enterText(fields.at(0), 'Budi Santoso');
    await tester.enterText(fields.at(1), '241401099');
    await tester.enterText(fields.at(2), 'Sistem Informasi');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Simpan'));
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(find.text('Budi Santoso'), findsOneWidget);
    expect(find.text('241401099 · Sistem Informasi'), findsOneWidget);
    expect(find.text('BS'), findsOneWidget);
    expect(find.text('Profil berhasil diperbarui.'), findsOneWidget);
  });

  testWidgets('Profile logout requires confirmation and can be restored', (
    WidgetTester tester,
  ) async {
    final SettingsController settings = SettingsController();
    addTearDown(settings.dispose);
    await pumpProfile(tester, settings);

    await tester.ensureVisible(find.text('Keluar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keluar'));
    await tester.pumpAndSettle();

    expect(find.text('Keluar dari AturAja?'), findsOneWidget);
    expect(
      find.text('Yakin ingin keluar? Sesi lokal akan diakhiri.'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(TextButton, 'Keluar'));
    await tester.pumpAndSettle();

    expect(find.text('Sesi berakhir'), findsOneWidget);
    expect(find.text('Anda telah keluar dari akun.'), findsOneWidget);

    await tester.tap(find.text('Masuk lagi'));
    await tester.pumpAndSettle();
    expect(find.text('M Zidan Ruriano A.G'), findsOneWidget);
  });
}
