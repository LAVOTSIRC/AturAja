import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aturaja/data/models.dart';
import 'package:aturaja/data/roasting_intensity.dart';
import 'package:aturaja/data/roasting_notification.dart';
import 'package:aturaja/providers/app_provider.dart';
import 'package:aturaja/providers/settings_provider.dart';
import 'package:aturaja/screens/notification_settings_screen.dart';
import 'package:aturaja/services/budget_alert_service.dart';
import 'package:aturaja/services/local_notification_service.dart';
import 'package:aturaja/services/notification_ids.dart';
import 'package:aturaja/services/roasting_ai_service.dart';
import 'package:aturaja/services/roasting_notification_service.dart';
import 'package:aturaja/theme/theme_scope.dart';

class _ScheduledTask {
  final TaskItem task;
  final String? title;
  final String? body;

  const _ScheduledTask({
    required this.task,
    required this.title,
    required this.body,
  });
}

class _ScheduledDaily {
  final int id;
  final DateTime scheduledAt;
  final String title;
  final String body;
  final String payload;

  const _ScheduledDaily({
    required this.id,
    required this.scheduledAt,
    required this.title,
    required this.body,
    required this.payload,
  });
}

class _FakeNotificationService
    implements AppNotificationService, DailyRoastingCleaner {
  final List<_ScheduledTask> taskSchedules = <_ScheduledTask>[];
  final List<_ScheduledDaily> dailySchedules = <_ScheduledDaily>[];
  final List<int> cancelledNotificationIds = <int>[];
  final List<String> budgetTitles = <String>[];
  final List<String> budgetBodies = <String>[];
  final List<String> rescheduledTaskIds = <String>[];
  int cancelAllTaskCalls = 0;
  int rescheduleTaskCalls = 0;
  int cancelOtherDailyCalls = 0;
  String? lastKeptDailyUser;
  bool dailyScheduleResult = true;
  bool permissionGranted = true;

  void clearRecords() {
    taskSchedules.clear();
    dailySchedules.clear();
    cancelledNotificationIds.clear();
    budgetTitles.clear();
    budgetBodies.clear();
    rescheduledTaskIds.clear();
    cancelAllTaskCalls = 0;
    rescheduleTaskCalls = 0;
    cancelOtherDailyCalls = 0;
    lastKeptDailyUser = null;
  }

  @override
  Future<bool> requestPermissions() async => permissionGranted;

  @override
  Future<void> scheduleTaskReminder(
    TaskItem task, {
    String? title,
    String? body,
  }) async {
    taskSchedules.add(_ScheduledTask(task: task, title: title, body: body));
  }

  @override
  Future<void> cancelTaskReminder(String taskId) async {}

  @override
  Future<void> rescheduleTaskReminders(List<TaskItem> tasks) async {
    rescheduleTaskCalls++;
    rescheduledTaskIds
      ..clear()
      ..addAll(tasks.map((TaskItem task) => task.id));
  }

  @override
  Future<void> cancelAllTaskReminders() async {
    cancelAllTaskCalls++;
  }

  @override
  Future<void> showBudgetAlert({
    required int id,
    required String title,
    required String body,
  }) async {
    budgetTitles.add(title);
    budgetBodies.add(body);
  }

  @override
  Future<bool> scheduleDailyRoasting({
    required int id,
    required DateTime scheduledAt,
    required String title,
    required String body,
    required String payload,
  }) async {
    dailySchedules.add(
      _ScheduledDaily(
        id: id,
        scheduledAt: scheduledAt,
        title: title,
        body: body,
        payload: payload,
      ),
    );
    return dailyScheduleResult;
  }

  @override
  Future<void> cancelNotification(int id) async {
    cancelledNotificationIds.add(id);
  }

  @override
  Future<void> cancelDailyRoastingExcept(String? userId) async {
    cancelOtherDailyCalls++;
    lastKeptDailyUser = userId;
  }
}

class _FakeRoastingGenerator implements RoastingNotificationGenerator {
  Object? budgetError;
  Object? deadlineError;
  Object? dailyError;

  int budgetCalls = 0;
  int deadlineCalls = 0;
  int dailyCalls = 0;
  RoastingIntensity? lastBudgetIntensity;
  RoastingIntensity? lastDeadlineIntensity;
  RoastingIntensity? lastDailyIntensity;
  int? lastBudgetThreshold;
  int? lastBudgetSpent;
  int? lastBudgetLimit;
  String? lastDeadlineTitle;
  DateTime? lastDeadlineDueAt;
  Duration? lastDeadlineRemaining;
  DailyRoastingSummary? lastDailySummary;
  List<String> lastRecentMessages = <String>[];

  @override
  Future<RoastingNotificationMessage> generateBudgetNotification({
    required RoastingIntensity intensity,
    required int spent,
    required int limit,
    required int threshold,
    required List<String> recentMessages,
  }) async {
    budgetCalls++;
    lastBudgetIntensity = intensity;
    lastBudgetSpent = spent;
    lastBudgetLimit = limit;
    lastBudgetThreshold = threshold;
    lastRecentMessages = List<String>.of(recentMessages);
    final Object? failure = budgetError;
    if (failure != null) {
      throw failure;
    }
    return RoastingNotificationMessage(
      body: 'AI budget $spent/$limit ambang $threshold ${intensity.name}',
      generatedByAi: true,
      kind: RoastingNotificationKind.budget,
    );
  }

  @override
  Future<RoastingNotificationMessage> generateDeadlineNotification({
    required RoastingIntensity intensity,
    required String taskTitle,
    required DateTime dueAt,
    required Duration remaining,
    required List<String> recentMessages,
  }) async {
    deadlineCalls++;
    lastDeadlineIntensity = intensity;
    lastDeadlineTitle = taskTitle;
    lastDeadlineDueAt = dueAt;
    lastDeadlineRemaining = remaining;
    lastRecentMessages = List<String>.of(recentMessages);
    final Object? failure = deadlineError;
    if (failure != null) {
      throw failure;
    }
    return RoastingNotificationMessage(
      body:
          'AI deadline $taskTitle sisa ${remaining.inMinutes} menit '
          'pukul ${dueAt.hour}:${dueAt.minute} ${intensity.name}',
      generatedByAi: true,
      kind: RoastingNotificationKind.deadline,
    );
  }

  @override
  Future<RoastingNotificationMessage> generateDailyNotification({
    required RoastingIntensity intensity,
    required DailyRoastingSummary summary,
    required List<String> recentMessages,
  }) async {
    dailyCalls++;
    lastDailyIntensity = intensity;
    lastDailySummary = summary;
    lastRecentMessages = List<String>.of(recentMessages);
    final Object? failure = dailyError;
    if (failure != null) {
      throw failure;
    }
    return RoastingNotificationMessage(
      body:
          'AI daily ${summary.pendingTasks} tugas, '
          '${summary.todayTransactionCount} transaksi ${intensity.name}',
      generatedByAi: true,
      kind: RoastingNotificationKind.daily,
    );
  }
}

