import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:google_sign_in/google_sign_in.dart';

import '../data/auth_user.dart';
import '../data/models.dart';

/// Error autentikasi yang sudah dipetakan ke pesan berbahasa Indonesia.
class AuthFailure implements Exception {
  const AuthFailure(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => message;
}

/// Kontrak autentikasi agar UI dan test tidak bergantung langsung pada Firebase.
abstract interface class AuthService {
  AuthUser? get currentUser;

  Stream<AuthUser?> get authStateChanges;

  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
  });

  Future<AuthUser> registerWithEmail({
    required String email,
    required String password,
  });

  Future<AuthUser> signInWithGoogle();

  Future<void> sendEmailVerification();

  Future<AuthUser?> reloadUser();

  Future<void> sendPasswordResetEmail({required String email});

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  Future<void> signOut();

  Future<void> deleteAccount();
}

/// Implementasi autentikasi Firebase untuk email/password dan Google Sign-In.
class FirebaseAuthService implements AuthService {
  FirebaseAuthService({firebase.FirebaseAuth? auth, GoogleSignIn? googleSignIn})
    : _auth = auth ?? firebase.FirebaseAuth.instance,
      _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final firebase.FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;
  bool _googleInitialized = false;

  @override
  AuthUser? get currentUser => _toAuthUser(_auth.currentUser);

  @override
  Stream<AuthUser?> get authStateChanges =>
      _auth.authStateChanges().map(_toAuthUser);

