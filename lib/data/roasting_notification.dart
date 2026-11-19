import 'roasting_intensity.dart';

/// Jenis konten roasting yang dipakai oleh notifikasi otomatis.
enum RoastingNotificationKind { budget, deadline, daily }

/// Hasil generasi konten notifikasi.
///
/// [generatedByAi] membedakan hasil Gemini dari fallback lokal yang dipakai
/// ketika AI gagal, timeout, atau tidak tersedia.
class RoastingNotificationMessage {
  final String body;
  final bool generatedByAi;
  final RoastingNotificationKind kind;

  const RoastingNotificationMessage({
    required this.body,
    required this.generatedByAi,
    required this.kind,
  });
}

/// Ringkasan aktivitas minimum untuk Daily Roasting.
///
/// Hanya berisi angka yang memang tersedia di aplikasi. Deskripsi tugas dan
/// seluruh riwayat transaksi tidak dikirim ke Gemini.
class DailyRoastingSummary {
  final int pendingTasks;
  final int dueTodayTasks;
  final int overdueTasks;
  final int completedToday;
  final int todayExpense;
  final int todayTransactionCount;

  const DailyRoastingSummary({
    required this.pendingTasks,
    required this.dueTodayTasks,
    required this.overdueTasks,
    required this.completedToday,
    required this.todayExpense,
    required this.todayTransactionCount,
  });
}

/// Format nominal untuk fallback lokal tanpa bergantung pada lapisan UI.
String notificationRupiah(num value) {
  final int amount = value.abs().round();
  final String digits = amount.toString();
  final StringBuffer buffer = StringBuffer('Rp');
  for (int index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(digits[index]);
  }
  return buffer.toString();
}

/// Label sisa waktu yang tetap masuk akal saat notifikasi tampil.
String deadlineRemainingLabel(Duration remaining) {
  if (remaining.inMinutes >= 60) {
    final int hours = remaining.inHours;
    return hours <= 1 ? 'sekitar 1 jam' : 'sekitar $hours jam';
  }
  if (remaining.inMinutes <= 1) {
    return 'kurang dari 1 menit';
  }
  return 'sekitar ${remaining.inMinutes} menit';
}

String _shortTaskTitle(String title) {
  final String normalized = title.trim();
  if (normalized.isEmpty) {
    return 'Tugasmu';
  }
  if (normalized.length <= 80) {
    return normalized;
  }
  return '${normalized.substring(0, 77)}...';
}

/// Fallback Budget Roasting yang tetap memuat fakta anggaran aktual.
String fallbackBudgetRoast({
  required RoastingIntensity intensity,
  required int spent,
  required int limit,
  required int threshold,
}) {
  final int percentage = limit <= 0 ? 0 : ((spent / limit) * 100).round();
  final int remaining = limit - spent < 0 ? 0 : limit - spent;
  final bool exhausted = threshold >= 100 || spent >= limit;
  final String spentText = notificationRupiah(spent);
  final String limitText = notificationRupiah(limit);
  final String remainingText = notificationRupiah(remaining);

  switch (intensity) {
    case RoastingIntensity.santai:
      if (exhausted) {
        return 'Pengeluaran bulan ini sudah $spentText dari anggaran $limitText. '
            'Anggaranmu sudah terpakai $percentage%; sekarang waktunya '
            'berhenti sebentar, cek prioritas, dan susun rencana sampai akhir '
            'bulan.';
      }
      return 'Pengeluaran bulan ini sudah $spentText dari anggaran $limitText '
          '($percentage%). Masih ada sisa $remainingText; pilih kebutuhan yang '
          'benar-benar penting agar akhir bulan tetap tenang.';

    case RoastingIntensity.seimbang:
      if (exhausted) {
        return 'Dek, pengeluaran bulan ini sudah $spentText dan anggaran '
            '$limitText sudah habis. Dompetmu butuh istirahat, bukan checkout '
            'berikutnya; saatnya benahi prioritas sampai akhir bulan.';
      }
      return 'Dek, anggaran bulan ini sudah terpakai $percentage% '
          '($spentText dari $limitText). Dompetmu mulai memberi kode darurat; '
          'rem pengeluaran sebelum sisa $remainingText ikut hilang.';

    case RoastingIntensity.pedas:
      if (exhausted) {
        return 'Anggaran $limitText sudah habis, Dek, sementara pengeluaranmu '
            'mencapai $spentText. Belanja boleh semangat, tapi dompet bukan '
            'sumber dana abadi; berhenti dan benahi prioritasmu.';
      }
      return 'Anggaran baru terpakai $percentage% dan sudah tersisa '
          '$remainingText. Kalau tombol checkout tetap jadi favorit, sisa '
          'bulan ini bakal jadi latihan bertahan hidup.';
  }
}

