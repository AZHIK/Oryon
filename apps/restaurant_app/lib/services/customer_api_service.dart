/// Direct (non-outbox) write API for already-synced customers.
///
/// Mirrors `finance_api_service.dart`'s role: editing or deleting a
/// customer that already has a server id requires connectivity — there is
/// no offline-first queue for it.
library;

import 'package:dio/dio.dart';

import '../constants/api_paths.dart';

/// Thrown when POS Service rejects a customer mutation (not found, already
/// deleted, validation).
class CustomerApiException implements Exception {
  final String message;
  final int? statusCode;

  CustomerApiException(this.message, [this.statusCode]);

  @override
  String toString() =>
      'CustomerApiException: $message${statusCode != null ? ' (HTTP $statusCode)' : ''}';
}

class CustomerApiService {
  const CustomerApiService({required this._dio});

  final Dio _dio;

  Future<void> updateCustomer({
    required String businessId,
    required String customerId,
    String? name,
    String? phone,
    String? email,
    String? addressLine1,
  }) async {
    try {
      await _dio.patch(
        PosApiPaths.customer(businessId, customerId),
        data: {
          'name': ?name,
          'phone': ?phone,
          'email': ?email,
          'address_line1': ?addressLine1,
        },
      );
    } on DioException catch (e) {
      throw _toException(e);
    }
  }

  Future<void> deleteCustomer({
    required String businessId,
    required String customerId,
  }) async {
    try {
      await _dio.delete(PosApiPaths.customer(businessId, customerId));
    } on DioException catch (e) {
      throw _toException(e);
    }
  }

  CustomerApiException _toException(DioException e) {
    final detail = e.response?.data is Map
        ? (e.response?.data as Map)['detail']
        : null;
    return CustomerApiException(
      detail?.toString() ?? e.message ?? 'Request failed',
      e.response?.statusCode,
    );
  }
}
