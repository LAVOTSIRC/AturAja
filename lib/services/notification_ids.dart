/// ID notifikasi lokal yang stabil antar proses dan restart aplikasi.
///
/// Nilai 31-bit dipakai agar aman untuk Android dan iOS.
int stableNotificationId(String value) {
  // FNV-1a 31-bit.
  int hash = 0x811c9dc5;
  for (final int codeUnit in value.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return hash;
}

int taskNotificationId(String taskId) => stableNotificationId('task:$taskId');

int dailyRoastingNotificationId(String userKey) =>
    stableNotificationId('daily:$userKey');
