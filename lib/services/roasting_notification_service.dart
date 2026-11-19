import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models.dart';
import '../data/roasting_intensity.dart';
import '../data/roasting_notification.dart';
import '../providers/settings_provider.dart';
import 'budget_alert_service.dart';
import 'local_notification_service.dart';
import 'notification_ids.dart';
import 'roasting_ai_service.dart';

/// Koordinator notifikasi roasting otomatis.
///
/// Tanggung jawabnya:
/// - memeriksa pengaturan sebelum memanggil AI,
/// - menyiapkan konten saat aplikasi aktif,
/// - menyimpan pesan yang sudah dibuat agar tidak memanggil Gemini berulang,
/// - mencegah notifikasi ganda per akun/periode,
/// - menyerahkan penjadwalan ke [AppNotificationService].
class RoastingNotificationService {
  RoastingNotificationService({
    required this.notifications,
    required this.generator,
    required this.settings,
    this.preferences,
    DateTime Function()? clock,
    this.activeUserId,
    this.isAppActive,
  }) : _clock = clock ?? DateTime.now;

  static const int _historyLimit = 5;
  static const int _historyPromptLimit = 3;
  static const String _historyKeyPrefix = 'aturaja_roast_history_';
  static const String _taskKeyPrefix = 'aturaja_roast_task_';
  static const String _dailyKeyPrefix = 'aturaja_roast_daily_';
  static const String _budgetKeyPrefix = 'aturaja_budget_alert_';

  final AppNotificationService notifications;
  final RoastingNotificationGenerator generator;
  final SettingsController settings;
  SharedPreferences? preferences;
  final DateTime Function() _clock;
  final String? Function()? activeUserId;
  final bool Function()? isAppActive;

  Future<void> _taskChain = Future<void>.value();
  Future<void> _dailyChain = Future<void>.value();

  /// Membuat isi Budget Roasting. Mengembalikan null jika fitur tidak aktif
  /// sehingga [BudgetAlertService] memakai teks Budget Alert biasa.
  Future<BudgetAlertContent?> buildBudgetContent({
    required String? userId,
    required int threshold,
    required int spent,
    required int limit,
  }) async {
    if (!_isActive(userId) ||
        !settings.roastingAiEnabled ||
        !settings.budgetRoastingEnabled ||
        !settings.budgetAlertsEnabled) {
      return null;
    }

    final RoastingIntensity intensity = settings.roastingIntensity;
    final List<String> recent = await _recentMessages(userId);
    if (!_isActive(userId)) {
      return null;
    }
    RoastingNotificationMessage result;
    try {
      result = await generator.generateBudgetNotification(
        intensity: intensity,
        spent: spent,
        limit: limit,
        threshold: threshold,
        recentMessages: recent,
      );
    } catch (error) {
      debugPrint('Generator Budget Roasting gagal: $error');
      result = RoastingNotificationMessage(
        body: fallbackBudgetRoast(
          intensity: intensity,
          spent: spent,
          limit: limit,
          threshold: threshold,
        ),
        generatedByAi: false,
        kind: RoastingNotificationKind.budget,
      );
    }

    if (!_isActive(userId) ||
        !settings.roastingAiEnabled ||
        !settings.budgetRoastingEnabled ||
        !settings.budgetAlertsEnabled) {
      return null;
    }
    final String body = _nonEmpty(
      result.body,
      fallbackBudgetRoast(
        intensity: intensity,
        spent: spent,
        limit: limit,
        threshold: threshold,
      ),
    );
    await _remember(userId, body);
    return BudgetAlertContent(
      title: 'Budget Roasting',
      body: body,
      generatedByAi: result.generatedByAi,
    );
  }

  /// Menyinkronkan pengingat tugas. Pesan AI dibuat dan disimpan sebelum
  /// dijadwalkan, sehingga notifikasi tetap tampil walau aplikasi ditutup.
  Future<void> syncTaskReminders({
    required String? userId,
    required List<TaskItem> tasks,
  }) {
    final String? user = _schedulingUser(userId);
    final List<TaskItem> snapshot = List<TaskItem>.unmodifiable(tasks);
    final Future<void> next = _taskChain.then(
      (_) => _runTaskSync(user, snapshot),
    );
    _taskChain = next.catchError((Object error) {
      debugPrint('Sinkronisasi Deadline Roasting gagal: $error');
    });
    return next;
  }

