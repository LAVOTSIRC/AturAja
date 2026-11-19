import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../data/models.dart';
import 'notification_diag_log.dart';
import 'notification_ids.dart';

/// Kontrak layanan notifikasi agar provider dan test tidak bergantung langsung
/// pada plugin platform.
abstract interface class AppNotificationService {
  Future<bool> requestPermissions();

  Future<void> scheduleTaskReminder(
    TaskItem task, {
    String? title,
    String? body,
  });

  Future<void> cancelTaskReminder(String taskId);

  Future<void> rescheduleTaskReminders(List<TaskItem> tasks);

  Future<void> cancelAllTaskReminders();

  Future<void> showBudgetAlert({
    required int id,
    required String title,
    required String body,
  });

  Future<bool> scheduleDailyRoasting({
    required int id,
    required DateTime scheduledAt,
    required String title,
    required String body,
    required String payload,
  });

  Future<void> cancelNotification(int id);

  /// Meminta akses exact alarm via Android Intent ke Settings.
  /// Mengembalikan [true] jika izin sudah tersedia SEBELUM membuka settings
  /// (tidak perlu interaksi pengguna). Mengembalikan [false] jika layar settings
  /// dibuka untuk meminta pengguna mengaktifkan secara manual.
  /// Hanya berlaku untuk Android. Platform lain selalu return [true].
  Future<bool> requestExactAlarmPermissionIfNeeded();
}

/// Kemampuan opsional untuk membersihkan Daily Roasting milik akun lain.
///
/// Dipisahkan dari kontrak utama agar implementasi notifikasi lain (misalnya
/// fake di test) tidak wajib menyediakannya.
abstract interface class DailyRoastingCleaner {
  /// Membatalkan Daily Roasting yang bukan milik [userId]. Null membatalkan
  /// semua Daily Roasting yang tersisa, misalnya saat masuk sebagai tamu.
  Future<void> cancelDailyRoastingExcept(String? userId);
}

