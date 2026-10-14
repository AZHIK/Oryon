/// HTTP implementation of the units catalog API using Dio.
///
/// Calls Inventory Service's real `/units` list endpoint — global, not
/// business-scoped, so unlike `HttpSuppliersCatalogApi` there is no
/// `businessId` in the path and no paging loop (the taxonomy is a small
/// fixed set, per `services/inventory-service/app/api/v1/endpoints/units.py`).
library;

import 'package:dio/dio.dart';

import '../constants/api_paths.dart';
import 'units_catalog_api.dart';

/// HTTP client for fetching the unit taxonomy from Inventory Service via
/// Dio.
class HttpUnitsCatalogApi extends UnitsCatalogApi {
  final Dio _dio;

  HttpUnitsCatalogApi({required this._dio});

  @override
  Future<List<UnitDto>> fetchUnits() async {
    try {
      final response = await _dio.get(InventoryApiPaths.units);
      final rows = (response.data as List<dynamic>).cast<Map<String, dynamic>>();
      return rows.map(_unitFromJson).toList();
    } on DioException catch (e) {
      throw UnitsFetchException(
        'Units fetch failed: ${e.message}',
        e.response?.statusCode,
      );
    }
  }

  UnitDto _unitFromJson(Map<String, dynamic> u) => UnitDto(
        id: u['id'] as String,
        code: u['code'] as String,
        name: u['name'] as String,
        abbreviation: u['abbreviation'] as String,
        sortOrder: u['sort_order'] as int,
        isActive: u['is_active'] as bool,
      );
}

/// Units fetch error for debugging.
class UnitsFetchException implements Exception {
  final String message;
  final int? statusCode;

  UnitsFetchException(this.message, [this.statusCode]);

  @override
  String toString() =>
      'UnitsFetchException: $message${statusCode != null ? ' (HTTP $statusCode)' : ''}';
}