  /// Menyiapkan dan menjadwalkan Daily Roasting berikutnya.
  Future<void> syncDaily({
    required String? userId,
    required DailyRoastingSummary summary,
  }) {
    final String? user = _schedulingUser(userId);
    final Future<void> next = _dailyChain.then(
      (_) => _runDailySync(user, summary),
    );
    _dailyChain = next.catchError((Object error) {
      debugPrint('Sinkronisasi Daily Roasting gagal: $error');
    });
    return next;
  }

  /// Membatalkan jadwal milik akun yang sedang keluar.
  ///
  /// Riwayat dan status tetap disimpan agar tidak memicu generasi ulang saat
  /// pengguna kembali, tetapi tidak dipakai oleh akun lain.
  Future<void> cancelForUser(String? userId) async {
    final String? user = _schedulingUser(userId);
    if (user == null) {
      return;
    }
    await notifications.cancelNotification(dailyRoastingNotificationId(user));
    await notifications.cancelAllTaskReminders();
  }

  /// Menghapus jadwal dan status lokal untuk akun yang datanya dihapus.
  Future<void> clearUserData(String? userId) async {
    final String? user = _schedulingUser(userId);
    if (user == null) {
      return;
    }
    await cancelForUser(user);
    final SharedPreferences prefs = await _prefs();
    final String historyKey = _historyKey(user);
    final String dailyKey = _dailyRecordKey(user);
    final String taskPrefix = '$_taskKeyPrefix${_userKey(user)}_';
    final String budgetPrefix = '$_budgetKeyPrefix${_userKey(user)}_';
    for (final String key in prefs.getKeys().toList()) {
      if (key == historyKey ||
          key == dailyKey ||
          key.startsWith(taskPrefix) ||
          key.startsWith(budgetPrefix)) {
        await prefs.remove(key);
      }
    }
  }

  Future<void> _cancelOtherDailyRoasting(String? userId) async {
    final AppNotificationService service = notifications;
    if (service is DailyRoastingCleaner) {
      await (service as DailyRoastingCleaner).cancelDailyRoastingExcept(userId);
    }
  }

  Future<void> _runTaskSync(String? userId, List<TaskItem> tasks) async {
    try {
      if (userId == null || !settings.deadlineNotificationsEnabled) {
        await notifications.cancelAllTaskReminders();
        return;
      }
      if (!_isCurrentUser(userId)) {
        return;
      }

      final bool useRoasting =
          settings.roastingAiEnabled && settings.deadlineRoastingEnabled;
      if (!useRoasting || !(isAppActive?.call() ?? true)) {
        await notifications.rescheduleTaskReminders(tasks);
        return;
      }

      final SharedPreferences prefs = await _prefs();
      final DateTime now = _clock();
      final RoastingIntensity intensity = settings.roastingIntensity;
      final List<_TaskPlan> plans = <_TaskPlan>[];

      for (final TaskItem task in tasks) {
        if (!_isActive(userId)) {
          return;
        }
        if (!settings.roastingAiEnabled ||
            !settings.deadlineRoastingEnabled ||
            !settings.deadlineNotificationsEnabled) {
          await notifications.rescheduleTaskReminders(tasks);
          return;
        }
        final DateTime? scheduledAt = LocalNotificationService.reminderTimeFor(
          task,
          now,
        );
        if (scheduledAt == null) {
          continue;
        }

        final Duration remaining = task.dueDate!.difference(scheduledAt);
        final String signature = _taskSignature(task, intensity, remaining);
        final String cacheKey = _taskCacheKey(userId, task.id);
        final _TaskMessageRecord? cached = _decodeTaskMessage(
          prefs.getString(cacheKey),
        );

        _TaskMessageRecord record;
        if (cached != null &&
            cached.signature == signature &&
            cached.body.trim().isNotEmpty) {
          record = cached;
        } else {
          final String fallback = fallbackDeadlineRoast(
            intensity: intensity,
            taskTitle: task.title,
            remaining: remaining,
          );
          RoastingNotificationMessage result;
          try {
            final List<String> recent = await _recentMessages(userId);
            if (!_isActive(userId)) {
              return;
            }
            result = await generator.generateDeadlineNotification(
              intensity: intensity,
              taskTitle: task.title,
              dueAt: task.dueDate!,
              remaining: remaining,
              recentMessages: recent,
            );
          } catch (error) {
            debugPrint('Generator Deadline Roasting gagal: $error');
            result = RoastingNotificationMessage(
              body: fallback,
              generatedByAi: false,
              kind: RoastingNotificationKind.deadline,
            );
          }
          if (!_isActive(userId)) {
            return;
          }
          final String body = _nonEmpty(result.body, fallback);
          record = _TaskMessageRecord(
            signature: signature,
            body: body,
            generatedByAi: result.generatedByAi,
          );
          await prefs.setString(cacheKey, jsonEncode(record.toJson()));
          await _remember(userId, body);
        }

        plans.add(_TaskPlan(task: task, body: record.body));
      }

      if (!_isCurrentUser(userId)) {
        return;
      }
      if (!settings.roastingAiEnabled ||
          !settings.deadlineRoastingEnabled ||
          !settings.deadlineNotificationsEnabled) {
        await notifications.rescheduleTaskReminders(tasks);
        return;
      }
      await notifications.cancelAllTaskReminders();
      for (final _TaskPlan plan in plans) {
        if (!_isCurrentUser(userId)) {
          return;
        }
        await notifications.scheduleTaskReminder(
          plan.task,
          title: 'Deadline Roasting',
          body: plan.body,
        );
      }
      try {
        await _pruneTaskCache(
          userId,
          tasks.map((TaskItem task) => task.id).toSet(),
          prefs,
        );
      } catch (error) {
        debugPrint('Gagal membersihkan cache Deadline Roasting: $error');
      }
    } catch (error) {
      debugPrint('Gagal menyiapkan Deadline Roasting: $error');
      if (userId != null && _isCurrentUser(userId)) {
        try {
          await notifications.rescheduleTaskReminders(tasks);
        } catch (fallbackError) {
          debugPrint(
            'Gagal menjadwalkan pengingat tugas biasa: $fallbackError',
          );
        }
      }
    }
  }

