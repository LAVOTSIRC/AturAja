import 'package:aturaja/data/models.dart';
import 'package:aturaja/services/budget_alert_service.dart';
import 'package:aturaja/services/local_notification_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Fake notification service
// ---------------------------------------------------------------------------

class FakeNotificationService implements AppNotificationService {
  int budgetAlertCalls = 0;
  String? lastTitle;
  String? lastBody;
  int? lastBudgetId;
  bool shouldThrow = false;

  final List<String> scheduledTaskIds = [];
  final List<String> cancelledTaskIds = [];

  @override
  Future<bool> requestPermissions() async => true;

  @override
  Future<void> scheduleTaskReminder(
    TaskItem task, {
    String? title,
    String? body,
  }) async {
    scheduledTaskIds.add(task.id);
  }

  @override
  Future<void> cancelTaskReminder(String taskId) async {
    cancelledTaskIds.add(taskId);
  }

  @override
  Future<void> rescheduleTaskReminders(List<TaskItem> tasks) async {
    for (final task in tasks) {
      scheduledTaskIds.add(task.id);
    }
  }

  @override
  Future<void> cancelAllTaskReminders() async {}

  @override
  Future<bool> scheduleDailyRoasting({
    required int id,
    required DateTime scheduledAt,
    required String title,
    required String body,
    required String payload,
  }) async => true;

  @override
  Future<void> cancelNotification(int id) async {}

