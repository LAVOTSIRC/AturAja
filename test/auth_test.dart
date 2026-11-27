import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:aturaja/data/auth_user.dart';
import 'package:aturaja/data/models.dart';
import 'package:aturaja/data/settings_controller.dart';
import 'package:aturaja/main.dart';
import 'package:aturaja/providers/app_provider.dart';
import 'package:aturaja/providers/auth_provider.dart';
import 'package:aturaja/screens/login_screen.dart';
import 'package:aturaja/screens/main_shell.dart';
import 'package:aturaja/screens/profile_screen.dart';
import 'package:aturaja/screens/register_screen.dart';
import 'package:aturaja/screens/verify_email_screen.dart';
import 'package:aturaja/services/auth_service.dart';
import 'package:aturaja/theme/theme_scope.dart';

import 'helpers/fake_auth_service.dart';

Future<AuthProvider> pumpAuthApp(
  WidgetTester tester, {
  required bool isLoggedIn,
  String initialLocation = '/home',
  FakeAuthService? service,
}) async {
  final AppProvider app = AppProvider.inMemory();
  final FakeAuthService authService =
      service ?? FakeAuthService(initialUser: isLoggedIn ? testAuthUser : null);
  final AuthProvider auth = AuthProvider(service: authService);
  await auth.initialize();
  addTearDown(() {
    auth.dispose();
    authService.dispose();
    app.dispose();
  });

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppProvider>.value(value: app),
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ChangeNotifierProvider<ThemeController>.value(value: app.theme),
        ChangeNotifierProvider<SettingsController>.value(value: app.settings),
      ],
      child: MyApp(initialLocation: initialLocation),
    ),
  );
  await tester.pumpAndSettle();
  return auth;
}