/// Fallback Deadline Roasting berdasarkan judul tugas dan sisa waktu aktual.
String fallbackDeadlineRoast({
  required RoastingIntensity intensity,
  required String taskTitle,
  required Duration remaining,
}) {
  final String title = _shortTaskTitle(taskTitle);
  final String timeLeft = deadlineRemainingLabel(remaining);

  switch (intensity) {
    case RoastingIntensity.santai:
      return 'Tugas "$title" punya tenggat $timeLeft lagi. Masih ada waktu '
          'untuk mulai dari langkah kecil; kerjakan bagian pertamanya sekarang, '
          'ya.';
    case RoastingIntensity.seimbang:
      return 'Dek, deadline "$title" tinggal $timeLeft lagi. Waktu untuk '
          'menunda sudah hampir habis; buka tugasnya dan mulai sekarang.';
    case RoastingIntensity.pedas:
      return '"$title" tinggal $timeLeft lagi, Dek. Deadline tidak akan '
          'menunggu sampai kamu merasa siap; kerjakan sekarang sebelum panik '
          'yang mengambil alih.';
  }
}

/// Fallback Daily Roasting yang hanya menyebut aktivitas yang tersedia.
String fallbackDailyRoast({
  required RoastingIntensity intensity,
  required DailyRoastingSummary summary,
}) {
  final List<String> facts = <String>[];
  if (summary.pendingTasks > 0) {
    facts.add('${summary.pendingTasks} tugas belum selesai');
  }
  if (summary.dueTodayTasks > 0) {
    facts.add('${summary.dueTodayTasks} tugas jatuh tempo hari ini');
  }
  if (summary.overdueTasks > 0) {
    facts.add('${summary.overdueTasks} tugas sudah lewat deadline');
  }
  if (summary.completedToday > 0) {
    facts.add('${summary.completedToday} tugas selesai hari ini');
  }
  if (summary.todayTransactionCount > 0) {
    facts.add(
      '${summary.todayTransactionCount} transaksi hari ini '
      '(${notificationRupiah(summary.todayExpense)})',
    );
  }

  final String activity = facts.isEmpty
      ? 'Belum ada aktivitas baru yang tercatat'
      : 'Catatan aktivitas terbaru: ${facts.join(', ')}';

  switch (intensity) {
    case RoastingIntensity.santai:
      if (facts.isEmpty) {
        return '$activity. Tidak apa-apa; sempatkan satu langkah kecil untuk '
            'menutup hari dengan perasaan lebih tenang.';
      }
      return '$activity. Tetap tenang, pilih satu prioritas kecil, lalu beri '
          'dirimu apresiasi setelah menyelesaikannya.';
    case RoastingIntensity.seimbang:
      if (facts.isEmpty) {
        return '$activity, Dek. Bukan masalah, tapi jangan biarkan hari '
            'berakhir tanpa satu langkah kecil yang bisa kamu banggakan.';
      }
      return '$activity, Dek. Mulai dari satu tugas atau tahan satu '
          'pengeluaran; jangan tunggu semuanya menumpuk.';
    case RoastingIntensity.pedas:
      if (facts.isEmpty) {
        return '$activity, Dek. Bukan mau menuduh, tapi kalender tidak akan '
            'mengerjakan tugasmu sendiri; mulai satu langkah sekarang.';
      }
      return '$activity, Dek. To-do list dan dompet sama-sama butuh perhatian; '
          'berhenti menunda dan bereskan satu hal sekarang.';
  }
}
