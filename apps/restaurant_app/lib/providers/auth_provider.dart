/// High-level auth orchestration: OTP login, token management, device locking.
///
/// Handles the full auth flow:
/// 1. Request OTP for phone
/// 2. Verify OTP code → get tokens
/// 3. Check onboarding status
/// 4. Either: create business (owner), switch context (invited business
///    staff), or lock straight to the assigned store (invited store staff
///    — their login token is already scoped, and context-switch rejects
///    them)
/// 5. If the business already has a store, lock the device to the primary
///    one — a business with none yet (owner still mid-onboarding) leaves
///    the device unprovisioned rather than failing the login
/// 6. Persist tokens & profile
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';

import '../auth/auth_dtos.dart';
import '../auth/identity_service_api.dart';
import '../auth/jwt_decoder.dart';
import '../auth/permissions_cache_sync.dart';
import '../auth/refresh_coordinator.dart';
import '../auth/api_log_interceptor.dart';
import '../auth/token_refresh_interceptor.dart';
import '../auth/token_storage.dart';
import '../config/api_config.dart';
import '../constants/app_durations.dart';
import '../database/app_database.dart';
import '../database/local_profile_repository.dart';
import '../sync/catalog_sync_service.dart';
import '../sync/http_inventory_catalog_api.dart';
import '../utils/pin_hasher.dart';
import 'database_providers.dart';
import 'inventory_api_provider.dart';
import 'permissions_cache_tick_provider.dart';

/// Auth flow state machine.
enum AuthState {
  unauthenticated,
  requestingOtp,
  verifyingOtp,
  checkingOnboarding,
  creatingBusiness,
  switchingContext,
  complete,
}

/// Auth context: tracks where we are in the login flow.
class AuthContext {
  final AuthState state;
  final String? phone;
  final String? email;
  final String? accessToken;
  final String? refreshToken;
  final String? userId;
  final OnboardingStatusOutput? onboardingStatus;
  final String? selectedBusinessId;
  final String? selectedStoreId;
  final String? error;

  const AuthContext({
    this.state = AuthState.unauthenticated,
    this.phone,
    this.email,
    this.accessToken,
    this.refreshToken,
    this.userId,
    this.onboardingStatus,
    this.selectedBusinessId,
    this.selectedStoreId,
    this.error,
  });

  /// True when the account has no name on file yet — set by the phone-first
  /// (OTP-only) signup path, which never asks for one. The UI routes to
  /// CompleteProfileScreen before continuing when this is true.
  bool get needsProfile => onboardingStatus?.needsProfile ?? false;

  String? get fullName => onboardingStatus?.fullName;

  AuthContext copyWith({
    AuthState? state,
    String? phone,
    String? email,
    String? accessToken,
    String? refreshToken,
    String? userId,
    OnboardingStatusOutput? onboardingStatus,
    String? selectedBusinessId,
    String? selectedStoreId,
    String? error,
    // Null means "leave it alone" for both identifiers, so switching channels
    // needs explicit clears — otherwise a stale email from an earlier attempt
    // would still look like the active sign-in address.
    bool clearPhone = false,
    bool clearEmail = false,
  }) =>
      AuthContext(
        state: state ?? this.state,
        phone: clearPhone ? null : (phone ?? this.phone),
        email: clearEmail ? null : (email ?? this.email),
        accessToken: accessToken ?? this.accessToken,
        refreshToken: refreshToken ?? this.refreshToken,
        userId: userId ?? this.userId,
        onboardingStatus: onboardingStatus ?? this.onboardingStatus,
        selectedBusinessId: selectedBusinessId ?? this.selectedBusinessId,
        selectedStoreId: selectedStoreId ?? this.selectedStoreId,
        error: error ?? this.error,
      );
}

/// Orchestrates the auth flow.
class AuthNotifier extends Notifier<AuthContext> {
  late final IdentityServiceApi _api;
  late final TokenStorage _tokenStorage;
  late final LocalProfileRepository _profileRepo;

