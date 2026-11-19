import 'package:aturaja/services/app_lock_service.dart';

/// Layanan kunci aplikasi in-memory untuk widget test.
class FakeAppLockService extends AppLockService {
  String? pin;
  bool biometricAvailable = false;
  bool biometricSucceeds = false;

  @override
  Future<bool> hasPin() async => pin != null;

  @override
  Future<void> savePin(String value) async {
    pin = value;
  }

  @override
  Future<bool> verifyPin(String value) async => pin != null && pin == value;

  @override
  Future<bool> canUseBiometrics() async => biometricAvailable;

  @override
  Future<bool> authenticateWithBiometrics() async => biometricSucceeds;

  @override
  Future<void> clearPin() async {
    pin = null;
  }
}
