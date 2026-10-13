/// Pluggable interface for fetching the completed-sales ledger and per-sale
/// line items from POS Service.
///
/// This is the read-side counterpart to `pos_sync_api.dart` (which pushes
/// new sales), mirroring how `inventory_catalog_api.dart` pairs with
/// `services/inventory_api_service.dart`. `HttpPosCatalogApi` calls the
/// real endpoints.
library;

import 'package:decimal/decimal.dart';

/// Data transfer object for one row of the sales ledger (`GET /sales`).
///
/// Mirrors the backend's `SaleListItem` — the same shape as `SaleRead`
/// minus `line_items`, which are fetched separately per-sale via
/// [PosCatalogApi.fetchSaleLineItems].
class SaleDto {
  final String id;
  final String businessId;
  final String storeId;
  final String clientSaleId;
  final String status;
  final Decimal subtotal;
  final Decimal discountAmount;
  final Decimal taxAmount;
  final Decimal total;
  final String paymentMethod;
  final String? actorId;
  final String? customerId;
  final DateTime occurredAt;
  final DateTime syncedAt;
  final DateTime? voidedAt;
  final DateTime? refundedAt;
  final String? voidOrRefundReason;
  final DateTime createdAt;

  SaleDto({
    required this.id,
    required this.businessId,
    required this.storeId,
    required this.clientSaleId,
    required this.status,
    required this.subtotal,
    required this.discountAmount,
    required this.taxAmount,
    required this.total,
    required this.paymentMethod,
    this.actorId,
    this.customerId,
    required this.occurredAt,
    required this.syncedAt,
    this.voidedAt,
    this.refundedAt,
    this.voidOrRefundReason,
    required this.createdAt,
  });
}

/// Data transfer object for one line item of a sale (`SaleLineItemRead`).
class SaleLineItemDto {
  final String id;
  final String saleId;
  final String itemId;
  final Decimal quantity;
  final Decimal unitPrice;
  final Decimal discountAmount;
  final Decimal lineTotal;

  /// Sale-time production cost snapshot. Null for sales synced before
  /// snapshots existed.
  final Decimal? unitCost;

  SaleLineItemDto({
    required this.id,
    required this.saleId,
    required this.itemId,
    required this.quantity,
    required this.unitPrice,
    required this.discountAmount,
    required this.lineTotal,
    this.unitCost,
  });
}

/// Pluggable API for fetching completed sales and their line items.
abstract class PosCatalogApi {
  /// Fetches the sales ledger for a store, most recent first.
  Future<List<SaleDto>> fetchSales({required String storeId});

  /// Fetches the line items for one sale (`GET /sales/{sale_id}`'s
  /// `line_items`) — a separate call because the ledger endpoint doesn't
  /// include them, and a synced sale's lines never change once fetched.
  Future<List<SaleLineItemDto>> fetchSaleLineItems({required String saleId});
}