  @override
  AuthContext build() {
    _api = IdentityServiceApi(dio: ref.watch(identityServiceDioProvider));
    _tokenStorage = TokenStorage();
    _profileRepo = ref.watch(localProfileRepositoryProvider);

    // On build, check if tokens are already stored (returning user).
    _checkStoredSession();
    return const AuthContext();
  }

  /// Checks if a valid session is already stored locally.
  ///
  /// An expired cached access token is the *normal* case here (short TTL,
  /// app relaunched after any real idle period) — so this exchanges the
  /// refresh token online for a fresh one instead of giving up. If that
  /// exchange itself fails (offline, or the refresh token is expired/
  /// revoked), this still restores the stale token rather than leaving the
  /// app unauthenticated — a stale-but-decodable token is what lets the UI
  /// keep showing the right permissions while offline; see
  /// [restoreSessionViaRefresh], which PIN unlock uses for the same reason.
  Future<void> _checkStoredSession() async {
    try {
      final tokenSet = await _tokenStorage.getTokenSet();
      if (tokenSet == null) return;
      if (!tokenSet.isExpired) {
        restoreSession(tokenSet);
        return;
      }
      await restoreSessionViaRefresh(tokenSet);
    } catch (_) {
      // Storage read itself failed — continue unauthenticated; the router
      // sends the user to login.
    }
  }

  /// Restores a session from a stored token set (used on device unlock).
  /// Called when a user unlocks the device with their PIN.
  void restoreSession(TokenSet tokenSet) {
    state = state.copyWith(
      state: AuthState.complete,
      accessToken: tokenSet.accessToken,
      refreshToken: tokenSet.refreshToken,
      userId: tokenSet.userId,
    );
  }

  /// Restores a session on PIN unlock by exchanging the stored refresh
  /// token for a fresh access token online first.
  ///
  /// PIN unlock guards exactly the idle window where the cached access
  /// token has very likely already expired — trusting it as-is (the old
  /// behavior) hands the app a token the backend immediately rejects, and
  /// every request comes back 401 until something else happens to trigger
  /// a reactive refresh. This also re-points `TokenStorage`'s
  /// current-session pointer at the unlocking profile, which a bare
  /// [restoreSession] (in-memory only) never does.
  Future<void> restoreSessionViaRefresh(TokenSet tokenSet) async {
    try {
      final fresh = await _refreshAndPersist(tokenSet);
      restoreSession(fresh);
    } catch (_) {
      // Offline, or the refresh token itself is expired/revoked — fall
      // back to the cached token so the app still works offline, or so
      // the request interceptor's reactive refresh gets one more chance.
      restoreSession(tokenSet);
    }
  }

  /// Exchanges the latest stored refresh token for a fresh access token and
  /// persists the result, rather than trusting a cached token that may
  /// already be expired.
  ///
  /// Goes through the process-wide [refreshTokens] coordinator (re-reading
  /// the latest stored pair inside its lock): a direct backend call here
  /// would race the interceptor's own 401-refresh at startup, replay the
  /// same one-shot token twice, and trip the backend's reuse detector —
  /// revoking the session family and breaking online access until the next
  /// OTP login. [tokenSet] only selects WHICH user's session to refresh;
  /// the token value sent is whatever storage holds at lock time.
  Future<TokenSet> _refreshAndPersist(TokenSet tokenSet) async {
    final fresh = await refreshTokens(
      api: _api,
      storage: _tokenStorage,
      userId: tokenSet.userId,
    );
    await _syncPermissionsCache(fresh);
    return fresh;
  }

  /// Writes this token's permissions to the local `CachedPermissions` table
  /// — see `syncPermissionsCache` (shared with `TokenRefreshInterceptor`'s
  /// background 401 refresh, the other place a fresh token appears).
  Future<void> _syncPermissionsCache(TokenSet tokenSet) {
    return syncPermissionsCache(
      profileRepo: _profileRepo,
      userId: tokenSet.userId,
      accessToken: tokenSet.accessToken,
      onSynced: () => ref.read(permissionsCacheTickProvider.notifier).state++,
    );
  }

  /// Step 1: Request OTP code for a phone number.
  Future<void> requestOtp(String phone) async {
    state = state.copyWith(state: AuthState.requestingOtp);
    try {
      await _api.requestOtp(phone);
      state = state.copyWith(
        phone: phone,
        clearEmail: true,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        state: AuthState.unauthenticated,
        error: e.toString(),
      );
      rethrow;
    }
  }

