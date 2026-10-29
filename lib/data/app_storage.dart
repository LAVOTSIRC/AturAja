import 'package:shared_preferences/shared_preferences.dart';

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