SettingsController _settings({
  bool master = true,
  bool budgetAlerts = true,
  bool deadlineNotifications = true,
  bool budgetRoast = false,
  bool deadlineRoast = false,
  bool dailyRoast = false,
  int hour = 20,
  int minute = 0,
  RoastingIntensity intensity = RoastingIntensity.seimbang,
}) {
  final SettingsController settings = SettingsController()
    ..roastingAiEnabled = master
    ..budgetAlertsEnabled = budgetAlerts
    ..deadlineNotificationsEnabled = deadlineNotifications
    ..budgetRoastingEnabled = budgetRoast
    ..deadlineRoastingEnabled = deadlineRoast
    ..dailyRoastingEnabled = dailyRoast
    ..dailyRoastingHour = hour
    ..dailyRoastingMinute = minute
    ..roastingIntensity = intensity;
  return settings;
}

TaskItem _task({
  String id = 'task-1',
  String title = 'Tugas laporan',
  String deadline = 'Besok',
  DateTime? dueDate,
  bool done = false,
  DateTime? completedAt,
}) {
  return TaskItem(
    id: id,
    title: title,
    deadline: deadline,
    dueDate: dueDate,
    done: done,
    completedAt: completedAt,
  );
}

const DailyRoastingSummary _summary = DailyRoastingSummary(
  pendingTasks: 3,
  dueTodayTasks: 1,
  overdueTasks: 1,
  completedToday: 2,
  todayExpense: 25000,
  todayTransactionCount: 2,
);

Future<SharedPreferences> _preferences() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  return SharedPreferences.getInstance();
}

