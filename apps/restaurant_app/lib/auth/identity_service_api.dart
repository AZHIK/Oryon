/// HTTP client for Identity Service endpoints.
///
/// Handles OTP login, token refresh, business creation, and store lookups.
/// Verified against the live identity-service backend.
library;

import 'package:dio/dio.dart';
import '../constants/api_paths.dart';
import 'auth_dtos.dart';

/// Calls Identity Service endpoints via Dio.
class IdentityServiceApi {
  final Dio _dio;

  IdentityServiceApi({required this._dio});

  /// POST /auth/otp/request - Request an OTP code for a phone number.
  /// Returns void (204 No Content response from backend).
  Future<void> requestOtp(String phone) async {
    try {
      await _dio.post(
        IdentityApiPaths.otpRequest,
        data: OtpRequestInput(phone: phone).toJson(),
      );
    } on DioException catch (e) {
      throw AuthException('OTP request failed: ${e.message}', e.response?.statusCode);
    }
  }

  /// POST /auth/otp/verify - Verify OTP code and get tokens.
  Future<TokenResponse> verifyOtp({
    required String phone,
    required String code,
  }) async {
    try {
      final response = await _dio.post(
        IdentityApiPaths.otpVerify,
        data: OtpVerifyInput(phone: phone, code: code).toJson(),
      );
      return TokenResponse.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw AuthException('OTP verify failed: ${e.message}', e.response?.statusCode);
    }
  }

  /// GET /users/me/onboarding-status - Check onboarding status (requires bearer token).
  Future<OnboardingStatusOutput> getOnboardingStatus(String bearerToken) async {
    try {
      final response = await _dio.get(
        IdentityApiPaths.onboardingStatus,
        options: Options(
          headers: {'Authorization': 'Bearer $bearerToken'},
        ),
      );
      return OnboardingStatusOutput.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw AuthException(
        'Onboarding status check failed: ${e.message}',
        e.response?.statusCode,
      );
    }
  }

  /// PATCH /users/me - Set the caller's own name/email (requires bearer token).
  Future<UpdateProfileOutput> updateProfile({
    required UpdateProfileInput input,
    required String bearerToken,
  }) async {
    try {
      final response = await _dio.patch(
        IdentityApiPaths.updateMe,
        data: input.toJson(),
        options: Options(
          headers: {'Authorization': 'Bearer $bearerToken'},
        ),
      );
      return UpdateProfileOutput.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw AuthException(
        'Profile update failed: ${e.message}',
        e.response?.statusCode,
      );
    }
  }

  /// POST /auth/refresh - Refresh access token using refresh token.
  /// Note: the backend rotates the refresh token; the returned refresh_token is new.
  Future<TokenResponse> refreshAccessToken(String refreshToken) async {
    try {
      final response = await _dio.post(
        IdentityApiPaths.refresh,
        data: TokenRefreshInput(refreshToken: refreshToken).toJson(),
      );
      return TokenResponse.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw AuthException('Token refresh failed: ${e.message}', e.response?.statusCode);
    }
  }

  /// POST /auth/logout - Revoke the session backing [refreshToken].
  ///
  /// Best-effort by design: the backend treats an unknown token as a no-op
  /// and callers always clear local tokens afterwards, so a failure here
  /// (offline, expired token) must never block signing out locally.
  Future<void> logout({
    required String refreshToken,
    required String bearerToken,
  }) async {
    try {
      await _dio.post(
        IdentityApiPaths.logout,
        data: LogoutInput(refreshToken: refreshToken).toJson(),
        options: Options(
          headers: {'Authorization': 'Bearer $bearerToken'},
        ),
      );
    } on DioException catch (e) {
      throw AuthException('Logout failed: ${e.message}', e.response?.statusCode);
    }
  }
  /// POST /auth/context/switch - Scope token to a business (requires bearer token).
  Future<TokenResponse> switchContext({
    required String businessId,
    required String bearerToken,
  }) async {
    try {
      final response = await _dio.post(
        IdentityApiPaths.switchContext,
        data: ContextSwitchInput(businessId: businessId).toJson(),
        options: Options(
          headers: {'Authorization': 'Bearer $bearerToken'},
        ),
      );
      return TokenResponse.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw AuthException(
        'Context switch failed: ${e.message}',
        e.response?.statusCode,
      );
    }
  }

