import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/theme_scope.dart';
import 'models.dart';
import 'settings_controller.dart';

abstract class AppStorage {
  Future<String?> read();
  Future<void> write(String value);
}

class SharedPreferencesAppStorage implements AppStorage {
  static const String storageKey = 'aturaja_state_v1';

  final SharedPreferences preferences;

  const SharedPreferencesAppStorage(this.preferences);

  @override
  Future<String?> read() async => preferences.getString(storageKey);

  @override
  Future<void> write(String value) async {
    await preferences.setString(storageKey, value);
  }
}

class MemoryAppStorage implements AppStorage {
  String? value;

  MemoryAppStorage([this.value]);

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async {
    this.value = value;
  }
}

class AppStore extends ChangeNotifier {
  final AppStorage storage;
  final SettingsController settings;
  final ThemeController theme;

  List<TaskItem> tasks;
  ProfileData profile;
  bool isLoggedIn;

  bool _isLoading = false;
  Future<void> _saveChain = Future<void>.value();

  AppStore({
    required this.storage,
    required this.settings,
    required this.theme,
    required List<TaskItem> tasks,
    required this.profile,
    required this.isLoggedIn,
  }) : tasks = List<TaskItem>.of(tasks) {
    settings.addListener(_onDependencyChanged);
    theme.addListener(_onDependencyChanged);
  }

  factory AppStore.inMemory({
    List<TaskItem>? tasks,
    ProfileData? profile,
    bool isLoggedIn = false,
  }) {
    return AppStore(
      storage: MemoryAppStorage(),
      settings: SettingsController(),
      theme: ThemeController(),
      tasks: tasks ?? sampleTasks,
      profile: profile ?? ProfileData.initial,
      isLoggedIn: isLoggedIn,
    );
  }

  static Future<AppStore> loadPersistent() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final AppStore store = AppStore(
      storage: SharedPreferencesAppStorage(preferences),
      settings: SettingsController(),
      theme: ThemeController(),
      tasks: sampleTasks,
      profile: ProfileData.initial,
      isLoggedIn: false,
    );
    await store.load();
    return store;
  }

  List<TransactionItem> get transactions => transactionStore;

  int get pendingTaskCount => tasks.where((TaskItem task) => !task.done).length;
  int get urgentTaskCount => tasks.where((TaskItem task) => task.urgent).length;

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
        final List<TransactionItem> loadedTransactions = rawTransactions
            .whereType<Map>()
            .map(
              (Map item) =>
                  TransactionItem.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList();
        transactionStore
          ..clear()
          ..addAll(loadedTransactions);
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

      isLoggedIn = data['isLoggedIn'] as bool? ?? false;
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
    'transactions': transactionStore
        .map((TransactionItem transaction) => transaction.toJson())
        .toList(),
    'profile': profile.toJson(),
    'settings': settings.toJson(),
    'theme': theme.toJson(),
    'isLoggedIn': isLoggedIn,
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

  void updateProfile(ProfileData value) {
    profile = value;
    _changed();
  }

  void setLoggedIn(bool value) {
    if (isLoggedIn == value) {
      return;
    }
    isLoggedIn = value;
    _changed();
  }

  void transactionsChanged() {
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
