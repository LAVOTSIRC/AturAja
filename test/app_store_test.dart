import 'package:flutter_test/flutter_test.dart';

import 'package:bruh/data/app_store.dart';
import 'package:bruh/data/models.dart';
import 'package:bruh/data/settings_controller.dart';
import 'package:bruh/theme/theme_scope.dart';

void main() {
  test('TaskItem serializes and restores all fields', () {
    final TaskItem task = TaskItem(
      id: 42,
      title: 'Uji persistensi tugas',
      categories: const <String>['Tugas Kuliah', 'Pribadi'],
      description: 'Deskripsi tugas',
      deadline: 'Besok, 08:00',
      dueDate: DateTime(2026, 10, 30, 8),
      done: true,
    );

    final TaskItem restored = TaskItem.fromJson(task.toJson());

    expect(restored.id, task.id);
    expect(restored.title, task.title);
    expect(restored.categories, task.categories);
    expect(restored.description, task.description);
    expect(restored.deadline, task.deadline);
    expect(restored.dueDate, task.dueDate);
    expect(restored.done, task.done);
  });

  test('TransactionItem serializes and restores all fields', () {
    const TransactionItem transaction = TransactionItem(
      id: 99,
      label: 'Makan siang',
      amount: -25000,
      cat: 'food',
      time: '12:30',
      date: 'Hari ini',
      consumtive: true,
      receiptImagePath: '/tmp/struk.jpg',
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
        isLoggedIn: false,
      );
      addTearDown(store.dispose);
      await store.load();

      final TaskItem newTask = TaskItem(
        id: 777,
        title: 'Tugas baru yang harus bertahan',
        categories: const <String>['Pribadi'],
        deadline: 'Besok',
        dueDate: DateTime(2026, 11, 1, 9),
      );
      final TransactionItem newTransaction = TransactionItem(
        id: 888,
        label: 'Transaksi uji persistensi',
        amount: -15000,
        cat: 'food',
        time: '10:00',
      );

      store.addTask(newTask);
      transactionStore.insert(0, newTransaction);
      store.transactionsChanged();
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
      store.setLoggedIn(true);
      await store.save();

      final AppProvider restored = AppProvider(
        storage: storage,
        settings: SettingsController(),
        theme: ThemeController(),
        tasks: const <TaskItem>[],
        profile: ProfileData.initial,
        isLoggedIn: false,
      );
      addTearDown(restored.dispose);
      await restored.load();

      expect(
        restored.tasks.where((TaskItem task) => task.id == newTask.id),
        hasLength(1),
      );
      expect(
        restored.tasks.firstWhere((TaskItem task) => task.id == 777).title,
        newTask.title,
      );
      expect(restored.transactions.first.id, newTransaction.id);
      expect(restored.profile.fullName, 'Cristoval Pratama Siahaan');
      expect(restored.profile.nim, '241401999');
      expect(restored.settings.monthlyBudgetLimit, 2500000);
      expect(restored.settings.deadlineNotificationsEnabled, isFalse);
      expect(restored.theme.isDark, isFalse);
      expect(restored.isLoggedIn, isTrue);
    },
  );

  test('AppProvider keeps seeded data when stored JSON is invalid', () async {
    final MemoryAppStorage storage = MemoryAppStorage('bukan-json');
    final AppProvider store = AppProvider(
      storage: storage,
      settings: SettingsController(),
      theme: ThemeController(),
      tasks: sampleTasks,
      profile: ProfileData.initial,
      isLoggedIn: false,
    );
    addTearDown(store.dispose);

    await store.load();

    expect(store.tasks, isNotEmpty);
    expect(store.profile.fullName, ProfileData.initial.fullName);
  });

  test(
    'AppProvider supports task CRUD, nextTaskId, toggle, delete, and getters',
    () {
      final AppProvider store = AppProvider.inMemory(tasks: <TaskItem>[]);
      addTearDown(store.dispose);

      expect(store.nextTaskId, 1);

      final DateTime now = DateTime.now();
      final TaskItem task1 = TaskItem(
        id: store.nextTaskId,
        title: 'Tugas Hari Ini',
        categories: const <String>['Tugas Kuliah'],
        deadline: 'Hari ini, 23:59',
        dueDate: DateTime(now.year, now.month, now.day, 23, 59),
      );
      store.addTask(task1);

      expect(store.tasks.length, 1);
      expect(store.nextTaskId, 2);
      expect(store.todayTasks.length, 1);
      expect(store.todayTaskCount, 1);

      // Toggle task
      store.toggleTask(1);
      expect(store.tasks.first.done, isTrue);
      expect(store.todayTasks.length, 0); // Done tasks excluded from todayTasks

      // Toggle back
      store.toggleTask(1);
      expect(store.tasks.first.done, isFalse);

      // Upsert task (update)
      final TaskItem updatedTask1 = task1.copyWith(
        title: 'Tugas Hari Ini Updated',
      );
      store.upsertTask(updatedTask1);
      expect(store.tasks.length, 1);
      expect(store.tasks.first.title, 'Tugas Hari Ini Updated');

      // Delete task
      store.deleteTask(1);
      expect(store.tasks.length, 0);
      expect(store.todayTasks.length, 0);
    },
  );

  test('AppProvider restores task mutations after reload', () async {
    final MemoryAppStorage storage = MemoryAppStorage();
    final AppProvider store = AppProvider(
      storage: storage,
      settings: SettingsController(),
      theme: ThemeController(),
      tasks: <TaskItem>[],
      profile: ProfileData.initial,
      isLoggedIn: false,
    );
    addTearDown(store.dispose);
    await store.load();

    final TaskItem task = TaskItem(
      id: store.nextTaskId,
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
      isLoggedIn: false,
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
      isLoggedIn: false,
    );
    addTearDown(afterDelete.dispose);
    await afterDelete.load();

    expect(afterDelete.tasks, isEmpty);
  });
}
