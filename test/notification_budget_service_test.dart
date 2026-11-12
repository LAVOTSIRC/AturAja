import 'package:aturaja/data/models.dart';
import 'package:aturaja/services/budget_alert_service.dart';
import 'package:aturaja/services/local_notification_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeNotificationService implements AppNotificationService {
  int budgetAlertCalls = 0;
  String? lastTitle;
  String? lastBody;

  @override
  Future<bool> requestPermissions() async => true;

  @override
  Future<void> scheduleTaskReminder(TaskItem task) async {}

  @override
  Future<void> cancelTaskReminder(String taskId) async {}

  @override
  Future<void> rescheduleTaskReminders(List<TaskItem> tasks) async {}

  @override
  Future<void> cancelAllTaskReminders() async {}

  @override
  Future<void> showBudgetAlert({
    required int id,
    required String title,
    required String body,
  }) async {
    budgetAlertCalls++;
    lastTitle = title;
    lastBody = body;
  }
}

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

  group('LocalNotificationService.reminderTimeFor', () {
    final DateTime now = DateTime(2026, 11, 12, 10);

    test('schedules one hour before a deadline that is far away', () {
      final TaskItem task = taskWithDeadline(
        id: 'far',
        dueDate: now.add(const Duration(hours: 3)),
      );

      expect(
        LocalNotificationService.reminderTimeFor(task, now),
        now.add(const Duration(hours: 2)),
      );
    });

    test('schedules one minute from now when the deadline is near', () {
      final TaskItem task = taskWithDeadline(
        id: 'near',
        dueDate: now.add(const Duration(minutes: 30)),
      );

      expect(
        LocalNotificationService.reminderTimeFor(task, now),
        now.add(const Duration(minutes: 1)),
      );
    });

    test('uses an accurate message for near and far deadlines', () {
      expect(
        LocalNotificationService.reminderBodyFor(const Duration(hours: 1)),
        'akan mencapai tenggat dalam 1 jam.',
      );
      expect(
        LocalNotificationService.reminderBodyFor(const Duration(minutes: 30)),
        'akan mencapai tenggat dalam 30 menit.',
      );
      expect(
        LocalNotificationService.reminderBodyFor(const Duration(minutes: 1)),
        'akan mencapai tenggat dalam kurang dari 1 menit.',
      );
    });

    test('does not schedule overdue, completed, or undated tasks', () {
      expect(
        LocalNotificationService.reminderTimeFor(
          taskWithDeadline(
            id: 'overdue',
            dueDate: now.subtract(const Duration(minutes: 1)),
          ),
          now,
        ),
        isNull,
      );
      expect(
        LocalNotificationService.reminderTimeFor(
          taskWithDeadline(
            id: 'done',
            dueDate: now.add(const Duration(hours: 3)),
            done: true,
          ),
          now,
        ),
        isNull,
      );
      expect(
        LocalNotificationService.reminderTimeFor(
          taskWithDeadline(id: 'undated'),
          now,
        ),
        isNull,
      );
    });
  });

  group('BudgetAlertService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('fires once at 80% and once at 100%', () async {
      final FakeNotificationService notifications = FakeNotificationService();
      final BudgetAlertService service = BudgetAlertService(
        notifications: notifications,
      );

      await service.check(
        userId: 'user-1',
        spent: 800,
        limit: 1000,
        enabled: true,
      );
      expect(notifications.budgetAlertCalls, 1);
      expect(notifications.lastTitle, 'Budget alert 80%');

      await service.check(
        userId: 'user-1',
        spent: 900,
        limit: 1000,
        enabled: true,
      );
      expect(notifications.budgetAlertCalls, 1);

      await service.check(
        userId: 'user-1',
        spent: 1000,
        limit: 1000,
        enabled: true,
      );
      expect(notifications.budgetAlertCalls, 2);
      expect(notifications.lastTitle, 'Limit anggaran tercapai');

      await service.check(
        userId: 'user-1',
        spent: 1200,
        limit: 1000,
        enabled: true,
      );
      expect(notifications.budgetAlertCalls, 2);
    });

    test('does nothing when disabled or below 80%', () async {
      final FakeNotificationService notifications = FakeNotificationService();
      final BudgetAlertService service = BudgetAlertService(
        notifications: notifications,
      );

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
  });
}
