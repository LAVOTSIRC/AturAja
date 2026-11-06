import 'package:shared_preferences/shared_preferences.dart';

abstract class AppStorage {
  Future<String?> read();
  Future<void> write(String value);
}

class SharedPreferencesAppStorage implements AppStorage {
  /// Key lama yang dipakai sebelum data dipisahkan per akun.
  static const String legacyStorageKey = 'aturaja_state_v1';
  static const String guestStorageKey = 'aturaja_state_v1_guest';

  static String storageKeyFor(String? userId) {
    final String? normalized = userId?.trim();
    if (normalized == null || normalized.isEmpty) {
      return guestStorageKey;
    }
    return '${legacyStorageKey}_$normalized';
  }

  final SharedPreferences preferences;
  final String storageKey;

  SharedPreferencesAppStorage(this.preferences, {String? userId})
    : storageKey = storageKeyFor(userId);

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
