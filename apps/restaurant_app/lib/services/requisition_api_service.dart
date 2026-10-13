/// Write-side API client for the requisition flow.
///
/// Matches `PurchaseApiService`'s convention: plain Dio wrapper, strictly
/// online-only (no Drift outbox — the cart itself is session-only state and
/// the submit is a single transactional POST). Errors surface as
/// [RequisitionApiException] with the backend's `detail` message, shown
/// directly in the UI.
library;

import 'package:dio/dio.dart';

import '../constants/api_paths.dart';
import '../models/requisition.dart';

class RequisitionApiException implements Exception {
  final String message;
  final int? statusCode;

  RequisitionApiException(this.message, [this.statusCode]);

  @override
  String toString() =>
      'RequisitionApiException: $message${statusCode != null ? ' (HTTP $statusCode)' : ''}';
}

class RequisitionApiService {
  const RequisitionApiService({required Dio dio}) : _dio = dio;

  final Dio _dio;

  Never _rethrow(DioException e) {
    final detail =
        e.response?.data is Map ? (e.response?.data as Map)['detail'] : null;
    throw RequisitionApiException(
      detail?.toString() ?? e.message ?? 'Request failed',
      e.response?.statusCode,
    );
  }

  /// Submits the finalized cart. Lines already carry supplier_ids (per-item
  /// and/or bulk assignment resolved client-side). Returns the requisition
  /// with nested per-supplier POs and WhatsApp payloads.
  Future<Map<String, dynamic>> submit({
    required String businessId,
    required String storeId,
    required List<Map<String, dynamic>> lines,
    required String idempotencyKey,
    String? notes,
    DateTime? expectedAt,
  }) async {
    try {
      final response = await _dio.post(
        InventoryApiPaths.requisitions(businessId),
        data: {
          'store_id': storeId,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
          if (expectedAt != null)
            'expected_at': expectedAt.toUtc().toIso8601String(),
          'idempotency_key': idempotencyKey,
          'lines': lines,
        },
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      _rethrow(e);
    }
  }

  /// Fetches one submitted requisition with its POs and payloads.
  Future<Map<String, dynamic>> fetchRequisition({
    required String businessId,
    required String requisitionId,
  }) async {
    try {
      final response = await _dio.get(
        InventoryApiPaths.requisition(businessId, requisitionId),
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      _rethrow(e);
    }
  }
}

/// Builds [SubmittedRequisition] from a raw submit/fetch response, resolving
/// supplier names from the directory list.
SubmittedRequisition submittedFromResponse(
  Map<String, dynamic> json,
  Map<String, String> supplierNames,
) =>
    SubmittedRequisition.fromJson(json, supplierNames);
