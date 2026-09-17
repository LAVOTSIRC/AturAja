class TransactionItem {
  final int id;
  final String label;
  final int amount; // negative = expense, positive = income
  final String cat;
  final String time;
  final bool consumtive;

  const TransactionItem({
    required this.id,
    required this.label,
    required this.amount,
    required this.cat,
    required this.time,
    this.consumtive = false,
  });
}

class TaskItem {
  final int id;
  final String title;
  final String sub;
  final String deadline;
  final bool done;
  final bool urgent;

  const TaskItem({
    required this.id,
    required this.title,
    required this.sub,
    required this.deadline,
    this.done = false,
    this.urgent = false,
  });

  TaskItem copyWith({bool? done}) => TaskItem(
        id: id,
        title: title,
        sub: sub,
        deadline: deadline,
        done: done ?? this.done,
        urgent: urgent,
      );
}

const List<TransactionItem> sampleTransactions = [
  TransactionItem(
    id: 1,
    label: 'Batagor depan kampus',
    amount: -15000,
    cat: 'food',
    time: '10:42',
  ),
  TransactionItem(
    id: 2,
    label: 'Spotify Premium',
    amount: -54990,
    cat: 'entertainment',
    time: '09:00',
    consumtive: true,
  ),
  TransactionItem(
    id: 3,
    label: 'Kiriman Orang Tua',
    amount: 500000,
    cat: 'income',
    time: '08:30',
  ),
  TransactionItem(
    id: 4,
    label: 'Grab Food',
    amount: -45000,
    cat: 'food',
    time: '13:15',
    consumtive: true,
  ),
  TransactionItem(
    id: 5,
    label: 'Kopi Kenangan',
    amount: -29000,
    cat: 'entertainment',
    time: '07:50',
    consumtive: true,
  ),
];

const List<TaskItem> sampleTasks = [
  TaskItem(
    id: 1,
    title: 'Laporan Praktikum Algoritma',
    sub: 'Algoritma & Pemrograman',
    deadline: 'Hari ini, 23:59',
    urgent: true,
  ),
  TaskItem(
    id: 2,
    title: 'Quiz Chapter 3 Kalkulus',
    sub: 'Matematika Diskrit',
    deadline: 'Besok, 08:00',
    urgent: true,
  ),
  TaskItem(
    id: 3,
    title: 'Baca Materi Sistem Operasi',
    sub: 'Sistem Operasi',
    deadline: '3 hari lagi',
  ),
  TaskItem(
    id: 4,
    title: 'Kumpulkan Form KRS',
    sub: 'Akademik',
    deadline: 'Selesai',
    done: true,
  ),
  TaskItem(
    id: 5,
    title: 'Riset Topik Skripsi',
    sub: 'Skripsi',
    deadline: 'Minggu depan',
  ),
];