void main() {
  group('AuthProvider', () {
    test('memulihkan sesi dari currentUser saat initialize', () async {
      final FakeAuthService service = FakeAuthService(
        initialUser: testAuthUser,
      );
      final AuthProvider auth = AuthProvider(service: service);
      addTearDown(() {
        auth.dispose();
        service.dispose();
      });

      await auth.initialize();

      expect(auth.status, AuthStatus.authenticated);
      expect(auth.isAuthenticated, isTrue);
      expect(auth.user?.uid, testAuthUser.uid);
      expect(auth.user?.email, testAuthUser.email);
    });

    test(
      'signInWithEmail memperbarui sesi dan meneruskan kredensial',
      () async {
        final FakeAuthService service = FakeAuthService();
        final AuthProvider auth = AuthProvider(service: service);
        addTearDown(() {
          auth.dispose();
          service.dispose();
        });
        await auth.initialize();

        await auth.signInWithEmail(
          email: 'zidan@atmaja.id',
          password: 'rahasia123',
        );

        expect(auth.status, AuthStatus.authenticated);
        expect(auth.user?.email, 'zidan@atmaja.id');
        expect(service.lastEmail, 'zidan@atmaja.id');
        expect(service.lastPassword, 'rahasia123');
      },
    );

    test('registerWithEmail membuat sesi pengguna baru', () async {
      final FakeAuthService service = FakeAuthService();
      final AuthProvider auth = AuthProvider(service: service);
      addTearDown(() {
        auth.dispose();
        service.dispose();
      });
      await auth.initialize();

      await auth.registerWithEmail(
        email: 'baru@atmaja.id',
        password: 'rahasia123',
      );

      expect(auth.isAuthenticated, isTrue);
      expect(auth.user?.email, 'baru@atmaja.id');
    });

    test('signInWithGoogle memakai jalur Google pada service', () async {
      final FakeAuthService service = FakeAuthService();
      final AuthProvider auth = AuthProvider(service: service);
      addTearDown(() {
        auth.dispose();
        service.dispose();
      });
      await auth.initialize();

      await auth.signInWithGoogle();

      expect(auth.isAuthenticated, isTrue);
      expect(auth.user?.uid, 'google-uid');
      expect(service.googleSignInCalls, 1);
    });

    test('signOut mengakhiri sesi dan memanggil service', () async {
      final FakeAuthService service = FakeAuthService(
        initialUser: testAuthUser,
      );
      final AuthProvider auth = AuthProvider(service: service);
      addTearDown(() {
        auth.dispose();
        service.dispose();
      });
      await auth.initialize();

      await auth.signOut();

      expect(auth.status, AuthStatus.unauthenticated);
      expect(auth.user, isNull);
      expect(service.signOutCalls, 1);
    });

    test('deleteAccount menghapus sesi dan memanggil service', () async {
      final FakeAuthService service = FakeAuthService(
        initialUser: testAuthUser,
      );
      final AuthProvider auth = AuthProvider(service: service);
      addTearDown(() {
        auth.dispose();
        service.dispose();
      });
      await auth.initialize();

      await auth.deleteAccount();

      expect(auth.status, AuthStatus.unauthenticated);
      expect(auth.user, isNull);
      expect(service.deleteAccountCalls, 1);
    });

    test('deleteAccount meneruskan requires-recent-login', () async {
      final FakeAuthService service = FakeAuthService(initialUser: testAuthUser)
        ..failure = const AuthFailure(
          'requires-recent-login',
          'Silakan login ulang.',
        );
      final AuthProvider auth = AuthProvider(service: service);
      addTearDown(() {
        auth.dispose();
        service.dispose();
      });
      await auth.initialize();

      await expectLater(
        auth.deleteAccount(),
        throwsA(
          isA<AuthFailure>().having(
            (AuthFailure failure) => failure.code,
            'code',
            'requires-recent-login',
          ),
        ),
      );
      expect(auth.isAuthenticated, isTrue);
    });

    test('AuthFailure dari service diteruskan tanpa mengubah sesi', () async {
      final FakeAuthService service = FakeAuthService()
        ..failure = const AuthFailure('wrong-password', 'Kata sandi salah.');
      final AuthProvider auth = AuthProvider(service: service);
      addTearDown(() {
        auth.dispose();
        service.dispose();
      });
      await auth.initialize();

      await expectLater(
        auth.signInWithEmail(email: 'zidan@atmaja.id', password: 'salah'),
        throwsA(
          isA<AuthFailure>().having(
            (AuthFailure error) => error.message,
            'message',
            'Kata sandi salah.',
          ),
        ),
      );
      expect(auth.isAuthenticated, isFalse);
    });
  });

  group('Halaman autentikasi', () {
    testWidgets('tombol Google memanggil callback', (
      WidgetTester tester,
    ) async {
      bool didGoogle = false;
      await tester.pumpWidget(
        ThemeScope(
          controller: ThemeController(),
          child: MaterialApp(
            home: LoginScreen(
              onLogin: ({
                required String email,
                required String password,
              }) async {},
              onGoogleSignIn: () async {
                didGoogle = true;
              },
              onRegister: () {},
            ),
          ),
        ),
      );

      await tester.ensureVisible(find.byTooltip('Masuk dengan Google'));
      await tester.tap(find.byTooltip('Masuk dengan Google'));
      await tester.pumpAndSettle();

      expect(didGoogle, isTrue);
    });

    testWidgets('register memvalidasi konfirmasi kata sandi', (
      WidgetTester tester,
    ) async {
      bool didRegister = false;
      await tester.pumpWidget(
        ThemeScope(
          controller: ThemeController(),
          child: MaterialApp(
            home: RegisterScreen(
              onRegister:
                  ({required String email, required String password}) async {
                    didRegister = true;
                  },
              onLogin: () {},
            ),
          ),
        ),
      );

      await tester.ensureVisible(find.byTooltip('Daftar'));
      await tester.tap(find.byTooltip('Daftar'));
      await tester.pump();
      expect(find.text('Email tidak boleh kosong.'), findsOneWidget);
      expect(find.text('Kata sandi tidak boleh kosong.'), findsOneWidget);
      expect(
        find.text('Konfirmasi kata sandi tidak boleh kosong.'),
        findsOneWidget,
      );
      expect(didRegister, isFalse);

      final Finder fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'baru@atmaja.id');
      await tester.enterText(fields.at(1), 'rahasia123');
      await tester.enterText(fields.at(2), 'beda123');
      await tester.ensureVisible(find.byTooltip('Daftar'));
      await tester.tap(find.byTooltip('Daftar'));
      await tester.pump();
      expect(find.text('Konfirmasi kata sandi tidak cocok.'), findsOneWidget);
      expect(didRegister, isFalse);

      await tester.enterText(fields.at(2), 'rahasia123');
      await tester.ensureVisible(find.byTooltip('Daftar'));
      await tester.tap(find.byTooltip('Daftar'));
      await tester.pumpAndSettle();
      expect(didRegister, isTrue);
    });
  });

  group('Proteksi rute', () {
    testWidgets('halaman terlindungi mengarah ke login saat belum masuk', (
      WidgetTester tester,
    ) async {
      await pumpAuthApp(tester, isLoggedIn: false, initialLocation: '/home');

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(MainShell), findsNothing);
    });

    testWidgets('halaman login diarahkan ke beranda saat sudah masuk', (
      WidgetTester tester,
    ) async {
      await pumpAuthApp(tester, isLoggedIn: true, initialLocation: '/login');

      expect(find.byType(MainShell), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
    });

    testWidgets('logout Firebase mengakhiri sesi dan kembali ke login', (
      WidgetTester tester,
    ) async {
      final AuthProvider auth = await pumpAuthApp(
        tester,
        isLoggedIn: true,
        initialLocation: '/profile',
      );

      await tester.ensureVisible(find.text('Keluar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keluar'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Keluar'));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(MainShell), findsNothing);
      expect((auth.service as FakeAuthService).signOutCalls, 1);
    });

    testWidgets(
      'register email baru langsung mengarah ke halaman verifikasi email, bukan beranda',
      (WidgetTester tester) async {
        final FakeAuthService service = FakeAuthService();
        await pumpAuthApp(
          tester,
          isLoggedIn: false,
          initialLocation: '/register',
          service: service,
        );

        expect(find.byType(RegisterScreen), findsOneWidget);

        final Finder fields = find.byType(TextField);
        await tester.enterText(fields.at(0), 'andi.pratama@gmail.com');
        await tester.enterText(fields.at(1), 'rahasia123');
        await tester.enterText(fields.at(2), 'rahasia123');
        await tester.ensureVisible(find.byTooltip('Daftar'));
        await tester.tap(find.byTooltip('Daftar'));
        await tester.pumpAndSettle();

        expect(find.byType(VerifyEmailScreen), findsOneWidget);
        expect(find.text('andi.pratama@gmail.com'), findsOneWidget);
        expect(find.byType(MainShell), findsNothing);
        expect(service.sendEmailVerificationCalls, 1);
      },
    );

    testWidgets(
      'akun belum terverifikasi diarahkan ke halaman verifikasi email sampai terverifikasi',
      (WidgetTester tester) async {
        final FakeAuthService service = FakeAuthService(
          initialUser: const AuthUser(
            uid: 'unverified-uid',
            email: 'budi.santoso@gmail.com',
            displayName: 'Budi Santoso',
            emailVerified: false,
          ),
        );
        await pumpAuthApp(
          tester,
          isLoggedIn: true,
          initialLocation: '/home',
          service: service,
        );

        expect(find.byType(VerifyEmailScreen), findsOneWidget);
        expect(find.text('budi.santoso@gmail.com'), findsOneWidget);
        expect(find.byType(MainShell), findsNothing);

        // Kirim ulang verifikasi
        await tester.ensureVisible(find.byTooltip('Kirim ulang verifikasi'));
        await tester.tap(find.byTooltip('Kirim ulang verifikasi'));
        await tester.pump();
        expect(service.sendEmailVerificationCalls, 1);

        // Cek saat belum verifikasi -> tetap di VerifyEmailScreen
        await tester.ensureVisible(find.byTooltip('Saya sudah verifikasi'));
        await tester.tap(find.byTooltip('Saya sudah verifikasi'));
        await tester.pumpAndSettle();
        expect(service.reloadUserCalls, 1);
        expect(find.byType(VerifyEmailScreen), findsOneWidget);

        // Simulasikan link verifikasi sudah diklik di email
        service.verifyOnReload = true;
        await tester.ensureVisible(find.byTooltip('Saya sudah verifikasi'));
        await tester.tap(find.byTooltip('Saya sudah verifikasi'));
        await tester.pumpAndSettle();

        expect(find.byType(MainShell), findsOneWidget);
        expect(find.byType(VerifyEmailScreen), findsNothing);
      },
    );

    testWidgets(
      'profil menampilkan email Google dan nama dari prefix email, bukan Zidan statis',
      (WidgetTester tester) async {
        final FakeAuthService service = FakeAuthService(
          initialUser: const AuthUser(
            uid: 'google-uid',
            email: 'siti.rahma@gmail.com',
            displayName: 'Siti Rahma',
            emailVerified: true,
          ),
        );
        await pumpAuthApp(
          tester,
          isLoggedIn: true,
          initialLocation: '/profile',
          service: service,
        );

        expect(find.byType(ProfileScreen), findsOneWidget);
        expect(find.text('siti.rahma@gmail.com'), findsOneWidget);
        expect(find.text('Siti Rahma'), findsOneWidget);
        expect(find.text('zidan@aturaja.id'), findsNothing);
        expect(find.text('M Zidan Ruriano A.G'), findsNothing);
      },
    );
  });

  group('Profil otomatis dari email', () {
    test('nameFromEmail memformat prefix email dengan rapi', () {
      expect(
        ProfileData.nameFromEmail('budi.santoso@gmail.com'),
        'Budi Santoso',
      );
      expect(
        ProfileData.nameFromEmail('siti_rahma-putri@kampus.id'),
        'Siti Rahma Putri',
      );
      expect(
        ProfileData.nameFromEmail('ahmad+test@gmail.com'),
        'Ahmad',
      );
      expect(ProfileData.nameFromEmail(''), '');
    });

    test('syncProfileWithAuthEmail mengganti profil kosong dan placeholder Zidan', () {
      final AppProvider app = AppProvider.inMemory(
        profile: ProfileData.initial,
        activeUserId: 'google-uid',
      );
      addTearDown(app.dispose);

      final bool changed = app.syncProfileWithAuthEmail('dewi.lestari@gmail.com');

      expect(changed, isTrue);
      expect(app.profile.email, 'dewi.lestari@gmail.com');
      expect(app.profile.fullName, 'Dewi Lestari');
      expect(app.profile.avatarLabel, 'DL');
    });

    test('syncProfileWithAuthEmail mempertahankan nama yang sudah diubah user', () {
      final AppProvider app = AppProvider.inMemory(
        profile: const ProfileData(
          fullName: 'Dewi Kustom',
          email: 'dewi.lestari@gmail.com',
          avatarLabel: 'DK',
        ),
        activeUserId: 'google-uid',
      );
      addTearDown(app.dispose);

      final bool changed = app.syncProfileWithAuthEmail('dewi.lestari@gmail.com');

      expect(changed, isFalse);
      expect(app.profile.fullName, 'Dewi Kustom');
      expect(app.profile.email, 'dewi.lestari@gmail.com');
    });
  });
}
