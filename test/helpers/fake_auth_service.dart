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
  String? lastEmail;
  String? lastPassword;

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
    return _emit(
      AuthUser(
        uid: 'registered-uid',
        email: email,
        displayName: email.split('@').first,
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
      ),
    );
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
