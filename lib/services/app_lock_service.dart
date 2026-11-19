import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// Menyimpan PIN aplikasi sebagai hash bersalt di secure storage.
///
/// PIN mentah tidak pernah ditulis ke SharedPreferences maupun ke log.
class AppLockService {
  AppLockService({
    FlutterSecureStorage? storage,
    LocalAuthentication? localAuthentication,
  }) : _storage = storage ?? const FlutterSecureStorage(),
       _localAuthentication = localAuthentication ?? LocalAuthentication();

  static const String _pinKey = 'aturaja_app_lock_pin_v1';

  final FlutterSecureStorage _storage;
  final LocalAuthentication _localAuthentication;

  Future<bool> hasPin() async {
    try {
      final String? value = await _storage.read(key: _pinKey);
      return value != null && value.contains(':');
    } catch (error) {
      debugPrint('Secure storage tidak tersedia: $error');
      return false;
    }
  }

  Future<void> savePin(String pin) async {
    final Random random = Random.secure();
    final List<int> saltBytes = List<int>.generate(
      16,
      (_) => random.nextInt(256),
    );
    final String salt = base64UrlEncode(saltBytes);
    final String hash = _hashPin(pin, salt);
    await _storage.write(key: _pinKey, value: '$salt:$hash');
  }

  Future<bool> verifyPin(String pin) async {
    try {
      final String? value = await _storage.read(key: _pinKey);
      if (value == null) {
        return false;
      }
      final int separator = value.indexOf(':');
      if (separator <= 0 || separator == value.length - 1) {
        return false;
      }
      final String salt = value.substring(0, separator);
      final String expected = value.substring(separator + 1);
      return _constantTimeEquals(_hashPin(pin, salt), expected);
    } catch (error) {
      debugPrint('Gagal memverifikasi PIN: $error');
      return false;
    }
  }

  Future<bool> canUseBiometrics() async {
    try {
      final bool supported = await _localAuthentication.isDeviceSupported();
      if (!supported) {
        return false;
      }
      return await _localAuthentication.canCheckBiometrics;
    } catch (error) {
      debugPrint('Biometrik tidak tersedia: $error');
      return false;
    }
  }

  Future<bool> authenticateWithBiometrics() async {
    try {
      final bool authenticated = await _localAuthentication.authenticate(
        localizedReason: 'Buka AturAja dengan biometrik',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
      return authenticated;
    } on LocalAuthException catch (error) {
      debugPrint('Autentikasi biometrik gagal: ${error.code.name}');
      return false;
    } on PlatformException catch (error) {
      debugPrint('Autentikasi biometrik gagal: ${error.code}');
      return false;
    } catch (error) {
      debugPrint('Autentikasi biometrik gagal: $error');
      return false;
    }
  }

  Future<void> clearPin() async {
    try {
      await _storage.delete(key: _pinKey);
    } catch (error) {
      debugPrint('Gagal menghapus PIN: $error');
    }
  }

  static String _hashPin(String pin, String salt) =>
      sha256.convert(utf8.encode('$salt:$pin')).toString();

  static bool _constantTimeEquals(String left, String right) {
    if (left.length != right.length) {
      return false;
    }
    int difference = 0;
    for (int index = 0; index < left.length; index++) {
      difference |= left.codeUnitAt(index) ^ right.codeUnitAt(index);
    }
    return difference == 0;
  }
}
