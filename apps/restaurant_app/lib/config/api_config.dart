/// Backend base URLs, centralized so they aren't duplicated (and drift)
/// across every Dio provider.
///
/// Local development uses the host ports each service's `docker-compose.yml`
/// publishes. Release builds must pass all three URLs at build time:
///
/// ```sh
/// flutter build apk \
///   --dart-define=IDENTITY_API_BASE_URL=https://auth.example.com/api/v1 \
///   --dart-define=INVENTORY_API_BASE_URL=https://inventory.example.com/api/v1 \
///   --dart-define=POS_API_BASE_URL=https://pos.example.com/api/v1
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

  static String get identityServiceBaseUrl => _resolve(
    name: 'IDENTITY_API_BASE_URL',
    override: _identityOverride,
    localDefault: 'http://localhost:8009/api/v1',
  );

  static String get inventoryServiceBaseUrl => _resolve(
    name: 'INVENTORY_API_BASE_URL',
    override: _inventoryOverride,
    localDefault: 'http://localhost:8100/api/v1',
  );

  static String get posServiceBaseUrl => _resolve(
    name: 'POS_API_BASE_URL',
    override: _posOverride,
    localDefault: 'http://localhost:8200/api/v1',
  );

  static String _resolve({
    required String name,
    required String override,
    required String localDefault,
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
      return localDefault;
    }

    throw StateError(
      '$name is not set. Release builds must pass it with --dart-define.',
    );
  }
}
