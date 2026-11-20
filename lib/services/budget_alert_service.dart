import 'package:shared_preferences/shared_preferences.dart';

import 'local_notification_service.dart';

/// Mengirim peringatan anggaran satu kali untuk setiap ambang 80% dan 100%
/// per bulan. Penanda ambang disimpan di SharedPreferences agar tidak berulang
/// setiap kali transaksi baru ditambahkan.
class BudgetAlertService {
  BudgetAlertService({required this.notifications, this.preferences});

  final AppNotificationService notifications;
  SharedPreferences? preferences;

  Future<void> check({
    required String? userId,
    required int spent,
    required int limit,
    required bool enabled,
  }) async {
    if (!enabled || limit <= 0 || spent <= 0) {
      return;
    }

    final int threshold = spent >= limit
        ? 100
        : (spent * 5 >= limit * 4 ? 80 : 0);
    if (threshold == 0) {
      return;
    }

    try {
      final SharedPreferences sharedPreferences =
          preferences ?? await SharedPreferences.getInstance();
      preferences = sharedPreferences;

      final DateTime now = DateTime.now();
      final String key =
          'aturaja_budget_alert_${userId?.trim().isNotEmpty == true ? userId : 'guest'}_'
          '${now.year}_${now.month}_$limit';
      final int previousThreshold = sharedPreferences.getInt(key) ?? 0;
      if (previousThreshold >= threshold) {
        return;
      }

      final String title;
      final String body;
      if (threshold >= 100) {
        title = 'Limit anggaran tercapai';
        body =
            'Pengeluaran bulan ini sudah mencapai limit ${_rupiah(limit)}. '
            'Coba tahan pengeluaran tidak penting dulu.';
      } else {
        final int remaining = limit - spent;
        title = 'Budget alert 80%';
        body =
            'Pengeluaran bulan ini sudah 80% dari limit. '
            'Sisa anggaran ${_rupiah(remaining)}.';
      }

      await notifications.showBudgetAlert(
        id: _stableNotificationId('budget:$key'),
        title: title,
        body: body,
      );
      await sharedPreferences.setInt(key, threshold);
    } catch (_) {
      // Kegagalan notifikasi tidak boleh mengganggu pencatatan transaksi.
    }
  }

  static String _rupiah(int value) {
    final String digits = value.toString();
    final StringBuffer buffer = StringBuffer('Rp');
    for (int index = 0; index < digits.length; index++) {
      if (index > 0 && (digits.length - index) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(digits[index]);
    }
    return buffer.toString();
  }

  static int _stableNotificationId(String value) {
    int hash = 0x811c9dc5;
    for (final int codeUnit in value.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }
}
