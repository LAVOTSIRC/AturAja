// Basic smoke test for the AturAja app: verifies the splash screen shows
// the app name on launch.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:bruh/data/models.dart';
import 'package:bruh/data/settings_controller.dart';
import 'package:bruh/main.dart';
import 'package:bruh/providers/app_provider.dart';
import 'package:bruh/theme/app_colors.dart';
import 'package:bruh/screens/brain_dump_finance_screen.dart';
import 'package:bruh/screens/finance_screen.dart';
import 'package:bruh/screens/home_screen.dart';
import 'package:bruh/screens/login_screen.dart';
import 'package:bruh/screens/main_shell.dart';
import 'package:bruh/screens/profile_screen.dart';
import 'package:bruh/screens/task_screen.dart';
import 'package:bruh/services/receipt_camera.dart';
import 'package:bruh/theme/theme_scope.dart';
import 'package:bruh/widgets/quick_add_modal.dart';

Future<AppProvider> pumpApp(
  WidgetTester tester, {
  String initialLocation = '/home',
  bool isLoggedIn = true,
  bool settle = true,
  List<TransactionItem>? transactions,
}) async {
  final AppProvider app = AppProvider.inMemory(
    isLoggedIn: isLoggedIn,
    transactions: transactions,
  );
  addTearDown(app.dispose);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppProvider>.value(value: app),
        ChangeNotifierProvider<ThemeController>.value(value: app.theme),
        ChangeNotifierProvider<SettingsController>.value(value: app.settings),
      ],
      child: MyApp(initialLocation: initialLocation),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  }
  return app;
}

