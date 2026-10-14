/// HTTP implementation of the POS sync API using Dio.
///
/// Calls the real POS Service `/businesses/{business_id}/sales/sync`
/// endpoint. Auth is handled by the Dio client's own interceptor
/// (`TokenRefreshInterceptor`, attached in `posServiceDioProvider`) — this
/// class never touches a bearer token itself, matching every other real API
/// client in the app (`HttpInventoryCatalogApi`, `InventoryApiService`).
library;

import 'package:dio/dio.dart';
import '../constants/api_paths.dart';
import 'pos_sync_api.dart';
import 'sync_dtos.dart';

/// HTTP client for syncing sales to POS Service via Dio.
class HttpSyncApi extends PosSyncApi {
  final Dio _dio;
  final String _businessId;

  HttpSyncApi({required this._dio, required this._businessId});

  @override
  Future<SyncBatchResult> syncSales(List<PendingSaleDto> batch) async {
    try {
      final response = await _dio.post(
        PosApiPaths.salesSync(_businessId),
        data: {
          'sales': batch.map((s) => s.toJson()).toList(),
        },
      );

      final results = (response.data['results'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map((r) => SyncRowResult(
            clientSaleId: r['client_sale_id'] as String,
            status: r['status'] as String, // created|duplicate|failed
            reason: r['reason'] as String?,
          ))
          .toList();

      return SyncBatchResult(results: results);
    } on DioException catch (e) {
      throw HttpException(
        'Sync failed: ${e.message}',
        e.response?.statusCode,
      );
    }
  }
}

/// HTTP error for debugging.
class HttpException implements Exception {
  final String message;
  final int? statusCode;

  HttpException(this.message, [this.statusCode]);

  @override
  String toString() => 'HttpException: $message${statusCode != null ? ' (HTTP $statusCode)' : ''}';
}
