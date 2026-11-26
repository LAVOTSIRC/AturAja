/// Entri riwayat diagnostik notifikasi (disimpan dalam memori).
class NotificationDiagEntry {
  final DateTime timestamp;
  final String category; // 'task', 'budget', 'daily', 'test'
  final int notifId;
  final DateTime? scheduledAt;
  final String mode; // 'exact', 'inexact', 'immediate'
  final String result; // 'scheduled', 'shown', 'cancelled', 'skipped', 'error'
  final String message;

  const NotificationDiagEntry({
    required this.timestamp,
    required this.category,
    required this.notifId,
    this.scheduledAt,
    required this.mode,
    required this.result,
    required this.message,
  });
}

/// Ledger dan pencatat diagnostik notifikasi untuk keperluan debug.
///
/// Menyimpan riwayat kejadian notifikasi (maksimal 100 entri) dan memetakan
/// ID notifikasi ke waktu jadwal aktual yang dihitung saat penjadwalan.
class NotificationDiagLog {
  NotificationDiagLog._();
  static final NotificationDiagLog instance = NotificationDiagLog._();

  static const int maxEntries = 100;
  final List<NotificationDiagEntry> _entries = <NotificationDiagEntry>[];
  final Map<int, DateTime> _scheduleLedger = <int, DateTime>{};

  List<NotificationDiagEntry> getAll() =>
      List<NotificationDiagEntry>.unmodifiable(_entries.reversed);

  DateTime? getScheduledTime(int notifId) => _scheduleLedger[notifId];

  void recordSchedule(int notifId, DateTime scheduledAt) {
    _scheduleLedger[notifId] = scheduledAt;
  }

  void removeSchedule(int notifId) {
    _scheduleLedger.remove(notifId);
  }

  void add({
    required String category,
    required int notifId,
    DateTime? scheduledAt,
    required String mode,
    required String result,
    required String message,
  }) {
    if (scheduledAt != null) {
      recordSchedule(notifId, scheduledAt);
    }
    final NotificationDiagEntry entry = NotificationDiagEntry(
      timestamp: DateTime.now(),
      category: category,
      notifId: notifId,
      scheduledAt: scheduledAt,
      mode: mode,
      result: result,
      message: message,
    );
    _entries.add(entry);
    if (_entries.length > maxEntries) {
      _entries.removeAt(0);
    }
  }

  void clear() {
    _entries.clear();
    _scheduleLedger.clear();
  }
}
