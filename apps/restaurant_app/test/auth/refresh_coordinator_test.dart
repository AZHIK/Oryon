import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:restaurant_pos/auth/identity_service_api.dart';
import 'package:restaurant_pos/auth/refresh_coordinator.dart';
import 'package:restaurant_pos/auth/token_storage.dart';

/// Counts refresh calls and rotates the pair like the real backend. The small
/// delay keeps both callers in flight together, which is the race under test.
class _RefreshAdapter implements HttpClientAdapter {
  int refreshCalls = 0;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (!options.path.endsWith('/auth/refresh')) {
      return ResponseBody.fromString('', 404);
    }

    refreshCalls++;
    final call = refreshCalls;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return ResponseBody.fromString(
      jsonEncode({
        'access_token': 'access-$call',
        'refresh_token': 'refresh-$call',
        'token_type': 'bearer',
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  late Map<String, String> values;

  setUp(() {
    values = {};
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
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('current-session and per-user refreshes share one rotation', () async {
    final storage = TokenStorage();
    await storage.saveTokenSet(
      TokenSet(
        accessToken: 'access-old',
        refreshToken: 'refresh-old',
        expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
        userId: 'user-1',
      ),
    );

    final adapter = _RefreshAdapter();
    final api = IdentityServiceApi(
      dio: Dio()..httpClientAdapter = adapter,
    );

    // Mirrors the cold-start (explicit user id) and 401-interceptor (current
    // session) paths firing together against the same stored token.
    final results = await Future.wait([
      refreshTokens(api: api, storage: storage),
      refreshTokens(api: api, storage: storage, userId: 'user-1'),
    ]);

    expect(adapter.refreshCalls, 1);
    expect(results[0].accessToken, 'access-1');
    expect(results[1].accessToken, 'access-1');
    expect(results[0].refreshToken, 'refresh-1');

    final stored = await storage.getTokenSet();
    expect(stored?.accessToken, 'access-1');
    expect(stored?.refreshToken, 'refresh-1');
  });
}
