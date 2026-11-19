// Parser dan formatter jadwal tugas (tanggal + jam).
//
// Dipakai form tugas dan Brain Dump AI supaya tanggal/jam yang dipilih
// manual, dibaca dari teks, atau dikembalikan Gemini diperlakukan sama.

typedef ClockTime = ({int hour, int minute});

const int defaultDueHour = 23;
const int defaultDueMinute = 59;

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

bool _isValidDate(int year, int month, int day) {
  if (month < 1 || month > 12 || day < 1 || day > 31) {
    return false;
  }
  final DateTime date = DateTime(year, month, day);
  return date.year == year && date.month == month && date.day == day;
}

String _two(int value) => value.toString().padLeft(2, '0');

/// Mengubah jam 12-jam + keterangan (pagi/siang/sore/malam) menjadi jam 24-jam.
int applyDayPeriod(int hour, String? period) {
  switch (period) {
    case 'pagi':
      return hour == 12 ? 0 : hour;
    case 'siang':
      return hour >= 1 && hour <= 6 ? hour + 12 : hour;
    case 'sore':
      return hour < 12 ? hour + 12 : hour;
    case 'malam':
      if (hour == 12) {
        return 0;
      }
      // "jam 1 malam" berarti dini hari, "jam 8 malam" berarti 20:00.
      return hour >= 6 && hour < 12 ? hour + 12 : hour;
    default:
      return hour;
  }
}

ClockTime? _validClock(int hour, int minute) {
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
    return null;
  }
  return (hour: hour, minute: minute);
}

/// Jam sekarang yang dibulatkan ke menit berikutnya. Dipakai sebagai jam
/// default agar tenggat yang baru dibuat tidak langsung dianggap lewat.
ClockTime upcomingClockTime({DateTime? now}) {
  final DateTime upcoming = (now ?? DateTime.now()).add(
    const Duration(minutes: 1),
  );
  return (hour: upcoming.hour, minute: upcoming.minute);
}

/// Tenggat hari ini pada [upcomingClockTime].
DateTime dueAtCurrentTime({DateTime? now}) {
  final DateTime current = now ?? DateTime.now();
  final ClockTime clock = upcomingClockTime(now: current);
  return DateTime(
    current.year,
    current.month,
    current.day,
    clock.hour,
    clock.minute,
  );
}

/// Membaca jam dari teks bebas, contoh: "jam 8 malam", "pukul 07.30",
/// "jam 15:45", atau "08:00". Mengembalikan null jika jam tidak disebut.
ClockTime? parseClockTime(String text) {
  final String lower = text.toLowerCase();

  final RegExpMatch? keyword = RegExp(
    r'\b(?:jam|pukul|pk)\.?\s*(\d{1,2})(?:[:.](\d{2}))?\s*(pagi|siang|sore|malam)?\b',
  ).firstMatch(lower);
  if (keyword != null) {
    final int hour = applyDayPeriod(
      int.parse(keyword.group(1)!),
      keyword.group(3),
    );
    return _validClock(hour, int.tryParse(keyword.group(2) ?? '0') ?? 0);
  }

  final RegExpMatch? colon = RegExp(
    r'\b(\d{1,2}):(\d{2})\s*(pagi|siang|sore|malam)?\b',
  ).firstMatch(lower);
  if (colon != null) {
    final int hour = applyDayPeriod(int.parse(colon.group(1)!), colon.group(3));
    return _validClock(hour, int.parse(colon.group(2)!));
  }
  return null;
}

