import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:restaurant_pos/auth/jwt_decoder.dart';
import 'package:restaurant_pos/constants/app_strings.dart';
import 'package:restaurant_pos/database/app_database.dart';
import 'package:restaurant_pos/database/local_profile_repository.dart';
import 'package:restaurant_pos/main.dart';
import 'package:restaurant_pos/models/session.dart';
import 'package:restaurant_pos/providers/auth_provider.dart';
import 'package:restaurant_pos/providers/connectivity_provider.dart';
import 'package:restaurant_pos/providers/database_providers.dart';
import 'package:restaurant_pos/providers/session_provider.dart';
import 'package:restaurant_pos/router/app_router.dart';
import 'package:restaurant_pos/screens/auth/onboarding_screen.dart';
import 'package:restaurant_pos/screens/auth/otp_login_screen.dart';
import 'package:restaurant_pos/screens/auth/pin_unlock_screen.dart';
import 'package:restaurant_pos/screens/auth/set_pin_screen.dart';
import 'package:restaurant_pos/utils/phone_validation.dart';
import 'package:restaurant_pos/utils/pin_hasher.dart';

import 'test_helpers/fake_identity_backend.dart';

/// `TokenStorage` (used by `AuthNotifier`, real in every build — there's no
/// Riverpod seam to inject a fake) talks to `flutter_secure_storage`'s
/// platform channel directly, which has no built-in test double. Any test
/// reaching `_switchContextAndLock` (real OTP login, business onboarding)
/// needs this backed by something, so call this once per test — from
/// `pumpSession` or directly — to install an in-memory stand-in.
void mockSecureStorage() {
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final values = <String, String>{};
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
        final args =
            (call.arguments as Map?)?.cast<String, dynamic>() ?? const {};
        switch (call.method) {
          case 'write':
            values[args['key'] as String] = args['value'] as String;
            return null;
          case 'read':
            return values[args['key'] as String];
          case 'delete':
            values.remove(args['key'] as String);
            return null;
          case 'deleteAll':
            values.clear();
            return null;
          case 'readAll':
            return Map<String, String>.from(values);
          case 'containsKey':
            return values.containsKey(args['key'] as String);
          default:
            return null;
        }
      });
  addTearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );
}

/// A local staff profile to seed into the in-memory database before a test
/// pumps the app — the record `LocalProfileRepository`/`PinUnlockScreen`'s
/// real PIN-verification path (and the Profile Picker's saved-profile names)
/// expect to already be on the device, exactly as Set PIN would have written
/// it on a previous sign-in.
class LocalProfile {
  const LocalProfile({required this.id, required this.name, this.pin});

  final String id;
  final String name;
  final String? pin;
}

