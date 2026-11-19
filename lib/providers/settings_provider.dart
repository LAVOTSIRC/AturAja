import 'package:flutter/foundation.dart';

class SettingsController extends ChangeNotifier {
  bool deadlineNotificationsEnabled = true;
  bool budgetAlertsEnabled = true;
  bool roastingAiEnabled = true;
  bool autoBackupEnabled = true;
  int monthlyBudgetLimit = 1200000;
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
    autoBackupEnabled = true;
    monthlyBudgetLimit = 1200000;
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