  /// Step 1 (email channel): Request an OTP code for an email address.
  Future<void> requestEmailOtp(String email) async {
    state = state.copyWith(state: AuthState.requestingOtp);
    try {
      await _api.requestEmailOtp(email);
      state = state.copyWith(email: email, clearPhone: true, error: null);
    } catch (e) {
      state = state.copyWith(
        state: AuthState.unauthenticated,
        error: e.toString(),
      );
      rethrow;
    }
  }

  /// Step 2: Verify an SMS OTP code and get tokens.
  Future<void> verifyOtp(String code) {
    return _verifyLogin(() {
      final phone = state.phone;
      if (phone == null) throw StateError('Phone not set');
      return _api.verifyOtp(phone: phone, code: code);
    });
  }

  /// Step 2 (email channel): Verify an emailed OTP code and get tokens.
  Future<void> verifyEmailOtp(String code) {
    return _verifyLogin(() {
      final email = state.email;
      if (email == null) throw StateError('Email not set');
      return _api.verifyEmailOtp(email: email, code: code);
    });
  }

  /// Verifies [request]'s code and runs the same post-login steps for either
  /// delivery channel: decode the token, then check onboarding.
  Future<void> _verifyLogin(Future<TokenResponse> Function() request) async {
    state = state.copyWith(state: AuthState.verifyingOtp);
    try {
      final tokenOutput = await request();

      // Decode JWT to get user ID and expiry.
      final claims = decodeAccessToken(tokenOutput.accessToken);
      final userId = claims.sub;

      state = state.copyWith(
        state: AuthState.checkingOnboarding,
        accessToken: tokenOutput.accessToken,
        refreshToken: tokenOutput.refreshToken,
        userId: userId,
      );

      // Persist the online session immediately, not only after a business
      // context exists. A brand-new owner has no business yet, so the later
      // `_switchContextAndLock` writes never run until onboarding finishes —
      // without this, closing the app between Complete Profile and Set PIN
      // left a saved local profile with no tokens, and Set PIN had nothing to
      // decode. Invited staff still overwrite this with business-scoped
      // tokens moments later.
      await _tokenStorage.saveTokenSet(
        TokenSet(
          accessToken: tokenOutput.accessToken,
          refreshToken: tokenOutput.refreshToken,
          expiresAt: DateTime.now().add(AppDurations.sessionLifetime),
          userId: userId,
        ),
      );

      // Step 3: Check onboarding status.
      await _checkOnboarding(tokenOutput.accessToken);
    } catch (e) {
      state = state.copyWith(
        state: AuthState.unauthenticated,
        error: e.toString(),
      );
      rethrow;
    }
  }

  /// Step 3: Check onboarding and branch.
  Future<void> _checkOnboarding(String accessToken) async {
    try {
      final onboardingStatus = await _api.getOnboardingStatus(accessToken);
      state = state.copyWith(onboardingStatus: onboardingStatus);

      // If user needs onboarding, they must create a business.
      // If not, they were invited and have a business already — switch to it.
      if (onboardingStatus.needsOnboarding) {
        // Flow stops here; caller proceeds to onboarding screen.
        // createBusinessAndOnboard will be called from the UI.
        state = state.copyWith(state: AuthState.complete);
      } else {
        // User has a business already (invited staff).
        final businessId = onboardingStatus.businessId;
        if (businessId != null) {
          final claims = decodeAccessToken(accessToken);
          if (claims.userCategory == 'business_store_staff') {
            // Store staff (cashiers, etc.) skip the context switch:
            // POST /auth/context/switch is business_staff-only (403 for
            // store staff), and the login token already carries
            // active_business_id + active_store_id + roles/permissions.
            // Just lock the device to the assigned store and finish.
            await _lockStoreStaffContext(
              businessId: claims.activeBusinessId ?? businessId,
              storeId: claims.activeStoreId,
              businessName:
                  onboardingStatus.businessName ?? 'Restaurant',
              accessToken: accessToken,
            );
          } else {
            await _switchContextAndLock(businessId, accessToken);
          }
        }
      }
    } catch (e) {
      state = state.copyWith(
        state: AuthState.unauthenticated,
        error: e.toString(),
      );
      rethrow;
    }
  }

