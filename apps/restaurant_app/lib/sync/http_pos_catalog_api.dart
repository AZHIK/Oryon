/// HTTP implementation of the POS catalog (read-side) API using Dio.
///
/// Calls the real POS Service `/businesses/{business_id}/sales` (list) and
/// `/businesses/{business_id}/sales/{sale_id}` (detail, for line items)
/// endpoints. Auth is handled by the Dio client's own interceptor
/// (`TokenRefreshInterceptor`, attached in `posServiceDioProvider`) — this
/// class never touches a bearer token itself.
library;

import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import '../constants/api_paths.dart';
import '../constants/app_limits.dart';
import 'pos_catalog_api.dart';

/// The list endpoint caps a single page at 100 rows (backend-enforced) and
/// defaults to 20 — a full ledger pull must page through until a page comes
/// back short of [_pageSize], or a store with more than one page of sales
/// would silently sync only its most recent 20/100.
const _pageSize = AppLimits.catalogFetchPageSize;

/// HTTP client for fetching completed sales and their line items from POS
/// Service via Dio.
class HttpPosCatalogApi extends PosCatalogApi {
  final Dio _dio;
  final String _businessId;

  HttpPosCatalogApi({required this._dio, required this._businessId});

  @override
  Future<List<SaleDto>> fetchSales({required String storeId}) async {
    try {
      final sales = <SaleDto>[];
      var offset = 0;
      while (true) {
        final response = await _dio.get(
          PosApiPaths.sales(_businessId),
          queryParameters: {
            'store_id': storeId,
            'limit': _pageSize,
            'offset': offset,
          },
        );
        final page = (response.data['items'] as List<dynamic>)
            .cast<Map<String, dynamic>>();
        sales.addAll(page.map(_saleFromJson));
        if (page.length < _pageSize) break;
        offset += _pageSize;
      }
      return sales;
    } on DioException catch (e) {
      throw PosFetchException(
        'Sales fetch failed: ${e.message}',
        e.response?.statusCode,
      );
    }
  }

  @override
  Future<List<SaleLineItemDto>> fetchSaleLineItems({
    required String saleId,
  }) async {
    try {
      final response = await _dio.get(PosApiPaths.sale(_businessId, saleId));
      final lineItems = (response.data['line_items'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      return lineItems.map(_lineItemFromJson).toList();
    } on DioException catch (e) {
      throw PosFetchException(
        'Sale detail fetch failed: ${e.message}',
        e.response?.statusCode,
      );
    }
  }

  SaleDto _saleFromJson(Map<String, dynamic> sale) => SaleDto(
        id: sale['id'] as String,
        businessId: sale['business_id'] as String,
        storeId: sale['store_id'] as String,
        clientSaleId: sale['client_sale_id'] as String,
        status: sale['status'] as String,
        subtotal: Decimal.parse(sale['subtotal'].toString()),
        discountAmount: Decimal.parse(sale['discount_amount'].toString()),
        taxAmount: Decimal.parse(sale['tax_amount'].toString()),
        total: Decimal.parse(sale['total'].toString()),
        paymentMethod: sale['payment_method'] as String,
        actorId: sale['actor_id'] as String?,
        customerId: sale['customer_id'] as String?,
        occurredAt: DateTime.parse(sale['occurred_at'] as String),
        syncedAt: DateTime.parse(sale['synced_at'] as String),
        voidedAt: sale['voided_at'] != null
            ? DateTime.parse(sale['voided_at'] as String)
            : null,
        refundedAt: sale['refunded_at'] != null
            ? DateTime.parse(sale['refunded_at'] as String)
            : null,
        voidOrRefundReason: sale['void_or_refund_reason'] as String?,
        createdAt: DateTime.parse(sale['created_at'] as String),
      );

  SaleLineItemDto _lineItemFromJson(Map<String, dynamic> line) =>
      SaleLineItemDto(
        id: line['id'] as String,
        saleId: line['sale_id'] as String,
        itemId: line['item_id'] as String,
        quantity: Decimal.parse(line['quantity'].toString()),
        unitPrice: Decimal.parse(line['unit_price'].toString()),
        discountAmount: Decimal.parse(line['discount_amount'].toString()),
        lineTotal: Decimal.parse(line['line_total'].toString()),
        unitCost: line['unit_cost'] != null
            ? Decimal.parse(line['unit_cost'].toString())
            : null,
      );
}

/// Sales fetch error for debugging.
class PosFetchException implements Exception {
  final String message;
  final int? statusCode;

  PosFetchException(this.message, [this.statusCode]);

  @override
  String toString() =>
      'PosFetchException: $message${statusCode != null ? ' (HTTP $statusCode)' : ''}';
}
