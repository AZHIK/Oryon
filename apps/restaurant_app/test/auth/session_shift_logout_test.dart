/// End-shift vs logout session semantics.
///
/// - `endShift()` kills only the *offline* session (locks the till, keeps the
///   online tokens/session so a PIN unlock resumes without a new OTP login).
/// - `logout()` kills both the *online* session (backend revoke best-effort +
///   cleared tokens) and the *offline* session.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:restaurant_pos/models/session.dart';
import 'package:restaurant_pos/providers/auth_provider.dart';
import 'package:restaurant_pos/providers/session_provider.dart';

import '../test_helpers/test_container.dart';

SessionState _signedIn() => const SessionState(
  savedProfileIds: ['stf-01'],
  activeStaffId: 'stf-01',
  isLoggedIn: true,
  pin: '246813',
  isUnlocked: true,
  hasCompletedOnboarding: true,
  bootstrapped: true,
);

void main() {
  group('endShift (offline only)', () {
    test('locks the till but keeps the login and profile', () {
      final container = newTestContainer();
      container.read(sessionProvider.notifier).state = _signedIn();

      container.read(sessionProvider.notifier).endShift();

      final session = container.read(sessionProvider);
      expect(session.isUnlocked, isFalse);
      expect(session.isLoggedIn, isTrue);
      expect(session.activeStaffId, 'stf-01');
      expect(session.entryRoute, '/auth/unlock');
    });
  });

  group('logout (online + offline)', () {
    test('drops the local session and resets auth state', () async {
      final container = newTestContainer();
      container.read(sessionProvider.notifier).state = _signedIn();

      await container.read(sessionProvider.notifier).logout();

      final session = container.read(sessionProvider);
      expect(session.isLoggedIn, isFalse);
      expect(session.isUnlocked, isFalse);
      expect(session.activeStaffId, isNull);
      // Logout deactivates and removes this profile from the picker.
      expect(session.hasSavedProfiles, isFalse);
      expect(session.entryRoute, '/auth/login');

      final auth = container.read(authProvider);
      expect(auth.state, AuthState.unauthenticated);
      expect(auth.accessToken, isNull);
      expect(auth.refreshToken, isNull);
    });
  });
}
