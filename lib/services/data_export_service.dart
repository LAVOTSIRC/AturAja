import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/models.dart';

class DataExportResult {
  final List<File> files;
  final String folderPath;
  final bool shared;

  const DataExportResult({
    required this.files,
    required this.folderPath,
    required this.shared,
  });
}

/// Membuat salinan data pengguna dalam format JSON dan CSV, lalu membuka
/// share sheet perangkat. Data sensitif seperti token, password, dan path
/// internal foto struk tidak disertakan.
class DataExportService {
  Future<DataExportResult> exportAndShare({
    required List<TaskItem> tasks,
    required List<TransactionItem> transactions,
    required ProfileData profile,
  }) async {
    final Directory directory = await _exportDirectory();
    final String timestamp = _timestamp(DateTime.now());
    final String prefix = 'aturaja_export_$timestamp';

    final File jsonFile = File('${directory.path}/$prefix.json');
    final File tasksCsv = File('${directory.path}/${prefix}_tasks.csv');
    final File transactionsCsv = File(
      '${directory.path}/${prefix}_transactions.csv',
    );

    await jsonFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
        'exported_at': DateTime.now().toIso8601String(),
        'profile': profile.toJson(),
        'tasks': tasks.map(_taskJson).toList(),
        'transactions': transactions.map(_transactionJson).toList(),
      }),
      flush: true,
    );
    await tasksCsv.writeAsString(_tasksCsv(tasks), flush: true);
    await transactionsCsv.writeAsString(
      _transactionsCsv(transactions),
      flush: true,
    );

    final List<File> files = <File>[jsonFile, tasksCsv, transactionsCsv];
    bool shared = false;
    try {
      await SharePlus.instance.share(
        ShareParams(
          subject: 'Ekspor data AturAja',
          text: 'Salinan data AturAja dalam format JSON dan CSV.',
          files: files
              .map(
                (File file) => XFile(
                  file.path,
                  mimeType: file.path.endsWith('.json')
                      ? 'application/json'
                      : 'text/csv',
                ),
              )
              .toList(),
        ),
      );
      shared = true;
    } catch (error) {
      debugPrint('Share sheet tidak tersedia: $error');
    }

    return DataExportResult(
      files: files,
      folderPath: directory.path,
      shared: shared,
    );
  }

  Future<Directory> _exportDirectory() async {
    try {
      final Directory directory = await getTemporaryDirectory();
      return Directory(
        '${directory.path}${Platform.pathSeparator}aturaja_exports',
      )..createSync(recursive: true);
    } catch (error) {
      debugPrint('Direktori sementara tidak tersedia: $error');
      return Directory.systemTemp.createTempSync('aturaja_exports_');
    }
  }

  static Map<String, dynamic> _taskJson(TaskItem task) => <String, dynamic>{
    'id': task.id,
    'title': task.title,
    'categories': task.categories,
    'description': task.description,
    'deadline': task.deadline,
    'due_date': task.dueDate?.toIso8601String(),
    'done': task.done,
    'created_at': task.createdAt?.toIso8601String(),
    'updated_at': task.updatedAt?.toIso8601String(),
  };

  static Map<String, dynamic> _transactionJson(TransactionItem transaction) =>
      <String, dynamic>{
        'id': transaction.id,
        'label': transaction.label,
        'amount': transaction.amount,
        'category': transaction.cat,
        'time': transaction.time,
        'date': transaction.date,
        'consumtive': transaction.consumtive,
        'has_receipt': transaction.receiptImagePath != null,
        'created_at': transaction.createdAt?.toIso8601String(),
        'updated_at': transaction.updatedAt?.toIso8601String(),
      };

  static String _tasksCsv(List<TaskItem> tasks) {
    final StringBuffer buffer = StringBuffer('\uFEFF');
    buffer.write(
      'id,title,categories,description,deadline,due_date,done,created_at,updated_at\r\n',
    );
    for (final TaskItem task in tasks) {
      final String row = <String>[
        task.id,
        task.title,
        task.categories.join('|'),
        task.description,
        task.deadline,
        task.dueDate?.toIso8601String() ?? '',
        task.done ? 'true' : 'false',
        task.createdAt?.toIso8601String() ?? '',
        task.updatedAt?.toIso8601String() ?? '',
      ].map(_csvCell).join(',');
      buffer.write('$row\r\n');
    }
    return buffer.toString();
  }

  static String _transactionsCsv(List<TransactionItem> transactions) {
    final StringBuffer buffer = StringBuffer('\uFEFF');
    buffer.write(
      'id,label,amount,category,time,date,consumtive,has_receipt,created_at,updated_at\r\n',
    );
    for (final TransactionItem transaction in transactions) {
      final String row = <String>[
        transaction.id,
        transaction.label,
        transaction.amount.toString(),
        transaction.cat,
        transaction.time,
        transaction.date,
        transaction.consumtive ? 'true' : 'false',
        transaction.receiptImagePath != null ? 'true' : 'false',
        transaction.createdAt?.toIso8601String() ?? '',
        transaction.updatedAt?.toIso8601String() ?? '',
      ].map(_csvCell).join(',');
      buffer.write('$row\r\n');
    }
    return buffer.toString();
  }

  static String _csvCell(String value) => '"${value.replaceAll('"', '""')}"';

  static String _timestamp(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${value.year}${two(value.month)}${two(value.day)}_'
        '${two(value.hour)}${two(value.minute)}${two(value.second)}';
  }
}
