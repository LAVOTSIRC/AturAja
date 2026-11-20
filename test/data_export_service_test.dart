import 'dart:convert';
import 'dart:io';

import 'package:aturaja/data/models.dart';
import 'package:aturaja/services/data_export_service.dart';
import 'package:flutter_test/flutter_test.dart';

TaskItem taskWithDeadline({
  required String id,
  DateTime? dueDate,
  bool done = false,
}) {
  return TaskItem(
    id: id,
    title: 'Tugas $id',
    deadline: 'Hari ini',
    dueDate: dueDate,
    done: done,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DataExportService', () {
    test('writes sanitized JSON and CSV files', () async {
      final Directory directory = await Directory.systemTemp.createTemp(
        'aturaja_export_test_',
      );
      addTearDown(() async {
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });

      final DataExportService service = DataExportService();
      final DataExportResult result = await service.exportAndShare(
        tasks: <TaskItem>[
          taskWithDeadline(id: 'task-1', dueDate: DateTime(2026, 11, 13, 9)),
        ],
        transactions: const <TransactionItem>[
          TransactionItem(
            id: 'tx-1',
            label: 'Kopi "enak"',
            amount: -25000,
            cat: 'food',
            time: '10:00',
            receiptImagePath: '/private/receipt.jpg',
          ),
        ],
        profile: const ProfileData(
          fullName: 'Christein',
          nim: '241401999',
          program: 'Ilmu Komputer',
          avatarLabel: 'CH',
        ),
      );

      expect(result.files, hasLength(3));
      expect(result.files.every((File file) => file.existsSync()), isTrue);

      final Map<String, dynamic> json = jsonDecode(
        await result.files[0].readAsString(),
      ) as Map<String, dynamic>;
      final List<dynamic> transactions = json['transactions'] as List<dynamic>;
      final Map<String, dynamic> transaction =
          transactions.single as Map<String, dynamic>;
      expect(transaction['has_receipt'], isTrue);
      expect(transaction.containsKey('receiptImagePath'), isFalse);

      final String tasksCsv = await result.files[1].readAsString();
      expect(tasksCsv, contains('task-1'));
      expect(tasksCsv, contains('Tugas task-1'));

      final String transactionsCsv = await result.files[2].readAsString();
      expect(transactionsCsv, contains('"Kopi ""enak"""'));
      expect(transactionsCsv, isNot(contains('/private/receipt.jpg')));
    });
  });
}
