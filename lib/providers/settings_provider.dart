import 'package:flutter/foundation.dart';

import '../data/roasting_intensity.dart';

class SettingsController extends ChangeNotifier {
  bool deadlineNotificationsEnabled = true;
  bool budgetAlertsEnabled = true;
  bool roastingAiEnabled = true;
  RoastingIntensity roastingIntensity = RoastingIntensity.defaultIntensity;

  /// Notifikasi roasting otomatis nonaktif secara default agar perilaku
  /// pengguna lama tidak berubah tanpa persetujuan.
  bool budgetRoastingEnabled = false;
  bool deadlineRoastingEnabled = false;
  bool dailyRoastingEnabled = false;
  int dailyRoastingHour = 20;
  int dailyRoastingMinute = 0;

  bool autoBackupEnabled = true;
  int monthlyBudgetLimit = 0;
  bool biometricLockEnabled = false;
  bool pinWasUpdated = false;
  bool accountDeletionRequested = false;
  DateTime? lastSyncedAt;

  int get activeNotificationCount =>
      (deadlineNotificationsEnabled ? 1 : 0) +
      (budgetAlertsEnabled ? 1 : 0) +
      (roastingAiEnabled ? 1 : 0);

  String get notificationStatus {
    if (activeNotificationCount == 0) {
      return 'Semua notifikasi nonaktif';
    }
    return '$activeNotificationCount dari 3 kategori aktif';
  }

  String get dailyRoastingTimeLabel {
    final String hour = dailyRoastingHour.toString().padLeft(2, '0');
    final String minute = dailyRoastingMinute.toString().padLeft(2, '0');
    return '$hour.$minute';
  }

  String get cloudSyncStatus {
    final DateTime? syncedAt = lastSyncedAt;
    if (syncedAt == null) {
      return 'Belum pernah';
    }
    final int minutes = DateTime.now().difference(syncedAt).inMinutes;
    if (minutes <= 0) {
      return 'Baru saja';
    }
    if (minutes == 1) {
      return 'Sinkron 1 mnt lalu';
    }
    return 'Sinkron $minutes mnt lalu';
  }

  String get cloudBackupStatus =>
      '$cloudSyncStatus | ${autoBackupEnabled ? 'Auto' : 'Manual'}';

  String get nlpModelStatus => 'Demo NLP lokal';

  String get privacyStatus {
    if (accountDeletionRequested) {
      return 'Akun ditandai dihapus';
    }
    return biometricLockEnabled ? 'Biometrik aktif' : 'Biometrik nonaktif';
  }

  void resetToDefaults() {
    deadlineNotificationsEnabled = true;
    budgetAlertsEnabled = true;
    roastingAiEnabled = true;
    roastingIntensity = RoastingIntensity.defaultIntensity;
    budgetRoastingEnabled = false;
    deadlineRoastingEnabled = false;
    dailyRoastingEnabled = false;
    dailyRoastingHour = 20;
    dailyRoastingMinute = 0;
    autoBackupEnabled = true;
    monthlyBudgetLimit = 0;
    biometricLockEnabled = false;
    pinWasUpdated = false;
    accountDeletionRequested = false;
    lastSyncedAt = null;
    notifyListeners();
  }

  void setDeadlineNotifications(bool value) {
    if (deadlineNotificationsEnabled == value) {
      return;
    }
    deadlineNotificationsEnabled = value;
    notifyListeners();
  }

  void setBudgetAlerts(bool value) {
    if (budgetAlertsEnabled == value) {
      return;
    }
    budgetAlertsEnabled = value;
    notifyListeners();
  }

  void setRoastingAi(bool value) {
    if (roastingAiEnabled == value) {
      return;
    }
    roastingAiEnabled = value;
    notifyListeners();
  }

  void setRoastingIntensity(RoastingIntensity value) {
    if (roastingIntensity == value) {
      return;
    }
    roastingIntensity = value;
    notifyListeners();
  }

  void setBudgetRoasting(bool value) {
    if (budgetRoastingEnabled == value) {
      return;
    }
    budgetRoastingEnabled = value;
    notifyListeners();
  }

  void setDeadlineRoasting(bool value) {
    if (deadlineRoastingEnabled == value) {
      return;
    }
    deadlineRoastingEnabled = value;
    notifyListeners();
  }

  void setDailyRoasting(bool value) {
    if (dailyRoastingEnabled == value) {
      return;
    }
    dailyRoastingEnabled = value;
    notifyListeners();
  }

