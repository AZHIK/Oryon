/// HTTP implementation of the inventory catalog API using Dio.
///
/// Calls the real Inventory Service `/businesses/{business_id}/items` and
/// `/businesses/{business_id}/stock` endpoints. Auth is handled by the Dio
/// client's own interceptor (`TokenRefreshInterceptor`, attached in
/// `inventoryServiceDioProvider`) — this class never touches a bearer token
/// itself.
library;

import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import '../constants/api_paths.dart';
import '../constants/app_limits.dart';
import 'inventory_catalog_api.dart';

/// Both list endpoints cap a single page at 100 rows (backend-enforced) and
/// default to 20 — a full-catalog sync must page through until a page comes
/// back short of [_pageSize], or a business with more than one page of items
/// would silently sync only its first 20/100.
const _pageSize = AppLimits.catalogFetchPageSize;

/// HTTP client for fetching catalog items and stock levels from Inventory
/// Service via Dio.
class HttpInventoryCatalogApi extends InventoryCatalogApi {
  final Dio _dio;
  final String _businessId;

  HttpInventoryCatalogApi({required this._dio, required this._businessId});

  @override
  Future<List<CatalogItemDto>> fetchItems({required String storeId}) async {
    try {
      final items = <CatalogItemDto>[];
      var offset = 0;
      while (true) {
        final response = await _dio.get(
          InventoryApiPaths.items(_businessId),
          queryParameters: {
            'store_id': storeId,
            'limit': _pageSize,
            'offset': offset,
          },
        );
        final page = (response.data as List<dynamic>).cast<Map<String, dynamic>>();
        items.addAll(page.map(_itemFromJson));
        if (page.length < _pageSize) break;
        offset += _pageSize;
      }
      return items;
    } on DioException catch (e) {
      throw CatalogFetchException(
        'Catalog fetch failed: ${e.message}',
        e.response?.statusCode,
      );
    }
  }

  @override
  Future<List<StockLevelDto>> fetchStockLevels({required String storeId}) async {
    try {
      final levels = <StockLevelDto>[];
      var offset = 0;
      while (true) {
        final response = await _dio.get(
          InventoryApiPaths.stock(_businessId),
          queryParameters: {
            'store_id': storeId,
            'limit': _pageSize,
            'offset': offset,
          },
        );
        final page = (response.data as List<dynamic>).cast<Map<String, dynamic>>();
        levels.addAll(page.map(_stockLevelFromJson));
        if (page.length < _pageSize) break;
        offset += _pageSize;
      }
      return levels;
    } on DioException catch (e) {
      throw CatalogFetchException(
        'Stock level fetch failed: ${e.message}',
        e.response?.statusCode,
      );
    }
  }

  CatalogItemDto _itemFromJson(Map<String, dynamic> item) => CatalogItemDto(
        id: item['id'] as String,
        businessId: item['business_id'] as String,
        storeId: item['store_id'] as String,
        name: item['name'] as String,
        unitId: item['unit_id'] as String?,
        category: item['category_id'] as String?,
        supplierId: item['supplier_id'] as String?,
        reorderThreshold: Decimal.parse(item['reorder_threshold'].toString()),
        reorderQuantity: Decimal.parse(item['reorder_quantity'].toString()),
        sellingPrice: item['selling_price'] != null
            ? Decimal.parse(item['selling_price'].toString())
            : null,
        unitCost: item['unit_cost'] != null
            ? Decimal.parse(item['unit_cost'].toString())
            : null,
        allowNegativeStock: item['allow_negative_stock'] as bool? ?? false,
        itemType: item['item_type'] as String,
        isActive: item['is_active'] as bool? ?? true,
        createdAt: DateTime.parse(item['created_at'] as String),
        updatedAt: DateTime.parse(item['updated_at'] as String),
        imageUrl: item['image_url'] as String?,
      );

  StockLevelDto _stockLevelFromJson(Map<String, dynamic> level) => StockLevelDto(
        itemId: level['item_id'] as String,
        storeId: level['store_id'] as String,
        currentQuantity: Decimal.parse(level['current_quantity'].toString()),
        updatedAt: DateTime.parse(level['updated_at'] as String),
      );
}

/// Catalog fetch error for debugging.
class CatalogFetchException implements Exception {
  final String message;
  final int? statusCode;

  CatalogFetchException(this.message, [this.statusCode]);

  @override
  String toString() =>
      'CatalogFetchException: $message${statusCode != null ? ' (HTTP $statusCode)' : ''}';
}
