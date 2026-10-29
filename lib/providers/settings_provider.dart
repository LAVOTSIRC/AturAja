import 'package:flutter/foundation.dart';

class SettingsController extends ChangeNotifier {
  bool deadlineNotificationsEnabled = true;
  bool budgetAlertsEnabled = true;
  bool roastingAiEnabled = true;
  bool autoBackupEnabled = true;
  bool isCloudSyncing = false;
  int monthlyBudgetLimit = 1200000;
  bool biometricLockEnabled = true;
  bool pinWasUpdated = false;
  bool accountDeletionRequested = false;
  DateTime? lastSyncedAt = DateTime.now().subtract(const Duration(minutes: 10));
  bool _isDisposed = false;

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
    if (isCloudSyncing) {
      return 'Menyinkronkan...';
    }
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

  String get nlpModelStatus => 'Model lokal v2.1';

  String get privacyStatus {
    if (accountDeletionRequested) {
      return 'Akun ditandai dihapus';
    }
    return biometricLockEnabled ? 'Biometrik aktif' : 'Biometrik nonaktif';
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

  Future<void> syncCloud() async {
    if (isCloudSyncing || _isDisposed) {
      return;
    }
    isCloudSyncing = true;
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (_isDisposed) {
      return;
    }
    lastSyncedAt = DateTime.now();
    isCloudSyncing = false;
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
    isCloudSyncing = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