  /// Store-staff login finish: the login token is already scoped to the
  /// assigned business + store, so there is no context switch — persist the
  /// tokens, provision the device to the assigned store (when known), and
  /// mark the flow complete. Mirrors the persistence tail of
  /// [_switchContextAndLock] without its switch/list-stores calls.
  Future<void> _lockStoreStaffContext({
    required String businessId,
    required String? storeId,
    required String businessName,
    required String accessToken,
  }) async {
    final userId = state.userId ?? decodeAccessToken(accessToken).sub;

    if (storeId != null) {
      await _profileRepo.reprovisionDevice(
        businessId: businessId,
        businessLocationId: storeId,
        businessName: businessName,
      );
    }

    await _tokenStorage.saveTokenSet(
      TokenSet(
        accessToken: accessToken,
        refreshToken: state.refreshToken!,
        expiresAt: DateTime.now().add(AppDurations.sessionLifetime),
        userId: userId,
      ),
    );

    state = state.copyWith(
      state: AuthState.complete,
      accessToken: accessToken,
      selectedBusinessId: businessId,
      selectedStoreId: storeId,
    );
  }

  /// Records the caller's own name/email — the first thing a phone-first
  /// (OTP-only) signup does, since /auth/otp/verify never collects one.
  ///
  /// For an email-first signup the address is already the account identifier
  /// (captured during OTP verification), so an omitted [email] falls back to
  /// it rather than being sent as "clear the email".
  ///
  /// Also saves the name to the local `LocalUserProfiles` row immediately
  /// (creating it if this is the very first write for this user, since Set
  /// PIN hasn't run yet) — the Profile Picker and PIN unlock read from that
  /// table, not from this in-memory state, so without this the name would
  /// only reach local storage once Set PIN incidentally happens to run.
  Future<void> completeProfile({
    required String fullName,
    String? email,
    String? phone,
  }) async {
    try {
      final accessToken = state.accessToken;
      if (accessToken == null) throw StateError('No access token');

      final effectiveEmail = email ?? state.email;
      final output = await _api.updateProfile(
        input: UpdateProfileInput(
          fullName: fullName,
          email: effectiveEmail,
          phone: phone,
        ),
        bearerToken: accessToken,
      );

      final status = state.onboardingStatus;
      state = state.copyWith(
        onboardingStatus: OnboardingStatusOutput(
          needsOnboarding: status?.needsOnboarding ?? true,
          businessId: status?.businessId,
          businessName: status?.businessName,
          fullName: output.fullName,
          email: output.email,
        ),
      );

      // Defensive: userId is normally set at OTP verify, but a missing id
      // must never silently skip the local write (the "no error, but no
      // row" symptom) — re-derive it from the token we just used.
      var userId = state.userId ?? decodeAccessToken(accessToken).sub;
      if (userId.isEmpty) {
        throw StateError('User ID not set after OTP verify');
      }
      await _profileRepo.upsertDisplayName(userId, output.fullName);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  /// Create a business and lock the device to it (owner onboarding path).
  ///
  /// Idempotent on retry: if the backend answers 409 (this owner already has
  /// a business — e.g. onboarding was abandoned after the business was
  /// created, then re-run with the same account), this recovers by switching
  /// context to the existing business instead of failing. The wizard then
  /// continues to the team step rather than stalling on a duplicate error.
  Future<void> createBusinessAndOnboard({
    required String name,
    required String address,
    required String phone,
    String? city,
    String? countryCode,
    String? timezone,
    String? taxId,
    String? registrationNumber,
    String? cuisineType,
    String? licenseDocumentUrl,
  }) async {
    try {
      state = state.copyWith(state: AuthState.creatingBusiness);

      final accessToken = state.accessToken;
      if (accessToken == null) throw StateError('No access token');

      final businessInput = BusinessCreateInput(
        name: name,
        businessType: 'restaurant',
        phone: phone,
        address: address,
        city: city,
        countryCode: countryCode ?? 'TZ',
        timezone: timezone ?? 'Africa/Dar_es_Salaam',
        taxId: taxId,
        registrationNumber: registrationNumber,
        cuisineType: cuisineType,
        licenseDocumentUrl: licenseDocumentUrl,
      );

      String businessId;
      String effectiveBusinessName = name;
      try {
        final businessOutput = await _api.createBusiness(
          input: businessInput,
          bearerToken: accessToken,
        );
        businessId = businessOutput.businessId;
      } on AuthException catch (e) {
        // One-business-per-owner: a retried onboarding lands here. Recover
        // by re-reading the existing business instead of surfacing 409.
        if (e.statusCode != 409) rethrow;
        final recoveredId = await _recoverExistingBusinessId(accessToken);
        if (recoveredId == null) rethrow;
        businessId = recoveredId;
        final recoveredName = state.onboardingStatus?.businessName;
        if (recoveredName != null && recoveredName.trim().isNotEmpty) {
          effectiveBusinessName = recoveredName;
        }
      }

      state = state.copyWith(selectedBusinessId: businessId);

      // Now switch context and lock to this business.
      await _switchContextAndLock(businessId, accessToken);

      // The owner's PIN (and LocalUserProfiles row) was already set before
      // reaching onboarding, so their role/business can be cached now,
      // explicitly, as soon as the business is saved. Invited staff get
      // this in setPin() instead — see that method for why the two flows
      // need separate write sites (LocalUserProfiles/CachedPermissions FK
      // ordering is reversed between them).
      if (state.userId != null &&
          state.selectedBusinessId != null &&
          state.selectedStoreId != null) {
        await _cachePermissions(
          userId: state.userId!,
          businessId: state.selectedBusinessId!,
          businessLocationId: state.selectedStoreId!,
          businessName: effectiveBusinessName,
          claims: decodeAccessToken(state.accessToken!),
        );
      }
    } catch (e) {
      state = state.copyWith(
        state: AuthState.unauthenticated,
        error: e.toString(),
      );
      rethrow;
    }
  }

  /// Re-reads onboarding-status after a 409 on business creation and returns
  /// the owner's existing business id, or null when there is nothing to
  /// recover (backend still says onboarding is needed).
  Future<String?> _recoverExistingBusinessId(String accessToken) async {
    try {
      final status = await _api.getOnboardingStatus(accessToken);
      state = state.copyWith(onboardingStatus: status);
      if (status.needsOnboarding || status.businessId == null) return null;
      return status.businessId;
    } catch (_) {
      return null;
    }
  }

  /// Step 4: Switch context to business and lock device.
  Future<void> _switchContextAndLock(
    String businessId,
    String accessToken,
  ) async {
    try {
      state = state.copyWith(state: AuthState.switchingContext);

      // Call the context switch endpoint. This alone is what authenticates
      // the user into this business context — everything below is optional
      // device provisioning, not a login requirement.
      final switchOutput = await _api.switchContext(
        businessId: businessId,
        bearerToken: accessToken,
      );

      // Look up stores only to lock this terminal to one, if it already has
      // one. A business the owner hasn't finished setting up yet — or one
      // this account was invited to before any store existed — has none,
      // and that must not block login: the device just stays unprovisioned
      // (see DeviceConfig's doc comment) until a store exists to lock to.
      final stores = await _api.listStores(
        businessId: businessId,
        bearerToken: switchOutput.accessToken,
      );
      final primaryStore = stores.isEmpty
          ? null
          : stores.firstWhere((s) => s.isPrimary, orElse: () => stores.first);

      if (primaryStore != null) {
        final businessName = state.onboardingStatus?.businessName ?? 'Restaurant';
        await _profileRepo.reprovisionDevice(
          businessId: businessId,
          businessLocationId: primaryStore.id,
          businessName: businessName,
        );
      }

      // Save tokens (access token may have changed after context switch).
      final expiresAt = DateTime.now().add(
        AppDurations.sessionLifetime, // Assume 15-min TTL (env config default)
      );
      await _tokenStorage.saveTokenSet(
        TokenSet(
          accessToken: switchOutput.accessToken,
          refreshToken: switchOutput.refreshToken,
          expiresAt: expiresAt,
          userId: state.userId!,
        ),
      );

      // Update profile roleLabel with new roles from business-scoped token.
      // setPin() saved the profile with empty roles (pre-context-switch);
      // now that we have switched context, update it with actual role names.
      final newClaims = decodeAccessToken(switchOutput.accessToken);
      final newRoleLabel = newClaims.roles.isNotEmpty ? newClaims.roles.join(', ') : null;
      await _profileRepo.updateRoleLabel(state.userId!, newRoleLabel);

      // Update auth state AFTER all persistence is complete.
      // Updating state triggers providers that watch authProvider (like storesProvider)
      // to re-run, so they must see the new token already in TokenStorage.
      state = state.copyWith(
        state: AuthState.complete,
        accessToken: switchOutput.accessToken,
        refreshToken: switchOutput.refreshToken,
        selectedBusinessId: businessId,
        selectedStoreId: primaryStore?.id,
      );
    } catch (e) {
      state = state.copyWith(
        state: AuthState.unauthenticated,
        error: e.toString(),
      );
      rethrow;
    }
  }

  /// Switches the terminal's operating store within the current business.
  ///
  /// Returns true when the backend reissued store-scoped tokens (online):
  /// tokens are persisted, the role label and permission cache follow the
  /// new token, and `selectedStoreId` moves — everything downstream of
  /// `currentStoreIdProvider` re-reads for the new store. Returns false
  /// when the exchange never reached the backend (offline): the device
  /// still re-points locally and the caller raises the pending-token banner
  /// with a retry. A backend answer (403/404/…) is rethrown — those are
  /// real rejections, not connectivity.
  ///
  /// Deliberately leaves `state.state` alone: flipping to
  /// `switchingContext` mid-session would trip the router's auth guards.
  /// The caller owns the loading UI for the switch.
  Future<bool> switchStore({required String storeId}) async {
    final businessId = state.selectedBusinessId;
    final userId = state.userId;
    if (businessId == null || userId == null) {
      throw StateError('No business context to switch store within');
    }

    var tokenRefreshed = false;
    var accessToken = state.accessToken;
    var refreshToken = state.refreshToken;

    if (accessToken != null) {
      try {
        final switched = await _api.switchStore(
          storeId: storeId,
          bearerToken: accessToken,
        );
        accessToken = switched.accessToken;
        refreshToken = switched.refreshToken;
        await _tokenStorage.saveTokenSet(
          TokenSet(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: DateTime.now().add(AppDurations.sessionLifetime),
            userId: userId,
          ),
        );
        tokenRefreshed = true;
      } on AuthException catch (e) {
        // No HTTP status means the request never reached the backend
        // (offline/DNS) — fall through to the local re-point below.
        // A status is the backend answering: surface it.
        if (e.statusCode != null) rethrow;
      }
    }

    final device = await _profileRepo.currentDevice();
    final storedName = device?.businessName as String?;
    final businessName = (storedName == null || storedName.trim().isEmpty)
        ? (state.onboardingStatus?.businessName ?? 'Restaurant')
        : storedName;

    await _profileRepo.provisionDevice(
      businessId: businessId,
      businessLocationId: storeId,
      businessName: businessName,
    );

    if (tokenRefreshed) {
      final claims = decodeAccessToken(accessToken!);
      await _profileRepo.updateRoleLabel(
        userId,
        claims.roles.isNotEmpty ? claims.roles.join(', ') : null,
      );
      await _cachePermissions(
        userId: userId,
        businessId: businessId,
        businessLocationId: storeId,
        businessName: businessName,
        claims: claims,
      );
    }

    state = state.copyWith(
      accessToken: accessToken,
      refreshToken: refreshToken,
      selectedStoreId: storeId,
    );
    return tokenRefreshed;
  }

  /// Save PIN to local profile.
  ///
  /// Invited staff already have a business context by this point (their
  /// `_switchContextAndLock()` ran during `_checkOnboarding()`, before Set
  /// PIN) — so this is also where their real role and permissions get
  /// cached, from the access token's `roles`/`permissions` claims.
  ///
  /// This was originally an explicit lookup — `GET .../staff` (find self by
  /// user id) then `GET .../roles/{id}/permissions` per role — rather than
  /// trusting the token. That turned out to be backwards: both endpoints
  /// require admin-level permissions (`user_business_roles.view`,
  /// `business_roles.view`) that an ordinary invited staff member's own
  /// role doesn't carry, so the lookup 403s for anyone but a manager/owner.
  /// The backend's own authorization layer (`require_business_permission`,
  /// `require_business_context`) reads `roles`/`permissions`/
  /// `active_business_id` straight off these same decoded claims for every
  /// request — there is no more authoritative source available to a
  /// non-admin caller, so this uses that directly.
  ///
  /// A fresh owner has no business yet at this point (they onboard after
  /// Set PIN) — there is nothing to cache here for them; see
  /// `createBusinessAndOnboard()` for their write site.
  Future<void> setPin(String pin) async {
    try {
      final userId = state.userId;
      if (userId == null) throw StateError('User ID not set');

      // Coming back to a half-finished signup after a restart: the profile
      // exists locally but the in-memory auth session may not have been
      // restored yet. Recover the stored session so claims are available.
      var accessToken = state.accessToken;
      if (accessToken == null) {
        final stored = await _tokenStorage.getTokenSetForUser(userId);
        if (stored != null) {
          await restoreSessionViaRefresh(stored);
          accessToken = state.accessToken;
        }
      }

      final salt = PinHasher.generateSalt();
      final pinHash = PinHasher.hash(pin, salt);
      final now = DateTime.now();
      final claims = accessToken == null ? null : decodeAccessToken(accessToken);

      // Create or update the profile. A re-login reactivates a
      // logout-deactivated row here (see `SessionNotifier.logout`). When the
      // in-memory onboarding status is missing (cold restart straight into
      // Set PIN), keep the name already saved locally rather than
      // overwriting it with a placeholder.
      var name = state.fullName;
      if (name == null || name.isEmpty) {
        final existing = await _profileRepo.getProfile(userId);
        name = existing?.displayName as String?;
      }
      final roleLabel = claims != null && claims.roles.isNotEmpty
          ? claims.roles.join(', ')
          : null;
      await _profileRepo.upsertProfile(
        LocalUserProfilesCompanion(
          id: Value(userId),
          displayName: Value(name != null && name.isNotEmpty ? name : 'Staff Member'),
          pinHash: Value(pinHash),
          pinSalt: Value(salt),
          roleLabel: Value(roleLabel),
          isDeactivated: const Value(false),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      if (claims != null &&
          state.selectedBusinessId != null &&
          state.selectedStoreId != null) {
        await _cachePermissions(
          userId: userId,
          businessId: state.selectedBusinessId!,
          businessLocationId: state.selectedStoreId!,
          businessName: state.onboardingStatus?.businessName ?? 'Restaurant',
          claims: claims,
        );
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  /// Refreshes the local RBAC cache for [userId] from [claims]. Callers must
  /// only invoke this once a `LocalUserProfiles` row for [userId] already
  /// exists (FK, cascade-delete) — see the two call sites (`setPin` and
  /// `createBusinessAndOnboard`) for why that's guaranteed differently for
  /// each account type.
  ///
  /// Bumps `permissionsCacheTickProvider` on success — neither call site
  /// changes `authProvider`'s token/claims as part of the same write (Set
  /// PIN doesn't touch the token at all), so without this,
  /// `currentUserPermissionsProvider` would have no signal that a fresh
  /// cache row now exists and could stay stuck on whatever it last
  /// resolved to (typically `Unknown()`, before this ever ran).
  Future<void> _cachePermissions({
    required String userId,
    required String businessId,
    required String businessLocationId,
    required String businessName,
    required JwtClaims claims,
  }) async {
    await _profileRepo.upsertPermissions(
      CachedPermissionsCompanion.insert(
        userId: userId,
        businessId: businessId,
        businessName: businessName,
        businessLocationId: businessLocationId,
        roleName: claims.roles.isNotEmpty ? claims.roles.join(', ') : 'Staff',
        permissionCodes: jsonEncode(claims.permissions),
        cachedAt: DateTime.now(),
      ),
    );
    ref.read(permissionsCacheTickProvider.notifier).state++;

    // Warm the inventory cache as soon as a business/store context exists.
    // Fire-and-forget: `InventoryNotifier.build()` does its own
    // stale-while-revalidate refresh regardless, so a failure here (offline,
    // no `inventory.view` permission) just means the first inventory screen
    // visit does the sync instead — never worth failing login over.
    //
    // Built directly here rather than via `catalogSyncServiceProvider` —
    // that provider resolves its business id through `currentBusinessIdProvider`,
    // which itself watches `authProvider`. Reading it from inside
    // `AuthNotifier` (this class) while its own build/state-change is still
    // in flight is a circular read Riverpod rejects outright, so this
    // constructs the sync service from providers that don't loop back here.
    unawaited(
      CatalogSyncService(
        db: ref.read(appDatabaseProvider),
        api: HttpInventoryCatalogApi(
          dio: ref.read(inventoryServiceDioProvider),
          businessId: businessId,
        ),
      ).syncAll(businessId: businessId, storeId: businessLocationId),
    );
  }

  /// Reset state for next login.
  void reset() {
    state = const AuthContext();
  }

  /// Signs out of the *online* session.
  ///
  /// Revokes the stored refresh token on the backend (best-effort: offline
  /// or an already-expired token must not block signing out), then always
  /// clears the locally stored tokens and resets the in-memory auth state.
  /// The *offline* session (PIN lock, [SessionNotifier]) is cleared by the
  /// caller — see [SessionNotifier.logout] which orchestrates both.
  Future<void> logout() async {
    var accessToken = state.accessToken;
    var refreshToken = state.refreshToken;

    // After a cold start the in-memory state may be empty while secure
    // storage still holds the online session — fall back to it so the
    // backend revocation still gets the right refresh token.
    if (accessToken == null || refreshToken == null) {
      try {
        final stored = await _tokenStorage.getTokenSet();
        accessToken ??= stored?.accessToken;
        refreshToken ??= stored?.refreshToken;
      } catch (_) {
        // Storage unreadable — fall through to local cleanup.
      }
    }

    if (accessToken != null && refreshToken != null) {
      try {
        await _api.logout(
          refreshToken: refreshToken,
          bearerToken: accessToken,
        );
      } catch (_) {
        // Best-effort revocation — local cleanup below still runs so logout
        // works offline and with expired/revoked tokens.
      }
    }

    try {
      await _tokenStorage.clearTokenSet();
    } catch (_) {
      // Secure-storage failure must not leave the in-memory session alive.
    }
    reset();
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthContext>(
  AuthNotifier.new,
);

/// Provides the Dio client for auth API calls (no bearer token yet).
///
/// Public (not `_dioClientProvider`) so tests can override it with a fake
/// `HttpClientAdapter` instead of hitting a live backend.
final identityServiceDioProvider = Provider<Dio>((ref) {
  final baseUrl = ApiConfig.identityServiceBaseUrl;

  final dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: AppDurations.connectTimeout,
    receiveTimeout: AppDurations.receiveTimeout,
    sendTimeout: AppDurations.sendTimeout,
  ));

  // Auto-attaches the current access token to every request and silently
  // refreshes-and-retries on a 401 — this is now the one real, working
  // client for every identity-service call (auth, business, staff/roles),
  // not a second parallel setup. Callers built against this provider don't
  // need to thread a bearer token through every method themselves.
  dio.interceptors.add(TokenRefreshInterceptor(
    tokenStorage: TokenStorage(),
    baseUrl: baseUrl,
    profileRepo: ref.watch(localProfileRepositoryProvider),
    onPermissionsSynced: () => ref.read(permissionsCacheTickProvider.notifier).state++,
  ));

  // Debug-only, credential-redacting logging. Never ship request bodies to
  // a release build's log (SEC-05).
  if (kDebugMode) {
    dio.interceptors.add(const ApiLogInterceptor());
  }

  return dio;
});