  Future<void> _runDailySync(
    String? userId,
    DailyRoastingSummary summary,
  ) async {
    try {
      if (userId == null) {
        await _cancelOtherDailyRoasting(null);
        return;
      }
      if (!_isCurrentUser(userId)) {
        return;
      }
      await _cancelOtherDailyRoasting(userId);
      final int notificationId = dailyRoastingNotificationId(userId);
      if (!settings.roastingAiEnabled || !settings.dailyRoastingEnabled) {
        await notifications.cancelNotification(notificationId);
        return;
      }
      if (!(isAppActive?.call() ?? true)) {
        return;
      }

      final SharedPreferences prefs = await _prefs();
      final DateTime now = _clock();
      final RoastingIntensity intensity = settings.roastingIntensity;
      _DailyMessageRecord? record = _decodeDailyMessage(
        prefs.getString(_dailyRecordKey(userId)),
      );
      final DateTime candidate = _nextDailySlot(now, record);
      final String dateKey = _dateKey(candidate);
      final bool canReuse =
          record != null &&
          record.dateKey == dateKey &&
          record.intensityName == intensity.name &&
          record.body.trim().isNotEmpty;

      if (!canReuse) {
        final String fallback = fallbackDailyRoast(
          intensity: intensity,
          summary: summary,
        );
        RoastingNotificationMessage result;
        try {
          final List<String> recent = await _recentMessages(userId);
          if (!_isActive(userId)) {
            return;
          }
          result = await generator.generateDailyNotification(
            intensity: intensity,
            summary: summary,
            recentMessages: recent,
          );
        } catch (error) {
          debugPrint('Generator Daily Roasting gagal: $error');
          result = RoastingNotificationMessage(
            body: fallback,
            generatedByAi: false,
            kind: RoastingNotificationKind.daily,
          );
        }
        if (!_isCurrentUser(userId)) {
          return;
        }
        if (!settings.roastingAiEnabled || !settings.dailyRoastingEnabled) {
          await notifications.cancelNotification(notificationId);
          return;
        }
        final String body = _nonEmpty(result.body, fallback);
        record = _DailyMessageRecord(
          dateKey: dateKey,
          body: body,
          intensityName: intensity.name,
          generatedByAi: result.generatedByAi,
          scheduledAt: candidate,
        );
        await prefs.setString(
          _dailyRecordKey(userId),
          jsonEncode(record.toJson()),
        );
        await _remember(userId, body);
      } else {
        record = _DailyMessageRecord(
          dateKey: record.dateKey,
          body: record.body,
          intensityName: record.intensityName,
          generatedByAi: record.generatedByAi,
          scheduledAt: candidate,
        );
        await prefs.setString(
          _dailyRecordKey(userId),
          jsonEncode(record.toJson()),
        );
      }

      if (!_isCurrentUser(userId)) {
        return;
      }
      if (!settings.roastingAiEnabled || !settings.dailyRoastingEnabled) {
        await notifications.cancelNotification(notificationId);
        return;
      }
      await notifications.scheduleDailyRoasting(
        id: notificationId,
        scheduledAt: candidate,
        title: 'Daily Roasting',
        body: record.body,
        payload: 'daily:$userId',
      );
    } catch (error) {
      debugPrint('Gagal menyiapkan Daily Roasting: $error');
    }
  }

