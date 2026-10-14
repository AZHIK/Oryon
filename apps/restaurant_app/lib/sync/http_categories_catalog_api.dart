/// HTTP implementation of the categories catalog API using Dio.
///
/// Calls Inventory Service's real `/categories` list endpoint — global, not
/// business-scoped, so unlike `HttpSuppliersCatalogApi` there is no
/// `businessId` in the path and no paging loop (the taxonomy is a small
/// fixed set, per `services/inventory-service/app/api/v1/endpoints/categories.py`).
library;

import 'package:dio/dio.dart';

import '../constants/api_paths.dart';
import 'categories_catalog_api.dart';

/// HTTP client for fetching the category taxonomy from Inventory Service
/// via Dio.
class HttpCategoriesCatalogApi extends CategoriesCatalogApi {
  final Dio _dio;

  HttpCategoriesCatalogApi({required this._dio});

  @override
  Future<List<CategoryDto>> fetchCategories() async {
    try {
      final response = await _dio.get(InventoryApiPaths.categories);
      final rows = (response.data as List<dynamic>).cast<Map<String, dynamic>>();
      return rows.map(_categoryFromJson).toList();
    } on DioException catch (e) {
      throw CategoriesFetchException(
        'Categories fetch failed: ${e.message}',
        e.response?.statusCode,
      );
    }
  }

  CategoryDto _categoryFromJson(Map<String, dynamic> c) => CategoryDto(
        id: c['id'] as String,
        code: c['code'] as String,
        name: c['name'] as String,
        sortOrder: c['sort_order'] as int,
        isActive: c['is_active'] as bool,
      );
}

/// Categories fetch error for debugging.
class CategoriesFetchException implements Exception {
  final String message;
  final int? statusCode;

  CategoriesFetchException(this.message, [this.statusCode]);

  @override
  String toString() =>
      'CategoriesFetchException: $message${statusCode != null ? ' (HTTP $statusCode)' : ''}';
}
