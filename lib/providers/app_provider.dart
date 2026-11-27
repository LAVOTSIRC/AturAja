import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/app_storage.dart';
import '../data/cloud_repository.dart';
import '../data/id_generator.dart';
import '../data/models.dart';
import '../data/roasting_notification.dart';
import '../services/budget_alert_service.dart';
import '../services/local_notification_service.dart';
import '../services/roasting_ai_service.dart';
import '../services/roasting_notification_service.dart';
import 'settings_provider.dart';
import 'theme_provider.dart';

int _compareTransactionsNewestFirst(TransactionItem a, TransactionItem b) {
  final DateTime? aCreated = a.createdAt;
  final DateTime? bCreated = b.createdAt;
  if (aCreated != null && bCreated != null) {
    return bCreated.compareTo(aCreated);
  }
  if (aCreated != null) {
    return -1;
  }
  if (bCreated != null) {
    return 1;
  }

  final int? aId = int.tryParse(a.id.split('-').first);
  final int? bId = int.tryParse(b.id.split('-').first);
  if (aId != null && bId != null) {
    return bId.compareTo(aId);
  }
  return 0;
}

class AppProvider extends ChangeNotifier {
  AppStorage storage;
  final SettingsController settings;
  final ThemeController theme;
  final CloudRepository? cloudRepository;
  final AppNotificationService? notifications;
  final BudgetAlertService? budgetAlerts;
  final RoastingNotificationGenerator? roastingGenerator;
  late final RoastingNotificationService? roastingNotifications;

  final SharedPreferences? preferences;
  String? activeUserId;
  String? activeUserEmail;
  bool _isAppActive = true;
  Future<void> _switchChain = Future<void>.value();
  Future<void> _cloudWriteChain = Future<void>.value();
  Future<void> _syncReminderChain = Future<void>.value();

  StreamSubscription<List<TaskItem>>? _tasksSubscription;
  StreamSubscription<List<TransactionItem>>? _transactionsSubscription;
  StreamSubscription<ProfileData?>? _profileSubscription;
  StreamSubscription<CloudMeta>? _metaSubscription;
  String? _connectedUserId;

  List<TaskItem> tasks;
  List<TransactionItem> _transactions;
  ProfileData profile;

