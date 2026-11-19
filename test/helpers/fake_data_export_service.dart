import 'dart:io';

import 'package:aturaja/data/models.dart';
import 'package:aturaja/services/data_export_service.dart';

/// Ekspor in-memory untuk widget test agar tidak bergantung pada file I/O dan
/// share sheet platform.
class FakeDataExportService extends DataExportService {
  int exportCalls = 0;

  @override
  Future<DataExportResult> exportAndShare({
    required List<TaskItem> tasks,
    required List<TransactionItem> transactions,
    required ProfileData profile,
  }) async {
    exportCalls++;
    return const DataExportResult(
      files: <File>[],
      folderPath: '/tmp/aturaja_exports',
      shared: false,
    );
  }
}
