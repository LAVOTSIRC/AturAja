import 'package:aturaja/services/app_lock_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class MemorySecureStorage extends FlutterSecureStorage {
  final Map<String, String> values = <String, String>{};

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return values[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    values.remove(key);
  }

  @override
  Future<void> deleteAll({
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    values.clear();
  }
}

void main() {
  test('menyimpan PIN sebagai hash bersalt, bukan teks biasa', () async {
    final MemorySecureStorage storage = MemorySecureStorage();
    final AppLockService service = AppLockService(storage: storage);

    await service.savePin('1234');

    final String stored = storage.values.values.single;
    final List<String> parts = stored.split(':');
    expect(parts, hasLength(2));
    expect(parts[0], isNotEmpty);
    expect(parts[1], hasLength(64));
    expect(stored, isNot('1234'));
    expect(await service.hasPin(), isTrue);
    expect(await service.verifyPin('1234'), isTrue);
    expect(await service.verifyPin('0000'), isFalse);
  });

  test('salt berubah setiap kali PIN disimpan ulang', () async {
    final MemorySecureStorage storage = MemorySecureStorage();
    final AppLockService service = AppLockService(storage: storage);

    await service.savePin('1234');
    final String first = storage.values.values.single;
    await service.savePin('1234');
    final String second = storage.values.values.single;

    expect(second, isNot(first));
    expect(await service.verifyPin('1234'), isTrue);
  });

  test('clearPin menghapus kredensial', () async {
    final MemorySecureStorage storage = MemorySecureStorage();
    final AppLockService service = AppLockService(storage: storage);
    await service.savePin('1234');

    await service.clearPin();

    expect(await service.hasPin(), isFalse);
    expect(await service.verifyPin('1234'), isFalse);
    expect(storage.values, isEmpty);
  });
}
