import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../data/models.dart';

/// Kontrak layanan notifikasi agar provider dan test tidak bergantung langsung
/// pada plugin platform.
abstract interface class AppNotificationService {
  Future<bool> requestPermissions();

  Future<void> scheduleTaskReminder(TaskItem task);

  Future<void> cancelTaskReminder(String taskId);

  Future<void> rescheduleTaskReminders(List<TaskItem> tasks);

  Future<void> cancelAllTaskReminders();

  Future<void> showBudgetAlert({
    required int id,
    required String title,
    required String body,
  });
}

/// Notifikasi lokal untuk pengingat deadline dan peringatan anggaran.
///
/// Jadwal disimpan oleh plugin Android/iOS sehingga tetap muncul walau
/// aplikasi sedang ditutup. Waktu jadwal dikirim dalam UTC agar tidak
/// bergantung pada konfigurasi zona waktu perangkat.
class LocalNotificationService implements AppNotificationService {
  LocalNotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const String _channelId = 'aturaja_reminders';
  static const String _channelName = 'Pengingat AturAja';
  static const String _channelDescription =
      'Pengingat deadline tugas dan peringatan anggaran AturAja.';

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    tz_data.initializeTimeZones();

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        );
    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    try {
      await _plugin.initialize(settings: settings);
      _initialized = true;
    } catch (error) {
      debugPrint('Gagal menginisialisasi notifikasi lokal: $error');
    }
  }

  @override
  Future<bool> requestPermissions() async {
    await initialize();
    if (kIsWeb) {
      return false;
    }

    try {
      if (Platform.isAndroid) {
        final AndroidFlutterLocalNotificationsPlugin? android = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        final bool? granted = await android?.requestNotificationsPermission();
        // null berarti versi Android belum membutuhkan izin runtime.
        return granted ?? true;
      }
      if (Platform.isIOS) {
        final IOSFlutterLocalNotificationsPlugin? ios = _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
        final bool? granted = await ios?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }
    } catch (error) {
      debugPrint('Gagal meminta izin notifikasi: $error');
    }
    return true;
  }

  @override
  Future<void> scheduleTaskReminder(TaskItem task) async {
    await initialize();
    await cancelTaskReminder(task.id);

    final DateTime? scheduledAt = reminderTimeFor(task, DateTime.now());
    if (scheduledAt == null) {
      return;
    }

    try {
      await _plugin.zonedSchedule(
        id: _taskNotificationId(task.id),
        title: 'Deadline tugas',
        body: '${task.title} akan mencapai tenggat dalam 1 jam.',
        scheduledDate: tz.TZDateTime.from(scheduledAt.toUtc(), tz.UTC),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: 'task:${task.id}',
      );
    } catch (error) {
      debugPrint('Gagal menjadwalkan pengingat tugas ${task.id}: $error');
    }
  }

  @override
  Future<void> cancelTaskReminder(String taskId) async {
    await initialize();
    try {
      await _plugin.cancel(id: _taskNotificationId(taskId));
    } catch (error) {
      debugPrint('Gagal membatalkan pengingat tugas $taskId: $error');
    }
  }

  @override
  Future<void> rescheduleTaskReminders(List<TaskItem> tasks) async {
    await initialize();
    try {
      await _plugin.cancelAllPendingNotifications();
    } catch (error) {
      debugPrint('Gagal membersihkan jadwal pengingat lama: $error');
    }
    for (final TaskItem task in tasks) {
      await scheduleTaskReminder(task);
    }
  }

  @override
  Future<void> cancelAllTaskReminders() async {
    await initialize();
    try {
      await _plugin.cancelAllPendingNotifications();
    } catch (error) {
      debugPrint('Gagal membatalkan semua pengingat: $error');
    }
  }

  @override
  Future<void> showBudgetAlert({
    required int id,
    required String title,
    required String body,
  }) async {
    await initialize();
    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        payload: 'budget',
      );
    } catch (error) {
      debugPrint('Gagal menampilkan peringatan anggaran: $error');
    }
  }

  /// Waktu pengingat: satu jam sebelum deadline. Jika deadline tinggal kurang
  /// dari satu jam, pengingat dijadwalkan satu menit dari sekarang. Tugas yang
  /// sudah selesai atau tidak punya `dueDate` tidak dijadwalkan.
  @visibleForTesting
  static DateTime? reminderTimeFor(TaskItem task, DateTime now) {
    if (task.done || task.dueDate == null) {
      return null;
    }
    final DateTime due = task.dueDate!;
    if (!due.isAfter(now)) {
      return null;
    }
    final DateTime oneHourBefore = due.subtract(const Duration(hours: 1));
    if (oneHourBefore.isAfter(now)) {
      return oneHourBefore;
    }
    return now.add(const Duration(minutes: 1));
  }

  static int _taskNotificationId(String taskId) =>
      _stableNotificationId('task:$taskId');

  static int _stableNotificationId(String value) {
    // FNV-1a 31-bit agar ID notifikasi stabil antar proses/aplikasi restart.
    int hash = 0x811c9dc5;
    for (final int codeUnit in value.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }
}