/// Pumps the app with [session] as the starting state and navigates to [route].
///
/// Overriding the notifier rather than driving the UI into position keeps each
/// test about one thing — the alternative is every lockout test having to sign
/// in and fail three PINs first.
Future<ProviderContainer> pumpSession(
  WidgetTester tester, {
  required Size size,
  SessionState? session,
  String? route,
  List<Override> overrides = const [],
  // Tests that jump straight to an authenticated route via `session` skip
  // the real OTP flow entirely, so `authProvider`'s in-memory access token
  // is never populated — anything that reads it (business/staff/role
  // calls, all gated behind a real token) needs it seeded by hand here.
  String? authAccessToken,
  List<LocalProfile> localProfiles = const [],
}) async {
  tester.view.physicalSize = size * tester.view.devicePixelRatio;
  addTearDown(tester.view.reset);
  mockSecureStorage();

  // `authProvider`'s build() reaches `appDatabaseProvider` (via
  // `localProfileRepositoryProvider`) to restore any saved local profile —
  // real in production because `main.dart` always overrides it, but every
  // screen that shows staff/role/permission info now watches `authProvider`
  // too (for the current user's decoded token), so any route reachable here
  // needs a working database, not just the tests that log in explicitly.
  final database = AppDatabase(NativeDatabase.memory());
  addTearDown(database.close);

  final profileRepo = LocalProfileRepository(database);
  for (final profile in localProfiles) {
    final salt = PinHasher.generateSalt();
    final now = DateTime.now();
    await profileRepo.upsertProfile(
      LocalUserProfilesCompanion.insert(
        id: profile.id,
        displayName: profile.name,
        pinHash: profile.pin == null ? '' : PinHasher.hash(profile.pin!, salt),
        pinSalt: salt,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  final container = ProviderContainer(
    overrides: [appDatabaseProvider.overrideWithValue(database), ...overrides],
  );
  addTearDown(container.dispose);

  if (session != null) {
    container.read(sessionProvider.notifier).state = session;
  }
  if (authAccessToken != null) {
    container.read(authProvider.notifier).state = AuthContext(
      state: AuthState.complete,
      accessToken: authAccessToken,
      userId: decodeAccessToken(authAccessToken).sub,
    );
  }

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const RestaurantPosApp(),
    ),
  );
  await tester.pumpAndSettle();

  if (route != null) {
    container.read(goRouterProvider).go(route);
    await tester.pumpAndSettle();
  }
  return container;
}

String _locationOf(ProviderContainer container) => container
    .read(goRouterProvider)
    .routerDelegate
    .currentConfiguration
    .uri
    .path;

void main() {
  group('Session routing', () {
    test('entryRoute names one destination per state', () {
      const fresh = SessionState();
      expect(fresh.entryRoute, '/auth/login');

      const withProfiles = SessionState(savedProfileIds: ['stf-01']);
      expect(withProfiles.entryRoute, '/auth/profiles');

      const noPin = SessionState(isLoggedIn: true);
      expect(noPin.entryRoute, '/auth/set-pin');

      const locked = SessionState(isLoggedIn: true, pin: '246813');
      expect(locked.entryRoute, '/auth/unlock');

      const needsOnboarding = SessionState(
        isLoggedIn: true,
        pin: '246813',
        isUnlocked: true,
      );
      expect(needsOnboarding.entryRoute, '/auth/onboarding');

      expect(SessionNotifier.seed.entryRoute, '/dashboard');
    });

    testWidgets('the splash holds until its brand moment finishes', (
      tester,
    ) async {
      tester.view.physicalSize =
          const Size(1440, 900) * tester.view.devicePixelRatio;
      addTearDown(tester.view.reset);

      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const RestaurantPosApp(),
        ),
      );

      // One frame in: still on the splash, and the session has not bootstrapped.
      await tester.pump();
      expect(container.read(sessionProvider).bootstrapped, isFalse);
      expect(_locationOf(container), AppRoute.splashPath);

      await tester.pumpAndSettle();
      expect(container.read(sessionProvider).bootstrapped, isTrue);
      expect(_locationOf(container), AppRoute.loginPath);
    });

    testWidgets('a locked session is bounced off a protected route', (
      tester,
    ) async {
      final container = await pumpSession(
        tester,
        size: const Size(1440, 900),
        session: const SessionState(
          savedProfileIds: ['stf-01'],
          activeStaffId: 'stf-01',
          isLoggedIn: true,
          pin: '246813',
          hasCompletedOnboarding: true,
          bootstrapped: true,
        ),
        route: AppRoute.inventoryPath,
      );

      expect(_locationOf(container), AppRoute.unlockPath);
    });

    testWidgets('a signed-out device with profiles lands on the picker', (
      tester,
    ) async {
      final container = await pumpSession(
        tester,
        size: const Size(1440, 900),
        session: const SessionState(
          savedProfileIds: ['stf-01', 'stf-02'],
          bootstrapped: true,
        ),
        route: AppRoute.dashboardPath,
      );

      expect(_locationOf(container), AppRoute.profilesPath);
    });

    testWidgets('a fresh device with no profiles lands on login', (
      tester,
    ) async {
      final container = await pumpSession(
        tester,
        size: const Size(1440, 900),
        session: const SessionState(bootstrapped: true),
        route: AppRoute.salesPath,
      );

      expect(_locationOf(container), AppRoute.loginPath);
    });

    testWidgets('an unlocked session reaches the shell untouched', (
      tester,
    ) async {
      final container = await pumpSession(
        tester,
        size: const Size(1440, 900),
        session: const SessionState(
          savedProfileIds: ['stf-01'],
          activeStaffId: 'stf-01',
          isLoggedIn: true,
          pin: '246813',
          isUnlocked: true,
          hasCompletedOnboarding: true,
          bootstrapped: true,
        ),
        route: AppRoute.inventoryPath,
      );

      expect(_locationOf(container), AppRoute.inventoryPath);
    });

    testWidgets('locking the till puts the guard back up', (tester) async {
      final container = await pumpSession(
        tester,
        size: const Size(1440, 900),
        session: const SessionState(
          savedProfileIds: ['stf-01'],
          activeStaffId: 'stf-01',
          isLoggedIn: true,
          pin: '246813',
          isUnlocked: true,
          hasCompletedOnboarding: true,
          bootstrapped: true,
        ),
        route: AppRoute.dashboardPath,
      );
      expect(_locationOf(container), AppRoute.dashboardPath);

      container.read(sessionProvider.notifier).lock();
      await tester.pumpAndSettle();

      expect(_locationOf(container), AppRoute.unlockPath);
    });
  });

  group('Profile picker', () {
    testWidgets('picking a profile arms the unlock screen for that person', (
      tester,
    ) async {
      final container = await pumpSession(
        tester,
        size: const Size(1440, 900),
        session: const SessionState(
          savedProfileIds: ['stf-01', 'stf-02'],
          bootstrapped: true,
        ),
        route: AppRoute.profilesPath,
        localProfiles: const [
          LocalProfile(id: 'stf-01', name: 'Ava Mensah'),
          LocalProfile(id: 'stf-02', name: 'Marco Ferreira'),
        ],
      );

      await tester.tap(find.text('Marco Ferreira'));
      await tester.pumpAndSettle();

      final session = container.read(sessionProvider);
      expect(session.activeStaffId, 'stf-02');
      expect(session.isUnlocked, isFalse);
      expect(_locationOf(container), AppRoute.unlockPath);
      expect(container.read(sessionStaffProvider)?.name, 'Marco Ferreira');
    });
  });

  group('OTP login', () {
    /// The identity-service backend is real in the running app — these
    /// widget tests stand in a fake [HttpClientAdapter] (see
    /// `test_helpers/fake_identity_backend.dart`) instead of hitting a live
    /// server, by overriding [identityServiceDioProvider].
    List<Override> fakeBackend(FakeIdentityBackendState state) => [
      identityServiceDioProvider.overrideWithValue(
        Dio()..httpClientAdapter = FakeIdentityAdapter(state),
      ),
    ];

    testWidgets('a short number is refused before any code is sent', (
      tester,
    ) async {
      await pumpSession(
        tester,
        size: const Size(1440, 900),
        session: const SessionState(bootstrapped: true),
        route: AppRoute.loginPath,
        overrides: fakeBackend(FakeIdentityBackendState()),
      );

      await tester.tap(find.byKey(OtpLoginKeys.usePhoneInstead));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(OtpLoginKeys.sendCode));
      await tester.pumpAndSettle();
      expect(find.text('Enter your phone number'), findsOneWidget);

      await tester.enterText(find.byKey(OtpLoginKeys.phone), '123');
      await tester.tap(find.byKey(OtpLoginKeys.sendCode));
      await tester.pumpAndSettle();
      expect(find.text(tanzanianPhoneHint), findsOneWidget);

      // Still on the phone step — the boxes only exist once a code is sent.
      expect(find.byKey(OtpLoginKeys.digit(0)), findsNothing);
    });

    testWidgets(
      'requesting a code while offline says a connection is required',
      (tester) async {
        final state = FakeIdentityBackendState();
        await pumpSession(
          tester,
          size: const Size(1440, 900),
          session: const SessionState(bootstrapped: true),
          route: AppRoute.loginPath,
          overrides: [
            ...fakeBackend(state),
            isOnlineProvider.overrideWith((ref) => Stream.value(false)),
          ],
        );

        await tester.enterText(
          find.byKey(OtpLoginKeys.email),
          'staff@example.com',
        );
        await tester.tap(find.byKey(OtpLoginKeys.sendCode));
        await tester.pumpAndSettle();

        expect(find.text(AppStrings.otpNeedsInternet), findsOneWidget);
        expect(find.byKey(OtpLoginKeys.digit(0)), findsNothing);
        expect(state.email, isNull);

        // Same guard on the phone channel, which talks to a different endpoint.
        await tester.tap(find.byKey(OtpLoginKeys.usePhoneInstead));
        await tester.pumpAndSettle();

        await tester.enterText(find.byKey(OtpLoginKeys.phone), '712345678');
        await tester.tap(find.byKey(OtpLoginKeys.sendCode));
        await tester.pumpAndSettle();

        expect(find.text(AppStrings.otpNeedsInternet), findsOneWidget);
        expect(find.byKey(OtpLoginKeys.digit(0)), findsNothing);
      },
    );

    testWidgets('verifying while offline says a connection is required', (
      tester,
    ) async {
      final connectivity = StreamController<bool>();
      addTearDown(connectivity.close);
      final container = await pumpSession(
        tester,
        size: const Size(1440, 900),
        session: const SessionState(bootstrapped: true),
        route: AppRoute.loginPath,
        overrides: [
          ...fakeBackend(FakeIdentityBackendState()),
          isOnlineProvider.overrideWith((ref) => connectivity.stream),
        ],
      );

      await tester.enterText(
        find.byKey(OtpLoginKeys.email),
        'staff@example.com',
      );
      await tester.tap(find.byKey(OtpLoginKeys.sendCode));
      await tester.pumpAndSettle();
      expect(find.byKey(OtpLoginKeys.digit(0)), findsOneWidget);

      connectivity.add(false);
      await tester.pump();
      for (var i = 0; i < fakeOtpCode.length; i++) {
        await tester.enterText(
          find.byKey(OtpLoginKeys.digit(i)),
          fakeOtpCode[i],
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.otpNeedsInternet), findsOneWidget);
      expect(container.read(sessionProvider).isLoggedIn, isFalse);

      await tester.pump(const Duration(seconds: 31));
    });

    testWidgets('a valid number opens the code step with a live cooldown', (
      tester,
    ) async {
      await pumpSession(
        tester,
        size: const Size(1440, 900),
        session: const SessionState(bootstrapped: true),
        route: AppRoute.loginPath,
        overrides: fakeBackend(FakeIdentityBackendState()),
      );

      await tester.tap(find.byKey(OtpLoginKeys.usePhoneInstead));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(OtpLoginKeys.phone), '712345678');
      await tester.tap(find.byKey(OtpLoginKeys.sendCode));
      await tester.pumpAndSettle();

      expect(find.byKey(OtpLoginKeys.digit(0)), findsOneWidget);
      expect(find.byKey(OtpLoginKeys.digit(5)), findsOneWidget);
      expect(find.text('Resend code in 30s'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Resend code in 29s'), findsOneWidget);

      // Wind the cooldown out so no timer outlives the test.
      await tester.pump(const Duration(seconds: 30));
      expect(find.byKey(OtpLoginKeys.resend), findsOneWidget);
    });

    testWidgets('a code other than the correct one is rejected', (
      tester,
    ) async {
      final container = await pumpSession(
        tester,
        size: const Size(1440, 900),
        session: const SessionState(bootstrapped: true),
        route: AppRoute.loginPath,
        overrides: fakeBackend(FakeIdentityBackendState()),
      );

      await tester.tap(find.byKey(OtpLoginKeys.usePhoneInstead));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(OtpLoginKeys.phone), '712345678');
      await tester.tap(find.byKey(OtpLoginKeys.sendCode));
      await tester.pumpAndSettle();

      for (var i = 0; i < 6; i++) {
        await tester.enterText(find.byKey(OtpLoginKeys.digit(i)), '0');
        await tester.pump();
      }
      await tester.pumpAndSettle();

      expect(
        find.text('That code is not right. Check your messages.'),
        findsOneWidget,
      );
      expect(container.read(sessionProvider).isLoggedIn, isFalse);

      await tester.pump(const Duration(seconds: 31));
    });

    testWidgets('an invalid email is refused before any code is sent', (
      tester,
    ) async {
      await pumpSession(
        tester,
        size: const Size(1440, 900),
        session: const SessionState(bootstrapped: true),
        route: AppRoute.loginPath,
        overrides: fakeBackend(FakeIdentityBackendState()),
      );

      expect(find.byKey(OtpLoginKeys.email), findsOneWidget);

      await tester.enterText(find.byKey(OtpLoginKeys.email), 'not-an-email');
      await tester.tap(find.byKey(OtpLoginKeys.sendCode));
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid email address'), findsOneWidget);
      expect(find.byKey(OtpLoginKeys.digit(0)), findsNothing);
    });

    testWidgets('an email code signs in through the same guard hand-off', (
      tester,
    ) async {
      final container = await pumpSession(
        tester,
        size: const Size(1440, 900),
        session: const SessionState(bootstrapped: true),
        route: AppRoute.loginPath,
        overrides: fakeBackend(FakeIdentityBackendState()),
      );

      await tester.enterText(
        find.byKey(OtpLoginKeys.email),
        'staff@example.com',
      );
      await tester.tap(find.byKey(OtpLoginKeys.sendCode));
      await tester.pumpAndSettle();

      expect(find.byKey(OtpLoginKeys.digit(0)), findsOneWidget);
      expect(find.text('We emailed you a 6-digit code'), findsOneWidget);

      for (var i = 0; i < fakeOtpCode.length; i++) {
        await tester.enterText(
          find.byKey(OtpLoginKeys.digit(i)),
          fakeOtpCode[i],
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();

      final session = container.read(sessionProvider);
      expect(session.isLoggedIn, isTrue);
      expect(_locationOf(container), AppRoute.setPinPath);

      await tester.pump(const Duration(seconds: 31));
    });

    testWidgets('the correct code signs in and hands off to the guard', (
      tester,
    ) async {
      final container = await pumpSession(
        tester,
        size: const Size(1440, 900),
        session: const SessionState(bootstrapped: true),
        route: AppRoute.loginPath,
        overrides: fakeBackend(FakeIdentityBackendState()),
      );

      await tester.tap(find.byKey(OtpLoginKeys.usePhoneInstead));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(OtpLoginKeys.phone), '712345678');
      await tester.tap(find.byKey(OtpLoginKeys.sendCode));
      await tester.pumpAndSettle();

      for (var i = 0; i < fakeOtpCode.length; i++) {
        await tester.enterText(
          find.byKey(OtpLoginKeys.digit(i)),
          fakeOtpCode[i],
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();

      final session = container.read(sessionProvider);
      expect(session.isLoggedIn, isTrue);
      // No PIN on this device yet, so Set PIN is the next step — not the
      // Dashboard. (The fake backend returns a non-empty full_name, so the
      // complete-profile step is skipped — that path has its own test group.)
      expect(session.hasPin, isFalse);
      expect(_locationOf(container), AppRoute.setPinPath);

      await tester.pump(const Duration(seconds: 31));
    });

    testWidgets(
      'a brand-new account with no name is sent to complete their profile',
      (tester) async {
        final state = FakeIdentityBackendState()..fullName = '';
        final container = await pumpSession(
          tester,
          size: const Size(1440, 900),
          session: const SessionState(bootstrapped: true),
          route: AppRoute.loginPath,
          overrides: fakeBackend(state),
        );

        await tester.tap(find.byKey(OtpLoginKeys.usePhoneInstead));
        await tester.pumpAndSettle();

        await tester.enterText(find.byKey(OtpLoginKeys.phone), '712345678');
        await tester.tap(find.byKey(OtpLoginKeys.sendCode));
        await tester.pumpAndSettle();

        for (var i = 0; i < fakeOtpCode.length; i++) {
          await tester.enterText(
            find.byKey(OtpLoginKeys.digit(i)),
            fakeOtpCode[i],
          );
          await tester.pump();
        }
        await tester.pumpAndSettle();

        expect(_locationOf(container), AppRoute.completeProfilePath);

        await tester.pump(const Duration(seconds: 31));
      },
    );
  });

  group('Set PIN', () {
    Future<void> enter(WidgetTester tester, String digits) async {
      for (final digit in digits.split('')) {
        await tester.tap(find.widgetWithText(InkWell, digit).first);
        await tester.pump();
      }
      await tester.pumpAndSettle();
    }

    testWidgets('a mismatch clears both passes and says so', (tester) async {
      final container = await pumpSession(
        tester,
        size: const Size(1440, 900),
        session: const SessionState(isLoggedIn: true, bootstrapped: true),
        route: AppRoute.setPinPath,
        authAccessToken: fakeScopedToken(),
      );

      await enter(tester, '111111');
      await enter(tester, '222222');

      expect(find.byKey(SetPinKeys.error), findsOneWidget);
      expect(container.read(sessionProvider).hasPin, isFalse);
      // Back to the first pass, not stuck on the confirmation.
      expect(find.text('Create your PIN'), findsOneWidget);
    });

    testWidgets('a matching pair saves the PIN and moves on', (tester) async {
      final container = await pumpSession(
        tester,
        size: const Size(1440, 900),
        session: const SessionState(isLoggedIn: true, bootstrapped: true),
        route: AppRoute.setPinPath,
        authAccessToken: fakeScopedToken(),
      );

      await enter(tester, '135790');
      expect(find.text('Confirm your PIN'), findsOneWidget);

      await enter(tester, '135790');
      await tester.pumpAndSettle();

      final session = container.read(sessionProvider);
      expect(session.pin, '135790');
      expect(session.isUnlocked, isTrue);
      // Onboarding has not run on this fresh account, so that is what follows.
      expect(_locationOf(container), AppRoute.onboardingPath);
    });
  });

  group('PIN unlock', () {
    Future<void> enter(WidgetTester tester, String digits) async {
      for (final digit in digits.split('')) {
        await tester.tap(find.widgetWithText(InkWell, digit).first);
        await tester.pump();
      }
      await tester.pumpAndSettle();
    }

    SessionState lockedSession() =>
        SessionNotifier.seed.copyWith(isUnlocked: false, bootstrapped: true);

    testWidgets('the right PIN unlocks and lands on the dashboard', (
      tester,
    ) async {
      final container = await pumpSession(
        tester,
        size: const Size(1440, 900),
        session: lockedSession(),
        route: AppRoute.unlockPath,
        localProfiles: const [
          LocalProfile(id: 'stf-01', name: 'Ava Mensah', pin: '246813'),
        ],
      );

      await enter(tester, '246813');
      await tester.pumpAndSettle();

      expect(container.read(sessionProvider).isUnlocked, isTrue);
      expect(_locationOf(container), AppRoute.dashboardPath);
    });

    testWidgets('three wrong PINs lock the terminal out with a countdown', (
      tester,
    ) async {
      final container = await pumpSession(
        tester,
        size: const Size(1440, 900),
        session: lockedSession(),
        route: AppRoute.unlockPath,
        localProfiles: const [
          LocalProfile(id: 'stf-01', name: 'Ava Mensah', pin: '246813'),
        ],
      );

      await enter(tester, '000000');
      expect(find.byKey(PinUnlockKeys.error), findsOneWidget);
      expect(container.read(sessionProvider).failedAttempts, 1);

      await enter(tester, '000000');
      await enter(tester, '000000');
      await tester.pumpAndSettle();

      final session = container.read(sessionProvider);
      expect(session.failedAttempts, SessionState.maxAttempts);
      expect(session.isLockedOutAt(DateTime.now()), isTrue);

      // The keypad is gone, the lockout panel is up, and the OTP way out
      // survives the lockout.
      expect(find.byKey(PinUnlockKeys.lockout), findsOneWidget);
      expect(find.byKey(PinUnlockKeys.dots), findsNothing);
      expect(find.text('Too many attempts'), findsOneWidget);
      expect(find.byKey(PinUnlockKeys.otpFallback), findsOneWidget);

      // The counter is genuinely ticking rather than a static label.
      expect(find.text('30'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('29'), findsOneWidget);

      // And it releases itself without another key press.
      await tester.pump(const Duration(seconds: 30));
      await tester.pumpAndSettle();

      expect(container.read(sessionProvider).failedAttempts, 0);
      expect(find.byKey(PinUnlockKeys.lockout), findsNothing);
      expect(find.byKey(PinUnlockKeys.dots), findsOneWidget);
    });

    testWidgets('a locked-out entry cannot be submitted', (tester) async {
      final container = await pumpSession(
        tester,
        size: const Size(1440, 900),
        session: lockedSession().copyWith(
          failedAttempts: SessionState.maxAttempts,
          lockedUntil: DateTime.now().add(const Duration(seconds: 30)),
        ),
        route: AppRoute.unlockPath,
      );

      // Even the correct PIN is refused while the lockout stands.
      expect(
        await container.read(sessionProvider.notifier).submitPin('246813'),
        isFalse,
      );
      expect(container.read(sessionProvider).isUnlocked, isFalse);

      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();
    });
  });

  group('Business onboarding', () {
    testWidgets('continue is inert until the step is valid', (tester) async {
      await pumpSession(
        tester,
        size: const Size(1440, 900),
        session: SessionNotifier.seed.copyWith(
          hasCompletedOnboarding: false,
          bootstrapped: true,
        ),
        route: AppRoute.onboardingPath,
      );

      // An empty business name cannot advance.
      expect(
        tester.widget<FilledButton>(find.byKey(OnboardingKeys.next)).onPressed,
        isNull,
      );

      await tester.enterText(find.byKey(OnboardingKeys.businessName), 'Olive');
      await tester.pumpAndSettle();

      expect(
        tester.widget<FilledButton>(find.byKey(OnboardingKeys.next)).onPressed,
        isNotNull,
      );
      // Back is hidden on the first step.
      expect(find.byKey(OnboardingKeys.back), findsNothing);
    });
  });

  group('First-login local caching', () {
    /// Same fake backend pattern as 'OTP login' / 'Business onboarding'.
    ///
    /// These tests drive `authProvider`'s notifier methods directly against
    /// a bare `ProviderContainer` — no `pumpWidget` — rather than through the
    /// OTP/onboarding screens: the write logic under test lives entirely in
    /// `auth_provider.dart` (see `setPin` and `createBusinessAndOnboard`),
    /// so mounting the real app here would add nothing but risk (the brand
    /// panel's `google_fonts` calls do real network I/O the moment any
    /// widget builds, which has nothing to do with what's under test).
    List<Override> fakeBackend(FakeIdentityBackendState state) => [
      identityServiceDioProvider.overrideWithValue(
        Dio()..httpClientAdapter = FakeIdentityAdapter(state),
      ),
    ];

    /// Starts [action], pumps until nothing's pending, then awaits the
    /// result — awaiting [action] directly can deadlock forever in
    /// `testWidgets`' FakeAsync zone: nothing ever prompts it to drain the
    /// microtasks/timers the action itself is waiting on, since pumping
    /// only happens *after* the (never-completing) await returns.
    Future<T> pumped<T>(
      WidgetTester tester,
      Future<T> Function() action,
    ) async {
      final future = action();
      await tester.pumpAndSettle();
      return future;
    }

    /// A bare container wired the same way `pumpSession` wires
    /// `appDatabaseProvider`, minus mounting any widget.
    ProviderContainer bareContainer(List<Override> overrides) {
      mockSecureStorage();
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          ...overrides,
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    testWidgets(
      'an invited staff member caches business/role/permissions only once they set a PIN',
      (tester) async {
        // setPin() caches from the access token's roles/permissions claims
        // (see auth_provider.dart's doc comment on setPin for why: the two
        // RBAC lookup endpoints require admin-level permissions an ordinary
        // invited staff member's own role won't have). The fake backend's
        // /auth/context/switch always returns roles:['owner'],
        // permissions:['*'] once a businessId is set — a simplification,
        // not tied to any real role/permission set — so that's what a
        // signed-in invited staff member's token carries here too.
        final state = FakeIdentityBackendState()
          ..needsOnboarding = false
          ..businessId = 'biz-1'
          ..businessName = 'The Copper Fig';

        final container = bareContainer(fakeBackend(state));
        final db = container.read(appDatabaseProvider);
        final notifier = container.read(authProvider.notifier);

        await pumped(tester, () => notifier.requestOtp('712345678'));
        await pumped(tester, () => notifier.verifyOtp(fakeOtpCode));

        // Signed in and context-switched (device provisioned to biz-1
        // already), but Set PIN hasn't run yet — nothing about this staff
        // member should be cached locally until it does.
        expect(await db.select(db.cachedPermissions).get(), isEmpty);

        await pumped(tester, () => notifier.setPin('135790'));

        final cached = await db.select(db.cachedPermissions).get();
        expect(cached, hasLength(1));
        expect(cached.single.businessId, 'biz-1');
        expect(cached.single.businessLocationId, 'store-1');
        expect(cached.single.roleName, 'owner');
        expect(jsonDecode(cached.single.permissionCodes), contains('*'));
      },
    );

    testWidgets(
      'a new owner caches business/role/permissions as soon as their business is saved',
      (tester) async {
        final container = bareContainer(
          fakeBackend(FakeIdentityBackendState()),
        );
        final db = container.read(appDatabaseProvider);
        final notifier = container.read(authProvider.notifier);

        await pumped(tester, () => notifier.requestOtp('712345678'));
        await pumped(tester, () => notifier.verifyOtp(fakeOtpCode));
        await pumped(tester, () => notifier.setPin('135790'));

        // Set PIN runs before onboarding for a fresh owner (no business
        // exists yet), so nothing should be cached from this alone.
        expect(await db.select(db.cachedPermissions).get(), isEmpty);

        await pumped(
          tester,
          () => notifier.createBusinessAndOnboard(
            name: 'The Brass Olive',
            address: '12 Harbour Rd',
            phone: '',
          ),
        );

        final ownerId = container.read(authProvider).userId;
        expect(ownerId, isNotNull);

        final cached = await (db.select(
          db.cachedPermissions,
        )..where((row) => row.userId.equals(ownerId!))).getSingle();
        expect(
          cached.businessId,
          container.read(authProvider).selectedBusinessId,
        );
        expect(cached.roleName, 'owner');
      },
    );
  });
}