/// Membaca tanggal (tanpa jam) dari teks bebas. Mendukung "hari ini", "besok",
/// "lusa", "N hari lagi", "minggu depan", "tanggal N (bulan ini)", `d/m/yyyy`
/// dan `yyyy-mm-dd`.
DateTime? parseDueDate(String text, {DateTime? now}) {
  final String lower = text.toLowerCase();
  final DateTime today = _dateOnly(now ?? DateTime.now());

  final RegExpMatch? iso = RegExp(
    r'\b(\d{4})-(\d{1,2})-(\d{1,2})\b',
  ).firstMatch(lower);
  if (iso != null) {
    final int year = int.parse(iso.group(1)!);
    final int month = int.parse(iso.group(2)!);
    final int day = int.parse(iso.group(3)!);
    if (_isValidDate(year, month, day)) {
      return DateTime(year, month, day);
    }
  }

  // Tanda '-' hanya dianggap tanggal jika ada tahun, supaya teks seperti
  // "Quiz bab 4-5" tidak terbaca sebagai 4 Mei.
  final RegExpMatch? numeric = RegExp(
    r'\b(\d{1,2})/(\d{1,2})(?:/(\d{4}))?\b|\b(\d{1,2})-(\d{1,2})-(\d{4})\b',
  ).firstMatch(lower);
  if (numeric != null) {
    final bool slash = numeric.group(1) != null;
    final int day = int.parse(numeric.group(slash ? 1 : 4)!);
    final int month = int.parse(numeric.group(slash ? 2 : 5)!);
    final int year =
        int.tryParse(numeric.group(slash ? 3 : 6) ?? '') ?? today.year;
    if (_isValidDate(year, month, day)) {
      return DateTime(year, month, day);
    }
  }

  final RegExpMatch? dayOfMonth = RegExp(
    r'\btanggal\s+(\d{1,2})(\s+bulan\s+ini)?\b',
  ).firstMatch(lower);
  if (dayOfMonth != null) {
    final int day = int.parse(dayOfMonth.group(1)!);
    final bool explicitThisMonth = dayOfMonth.group(2) != null;
    int month = today.month;
    int year = today.year;
    if (!explicitThisMonth && day < today.day) {
      month += 1;
      if (month > 12) {
        month = 1;
        year += 1;
      }
    }
    if (_isValidDate(year, month, day)) {
      return DateTime(year, month, day);
    }
  }

  if (lower.contains('lusa')) {
    return today.add(const Duration(days: 2));
  }
  if (lower.contains('besok')) {
    return today.add(const Duration(days: 1));
  }
  if (lower.contains('hari ini')) {
    return today;
  }
  final RegExpMatch? daysAhead = RegExp(
    r'\b(\d{1,3})\s*hari\s*lagi\b',
  ).firstMatch(lower);
  if (daysAhead != null) {
    return today.add(Duration(days: int.parse(daysAhead.group(1)!)));
  }
  if (lower.contains('minggu depan')) {
    return today.add(const Duration(days: 7));
  }
  return null;
}

/// Jika tanggal tidak disebut (hanya jam) dan hasilnya sudah lewat, geser ke
/// besok. Tanpa ini, "jam 8 pagi" yang ditulis malam hari langsung terlewat.
DateTime _rollForwardIfPast(DateTime value, DateTime now) {
  if (value.isAfter(now)) {
    return value;
  }
  return DateTime(value.year, value.month, value.day + 1, value.hour, value.minute);
}

/// Gabungan [parseDueDate] dan [parseClockTime]. Jika hanya jam yang disebut,
/// tanggalnya hari ini, atau besok bila jam itu sudah lewat. Jika hanya tanggal
/// yang disebut, jam default dipakai. Null jika keduanya tidak ada di teks.
DateTime? parseSchedule(
  String text, {
  DateTime? now,
  int defaultHour = defaultDueHour,
  int defaultMinute = defaultDueMinute,
  bool useCurrentTimeAsDefault = false,
}) {
  final DateTime current = now ?? DateTime.now();
  final ClockTime fallback = useCurrentTimeAsDefault
      ? upcomingClockTime(now: current)
      : (hour: defaultHour, minute: defaultMinute);
  final DateTime? date = parseDueDate(text, now: current);
  final ClockTime? time = parseClockTime(text);
  if (date == null && time == null) {
    return null;
  }
  final DateTime day = date ?? _dateOnly(current);
  final DateTime result = DateTime(
    day.year,
    day.month,
    day.day,
    time?.hour ?? fallback.hour,
    time?.minute ?? fallback.minute,
  );
  return date == null ? _rollForwardIfPast(result, current) : result;
}

DateTime? _parseIsoDate(String? value) {
  if (value == null) {
    return null;
  }
  final RegExpMatch? match = RegExp(
    r'^\s*(\d{4})-(\d{1,2})-(\d{1,2})',
  ).firstMatch(value);
  if (match == null) {
    return null;
  }
  final int year = int.parse(match.group(1)!);
  final int month = int.parse(match.group(2)!);
  final int day = int.parse(match.group(3)!);
  return _isValidDate(year, month, day) ? DateTime(year, month, day) : null;
}

