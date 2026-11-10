import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aturaja/data/app_store.dart';
import 'package:aturaja/data/models.dart';
import 'package:aturaja/data/settings_controller.dart';
import 'package:aturaja/theme/theme_scope.dart';

import 'helpers/fake_cloud_repository.dart';

void main() {
  test('TaskItem serializes and restores all fields', () {
    final TaskItem task = TaskItem(
      id: 'task-42',
      title: 'Uji persistensi tugas',
      categories: const <String>['Tugas Kuliah', 'Pribadi'],
      description: 'Deskripsi tugas',
      deadline: 'Besok, 08:00',
      dueDate: DateTime(2026, 10, 30, 8),
      done: true,
      createdAt: DateTime(2026, 10, 20, 9),
      updatedAt: DateTime(2026, 10, 21, 10),
    );

    final TaskItem restored = TaskItem.fromJson(task.toJson());

    expect(restored.id, task.id);
    expect(restored.title, task.title);
    expect(restored.categories, task.categories);
    expect(restored.description, task.description);
    expect(restored.deadline, task.deadline);
    expect(restored.dueDate, task.dueDate);
    expect(restored.done, task.done);
    expect(restored.createdAt, task.createdAt);
    expect(restored.updatedAt, task.updatedAt);
  });

  test('ID angka dari penyimpanan lama menjadi String dan legacyId', () {
    final TaskItem task = TaskItem.fromJson(<String, dynamic>{
      'id': 42,
      'title': 'Tugas lama',
      'categories': <String>['Pribadi'],
      'deadline': 'Besok',
    });
    final TransactionItem transaction = TransactionItem.fromJson(
      <String, dynamic>{
        'id': 99,
        'label': 'Transaksi lama',
        'amount': -1000,
        'cat': 'food',
        'time': '10:00',
      },
    );

    expect(task.id, '42');
    expect(task.legacyId, '42');
    expect(transaction.id, '99');
    expect(transaction.legacyId, '99');
  });

  test('TransactionItem serializes and restores all fields', () {
    final TransactionItem transaction = TransactionItem(
      id: 'tx-99',
      label: 'Makan siang',
      amount: -25000,
      cat: 'food',
      time: '12:30',
      date: 'Hari ini',
      consumtive: true,
      receiptImagePath: '/tmp/struk.jpg',
      createdAt: DateTime(2026, 10, 20, 9),
      updatedAt: DateTime(2026, 10, 21, 10),
    );

    final TransactionItem restored = TransactionItem.fromJson(
      transaction.toJson(),
    );

    expect(restored.id, transaction.id);
    expect(restored.label, transaction.label);
    expect(restored.amount, transaction.amount);
    expect(restored.cat, transaction.cat);
    expect(restored.time, transaction.time);
    expect(restored.date, transaction.date);
    expect(restored.createdAt, transaction.createdAt);
    expect(restored.updatedAt, transaction.updatedAt);
    expect(restored.consumtive, transaction.consumtive);
    expect(restored.receiptImagePath, transaction.receiptImagePath);
  });

  test(
    'AppProvider persists tasks, transactions, profile, settings, and theme',
    () async {
      final MemoryAppStorage storage = MemoryAppStorage();
      final AppProvider store = AppProvider(
        storage: storage,
        settings: SettingsController(),
        theme: ThemeController(),
        tasks: sampleTasks,
        profile: ProfileData.initial,
      );
      addTearDown(store.dispose);
      await store.load();

      final TaskItem newTask = TaskItem(
        id: 'task-777',
        title: 'Tugas baru yang harus bertahan',
        categories: const <String>['Pribadi'],
        deadline: 'Besok',
        dueDate: DateTime(2026, 11, 1, 9),
      );
      final TransactionItem newTransaction = TransactionItem(
        id: 'tx-888',
        label: 'Transaksi uji persistensi',
        amount: -15000,
        cat: 'food',
        time: '10:00',
      );

      store.addTask(newTask);
      store.addTransaction(newTransaction);
      store.updateProfile(
        const ProfileData(
          fullName: 'Cristoval Pratama Siahaan',
          nim: '241401999',
          program: 'Ilmu Komputer',
          avatarLabel: 'CP',
        ),
      );
      store.settings.setMonthlyBudgetLimit(2500000);
      store.settings.setDeadlineNotifications(false);
      store.theme.setDark(false);
      await store.save();

      final AppProvider restored = AppProvider(
        storage: storage,
        settings: SettingsController(),
        theme: ThemeController(),
        tasks: const <TaskItem>[],
        profile: ProfileData.initial,
      );
      addTearDown(restored.dispose);
      await restored.load();

      expect(
        restored.tasks.where((TaskItem task) => task.id == newTask.id),
        hasLength(1),
      );
      expect(
        restored.tasks
            .firstWhere((TaskItem task) => task.id == 'task-777')
            .title,
        newTask.title,
      );
      expect(restored.transactions.first.id, newTransaction.id);
      expect(restored.profile.fullName, 'Cristoval Pratama Siahaan');
      expect(restored.profile.nim, '241401999');
      expect(restored.settings.monthlyBudgetLimit, 2500000);
      expect(restored.settings.deadlineNotificationsEnabled, isFalse);
      expect(restored.theme.isDark, isFalse);
    },
  );

  test('AppProvider persists transaction changes and task deletion', () async {
    final MemoryAppStorage storage = MemoryAppStorage();
    final AppProvider store = AppProvider(
      storage: storage,
      settings: SettingsController(),
      theme: ThemeController(),
      tasks: sampleTasks,
      transactions: const <TransactionItem>[],
      profile: ProfileData.initial,
    );
    addTearDown(store.dispose);
    await store.load();

    final TaskItem deletedTask = store.tasks.first;
    store.deleteTask(deletedTask.id);

    const TransactionItem transaction = TransactionItem(
      id: 'tx-888',
      label: 'Transaksi awal',
      amount: -15000,
      cat: 'food',
      time: '10:00',
    );
    store.addTransaction(transaction);
    store.updateTransaction(
      transaction.copyWith(label: 'Transaksi setelah edit'),
    );
    await store.save();

    final AppProvider restored = AppProvider(
      storage: storage,
      settings: SettingsController(),
      theme: ThemeController(),
      tasks: const <TaskItem>[],
      transactions: const <TransactionItem>[],
      profile: ProfileData.initial,
    );
    addTearDown(restored.dispose);
    await restored.load();

    expect(
      restored.tasks.any((TaskItem task) => task.id == deletedTask.id),
      isFalse,
    );
    expect(restored.transactions.single.label, 'Transaksi setelah edit');

    restored.deleteTransaction(transaction.id);
    expect(restored.transactions, isEmpty);
    restored.restoreTransaction(transaction);
    expect(restored.transactions.single.id, transaction.id);
    await restored.save();

    final AppProvider reloaded = AppProvider(
      storage: storage,
      settings: SettingsController(),
      theme: ThemeController(),
      tasks: const <TaskItem>[],
      transactions: const <TransactionItem>[],
      profile: ProfileData.initial,
    );
    addTearDown(reloaded.dispose);
    await reloaded.load();
    expect(reloaded.transactions.single.id, transaction.id);
  });

  test('AppProvider shows newest transactions first on the home screen', () {
    final AppProvider store = AppProvider.inMemory(
      tasks: const <TaskItem>[],
      transactions: const <TransactionItem>[],
    );
    addTearDown(store.dispose);

    store.addTransaction(
      TransactionItem(
        id: 'older',
        label: 'Beli batagor lama',
        amount: -10000,
        cat: 'food',
        time: '09:00',
        createdAt: DateTime(2026, 11, 10, 9),
      ),
    );
    store.addTransaction(
      TransactionItem(
        id: 'newer',
        label: 'Makan siang terbaru',
        amount: -25000,
        cat: 'food',
        time: '12:00',
        createdAt: DateTime(2026, 11, 10, 12),
      ),
    );

    expect(store.recentTransactions.first.id, 'newer');
    expect(store.recentTransactions.last.id, 'older');
  });

  test('AppProvider keeps seeded data when stored JSON is invalid', () async {
    final MemoryAppStorage storage = MemoryAppStorage('bukan-json');
    final AppProvider store = AppProvider(
      storage: storage,
      settings: SettingsController(),
      theme: ThemeController(),
      tasks: sampleTasks,
      profile: ProfileData.initial,
    );
    addTearDown(store.dispose);

    await store.load();

    expect(store.tasks, isNotEmpty);
    expect(store.profile.fullName, ProfileData.initial.fullName);
  });

  test('AppProvider supports task CRUD, generated IDs, toggle, delete, and getters', () {
    final AppProvider store = AppProvider.inMemory(tasks: <TaskItem>[]);
    addTearDown(store.dispose);

    final String firstId = store.newTaskId;
    final String secondId = store.newTaskId;
    expect(firstId, isNotEmpty);
    expect(secondId, isNotEmpty);
    expect(firstId, isNot(secondId));

    final DateTime now = DateTime.now();
    final TaskItem task1 = TaskItem(
      id: firstId,
      title: 'Tugas Hari Ini',
      categories: const <String>['Tugas Kuliah'],
      deadline: 'Hari ini, 23:59',
      dueDate: DateTime(now.year, now.month, now.day, 23, 59),
    );
    store.addTask(task1);

    expect(store.tasks.length, 1);
    expect(store.todayTasks.length, 1);
    expect(store.todayTaskCount, 1);

    // Toggle task
    store.toggleTask(task1.id);
    expect(store.tasks.first.done, isTrue);
    expect(store.todayTasks.length, 0); // Done tasks excluded from todayTasks

    // Toggle back
    store.toggleTask(task1.id);
    expect(store.tasks.first.done, isFalse);

    // Upsert task (update)
    final TaskItem updatedTask1 = task1.copyWith(
      title: 'Tugas Hari Ini Updated',
    );
    store.upsertTask(updatedTask1);
    expect(store.tasks.length, 1);
    expect(store.tasks.first.title, 'Tugas Hari Ini Updated');

    // Delete task
    store.deleteTask(task1.id);
    expect(store.tasks.length, 0);
    expect(store.todayTasks.length, 0);
  });

  test('AppProvider restores task mutations after reload', () async {
    final MemoryAppStorage storage = MemoryAppStorage();
    final AppProvider store = AppProvider(
      storage: storage,
      settings: SettingsController(),
      theme: ThemeController(),
      tasks: <TaskItem>[],
      profile: ProfileData.initial,
    );
    addTearDown(store.dispose);
    await store.load();

    final TaskItem task = TaskItem(
      id: store.newTaskId,
      title: 'Tugas yang disimpan',
      categories: const <String>['Tugas Kuliah'],
      deadline: 'Besok',
      dueDate: DateTime(2026, 10, 30, 8),
    );
    store.addTask(task);
    store.toggleTask(task.id);
    store.upsertTask(store.tasks.single.copyWith(title: 'Tugas yang diedit'));
    await store.save();

    final AppProvider restored = AppProvider(
      storage: storage,
      settings: SettingsController(),
      theme: ThemeController(),
      tasks: <TaskItem>[],
      profile: ProfileData.initial,
    );
    addTearDown(restored.dispose);
    await restored.load();

    expect(restored.tasks.single.title, 'Tugas yang diedit');
    expect(restored.tasks.single.done, isTrue);
    expect(restored.tasks.single.dueDate, task.dueDate);

    restored.deleteTask(task.id);
    await restored.save();

    final AppProvider afterDelete = AppProvider(
      storage: storage,
      settings: SettingsController(),
      theme: ThemeController(),
      tasks: <TaskItem>[],
      profile: ProfileData.initial,
    );
    addTearDown(afterDelete.dispose);
    await afterDelete.load();

    expect(afterDelete.tasks, isEmpty);
  });

  test('AppProvider memisahkan data lokal per akun Firebase', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final AppProvider store = await AppProvider.loadPersistent(
      userId: 'firebase-uid-a',
    );
    addTearDown(store.dispose);

    expect(store.tasks, isEmpty);
    expect(store.transactions, isEmpty);
    expect(store.profile.fullName, isEmpty);

    final TaskItem taskA = TaskItem(
      id: 'task-101',
      title: 'Tugas akun A',
      categories: const <String>['Pribadi'],
      deadline: 'Besok',
      dueDate: DateTime(2026, 11, 7, 9),
    );
    store.addTask(taskA);
    await store.save();

    await store.switchUser('firebase-uid-b');
    expect(store.tasks, isEmpty);
    expect(store.transactions, isEmpty);

    final TaskItem taskB = TaskItem(
      id: 'task-202',
      title: 'Tugas akun B',
      categories: const <String>['Tugas Kuliah'],
      deadline: 'Lusa',
      dueDate: DateTime(2026, 11, 8, 9),
    );
    store.addTask(taskB);
    await store.save();

    await store.switchUser('firebase-uid-a');
    expect(store.tasks.any((TaskItem task) => task.id == taskA.id), isTrue);
    expect(store.tasks.any((TaskItem task) => task.id == taskB.id), isFalse);
  });

  test('data lama dimigrasikan ke akun pertama yang masuk', () async {
    final TaskItem legacyTask = TaskItem(
      id: 'task-303',
      title: 'Tugas sebelum pemisahan akun',
      categories: const <String>['Pribadi'],
      deadline: 'Besok',
      dueDate: DateTime(2026, 11, 7, 9),
    );
    final String legacyData = jsonEncode(<String, dynamic>{
      'version': 1,
      'tasks': <Map<String, dynamic>>[legacyTask.toJson()],
      'transactions': <Map<String, dynamic>>[],
      'profile': ProfileData.initial.toJson(),
      'settings': <String, dynamic>{},
      'theme': <String, dynamic>{},
    });
    SharedPreferences.setMockInitialValues(<String, Object>{
      SharedPreferencesAppStorage.legacyStorageKey: legacyData,
    });

    final AppProvider store = await AppProvider.loadPersistent(
      userId: 'firebase-uid-migrated',
    );
    addTearDown(store.dispose);

    expect(store.tasks.single.id, legacyTask.id);
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getString(
        SharedPreferencesAppStorage.storageKeyFor('firebase-uid-migrated'),
      ),
      isNotNull,
    );
    expect(
      preferences.getString(SharedPreferencesAppStorage.legacyStorageKey),
      isNull,
    );
  });

  test(
    'data lokal dimigrasikan ke cloud hanya saat cloud masih kosong',
    () async {
      final FakeCloudRepository cloud = FakeCloudRepository();
      addTearDown(cloud.dispose);
      final TaskItem localTask = TaskItem(
        id: 'task-local-cloud',
        title: 'Tugas lokal sebelum cloud',
        categories: const <String>['Pribadi'],
        deadline: 'Besok',
        dueDate: DateTime(2026, 11, 7, 9),
      );

      final AppProvider first = AppProvider(
        storage: MemoryAppStorage(),
        settings: SettingsController(),
        theme: ThemeController(),
        tasks: <TaskItem>[localTask],
        transactions: const <TransactionItem>[],
        profile: ProfileData.initial,
        activeUserId: 'cloud-user',
        cloudRepository: cloud,
      );
      addTearDown(first.dispose);

      await first.connectCloud();
      expect(cloud.migrateCalls, 1);
      expect(cloud.tasks[localTask.id]?.title, localTask.title);
      expect(cloud.profile?.fullName, ProfileData.initial.fullName);
      expect(cloud.lastSyncedAt, isNotNull);

      final TaskItem secondLocal = TaskItem(
        id: 'task-second-device',
        title: 'Tugas dari perangkat kedua',
        categories: const <String>['Pribadi'],
        deadline: 'Lusa',
      );
      final AppProvider second = AppProvider(
        storage: MemoryAppStorage(),
        settings: SettingsController(),
        theme: ThemeController(),
        tasks: <TaskItem>[secondLocal],
        transactions: const <TransactionItem>[],
        profile: ProfileData.empty,
        activeUserId: 'cloud-user',
        cloudRepository: cloud,
      );
      addTearDown(second.dispose);

      await second.connectCloud();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(cloud.migrateCalls, 2);
      expect(cloud.tasks.containsKey(secondLocal.id), isFalse);
      expect(second.tasks.single.id, localTask.id);
    },
  );

  test(
    'perubahan lokal ditulis ke cloud dan snapshot cloud diterapkan',
    () async {
      final FakeCloudRepository cloud = FakeCloudRepository();
      addTearDown(cloud.dispose);
      final AppProvider store = AppProvider(
        storage: MemoryAppStorage(),
        settings: SettingsController(),
        theme: ThemeController(),
        tasks: const <TaskItem>[],
        transactions: const <TransactionItem>[],
        profile: ProfileData.empty,
        activeUserId: 'cloud-user',
        cloudRepository: cloud,
      );
      addTearDown(store.dispose);
      await store.connectCloud();

      final TaskItem task = TaskItem(
        id: 'task-crud',
        title: 'Tugas cloud',
        categories: const <String>['Pribadi'],
        deadline: 'Besok',
      );
      await store.addTask(task);
      expect(cloud.tasks[task.id]?.title, task.title);

      final TaskItem remote = TaskItem(
        id: 'task-remote',
        title: 'Tugas dari cloud',
        categories: const <String>['Pribadi'],
        deadline: 'Hari ini',
      );
      cloud.addRemoteTask(remote);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(store.tasks.any((TaskItem item) => item.id == remote.id), isTrue);

      await store.deleteTask(remote.id);
      expect(cloud.tasks.containsKey(remote.id), isFalse);
    },
  );

  test('sync manual tetap mengunggah saat auto-backup dimatikan', () async {
    final FakeCloudRepository cloud = FakeCloudRepository()
      ..saveAllDelay = Duration.zero;
    addTearDown(cloud.dispose);
    final AppProvider store = AppProvider(
      storage: MemoryAppStorage(),
      settings: SettingsController(),
      theme: ThemeController(),
      tasks: const <TaskItem>[],
      transactions: const <TransactionItem>[],
      profile: ProfileData.empty,
      activeUserId: 'cloud-user',
      cloudRepository: cloud,
    );
    addTearDown(store.dispose);
    await store.connectCloud();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    store.settings.setAutoBackup(false);

    final TaskItem task = TaskItem(
      id: 'task-manual',
      title: 'Tugas manual sync',
      categories: const <String>['Pribadi'],
      deadline: 'Besok',
    );
    await store.addTask(task);
    expect(cloud.tasks.containsKey(task.id), isFalse);

    await store.syncCloudNow();
    expect(cloud.tasks[task.id]?.title, task.title);
    expect(store.lastSyncedAt, isNotNull);
  });

  test('user yang sudah migrasi tetap mendapat stream cloud walau migrasi gagal (skenario offline)', () async {
    const String userId = 'returning-user-offline';
    final String flagKey = 'aturaja_cloud_migrated_$userId';

    SharedPreferences.setMockInitialValues(<String, Object>{
      flagKey: true, // flag migrasi sudah ada dari sesi sebelumnya
    });
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    final FakeCloudRepository cloud = FakeCloudRepository()
      ..throwOnMigrate = true; // simulasi gagal migrasi (mis. offline)
    addTearDown(cloud.dispose);

    // Tambahkan data ke cloud (seolah sudah diisi dari perangkat lain)
    final TaskItem existingTask = TaskItem(
      id: 'task-cloud-existing',
      title: 'Tugas sudah ada di cloud',
      categories: const <String>['Pribadi'],
      deadline: 'Besok',
    );
    cloud.tasks[existingTask.id] = existingTask;
    cloud.initialized = true;

    final AppProvider store = AppProvider(
      storage: MemoryAppStorage(),
      settings: SettingsController(),
      theme: ThemeController(),
      tasks: const <TaskItem>[],
      transactions: const <TransactionItem>[],
      profile: ProfileData.empty,
      preferences: prefs,
      activeUserId: userId,
      cloudRepository: cloud,
    );
    addTearDown(store.dispose);

    await store.connectCloud();
    await Future<void>.delayed(const Duration(milliseconds: 10));

    // Meski migrasi gagal, stream tetap aktif karena previouslyMigrated = true
    // → data cloud (dari cache offline atau fake repo) berhasil diterima
    expect(
      store.tasks.any((TaskItem t) => t.id == existingTask.id),
      isTrue,
      reason: 'Stream harus dipasang walau migrasi gagal untuk returning user',
    );
    // catatan: cloudError bisa sudah dibersihkan oleh meta stream
    expect(cloud.migrateCalls, 1);
  });

  test(
    'user baru tidak mendapat stream cloud saat migrasi gagal offline',
    () async {
      // User baru: tidak ada flag migrasi di SharedPreferences
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      final FakeCloudRepository cloud = FakeCloudRepository()
        ..throwOnMigrate = true; // simulasi error jaringan
      addTearDown(cloud.dispose);

      final AppProvider store = AppProvider(
        storage: MemoryAppStorage(),
        settings: SettingsController(),
        theme: ThemeController(),
        tasks: <TaskItem>[
          TaskItem(
            id: 'task-local-only',
            title: 'Tugas lokal yang harus dipertahankan',
            categories: const <String>['Pribadi'],
            deadline: 'Besok',
          ),
        ],
        transactions: const <TransactionItem>[],
        profile: ProfileData.empty,
        preferences: prefs,
        activeUserId: 'new-user-offline',
        cloudRepository: cloud,
      );
      addTearDown(store.dispose);

      await store.connectCloud();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Data lokal tetap ada (stream tidak dipasang karena user baru)
      expect(
        store.tasks.any((TaskItem t) => t.id == 'task-local-only'),
        isTrue,
      );
      expect(store.cloudError, isNotNull);
    },
  );

  test('migrasi sukses menyimpan flag ke SharedPreferences', () async {
    const String userId = 'user-first-migration';
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    final FakeCloudRepository cloud = FakeCloudRepository();
    addTearDown(cloud.dispose);

    final AppProvider store = AppProvider(
      storage: MemoryAppStorage(),
      settings: SettingsController(),
      theme: ThemeController(),
      tasks: <TaskItem>[
        TaskItem(
          id: 'task-migrate',
          title: 'Tugas yang dimigrasikan',
          categories: const <String>['Pribadi'],
          deadline: 'Besok',
        ),
      ],
      transactions: const <TransactionItem>[],
      profile: ProfileData.initial,
      preferences: prefs,
      activeUserId: userId,
      cloudRepository: cloud,
    );
    addTearDown(store.dispose);

    await store.connectCloud();

    // Flag migrasi harus tersimpan di SharedPreferences
    expect(prefs.getBool('aturaja_cloud_migrated_$userId'), isTrue);
  });

  test('deleteAllUserData menghapus data lokal dan cloud', () async {
    final FakeCloudRepository cloud = FakeCloudRepository();
    addTearDown(cloud.dispose);
    final AppProvider store = AppProvider(
      storage: MemoryAppStorage(),
      settings: SettingsController(),
      theme: ThemeController(),
      tasks: <TaskItem>[
        TaskItem(
          id: 'task-delete-account',
          title: 'Tugas dihapus',
          categories: const <String>['Pribadi'],
          deadline: 'Besok',
        ),
      ],
      transactions: const <TransactionItem>[
        TransactionItem(
          id: 'tx-delete-account',
          label: 'Transaksi dihapus',
          amount: -1000,
          cat: 'other',
          time: '10:00',
        ),
      ],
      profile: ProfileData.initial,
      activeUserId: 'cloud-user',
      cloudRepository: cloud,
    );
    addTearDown(store.dispose);
    await store.connectCloud();
    await Future<void>.delayed(const Duration(milliseconds: 10));

    await store.deleteAllUserData();

    expect(store.tasks, isEmpty);
    expect(store.transactions, isEmpty);
    expect(store.profile.fullName, isEmpty);
    expect(cloud.tasks, isEmpty);
    expect(cloud.transactions, isEmpty);
    expect(cloud.profile, isNull);
    expect(store.lastSyncedAt, isNull);
  });
}
