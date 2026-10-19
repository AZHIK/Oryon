/// HTTP implementation of the suppliers catalog API using Dio.
///
/// Calls Inventory Service's real `/businesses/{business_id}/suppliers`
/// list endpoint. Mirrors `HttpCustomerCatalogApi`'s paging loop.
library;

import 'package:dio/dio.dart';

import '../constants/api_paths.dart';
import '../constants/app_limits.dart';
import 'suppliers_catalog_api.dart';

const _pageSize = AppLimits.catalogFetchPageSize;

/// HTTP client for fetching the supplier directory from Inventory Service
/// via Dio.
class HttpSuppliersCatalogApi extends SuppliersCatalogApi {
  final Dio _dio;
  final String _businessId;

  HttpSuppliersCatalogApi({
    required this._dio,
    required this._businessId,
  });

  @override
  Future<List<SupplierDto>> fetchSuppliers() async {
    try {
      final suppliers = <SupplierDto>[];
      var offset = 0;
      while (true) {
        final response = await _dio.get(
          InventoryApiPaths.suppliers(_businessId),
          queryParameters: {
            'limit': _pageSize,
            'offset': offset,
            'include_deleted': true,
          },
        );
        final page =
            (response.data['items'] as List<dynamic>).cast<Map<String, dynamic>>();
        suppliers.addAll(page.map(_supplierFromJson));
        if (page.length < _pageSize) break;
        offset += _pageSize;
      }
      return suppliers;
    } on DioException catch (e) {
      throw SuppliersFetchException(
        'Suppliers fetch failed: ${e.message}',
        e.response?.statusCode,
      );
    }
  }

  SupplierDto _supplierFromJson(Map<String, dynamic> s) => SupplierDto(
        id: s['id'] as String,
        businessId: s['business_id'] as String,
        name: s['name'] as String,
        phone: s['phone'] as String?,
        email: s['email'] as String?,
        addressLine1: s['address_line1'] as String?,
        notes: s['notes'] as String?,
        updatedAt: DateTime.parse(s['updated_at'] as String),
        isDeleted: s['is_deleted'] as bool,
        createdAt: DateTime.parse(s['created_at'] as String),
      );
}

/// Suppliers fetch error for debugging.
class SuppliersFetchException implements Exception {
  final String message;
  final int? statusCode;

  SuppliersFetchException(this.message, [this.statusCode]);

  @override
  String toString() =>
      'SuppliersFetchException: $message${statusCode != null ? ' (HTTP $statusCode)' : ''}';
}
