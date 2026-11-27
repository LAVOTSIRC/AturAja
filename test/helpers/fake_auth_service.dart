import 'dart:async';

import 'package:aturaja/data/auth_user.dart';
import 'package:aturaja/services/auth_service.dart';

const AuthUser testAuthUser = AuthUser(
  uid: 'test-uid',
  email: 'zidan@atmaja.id',
  displayName: 'Zidan',
);

/// Implementasi [AuthService] untuk widget test tanpa plugin Firebase.
class FakeAuthService implements AuthService {
  FakeAuthService({AuthUser? initialUser}) : _currentUser = initialUser;

  final StreamController<AuthUser?> _controller =
      StreamController<AuthUser?>.broadcast();

  AuthUser? _currentUser;
  AuthFailure? failure;
  int signOutCalls = 0;
  int deleteAccountCalls = 0;
  int googleSignInCalls = 0;
  int sendEmailVerificationCalls = 0;
  int reloadUserCalls = 0;
  int passwordResetCalls = 0;
  int changePasswordCalls = 0;
  bool verifyOnReload = false;
  String? lastEmail;
  String? lastPassword;
  String? lastResetEmail;
  String? lastCurrentPassword;
  String? lastNewPassword;

  @override
  AuthUser? get currentUser => _currentUser;

  @override
  Stream<AuthUser?> get authStateChanges => _controller.stream;

  @override
  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    lastEmail = email;
    lastPassword = password;
    if (failure != null) {
      throw failure!;
    }
    return _emit(
      AuthUser(
        uid: 'email-uid',
        email: email,
        displayName: email.split('@').first,
      ),
    );
  }

  @override
  Future<AuthUser> registerWithEmail({
    required String email,
    required String password,
  }) async {
    lastEmail = email;
    lastPassword = password;
    if (failure != null) {
      throw failure!;
    }
    sendEmailVerificationCalls++;
    return _emit(
      AuthUser(
        uid: 'registered-uid',
        email: email,
        displayName: email.split('@').first,
        emailVerified: false,
      ),
    );
  }

  @override
  Future<AuthUser> signInWithGoogle() async {
    googleSignInCalls++;
    if (failure != null) {
      throw failure!;
    }
    return _emit(
      const AuthUser(
        uid: 'google-uid',
        email: 'google@atmaja.id',
        displayName: 'Google User',
        emailVerified: true,
        hasPasswordProvider: false,
      ),
    );
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    passwordResetCalls++;
    lastResetEmail = email;
    if (failure != null) {
      throw failure!;
    }
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    changePasswordCalls++;
    lastCurrentPassword = currentPassword;
    lastNewPassword = newPassword;
    if (failure != null) {
      throw failure!;
    }
    if (_currentUser == null) {
      throw const AuthFailure('missing-user', 'Sesi pengguna tidak ditemukan.');
    }
    if (!(_currentUser?.hasPasswordProvider ?? false)) {
      throw const AuthFailure(
        'password-not-supported',
        'Akun ini masuk dengan Google. Kelola kata sandi melalui akun Google kamu.',
      );
    }
  }

  @override
  Future<void> sendEmailVerification() async {
    sendEmailVerificationCalls++;
    if (failure != null) {
      throw failure!;
    }
    if (_currentUser == null) {
      throw const AuthFailure('missing-user', 'Sesi pengguna tidak ditemukan.');
    }
  }

  @override
  Future<AuthUser?> reloadUser() async {
    reloadUserCalls++;
    if (failure != null) {
      throw failure!;
    }
    final AuthUser? user = _currentUser;
    if (user == null) {
      return null;
    }
    if (verifyOnReload && !user.emailVerified) {
      return _emit(
        AuthUser(
          uid: user.uid,
          email: user.email,
          displayName: user.displayName,
          photoUrl: user.photoUrl,
          emailVerified: true,
        ),
      );
    }
    return user;
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    _currentUser = null;
    _controller.add(null);
  }

  @override
  Future<void> deleteAccount() async {
    deleteAccountCalls++;
    if (failure != null) {
      throw failure!;
    }
    _currentUser = null;
    _controller.add(null);
  }

  void dispose() {
    _controller.close();
  }

  AuthUser _emit(AuthUser user) {
    _currentUser = user;
    _controller.add(user);
    return user;
  }
}