ClockTime? _parseHm(String? value) {
  if (value == null) {
    return null;
  }
  final RegExpMatch? match = RegExp(
    r'^\s*(\d{1,2}):(\d{2})',
  ).firstMatch(value);
  if (match == null) {
    return null;
  }
  return _validClock(int.parse(match.group(1)!), int.parse(match.group(2)!));
}

/// Menentukan tenggat dari hasil Gemini (`due_date`, `due_time`) dan teks asli.
///
/// Tanggal/jam yang eksplisit di teks pengguna diutamakan karena dihitung
/// deterministik dari jam perangkat (mis. "jam 8 malam" selalu 20:00). Hasil
/// Gemini dipakai untuk ungkapan yang tidak dikenali parser lokal. Jika jam tidak
/// disebut sama sekali, jam default dipakai. Null bila tidak ada info jadwal.
///
/// Tanggal dianggap tersirat jika teks tidak menyebutnya dan Gemini tidak
/// memberi tanggal (atau hanya mengisi hari ini). Jam yang sudah lewat pada
/// tanggal tersirat digeser ke besok, bukan dibiarkan jadi tugas terlewat.
DateTime? resolveAiDueDateTime({
  String? aiDate,
  String? aiTime,
  required String sourceText,
  DateTime? now,
  int defaultHour = defaultDueHour,
  int defaultMinute = defaultDueMinute,
  bool useCurrentTimeAsDefault = false,
}) {
  final DateTime current = now ?? DateTime.now();
  final ClockTime fallback = useCurrentTimeAsDefault
      ? upcomingClockTime(now: current)
      : (hour: defaultHour, minute: defaultMinute);
  final DateTime today = _dateOnly(current);

  DateTime? aiDay = _parseIsoDate(aiDate);
  if (aiDay != null && aiDay.isBefore(today)) {
    // Tanggal lampau hampir pasti salah tafsir (mis. salah tahun).
    aiDay = null;
  }
  final DateTime? textDate = parseDueDate(sourceText, now: current);
  final DateTime? date = textDate ?? aiDay;
  final ClockTime? time = parseClockTime(sourceText) ?? _parseHm(aiTime);

  if (date == null && time == null) {
    return useCurrentTimeAsDefault ? dueAtCurrentTime(now: current) : null;
  }
  final bool impliedDate = textDate == null && (aiDay == null || aiDay == today);
  final DateTime day = date ?? today;
  final DateTime result = DateTime(
    day.year,
    day.month,
    day.day,
    time?.hour ?? fallback.hour,
    time?.minute ?? fallback.minute,
  );
  return impliedDate ? _rollForwardIfPast(result, current) : result;
}

/// Tenggat untuk brain dump: memakai tanggal/jam dari teks atau Gemini. Jika
/// keduanya tidak menyebut, tugas dijadwalkan hari ini pada jam sekarang.
DateTime dueDateForBrainDump({
  String? aiDate,
  String? aiTime,
  required String sourceText,
  DateTime? now,
}) {
  final DateTime current = now ?? DateTime.now();
  return resolveAiDueDateTime(
        aiDate: aiDate,
        aiTime: aiTime,
        sourceText: sourceText,
        now: current,
        useCurrentTimeAsDefault: true,
      ) ??
      dueAtCurrentTime(now: current);
}

/// "Hari ini", "Besok", atau `d/m/yyyy`.
String formatDueDateLabel(DateTime due, {DateTime? now}) {
  final DateTime today = _dateOnly(now ?? DateTime.now());
  final DateTime day = _dateOnly(due);
  final int diff = DateTime.utc(day.year, day.month, day.day)
      .difference(DateTime.utc(today.year, today.month, today.day))
      .inDays;
  if (diff == 0) {
    return 'Hari ini';
  }
  if (diff == 1) {
    return 'Besok';
  }
  return '${day.day}/${day.month}/${day.year}';
}

/// `HH:mm` (24 jam).
String formatDueTimeLabel(DateTime due) => '${_two(due.hour)}:${_two(due.minute)}';

/// Teks tenggat yang disimpan di tugas, contoh: "Besok, 08:00".
String formatDeadline(DateTime due, {DateTime? now}) =>
    '${formatDueDateLabel(due, now: now)}, ${formatDueTimeLabel(due)}';
