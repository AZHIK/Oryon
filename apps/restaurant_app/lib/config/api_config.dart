/// Backend base URLs, centralized so they aren't duplicated (and drift)
/// across every Dio provider.
///
/// Debug builds default to the deployed Oryon Foods APIs so the app can be
/// tested against the VPS without extra flags:
///
/// ```sh
/// flutter run -d linux
/// ```
///
/// For local development, opt into the Docker Compose ports:
///
/// ```sh
/// flutter run -d linux --dart-define=API_ENV=local
/// ```
///
/// Explicit service URL overrides win over both defaults. Release builds still
/// require all three URLs at build time and reject non-HTTPS values:
///
/// ```sh
/// flutter build apk \
///   --dart-define=IDENTITY_API_BASE_URL=https://auth.oryonfoods.com/api/v1 \
///   --dart-define=INVENTORY_API_BASE_URL=https://inventory.oryonfoods.com/api/v1 \
///   --dart-define=POS_API_BASE_URL=https://pos.oryonfoods.com/api/v1
/// ```
///
/// A release build without them fails immediately instead of silently
/// shipping `http://localhost` to real users (SEC-05).
library;

import 'package:flutter/foundation.dart';

abstract final class ApiConfig {
  static const _identityOverride = String.fromEnvironment(
    'IDENTITY_API_BASE_URL',
  );
  static const _inventoryOverride = String.fromEnvironment(
    'INVENTORY_API_BASE_URL',
  );
  static const _posOverride = String.fromEnvironment('POS_API_BASE_URL');

  /// `production` (default) or `local`. Explicit service URL defines always win.
  static const _apiEnvironment = String.fromEnvironment(
    'API_ENV',
    defaultValue: 'production',
  );

  static const _productionIdentity = 'https://auth.oryonfoods.com/api/v1';
  static const _productionInventory = 'https://inventory.oryonfoods.com/api/v1';
  static const _productionPos = 'https://pos.oryonfoods.com/api/v1';

  static const _localIdentity = 'http://localhost:8009/api/v1';
  static const _localInventory = 'http://localhost:8100/api/v1';
  static const _localPos = 'http://localhost:8200/api/v1';

  /// Tests must never reach the deployed APIs. `test/flutter_test_config.dart`
  /// turns this on before any test suite runs.
  @visibleForTesting
  static bool useLocalDefaultsForTests = false;

  static bool get _useLocalDefaults =>
      _apiEnvironment == 'local' || useLocalDefaultsForTests;

  static String get identityServiceBaseUrl => _resolve(
    name: 'IDENTITY_API_BASE_URL',
    override: _identityOverride,
    defaultBaseUrl: _useLocalDefaults ? _localIdentity : _productionIdentity,
  );

  static String get inventoryServiceBaseUrl => _resolve(
    name: 'INVENTORY_API_BASE_URL',
    override: _inventoryOverride,
    defaultBaseUrl: _useLocalDefaults ? _localInventory : _productionInventory,
  );

  static String get posServiceBaseUrl => _resolve(
    name: 'POS_API_BASE_URL',
    override: _posOverride,
    defaultBaseUrl: _useLocalDefaults ? _localPos : _productionPos,
  );

  static String _resolve({
    required String name,
    required String override,
    required String defaultBaseUrl,
  }) {
    if (override.isNotEmpty) {
      final uri = Uri.tryParse(override);
      if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
        throw StateError('$name is not a valid absolute URL: $override');
      }
      if (kReleaseMode && uri.scheme != 'https') {
        throw StateError('$name must use https:// in release builds');
      }
      return override;
    }

    if (!kReleaseMode) {
      return defaultBaseUrl;
    }

    throw StateError(
      '$name is not set. Release builds must pass it with --dart-define.',
    );
  }
}
