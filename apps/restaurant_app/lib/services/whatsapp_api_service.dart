/// API client for the WhatsApp Business Cloud API connection.
///
/// Matches `RequisitionApiService`'s convention: plain Dio wrapper,
/// strictly online-only. Errors surface as [WhatsAppApiException] with the
/// backend's `detail` message, shown directly in the UI.
library;

import 'package:dio/dio.dart';

import '../constants/api_paths.dart';

class WhatsAppApiException implements Exception {
  final String message;
  final int? statusCode;

  WhatsAppApiException(this.message, [this.statusCode]);

  @override
  String toString() =>
      'WhatsAppApiException: $message${statusCode != null ? ' (HTTP $statusCode)' : ''}';
}

/// The business's WhatsApp connection as the backend reports it.
///
/// `tokenPreview` is the last-4 masked token — the full secret is only ever
/// sent in the connect call, never read back.
class WhatsAppConnectionInfo {
  const WhatsAppConnectionInfo({
    required this.status,
    required this.phoneNumberId,
    this.displayPhoneNumber,
    this.tokenPreview,
    this.verifyToken,
    this.webhookPath,
    this.lastError,
  });

  final String status;
  final String phoneNumberId;
  final String? displayPhoneNumber;
  final String? tokenPreview;
  final String? verifyToken;
  final String? webhookPath;
  final String? lastError;

  bool get isConnected => status == 'connected';

  factory WhatsAppConnectionInfo.fromJson(Map<String, dynamic> json) =>
      WhatsAppConnectionInfo(
        status: json['status'] as String? ?? 'disconnected',
        phoneNumberId: json['phone_number_id'] as String? ?? '',
        displayPhoneNumber: json['display_phone_number'] as String?,
        tokenPreview: json['token_preview'] as String?,
        verifyToken: json['verify_token'] as String?,
        webhookPath: json['webhook_path'] as String?,
        lastError: json['last_error'] as String?,
      );
}

class WhatsAppApiService {
  const WhatsAppApiService({required Dio dio}) : _dio = dio;

  final Dio _dio;

  Never _rethrow(DioException e) {
    final detail = e.response?.data is Map
        ? (e.response?.data as Map)['detail']
        : null;
    throw WhatsAppApiException(
      detail?.toString() ?? e.message ?? 'Request failed',
      e.response?.statusCode,
    );
  }

  /// Returns null when the business never connected (HTTP 404).
  Future<WhatsAppConnectionInfo?> fetchConnection({
    required String businessId,
  }) async {
    try {
      final response = await _dio.get(
        InventoryApiPaths.whatsappConnection(businessId),
      );
      return WhatsAppConnectionInfo.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      _rethrow(e);
    }
  }

  /// Stores the operator-pasted credentials AND live-verifies them against
  /// the Graph API in one call. Returns the resulting status
  /// (`connected` or `error` with `lastError` from the provider).
  Future<WhatsAppConnectionInfo> connect({
    required String businessId,
    required String phoneNumberId,
    required String accessToken,
    String? displayPhoneNumber,
  }) async {
    try {
      final response = await _dio.put(
        InventoryApiPaths.whatsappConnection(businessId),
        data: {
          'phone_number_id': phoneNumberId,
          if (displayPhoneNumber != null && displayPhoneNumber.isNotEmpty)
            'display_phone_number': displayPhoneNumber,
          'access_token': accessToken,
        },
      );
      return WhatsAppConnectionInfo.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      _rethrow(e);
    }
  }

  Future<void> disconnect({required String businessId}) async {
    try {
      await _dio.delete(InventoryApiPaths.whatsappConnection(businessId));
    } on DioException catch (e) {
      _rethrow(e);
    }
  }

  /// Re-checks stored credentials against the Graph API.
  Future<Map<String, dynamic>> testConnection({
    required String businessId,
  }) async {
    try {
      final response = await _dio.post(
        InventoryApiPaths.whatsappConnectionTest(businessId),
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      _rethrow(e);
    }
  }
}
