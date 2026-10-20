/// Email-first signup parity: the same local profile row a phone-first
/// signup gets must be created for an account that signs up with an email
/// address, and the address must survive the complete-profile step.
library;

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:restaurant_pos/database/app_database.dart';
import 'package:restaurant_pos/providers/auth_provider.dart';
import 'package:restaurant_pos/providers/database_providers.dart';
import 'package:restaurant_pos/providers/session_provider.dart';

import '../test_helpers/fake_identity_backend.dart';
import '../test_helpers/test_container.dart';

Map<String, String> _mockSecureStorage() {
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final values = <String, String>{};
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
    final args = (call.arguments as Map?)?.cast<String, dynamic>() ?? const {};
    switch (call.method) {
      case 'write':
        values[args['key'] as String] = args['value'] as String;
        return null;
      case 'read':
        return values[args['key'] as String];
      case 'delete':
        values.remove(args['key'] as String);
        return null;
      default:
        return null;
    }
  });
  addTearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );
  return values;
}

ProviderContainer _containerWithBackend(
  FakeIdentityBackendState backendState, {
  Dio? dio,
  AppDatabase? database,
}) {
  final client = dio ??
      (Dio(BaseOptions(baseUrl: 'http://localhost'))
        ..httpClientAdapter = FakeIdentityAdapter(backendState));
  return newTestContainer(
    database: database,
    extraOverrides: [
      identityServiceDioProvider.overrideWithValue(client),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('email signup creates the local profile row like the phone flow',
      () async {
    _mockSecureStorage();

    // Fresh email-first account: no name yet, no business yet.
    final backendState = FakeIdentityBackendState()
      ..fullName = ''
      ..needsOnboarding = true;
    final container = _containerWithBackend(backendState);

    const email = 'new-owner@example.com';

    // 1. Email OTP signup.
    await container.read(sessionProvider.notifier).requestEmailOtp(email);
    await container
        .read(sessionProvider.notifier)
        .completeEmailOtpLogin(fakeOtpCode);

    final userId = container.read(authProvider).userId;
    expect(userId, isNotNull);
    expect(container.read(authProvider).email, email);

    // 2. Complete profile — the screen omits the email field for email
    // signups but offers an optional phone number.
    const phone = '+255712345678';
    await container.read(authProvider.notifier).completeProfile(
          fullName: 'Email Owner',
          phone: phone,
        );

    // The signup address must not be cleared as a side effect, and the new
    // phone is recorded on the account.
    expect(backendState.email, email);
    expect(backendState.phone, phone);

    final repo = container.read(localProfileRepositoryProvider);
    final afterProfile = await repo.getProfile(userId!);
    expect(afterProfile, isNotNull,
        reason: 'complete-profile must create the local profile row');
    expect(afterProfile!.displayName, 'Email Owner');

    // 3. Set PIN fills in the row, exactly like the phone-first path.
    await container.read(sessionProvider.notifier).setPin('246810');
    final afterPin = await repo.getProfile(userId);
    expect(afterPin!.pinHash, isNotEmpty);
    expect(afterPin.displayName, 'Email Owner');

    // The profile is offered on the local picker after this device starts
    // serving this account.
    final saved = await repo.activeProfiles();
    expect(saved.map((row) => row.id), contains(userId));
  });

  test('restart between Complete Profile and Set PIN still allows Set PIN',
      () async {
    _mockSecureStorage();

    final backendState = FakeIdentityBackendState()
      ..fullName = ''
      ..needsOnboarding = true;
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost'))
      ..httpClientAdapter = FakeIdentityAdapter(backendState);

    // --- Session 1: sign up, save name, then "close the app" before PIN. ---
    final first = _containerWithBackend(
      backendState,
      dio: dio,
      database: database,
    );
    await first.read(sessionProvider.notifier).requestEmailOtp('restart@example.com');
    await first
        .read(sessionProvider.notifier)
        .completeEmailOtpLogin(fakeOtpCode);
    await first.read(authProvider.notifier).completeProfile(
          fullName: 'Restart User',
        );
    final userId = first.read(authProvider).userId!;
    expect(
      (await first.read(localProfileRepositoryProvider).getProfile(userId))!.pinHash,
      isEmpty,
    );

    // --- Session 2: cold start over the same DB + secure storage. ---
    final second = _containerWithBackend(
      backendState,
      dio: dio,
      database: database,
    );
    // Let the cold-start restore settle, then select the unfinished profile
    // exactly like the picker does.
    second.read(authProvider);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await second.read(sessionProvider.notifier).loadSavedProfiles();
    await second.read(sessionProvider.notifier).selectProfile(userId);

    // The stored session must be recoverable, otherwise setPin has no token.
    expect(second.read(authProvider).accessToken, isNotNull);

    await second.read(sessionProvider.notifier).setPin('246810');
    final row =
        await second.read(localProfileRepositoryProvider).getProfile(userId);
    expect(row!.pinHash, isNotEmpty);
    expect(row.displayName, 'Restart User');
  });
}