  DateTime _nextDailySlot(DateTime now, _DailyMessageRecord? record) {
    final int hour = settings.dailyRoastingHour;
    final int minute = settings.dailyRoastingMinute;
    final DateTime todaySlot = DateTime(
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    final DateTime tomorrowSlot = DateTime(
      now.year,
      now.month,
      now.day + 1,
      hour,
      minute,
    );

    DateTime candidate;
    final DateTime? recordDate = record == null
        ? null
        : _parseDateKey(record.dateKey);
    if (recordDate != null && !_dateOnly(recordDate).isBefore(_dateOnly(now))) {
      final DateTime recordSlot = DateTime(
        recordDate.year,
        recordDate.month,
        recordDate.day,
        hour,
        minute,
      );
      if (_sameDay(recordDate, now) && !record!.scheduledAt.isAfter(now)) {
        // Slot hari ini sudah lewat/terkirim; jangan mengirim dua kali.
        candidate = tomorrowSlot;
      } else if (recordSlot.isAfter(now)) {
        candidate = recordSlot;
      } else {
        candidate = tomorrowSlot;
      }
    } else {
      candidate = todaySlot.isAfter(now) ? todaySlot : tomorrowSlot;
    }

    if (!candidate.isAfter(now)) {
      candidate = tomorrowSlot;
    }
    return candidate;
  }

  String _taskSignature(
    TaskItem task,
    RoastingIntensity intensity,
    Duration remaining,
  ) {
    return '${task.title.trim()}|'
        '${task.dueDate?.toIso8601String() ?? ''}|'
        '${intensity.name}|'
        '${_remainingBucket(remaining)}';
  }

  String _remainingBucket(Duration remaining) {
    if (remaining < const Duration(minutes: 5)) {
      return 'immediate';
    }
    final int minutes = remaining.inMinutes;
    if (minutes <= 5) {
      return 'under-5';
    }
    if (minutes <= 15) {
      return 'under-15';
    }
    if (minutes <= 30) {
      return 'under-30';
    }
    if (minutes <= 60) {
      return 'under-60';
    }
    return 'far';
  }

  Future<List<String>> _recentMessages(String? userId) async {
    try {
      final SharedPreferences prefs = await _prefs();
      final List<String> history = _readHistory(
        prefs.getString(_historyKey(userId)),
      );
      if (history.length <= _historyPromptLimit) {
        return history;
      }
      return history.sublist(history.length - _historyPromptLimit);
    } catch (error) {
      debugPrint('Gagal membaca riwayat roasting: $error');
      return <String>[];
    }
  }

  Future<void> _remember(String? userId, String message) async {
    final String normalized = message.trim();
    if (normalized.isEmpty) {
      return;
    }
    try {
      final SharedPreferences prefs = await _prefs();
      final List<String> history = _readHistory(
        prefs.getString(_historyKey(userId)),
      );
      history.add(
        normalized.length > 240
            ? '${normalized.substring(0, 237)}...'
            : normalized,
      );
      while (history.length > _historyLimit) {
        history.removeAt(0);
      }
      await prefs.setString(_historyKey(userId), jsonEncode(history));
    } catch (error) {
      debugPrint('Gagal menyimpan riwayat roasting: $error');
    }
  }

  List<String> _readHistory(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return <String>[];
    }
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<String>()
            .map((String value) => value.trim())
            .where((String value) => value.isNotEmpty)
            .toList();
      }
    } catch (_) {
      // Riwayat rusak tidak boleh menghalangi notifikasi baru.
    }
    return <String>[];
  }

  Future<void> _pruneTaskCache(
    String userId,
    Set<String> taskIds,
    SharedPreferences prefs,
  ) async {
    final String prefix = '$_taskKeyPrefix${_userKey(userId)}_';
    for (final String key in prefs.getKeys().toList()) {
      if (!key.startsWith(prefix)) {
        continue;
      }
      final String taskId = key.substring(prefix.length);
      if (!taskIds.contains(taskId)) {
        await prefs.remove(key);
      }
    }
  }

  Future<SharedPreferences> _prefs() async {
    final SharedPreferences? cached = preferences;
    if (cached != null) {
      return cached;
    }
    final SharedPreferences loaded = await SharedPreferences.getInstance();
    preferences = loaded;
    return loaded;
  }

  bool _isActive(String? userId) {
    return _isCurrentUser(userId) && (isAppActive?.call() ?? true);
  }

  bool _isCurrentUser(String? userId) {
    final String? Function()? callback = activeUserId;
    if (callback == null) {
      return true;
    }
    return _userKey(callback()) == _userKey(userId);
  }

  String? _schedulingUser(String? userId) {
    final String? normalized = userId?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  String _userKey(String? userId) {
    final String? normalized = userId?.trim();
    return normalized == null || normalized.isEmpty ? 'guest' : normalized;
  }

  String _historyKey(String? userId) => '$_historyKeyPrefix${_userKey(userId)}';

  String _taskCacheKey(String userId, String taskId) =>
      '$_taskKeyPrefix${_userKey(userId)}_$taskId';

  String _dailyRecordKey(String userId) =>
      '$_dailyKeyPrefix${_userKey(userId)}';

  String _dateKey(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)}';
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  DateTime? _parseDateKey(String value) {
    final RegExpMatch? match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$')
        .firstMatch(value.trim());
    if (match == null) {
      return null;
    }
    final int? year = int.tryParse(match.group(1)!);
    final int? month = int.tryParse(match.group(2)!);
    final int? day = int.tryParse(match.group(3)!);
    if (year == null || month == null || day == null) {
      return null;
    }
    final DateTime result = DateTime(year, month, day);
    if (result.year != year || result.month != month || result.day != day) {
      return null;
    }
    return result;
  }

  _TaskMessageRecord? _decodeTaskMessage(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is Map) {
        return _TaskMessageRecord.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {
      // Cache rusak diabaikan dan pesan akan dibuat ulang.
    }
    return null;
  }

  _DailyMessageRecord? _decodeDailyMessage(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is Map) {
        return _DailyMessageRecord.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {
      // Cache rusak diabaikan dan pesan akan dibuat ulang.
    }
    return null;
  }

  static String _nonEmpty(String value, String fallback) {
    final String normalized = value.trim();
    return normalized.isEmpty ? fallback : normalized;
  }
}

