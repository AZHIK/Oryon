/// Dio interceptor for automatic access token refresh.
///
/// Catches 401 responses, attempts to refresh the token using the refresh token,
/// and retries the original request with the new access token.
///
/// Uses its own bare Dio instance (no interceptors) for refresh calls to avoid
/// reentrancy issues if the refresh call itself fails with 401.
library;

import 'dart:async';

import 'package:dio/dio.dart';
import '../constants/api_paths.dart';
import '../constants/app_durations.dart';
import '../database/local_profile_repository.dart';
import 'identity_service_api.dart';
import 'permissions_cache_sync.dart';
import 'refresh_coordinator.dart';
import 'token_storage.dart';

/// Handles silent token refresh on 401 responses.
class TokenRefreshInterceptor extends Interceptor {
  final TokenStorage _tokenStorage;

  /// Optional: when given, a successful background refresh also updates
  /// the local `CachedPermissions` table (see `syncPermissionsCache`) —
  /// without this, a long session kept alive purely by this reactive
  /// refresh (no PIN unlock, no cold start) would never pick up a
  /// permission change an admin makes mid-session. Null in call sites that
  /// have no database to write to (e.g. a bare pre-login Dio client).
  final LocalProfileRepository? _profileRepo;

  /// Called after a successful cache sync so a Riverpod-aware caller can
  /// bump `permissionsCacheTickProvider` — this class has no `ref` of its
  /// own to do that directly.
  final void Function()? _onPermissionsSynced;
  late final IdentityServiceApi _api;

  /// Public endpoints whose own normal error path is a 401 unrelated to
  /// token expiry (wrong OTP code, wrong password) — refreshing and
  /// retrying these would just resend the same bad credentials and get
  /// the same 401 back, wasting a round-trip on every failed attempt.
  static const _publicAuthPaths = IdentityApiPaths.publicAuthPaths;

  // Lock to prevent multiple simultaneous refresh attempts.
  //
  // Static (process-wide), not per instance: every Dio client owns its own
  // interceptor, but they all share the one refresh token in TokenStorage.
  // The backend rotates the refresh token on each use and treats a second
  // concurrent use as token reuse — so N parallel 401s (a screen firing
  // several pulls at once) must produce exactly ONE refresh call, with the
  // losers waiting and retrying on the winner's tokens. A per-instance lock
  // lets every client refresh at once and kills the session instead.
  static bool _isRefreshing = false;
  static Future<void>? _refreshFuture;

  /// Fires when a refresh is *rejected* by the server — the session is dead
  /// and the device's tokens are cleared. The app listens once (see
  /// `sessionExpiryWatcherProvider`) to alert and route back to OTP login.
  /// Transient failures (offline, 5xx) never fire: those keep their tokens
  /// and stay silent.
  static final StreamController<void> _sessionExpiredController =
      StreamController<void>.broadcast(sync: true);

  static Stream<void> get sessionExpired => _sessionExpiredController.stream;