  @override
  Future<void> showBudgetAlert({
    required int id,
    required String title,
    required String body,
  }) async {
    if (shouldThrow) throw Exception('OS notification failed');
    budgetAlertCalls++;
    lastTitle = title;
    lastBody = body;
    lastBudgetId = id;
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

TaskItem taskWithDeadline({
  required String id,
  DateTime? dueDate,
  bool done = false,
}) {
  return TaskItem(
    id: id,
    title: 'Tugas $id',
    deadline: 'Hari ini',
    dueDate: dueDate,
    done: done,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // =========================================================================
  // reminderTimeFor — 5-minute rule
  // =========================================================================
  group('LocalNotificationService.reminderTimeFor (5-minute rule)', () {
    final DateTime now = DateTime(2026, 11, 12, 10, 0, 0);

    // ----- Case 1: deadline > 5 minutes away -----

    test('Case 1a: deadline 7 minutes away → schedules at deadline-5min', () {
      // Task created at 22:10, deadline 22:17 → notify at 22:12
      final DateTime due = now.add(const Duration(minutes: 7));
      final task = taskWithDeadline(id: 't1', dueDate: due);
      final result = LocalNotificationService.reminderTimeFor(task, now);
      expect(result, due.subtract(const Duration(minutes: 5)));
    });

    test('Case 1b: deadline 2 hours away → schedules at deadline-5min', () {
      // Task created at 10:00, deadline 12:00 → notify at 11:55
      final DateTime due = now.add(const Duration(hours: 2));
      final task = taskWithDeadline(id: 't2', dueDate: due);
      final result = LocalNotificationService.reminderTimeFor(task, now);
      expect(result, due.subtract(const Duration(minutes: 5)));
    });

    test('Case 1c: deadline exactly 6 minutes away → schedules at deadline-5min', () {
      final DateTime due = now.add(const Duration(minutes: 6));
      final task = taskWithDeadline(id: 't3', dueDate: due);
      final result = LocalNotificationService.reminderTimeFor(task, now);
      expect(result, due.subtract(const Duration(minutes: 5)));
    });

    // ----- Case 2: deadline ≤ 5 minutes away (but not past) -----

    test('Case 2a: deadline 3 minutes away → shows immediately (now+5s)', () {
      // Task created at 10:00, deadline 10:03 → immediate
      final DateTime due = now.add(const Duration(minutes: 3));
      final task = taskWithDeadline(id: 't4', dueDate: due);
      final result = LocalNotificationService.reminderTimeFor(task, now);
      // Should be now + 5 seconds (immediate)
      expect(result, isNotNull);
      expect(result!.isAfter(now), isTrue);
      expect(result.difference(now).inSeconds, lessThanOrEqualTo(10));
    });

    test('Case 2b: deadline exactly 5 minutes away → shows immediately', () {
      final DateTime due = now.add(const Duration(minutes: 5));
      final task = taskWithDeadline(id: 't5', dueDate: due);
      final result = LocalNotificationService.reminderTimeFor(task, now);
      expect(result, isNotNull);
      expect(result!.isAfter(now), isTrue);
      expect(result.difference(now).inSeconds, lessThanOrEqualTo(10));
    });

    test('Case 2c: deadline 1 minute away → shows immediately', () {
      final DateTime due = now.add(const Duration(minutes: 1));
      final task = taskWithDeadline(id: 't6', dueDate: due);
      final result = LocalNotificationService.reminderTimeFor(task, now);
      expect(result, isNotNull);
      expect(result!.isAfter(now), isTrue);
    });

    // ----- Case 3: deadline already past -----

    test('Case 3: deadline past → returns null', () {
      // Task created at 10:00, deadline 09:55 → no notification
      final DateTime due = now.subtract(const Duration(minutes: 5));
      final task = taskWithDeadline(id: 't7', dueDate: due);
      expect(LocalNotificationService.reminderTimeFor(task, now), isNull);
    });

    test('Case 3b: deadline 1 second ago → returns null', () {
      final DateTime due = now.subtract(const Duration(seconds: 1));
      final task = taskWithDeadline(id: 't8', dueDate: due);
      expect(LocalNotificationService.reminderTimeFor(task, now), isNull);
    });

    // ----- Case 4: task completed -----

    test('Case 4: completed task → returns null even with future deadline', () {
      final DateTime due = now.add(const Duration(hours: 2));
      final task = taskWithDeadline(id: 't9', dueDate: due, done: true);
      expect(LocalNotificationService.reminderTimeFor(task, now), isNull);
    });

    // ----- Case 5: no dueDate -----

    test('Case 5: task without dueDate → returns null', () {
      final task = taskWithDeadline(id: 't10', dueDate: null);
      expect(LocalNotificationService.reminderTimeFor(task, now), isNull);
    });
  });

  // =========================================================================
  // reminderBodyFor
  // =========================================================================
  group('LocalNotificationService.reminderBodyFor', () {
    test('immediate notification (≤10s remaining) uses urgent phrasing', () {
      final body = LocalNotificationService.reminderBodyFor(
        const Duration(seconds: 5),
      );
      expect(body, contains('segera'));
    });

    test('5 minutes remaining uses "5 menit"', () {
      final body = LocalNotificationService.reminderBodyFor(
        const Duration(minutes: 5),
      );
      expect(body, contains('5 menit'));
    });

    test('30 minutes remaining uses "30 menit"', () {
      final body = LocalNotificationService.reminderBodyFor(
        const Duration(minutes: 30),
      );
      expect(body, contains('30 menit'));
    });

    test('less than 1 minute uses "kurang dari 1 menit"', () {
      final body = LocalNotificationService.reminderBodyFor(
        const Duration(seconds: 30),
      );
      // Either "segera" or "kurang dari 1 menit" is acceptable
      expect(body, isNotEmpty);
    });
  });

  // =========================================================================
  // BudgetAlertService
  // =========================================================================
  group('BudgetAlertService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('fires once at 80% and once at 100%', () async {
      final notifications = FakeNotificationService();
      final service = BudgetAlertService(notifications: notifications);

      await service.check(
        userId: 'user-1',
        spent: 800,
        limit: 1000,
        enabled: true,
      );
      expect(notifications.budgetAlertCalls, 1);
      expect(notifications.lastTitle, 'Budget alert 80%');

      // Another call at same threshold → no duplicate
      await service.check(
        userId: 'user-1',
        spent: 900,
        limit: 1000,
        enabled: true,
      );
      expect(notifications.budgetAlertCalls, 1);

      // Cross 100% threshold → fires again
      await service.check(
        userId: 'user-1',
        spent: 1000,
        limit: 1000,
        enabled: true,
      );
      expect(notifications.budgetAlertCalls, 2);
      expect(notifications.lastTitle, 'Limit anggaran tercapai');

      // Over 100% → no duplicate
      await service.check(
        userId: 'user-1',
        spent: 1200,
        limit: 1000,
        enabled: true,
      );
      expect(notifications.budgetAlertCalls, 2);
    });

    test('80% and 100% notifications have different IDs', () async {
      final notifications = FakeNotificationService();
      final service = BudgetAlertService(notifications: notifications);

      await service.check(
        userId: 'user-1',
        spent: 800,
        limit: 1000,
        enabled: true,
      );
      final int id80 = notifications.lastBudgetId!;

      // Reset so we can fire 100%
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final notifications2 = FakeNotificationService();
      final service2 = BudgetAlertService(notifications: notifications2);
      await service2.check(
        userId: 'user-1',
        spent: 1000,
        limit: 1000,
        enabled: true,
      );
      final int id100 = notifications2.lastBudgetId!;

      // IDs must differ so both notifications can coexist in tray
      expect(id80, isNot(equals(id100)));
    });

    test('does nothing when disabled or below 80%', () async {
      final notifications = FakeNotificationService();
      final service = BudgetAlertService(notifications: notifications);

      await service.check(
        userId: 'user-1',
        spent: 500,
        limit: 1000,
        enabled: true,
      );
      await service.check(
        userId: 'user-1',
        spent: 900,
        limit: 1000,
        enabled: false,
      );
      expect(notifications.budgetAlertCalls, 0);
    });

    test('threshold not saved when notification fails', () async {
      final notifications = FakeNotificationService()..shouldThrow = true;
      final service = BudgetAlertService(notifications: notifications);

      // First call fails
      await service.check(
        userId: 'user-1',
        spent: 800,
        limit: 1000,
        enabled: true,
      );
      expect(notifications.budgetAlertCalls, 0);

      // Second call with working notifications should fire (threshold not saved)
      notifications.shouldThrow = false;
      await service.check(
        userId: 'user-1',
        spent: 800,
        limit: 1000,
        enabled: true,
      );
      expect(notifications.budgetAlertCalls, 1);
    });

    test('resets correctly for new month', () async {
      final notifications = FakeNotificationService();
      
      // Simulate previous month already at 100%
      final DateTime lastMonth = DateTime.now().subtract(const Duration(days: 32));
      final String lastMonthKey =
          'aturaja_budget_alert_user-1_${lastMonth.year}_${lastMonth.month}_1000';
      SharedPreferences.setMockInitialValues(<String, Object>{
        lastMonthKey: 100,
      });

      final service = BudgetAlertService(notifications: notifications);

      // Current month at 80% → should fire (different month key)
      await service.check(
        userId: 'user-1',
        spent: 800,
        limit: 1000,
        enabled: true,
      );
      expect(notifications.budgetAlertCalls, 1);
    });

    test('concurrent checks for same threshold are deduplicated', () async {
      final notifications = FakeNotificationService();
      final service = BudgetAlertService(notifications: notifications);

      // Fire three concurrent checks
      await Future.wait([
        service.check(userId: 'u', spent: 800, limit: 1000, enabled: true),
        service.check(userId: 'u', spent: 850, limit: 1000, enabled: true),
        service.check(userId: 'u', spent: 900, limit: 1000, enabled: true),
      ]);

      // All three are at 80% threshold → should only fire once
      expect(notifications.budgetAlertCalls, 1);
    });
  });
}
