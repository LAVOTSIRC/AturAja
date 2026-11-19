import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:aturaja/data/app_store.dart';
import 'package:aturaja/data/models.dart';
import 'package:aturaja/data/roasting_intensity.dart';
import 'package:aturaja/data/settings_controller.dart';
import 'package:aturaja/screens/home_screen.dart';
import 'package:aturaja/screens/notification_settings_screen.dart';
import 'package:aturaja/services/roasting_ai_service.dart';
import 'package:aturaja/theme/theme_scope.dart';

class _RecordingRoastingGenerator implements RoastingAiGenerator {
  _RecordingRoastingGenerator({this.error});

  final Object? error;
  final List<RoastingIntensity> receivedIntensities = <RoastingIntensity>[];

  @override
  Future<String> generate({
    required int totalExpense,
    required int pendingTasks,
    required int transactionCount,
    required RoastingIntensity intensity,
  }) async {
    receivedIntensities.add(intensity);
    final Object? failure = error;
    if (failure != null) {
      throw failure;
    }
    return 'Roasting uji dari AI.';
  }
}

Future<void> _pumpNotificationSettings(
  WidgetTester tester,
  SettingsController settings,
) async {
  final ThemeController theme = ThemeController();
  addTearDown(theme.dispose);
  await tester.pumpWidget(
    ThemeScope(
      controller: theme,
      child: MaterialApp(home: NotificationSettingsScreen(settings: settings)),
    ),
  );
  await tester.pumpAndSettle();
}

