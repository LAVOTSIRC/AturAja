import 'models.dart';

class CloudMeta {
  final DateTime? lastSyncedAt;
  final int schemaVersion;
  final bool hasPendingWrites;

  const CloudMeta({
    this.lastSyncedAt,
    this.schemaVersion = 1,
    this.hasPendingWrites = false,
  });
}

abstract class CloudRepository {
  Stream<List<TaskItem>> watchTasks(String userId);

  Stream<List<TransactionItem>> watchTransactions(String userId);

  Stream<ProfileData?> watchProfile(String userId);

  Stream<CloudMeta> watchMeta(String userId);

  Future<bool> migrateLocalIfCloudEmpty(
    String userId, {
    required List<TaskItem> tasks,
    required List<TransactionItem> transactions,
    required ProfileData profile,
  });

  Future<void> saveTask(String userId, TaskItem task);

  Future<void> deleteTask(String userId, String taskId);

  Future<void> saveTransaction(String userId, TransactionItem transaction);

  Future<void> deleteTransaction(String userId, String transactionId);

  Future<void> saveProfile(String userId, ProfileData profile);

  Future<void> saveAll(
    String userId, {
    required List<TaskItem> tasks,
    required List<TransactionItem> transactions,
    required ProfileData profile,
  });

  Future<void> deleteAllUserData(String userId);
}
