import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/app_storage.dart';
import '../data/models.dart';
import 'settings_provider.dart';
import 'theme_provider.dart';

class AppProvider extends ChangeNotifier {
  AppStorage storage;
  final SettingsController settings;
  final ThemeController theme;

  final SharedPreferences? preferences;
  String? activeUserId;
  Future<void> _switchChain = Future<void>.value();

  List<TaskItem> tasks;
  List<TransactionItem> _transactions;
  ProfileData profile;

  bool _isLoading = false;
  Future<void> _saveChain = Future<void>.value();

  AppProvider({
    required this.storage,
    required this.settings,
    required this.theme,
    required List<TaskItem> tasks,
    List<TransactionItem>? transactions,
    required this.profile,
    this.preferences,
    this.activeUserId,
  }) : tasks = List<TaskItem>.of(tasks),
       _transactions = List<TransactionItem>.of(
         transactions ?? sampleTransactions,
       ) {
    settings.addListener(_onDependencyChanged);
    theme.addListener(_onDependencyChanged);
  }

  factory AppProvider.inMemory({
    List<TaskItem>? tasks,
    List<TransactionItem>? transactions,
    ProfileData? profile,
  }) {
    return AppProvider(
      storage: MemoryAppStorage(),
      settings: SettingsController(),
      theme: ThemeController(),
      tasks: tasks ?? sampleTasks,
      transactions: transactions,
      profile: profile ?? ProfileData.initial,
    );
  }

