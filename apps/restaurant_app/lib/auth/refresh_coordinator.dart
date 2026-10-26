/// Process-wide coordinator for refresh-token use.
///
/// Background: the backend rotates the refresh token on EVERY use and treats
/// a second concurrent use of the same token as a replay attack
/// (`TokenReuseDetectedError` → the whole session family is revoked → every
/// later refresh 401s forever). Three components refresh independently —
/// `TokenRefreshInterceptor` (reactive 401 retry), `AuthNotifier` (cold-start
/// restore, PIN-unlock restore) and, indirectly, the provision guard (whose
/// 401s trigger the interceptor) — so without serialization two of them can
/// fire with the same one-shot token at startup and permanently kill the
/// session. A dead session means the provision guard can never verify
/// anything (`indeterminate` forever) and the app can never get online again
/// without a fresh OTP login.
///
/// Rules enforced here:
/// - exactly ONE backend refresh call is ever in flight process-wide;
///   concurrent callers share its result instead of firing their own;
/// - the token sent is always re-read from storage INSIDE the lock, so a
///   caller holding a stale captured pair transparently uses the rotated
///   pair another caller just persisted;
/// - this unit never clears storage and never interprets rejections — a 401
///   propagates to the caller, which owns the policy (interceptor:
///   clear + expire; AuthNotifier: fall back to cached offline session).
library;

import '../constants/app_durations.dart';
import 'identity_service_api.dart';
import 'token_storage.dart';

/// Process-wide in-flight refreshes, keyed by the resolved session user id.
/// Concurrent callers for the SAME session await the same future; different
/// users on a shared device refresh independently.
final Map<String, Future<TokenSet>> _flights = {};

/// Refreshes using the latest stored pair and persists the rotated result.
///
/// [userId] selects a per-user session; null means the current session.
/// Throws when there is nothing stored, when offline, or when the backend
/// rejects the token (expired/revoked/replayed) — callers decide policy.
Future<TokenSet> refreshTokens({
  required IdentityServiceApi api,
  required TokenStorage storage,
  String? userId,
}) async {
  // Resolve "current session" (null) to the stored current user id BEFORE
  // joining the flight map. Callers that do pass a userId must share the same
  // flight: the cold-start restore passes one, while the 401 interceptor does
  // not, and keying those separately let both refresh with the same one-shot
  // token — the backend read the second use as replay and revoked the whole
  // session.
  final key = userId ?? await storage.currentUserId();
  if (key == null) throw StateError('No stored session to refresh');

  final flight = _flights[key];
  if (flight != null) return flight;
  final future = _doRefresh(api: api, storage: storage, userId: key);
  _flights[key] = future;
  return future.whenComplete(() {
    if (identical(_flights[key], future)) _flights.remove(key);
  });
}

Future<TokenSet> _doRefresh({
  required IdentityServiceApi api,
  required TokenStorage storage,
  String? userId,
}) async {
  // Re-read INSIDE the shared flight: whoever refreshed just before us
  // already persisted the rotated pair, so this picks it up instead of
  // replaying the stale token we may have captured earlier.
  final stored = userId == null
      ? await storage.getTokenSet()
      : await storage.getTokenSetForUser(userId);
  if (stored == null) throw StateError('No stored session to refresh');
  final output = await api.refreshAccessToken(stored.refreshToken);
  final fresh = TokenSet(
    accessToken: output.accessToken,
    refreshToken: output.refreshToken,
    expiresAt: DateTime.now().add(AppDurations.sessionLifetime),
    userId: stored.userId,
  );
  await storage.saveTokenSet(fresh);
  return fresh;
}
