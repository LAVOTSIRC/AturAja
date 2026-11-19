import 'package:flutter_test/flutter_test.dart';

import 'package:aturaja/utils/task_schedule.dart';

void main() {
  // Kamis, 19 November 2026 pukul 14:00.
  final DateTime now = DateTime(2026, 11, 19, 14, 0);

  group('parseClockTime', () {
    test('mengonversi keterangan pagi/siang/sore/malam ke 24 jam', () {
      expect(parseClockTime('kerjakan jam 6 pagi'), (hour: 6, minute: 0));
      expect(parseClockTime('jam 12 siang'), (hour: 12, minute: 0));
      expect(parseClockTime('jam 1 siang'), (hour: 13, minute: 0));
      expect(parseClockTime('jam 3 sore'), (hour: 15, minute: 0));
      expect(parseClockTime('jam 8 malam'), (hour: 20, minute: 0));
      expect(parseClockTime('jam 11 malam'), (hour: 23, minute: 0));
      expect(parseClockTime('jam 12 malam'), (hour: 0, minute: 0));
      expect(parseClockTime('jam 1 malam'), (hour: 1, minute: 0));
    });

    test('membaca menit dan format pukul/titik/titik dua', () {
      expect(parseClockTime('pukul 07.30'), (hour: 7, minute: 30));
      expect(parseClockTime('jam 15:45'), (hour: 15, minute: 45));
      expect(parseClockTime('Besok, 08:00'), (hour: 8, minute: 0));
      expect(parseClockTime('jam 7:30 malam'), (hour: 19, minute: 30));
      expect(parseClockTime('jam 8'), (hour: 8, minute: 0));
    });

    test('mengembalikan null jika jam tidak ada atau tidak valid', () {
      expect(parseClockTime('besok kerjakan tugas'), isNull);
      expect(parseClockTime('jam 25'), isNull);
      expect(parseClockTime('jam 8:75'), isNull);
    });
  });

  group('parseDueDate', () {
    test('mengenali tanggal relatif', () {
      expect(parseDueDate('hari ini', now: now), DateTime(2026, 11, 19));
      expect(parseDueDate('Besok jam 8', now: now), DateTime(2026, 11, 20));
      expect(parseDueDate('lusa', now: now), DateTime(2026, 11, 21));
      expect(parseDueDate('3 hari lagi', now: now), DateTime(2026, 11, 22));
      expect(parseDueDate('minggu depan', now: now), DateTime(2026, 11, 26));
    });

    test('mengenali tanggal eksplisit', () {
      expect(
        parseDueDate('tanggal 25 bulan ini', now: now),
        DateTime(2026, 11, 25),
      );
      expect(parseDueDate('20/12/2026', now: now), DateTime(2026, 12, 20));
      expect(parseDueDate('2026-12-01, 08:00', now: now), DateTime(2026, 12, 1));
      expect(parseDueDate('25-12-2026', now: now), DateTime(2026, 12, 25));
    });

    test('tanggal yang sudah lewat tanpa "bulan ini" menjadi bulan depan', () {
      expect(parseDueDate('tanggal 10', now: now), DateTime(2026, 12, 10));
      expect(parseDueDate('tanggal 10 bulan ini', now: now),
          DateTime(2026, 11, 10));
    });

    test('mengabaikan angka yang bukan tanggal', () {
      expect(parseDueDate('Quiz bab 4-5', now: now), isNull);
      expect(parseDueDate('tanggal 31 bulan ini', now: now), isNull);
      expect(parseDueDate('tanpa tanggal', now: now), isNull);
    });
  });

  group('parseSchedule', () {
    test('menggabungkan tanggal dan jam', () {
      expect(
        parseSchedule('Besok jam 8 malam kerjakan laporan', now: now),
        DateTime(2026, 11, 20, 20, 0),
      );
      expect(
        parseSchedule('Jogging 5km lusa jam 16:30', now: now),
        DateTime(2026, 11, 21, 16, 30),
      );
    });

    test('hanya jam berarti hari ini, hanya tanggal berarti jam default', () {
      expect(
        parseSchedule('rapat jam 7 malam', now: now),
        DateTime(2026, 11, 19, 19, 0),
      );
      expect(parseSchedule('kumpulkan besok', now: now),
          DateTime(2026, 11, 20, 23, 59));
      expect(
        parseSchedule(
          'kumpulkan besok',
          now: now,
          defaultHour: 8,
          defaultMinute: 15,
        ),
        DateTime(2026, 11, 20, 8, 15),
      );
    });

    test('jam tanpa tanggal yang sudah lewat menjadi besok', () {
      expect(
        parseSchedule('jogging jam 6 pagi', now: now),
        DateTime(2026, 11, 20, 6, 0),
      );
      expect(
        parseSchedule('hari ini jam 6 pagi', now: now),
        DateTime(2026, 11, 19, 6, 0),
      );
    });

    test('null jika teks tidak memuat jadwal', () {
      expect(parseSchedule('beli makan siang', now: now), isNull);
    });

    test('jam default bisa diganti jam sekarang', () {
      expect(
        parseSchedule('kumpulkan besok', now: now, useCurrentTimeAsDefault: true),
        DateTime(2026, 11, 20, 14, 1),
      );
      expect(
        parseSchedule('beli sabun', now: now, useCurrentTimeAsDefault: true),
        isNull,
      );
    });
  });

  group('resolveAiDueDateTime', () {
    test('memakai tanggal dan jam dari Gemini jika teks tidak menyebutnya', () {
      expect(
        resolveAiDueDateTime(
          aiDate: '2026-11-25',
          aiTime: '09:15',
          sourceText: 'presentasi proposal skripsi',
          now: now,
        ),
        DateTime(2026, 11, 25, 9, 15),
      );
    });

    test('jam eksplisit di teks mengalahkan jam Gemini yang salah AM/PM', () {
      expect(
        resolveAiDueDateTime(
          aiDate: '2026-11-20',
          aiTime: '08:00',
          sourceText: 'besok jam 8 malam rapat BEM',
          now: now,
        ),
        DateTime(2026, 11, 20, 20, 0),
      );
    });

    test('jam Gemini tetap dipakai untuk ungkapan yang tidak dikenali', () {
      expect(
        resolveAiDueDateTime(
          aiDate: '2026-11-20',
          aiTime: '19:30',
          sourceText: 'besok setengah 8 malam rapat',
          now: now,
        ),
        DateTime(2026, 11, 20, 19, 30),
      );
    });

    test('format jam dengan detik dari Gemini tetap terbaca', () {
      expect(
        resolveAiDueDateTime(
          aiDate: '2026-11-22',
          aiTime: '08:00:00',
          sourceText: 'senin depan kuis',
          now: now,
        ),
        DateTime(2026, 11, 22, 8, 0),
      );
    });

    test('tanggal Gemini tanpa jam memakai jam default', () {
      expect(
        resolveAiDueDateTime(
          aiDate: '2026-11-25',
          sourceText: 'kumpul laporan',
          now: now,
        ),
        DateTime(2026, 11, 25, 23, 59),
      );
    });

    test('jam Gemini tanpa tanggal memakai hari ini', () {
      expect(
        resolveAiDueDateTime(
          aiTime: '18:00',
          sourceText: 'ambil laundry',
          now: now,
        ),
        DateTime(2026, 11, 19, 18, 0),
      );
    });

    test('tanggal lampau dari Gemini diabaikan', () {
      expect(
        resolveAiDueDateTime(
          aiDate: '2024-01-05',
          aiTime: '17:00',
          sourceText: 'ambil laundry',
          now: now,
        ),
        DateTime(2026, 11, 19, 17, 0),
      );
    });

    test('jam yang sudah lewat tanpa tanggal digeser ke besok', () {
      // Sekarang 14:00; jam 08:00 hari ini sudah lewat.
      expect(
        resolveAiDueDateTime(
          aiTime: '08:00',
          sourceText: 'kerjakan laporan jam 8 pagi',
          now: now,
        ),
        DateTime(2026, 11, 20, 8, 0),
      );
      // Gemini yang hanya mengisi tanggal hari ini juga dianggap tersirat.
      expect(
        resolveAiDueDateTime(
          aiDate: '2026-11-19',
          aiTime: '08:00',
          sourceText: 'kerjakan laporan',
          now: now,
        ),
        DateTime(2026, 11, 20, 8, 0),
      );
    });

    test('tanggal yang disebut eksplisit tidak digeser', () {
      expect(
        resolveAiDueDateTime(
          aiDate: '2026-11-19',
          aiTime: '08:00',
          sourceText: 'hari ini jam 8 pagi',
          now: now,
        ),
        DateTime(2026, 11, 19, 8, 0),
      );
    });

    test('null jika tidak ada informasi jadwal sama sekali', () {
      expect(
        resolveAiDueDateTime(sourceText: 'beli sabun', now: now),
        isNull,
      );
    });

    test('jadwal tanpa tanggal/jam memakai hari ini pada jam sekarang', () {
      expect(
        resolveAiDueDateTime(
          sourceText: 'beli sabun',
          now: now,
          useCurrentTimeAsDefault: true,
        ),
        DateTime(2026, 11, 19, 14, 1),
      );
    });
  });

  group('dueDateForBrainDump', () {
    test('tugas tanpa jadwal dijadwalkan hari ini pada jam sekarang', () {
      expect(
        dueDateForBrainDump(sourceText: 'kerjakan laporan', now: now),
        DateTime(2026, 11, 19, 14, 1),
      );
    });

    test('memakai tanggal dan jam yang disebut di teks', () {
      expect(
        dueDateForBrainDump(sourceText: 'besok jam 7 malam rapat', now: now),
        DateTime(2026, 11, 20, 19, 0),
      );
    });

    test('memakai tanggal dan jam dari Gemini', () {
      expect(
        dueDateForBrainDump(
          aiDate: '2026-11-25',
          aiTime: '09:15',
          sourceText: 'presentasi proposal',
          now: now,
        ),
        DateTime(2026, 11, 25, 9, 15),
      );
    });
  });

  group('format deadline', () {
    test('memakai Hari ini, Besok, atau tanggal numerik', () {
      expect(
        formatDeadline(DateTime(2026, 11, 19, 8, 5), now: now),
        'Hari ini, 08:05',
      );
      expect(
        formatDeadline(DateTime(2026, 11, 20, 20, 0), now: now),
        'Besok, 20:00',
      );
      expect(
        formatDeadline(DateTime(2026, 11, 25, 23, 59), now: now),
        '25/11/2026, 23:59',
      );
    });

    test('hasil format bisa dibaca kembali tanpa kehilangan jam', () {
      for (final DateTime due in <DateTime>[
        DateTime(2026, 11, 19, 8, 5),
        DateTime(2026, 11, 20, 20, 0),
        DateTime(2026, 12, 31, 0, 0),
        DateTime(2027, 1, 2, 23, 59),
      ]) {
        expect(parseSchedule(formatDeadline(due, now: now), now: now), due);
      }
    });
  });
}