  /// Memuat data milik akun Firebase aktif.
  ///
  /// Akun yang belum punya data akan dimulai dari state kosong. Data lama dari
  /// versi sebelum pemisahan akun dimigrasikan ke akun pertama yang masuk.
  static Future<AppProvider> loadPersistent({String? userId}) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    if (userId != null) {
      await _migrateLegacyData(preferences, userId);
    }
    final bool isGuest = userId == null || userId.trim().isEmpty;
    final AppProvider provider = AppProvider(
      storage: SharedPreferencesAppStorage(preferences, userId: userId),
      settings: SettingsController(),
      theme: ThemeController(),
      tasks: isGuest ? sampleTasks : const <TaskItem>[],
      transactions: isGuest ? sampleTransactions : const <TransactionItem>[],
      profile: isGuest ? ProfileData.initial : ProfileData.empty,
      preferences: preferences,
      activeUserId: userId,
    );
    await provider.load();
    return provider;
  }

  /// Berganti penyimpanan saat akun Firebase berubah.
  Future<void> switchUser(String? userId) {
    _switchChain = _switchChain.then((_) => _switchUser(userId));
    return _switchChain;
  }

  Future<void> _switchUser(String? userId) async {
    if (activeUserId == userId) {
      return;
    }
    final SharedPreferences? prefs = preferences;
    if (prefs == null) {
      return;
    }

    // Simpan dulu data akun sebelumnya sebelum mengganti key penyimpanan.
    await save();
    if (userId != null) {
      await _migrateLegacyData(prefs, userId);
    }

    activeUserId = userId;
    storage = SharedPreferencesAppStorage(prefs, userId: userId);
    _isLoading = true;
    _resetState(seedSampleData: userId == null || userId.trim().isEmpty);
    notifyListeners();
    await load();
  }

  static Future<void> _migrateLegacyData(
    SharedPreferences prefs,
    String userId,
  ) async {
    final String userKey = SharedPreferencesAppStorage.storageKeyFor(userId);
    if (prefs.containsKey(userKey)) {
      return;
    }
    final String? legacy = prefs.getString(
      SharedPreferencesAppStorage.legacyStorageKey,
    );
    if (legacy == null || legacy.trim().isEmpty) {
      return;
    }
    await prefs.setString(userKey, legacy);
    await prefs.remove(SharedPreferencesAppStorage.legacyStorageKey);
  }

  void _resetState({required bool seedSampleData}) {
    tasks = seedSampleData ? List<TaskItem>.of(sampleTasks) : <TaskItem>[];
    _transactions = seedSampleData
        ? List<TransactionItem>.of(sampleTransactions)
        : <TransactionItem>[];
    profile = seedSampleData ? ProfileData.initial : ProfileData.empty;
    settings.resetToDefaults();
    theme.resetToDefaults();
  }

  List<TransactionItem> get transactions =>
      List<TransactionItem>.unmodifiable(_transactions);

  List<TransactionItem> get recentTransactions =>
      _transactions.take(4).toList();

  int get totalIncome => _transactions
      .where((TransactionItem item) => item.amount > 0)
      .fold(0, (int sum, TransactionItem item) => sum + item.amount);

  int get totalExpense => _transactions
      .where((TransactionItem item) => item.amount < 0)
      .fold(0, (int sum, TransactionItem item) => sum + item.amount.abs());

  int get balance => totalIncome - totalExpense;

  int get budgetLimit => settings.monthlyBudgetLimit;

  int get pendingTaskCount => tasks.where((TaskItem task) => !task.done).length;

  int get urgentTaskCount =>
      tasks.where((TaskItem task) => task.urgent && !task.done).length;

  List<TaskItem> get urgentTasks =>
      tasks.where((TaskItem task) => task.urgent && !task.done).toList();

  List<TaskItem> get todayTasks => tasks.where((TaskItem task) {
    if (task.done) return false;
    if (task.dueDate != null) {
      final DateTime now = DateTime.now();
      return task.dueDate!.year == now.year &&
          task.dueDate!.month == now.month &&
          task.dueDate!.day == now.day;
    }
    final String lower = task.deadline.toLowerCase();
    return lower.contains('hari ini');
  }).toList();

  int get todayTaskCount => todayTasks.length;

  int get nextTaskId {
    if (tasks.isEmpty) return 1;
    return tasks
            .map((TaskItem t) => t.id)
            .reduce((int a, int b) => a > b ? a : b) +
        1;
  }

  Future<void> load() async {
    _isLoading = true;
    try {
      final String? raw = await storage.read();
      if (raw == null || raw.trim().isEmpty) {
        _isLoading = false;
        await save();
        return;
      }

      final dynamic decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return;
      }
      final Map<String, dynamic> data = Map<String, dynamic>.from(decoded);

      final dynamic rawTasks = data['tasks'];
      if (rawTasks is List) {
        tasks = rawTasks
            .whereType<Map>()
            .map(
              (Map item) => TaskItem.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList();
      }

      final dynamic rawTransactions = data['transactions'];
      if (rawTransactions is List) {
        _transactions = rawTransactions
            .whereType<Map>()
            .map(
              (Map item) =>
                  TransactionItem.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList();
      }

      final dynamic rawProfile = data['profile'];
      if (rawProfile is Map) {
        profile = ProfileData.fromJson(Map<String, dynamic>.from(rawProfile));
      }

      final dynamic rawSettings = data['settings'];
      if (rawSettings is Map) {
        settings.applyJson(Map<String, dynamic>.from(rawSettings));
      }

      final dynamic rawTheme = data['theme'];
      if (rawTheme is Map) {
        theme.applyJson(Map<String, dynamic>.from(rawTheme));
      }
    } catch (error) {
      debugPrint('Gagal memuat data AturAja: $error');
    } finally {
      _isLoading = false;
    }
    notifyListeners();
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'version': 1,
    'tasks': tasks.map((TaskItem task) => task.toJson()).toList(),
    'transactions': _transactions
        .map((TransactionItem transaction) => transaction.toJson())
        .toList(),
    'profile': profile.toJson(),
    'settings': settings.toJson(),
    'theme': theme.toJson(),
  };

  Future<void> save() {
    if (_isLoading) {
      return Future<void>.value();
    }
    _saveChain = _saveChain.then((_) async {
      try {
        await storage.write(jsonEncode(toJson()));
      } catch (error) {
        debugPrint('Gagal menyimpan data AturAja: $error');
      }
    });
    return _saveChain;
  }

  void addTask(TaskItem task) {
    tasks = <TaskItem>[...tasks, task];
    _changed();
  }

  void upsertTask(TaskItem task) {
    final int index = tasks.indexWhere((TaskItem item) => item.id == task.id);
    if (index < 0) {
      addTask(task);
      return;
    }
    final List<TaskItem> next = List<TaskItem>.of(tasks);
    next[index] = task;
    tasks = next;
    _changed();
  }

  void toggleTask(int id) {
    tasks = tasks
        .map(
          (TaskItem task) =>
              task.id == id ? task.copyWith(done: !task.done) : task,
        )
        .toList();
    _changed();
  }

  void deleteTask(int id) {
    tasks = tasks.where((TaskItem task) => task.id != id).toList();
    _changed();
  }

  void addTransaction(TransactionItem transaction) {
    _transactions = <TransactionItem>[transaction, ..._transactions];
    _changed();
  }

  void updateTransaction(TransactionItem transaction) {
    final int index = _transactions.indexWhere(
      (TransactionItem item) => item.id == transaction.id,
    );
    if (index < 0) {
      return;
    }
    final List<TransactionItem> next = List<TransactionItem>.of(_transactions);
    next[index] = transaction;
    _transactions = next;
    _changed();
  }

  void deleteTransaction(int id) {
    final List<TransactionItem> next = _transactions
        .where((TransactionItem item) => item.id != id)
        .toList();
    if (next.length == _transactions.length) {
      return;
    }
    _transactions = next;
    _changed();
  }

  void restoreTransaction(TransactionItem transaction, {int? index}) {
    if (_transactions.any(
      (TransactionItem item) => item.id == transaction.id,
    )) {
      return;
    }
    final List<TransactionItem> next = List<TransactionItem>.of(_transactions);
    final int insertIndex = (index ?? 0).clamp(0, next.length);
    next.insert(insertIndex, transaction);
    _transactions = next;
    _changed();
  }

  void updateProfile(ProfileData value) {
    profile = value;
    _changed();
  }

  void _onDependencyChanged() {
    notifyListeners();
    if (!_isLoading) {
      unawaited(save());
    }
  }

  void _changed() {
    notifyListeners();
    unawaited(save());
  }

  @override
  void dispose() {
    settings.removeListener(_onDependencyChanged);
    theme.removeListener(_onDependencyChanged);
    settings.dispose();
    theme.dispose();
    super.dispose();
  }
}