  /// POST /auth/context/switch-store - Scope token to a store (business
  /// staff with `stores.switch`; requires bearer token). The backend
  /// reissues tokens with `active_store_id` set — the online proof of which
  /// store this terminal is now scoped to.
  Future<TokenResponse> switchStore({
    required String storeId,
    required String bearerToken,
  }) async {
    try {
      final response = await _dio.post(
        IdentityApiPaths.switchStore,
        data: StoreSwitchInput(storeId: storeId).toJson(),
        options: Options(
          headers: {'Authorization': 'Bearer $bearerToken'},
        ),
      );
      return TokenResponse.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw AuthException.fromDio('Store switch failed', e);
    }
  }

  /// POST /api/v1/businesses - Create a new business (requires bearer token).
  Future<BusinessCreateOutput> createBusiness({
    required BusinessCreateInput input,
    required String bearerToken,
  }) async {
    try {
      final response = await _dio.post(
        IdentityApiPaths.businesses,
        data: input.toJson(),
        options: Options(
          headers: {'Authorization': 'Bearer $bearerToken'},
        ),
      );
      return BusinessCreateOutput.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw AuthException(
        'Business creation failed: ${e.message}',
        e.response?.statusCode,
      );
    }
  }

  /// GET /api/v1/businesses/{businessId}/exists - Public existence probe.
  ///
  /// Deliberately UNAUTHENTICATED (no Authorization header — the request
  /// interceptor must not attach one): a device with a dead session still
  /// needs to answer "is my locked business still on this server?".
  /// 200 = present; 404 (as [AuthException] with status 404) = deleted.
  Future<void> businessExists({required String businessId}) async {
    try {
      await _dio.get(IdentityApiPaths.businessExists(businessId));
    } on DioException catch (e) {
      throw AuthException.fromDio('Business probe failed', e);
    }
  }

  /// GET /api/v1/businesses/{businessId}/stores/{storeId} - Fetch one store.
  ///
  /// This is the store-staff-safe check: `business_store_staff` is blocked
  /// from `listStores` (business-wide operation) but CAN read its own store
  /// detail (store-scope match enforced server-side). 404 = store (or its
  /// business) gone. 403 = scope mismatch / access revoked.
  Future<StoreReadDto> getStore({
    required String businessId,
    required String storeId,
    required String bearerToken,
  }) async {
    try {
      final response = await _dio.get(
        IdentityApiPaths.store(businessId, storeId),
        options: Options(
          headers: {'Authorization': 'Bearer $bearerToken'},
        ),
      );
      return StoreReadDto.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw AuthException.fromDio('Store fetch failed', e);
    }
  }

  /// GET /api/v1/businesses/{businessId}/stores - List stores for a business.
  Future<List<StoreDto>> listStores({
    required String businessId,
    required String bearerToken,
  }) async {
    try {
      final response = await _dio.get(
        IdentityApiPaths.businessStores(businessId),
        options: Options(
          headers: {'Authorization': 'Bearer $bearerToken'},
        ),
      );
      final items = (response.data as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map((item) => StoreDto.fromJson(item))
          .toList();
      return items;
    } on DioException catch (e) {
      throw AuthException.fromDio('Store list failed', e);
    }
  }
}

/// Auth operation error.
class AuthException implements Exception {
  final String message;
  final int? statusCode;

  AuthException(this.message, [this.statusCode]);

  /// Builds from a failed Dio call, preferring the backend's own `detail`
  /// string over Dio's generic status-code explainer paragraph — so logs
  /// and UI show what the backend actually said. Transport failures (no
  /// response) embed the Dio error type + underlying error instead.
  factory AuthException.fromDio(String action, DioException e) {
    final data = e.response?.data;
    final detail = data is Map && data['detail'] is String
        ? data['detail'] as String
        : null;
    final cause = detail ??
        (e.response != null
            ? 'HTTP ${e.response?.statusCode}'
            : '${e.type}${e.error == null ? '' : ': ${e.error}'}');
    return AuthException('$action: $cause', e.response?.statusCode);
  }

  @override
  String toString() =>
      'AuthException: $message${statusCode != null ? ' (HTTP $statusCode)' : ''}';
}