  @override
  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final firebase.UserCredential credential = await _auth
          .signInWithEmailAndPassword(email: email.trim(), password: password);
      return _requireUser(credential.user);
    } on firebase.FirebaseAuthException catch (error) {
      throw _mapFirebaseException(error);
    }
  }

  @override
  Future<AuthUser> registerWithEmail({
    required String email,
    required String password,
  }) async {
    final String trimmedEmail = email.trim();
    try {
      final firebase.UserCredential credential = await _auth
          .createUserWithEmailAndPassword(
            email: trimmedEmail,
            password: password,
          );
      final firebase.User? createdUser = credential.user;
      if (createdUser != null) {
        final String derivedName = ProfileData.nameFromEmail(trimmedEmail);
        if (derivedName.isNotEmpty) {
          try {
            await createdUser.updateDisplayName(derivedName);
          } catch (_) {
            // Kegagalan sinkron displayName tidak boleh membatalkan registrasi.
          }
        }
        await createdUser.sendEmailVerification();
      }
      return _requireUser(_auth.currentUser ?? createdUser);
    } on firebase.FirebaseAuthException catch (error) {
      throw _mapFirebaseException(error);
    }
  }

  @override
  Future<AuthUser> signInWithGoogle() async {
    await _ensureGoogleInitialized();
    try {
      final GoogleSignInAccount account = await _googleSignIn.authenticate();
      final String? idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const AuthFailure(
          'google-id-token-missing',
          'Token Google tidak tersedia. Coba masuk ulang.',
        );
      }

      final firebase.UserCredential credential = await _auth
          .signInWithCredential(
            firebase.GoogleAuthProvider.credential(idToken: idToken),
          );
      return _requireUser(credential.user);
    } on GoogleSignInException catch (error) {
      throw _mapGoogleException(error);
    } on firebase.FirebaseAuthException catch (error) {
      throw _mapFirebaseException(error);
    }
  }

  @override
  Future<void> sendEmailVerification() async {
    final firebase.User? user = _auth.currentUser;
    if (user == null) {
      throw const AuthFailure(
        'missing-user',
        'Sesi pengguna tidak ditemukan. Silakan masuk ulang.',
      );
    }
    try {
      await user.sendEmailVerification();
    } on firebase.FirebaseAuthException catch (error) {
      throw _mapFirebaseException(error);
    }
  }

  @override
  Future<AuthUser?> reloadUser() async {
    final firebase.User? user = _auth.currentUser;
    if (user == null) {
      return null;
    }
    try {
      await user.reload();
      return _toAuthUser(_auth.currentUser);
    } on firebase.FirebaseAuthException catch (error) {
      throw _mapFirebaseException(error);
    }
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on firebase.FirebaseAuthException catch (error) {
      throw _mapFirebaseException(error);
    }
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final firebase.User? user = _auth.currentUser;
    if (user == null) {
      throw const AuthFailure(
        'missing-user',
        'Sesi pengguna tidak ditemukan. Silakan masuk ulang.',
      );
    }
    final bool hasPassword = user.providerData.any(
      (firebase.UserInfo info) => info.providerId == 'password',
    );
    final String? email = user.email;
    if (!hasPassword || email == null || email.trim().isEmpty) {
      throw const AuthFailure(
        'password-not-supported',
        'Akun ini masuk dengan Google. Kelola kata sandi melalui akun Google kamu.',
      );
    }
    try {
      final firebase.AuthCredential credential =
          firebase.EmailAuthProvider.credential(
            email: email.trim(),
            password: currentPassword,
          );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
    } on firebase.FirebaseAuthException catch (error) {
      if (error.code == 'wrong-password' ||
          error.code == 'invalid-credential') {
        throw const AuthFailure(
          'wrong-password',
          'Kata sandi saat ini salah.',
        );
      }
      throw _mapFirebaseException(error);
    }
  }

  @override
  Future<void> signOut() async {
    // Google Sign-In hanya perlu di-reset jika sebelumnya sudah diinisialisasi.
    if (_googleInitialized) {
      try {
        await _googleSignIn.signOut();
      } catch (_) {
        // Firebase tetap harus logout walaupun sesi Google gagal dibersihkan.
      }
    }
    await _auth.signOut();
  }

  @override
  Future<void> deleteAccount() async {
    final firebase.User? user = _auth.currentUser;
    if (user == null) {
      throw const AuthFailure(
        'missing-user',
        'Sesi pengguna tidak ditemukan. Silakan masuk ulang.',
      );
    }
    try {
      await user.delete();
      if (_googleInitialized) {
        try {
          await _googleSignIn.signOut();
        } catch (_) {
          // Akun Firebase sudah terhapus; kegagalan reset Google tidak fatal.
        }
      }
    } on firebase.FirebaseAuthException catch (error) {
      throw _mapFirebaseException(error);
    }
  }

  Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) {
      return;
    }
    await _googleSignIn.initialize();
    _googleInitialized = true;
  }

  AuthUser _requireUser(firebase.User? user) {
    if (user == null) {
      throw const AuthFailure(
        'missing-user',
        'Sesi pengguna tidak ditemukan. Silakan coba lagi.',
      );
    }
    return _toAuthUser(user)!;
  }

  AuthUser? _toAuthUser(firebase.User? user) {
    if (user == null) {
      return null;
    }
    final bool hasPasswordProvider = user.providerData.any(
      (firebase.UserInfo info) => info.providerId == 'password',
    );
    return AuthUser(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
      photoUrl: user.photoURL,
      emailVerified: user.emailVerified,
      hasPasswordProvider: hasPasswordProvider,
    );
  }

  AuthFailure _mapFirebaseException(firebase.FirebaseAuthException error) {
    final String message = switch (error.code) {
      'invalid-email' => 'Format email tidak valid.',
      'user-disabled' => 'Akun ini sedang dinonaktifkan.',
      'user-not-found' => 'Email belum terdaftar.',
      'wrong-password' ||
      'invalid-credential' => 'Email atau kata sandi salah.',
      'email-already-in-use' =>
        'Email sudah terdaftar. Silakan masuk menggunakan akun tersebut.',
      'weak-password' =>
        'Kata sandi terlalu lemah. Gunakan minimal 6 karakter.',
      'operation-not-allowed' =>
        'Metode masuk ini belum diaktifkan di Firebase Console.',
      'too-many-requests' =>
        'Terlalu banyak percobaan masuk. Coba lagi beberapa saat lagi.',
      'network-request-failed' =>
        'Koneksi internet bermasalah. Periksa jaringan lalu coba lagi.',
      'requires-recent-login' => 'Silakan masuk ulang untuk melanjutkan.',
      _ => 'Terjadi kesalahan autentikasi. Silakan coba lagi.',
    };
    return AuthFailure(error.code, message);
  }

  AuthFailure _mapGoogleException(GoogleSignInException error) {
    final String message = switch (error.code) {
      GoogleSignInExceptionCode.canceled => 'Masuk dengan Google dibatalkan.',
      GoogleSignInExceptionCode.interrupted =>
        'Proses masuk dengan Google terganggu. Silakan coba lagi.',
      GoogleSignInExceptionCode.clientConfigurationError ||
      GoogleSignInExceptionCode.providerConfigurationError =>
        'Konfigurasi Google Sign-In belum benar. Periksa SHA-1 dan '
            'google-services.json.',
      GoogleSignInExceptionCode.uiUnavailable =>
        'Jendela masuk Google tidak dapat ditampilkan. Coba lagi.',
      GoogleSignInExceptionCode.userMismatch =>
        'Akun Google tidak cocok dengan sesi saat ini.',
      _ => 'Gagal masuk dengan Google. Silakan coba lagi.',
    };
    return AuthFailure(error.code.name, message);
  }
}