Future<void> _pumpSettings(
  WidgetTester tester,
  SettingsController settings, {
  Future<bool> Function(bool value)? onBudgetRoastingChanged,
  Future<bool> Function(bool value)? onDeadlineRoastingChanged,
  Future<bool> Function(bool value)? onDailyRoastingChanged,
  Future<void> Function(int hour, int minute)? onDailyTimeChanged,
}) async {
  final ThemeController theme = ThemeController();
  addTearDown(theme.dispose);
  await tester.pumpWidget(
    ThemeScope(
      controller: theme,
      child: MaterialApp(
        home: NotificationSettingsScreen(
          settings: settings,
          onBudgetRoastingChanged: onBudgetRoastingChanged,
          onDeadlineRoastingChanged: onDeadlineRoastingChanged,
          onDailyRoastingChanged: onDailyRoastingChanged,
          onDailyTimeChanged: onDailyTimeChanged,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _switchFor(String title) {
  return find.descendant(
    of: find.ancestor(
      of: find.text(title),
      matching: find.byType(SwitchListTile),
    ),
    matching: find.byType(Switch),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Pengaturan notifikasi roasting otomatis', () {
    test('default nonaktif, waktu 20.00, tersimpan, dan reset aman', () {
      final SettingsController settings = SettingsController();
      addTearDown(settings.dispose);

      expect(settings.budgetRoastingEnabled, isFalse);
      expect(settings.deadlineRoastingEnabled, isFalse);
      expect(settings.dailyRoastingEnabled, isFalse);
      expect(settings.dailyRoastingHour, 20);
      expect(settings.dailyRoastingMinute, 0);
      expect(settings.dailyRoastingTimeLabel, '20.00');

      settings.setBudgetRoasting(true);
      settings.setDeadlineRoasting(true);
      settings.setDailyRoasting(true);
      settings.setDailyRoastingTime(21, 45);
      settings.setRoastingAi(false);

      final Map<String, dynamic> json = settings.toJson();
      expect(json['budgetRoastingEnabled'], isTrue);
      expect(json['deadlineRoastingEnabled'], isTrue);
      expect(json['dailyRoastingEnabled'], isTrue);
      expect(json['dailyRoastingHour'], 21);
      expect(json['dailyRoastingMinute'], 45);
      expect(json['roastingAiEnabled'], isFalse);

      final SettingsController restored = SettingsController()..applyJson(json);
      addTearDown(restored.dispose);
      expect(restored.budgetRoastingEnabled, isTrue);
      expect(restored.deadlineRoastingEnabled, isTrue);
      expect(restored.dailyRoastingEnabled, isTrue);
      expect(restored.dailyRoastingHour, 21);
      expect(restored.dailyRoastingMinute, 45);
      expect(restored.roastingAiEnabled, isFalse);

      restored.resetToDefaults();
      expect(restored.budgetRoastingEnabled, isFalse);
      expect(restored.deadlineRoastingEnabled, isFalse);
      expect(restored.dailyRoastingEnabled, isFalse);
      expect(restored.dailyRoastingHour, 20);
      expect(restored.dailyRoastingMinute, 0);
    });

    test('data lama dan waktu tidak valid memakai default yang aman', () {
      final SettingsController legacy = SettingsController()
        ..applyJson(<String, dynamic>{'roastingAiEnabled': false});
      addTearDown(legacy.dispose);
      expect(legacy.budgetRoastingEnabled, isFalse);
      expect(legacy.deadlineRoastingEnabled, isFalse);
      expect(legacy.dailyRoastingEnabled, isFalse);
      expect(legacy.dailyRoastingHour, 20);
      expect(legacy.dailyRoastingMinute, 0);

      final SettingsController invalid = SettingsController()
        ..applyJson(<String, dynamic>{
          'dailyRoastingHour': 99,
          'dailyRoastingMinute': -2,
        });
      addTearDown(invalid.dispose);
      expect(invalid.dailyRoastingHour, 20);
      expect(invalid.dailyRoastingMinute, 0);

      invalid.setDailyRoastingTime(30, 90);
      expect(invalid.dailyRoastingHour, 23);
      expect(invalid.dailyRoastingMinute, 59);
    });
  });

  group('Budget Roasting', () {
    test('mengirim satu konten AI per ambang 80% dan 100%', () async {
      final SharedPreferences prefs = await _preferences();
      final SettingsController settings = _settings(
        budgetRoast: true,
        intensity: RoastingIntensity.pedas,
      );
      addTearDown(settings.dispose);
      final _FakeNotificationService notifications = _FakeNotificationService();
      final _FakeRoastingGenerator generator = _FakeRoastingGenerator();
      final RoastingNotificationService coordinator =
          RoastingNotificationService(
            notifications: notifications,
            generator: generator,
            settings: settings,
            preferences: prefs,
            activeUserId: () => 'user-a',
          );
      final BudgetAlertService service = BudgetAlertService(
        notifications: notifications,
        preferences: prefs,
      );
      Future<BudgetAlertContent?> contentBuilder({
        required int threshold,
        required int spent,
        required int limit,
      }) => coordinator.buildBudgetContent(
        userId: 'user-a',
        threshold: threshold,
        spent: spent,
        limit: limit,
      );

      Future<void> check(int spent) => service.check(
        userId: 'user-a',
        spent: spent,
        limit: 1000,
        enabled: true,
        contentBuilder: contentBuilder,
      );

      await check(800);
      expect(generator.budgetCalls, 1);
      expect(generator.lastBudgetIntensity, RoastingIntensity.pedas);
      expect(generator.lastBudgetThreshold, 80);
      expect(notifications.budgetTitles, <String>['Budget Roasting']);
      expect(notifications.budgetBodies.single, contains('AI budget'));

      await check(950);
      expect(
        generator.budgetCalls,
        1,
        reason: 'Ambang 80% tidak boleh diulang.',
      );
      expect(notifications.budgetBodies, hasLength(1));

      await check(1000);
      expect(generator.budgetCalls, 2);
      expect(generator.lastBudgetThreshold, 100);
      expect(notifications.budgetTitles, hasLength(2));
      expect(notifications.budgetBodies.last, contains('ambang 100'));

      await check(1200);
      expect(
        generator.budgetCalls,
        2,
        reason: 'Ambang 100% tidak boleh diulang.',
      );
      expect(notifications.budgetBodies, hasLength(2));

      notifications.clearRecords();
      final BudgetAlertService restarted = BudgetAlertService(
        notifications: notifications,
        preferences: prefs,
      );
      await restarted.check(
        userId: 'user-a',
        spent: 1000,
        limit: 1000,
        enabled: true,
        contentBuilder: contentBuilder,
      );
      expect(
        notifications.budgetBodies,
        isEmpty,
        reason: 'Status ambang harus bertahan setelah restart.',
      );
      expect(generator.budgetCalls, 2);
    });

    test('pemeriksaan bersamaan tidak membuat notifikasi ganda', () async {
      final SharedPreferences prefs = await _preferences();
      final SettingsController settings = _settings(budgetRoast: true);
      addTearDown(settings.dispose);
      final _FakeNotificationService notifications = _FakeNotificationService();
      final _FakeRoastingGenerator generator = _FakeRoastingGenerator();
      final RoastingNotificationService coordinator =
          RoastingNotificationService(
            notifications: notifications,
            generator: generator,
            settings: settings,
            preferences: prefs,
            activeUserId: () => 'user-a',
          );
      final BudgetAlertService service = BudgetAlertService(
        notifications: notifications,
        preferences: prefs,
      );
      Future<BudgetAlertContent?> contentBuilder({
        required int threshold,
        required int spent,
        required int limit,
      }) => coordinator.buildBudgetContent(
        userId: 'user-a',
        threshold: threshold,
        spent: spent,
        limit: limit,
      );

      await Future.wait(<Future<void>>[
        service.check(
          userId: 'user-a',
          spent: 800,
          limit: 1000,
          enabled: true,
          contentBuilder: contentBuilder,
        ),
        service.check(
          userId: 'user-a',
          spent: 800,
          limit: 1000,
          enabled: true,
          contentBuilder: contentBuilder,
        ),
      ]);

      expect(generator.budgetCalls, 1);
      expect(notifications.budgetBodies, hasLength(1));
    });

    test(
      'fallback lokal dipakai saat Gemini gagal dan dapat dibedakan',
      () async {
        final SharedPreferences prefs = await _preferences();
        final SettingsController settings = _settings(
          budgetRoast: true,
          intensity: RoastingIntensity.seimbang,
        );
        addTearDown(settings.dispose);
        final _FakeNotificationService notifications =
            _FakeNotificationService();
        final _FakeRoastingGenerator generator = _FakeRoastingGenerator()
          ..budgetError = Exception('offline');
        final RoastingNotificationService coordinator =
            RoastingNotificationService(
              notifications: notifications,
              generator: generator,
              settings: settings,
              preferences: prefs,
              activeUserId: () => 'user-a',
            );

        final BudgetAlertContent? content = await coordinator
            .buildBudgetContent(
              userId: 'user-a',
              threshold: 80,
              spent: 800,
              limit: 1000,
            );

        expect(content, isNotNull);
        expect(content!.generatedByAi, isFalse);
        expect(content.title, 'Budget Roasting');
        expect(content.body, contains('Rp800'));
        expect(content.body, contains('80%'));
      },
    );

    test('alert dibatalkan jika akun berganti saat konten disiapkan', () async {
      final SharedPreferences prefs = await _preferences();
      final _FakeNotificationService notifications = _FakeNotificationService();
      final BudgetAlertService service = BudgetAlertService(
        notifications: notifications,
        preferences: prefs,
      );
      bool active = true;

      await service.check(
        userId: 'user-a',
        spent: 800,
        limit: 1000,
        enabled: true,
        contentBuilder:
            ({
              required int threshold,
              required int spent,
              required int limit,
            }) async {
              active = false;
              return const BudgetAlertContent(
                title: 'Budget Roasting',
                body: 'Konten akun lama',
                generatedByAi: true,
              );
            },
        shouldNotify: () => active,
      );

      expect(notifications.budgetBodies, isEmpty);

      active = true;
      await service.check(
        userId: 'user-a',
        spent: 800,
        limit: 1000,
        enabled: true,
      );
      expect(notifications.budgetTitles, <String>['Budget alert 80%']);
    });

    test(
      'Budget Alert biasa tetap dipakai saat Budget Roasting nonaktif',
      () async {
        final SharedPreferences prefs = await _preferences();
        final SettingsController settings = _settings(
          budgetAlerts: true,
          budgetRoast: false,
        );
        addTearDown(settings.dispose);
        final _FakeNotificationService notifications =
            _FakeNotificationService();
        final _FakeRoastingGenerator generator = _FakeRoastingGenerator();
        final RoastingNotificationService coordinator =
            RoastingNotificationService(
              notifications: notifications,
              generator: generator,
              settings: settings,
              preferences: prefs,
              activeUserId: () => 'user-a',
            );
        final BudgetAlertService service = BudgetAlertService(
          notifications: notifications,
          preferences: prefs,
        );

        expect(
          await coordinator.buildBudgetContent(
            userId: 'user-a',
            threshold: 80,
            spent: 800,
            limit: 1000,
          ),
          isNull,
        );
        await service.check(
          userId: 'user-a',
          spent: 800,
          limit: 1000,
          enabled: true,
        );

        expect(generator.budgetCalls, 0);
        expect(notifications.budgetTitles, <String>['Budget alert 80%']);
        expect(notifications.budgetBodies.single, contains('80%'));
      },
    );
  });

  group('Deadline Roasting', () {
    test(
      'konten AI disimpan, dipakai ulang, dan mengikuti intensitas terbaru',
      () async {
        final SharedPreferences prefs = await _preferences();
        final SettingsController settings = _settings(
          deadlineRoast: true,
          intensity: RoastingIntensity.pedas,
        );
        addTearDown(settings.dispose);
        final _FakeNotificationService notifications =
            _FakeNotificationService();
        final _FakeRoastingGenerator generator = _FakeRoastingGenerator();
        final DateTime now = DateTime(2026, 11, 19, 8);
        final DateTime due = now.add(const Duration(hours: 3));
        final RoastingNotificationService coordinator =
            RoastingNotificationService(
              notifications: notifications,
              generator: generator,
              settings: settings,
              preferences: prefs,
              clock: () => now,
              activeUserId: () => 'user-a',
            );
        final TaskItem task = _task(dueDate: due);

        await coordinator.syncTaskReminders(
          userId: 'user-a',
          tasks: <TaskItem>[task],
        );
        expect(generator.deadlineCalls, 1);
        expect(generator.lastDeadlineIntensity, RoastingIntensity.pedas);
        expect(generator.lastDeadlineTitle, task.title);
        expect(generator.lastDeadlineDueAt, due);
        expect(generator.lastDeadlineRemaining, const Duration(minutes: 5));
        expect(notifications.taskSchedules, hasLength(1));
        expect(notifications.taskSchedules.single.title, 'Deadline Roasting');
        expect(
          notifications.taskSchedules.single.body,
          contains('AI deadline'),
        );
        final String firstBody = notifications.taskSchedules.single.body!;

        await coordinator.syncTaskReminders(
          userId: 'user-a',
          tasks: <TaskItem>[task],
        );
        expect(
          generator.deadlineCalls,
          1,
          reason: 'Pesan tugas harus dipakai ulang.',
        );
        expect(notifications.taskSchedules, hasLength(2));
        expect(notifications.taskSchedules.last.body, firstBody);

        final RoastingNotificationService restarted =
            RoastingNotificationService(
              notifications: notifications,
              generator: generator,
              settings: settings,
              preferences: prefs,
              clock: () => now,
              activeUserId: () => 'user-a',
            );
        await restarted.syncTaskReminders(
          userId: 'user-a',
          tasks: <TaskItem>[task],
        );
        expect(
          generator.deadlineCalls,
          1,
          reason: 'Cache pesan harus bertahan setelah restart.',
        );
        expect(notifications.taskSchedules.last.body, firstBody);

        settings.setRoastingIntensity(RoastingIntensity.santai);
        await coordinator.syncTaskReminders(
          userId: 'user-a',
          tasks: <TaskItem>[task],
        );
        expect(generator.deadlineCalls, 2);
        expect(generator.lastDeadlineIntensity, RoastingIntensity.santai);
        expect(generator.lastRecentMessages, contains(firstBody));
        expect(notifications.taskSchedules.last.body, contains('santai'));

        final TaskItem changed = task.copyWith(
          dueDate: due.add(const Duration(hours: 1)),
        );
        await coordinator.syncTaskReminders(
          userId: 'user-a',
          tasks: <TaskItem>[changed],
        );
        expect(generator.deadlineCalls, 3);
        expect(generator.lastDeadlineDueAt, changed.dueDate);
        expect(
          notifications.taskSchedules.last.body,
          isNot(
            notifications
                .taskSchedules[notifications.taskSchedules.length - 2]
                .body,
          ),
        );
      },
    );

    test(
      'sisa waktu yang berubah menghasilkan konten baru yang akurat',
      () async {
        final SharedPreferences prefs = await _preferences();
        final SettingsController settings = _settings(deadlineRoast: true);
        addTearDown(settings.dispose);
        final _FakeNotificationService notifications =
            _FakeNotificationService();
        final _FakeRoastingGenerator generator = _FakeRoastingGenerator();
        DateTime now = DateTime(2026, 11, 19, 8);
        final DateTime due = now.add(const Duration(minutes: 30));
        final RoastingNotificationService coordinator =
            RoastingNotificationService(
              notifications: notifications,
              generator: generator,
              settings: settings,
              preferences: prefs,
              clock: () => now,
              activeUserId: () => 'user-a',
            );
        final TaskItem task = _task(dueDate: due);

        await coordinator.syncTaskReminders(
          userId: 'user-a',
          tasks: <TaskItem>[task],
        );
        expect(generator.deadlineCalls, 1);
        expect(generator.lastDeadlineRemaining, const Duration(minutes: 5));

        await coordinator.syncTaskReminders(
          userId: 'user-a',
          tasks: <TaskItem>[task],
        );
        expect(generator.deadlineCalls, 1);

        now = DateTime(2026, 11, 19, 8, 27);
        await coordinator.syncTaskReminders(
          userId: 'user-a',
          tasks: <TaskItem>[task],
        );
        expect(generator.deadlineCalls, 2);
        expect(
          generator.lastDeadlineRemaining,
          const Duration(minutes: 2, seconds: 55),
        );
        expect(notifications.taskSchedules.last.body, contains('2 menit'));
      },
    );

    test(
      'selesai, dihapus, dan dinonaktifkan tidak meninggalkan AI alert',
      () async {
        final SharedPreferences prefs = await _preferences();
        final SettingsController settings = _settings(deadlineRoast: true);
        addTearDown(settings.dispose);
        final _FakeNotificationService notifications =
            _FakeNotificationService();
        final _FakeRoastingGenerator generator = _FakeRoastingGenerator();
        final DateTime now = DateTime(2026, 11, 19, 8);
        final DateTime due = now.add(const Duration(hours: 3));
        final RoastingNotificationService coordinator =
            RoastingNotificationService(
              notifications: notifications,
              generator: generator,
              settings: settings,
              preferences: prefs,
              clock: () => now,
              activeUserId: () => 'user-a',
            );
        final TaskItem task = _task(dueDate: due);

        await coordinator.syncTaskReminders(
          userId: 'user-a',
          tasks: <TaskItem>[task],
        );
        expect(generator.deadlineCalls, 1);
        notifications.clearRecords();

        final TaskItem completed = task.copyWith(done: true, completedAt: now);
        await coordinator.syncTaskReminders(
          userId: 'user-a',
          tasks: <TaskItem>[completed],
        );
        expect(generator.deadlineCalls, 1);
        expect(notifications.taskSchedules, isEmpty);
        expect(notifications.cancelAllTaskCalls, greaterThan(0));

        notifications.clearRecords();
        await coordinator.syncTaskReminders(
          userId: 'user-a',
          tasks: <TaskItem>[],
        );
        expect(generator.deadlineCalls, 1);
        expect(notifications.taskSchedules, isEmpty);
        expect(notifications.cancelAllTaskCalls, greaterThan(0));

        settings.setDeadlineRoasting(false);
        notifications.clearRecords();
        await coordinator.syncTaskReminders(
          userId: 'user-a',
          tasks: <TaskItem>[task],
        );
        expect(generator.deadlineCalls, 1);
        expect(notifications.rescheduleTaskCalls, 1);
        expect(notifications.rescheduledTaskIds, <String>[task.id]);

        settings.setDeadlineNotifications(false);
        settings.setDeadlineRoasting(true);
        notifications.clearRecords();
        await coordinator.syncTaskReminders(
          userId: 'user-a',
          tasks: <TaskItem>[task],
        );
        expect(generator.deadlineCalls, 1);
        expect(notifications.taskSchedules, isEmpty);
        expect(notifications.cancelAllTaskCalls, greaterThan(0));
      },
    );

    test(
      'master Roasting AI nonaktif mempertahankan pengingat biasa',
      () async {
        final SharedPreferences prefs = await _preferences();
        final SettingsController settings = _settings(
          master: false,
          deadlineRoast: true,
        );
        addTearDown(settings.dispose);
        final _FakeNotificationService notifications =
            _FakeNotificationService();
        final _FakeRoastingGenerator generator = _FakeRoastingGenerator();
        final RoastingNotificationService coordinator =
            RoastingNotificationService(
              notifications: notifications,
              generator: generator,
              settings: settings,
              preferences: prefs,
              clock: () => DateTime(2026, 11, 19, 8),
              activeUserId: () => 'user-a',
            );

        await coordinator.syncTaskReminders(
          userId: 'user-a',
          tasks: <TaskItem>[_task(dueDate: DateTime(2026, 11, 19, 11))],
        );

        expect(generator.deadlineCalls, 0);
        expect(notifications.rescheduleTaskCalls, 1);
      },
    );

    test('fallback memuat judul tugas dan sisa waktu aktual', () async {
      final SharedPreferences prefs = await _preferences();
      final SettingsController settings = _settings(
        deadlineRoast: true,
        intensity: RoastingIntensity.santai,
      );
      addTearDown(settings.dispose);
      final _FakeNotificationService notifications = _FakeNotificationService();
      final _FakeRoastingGenerator generator = _FakeRoastingGenerator()
        ..deadlineError = Exception('timeout');
      final DateTime now = DateTime(2026, 11, 19, 8);
      final RoastingNotificationService coordinator =
          RoastingNotificationService(
            notifications: notifications,
            generator: generator,
            settings: settings,
            preferences: prefs,
            clock: () => now,
            activeUserId: () => 'user-a',
          );

      await coordinator.syncTaskReminders(
        userId: 'user-a',
        tasks: <TaskItem>[
          _task(
            title: 'Presentasi kelompok',
            dueDate: now.add(const Duration(hours: 3)),
          ),
        ],
      );

      expect(notifications.taskSchedules, hasLength(1));
      expect(
        notifications.taskSchedules.single.body,
        contains('Presentasi kelompok'),
      );
      expect(notifications.taskSchedules.single.body, contains('tenggat'));
      expect(
        notifications.taskSchedules.single.body,
        isNot(contains('AI deadline')),
      );
    });
  });

  group('Daily Roasting', () {
    test(
      'satu generasi per tanggal dan jadwal mengikuti waktu terbaru',
      () async {
        final SharedPreferences prefs = await _preferences();
        final SettingsController settings = _settings(
          dailyRoast: true,
          intensity: RoastingIntensity.seimbang,
        );
        addTearDown(settings.dispose);
        final _FakeNotificationService notifications =
            _FakeNotificationService();
        final _FakeRoastingGenerator generator = _FakeRoastingGenerator();
        DateTime now = DateTime(2026, 11, 19, 19);
        final RoastingNotificationService coordinator =
            RoastingNotificationService(
              notifications: notifications,
              generator: generator,
              settings: settings,
              preferences: prefs,
              clock: () => now,
              activeUserId: () => 'user-a',
            );

        await coordinator.syncDaily(userId: 'user-a', summary: _summary);
        expect(generator.dailyCalls, 1);
        expect(generator.lastDailySummary?.pendingTasks, 3);
        expect(generator.lastDailyIntensity, RoastingIntensity.seimbang);
        expect(notifications.dailySchedules, hasLength(1));
        expect(
          notifications.dailySchedules.single.scheduledAt,
          DateTime(2026, 11, 19, 20),
        );
        expect(notifications.dailySchedules.single.title, 'Daily Roasting');
        expect(notifications.dailySchedules.single.body, contains('AI daily'));

        await coordinator.syncDaily(userId: 'user-a', summary: _summary);
        expect(generator.dailyCalls, 1);
        expect(notifications.dailySchedules, hasLength(2));
        expect(
          notifications.dailySchedules.last.body,
          notifications.dailySchedules.first.body,
        );

        final RoastingNotificationService restarted =
            RoastingNotificationService(
              notifications: notifications,
              generator: generator,
              settings: settings,
              preferences: prefs,
              clock: () => now,
              activeUserId: () => 'user-a',
            );
        await restarted.syncDaily(userId: 'user-a', summary: _summary);
        expect(
          generator.dailyCalls,
          1,
          reason: 'Jadwal dan pesan harus bertahan setelah restart.',
        );
        expect(
          notifications.dailySchedules.last.scheduledAt,
          DateTime(2026, 11, 19, 20),
        );

        settings.setDailyRoastingTime(21, 30);
        await coordinator.syncDaily(userId: 'user-a', summary: _summary);
        expect(generator.dailyCalls, 1);
        expect(
          notifications.dailySchedules.last.scheduledAt,
          DateTime(2026, 11, 19, 21, 30),
        );

        settings.setRoastingIntensity(RoastingIntensity.pedas);
        await coordinator.syncDaily(userId: 'user-a', summary: _summary);
        expect(generator.dailyCalls, 2);
        expect(generator.lastDailyIntensity, RoastingIntensity.pedas);
        expect(notifications.dailySchedules.last.body, contains('pedas'));
      },
    );

    test(
      'slot yang sudah lewat dijadwalkan besok tanpa duplikasi hari ini',
      () async {
        final SharedPreferences prefs = await _preferences();
        final SettingsController settings = _settings(dailyRoast: true);
        addTearDown(settings.dispose);
        final _FakeNotificationService notifications =
            _FakeNotificationService();
        final _FakeRoastingGenerator generator = _FakeRoastingGenerator();
        DateTime now = DateTime(2026, 11, 19, 19);
        final RoastingNotificationService coordinator =
            RoastingNotificationService(
              notifications: notifications,
              generator: generator,
              settings: settings,
              preferences: prefs,
              clock: () => now,
              activeUserId: () => 'user-a',
            );

        await coordinator.syncDaily(userId: 'user-a', summary: _summary);
        expect(
          notifications.dailySchedules.last.scheduledAt,
          DateTime(2026, 11, 19, 20),
        );
        expect(generator.dailyCalls, 1);

        now = DateTime(2026, 11, 19, 20, 5);
        await coordinator.syncDaily(userId: 'user-a', summary: _summary);
        expect(generator.dailyCalls, 2);
        expect(
          notifications.dailySchedules.last.scheduledAt,
          DateTime(2026, 11, 20, 20),
        );

        now = DateTime(2026, 11, 19, 20, 10);
        await coordinator.syncDaily(userId: 'user-a', summary: _summary);
        expect(
          generator.dailyCalls,
          2,
          reason: 'Hari ini tidak boleh dikirim dua kali.',
        );
        expect(
          notifications.dailySchedules.last.scheduledAt,
          DateTime(2026, 11, 20, 20),
        );
      },
    );

    test('fitur setelah waktu lewat dijadwalkan untuk besok', () async {
      final SharedPreferences prefs = await _preferences();
      final SettingsController settings = _settings(dailyRoast: true);
      addTearDown(settings.dispose);
      final _FakeNotificationService notifications = _FakeNotificationService();
      final _FakeRoastingGenerator generator = _FakeRoastingGenerator();
      final DateTime now = DateTime(2026, 11, 19, 21);
      final RoastingNotificationService coordinator =
          RoastingNotificationService(
            notifications: notifications,
            generator: generator,
            settings: settings,
            preferences: prefs,
            clock: () => now,
            activeUserId: () => 'user-a',
          );

      await coordinator.syncDaily(userId: 'user-a', summary: _summary);
      expect(generator.dailyCalls, 1);
      expect(
        notifications.dailySchedules.single.scheduledAt,
        DateTime(2026, 11, 20, 20),
      );
    });

    test('nonaktif membatalkan jadwal tanpa memanggil Gemini', () async {
      final SharedPreferences prefs = await _preferences();
      final SettingsController settings = _settings(dailyRoast: false);
      addTearDown(settings.dispose);
      final _FakeNotificationService notifications = _FakeNotificationService();
      final _FakeRoastingGenerator generator = _FakeRoastingGenerator();
      final RoastingNotificationService coordinator =
          RoastingNotificationService(
            notifications: notifications,
            generator: generator,
            settings: settings,
            preferences: prefs,
            clock: () => DateTime(2026, 11, 19, 19),
            activeUserId: () => 'user-a',
          );

      await coordinator.syncDaily(userId: 'user-a', summary: _summary);
      expect(generator.dailyCalls, 0);
      expect(notifications.dailySchedules, isEmpty);
      expect(
        notifications.cancelledNotificationIds,
        contains(dailyRoastingNotificationId('user-a')),
      );

      settings.setDailyRoasting(true);
      settings.setRoastingAi(false);
      await coordinator.syncDaily(userId: 'user-a', summary: _summary);
      expect(generator.dailyCalls, 0);
      expect(notifications.dailySchedules, isEmpty);
    });

    test('fallback Daily memakai fakta aktivitas yang tersedia', () async {
      final SharedPreferences prefs = await _preferences();
      final SettingsController settings = _settings(
        dailyRoast: true,
        intensity: RoastingIntensity.pedas,
      );
      addTearDown(settings.dispose);
      final _FakeNotificationService notifications = _FakeNotificationService();
      final _FakeRoastingGenerator generator = _FakeRoastingGenerator()
        ..dailyError = Exception('offline');
      final RoastingNotificationService coordinator =
          RoastingNotificationService(
            notifications: notifications,
            generator: generator,
            settings: settings,
            preferences: prefs,
            clock: () => DateTime(2026, 11, 19, 19),
            activeUserId: () => 'user-a',
          );

      await coordinator.syncDaily(userId: 'user-a', summary: _summary);
      final String body = notifications.dailySchedules.single.body;
      expect(body, contains('3 tugas belum selesai'));
      expect(body, contains('1 tugas jatuh tempo hari ini'));
      expect(body, contains('2 transaksi hari ini'));
      expect(body, isNot(contains('AI daily')));
    });

    test('tamu membersihkan jadwal Daily milik akun lama', () async {
      final SharedPreferences prefs = await _preferences();
      final SettingsController settings = _settings(dailyRoast: true);
      addTearDown(settings.dispose);
      final _FakeNotificationService notifications = _FakeNotificationService();
      final _FakeRoastingGenerator generator = _FakeRoastingGenerator();
      String? activeUser;
      final RoastingNotificationService coordinator =
          RoastingNotificationService(
            notifications: notifications,
            generator: generator,
            settings: settings,
            preferences: prefs,
            clock: () => DateTime(2026, 11, 19, 19),
            activeUserId: () => activeUser,
          );

      await coordinator.syncDaily(userId: null, summary: _summary);

      expect(notifications.cancelOtherDailyCalls, 1);
      expect(notifications.lastKeptDailyUser, isNull);
      expect(generator.dailyCalls, 0);
      expect(notifications.dailySchedules, isEmpty);
    });

    test('status dan jadwal tidak bocor antar akun', () async {
      final SharedPreferences prefs = await _preferences();
      final SettingsController settings = _settings(dailyRoast: true);
      addTearDown(settings.dispose);
      final _FakeNotificationService notifications = _FakeNotificationService();
      final _FakeRoastingGenerator generator = _FakeRoastingGenerator();
      String? activeUser = 'user-a';
      final RoastingNotificationService coordinator =
          RoastingNotificationService(
            notifications: notifications,
            generator: generator,
            settings: settings,
            preferences: prefs,
            clock: () => DateTime(2026, 11, 19, 19),
            activeUserId: () => activeUser,
          );

      await coordinator.syncDaily(userId: 'user-a', summary: _summary);
      expect(generator.dailyCalls, 1);
      expect(notifications.dailySchedules.last.payload, 'daily:user-a');
      final int aId = notifications.dailySchedules.last.id;

      await coordinator.cancelForUser('user-a');
      expect(notifications.cancelledNotificationIds, contains(aId));

      activeUser = 'user-b';
      notifications.clearRecords();
      await coordinator.syncDaily(userId: 'user-b', summary: _summary);
      expect(generator.dailyCalls, 2);
      expect(notifications.dailySchedules.last.payload, 'daily:user-b');
      expect(notifications.lastKeptDailyUser, 'user-b');
      expect(notifications.dailySchedules.last.id, isNot(aId));

      notifications.clearRecords();
      await coordinator.syncDaily(userId: 'user-a', summary: _summary);
      expect(
        notifications.dailySchedules,
        isEmpty,
        reason: 'Akun lama tidak boleh dijadwalkan saat akun lain aktif.',
      );

      activeUser = 'user-a';
      await coordinator.syncDaily(userId: 'user-a', summary: _summary);
      expect(
        generator.dailyCalls,
        2,
        reason: 'Pesan akun A yang sudah dibuat harus dipakai ulang.',
      );
      expect(notifications.dailySchedules.single.payload, 'daily:user-a');
    });
  });

  group('Data aktivitas Daily Roasting', () {
    test('hanya memakai aktivitas hari ini yang tersedia', () {
      final DateTime now = DateTime.now();
      final DateTime yesterday = now.subtract(const Duration(days: 1));
      final AppProvider app = AppProvider.inMemory(
        tasks: <TaskItem>[
          _task(
            id: 'done-today',
            title: 'Selesai hari ini',
            done: true,
            completedAt: now,
          ),
          _task(
            id: 'done-yesterday',
            title: 'Selesai kemarin',
            done: true,
            completedAt: yesterday,
          ),
          _task(
            id: 'due-today',
            title: 'Jatuh tempo hari ini',
            deadline: 'Hari ini',
          ),
          _task(
            id: 'overdue',
            title: 'Terlambat',
            dueDate: now.subtract(const Duration(days: 2)),
          ),
        ],
        transactions: <TransactionItem>[
          TransactionItem(
            id: 'expense-today',
            label: 'Makan',
            amount: -25000,
            cat: 'Makanan',
            time: '12:00',
            date: 'Hari ini',
            createdAt: now,
          ),
          TransactionItem(
            id: 'income-today',
            label: 'Uang saku',
            amount: 100000,
            cat: 'Pemasukan',
            time: '08:00',
            date: 'Hari ini',
            createdAt: now,
          ),
          TransactionItem(
            id: 'expense-yesterday',
            label: 'Transport',
            amount: -15000,
            cat: 'Transportasi',
            time: '07:00',
            date: 'Kemarin',
            createdAt: yesterday,
          ),
        ],
        profile: ProfileData.initial,
      );
      addTearDown(app.dispose);

      expect(app.todayExpense, 25000);
      expect(app.todayTransactionCount, 2);
      expect(app.completedTodayTaskCount, 1);
      expect(app.overdueTaskCount, 1);
      expect(app.todayTaskCount, 1);
    });
  });

  group('Siklus aplikasi', () {
    test('tidak membuat konten Gemini saat aplikasi tidak aktif', () async {
      final SharedPreferences prefs = await _preferences();
      final SettingsController settings = _settings(
        budgetRoast: true,
        deadlineRoast: true,
        dailyRoast: true,
      );
      addTearDown(settings.dispose);
      final _FakeNotificationService notifications = _FakeNotificationService();
      final _FakeRoastingGenerator generator = _FakeRoastingGenerator();
      bool appActive = true;
      final DateTime now = DateTime(2026, 11, 19, 8);
      final RoastingNotificationService coordinator =
          RoastingNotificationService(
            notifications: notifications,
            generator: generator,
            settings: settings,
            preferences: prefs,
            clock: () => now,
            activeUserId: () => 'user-a',
            isAppActive: () => appActive,
          );
      final TaskItem task = _task(dueDate: now.add(const Duration(hours: 3)));

      appActive = false;
      await coordinator.syncTaskReminders(
        userId: 'user-a',
        tasks: <TaskItem>[task],
      );
      expect(generator.deadlineCalls, 0);
      expect(notifications.rescheduleTaskCalls, 1);
      expect(notifications.taskSchedules, isEmpty);
      expect(
        await coordinator.buildBudgetContent(
          userId: 'user-a',
          threshold: 80,
          spent: 800,
          limit: 1000,
        ),
        isNull,
      );
      expect(generator.budgetCalls, 0);
      await coordinator.syncDaily(userId: 'user-a', summary: _summary);
      expect(generator.dailyCalls, 0);
      expect(notifications.dailySchedules, isEmpty);

      appActive = true;
      await coordinator.syncTaskReminders(
        userId: 'user-a',
        tasks: <TaskItem>[task],
      );
      expect(generator.deadlineCalls, 1);
      expect(notifications.taskSchedules, hasLength(1));
      expect(
        await coordinator.buildBudgetContent(
          userId: 'user-a',
          threshold: 80,
          spent: 800,
          limit: 1000,
        ),
        isNotNull,
      );
      expect(generator.budgetCalls, 1);
      await coordinator.syncDaily(userId: 'user-a', summary: _summary);
      expect(generator.dailyCalls, 1);
      expect(notifications.dailySchedules, hasLength(1));
    });
  });

  group('Integrasi AppProvider', () {
    test(
      'foreground menyiapkan Budget dan Deadline Roasting tanpa duplikasi',
      () async {
        final SharedPreferences prefs = await _preferences();
        final DateTime now = DateTime.now();
        final SettingsController settings = _settings(
          budgetRoast: true,
          deadlineRoast: true,
        )..monthlyBudgetLimit = 1000;
        final _FakeNotificationService notifications =
            _FakeNotificationService();
        final _FakeRoastingGenerator generator = _FakeRoastingGenerator();
        final BudgetAlertService budgetAlerts = BudgetAlertService(
          notifications: notifications,
          preferences: prefs,
        );
        final AppProvider app = AppProvider.inMemory(
          settings: settings,
          tasks: <TaskItem>[_task(dueDate: now.add(const Duration(hours: 3)))],
          transactions: <TransactionItem>[
            TransactionItem(
              id: 'expense-1',
              label: 'Makan',
              amount: -800,
              cat: 'Makanan',
              time: '12:00',
              date: 'Hari ini',
              consumtive: true,
              createdAt: now,
            ),
          ],
          profile: ProfileData.initial,
          activeUserId: 'user-a',
          notifications: notifications,
          budgetAlerts: budgetAlerts,
          roastingGenerator: generator,
          preferences: prefs,
        );
        addTearDown(app.dispose);

        await app.onAppForeground();
        expect(generator.budgetCalls, 1);
        expect(generator.deadlineCalls, 1);
        expect(notifications.budgetTitles, <String>['Budget Roasting']);
        expect(notifications.taskSchedules, hasLength(1));
        expect(notifications.taskSchedules.single.title, 'Deadline Roasting');

        await app.onAppForeground();
        expect(generator.budgetCalls, 1);
        expect(generator.deadlineCalls, 1);
        expect(notifications.budgetTitles, hasLength(1));
        expect(notifications.taskSchedules, hasLength(2));
      },
    );

    test(
      'master Roasting AI nonaktif mencegah semua generasi otomatis',
      () async {
        final SharedPreferences prefs = await _preferences();
        final DateTime now = DateTime.now();
        final SettingsController settings = _settings(
          master: false,
          budgetRoast: true,
          deadlineRoast: true,
          dailyRoast: true,
        )..monthlyBudgetLimit = 1000;
        final _FakeNotificationService notifications =
            _FakeNotificationService();
        final _FakeRoastingGenerator generator = _FakeRoastingGenerator();
        final BudgetAlertService budgetAlerts = BudgetAlertService(
          notifications: notifications,
          preferences: prefs,
        );
        final AppProvider app = AppProvider.inMemory(
          settings: settings,
          tasks: <TaskItem>[_task(dueDate: now.add(const Duration(hours: 3)))],
          transactions: <TransactionItem>[
            TransactionItem(
              id: 'expense-1',
              label: 'Makan',
              amount: -1000,
              cat: 'Makanan',
              time: '12:00',
              date: 'Hari ini',
              consumtive: true,
              createdAt: now,
            ),
          ],
          profile: ProfileData.initial,
          activeUserId: 'user-a',
          notifications: notifications,
          budgetAlerts: budgetAlerts,
          roastingGenerator: generator,
          preferences: prefs,
        );
        addTearDown(app.dispose);

        await app.onAppForeground();

        expect(generator.budgetCalls, 0);
        expect(generator.deadlineCalls, 0);
        expect(generator.dailyCalls, 0);
        expect(notifications.budgetTitles, <String>['Limit anggaran tercapai']);
        expect(notifications.taskSchedules, isEmpty);
        expect(notifications.dailySchedules, isEmpty);
      },
    );
    test('izin perangkat ditolak tidak mengaktifkan fitur otomatis', () async {
      final SharedPreferences prefs = await _preferences();
      final SettingsController settings = _settings();
      final _FakeNotificationService notifications = _FakeNotificationService()
        ..permissionGranted = false;
      final _FakeRoastingGenerator generator = _FakeRoastingGenerator();
      final BudgetAlertService budgetAlerts = BudgetAlertService(
        notifications: notifications,
        preferences: prefs,
      );
      final AppProvider app = AppProvider.inMemory(
        settings: settings,
        profile: ProfileData.initial,
        activeUserId: 'user-a',
        notifications: notifications,
        budgetAlerts: budgetAlerts,
        roastingGenerator: generator,
        preferences: prefs,
      );
      addTearDown(app.dispose);

      expect(await app.setBudgetRoasting(true), isFalse);
      expect(await app.setDeadlineRoasting(true), isFalse);
      expect(await app.setDailyRoasting(true), isFalse);
      expect(settings.budgetRoastingEnabled, isFalse);
      expect(settings.deadlineRoastingEnabled, isFalse);
      expect(settings.dailyRoastingEnabled, isFalse);
      expect(generator.budgetCalls, 0);
      expect(generator.deadlineCalls, 0);
      expect(generator.dailyCalls, 0);
    });
  });

  group('UI notifikasi otomatis', () {
    testWidgets('tiga switch default nonaktif dan waktu 20.00 tampil', (
      WidgetTester tester,
    ) async {
      final SettingsController settings = _settings();
      addTearDown(settings.dispose);
      await _pumpSettings(tester, settings);

      expect(find.text('NOTIFIKASI ROASTING OTOMATIS'), findsOneWidget);
      expect(find.text('Budget Roasting'), findsOneWidget);
      expect(find.text('Deadline Roasting'), findsOneWidget);
      expect(find.text('Daily Roasting'), findsOneWidget);
      expect(find.text('Waktu Daily Roasting'), findsOneWidget);
      expect(find.text('20.00'), findsOneWidget);

      for (final String title in <String>[
        'Budget Roasting',
        'Deadline Roasting',
        'Daily Roasting',
      ]) {
        final Switch toggle = tester.widget<Switch>(_switchFor(title));
        expect(toggle.value, isFalse);
        expect(toggle.onChanged, isNotNull);
      }
    });

    testWidgets('switch otomatis mengikuti master dan pengaturan induknya', (
      WidgetTester tester,
    ) async {
      final SettingsController settings = _settings(
        master: false,
        budgetAlerts: false,
        deadlineNotifications: false,
      );
      addTearDown(settings.dispose);
      await _pumpSettings(tester, settings);

      for (final String title in <String>[
        'Budget Roasting',
        'Deadline Roasting',
        'Daily Roasting',
      ]) {
        expect(tester.widget<Switch>(_switchFor(title)).onChanged, isNull);
      }
      final ListTile timeTile = tester.widget<ListTile>(
        find.ancestor(
          of: find.text('Waktu Daily Roasting'),
          matching: find.byType(ListTile),
        ),
      );
      expect(timeTile.enabled, isFalse);

      settings.setRoastingAi(true);
      await tester.pumpAndSettle();
      expect(
        tester.widget<Switch>(_switchFor('Budget Roasting')).onChanged,
        isNull,
      );
      expect(
        tester.widget<Switch>(_switchFor('Deadline Roasting')).onChanged,
        isNull,
      );
      expect(
        tester.widget<Switch>(_switchFor('Daily Roasting')).onChanged,
        isNotNull,
      );

      settings.setBudgetAlerts(true);
      settings.setDeadlineNotifications(true);
      await tester.pumpAndSettle();
      expect(
        tester.widget<Switch>(_switchFor('Budget Roasting')).onChanged,
        isNotNull,
      );
      expect(
        tester.widget<Switch>(_switchFor('Deadline Roasting')).onChanged,
        isNotNull,
      );
    });

    testWidgets(
      'waktu Daily Roasting membuka time picker dan memakai callback',
      (WidgetTester tester) async {
        final SettingsController settings = _settings(dailyRoast: true);
        addTearDown(settings.dispose);
        int? selectedHour;
        int? selectedMinute;
        await _pumpSettings(
          tester,
          settings,
          onDailyTimeChanged: (int hour, int minute) async {
            selectedHour = hour;
            selectedMinute = minute;
            settings.setDailyRoastingTime(hour, minute);
          },
        );

        await tester.ensureVisible(find.text('Waktu Daily Roasting'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Waktu Daily Roasting'));
        await tester.pumpAndSettle();
        expect(find.byType(TimePickerDialog), findsOneWidget);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        expect(selectedHour, isNull);
        expect(selectedMinute, isNull);
        expect(find.text('20.00'), findsOneWidget);
      },
    );
  });
}