  bool _isLoading = false;
  bool _isManualSyncing = false;
  bool _hasPendingCloudWrites = false;
  String? _cloudError;
  DateTime? _lastSyncedAt;

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
    this.activeUserEmail,
    this.cloudRepository,
    this.notifications,
    this.budgetAlerts,
    this.roastingGenerator,
  }) : tasks = List<TaskItem>.of(tasks),
       _transactions = List<TransactionItem>.of(
         transactions ?? sampleTransactions,
       ) {
    final AppNotificationService? notificationService = notifications;
    final RoastingNotificationGenerator? generator = roastingGenerator;
    if (notificationService != null && generator != null) {
      roastingNotifications = RoastingNotificationService(
        notifications: notificationService,
        generator: generator,
        settings: settings,
        preferences: preferences,
        activeUserId: () => activeUserId,
        userName: () => profile.fullName,
        isAppActive: () => _isAppActive,
      );
    } else {
      roastingNotifications = null;
    }
    settings.addListener(_onSettingsChanged);
    theme.addListener(_onThemeChanged);
  }

  factory AppProvider.inMemory({
    List<TaskItem>? tasks,
    List<TransactionItem>? transactions,
    ProfileData? profile,
    String? activeUserId,
    CloudRepository? cloudRepository,
    AppNotificationService? notifications,
    BudgetAlertService? budgetAlerts,
    RoastingNotificationGenerator? roastingGenerator,
    SettingsController? settings,
    ThemeController? theme,
    SharedPreferences? preferences,
  }) {
    return AppProvider(
      storage: MemoryAppStorage(),
      settings: settings ?? SettingsController(),
      theme: theme ?? ThemeController(),
      tasks: tasks ?? sampleTasks,
      transactions: transactions,
      profile: profile ?? ProfileData.initial,
      activeUserId: activeUserId,
      cloudRepository: cloudRepository,
      notifications: notifications,
      budgetAlerts: budgetAlerts,
      roastingGenerator: roastingGenerator,
      preferences: preferences,
    );
  }

  /// Memuat data milik akun Firebase aktif.
  ///
  /// Akun yang belum punya data akan dimulai dari state kosong. Data lama dari
  /// versi sebelum pemisahan akun dimigrasikan ke akun pertama yang masuk.
  static Future<AppProvider> loadPersistent({
    String? userId,
    String? userEmail,
    CloudRepository? cloudRepository,
    AppNotificationService? notifications,
    BudgetAlertService? budgetAlerts,
    RoastingNotificationGenerator? roastingGenerator,
  }) async {
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
      activeUserEmail: userEmail,
      cloudRepository: cloudRepository,
      notifications: notifications,
      budgetAlerts: budgetAlerts,
      roastingGenerator: roastingGenerator,
    );
    await provider.load();
    provider.syncProfileWithAuthEmail(userEmail);
    if (!isGuest && cloudRepository != null) {
      await provider.connectCloud();
    }
    return provider;
  }

  /// Kunci SharedPreferences yang menyimpan flag migrasi cloud per user.
  static String _migrationFlagKey(String userId) =>
      'aturaja_cloud_migrated_$userId';

  bool get canUseCloud =>
      cloudRepository != null &&
      activeUserId != null &&
      activeUserId!.trim().isNotEmpty;

  bool get isCloudSyncing => _isManualSyncing || _hasPendingCloudWrites;

  /// True jika ada perubahan lokal yang belum dikonfirmasi server Firestore.
  bool get hasPendingCloudWrites => _hasPendingCloudWrites;

  DateTime? get lastSyncedAt => _lastSyncedAt;

  String? get cloudError => _cloudError;

  String get cloudSyncStatus {
    if (!canUseCloud) {
      return 'Belum terhubung';
    }
    if (isCloudSyncing) {
      return 'Menyinkronkan...';
    }
    if (_cloudError != null) {
      return 'Gagal sinkron';
    }
    final DateTime? syncedAt = _lastSyncedAt;
    if (syncedAt == null) {
      return 'Belum pernah';
    }
    final int minutes = DateTime.now().difference(syncedAt).inMinutes;
    if (minutes <= 0) {
      return 'Baru saja';
    }
    if (minutes == 1) {
      return 'Sinkron 1 mnt lalu';
    }
    return 'Sinkron $minutes mnt lalu';
  }

  String get cloudBackupStatus =>
      '$cloudSyncStatus | ${settings.autoBackupEnabled ? 'Auto' : 'Manual'}';

  String get newTaskId => newDocumentId();

  /// Berganti penyimpanan saat akun Firebase berubah.
  Future<void> switchUser(String? userId, {String? userEmail}) {
    _switchChain = _switchChain.then(
      (_) => _switchUser(userId, userEmail: userEmail),
    );
    return _switchChain;
  }

  Future<void> _switchUser(String? userId, {String? userEmail}) async {
    if (activeUserId == userId) {
      if (userEmail != null && userEmail.trim().isNotEmpty) {
        activeUserEmail = userEmail;
        syncProfileWithAuthEmail(userEmail, syncToCloud: true);
      }
      return;
    }
    final SharedPreferences? prefs = preferences;
    if (prefs == null) {
      activeUserId = userId;
      activeUserEmail = userEmail;
      syncProfileWithAuthEmail(userEmail, syncToCloud: true);
      return;
    }

    final String? previousUserId = activeUserId;
    // Simpan dulu data akun sebelumnya sebelum mengganti key penyimpanan.
    await save();
    await _disconnectCloud();
    if (userId != null) {
      await _migrateLegacyData(prefs, userId);
    }

    activeUserId = userId;
    activeUserEmail = userEmail;
    // Batalkan jadwal akun lama setelah akun aktif berganti agar pekerjaan
    // generasi yang masih berjalan melihat akun yang sudah tidak aktif.
    await roastingNotifications?.cancelForUser(previousUserId);
    if (roastingNotifications == null) {
      await notifications?.cancelAllTaskReminders();
    }
    storage = SharedPreferencesAppStorage(prefs, userId: userId);
    _isLoading = true;
    _resetState(seedSampleData: userId == null || userId.trim().isEmpty);
    notifyListeners();
    await load();
    syncProfileWithAuthEmail(userEmail);
    if (userId != null && cloudRepository != null) {
      await connectCloud();
    }
  }

  /// Mengisi email dan nama profil awal dari email akun autentikasi bila profil
  /// masih kosong atau masih berisi placeholder bawaan (`ProfileData.initial`).
  bool syncProfileWithAuthEmail(
    String? authEmail, {
    bool syncToCloud = false,
  }) {
    final String? uid = activeUserId?.trim();
    final String normalizedAuthEmail = authEmail?.trim() ?? '';
    if (uid == null || uid.isEmpty || normalizedAuthEmail.isEmpty) {
      return false;
    }

    final bool isDifferentFromInitial =
        normalizedAuthEmail.toLowerCase() !=
        ProfileData.initial.email.toLowerCase();
    final bool hasPlaceholderEmail =
        profile.email.trim().toLowerCase() ==
            ProfileData.initial.email.toLowerCase() &&
        isDifferentFromInitial;
    final bool hasPlaceholderName =
        profile.fullName.trim() == ProfileData.initial.fullName &&
        isDifferentFromInitial;

    final String nextEmail =
        (profile.email.trim().isEmpty || hasPlaceholderEmail)
        ? normalizedAuthEmail
        : profile.email.trim();
    final String derivedName = ProfileData.nameFromEmail(nextEmail);
    final String nextName =
        (profile.fullName.trim().isEmpty || hasPlaceholderName)
        ? derivedName
        : profile.fullName.trim();
    final String nextAvatar =
        (profile.avatarLabel.trim().isEmpty || nextName != profile.fullName)
        ? ProfileData.initialsFromName(nextName)
        : profile.avatarLabel.trim();

    if (nextEmail == profile.email &&
        nextName == profile.fullName &&
        nextAvatar == profile.avatarLabel) {
      return false;
    }

    profile = profile.copyWith(
      fullName: nextName,
      email: nextEmail,
      avatarLabel: nextAvatar,
    );
    notifyListeners();
    unawaited(save());
    if (syncToCloud && canUseCloud) {
      final ProfileData updated = profile;
      unawaited(
        _enqueueCloudWrite(
          (CloudRepository repository, String userId) =>
              repository.saveProfile(userId, updated),
        ),
      );
    }
    return true;
  }

  /// Menghubungkan provider ke Firestore dan memigrasikan data lokal sekali.
  Future<void> connectCloud() async {
    final CloudRepository? repository = cloudRepository;
    final String? userId = activeUserId?.trim();
    if (repository == null || userId == null || userId.isEmpty) {
      return;
    }
    if (_connectedUserId == userId) {
      return;
    }

    await _disconnectCloud();
    _connectedUserId = userId;
    _isManualSyncing = true;
    _cloudError = null;
    notifyListeners();

    // Jika user pernah berhasil migrasi sebelumnya, subscribe tetap
    // dijalankan walau migrasi kali ini gagal (mis. offline), supaya
    // cache offline Firestore masih bisa melayani data.
    final bool previouslyMigrated =
        preferences?.getBool(_migrationFlagKey(userId)) ?? false;

    try {
      final bool migrated = await repository.migrateLocalIfCloudEmpty(
        userId,
        tasks: List<TaskItem>.of(tasks),
        transactions: List<TransactionItem>.of(_transactions),
        profile: profile,
      );
      if (migrated) {
        _setLastSyncedAt(DateTime.now());
        await preferences?.setBool(_migrationFlagKey(userId), true);
      }
      _subscribeToCloud(repository, userId);
    } catch (error) {
      _cloudError = _messageFor(error);
      debugPrint('Gagal menghubungkan Firestore: $error');
      if (previouslyMigrated) {
        _subscribeToCloud(repository, userId);
      }
    } finally {
      _isManualSyncing = false;
      notifyListeners();
    }
  }

  Future<void> syncCloudNow() async {
    final CloudRepository? repository = cloudRepository;
    final String? userId = activeUserId?.trim();
    if (repository == null || userId == null || userId.isEmpty) {
      throw StateError(
        'Masuk ke akun terlebih dahulu untuk mencadangkan data.',
      );
    }
    if (_isManualSyncing) {
      return;
    }

    _isManualSyncing = true;
    _cloudError = null;
    notifyListeners();
    try {
      await repository.saveAll(
        userId,
        tasks: List<TaskItem>.of(tasks),
        transactions: List<TransactionItem>.of(_transactions),
        profile: profile,
      );
      _setLastSyncedAt(DateTime.now());
      if (_connectedUserId != userId) {
        _connectedUserId = userId;
        _subscribeToCloud(repository, userId);
      }
    } catch (error) {
      _cloudError = _messageFor(error);
      rethrow;
    } finally {
      _isManualSyncing = false;
      notifyListeners();
    }
  }

  void _subscribeToCloud(CloudRepository repository, String userId) {
    _tasksSubscription = repository.watchTasks(userId).listen((
      List<TaskItem> value,
    ) {
      tasks = List<TaskItem>.of(value);
      notifyListeners();
      unawaited(save());
      unawaited(_syncTaskReminders());
    }, onError: _handleCloudStreamError);
    _transactionsSubscription = repository.watchTransactions(userId).listen((
      List<TransactionItem> value,
    ) {
      _transactions = List<TransactionItem>.of(value);
      notifyListeners();
      unawaited(save());
      unawaited(_checkBudgetAlert());
    }, onError: _handleCloudStreamError);
    _profileSubscription = repository.watchProfile(userId).listen((
      ProfileData? value,
    ) {
      if (value == null) {
        return;
      }
      profile = value;
      final bool normalized = syncProfileWithAuthEmail(
        activeUserEmail,
        syncToCloud: true,
      );
      if (!normalized) {
        notifyListeners();
        unawaited(save());
      }
    }, onError: _handleCloudStreamError);
    _metaSubscription = repository.watchMeta(userId).listen((CloudMeta value) {
      _hasPendingCloudWrites = value.hasPendingWrites;
      if (value.lastSyncedAt != null) {
        _lastSyncedAt = value.lastSyncedAt;
        settings.setCloudLastSyncedAt(value.lastSyncedAt);
      }
      _cloudError = null;
      notifyListeners();
    }, onError: _handleCloudStreamError);
  }

  void _handleCloudStreamError(Object error) {
    _cloudError = _messageFor(error);
    _hasPendingCloudWrites = false;
    debugPrint('Stream Firestore gagal: $error');
    notifyListeners();
  }

  Future<void> _disconnectCloud() async {
    await _tasksSubscription?.cancel();
    await _transactionsSubscription?.cancel();
    await _profileSubscription?.cancel();
    await _metaSubscription?.cancel();
    _tasksSubscription = null;
    _transactionsSubscription = null;
    _profileSubscription = null;
    _metaSubscription = null;
    _connectedUserId = null;
    _hasPendingCloudWrites = false;
    _isManualSyncing = false;
    _cloudError = null;
    _lastSyncedAt = null;
    settings.setCloudLastSyncedAt(null);
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

  List<TransactionItem> get recentTransactions {
    final List<TransactionItem> sorted = List<TransactionItem>.of(
      _transactions,
    );
    sorted.sort(_compareTransactionsNewestFirst);
    return sorted.take(4).toList();
  }

  int get totalIncome => _transactions
      .where((TransactionItem item) => item.amount > 0)
      .fold(0, (int sum, TransactionItem item) => sum + item.amount);

  int get totalExpense => _transactions
      .where((TransactionItem item) => item.amount < 0)
      .fold(0, (int sum, TransactionItem item) => sum + item.amount.abs());

  int get monthlyExpense {
    final DateTime now = DateTime.now();
    return _transactions
        .where(
          (TransactionItem item) =>
              item.amount < 0 && _transactionIsInMonth(item, now),
        )
        .fold(0, (int sum, TransactionItem item) => sum + item.amount.abs());
  }

  int get todayExpense {
    final DateTime now = DateTime.now();
    return _transactions
        .where(
          (TransactionItem item) =>
              item.amount < 0 && _transactionIsToday(item, now),
        )
        .fold(0, (int sum, TransactionItem item) => sum + item.amount.abs());
  }

  int get todayTransactionCount {
    final DateTime now = DateTime.now();
    return _transactions
        .where((TransactionItem item) => _transactionIsToday(item, now))
        .length;
  }

  int get completedTodayTaskCount {
    final DateTime now = DateTime.now();
    return tasks.where((TaskItem task) {
      final DateTime? completedAt = task.completedAt;
      if (!task.done || completedAt == null) {
        return false;
      }
      final DateTime localCompletedAt = completedAt.toLocal();
      return localCompletedAt.year == now.year &&
          localCompletedAt.month == now.month &&
          localCompletedAt.day == now.day;
    }).length;
  }

  int get overdueTaskCount =>
      tasks.where((TaskItem task) => !task.done && task.isOverdue).length;

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

  Future<void> load() async {
    _isLoading = true;
    try {
      final String? raw = await storage.read();
      if (raw == null || raw.trim().isEmpty) {
        _isLoading = false;
        await save();
        unawaited(_syncTaskReminders());
        unawaited(_checkBudgetAlert());
        unawaited(_syncDailyRoasting());
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
    unawaited(_syncTaskReminders());
    unawaited(_checkBudgetAlert());
    unawaited(_syncDailyRoasting());
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

  Future<void> addTask(TaskItem task) {
    tasks = <TaskItem>[...tasks, task];
    _changed();
    unawaited(_syncTaskReminders());
    return _enqueueCloudWrite(
      (CloudRepository repository, String userId) =>
          repository.saveTask(userId, task),
    );
  }

  Future<void> upsertTask(TaskItem task) {
    final int index = tasks.indexWhere((TaskItem item) => item.id == task.id);
    if (index < 0) {
      return addTask(task);
    }
    final List<TaskItem> next = List<TaskItem>.of(tasks);
    next[index] = task;
    tasks = next;
    _changed();
    unawaited(_syncTaskReminders());
    return _enqueueCloudWrite(
      (CloudRepository repository, String userId) =>
          repository.saveTask(userId, task),
    );
  }

  Future<void> toggleTask(String id) {
    TaskItem? updated;
    tasks = tasks.map((TaskItem task) {
      if (task.id != id) {
        return task;
      }
      final bool markDone = !task.done;
      updated = task.copyWith(
        done: markDone,
        completedAt: markDone ? DateTime.now() : null,
        clearCompletedAt: !markDone,
      );
      return updated!;
    }).toList();
    _changed();
    unawaited(_syncTaskReminders());
    if (updated == null) {
      return Future<void>.value();
    }
    final TaskItem task = updated!;
    return _enqueueCloudWrite(
      (CloudRepository repository, String userId) =>
          repository.saveTask(userId, task),
    );
  }

  Future<void> deleteTask(String id) {
    tasks = tasks.where((TaskItem task) => task.id != id).toList();
    _changed();
    unawaited(notifications?.cancelTaskReminder(id));
    unawaited(_syncTaskReminders());
    return _enqueueCloudWrite(
      (CloudRepository repository, String userId) =>
          repository.deleteTask(userId, id),
    );
  }

  Future<void> addTransaction(TransactionItem transaction) =>
      addTransactions(<TransactionItem>[transaction]);

  Future<void> addTransactions(List<TransactionItem> transactions) async {
    if (transactions.isEmpty) return;
    final DateTime createdAt = DateTime.now();
    final List<TransactionItem> stored = transactions.map((item) {
      return item.createdAt == null
          ? item.copyWith(createdAt: createdAt)
          : item;
    }).toList();
    _transactions = <TransactionItem>[...stored, ..._transactions];
    _changed();
    unawaited(_checkBudgetAlert());
    await Future.wait(
      stored.map(
        (TransactionItem item) => _enqueueCloudWrite(
          (CloudRepository repository, String userId) =>
              repository.saveTransaction(userId, item),
        ),
      ),
    );
  }

  Future<void> updateTransaction(TransactionItem transaction) {
    final int index = _transactions.indexWhere(
      (TransactionItem item) => item.id == transaction.id,
    );
    if (index < 0) {
      return Future<void>.value();
    }
    final List<TransactionItem> next = List<TransactionItem>.of(_transactions);
    next[index] = transaction;
    _transactions = next;
    _changed();
    unawaited(_checkBudgetAlert());
    return _enqueueCloudWrite(
      (CloudRepository repository, String userId) =>
          repository.saveTransaction(userId, transaction),
    );
  }

  Future<void> deleteTransaction(String id) {
    final List<TransactionItem> next = _transactions
        .where((TransactionItem item) => item.id != id)
        .toList();
    if (next.length == _transactions.length) {
      return Future<void>.value();
    }
    _transactions = next;
    _changed();
    unawaited(_checkBudgetAlert());
    return _enqueueCloudWrite(
      (CloudRepository repository, String userId) =>
          repository.deleteTransaction(userId, id),
    );
  }

  Future<void> restoreTransaction(TransactionItem transaction, {int? index}) {
    if (_transactions.any(
      (TransactionItem item) => item.id == transaction.id,
    )) {
      return Future<void>.value();
    }
    final List<TransactionItem> next = List<TransactionItem>.of(_transactions);
    final int insertIndex = (index ?? 0).clamp(0, next.length);
    next.insert(insertIndex, transaction);
    _transactions = next;
    _changed();
    unawaited(_checkBudgetAlert());
    return _enqueueCloudWrite(
      (CloudRepository repository, String userId) =>
          repository.saveTransaction(userId, transaction),
    );
  }

  Future<void> deleteAllUserData() async {
    final CloudRepository? repository = cloudRepository;
    final String? userId = activeUserId?.trim();
    if (repository != null && userId != null && userId.isNotEmpty) {
      await repository.deleteAllUserData(userId);
    }
    await _disconnectCloud();
    await roastingNotifications?.clearUserData(userId);
    if (roastingNotifications == null) {
      await notifications?.cancelAllTaskReminders();
    }
    tasks = <TaskItem>[];
    _transactions = <TransactionItem>[];
    profile = ProfileData.empty;
    settings.resetToDefaults();
    theme.resetToDefaults();
    _changed();
    await save();
  }

  /// Menghapus salinan lokal akun aktif setelah akun Firebase dihapus.
  Future<void> clearLocalAccountData() async {
    final SharedPreferences? prefs = preferences;
    final String? userId = activeUserId?.trim();
    if (prefs == null || userId == null || userId.isEmpty) {
      return;
    }
    await roastingNotifications?.clearUserData(userId);
    await prefs.remove(SharedPreferencesAppStorage.storageKeyFor(userId));
    await prefs.remove(_migrationFlagKey(userId));
  }

  Future<void> updateProfile(ProfileData value) {
    profile = value;
    _changed();
    return _enqueueCloudWrite(
      (CloudRepository repository, String userId) =>
          repository.saveProfile(userId, value),
    );
  }

  Future<bool> requestNotificationPermission() async {
    final AppNotificationService? service = notifications;
    if (service == null) {
      return true;
    }
    return service.requestPermissions();
  }

  Future<bool> requestExactAlarmPermission() async {
    final AppNotificationService? service = notifications;
    if (service == null) {
      return true;
    }
    return service.requestExactAlarmPermissionIfNeeded();
  }

  Future<bool> setDeadlineNotifications(bool value) async {
    if (value) {
      final bool granted = await requestNotificationPermission();
      if (!granted) {
        return false;
      }
    }
    settings.setDeadlineNotifications(value);
    if (value) {
      await _syncTaskReminders();
    } else {
      await notifications?.cancelAllTaskReminders();
    }
    return true;
  }

  Future<bool> setBudgetAlerts(bool value) async {
    if (value) {
      final bool granted = await requestNotificationPermission();
      if (!granted) {
        return false;
      }
    }
    settings.setBudgetAlerts(value);
    if (value) {
      await _checkBudgetAlert();
    }
    return true;
  }

  Future<bool> setBudgetRoasting(bool value) async {
    if (value) {
      if (!settings.budgetAlertsEnabled) {
        return false;
      }
      final bool granted = await requestNotificationPermission();
      if (!granted) {
        return false;
      }
    }
    settings.setBudgetRoasting(value);
    return true;
  }

  Future<bool> setDeadlineRoasting(bool value) async {
    if (value) {
      if (!settings.deadlineNotificationsEnabled) {
        return false;
      }
      final bool granted = await requestNotificationPermission();
      if (!granted) {
        return false;
      }
    }
    settings.setDeadlineRoasting(value);
    await _syncTaskReminders();
    return true;
  }

  Future<bool> setDailyRoasting(bool value) async {
    if (value) {
      final bool granted = await requestNotificationPermission();
      if (!granted) {
        return false;
      }
    }
    settings.setDailyRoasting(value);
    await _syncDailyRoasting();
    return true;
  }

  Future<void> setDailyRoastingTime(int hour, int minute) async {
    settings.setDailyRoastingTime(hour, minute);
    await _syncDailyRoasting();
  }

  /// Dipanggil ketika aplikasi kembali ke foreground agar Daily Roasting
  /// berikutnya dijadwalkan dengan data terbaru yang tersedia.
  Future<void> onAppForeground() async {
    _isAppActive = true;
    if (_isLoading) {
      return;
    }
    await _syncTaskReminders();
    await _checkBudgetAlert();
    await _syncDailyRoasting();
  }

  /// Dipanggil saat aplikasi meninggalkan foreground. Update data dari cloud
  /// tetap boleh masuk, tetapi konten Gemini baru tidak dibuat di latar
  /// belakang.
  void onAppBackgrounded() {
    _isAppActive = false;
  }

  Future<void> _syncTaskReminders() {
    final Future<void> next = _syncReminderChain.then(
      (_) => _doSyncTaskReminders(),
    );
    _syncReminderChain = next.catchError((Object _) {});
    return next;
  }

  Future<void> _doSyncTaskReminders() async {
    try {
      final RoastingNotificationService? coordinator = roastingNotifications;
      if (coordinator != null) {
        await coordinator.syncTaskReminders(userId: activeUserId, tasks: tasks);
        return;
      }

      final AppNotificationService? service = notifications;
      if (service == null) {
        return;
      }
      final String? userId = activeUserId?.trim();
      if (userId == null ||
          userId.isEmpty ||
          !settings.deadlineNotificationsEnabled) {
        await service.cancelAllTaskReminders();
        return;
      }
      await service.rescheduleTaskReminders(tasks);
    } catch (error) {
      debugPrint('Gagal menyinkronkan pengingat tugas: $error');
    }
  }

  Future<void> _syncDailyRoasting() async {
    final RoastingNotificationService? coordinator = roastingNotifications;
    if (coordinator == null) {
      return;
    }
    try {
      await coordinator.syncDaily(
        userId: activeUserId,
        summary: DailyRoastingSummary(
          pendingTasks: pendingTaskCount,
          dueTodayTasks: todayTaskCount,
          overdueTasks: overdueTaskCount,
          completedToday: completedTodayTaskCount,
          todayExpense: todayExpense,
          todayTransactionCount: todayTransactionCount,
        ),
      );
    } catch (error) {
      debugPrint('Gagal menyinkronkan Daily Roasting: $error');
    }
  }

  Future<void> _checkBudgetAlert() async {
    final BudgetAlertService? service = budgetAlerts;
    if (service == null) {
      return;
    }
    try {
      final String? alertUserId = activeUserId;
      final RoastingNotificationService? coordinator = roastingNotifications;
      final bool useRoasting =
          coordinator != null &&
          settings.budgetAlertsEnabled &&
          settings.budgetRoastingEnabled &&
          settings.roastingAiEnabled;
      await service.check(
        userId: alertUserId,
        spent: monthlyExpense,
        limit: settings.monthlyBudgetLimit,
        enabled: settings.budgetAlertsEnabled,
        contentBuilder: useRoasting
            ? ({
                required int threshold,
                required int spent,
                required int limit,
              }) => coordinator.buildBudgetContent(
                userId: alertUserId,
                threshold: threshold,
                spent: spent,
                limit: limit,
              )
            : null,
        shouldNotify: () => activeUserId == alertUserId,
      );
    } catch (error) {
      debugPrint('Gagal memeriksa peringatan anggaran: $error');
    }
  }

  static DateTime? _transactionDate(TransactionItem transaction, DateTime now) {
    final DateTime? parsedDate = DateTime.tryParse(transaction.date);
    if (parsedDate != null) {
      return parsedDate.toLocal();
    }

    final DateTime? createdAt = transaction.createdAt;
    if (createdAt != null) {
      return createdAt.toLocal();
    }

    final RegExpMatch? legacyDate = RegExp(
      r'^(\d{1,2})[/-](\d{1,2})[/-](\d{4})$',
    ).firstMatch(transaction.date.trim());
    if (legacyDate != null) {
      final int? day = int.tryParse(legacyDate.group(1)!);
      final int? month = int.tryParse(legacyDate.group(2)!);
      final int? year = int.tryParse(legacyDate.group(3)!);
      if (day == null || month == null || year == null) {
        return null;
      }
      final DateTime candidate = DateTime(year, month, day);
      if (candidate.year != year ||
          candidate.month != month ||
          candidate.day != day) {
        return null;
      }
      return candidate;
    }

    final String normalized = transaction.date.trim().toLowerCase();
    if (normalized == 'hari ini') {
      return DateTime(now.year, now.month, now.day);
    }
    if (normalized == 'kemarin') {
      return DateTime(now.year, now.month, now.day - 1);
    }
    return null;
  }

  static bool _transactionIsInMonth(TransactionItem transaction, DateTime now) {
    final DateTime? date = _transactionDate(transaction, now);
    return date != null && date.year == now.year && date.month == now.month;
  }

  static bool _transactionIsToday(TransactionItem transaction, DateTime now) {
    final DateTime? date = _transactionDate(transaction, now);
    return date != null &&
        date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  Future<void> _enqueueCloudWrite(
    Future<void> Function(CloudRepository repository, String userId) action,
  ) {
    final CloudRepository? repository = cloudRepository;
    final String? userId = activeUserId?.trim();
    if (!settings.autoBackupEnabled ||
        repository == null ||
        userId == null ||
        userId.isEmpty) {
      return Future<void>.value();
    }

    _cloudWriteChain = _cloudWriteChain.then((_) async {
      try {
        await action(repository, userId);
        _cloudError = null;
        _setLastSyncedAt(DateTime.now());
      } catch (error) {
        _cloudError = _messageFor(error);
        debugPrint('Gagal menulis ke Firestore: $error');
      } finally {
        notifyListeners();
      }
    });
    return _cloudWriteChain;
  }

  void _setLastSyncedAt(DateTime value) {
    _lastSyncedAt = value;
    settings.setCloudLastSyncedAt(value);
  }

  String _messageFor(Object error) {
    final String message = error.toString().replaceFirst('Exception: ', '');
    return message.length > 120 ? '${message.substring(0, 117)}...' : message;
  }

  void _onSettingsChanged() {
    notifyListeners();
    if (_isLoading) {
      return;
    }
    unawaited(save());
    unawaited(_syncTaskReminders());
    unawaited(_checkBudgetAlert());
    unawaited(_syncDailyRoasting());
  }

  void _onThemeChanged() {
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
    unawaited(_tasksSubscription?.cancel());
    unawaited(_transactionsSubscription?.cancel());
    unawaited(_profileSubscription?.cancel());
    unawaited(_metaSubscription?.cancel());
    settings.removeListener(_onSettingsChanged);
    theme.removeListener(_onThemeChanged);
    settings.dispose();
    theme.dispose();
    super.dispose();
  }
}
