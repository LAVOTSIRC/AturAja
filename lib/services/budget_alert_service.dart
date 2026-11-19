import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'local_notification_service.dart';
import 'notification_ids.dart';

/// Isi notifikasi anggaran. [generatedByAi] membantu membedakan hasil Gemini
/// dari teks bawaan/fallback.
class BudgetAlertContent {
  final String title;
  final String body;
  final bool generatedByAi;

  const BudgetAlertContent({
    required this.title,
    required this.body,
    this.generatedByAi = false,
  });
}

typedef BudgetAlertContentBuilder = Future<BudgetAlertContent?> Function({
  required int threshold,
  required int spent,
  required int limit,
});

/// Mengirim peringatan anggaran satu kali untuk setiap ambang 80% dan 100%
/// per bulan. Penanda ambang disimpan di SharedPreferences agar tidak berulang
/// setiap kali transaksi baru ditambahkan.
class BudgetAlertService {
  BudgetAlertService({required this.notifications, this.preferences});

  final AppNotificationService notifications;
  SharedPreferences? preferences;

  Future<void> _checkChain = Future<void>.value();

  /// Pemeriksaan diserialisasi agar beberapa transaksi yang masuk hampir
  /// bersamaan tidak memicu ambang yang sama dua kali.
  Future<void> check({
    required String? userId,
    required int spent,
    required int limit,
    required bool enabled,
    BudgetAlertContentBuilder? contentBuilder,
    bool Function()? shouldNotify,
  }) {
    final Future<void> next = _checkChain.then(
      (_) => _check(
        userId: userId,
        spent: spent,
        limit: limit,
        enabled: enabled,
        contentBuilder: contentBuilder,
        shouldNotify: shouldNotify,
      ),
    );
    _checkChain = next.catchError((Object _) {});
    return next;
  }

  Future<void> _check({
    required String? userId,
    required int spent,
    required int limit,
    required bool enabled,
    BudgetAlertContentBuilder? contentBuilder,
    bool Function()? shouldNotify,
  }) async {
    if (!enabled || limit <= 0 || spent <= 0) {
      return;
    }
    if (shouldNotify != null && !shouldNotify()) {
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

      BudgetAlertContent? content;
      if (contentBuilder != null) {
        try {
          content = await contentBuilder(
            threshold: threshold,
            spent: spent,
            limit: limit,
          );
        } catch (error) {
          debugPrint('Gagal membuat konten Budget Roasting: $error');
        }
      }
      content ??= _staticContent(
        threshold: threshold,
        spent: spent,
        limit: limit,
      );
      if (shouldNotify != null && !shouldNotify()) {
        return;
      }

      // Show notification — if this throws, the catch below prevents setInt.
      await notifications.showBudgetAlert(
        id: stableNotificationId('budget:$key:$threshold'),
        title: content.title,
        body: content.body,
      );
      // Only save threshold after successful notification.
      await sharedPreferences.setInt(key, threshold);
    } catch (error) {
      // Kegagalan notifikasi tidak boleh mengganggu pencatatan transaksi.
      debugPrint('Gagal mengirim peringatan anggaran: $error');
    }
  }

  static BudgetAlertContent _staticContent({
    required int threshold,
    required int spent,
    required int limit,
  }) {
    if (threshold >= 100) {
      return BudgetAlertContent(
        title: 'Limit anggaran tercapai',
        body:
            'Pengeluaran bulan ini sudah mencapai limit ${_rupiah(limit)}. '
            'Coba tahan pengeluaran tidak penting dulu.',
      );
    }
    final int remaining = limit - spent;
    return BudgetAlertContent(
      title: 'Budget alert 80%',
      body:
          'Pengeluaran bulan ini sudah 80% dari limit. '
          'Sisa anggaran ${_rupiah(remaining)}.',
    );
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
}
