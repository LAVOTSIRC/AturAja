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
    'AppStore persists tasks, transactions, profile, settings, and theme',
    () async {
      final MemoryAppStorage storage = MemoryAppStorage();
      final AppStore store = AppStore(
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

      final AppStore restored = AppStore(
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

  test('AppStore keeps seeded data when stored JSON is invalid', () async {
    final MemoryAppStorage storage = MemoryAppStorage('bukan-json');
    final AppStore store = AppStore(
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
}