class _TaskPlan {
  final TaskItem task;
  final String body;

  const _TaskPlan({required this.task, required this.body});
}

class _TaskMessageRecord {
  final String signature;
  final String body;
  final bool generatedByAi;

  const _TaskMessageRecord({
    required this.signature,
    required this.body,
    required this.generatedByAi,
  });

  factory _TaskMessageRecord.fromJson(Map<String, dynamic> json) {
    return _TaskMessageRecord(
      signature: json['signature'] as String? ?? '',
      body: json['body'] as String? ?? '',
      generatedByAi: json['generatedByAi'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'signature': signature,
    'body': body,
    'generatedByAi': generatedByAi,
  };
}

class _DailyMessageRecord {
  final String dateKey;
  final String body;
  final String intensityName;
  final bool generatedByAi;
  final DateTime scheduledAt;

  const _DailyMessageRecord({
    required this.dateKey,
    required this.body,
    required this.intensityName,
    required this.generatedByAi,
    required this.scheduledAt,
  });

  factory _DailyMessageRecord.fromJson(Map<String, dynamic> json) {
    final String scheduledAtRaw = json['scheduledAt'] as String? ?? '';
    final DateTime scheduledAt =
        DateTime.tryParse(scheduledAtRaw) ??
        DateTime.fromMillisecondsSinceEpoch(0);
    return _DailyMessageRecord(
      dateKey: json['dateKey'] as String? ?? '',
      body: json['body'] as String? ?? '',
      intensityName: json['intensity'] as String? ?? '',
      generatedByAi: json['generatedByAi'] as bool? ?? false,
      scheduledAt: scheduledAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'dateKey': dateKey,
    'body': body,
    'intensity': intensityName,
    'generatedByAi': generatedByAi,
    'scheduledAt': scheduledAt.toIso8601String(),
  };
}
