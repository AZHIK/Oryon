/// HTTP implementation of the customer catalog (read-side) API using Dio.
///
/// Calls the real POS Service `/businesses/{business_id}/customers` list
/// endpoint. Mirrors `HttpFinanceCatalogApi`'s paging loop — the backend
/// caps a page at 100 rows, so a full pull must page through until a short
/// page comes back.
library;

import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';

import '../constants/api_paths.dart';
import '../constants/app_limits.dart';
import 'customer_catalog_api.dart';

const _pageSize = AppLimits.catalogFetchPageSize;

/// HTTP client for fetching the customer ledger from POS Service via Dio.
class HttpCustomerCatalogApi extends CustomerCatalogApi {
  final Dio _dio;
  final String _businessId;

  HttpCustomerCatalogApi({required this._dio, required this._businessId});

  @override
  Future<List<CustomerServerDto>> fetchCustomers() async {
    try {
      final customers = <CustomerServerDto>[];
      var offset = 0;
      while (true) {
        final response = await _dio.get(
          PosApiPaths.customers(_businessId),
          queryParameters: {
            'limit': _pageSize,
            'offset': offset,
            'include_deleted': true,
          },
        );
        final page = (response.data['items'] as List<dynamic>)
            .cast<Map<String, dynamic>>();
        customers.addAll(page.map(_customerFromJson));
        if (page.length < _pageSize) break;
        offset += _pageSize;
      }
      return customers;
    } on DioException catch (e) {
      throw CustomerFetchException(
        'Customers fetch failed: ${e.message}',
        e.response?.statusCode,
      );
    }
  }

  CustomerServerDto _customerFromJson(Map<String, dynamic> c) =>
      CustomerServerDto(
        id: c['id'] as String,
        businessId: c['business_id'] as String,
        name: c['name'] as String,
        phone: c['phone'] as String,
        email: c['email'] as String?,
        addressLine1: c['address_line1'] as String?,
        actorId: c['actor_id'] as String?,
        joinedAt: DateTime.parse(c['joined_at'] as String),
        syncedAt: DateTime.parse(c['synced_at'] as String),
        updatedAt: DateTime.parse(c['updated_at'] as String),
        isDeleted: c['is_deleted'] as bool,
        createdAt: DateTime.parse(c['created_at'] as String),
        totalOrders: c['total_orders'] as int,
        totalSpent: Decimal.parse(c['total_spent'].toString()),
        lastOrderAt: c['last_order_at'] != null
            ? DateTime.parse(c['last_order_at'] as String)
            : null,
      );
}

/// Customer fetch error for debugging.
class CustomerFetchException implements Exception {
  final String message;
  final int? statusCode;

  CustomerFetchException(this.message, [this.statusCode]);

  @override
  String toString() =>
      'CustomerFetchException: $message${statusCode != null ? ' (HTTP $statusCode)' : ''}';
}
