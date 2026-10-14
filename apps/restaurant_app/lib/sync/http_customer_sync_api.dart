/// HTTP implementation of the customer sync API using Dio.
///
/// Calls the real POS Service `/businesses/{business_id}/customers/sync`
/// endpoint. Auth is handled by the Dio client's own interceptor, same as
/// `HttpFinanceSyncApi`.
library;

import 'package:dio/dio.dart';

import '../constants/api_paths.dart';
import 'customer_sync_api.dart';
import 'customer_sync_dtos.dart';
import 'http_sync_api.dart' show HttpException;

/// HTTP client for syncing customers to POS Service.
class HttpCustomerSyncApi extends CustomerSyncApi {
  final Dio _dio;
  final String _businessId;

  HttpCustomerSyncApi({required this._dio, required this._businessId});

  @override
  Future<CustomerSyncBatchResult> syncCustomers(List<CustomerDto> batch) async {
    try {
      final response = await _dio.post(
        PosApiPaths.customersSync(_businessId),
        data: {'customers': batch.map((c) => c.toJson()).toList()},
      );
      final results = (response.data['results'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map((r) => CustomerSyncRowResult(
                clientCustomerId: r['client_customer_id'] as String,
                status: r['status'] as String,
                reason: r['reason'] as String?,
              ))
          .toList();
      return CustomerSyncBatchResult(results: results);
    } on DioException catch (e) {
      throw HttpException(
        'Customer sync failed: ${e.message}',
        e.response?.statusCode,
      );
    }
  }
}