  void setDailyRoastingTime(int hour, int minute) {
    final int safeHour = hour.clamp(0, 23);
    final int safeMinute = minute.clamp(0, 59);
    if (dailyRoastingHour == safeHour && dailyRoastingMinute == safeMinute) {
      return;
    }
    dailyRoastingHour = safeHour;
    dailyRoastingMinute = safeMinute;
    notifyListeners();
  }

  void setAutoBackup(bool value) {
    if (autoBackupEnabled == value) {
      return;
    }
    autoBackupEnabled = value;
    notifyListeners();
  }

  void setCloudLastSyncedAt(DateTime? value) {
    if (lastSyncedAt == value) {
      return;
    }
    lastSyncedAt = value;
    notifyListeners();
  }

  void setMonthlyBudgetLimit(int value) {
    if (monthlyBudgetLimit == value) {
      return;
    }
    monthlyBudgetLimit = value;
    notifyListeners();
  }

  void setBiometricLock(bool value) {
    if (biometricLockEnabled == value) {
      return;
    }
    biometricLockEnabled = value;
    notifyListeners();
  }

  void markPinUpdated() {
    if (pinWasUpdated) {
      return;
    }
    pinWasUpdated = true;
    notifyListeners();
  }

  void requestAccountDeletion() {
    if (accountDeletionRequested) {
      return;
    }
    accountDeletionRequested = true;
    notifyListeners();
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'deadlineNotificationsEnabled': deadlineNotificationsEnabled,
    'budgetAlertsEnabled': budgetAlertsEnabled,
    'roastingAiEnabled': roastingAiEnabled,
    'roastingIntensity': roastingIntensity.name,
    'budgetRoastingEnabled': budgetRoastingEnabled,
    'deadlineRoastingEnabled': deadlineRoastingEnabled,
    'dailyRoastingEnabled': dailyRoastingEnabled,
    'dailyRoastingHour': dailyRoastingHour,
    'dailyRoastingMinute': dailyRoastingMinute,
    'autoBackupEnabled': autoBackupEnabled,
    'monthlyBudgetLimit': monthlyBudgetLimit,
    'biometricLockEnabled': biometricLockEnabled,
    'pinWasUpdated': pinWasUpdated,
    'accountDeletionRequested': accountDeletionRequested,
    'lastSyncedAt': lastSyncedAt?.toIso8601String(),
  };

  void applyJson(Map<String, dynamic> json) {
    deadlineNotificationsEnabled =
        json['deadlineNotificationsEnabled'] as bool? ??
        deadlineNotificationsEnabled;
    budgetAlertsEnabled =
        json['budgetAlertsEnabled'] as bool? ?? budgetAlertsEnabled;
    roastingAiEnabled = json['roastingAiEnabled'] as bool? ?? roastingAiEnabled;
    roastingIntensity = RoastingIntensity.fromStorage(
      json['roastingIntensity'],
    );
    budgetRoastingEnabled = json['budgetRoastingEnabled'] as bool? ?? false;
    deadlineRoastingEnabled = json['deadlineRoastingEnabled'] as bool? ?? false;
    dailyRoastingEnabled = json['dailyRoastingEnabled'] as bool? ?? false;
    final int? storedHour = (json['dailyRoastingHour'] as num?)?.toInt();
    final int? storedMinute = (json['dailyRoastingMinute'] as num?)?.toInt();
    dailyRoastingHour =
        storedHour != null && storedHour >= 0 && storedHour <= 23
        ? storedHour
        : 20;
    dailyRoastingMinute =
        storedMinute != null && storedMinute >= 0 && storedMinute <= 59
        ? storedMinute
        : 0;
    autoBackupEnabled = json['autoBackupEnabled'] as bool? ?? autoBackupEnabled;
    monthlyBudgetLimit =
        (json['monthlyBudgetLimit'] as num?)?.toInt() ?? monthlyBudgetLimit;
    biometricLockEnabled =
        json['biometricLockEnabled'] as bool? ?? biometricLockEnabled;
    pinWasUpdated = json['pinWasUpdated'] as bool? ?? pinWasUpdated;
    accountDeletionRequested =
        json['accountDeletionRequested'] as bool? ?? accountDeletionRequested;
    final String? syncedAt = json['lastSyncedAt'] as String?;
    if (syncedAt != null) {
      lastSyncedAt = DateTime.tryParse(syncedAt) ?? lastSyncedAt;
    }
    notifyListeners();
  }
}
