import 'dart:async';

import 'package:aturaja/data/cloud_repository.dart';
import 'package:aturaja/data/models.dart';

class FakeCloudRepository implements CloudRepository {
  final Map<String, TaskItem> tasks = <String, TaskItem>{};
  final Map<String, TransactionItem> transactions = <String, TransactionItem>{};
  ProfileData? profile;
  DateTime? lastSyncedAt;
  int schemaVersion = 1;
  int migrateCalls = 0;
  Duration saveAllDelay = const Duration(milliseconds: 900);
  bool initialized = false;
  bool throwOnMigrate = false;

  final StreamController<List<TaskItem>> _tasksController =
      StreamController<List<TaskItem>>.broadcast();
  final StreamController<List<TransactionItem>> _transactionsController =
      StreamController<List<TransactionItem>>.broadcast();
  final StreamController<ProfileData?> _profileController =
      StreamController<ProfileData?>.broadcast();
  final StreamController<CloudMeta> _metaController =
      StreamController<CloudMeta>.broadcast();

  List<TaskItem> get taskList => tasks.values.toList();
  List<TransactionItem> get transactionList => transactions.values.toList();

  @override
  Stream<List<TaskItem>> watchTasks(String userId) async* {
    yield taskList;
    yield* _tasksController.stream;
  }

  @override
  Stream<List<TransactionItem>> watchTransactions(String userId) async* {
    yield transactionList;
    yield* _transactionsController.stream;
  }

  @override
  Stream<ProfileData?> watchProfile(String userId) async* {
    yield profile;
    yield* _profileController.stream;
  }

  @override
  Stream<CloudMeta> watchMeta(String userId) async* {
    yield CloudMeta(lastSyncedAt: lastSyncedAt, schemaVersion: schemaVersion);
    yield* _metaController.stream;
  }

  @override
  Future<bool> migrateLocalIfCloudEmpty(
    String userId, {
    required List<TaskItem> tasks,
    required List<TransactionItem> transactions,
    required ProfileData profile,
  }) async {
    migrateCalls += 1;
    if (throwOnMigrate) {
      throw Exception('Simulasi error jaringan saat migrasi');
    }
    if (initialized || this.profile != null) {
      return false;
    }
    for (final TaskItem task in tasks) {
      this.tasks[task.id] = task;
    }
    for (final TransactionItem item in transactions) {
      this.transactions[item.id] = item;
    }
    this.profile = profile;
    initialized = true;
    lastSyncedAt = DateTime.now();
    return true;
  }

  @override
  Future<void> saveTask(String userId, TaskItem task) async {
    initialized = true;
    tasks[task.id] = task;
    lastSyncedAt = DateTime.now();
    _tasksController.add(taskList);
    _metaController.add(CloudMeta(lastSyncedAt: lastSyncedAt));
  }

  @override
  Future<void> deleteTask(String userId, String taskId) async {
    tasks.remove(taskId);
    lastSyncedAt = DateTime.now();
    _tasksController.add(taskList);
    _metaController.add(CloudMeta(lastSyncedAt: lastSyncedAt));
  }

  @override
  Future<void> saveTransaction(
    String userId,
    TransactionItem transaction,
  ) async {
    initialized = true;
    transactions[transaction.id] = transaction;
    lastSyncedAt = DateTime.now();
    _transactionsController.add(transactionList);
    _metaController.add(CloudMeta(lastSyncedAt: lastSyncedAt));
  }

  @override
  Future<void> deleteTransaction(String userId, String transactionId) async {
    transactions.remove(transactionId);
    lastSyncedAt = DateTime.now();
    _transactionsController.add(transactionList);
    _metaController.add(CloudMeta(lastSyncedAt: lastSyncedAt));
  }

  @override
  Future<void> saveProfile(String userId, ProfileData profile) async {
    initialized = true;
    this.profile = profile;
    lastSyncedAt = DateTime.now();
    _profileController.add(profile);
    _metaController.add(CloudMeta(lastSyncedAt: lastSyncedAt));
  }

  @override
  Future<void> saveAll(
    String userId, {
    required List<TaskItem> tasks,
    required List<TransactionItem> transactions,
    required ProfileData profile,
  }) async {
    await Future<void>.delayed(saveAllDelay);
    this.tasks
      ..clear()
      ..addEntries(tasks.map((TaskItem task) => MapEntry(task.id, task)));
    this.transactions
      ..clear()
      ..addEntries(
        transactions.map((TransactionItem item) => MapEntry(item.id, item)),
      );
    this.profile = profile;
    initialized = true;
    lastSyncedAt = DateTime.now();
    _tasksController.add(taskList);
    _transactionsController.add(transactionList);
    _profileController.add(profile);
    _metaController.add(CloudMeta(lastSyncedAt: lastSyncedAt));
  }

  @override
  Future<void> deleteAllUserData(String userId) async {
    tasks.clear();
    transactions.clear();
    profile = null;
    initialized = false;
    lastSyncedAt = null;
    _tasksController.add(taskList);
    _transactionsController.add(transactionList);
    _profileController.add(null);
    _metaController.add(const CloudMeta());
  }

  void addRemoteTask(TaskItem task) {
    tasks[task.id] = task;
    lastSyncedAt = DateTime.now();
    _tasksController.add(taskList);
    _metaController.add(CloudMeta(lastSyncedAt: lastSyncedAt));
  }

  void addRemoteTransaction(TransactionItem transaction) {
    transactions[transaction.id] = transaction;
    lastSyncedAt = DateTime.now();
    _transactionsController.add(transactionList);
    _metaController.add(CloudMeta(lastSyncedAt: lastSyncedAt));
  }

  Future<void> dispose() async {
    await _tasksController.close();
    await _transactionsController.close();
    await _profileController.close();
    await _metaController.close();
  }
}