Future<void> pumpProfile(
  WidgetTester tester,
  SettingsController settings, {
  VoidCallback? onLogout,
}) async {
  await tester.pumpWidget(
    ThemeScope(
      controller: ThemeController(),
      child: MaterialApp(
        home: Scaffold(
          body: ProfileScreen(settings: settings, onLogout: onLogout ?? () {}),
        ),
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
  test('Home greeting follows the time of day', () {
    expect(greetingForHour(6), 'Selamat pagi');
    expect(greetingForHour(12), 'Selamat siang');
    expect(greetingForHour(16), 'Selamat sore');
    expect(greetingForHour(21), 'Selamat malam');
    expect(greetingForHour(2), 'Selamat malam');
  });

  testWidgets('Splash screen shows the AturAja logo text', (
    WidgetTester tester,
  ) async {
    await pumpApp(
      tester,
      initialLocation: '/splash',
      isLoggedIn: false,
      settle: false,
    );

    expect(find.textContaining('Atur'), findsWidgets);
    expect(find.textContaining('Aja'), findsWidgets);
  });

  testWidgets('Home quick actions invoke matching callbacks', (
    WidgetTester tester,
  ) async {
    int scanCount = 0;
    int taskCount = 0;
    int brainCount = 0;
    final AppProvider app = AppProvider.inMemory();
    addTearDown(app.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [ChangeNotifierProvider<AppProvider>.value(value: app)],
        child: ThemeScope(
          controller: app.theme,
          child: MaterialApp(
            home: HomeScreen(
              onScan: () => scanCount++,
              onAddTask: () => taskCount++,
              onBrainDump: () => brainCount++,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Catat'), findsNothing);
    expect(find.text('Scan Struk'), findsOneWidget);
    expect(find.text('Brain Dump'), findsOneWidget);
    expect(find.text('Tambah Tugas'), findsOneWidget);
    expect(find.text('Anggaran'), findsNothing);

    await tester.tap(find.text('Scan Struk'));
    expect(scanCount, 1);
    await tester.tap(find.text('Brain Dump'));
    expect(brainCount, 1);
    await tester.tap(find.text('Tambah Tugas'));
    expect(taskCount, 1);
  });

  testWidgets('Theme toggle repaints the bottom navigation shell', (
    WidgetTester tester,
  ) async {
    final AppProvider app = await pumpApp(tester);
    final Finder shellScaffold = find
        .descendant(of: find.byType(MainShell), matching: find.byType(Scaffold))
        .first;

    expect(
      tester.widget<Scaffold>(shellScaffold).backgroundColor,
      AppColors.dark.shell,
    );

    await tester.tap(find.byTooltip('Ganti ke mode terang'));
    await tester.pumpAndSettle();

    expect(app.theme.isDark, isFalse);
    expect(
      tester.widget<Scaffold>(shellScaffold).backgroundColor,
      AppColors.light.shell,
    );
  });

  testWidgets('Theme toggle repaints the login surface', (
    WidgetTester tester,
  ) async {
    final AppProvider app = await pumpApp(
      tester,
      initialLocation: '/login',
      isLoggedIn: false,
    );
    final Finder loginScaffold = find
        .descendant(
          of: find.byType(LoginScreen),
          matching: find.byType(Scaffold),
        )
        .first;

    expect(
      tester.widget<Scaffold>(loginScaffold).backgroundColor,
      AppColors.dark.bg,
    );

    app.theme.toggle();
    await tester.pumpAndSettle();

    expect(
      tester.widget<Scaffold>(loginScaffold).backgroundColor,
      AppColors.light.bg,
    );
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
    await pumpApp(tester);

    await tester.tap(find.text('Tambah Tugas'));
    await tester.pumpAndSettle();

    expect(find.text('Tambah Tugas Baru'), findsOneWidget);
    expect(find.text('Form Manual'), findsOneWidget);
    expect(find.text('AI Brain Dump'), findsOneWidget);

    final Finder fields = find.byType(TextField);
    await tester.enterText(fields.first, 'Submit laporan');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tambah Tugas'));
    await tester.pumpAndSettle();

    expect(find.text('Tugas berhasil ditambahkan.'), findsOneWidget);
    await tester.tap(find.byTooltip('Tugas'));
    await tester.pumpAndSettle();
    expect(find.text('Submit laporan'), findsOneWidget);
  });

  testWidgets('Add form switches between Manual and Brain Dump modes', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.byTooltip('Tugas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tambah'));
    await tester.pumpAndSettle();

    expect(find.text('Tambah Tugas Baru'), findsOneWidget);
    expect(find.text('JUDUL TUGAS *'), findsOneWidget);
    expect(find.text('AI Brain Dump Tugas'), findsNothing);

    await tester.tap(find.text('AI Brain Dump'));
    await tester.pumpAndSettle();

    expect(find.text('AI Brain Dump Tugas'), findsOneWidget);
    expect(find.text('JUDUL TUGAS *'), findsNothing);
    expect(find.text('Tambah Tugas'), findsNothing);

    await tester.tap(find.text('Form Manual'));
    await tester.pumpAndSettle();
    expect(find.text('JUDUL TUGAS *'), findsOneWidget);
    expect(find.text('AI Brain Dump Tugas'), findsNothing);
  });

  testWidgets('Edit form keeps the manual layout without mode switcher', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.byTooltip('Tugas'));
    await tester.pumpAndSettle();

    final Finder firstTask = find.byTooltip('Buka detail tugas').first;
    await tester.ensureVisible(firstTask);
    await tester.pumpAndSettle();
    await tester.tap(firstTask);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Edit Tugas'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Tugas'), findsOneWidget);
    expect(find.text('JUDUL TUGAS *'), findsOneWidget);
    expect(find.text('Form Manual'), findsNothing);
    expect(find.text('AI Brain Dump'), findsNothing);
  });

  testWidgets('No floating action button remains on any tab', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    for (final String tab in ['Beranda', 'Keuangan', 'Tugas', 'Profil']) {
      await tester.tap(find.byTooltip(tab));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Tambah catatan'), findsNothing);
      expect(find.byType(FloatingActionButton), findsNothing);
    }
  });

  testWidgets('Horizontal swipe moves between the main tabs', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
    expect(find.byType(HomeScreen), findsOneWidget);

    await tester.fling(find.byType(HomeScreen), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.byType(FinanceScreen), findsOneWidget);

    await tester.fling(find.byType(FinanceScreen), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.byType(TaskScreen), findsOneWidget);

    await tester.fling(find.byType(TaskScreen), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.byType(ProfileScreen), findsOneWidget);

    await tester.fling(find.byType(ProfileScreen), const Offset(400, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.byType(TaskScreen), findsOneWidget);
  });

  testWidgets('Horizontal swipe does not leave the first or last tab', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    await tester.drag(find.byType(HomeScreen), const Offset(320, 0));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);

    await tester.tap(find.byTooltip('Profil'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ProfileScreen), const Offset(-320, 0));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileScreen), findsOneWidget);
  });

  testWidgets('Swipe keeps the scroll position of a tab alive', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
    final Finder homeList = find
        .descendant(
          of: find.byType(HomeScreen),
          matching: find.byType(Scrollable),
        )
        .first;

    // Sedikit drift horizontal tidak boleh dianggap sebagai swipe tab.
    await tester.drag(homeList, const Offset(28, -280));
    await tester.pumpAndSettle();
    final double offset = tester
        .state<ScrollableState>(homeList)
        .position
        .pixels;
    expect(offset, greaterThan(0));
    expect(find.byType(FinanceScreen).hitTestable(), findsNothing);

    await tester.fling(find.byType(HomeScreen), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    await tester.fling(find.byType(FinanceScreen), const Offset(400, 0), 1000);
    await tester.pumpAndSettle();

    expect(
      tester.state<ScrollableState>(homeList).position.pixels,
      closeTo(offset, 0.1),
    );
  });

  testWidgets('Deleting a task removes it from the shared task list', (
    WidgetTester tester,
  ) async {
    final AppProvider app = await pumpApp(tester);
    await tester.tap(find.byTooltip('Tugas'));
    await tester.pumpAndSettle();

    final TaskItem firstTask = app.tasks.first;
    final int before = app.tasks.length;

    final Finder firstTaskTile = find.byTooltip('Buka detail tugas').first;
    await tester.ensureVisible(firstTaskTile);
    await tester.pumpAndSettle();
    await tester.tap(firstTaskTile);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Hapus Tugas'));
    await tester.pumpAndSettle();
    expect(find.text('Hapus Tugas?'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Hapus'));
    await tester.pumpAndSettle();

    expect(app.tasks.length, before - 1);
    expect(app.tasks.any((TaskItem task) => task.id == firstTask.id), isFalse);
    expect(find.text(firstTask.title), findsNothing);
  });

  testWidgets('Brain Dump finance note processes into a preview then saves', (
    WidgetTester tester,
  ) async {
    final AppProvider app = await pumpApp(tester);
    final int before = app.transactions.length;

    await tester.tap(find.text('Brain Dump'));
    await tester.pumpAndSettle();

    expect(find.text('Brain Dump Keuangan'), findsOneWidget);
    expect(find.text('AI Brain Dump Catatan Keuangan'), findsOneWidget);

    await tester.tap(find.text('Catatan Pengeluaran'));
    await tester.pumpAndSettle();
    expect(find.text('AI Brain Dump Catatan Pengeluaran'), findsOneWidget);

    await tester.tap(find.text('Belanja sayur 120rb'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Proses Brain Dump'));
    await tester.pumpAndSettle();

    expect(find.text('Periksa hasil AI sebelum disimpan'), findsOneWidget);
    expect(find.text('120000'), findsOneWidget);
    expect(find.text('Simpan Catatan Pengeluaran'), findsOneWidget);

    await tester.ensureVisible(find.text('Simpan Catatan Pengeluaran'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simpan Catatan Pengeluaran'));
    await tester.pumpAndSettle();

    expect(app.transactions.length, before + 1);
    expect(app.transactions.first.amount, -120000);
    expect(app.transactions.first.cat, 'belanja');
  });

  testWidgets('Brain Dump rejects input without a detectable amount', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ThemeScope(
        controller: ThemeController(),
        child: const MaterialApp(home: BrainDumpFinanceScreen()),
      ),
    );

    await tester.enterText(
      find.byType(TextField).first,
      'bayar kos bulan depan',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Proses Brain Dump'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Nominal belum terdeteksi'), findsOneWidget);
  });

  testWidgets('Profile setting rows navigate to five detail screens', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
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
    await pumpApp(tester);
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
    await pumpApp(tester);
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
    expect(find.text('Baru saja | Manual'), findsOneWidget);
  });

  testWidgets('Budget limit validates and saves only after confirmation', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
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
    await pumpApp(tester);
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
    await pumpApp(tester);
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

  testWidgets('Profile logout requires confirmation and reports session exit', (
    WidgetTester tester,
  ) async {
    final SettingsController settings = SettingsController();
    addTearDown(settings.dispose);
    bool didLogout = false;
    await pumpProfile(tester, settings, onLogout: () => didLogout = true);

    await tester.ensureVisible(find.text('Keluar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keluar'));
    await tester.pumpAndSettle();

    expect(find.text('Keluar dari AturAja?'), findsOneWidget);
    expect(
      find.text('Yakin ingin keluar? Sesi lokal akan diakhiri.'),
      findsOneWidget,
    );
    expect(didLogout, isFalse);

    await tester.tap(find.widgetWithText(TextButton, 'Keluar'));
    await tester.pumpAndSettle();
    expect(didLogout, isTrue);
  });

  testWidgets('Splash opens login when there is no session', (
    WidgetTester tester,
  ) async {
    await pumpApp(
      tester,
      initialLocation: '/splash',
      isLoggedIn: false,
      settle: false,
    );

    expect(find.byType(MainShell), findsNothing);
    expect(find.byType(LoginScreen), findsNothing);

    await tester.pump(const Duration(milliseconds: 2900));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(MainShell), findsNothing);
  });

  testWidgets('Login page validates credentials before continuing', (
    WidgetTester tester,
  ) async {
    bool didLogin = false;
    await tester.pumpWidget(
      ThemeScope(
        controller: ThemeController(),
        child: MaterialApp(home: LoginScreen(onLogin: () => didLogin = true)),
      ),
    );

    expect(find.text('Masuk ke AturAja'), findsOneWidget);

    await tester.ensureVisible(find.byTooltip('Masuk'));
    await tester.tap(find.byTooltip('Masuk'));
    await tester.pump();
    expect(find.text('Email tidak boleh kosong.'), findsOneWidget);
    expect(find.text('Kata sandi tidak boleh kosong.'), findsOneWidget);
    expect(didLogin, isFalse);

    final Finder fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'bukan-email');
    await tester.enterText(fields.at(1), '12345');
    await tester.ensureVisible(find.byTooltip('Masuk'));
    await tester.tap(find.byTooltip('Masuk'));
    await tester.pump();
    expect(find.text('Masukkan format email yang valid.'), findsOneWidget);
    expect(find.text('Kata sandi minimal 6 karakter.'), findsOneWidget);
    expect(didLogin, isFalse);

    await tester.enterText(fields.at(0), 'zidan@atmaja.id');
    await tester.enterText(fields.at(1), 'rahasia123');
    tester.testTextInput.hide();
    await tester.ensureVisible(find.byTooltip('Masuk'));
    await tester.tap(find.byTooltip('Masuk'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    expect(didLogin, isFalse);

    await tester.pump(const Duration(milliseconds: 800));
    expect(didLogin, isTrue);
  });

  testWidgets('Logout opens login and signing in returns to the app', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.byTooltip('Profil'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Keluar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keluar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Keluar'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(MainShell), findsNothing);

    await tester.ensureVisible(find.byTooltip('Masuk'));
    await tester.tap(find.byTooltip('Masuk'));
    await tester.pump();
    expect(find.text('Email tidak boleh kosong.'), findsOneWidget);

    final Finder fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'zidan@atmaja.id');
    await tester.enterText(fields.at(1), 'rahasia123');
    tester.testTextInput.hide();
    await tester.ensureVisible(find.byTooltip('Masuk'));
    await tester.tap(find.byTooltip('Masuk'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsWidgets);

    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();

    expect(find.byType(MainShell), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets(
    'Scan struk creates a real transaction that persists in history',
    (WidgetTester tester) async {
      ReceiptCamera.debugCaptureOverride = () async => 'test-receipt.jpg';
      addTearDown(() => ReceiptCamera.debugCaptureOverride = null);
      final AppProvider app = await pumpApp(tester);
      final int before = app.transactions.length;

      await tester.tap(find.text('Scan Struk'));
      // ScanScreen runs a perpetual scan-line animation, so pumpAndSettle()
      // would hang forever here; advance frames manually instead.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Ambil Foto Struk'), findsOneWidget);

      await tester.tap(find.byTooltip('Ambil foto'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 950));

      expect(find.text('Konfirmasi & Catat'), findsOneWidget);

      await tester.tap(find.text('Konfirmasi & Catat'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 650));
      await tester.pump(const Duration(milliseconds: 400));

      expect(app.transactions.length, before + 1);
      expect(app.transactions.first.label, 'Belanja di Indomaret');
      expect(app.transactions.first.amount, -28500);
      expect(app.transactions.first.cat, 'belanja');
      expect(app.transactions.first.receiptImagePath, 'test-receipt.jpg');
      expect(find.textContaining('berhasil dicatat'), findsOneWidget);
    },
  );

  testWidgets(
    'Manually adding an expense from Finance updates totals and history',
    (WidgetTester tester) async {
      final AppProvider app = await pumpApp(
        tester,
        initialLocation: '/finance',
        transactions: const <TransactionItem>[],
      );

      await tester.tap(find.bySemanticsLabel('Tambah pengeluaran'));
      await tester.pumpAndSettle();

      expect(find.text('Tambah Pengeluaran'), findsOneWidget);

      final Finder fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '25000');
      await tester.enterText(fields.at(1), 'Jajan sore');
      await tester.ensureVisible(find.text('Simpan'));
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();

      expect(app.transactions, hasLength(1));
      expect(app.transactions.first.label, 'Jajan sore');
      expect(app.transactions.first.amount, -25000);
      expect(app.transactions.first.cat, 'food');
      expect(find.textContaining('dicatat'), findsOneWidget);
      expect(find.text('Jajan sore'), findsOneWidget);
    },
  );

  testWidgets('Finance shows scan expenses in the Belanja category', (
    WidgetTester tester,
  ) async {
    await pumpApp(
      tester,
      initialLocation: '/finance',
      transactions: const <TransactionItem>[
        TransactionItem(
          id: 9003,
          label: 'Belanja di Indomaret',
          amount: -28500,
          cat: 'belanja',
          time: '10:00',
        ),
      ],
    );

    expect(find.text('Belanja'), findsWidgets);
    expect(find.text('100% dari total pengeluaran'), findsOneWidget);
  });

  testWidgets(
    'Finance screen computes budget usage and category totals from real transactions',
    (WidgetTester tester) async {
      final AppProvider app = await pumpApp(
        tester,
        initialLocation: '/finance',
        transactions: const <TransactionItem>[
          TransactionItem(
            id: 9001,
            label: 'Makan siang kantin',
            amount: -50000,
            cat: 'food',
            time: '12:00',
          ),
          TransactionItem(
            id: 9002,
            label: 'Nonton bioskop',
            amount: -50000,
            cat: 'entertainment',
            time: '19:00',
          ),
        ],
      );
      app.settings.setMonthlyBudgetLimit(200000);
      await tester.pumpAndSettle();

      expect(find.text('Anggaran Bulan Ini'), findsOneWidget);
      expect(find.text('Rp200.000'), findsOneWidget);
      expect(find.text('Terpakai: Rp100.000'), findsOneWidget);
      expect(find.text('Sisa Rp100.000'), findsOneWidget);
      expect(find.text('50% dari total pengeluaran'), findsNWidgets(2));
    },
  );
}