  TokenRefreshInterceptor({
    required this._tokenStorage,
    required String baseUrl,
    LocalProfileRepository? profileRepo,
    this._onPermissionsSynced,
  })  : _profileRepo = profileRepo {
    // Create a bare Dio instance (no interceptors) for refresh calls.
    // This prevents reentrancy if the refresh call itself fails.
    final bareDio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: AppDurations.connectTimeout,
      receiveTimeout: AppDurations.receiveTimeout,
      sendTimeout: AppDurations.sendTimeout,
    ));
    _api = IdentityServiceApi(dio: bareDio);
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Every IdentityServiceApi call that needs auth already sets its own
    // Authorization header with the exact token it was handed (e.g. the
    // freshly-issued one from /auth/otp/verify, before it's ever written to
    // TokenStorage by _switchContextAndLock). Only fall back to the stored
    // token for requests that didn't set one — overwriting an explicit
    // header here would replace a known-good token with a stale or
    // already-rotated one from a previous session.
    if (!options.headers.containsKey('Authorization')) {
      final tokenSet = await _tokenStorage.getTokenSet();
      if (tokenSet != null) {
        options.headers['Authorization'] = 'Bearer ${tokenSet.accessToken}';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // Only handle 401 Unauthorized responses.
    if (err.response?.statusCode != 401) {
      handler.next(err);
      return;
    }

    // These endpoints 401 for reasons unrelated to token expiry — refreshing
    // and retrying would just resend the same bad credentials.
    if (_publicAuthPaths.any((p) => err.requestOptions.path.contains(p))) {
      handler.next(err);
      return;
    }

    final tokenSet = await _tokenStorage.getTokenSet();
    if (tokenSet == null) {
      handler.next(err);
      return;
    }

    // A sibling client is already refreshing with the same token: wait for
    // it, then retry with whatever it stored. Never fire a second refresh
    // (see the lock's doc comment). The check-and-branch below runs with no
    // await in between, so exactly one client becomes the refresher.
    if (_isRefreshing) {
      final inFlight = _refreshFuture;
      if (inFlight != null) {
        try {
          await inFlight;
        } on DioException catch (e) {
          handler.next(e);
          return;
        }
      }
      try {
        handler.resolve(await _retry(err.requestOptions));
      } on DioException catch (e) {
        handler.next(e);
      }
      return;
    }

    // Start the single shared refresh.
    _isRefreshing = true;
    _refreshFuture = _performRefresh();
    try {
      await _refreshFuture;
    } catch (e) {
      // The session is dead (refresh rejected or storage failed — tokens
      // are already cleared by _performRefresh). Only the refresher resets
      // the lock; waiters above never touch it.
      _isRefreshing = false;
      _refreshFuture = null;
      if (e is DioException) {
        handler.next(e);
      } else {
        handler.next(
          DioException(requestOptions: err.requestOptions, error: e),
        );
      }
      return;
    }
    _isRefreshing = false;
    _refreshFuture = null;

    // Retry the original request with the new token.
    try {
      handler.resolve(await _retry(err.requestOptions));
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  /// Calls the API to refresh the access token.
  /// The backend rotates the refresh token on each refresh.
  ///
  /// The single backend call goes through [refreshTokens] (process-wide
  /// coordinator): parallel 401s share one rotation instead of replaying the
  /// same one-shot token and tripping the backend's reuse detector (which
  /// would revoke the whole session family).
  ///
  /// Only a server *rejection* (400/401/403 — invalid, expired, revoked or
  /// already-used refresh token) means the session is dead: tokens are
  /// cleared and [sessionExpired] fires so the app can alert and send the
  /// user back to OTP login. Anything else (no connection, 5xx) is
  /// transient — tokens are kept so the next attempt can still succeed, and
  /// nothing fires: going offline must never log anyone out.
  Future<void> _performRefresh() async {
    try {
      // Single flight shared with AuthNotifier's direct refreshes (cold
      // start, PIN unlock) — see refresh_coordinator.dart. The passed-in
      // token is only a fallback identity hint; the coordinator re-reads
      // the latest stored pair inside the lock.
      final fresh = await refreshTokens(api: _api, storage: _tokenStorage);

      final profileRepo = _profileRepo;
      if (profileRepo != null) {
        await syncPermissionsCache(
          profileRepo: profileRepo,
          userId: fresh.userId,
          accessToken: fresh.accessToken,
          onSynced: _onPermissionsSynced,
        );
      }
    } catch (e) {
      // Rejected by the server: the session is lost. Clear tokens and tell
      // the app, exactly once per death (the static lock guarantees only one
      // refresher runs, so this fires once no matter how many requests
      // 401'd together).
      if (_isRejection(e)) {
        await _tokenStorage.clearTokenSet();
        _sessionExpiredController.add(null);
      }
      rethrow;
    }
  }

  /// True when the refresh call itself was refused — as opposed to never
  /// reaching the server, or the server erroring. Accepts both raw
  /// [DioException] and the [AuthException] wrapper `IdentityServiceApi`
  /// converts it into (checking only `DioException` here used to silently
  /// never match, so dead sessions never surfaced).
  static bool _isRejection(Object e) {
    final int? status = switch (e) {
      DioException() => e.response?.statusCode,
      AuthException() => e.statusCode,
      _ => null,
    };
    return status == 400 || status == 401 || status == 403;
  }

  /// Retries a failed request with the new access token.
  ///
  /// Uses [requestOptions.baseUrl] — the base URL the ORIGINAL request was
  /// made against (Inventory/POS/whichever service this interceptor is
  /// attached to) — not the constructor's `baseUrl` (always Identity
  /// Service, needed only for the refresh call itself above). Retrying
  /// against Identity Service's URL would silently send a service's own
  /// request there instead, 404ing on every 401-triggered retry for any
  /// non-Identity client.
  Future<Response<dynamic>> _retry(RequestOptions requestOptions) async {
    final tokenSet = await _tokenStorage.getTokenSet();
    if (tokenSet != null) {
      requestOptions.headers['Authorization'] = 'Bearer ${tokenSet.accessToken}';
    }

    final dio = Dio(BaseOptions(baseUrl: requestOptions.baseUrl));
    return dio.request<dynamic>(
      requestOptions.path,
      options: Options(
        method: requestOptions.method,
        sendTimeout: requestOptions.sendTimeout,
        receiveTimeout: requestOptions.receiveTimeout,
        extra: requestOptions.extra,
        headers: requestOptions.headers,
        responseType: requestOptions.responseType,
        contentType: requestOptions.contentType,
        validateStatus: requestOptions.validateStatus,
        receiveDataWhenStatusError: requestOptions.receiveDataWhenStatusError,
        followRedirects: requestOptions.followRedirects,
        maxRedirects: requestOptions.maxRedirects,
      ),
      data: requestOptions.data,
      queryParameters: requestOptions.queryParameters,
    );
  }
}
