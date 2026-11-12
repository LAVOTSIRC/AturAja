import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:aturaja/data/settings_controller.dart';
import 'package:aturaja/main.dart';
import 'package:aturaja/providers/app_provider.dart';
import 'package:aturaja/providers/auth_provider.dart';
import 'package:aturaja/screens/login_screen.dart';
import 'package:aturaja/screens/main_shell.dart';
import 'package:aturaja/screens/register_screen.dart';
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
  });
}
