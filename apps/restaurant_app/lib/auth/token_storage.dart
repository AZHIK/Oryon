/// Persistent storage for access/refresh tokens and auth metadata.
///
/// Uses flutter_secure_storage for sensitive token data.
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants/app_durations.dart';

/// Holds access token, refresh token, and related metadata.
class TokenSet {
  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
  final String userId;

  TokenSet({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.userId,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  bool get isExpiringSoon =>
      DateTime.now().isAfter(expiresAt.subtract(AppDurations.tokenRefreshSkew));
}

/// Manages persistent storage of auth tokens via secure storage.
/// Supports per-user tokens for multi-user device scenarios.
class TokenStorage {
  final FlutterSecureStorage _storage;

  TokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _keyAccessToken = 'auth_access_token';
  static const _keyRefreshToken = 'auth_refresh_token';
  static const _keyExpiresAt = 'auth_expires_at';
  static const _keyUserId = 'auth_user_id';

  /// Points `getTokenSet()`/`clearTokenSet()` at whichever user's per-user
  /// keys are "the" active session, so callers that don't carry a userId
  /// around (the request interceptor, cold-start restore) can still resolve
  /// the right tokens instead of reading keys nothing writes.
  static const _keyCurrentUserId = 'auth_current_user_id';

  /// Per-user key prefixes for multi-user support.
  String _userKey(String key, String userId) => '${key}_$userId';

  /// Saves a token set persistently for a specific user, and marks them as
  /// the current session for `getTokenSet()`.
  Future<void> saveTokenSet(TokenSet tokenSet) async {
    await Future.wait([
      _storage.write(
        key: _userKey(_keyAccessToken, tokenSet.userId),
        value: tokenSet.accessToken,
      ),
      _storage.write(
        key: _userKey(_keyRefreshToken, tokenSet.userId),
        value: tokenSet.refreshToken,
      ),
      _storage.write(
        key: _userKey(_keyExpiresAt, tokenSet.userId),
        value: tokenSet.expiresAt.toIso8601String(),
      ),
      _storage.write(key: _userKey(_keyUserId, tokenSet.userId), value: tokenSet.userId),
      _storage.write(key: _keyCurrentUserId, value: tokenSet.userId),
    ]);
  }

  /// Retrieves a saved token set for a specific user, or null if none exists.
  Future<TokenSet?> getTokenSetForUser(String userId) async {
    final accessToken = await _storage.read(key: _userKey(_keyAccessToken, userId));
    if (accessToken == null) return null;

    final refreshToken = await _storage.read(key: _userKey(_keyRefreshToken, userId));
    final expiresAtStr = await _storage.read(key: _userKey(_keyExpiresAt, userId));

    if (refreshToken == null || expiresAtStr == null) {
      return null;
    }

    return TokenSet(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: DateTime.parse(expiresAtStr),
      userId: userId,
    );
  }

  /// The user whose tokens `getTokenSet()` currently resolves to, or null
  /// when no session is stored. Used by the refresh coordinator to key a
  /// "current session" refresh under the same identity as an explicit
  /// per-user one.
  Future<String?> currentUserId() => _storage.read(key: _keyCurrentUserId);

  /// Retrieves the token set for the current session, i.e. whichever user
  /// `saveTokenSet()` last ran for. Used by callers with no userId in hand
  /// (the request interceptor's auto-attach, cold-start session restore).
  Future<TokenSet?> getTokenSet() async {
    final userId = await currentUserId();
    if (userId == null) return null;
    return getTokenSetForUser(userId);
  }

  /// Clears all stored tokens for a specific user.
  Future<void> clearTokenSetForUser(String userId) async {
    await Future.wait([
      _storage.delete(key: _userKey(_keyAccessToken, userId)),
      _storage.delete(key: _userKey(_keyRefreshToken, userId)),
      _storage.delete(key: _userKey(_keyExpiresAt, userId)),
      _storage.delete(key: _userKey(_keyUserId, userId)),
    ]);
  }

  /// Clears the current session's tokens (logout or device reset).
  Future<void> clearTokenSet() async {
    final currentUserId = await _storage.read(key: _keyCurrentUserId);
    if (currentUserId != null) {
      await clearTokenSetForUser(currentUserId);
    }
    await _storage.delete(key: _keyCurrentUserId);
  }

  /// Best-effort wipe of EVERY stored token (all users + current pointer).
  /// Used after a remotely-deleted business: per-user rows in secure storage
  /// would otherwise survive the Drift wipe as orphans. Never throws.
  Future<void> clearAllTokens() async {
    try {
      final all = await _storage.readAll();
      final keys = all.keys.where(
        (k) =>
            k == _keyCurrentUserId ||
            k.startsWith(_keyAccessToken) ||
            k.startsWith(_keyRefreshToken) ||
            k.startsWith(_keyExpiresAt) ||
            k.startsWith(_keyUserId),
      );
      await Future.wait([for (final k in keys) _storage.delete(key: k)]);
    } catch (_) {
      // Secure-storage failure must not block the local wipe.
    }
  }

  /// Updates only the access token for a user (e.g., after a refresh).
  Future<void> updateAccessToken(String userId, String accessToken, DateTime expiresAt) async {
    await Future.wait([
      _storage.write(key: _userKey(_keyAccessToken, userId), value: accessToken),
      _storage.write(
        key: _userKey(_keyExpiresAt, userId),
        value: expiresAt.toIso8601String(),
      ),
    ]);
  }

  /// Updates both access token and refresh token for a user (after token refresh/rotation).
  /// The backend rotates the refresh token on each refresh, so both must be persisted.
  Future<void> updateTokens(
    String userId,
    String accessToken,
    String refreshToken,
    DateTime expiresAt,
  ) async {
    await Future.wait([
      _storage.write(key: _userKey(_keyAccessToken, userId), value: accessToken),
      _storage.write(key: _userKey(_keyRefreshToken, userId), value: refreshToken),
      _storage.write(
        key: _userKey(_keyExpiresAt, userId),
        value: expiresAt.toIso8601String(),
      ),
    ]);
  }
}
