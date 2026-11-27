import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/auth_user.dart';
import '../services/auth_service.dart';

enum AuthStatus { initializing, authenticated, unauthenticated }

/// Sumber kebenaran sesi autentikasi untuk seluruh UI.
class AuthProvider extends ChangeNotifier {
  AuthProvider({
    required this.service,
    AuthUser? initialUser,
    bool initialized = false,
  }) : _user = initialUser,
       _status = initialized
           ? (initialUser == null
                 ? AuthStatus.unauthenticated
                 : AuthStatus.authenticated)
           : AuthStatus.initializing;

  final AuthService service;
  StreamSubscription<AuthUser?>? _subscription;
  bool _disposed = false;

  AuthUser? _user;
  AuthStatus _status;

  AuthUser? get user => _user;

  AuthStatus get status => _status;

  bool get isAuthenticated => _status == AuthStatus.authenticated;

  bool get isInitializing => _status == AuthStatus.initializing;

  bool get isEmailVerified => _user?.emailVerified ?? false;

  bool get needsEmailVerification => isAuthenticated && !isEmailVerified;

  bool get canChangePassword => _user?.hasPasswordProvider ?? false;

  /// Mulai mendengarkan perubahan sesi Firebase.
  ///
  /// Dipanggil sekali dari `main` sebelum aplikasi dijalankan. Status awal
  /// diambil dari [AuthService.currentUser] agar sesi Firebase yang tersimpan
  /// langsung dipulihkan tanpa menunggu event stream pertama.
  Future<void> initialize() async {
    if (_subscription != null) {
      return;
    }
    _subscription = service.authStateChanges.listen(
      _applyUser,
      onError: (Object error, StackTrace stackTrace) {
        _applyUser(null);
      },
    );
    _applyUser(service.currentUser);
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final AuthUser user = await service.signInWithEmail(
      email: email,
      password: password,
    );
    _applyUser(user);
  }

  Future<void> registerWithEmail({
    required String email,
    required String password,
  }) async {
    final AuthUser user = await service.registerWithEmail(
      email: email,
      password: password,
    );
    _applyUser(user);
  }

  Future<void> signInWithGoogle() async {
    final AuthUser user = await service.signInWithGoogle();
    _applyUser(user);
  }

  Future<void> sendEmailVerification() async {
    await service.sendEmailVerification();
  }

  Future<bool> reloadUser() async {
    final AuthUser? refreshed = await service.reloadUser();
    _applyUser(refreshed);
    return refreshed?.emailVerified ?? false;
  }

  Future<void> sendPasswordResetEmail({required String email}) async {
    await service.sendPasswordResetEmail(email: email);
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await service.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }

  Future<void> signOut() async {
    await service.signOut();
    _applyUser(null);
  }

  Future<void> deleteAccount() async {
    await service.deleteAccount();
    _applyUser(null);
  }

  void _applyUser(AuthUser? user) {
    if (_disposed) {
      return;
    }
    _user = user;
    _status = user == null
        ? AuthStatus.unauthenticated
        : AuthStatus.authenticated;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    super.dispose();
  }
}
