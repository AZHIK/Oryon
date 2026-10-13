/// Data transfer objects for the sync API layer.
///
/// These DTOs are hand-written and decoupled from Drift-generated row types,
/// allowing the sync API to be tested independently of the database.
library;

import 'package:decimal/decimal.dart';

/// A pending sale ready for sync.
class PendingSaleDto {
  final String clientSaleId;
  final String status;
  final String storeId;
  final List<PendingSaleLineItemDto> lineItems;
  final Decimal discountAmount;
  final String paymentMethod;
  final String? customerId;
  final DateTime occurredAt;
  final int? deviceSequence;
  final String? voidOrRefundReason;

  PendingSaleDto({
    required this.clientSaleId,
    required this.status,
    required this.storeId,
    required this.lineItems,
    required this.discountAmount,
    required this.paymentMethod,
    this.customerId,
    required this.occurredAt,
    this.deviceSequence,
    this.voidOrRefundReason,
  });

  Map<String, dynamic> toJson() => {
    'client_sale_id': clientSaleId,
    'status': status,
    'store_id': storeId,
    'line_items': lineItems.map((li) => li.toJson()).toList(),
    'discount_amount': discountAmount.toString(),
    'payment_method': paymentMethod,
    'customer_id': customerId,
    // `.toUtc()` first: `DateTime.now()` (what `placeOrder` stamps `Order`s
    // with) is local time, and `.toIso8601String()` on a non-UTC DateTime
    // carries no timezone marker at all — the backend then parses it as
    // timezone-naive and 500s comparing it against its own timezone-aware
    // clock (`detect_time_drift`). `occurred_at` is documented as UTC device
    // time on both ends; this is what actually makes that true on the wire.
    'occurred_at': occurredAt.toUtc().toIso8601String(),
    'device_sequence': deviceSequence,
    'void_or_refund_reason': voidOrRefundReason,
  };
}

/// A line item within a pending sale.
class PendingSaleLineItemDto {
  final String itemId;
  final Decimal quantity;
  final Decimal unitPrice;
  final Decimal discountAmount;

  /// Per-unit production cost snapshot at sale time. Zero means
  /// unknown-but-frozen (flagged estimated downstream); null is legacy
  /// rows only — the backend stores it and reports value those at live
  /// recipe costs.
  final Decimal? unitCost;

  PendingSaleLineItemDto({
    required this.itemId,
    required this.quantity,
    required this.unitPrice,
    required this.discountAmount,
    this.unitCost,
  });

  Map<String, dynamic> toJson() => {
    'item_id': itemId,
    'quantity': quantity.toString(),
    'unit_price': unitPrice.toString(),
    'discount_amount': discountAmount.toString(),
    'unit_cost': unitCost?.toString(),
  };
}

/// Result of syncing one sale.
class SyncRowResult {
  final String clientSaleId;
  final String status; // 'created' | 'duplicate' | 'failed'
  final String? reason;

  SyncRowResult({
    required this.clientSaleId,
    required this.status,
    this.reason,
  });
}

/// Batch result from the sync API.
class SyncBatchResult {
  final List<SyncRowResult> results;

  SyncBatchResult({required this.results});
}