/// Notifikasi lokal untuk pengingat deadline, peringatan anggaran, dan
/// roasting otomatis.
///
/// Jadwal disimpan oleh plugin Android/iOS sehingga tetap muncul walau
/// aplikasi sedang ditutup. Waktu mengikuti offset zona waktu perangkat saat
/// jadwal dibuat.
class LocalNotificationService
    implements AppNotificationService, DailyRoastingCleaner {
  LocalNotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const String _channelId = 'aturaja_reminders';
  static const String _channelName = 'Pengingat AturAja';
  static const String _channelDescription =
      'Pengingat deadline tugas, peringatan anggaran, dan roasting AturAja.';

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;
  bool _timeZonesInitialized = false;

  Future<void> initialize() async {
    if (!_timeZonesInitialized) {
      tz_data.initializeTimeZones();
      _timeZonesInitialized = true;
    }
    // Perbarui offset setiap kali menjadwalkan agar perubahan zona waktu
    // perangkat tetap terpakai. Data timezone memakai offset saat ini karena
    // package timezone tidak menyediakan pembacaan zona IANA dari perangkat
    // tanpa plugin tambahan.
    applyDeviceLocalTimeZone();

    if (_initialized) {
      return;
    }

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

      // Pastikan channel notifikasi terdaftar di Android
      if (!kIsWeb && Platform.isAndroid) {
        final AndroidFlutterLocalNotificationsPlugin? android = _plugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        await android?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: _channelDescription,
            importance: Importance.high,
          ),
        );
      }
    } catch (error) {
      debugPrint('Gagal menginisialisasi notifikasi lokal: $error');
    }
  }

  /// Memakai zona waktu IANA yang valid dan dikenali oleh platform Android/Java
  /// sesuai offset perangkat (WIB, WITA, WIT, atau zona lain).
  @visibleForTesting
  static void applyDeviceLocalTimeZone({DateTime? now}) {
    final DateTime localNow = now ?? DateTime.now();
    final Duration offset = localNow.timeZoneOffset;
    final int hours = offset.inHours;

    String locationName;
    if (hours == 7) {
      locationName = 'Asia/Jakarta'; // WIB (UTC+7)
    } else if (hours == 8) {
      locationName = 'Asia/Makassar'; // WITA (UTC+8)
    } else if (hours == 9) {
      locationName = 'Asia/Jayapura'; // WIT (UTC+9)
    } else if (hours == 0) {
      locationName = 'UTC';
    } else {
      final int invHours = -hours;
      final String sign = invHours >= 0 ? '+' : '-';
      locationName = 'Etc/GMT$sign${invHours.abs()}';
    }

    try {
      tz.setLocalLocation(tz.getLocation(locationName));
    } catch (_) {
      try {
        tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
      } catch (_) {
        tz.setLocalLocation(tz.UTC);
      }
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
  Future<void> scheduleTaskReminder(
    TaskItem task, {
    String? title,
    String? body,
  }) async {
    await initialize();
    await cancelTaskReminder(task.id);

    final DateTime now = DateTime.now();
    final DateTime? scheduledAt = reminderTimeFor(task, now);

    debugPrint(
      '[NotifDiag] scheduleTaskReminder:'
      ' id=${task.id}'
      ' title="${task.title}"'
      ' dueDate=${task.dueDate?.toIso8601String() ?? "null"}'
      ' now=${now.toIso8601String()}'
      ' tzOffset=${now.timeZoneOffset}'
      ' scheduledAt=${scheduledAt?.toIso8601String() ?? "null (skipped)"}',
    );

    final int notifId = taskNotificationId(task.id);
    if (scheduledAt == null) {
      debugPrint('[NotifDiag] Skipping: no reminder time (overdue, done, or no dueDate)');
      NotificationDiagLog.instance.add(
        category: 'task',
        notifId: notifId,
        mode: '-',
        result: 'skipped',
        message: 'Dilewati: deadline lewat, tugas selesai, atau tanpa dueDate.',
      );
      return;
    }

    final Duration remaining = task.dueDate!.difference(scheduledAt);

    // Determine whether exact alarms are available on this device.
    AndroidScheduleMode scheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final AndroidFlutterLocalNotificationsPlugin? android = _plugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        final bool? canExact = await android?.canScheduleExactNotifications();
        if (canExact == true) {
          scheduleMode = AndroidScheduleMode.exactAllowWhileIdle;
        }
        debugPrint('[NotifDiag] canScheduleExactNotifications=$canExact → mode=$scheduleMode');
      } catch (e) {
        debugPrint('[NotifDiag] canScheduleExactNotifications error: $e');
      }
    }

    try {
      await _plugin.zonedSchedule(
        id: notifId,
        title: title ?? 'Deadline tugas',
        body: body ?? '${task.title} ${reminderBodyFor(remaining)}',
        scheduledDate: tz.TZDateTime.from(scheduledAt, tz.local),
        notificationDetails: _details(),
        androidScheduleMode: scheduleMode,
        payload: 'task:${task.id}',
      );
      debugPrint('[NotifDiag] Scheduled notif id=$notifId at $scheduledAt (mode=$scheduleMode)');
      NotificationDiagLog.instance.add(
        category: 'task',
        notifId: notifId,
        scheduledAt: scheduledAt,
        mode: scheduleMode == AndroidScheduleMode.exactAllowWhileIdle ? 'exact' : 'inexact',
        result: 'scheduled',
        message: 'Dijadwalkan pada $scheduledAt (mode=${scheduleMode.name})',
      );

      // Verify the notification is actually pending.
      final List<PendingNotificationRequest> pending =
          await _plugin.pendingNotificationRequests();
      final bool found = pending.any((PendingNotificationRequest r) => r.id == notifId);
      debugPrint('[NotifDiag] Verification: notif id=$notifId found in pending=$found (total pending=${pending.length})');
    } catch (error) {
      debugPrint('[NotifDiag] FAILED to schedule notif id=$notifId: $error');
      NotificationDiagLog.instance.add(
        category: 'task',
        notifId: notifId,
        scheduledAt: scheduledAt,
        mode: scheduleMode == AndroidScheduleMode.exactAllowWhileIdle ? 'exact' : 'inexact',
        result: 'error',
        message: 'Gagal menjadwalkan: $error',
      );
      rethrow;
    }
  }

  @override
  Future<void> cancelTaskReminder(String taskId) async {
    await initialize();
    final int notifId = taskNotificationId(taskId);
    try {
      await _plugin.cancel(id: notifId);
      NotificationDiagLog.instance.removeSchedule(notifId);
      NotificationDiagLog.instance.add(
        category: 'task',
        notifId: notifId,
        mode: '-',
        result: 'cancelled',
        message: 'Pengingat tugas $taskId dibatalkan.',
      );
    } catch (error) {
      debugPrint('Gagal membatalkan pengingat tugas $taskId: $error');
    }
  }

  @override
  Future<void> rescheduleTaskReminders(List<TaskItem> tasks) async {
    await initialize();
    await cancelAllTaskReminders();
    for (final TaskItem task in tasks) {
      try {
        await scheduleTaskReminder(task);
      } catch (error) {
        debugPrint('Gagal menjadwalkan tugas ${task.id}: $error');
      }
    }
  }

  @override
  Future<void> cancelAllTaskReminders() async {
    await initialize();
    try {
      // Hanya batalkan notifikasi bertanda tugas. Daily Roasting dijadwalkan
      // terpisah dan tidak boleh ikut terhapus saat sinkronisasi tugas.
      final List<PendingNotificationRequest> pending = await _plugin
          .pendingNotificationRequests();
      for (final PendingNotificationRequest request in pending) {
        if ((request.payload ?? '').startsWith('task:')) {
          await _plugin.cancel(id: request.id);
          NotificationDiagLog.instance.removeSchedule(request.id);
        }
      }
    } catch (error) {
      debugPrint('Gagal membatalkan semua pengingat tugas: $error');
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
        notificationDetails: _details(),
        payload: 'budget',
      );
      NotificationDiagLog.instance.add(
        category: 'budget',
        notifId: id,
        mode: 'immediate',
        result: 'shown',
        message: 'Budget alert ditampilkan ($title)',
      );
    } catch (error) {
      NotificationDiagLog.instance.add(
        category: 'budget',
        notifId: id,
        mode: 'immediate',
        result: 'error',
        message: 'Gagal menampilkan budget alert: $error',
      );
      rethrow;
    }
  }

  @override
  Future<bool> scheduleDailyRoasting({
    required int id,
    required DateTime scheduledAt,
    required String title,
    required String body,
    required String payload,
  }) async {
    await initialize();
    if (!scheduledAt.isAfter(DateTime.now())) {
      NotificationDiagLog.instance.add(
        category: 'daily',
        notifId: id,
        scheduledAt: scheduledAt,
        mode: 'inexact',
        result: 'skipped',
        message: 'Waktu Daily Roasting sudah lewat.',
      );
      return false;
    }
    try {
      await _plugin.cancel(id: id);
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.from(scheduledAt, tz.local),
        notificationDetails: _details(),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: payload,
      );
      NotificationDiagLog.instance.add(
        category: 'daily',
        notifId: id,
        scheduledAt: scheduledAt,
        mode: 'inexact',
        result: 'scheduled',
        message: 'Daily Roasting dijadwalkan pada $scheduledAt.',
      );
      return true;
    } catch (error) {
      debugPrint('Gagal menjadwalkan Daily Roasting: $error');
      NotificationDiagLog.instance.add(
        category: 'daily',
        notifId: id,
        scheduledAt: scheduledAt,
        mode: 'inexact',
        result: 'error',
        message: 'Gagal menjadwalkan Daily Roasting: $error',
      );
      return false;
    }
  }

  @override
  Future<void> cancelNotification(int id) async {
    await initialize();
    try {
      await _plugin.cancel(id: id);
      NotificationDiagLog.instance.removeSchedule(id);
      NotificationDiagLog.instance.add(
        category: 'general',
        notifId: id,
        mode: '-',
        result: 'cancelled',
        message: 'Notifikasi $id dibatalkan.',
      );
    } catch (error) {
      debugPrint('Gagal membatalkan notifikasi $id: $error');
    }
  }

  bool get isInitialized => _initialized;

  Future<bool> areNotificationsEnabled() async {
    if (kIsWeb) return false;
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? android = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      return await android?.areNotificationsEnabled() ?? false;
    }
    return true;
  }

  Future<bool> canScheduleExactNotifications() async {
    if (kIsWeb) return false;
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? android = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      return await android?.canScheduleExactNotifications() ?? false;
    }
    return true;
  }

  Future<List<PendingNotificationRequest>> getPendingNotificationRequests() async {
    return _plugin.pendingNotificationRequests();
  }

  Future<List<AndroidNotificationChannel>?> getNotificationChannels() async {
    if (kIsWeb) return null;
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? android = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      return await android?.getNotificationChannels();
    }
    return null;
  }

  Future<void> showTestNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    await initialize();
    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: _details(),
        payload: payload ?? 'debug:test',
      );
      NotificationDiagLog.instance.add(
        category: 'test',
        notifId: id,
        mode: 'immediate',
        result: 'shown',
        message: 'Test notification berhasil ditampilkan ($title).',
      );
    } catch (error) {
      NotificationDiagLog.instance.add(
        category: 'test',
        notifId: id,
        mode: 'immediate',
        result: 'error',
        message: 'Gagal menampilkan test notification: $error',
      );
      rethrow;
    }
  }

  @override
  Future<bool> requestExactAlarmPermissionIfNeeded() async {
    if (kIsWeb) return true;
    if (!Platform.isAndroid) return true;

    try {
      final AndroidFlutterLocalNotificationsPlugin? android = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      final bool? canExact = await android?.canScheduleExactNotifications();
      if (canExact == true) {
        return true;
      }
      // Request via Settings intent (Android 12+ / API 31+).
      await android?.requestExactAlarmsPermission();
      debugPrint('[NotifDiag] requestExactAlarmPermissionIfNeeded: opened Settings for exact alarm permission.');
      return false;
    } catch (error) {
      debugPrint('[NotifDiag] requestExactAlarmPermissionIfNeeded error: $error');
      return false;
    }
  }

  @override
  Future<void> cancelDailyRoastingExcept(String? userId) async {
    await initialize();
    final String? normalized = userId?.trim();
    final String? keepPayload = normalized == null || normalized.isEmpty
        ? null
        : 'daily:$normalized';
    try {
      final List<PendingNotificationRequest> pending = await _plugin
          .pendingNotificationRequests();
      for (final PendingNotificationRequest request in pending) {
        final String payload = request.payload ?? '';
        if (!payload.startsWith('daily:')) {
          continue;
        }
        if (keepPayload != null && payload == keepPayload) {
          continue;
        }
        await _plugin.cancel(id: request.id);
      }
    } catch (error) {
      debugPrint('Gagal membersihkan jadwal Daily Roasting lama: $error');
    }
  }

  NotificationDetails _details() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );
  }

  /// Waktu pengingat: 5 menit sebelum deadline. Jika deadline tinggal kurang
  /// dari 5 menit, pengingat dijadwalkan 5 detik dari sekarang. Tugas yang
  /// sudah selesai atau tidak punya `dueDate` tidak dijadwalkan.
  static DateTime? reminderTimeFor(TaskItem task, DateTime now) {
    if (task.done || task.dueDate == null) {
      return null;
    }
    final DateTime due = task.dueDate!;
    if (!due.isAfter(now)) {
      return null;
    }
    final Duration remaining = due.difference(now);
    if (remaining > const Duration(minutes: 5)) {
      return due.subtract(const Duration(minutes: 5));
    }
    // Deadline is within 5 minutes but not yet past: show immediately
    return now.add(const Duration(seconds: 5));
  }

  @visibleForTesting
  static String reminderBodyFor(Duration remaining) {
    if (remaining.inSeconds <= 10) {
      return 'akan segera mencapai tenggat!';
    }
    if (remaining.inMinutes < 1) {
      return 'akan mencapai tenggat dalam kurang dari 1 menit.';
    }
    if (remaining.inMinutes == 5) {
      return 'akan mencapai tenggat dalam 5 menit.';
    }
    return 'akan mencapai tenggat dalam ${remaining.inMinutes} menit.';
  }
}