Future<AppProvider> _pumpHome(
  WidgetTester tester, {
  required RoastingIntensity intensity,
  RoastingAiGenerator? generator,
}) async {
  final AppProvider app = AppProvider.inMemory(
    tasks: const <TaskItem>[],
    transactions: const <TransactionItem>[],
  );
  app.settings.setRoastingIntensity(intensity);
  addTearDown(app.dispose);
  await tester.pumpWidget(
    ChangeNotifierProvider<AppProvider>.value(
      value: app,
      child: ThemeScope(
        controller: app.theme,
        child: MaterialApp(
          home: Scaffold(
            body: HomeScreen(
              onScan: () {},
              onAddTask: () {},
              onBrainDump: () {},
              roastingAiGenerator: generator,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return app;
}

void main() {
  group('RoastingIntensity', () {
    test(
      'default adalah Seimbang dan fallback nilai tidak valid juga Seimbang',
      () {
        expect(RoastingIntensity.defaultIntensity, RoastingIntensity.seimbang);
        expect(RoastingIntensity.fromStorage(null), RoastingIntensity.seimbang);
        expect(
          RoastingIntensity.fromStorage('tidak-dikenal'),
          RoastingIntensity.seimbang,
        );
        expect(RoastingIntensity.fromStorage('PEDAS'), RoastingIntensity.pedas);
        expect(
          RoastingIntensity.fromStorage('santai'),
          RoastingIntensity.santai,
        );
        expect(
          RoastingIntensity.fromStorage('seimbang'),
          RoastingIntensity.seimbang,
        );
      },
    );

    test(
      'setiap intensitas memiliki deskripsi, pratinjau, dan gaya berbeda',
      () {
        final Set<String> previews = RoastingIntensity.values
            .map((RoastingIntensity intensity) => intensity.preview)
            .toSet();
        final Set<String> instructions = RoastingIntensity.values
            .map((RoastingIntensity intensity) => intensity.instruction)
            .toSet();

        expect(previews, hasLength(3));
        expect(instructions, hasLength(3));
        for (final RoastingIntensity intensity in RoastingIntensity.values) {
          expect(intensity.label, isNotEmpty);
          expect(intensity.description, isNotEmpty);
          expect(intensity.preview, isNotEmpty);
        }
      },
    );
  });

  group('SettingsController roasting intensity', () {
    test('default Seimbang dan setter memperbarui pilihan', () {
      final SettingsController settings = SettingsController();
      addTearDown(settings.dispose);
      int notifications = 0;
      settings.addListener(() => notifications++);

      expect(settings.roastingIntensity, RoastingIntensity.seimbang);

      settings.setRoastingIntensity(RoastingIntensity.santai);
      expect(settings.roastingIntensity, RoastingIntensity.santai);

      settings.setRoastingIntensity(RoastingIntensity.pedas);
      expect(settings.roastingIntensity, RoastingIntensity.pedas);

      settings.setRoastingIntensity(RoastingIntensity.seimbang);
      expect(settings.roastingIntensity, RoastingIntensity.seimbang);
      expect(notifications, 3);
    });

    test('intensitas tersimpan dan pulih lewat toJson/applyJson', () {
      final SettingsController settings = SettingsController();
      addTearDown(settings.dispose);
      settings.setRoastingIntensity(RoastingIntensity.pedas);
      settings.setMonthlyBudgetLimit(2500000);

      final Map<String, dynamic> json = settings.toJson();
      expect(json['roastingIntensity'], 'pedas');

      final SettingsController restored = SettingsController();
      addTearDown(restored.dispose);
      restored.applyJson(json);

      expect(restored.roastingIntensity, RoastingIntensity.pedas);
      expect(restored.monthlyBudgetLimit, 2500000);
    });

    test(
      'data lama tanpa intensitas memakai Seimbang tanpa merusak setelan lain',
      () {
        final SettingsController settings = SettingsController();
        addTearDown(settings.dispose);
        settings.setRoastingIntensity(RoastingIntensity.pedas);

        settings.applyJson(<String, dynamic>{
          'roastingAiEnabled': false,
          'monthlyBudgetLimit': 2000000,
        });

        expect(settings.roastingIntensity, RoastingIntensity.seimbang);
        expect(settings.roastingAiEnabled, isFalse);
        expect(settings.monthlyBudgetLimit, 2000000);
      },
    );

    test('nilai intensitas tidak valid memakai fallback Seimbang', () {
      final SettingsController settings = SettingsController();
      addTearDown(settings.dispose);
      settings.setRoastingIntensity(RoastingIntensity.santai);

      settings.applyJson(<String, dynamic>{'roastingIntensity': 'ekstrem'});

      expect(settings.roastingIntensity, RoastingIntensity.seimbang);
    });

    test('resetToDefaults mengembalikan intensitas ke Seimbang', () {
      final SettingsController settings = SettingsController();
      addTearDown(settings.dispose);
      settings.setRoastingIntensity(RoastingIntensity.pedas);

      settings.resetToDefaults();

      expect(settings.roastingIntensity, RoastingIntensity.seimbang);
    });

    test('menonaktifkan Roasting AI tidak menghapus pilihan intensitas', () {
      final SettingsController settings = SettingsController();
      addTearDown(settings.dispose);
      settings.setRoastingIntensity(RoastingIntensity.pedas);

      settings.setRoastingAi(false);

      expect(settings.roastingAiEnabled, isFalse);
      expect(settings.roastingIntensity, RoastingIntensity.pedas);
    });
  });

  group('Penyimpanan AppProvider', () {
    test('intensitas tetap tersimpan setelah aplikasi dimuat ulang', () async {
      final MemoryAppStorage storage = MemoryAppStorage();
      final AppProvider store = AppProvider(
        storage: storage,
        settings: SettingsController(),
        theme: ThemeController(),
        tasks: const <TaskItem>[],
        transactions: const <TransactionItem>[],
        profile: ProfileData.initial,
      );
      addTearDown(store.dispose);
      await store.load();
      store.settings.setRoastingIntensity(RoastingIntensity.pedas);
      store.settings.setRoastingAi(false);
      await store.save();

      final AppProvider restored = AppProvider(
        storage: storage,
        settings: SettingsController(),
        theme: ThemeController(),
        tasks: const <TaskItem>[],
        transactions: const <TransactionItem>[],
        profile: ProfileData.initial,
      );
      addTearDown(restored.dispose);
      await restored.load();

      expect(restored.settings.roastingIntensity, RoastingIntensity.pedas);
      expect(restored.settings.roastingAiEnabled, isFalse);
    });

    test(
      'data pengaturan lama tanpa properti intensitas tetap dimuat',
      () async {
        final String legacyData = jsonEncode(<String, dynamic>{
          'version': 1,
          'tasks': <Map<String, dynamic>>[],
          'transactions': <Map<String, dynamic>>[],
          'profile': ProfileData.initial.toJson(),
          'settings': <String, dynamic>{
            'roastingAiEnabled': false,
            'monthlyBudgetLimit': 2000000,
          },
          'theme': <String, dynamic>{'isDark': false},
        });
        final AppProvider store = AppProvider(
          storage: MemoryAppStorage(legacyData),
          settings: SettingsController(),
          theme: ThemeController(),
          tasks: const <TaskItem>[],
          transactions: const <TransactionItem>[],
          profile: ProfileData.initial,
        );
        addTearDown(store.dispose);

        await store.load();

        expect(store.settings.roastingIntensity, RoastingIntensity.seimbang);
        expect(store.settings.roastingAiEnabled, isFalse);
        expect(store.settings.monthlyBudgetLimit, 2000000);
      },
    );
  });

  group('RoastingAiService', () {
    test(
      'system instruction mengikuti intensitas dan mempertahankan batasan',
      () {
        final String santai = RoastingAiService.systemInstructionFor(
          RoastingIntensity.santai,
        );
        final String seimbang = RoastingAiService.systemInstructionFor(
          RoastingIntensity.seimbang,
        );
        final String pedas = RoastingAiService.systemInstructionFor(
          RoastingIntensity.pedas,
        );

        expect(santai, contains('Gaya SANTAI'));
        expect(santai, contains('Jangan gunakan sarkasme yang tajam'));
        expect(seimbang, contains('Gaya SEIMBANG'));
        expect(seimbang, contains('sindiran ringan'));
        expect(pedas, contains('Gaya PEDAS'));
        expect(pedas, contains('sarkasme'));
        expect(<String>{santai, seimbang, pedas}, hasLength(3));

        for (final String instruction in <String>[santai, seimbang, pedas]) {
          expect(instruction, contains('2 sampai 3 kalimat'));
          expect(instruction, contains('jangan mengarang'));
          expect(instruction, contains('jangan menghina'));
          expect(instruction, contains('bukan menyerang pribadi'));
          expect(instruction, contains('tetap berikan dorongan atau saran'));
        }
      },
    );
  });

  group('Fallback roasting', () {
    test('fallback mengikuti intensitas yang dipilih', () {
      final Map<RoastingIntensity, String> messages =
          <RoastingIntensity, String>{
            for (final RoastingIntensity intensity in RoastingIntensity.values)
              intensity: fallbackRoastFor(
                intensity: intensity,
                pendingTasks: 3,
                totalExpense: 1500000,
                budgetLimit: 1200000,
              ),
          };

      expect(messages.values.toSet(), hasLength(3));
      expect(messages[RoastingIntensity.santai], contains('langkah kecil'));
      expect(messages[RoastingIntensity.seimbang], contains('Dek'));
      expect(messages[RoastingIntensity.pedas], contains('tab belanja'));
    });

    test('semua kondisi aktivitas memiliki fallback untuk tiap intensitas', () {
      for (final RoastingIntensity intensity in RoastingIntensity.values) {
        final List<String> messages = <String>[
          fallbackRoastFor(
            intensity: intensity,
            pendingTasks: 2,
            totalExpense: 1500000,
            budgetLimit: 1200000,
          ),
          fallbackRoastFor(
            intensity: intensity,
            pendingTasks: 2,
            totalExpense: 100000,
            budgetLimit: 1200000,
          ),
          fallbackRoastFor(
            intensity: intensity,
            pendingTasks: 0,
            totalExpense: 1500000,
            budgetLimit: 1200000,
          ),
          fallbackRoastFor(
            intensity: intensity,
            pendingTasks: 0,
            totalExpense: 100000,
            budgetLimit: 1200000,
          ),
        ];

        expect(messages.toSet(), hasLength(4));
        for (final String message in messages) {
          expect(message.trim(), isNotEmpty);
        }
      }
    });
  });

  group('UI pengaturan intensitas', () {
    testWidgets('pratinjau berubah saat memilih Santai, Seimbang, dan Pedas', (
      WidgetTester tester,
    ) async {
      final SettingsController settings = SettingsController();
      addTearDown(settings.dispose);
      await _pumpNotificationSettings(tester, settings);

      expect(find.text(RoastingIntensity.seimbang.preview), findsOneWidget);
      expect(settings.roastingIntensity, RoastingIntensity.seimbang);

      for (final RoastingIntensity intensity in <RoastingIntensity>[
        RoastingIntensity.santai,
        RoastingIntensity.seimbang,
        RoastingIntensity.pedas,
      ]) {
        final Finder option = find.text(intensity.label);
        await tester.ensureVisible(option);
        await tester.tap(option);
        await tester.pumpAndSettle();

        expect(settings.roastingIntensity, intensity);
        expect(find.text(intensity.preview), findsOneWidget);
        expect(
          find.text('CONTOH GAYA ${intensity.label.toUpperCase()}'),
          findsOneWidget,
        );
      }
    });

    testWidgets('intensitas nonaktif tetap tersimpan dan tidak bisa diubah', (
      WidgetTester tester,
    ) async {
      final SettingsController settings = SettingsController();
      addTearDown(settings.dispose);
      settings.setRoastingIntensity(RoastingIntensity.pedas);
      await _pumpNotificationSettings(tester, settings);

      final Finder roastingTile = find.ancestor(
        of: find.text('Roasting AI'),
        matching: find.byType(SwitchListTile),
      );
      final Finder roastingSwitch = find.descendant(
        of: roastingTile,
        matching: find.byType(Switch),
      );
      await tester.ensureVisible(roastingSwitch);
      await tester.tap(roastingSwitch);
      await tester.pumpAndSettle();

      expect(settings.roastingAiEnabled, isFalse);
      expect(settings.roastingIntensity, RoastingIntensity.pedas);
      expect(
        find.text(
          'Aktifkan Roasting AI untuk menerapkan intensitas ini. '
          'Pilihanmu tetap tersimpan.',
        ),
        findsOneWidget,
      );
      expect(find.text(RoastingIntensity.pedas.preview), findsOneWidget);

      final Finder santaiOption = find.text('Santai');
      await tester.ensureVisible(santaiOption);
      await tester.tap(santaiOption);
      await tester.pumpAndSettle();

      expect(settings.roastingIntensity, RoastingIntensity.pedas);
    });
  });

  group('Integrasi HomeScreen', () {
    testWidgets('intensitas terbaru diteruskan ke generator roasting', (
      WidgetTester tester,
    ) async {
      final _RecordingRoastingGenerator generator =
          _RecordingRoastingGenerator();
      final AppProvider app = await _pumpHome(
        tester,
        intensity: RoastingIntensity.pedas,
        generator: generator,
      );

      await tester.tap(find.byTooltip('Notifikasi, notifikasi baru'));
      await tester.pumpAndSettle();

      expect(generator.receivedIntensities, <RoastingIntensity>[
        RoastingIntensity.pedas,
      ]);
      expect(find.text('Roasting uji dari AI.'), findsOneWidget);

      app.settings.setRoastingIntensity(RoastingIntensity.santai);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Notifikasi, notifikasi baru'));
      await tester.pumpAndSettle();

      expect(generator.receivedIntensities, <RoastingIntensity>[
        RoastingIntensity.pedas,
        RoastingIntensity.santai,
      ]);
    });

    testWidgets('fallback di HomeScreen mengikuti intensitas yang dipilih', (
      WidgetTester tester,
    ) async {
      final _RecordingRoastingGenerator generator = _RecordingRoastingGenerator(
        error: const FormatException('gagal'),
      );
      final AppProvider app = await _pumpHome(
        tester,
        intensity: RoastingIntensity.santai,
        generator: generator,
      );

      await tester.tap(find.byTooltip('Notifikasi, notifikasi baru'));
      await tester.pumpAndSettle();

      final String expected = fallbackRoastFor(
        intensity: RoastingIntensity.santai,
        pendingTasks: app.pendingTaskCount,
        totalExpense: app.totalExpense,
        budgetLimit: app.budgetLimit,
      );
      expect(find.text(expected), findsOneWidget);
      expect(
        find.text(
          fallbackRoastFor(
            intensity: RoastingIntensity.pedas,
            pendingTasks: app.pendingTaskCount,
            totalExpense: app.totalExpense,
            budgetLimit: app.budgetLimit,
          ),
        ),
        findsNothing,
      );
    });
  });
}
