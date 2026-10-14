/// Write-side API client for Inventory Service — the purchases module.
///
/// Matches `ReorderApiService`'s convention: a plain Dio-wrapping class,
/// no offline/demo mode — every call here requires connectivity. Purchases
/// are strictly online-only: there is no Drift outbox or background sync
/// for POs and GRNs (unlike POS sales or finance). The UI gates these calls
/// on `isOnlineProvider` and surfaces `PurchaseApiException.message`
/// directly.
library;

import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';

import '../constants/api_paths.dart';

/// Thrown when the backend rejects a purchase write — a sellable-item
/// rejection, an over-receive conflict, an overpay, etc. Callers can show
/// [message] directly.
class PurchaseApiException implements Exception {
  final String message;
  final int? statusCode;

  PurchaseApiException(this.message, [this.statusCode]);

  @override
  String toString() =>
      'PurchaseApiException: $message${statusCode != null ? ' (HTTP $statusCode)' : ''}';
}

// ── DTOs ─────────────────────────────────────────────────────────────────

Decimal _dec(dynamic v) => Decimal.parse(v.toString());
DateTime? _dt(dynamic v) => v == null ? null : DateTime.parse(v as String);

class PurchaseOrderLineInput {
  final String itemId;
  final Decimal quantityOrdered;
  final String? notes;

  const PurchaseOrderLineInput({
    required this.itemId,
    required this.quantityOrdered,
    this.notes,
  });
}

class PurchaseOrderLineDto {
  final String id;
  final String purchaseOrderId;
  final String itemId;
  final Decimal quantityOrdered;
  final Decimal quantityReceived;
  final String unit;
  final String? notes;

  const PurchaseOrderLineDto({
    required this.id,
    required this.purchaseOrderId,
    required this.itemId,
    required this.quantityOrdered,
    required this.quantityReceived,
    required this.unit,
    this.notes,
  });

  factory PurchaseOrderLineDto.fromJson(Map<String, dynamic> j) =>
      PurchaseOrderLineDto(
        id: j['id'] as String,
        purchaseOrderId: j['purchase_order_id'] as String,
        itemId: j['item_id'] as String,
        quantityOrdered: _dec(j['quantity_ordered']),
        quantityReceived: _dec(j['quantity_received']),
        unit: j['unit'] as String,
        notes: j['notes'] as String?,
      );

  Decimal get outstanding => quantityOrdered - quantityReceived;
}

class PurchaseOrderDto {
  final String id;
  final String businessId;
  final String storeId;
  final String supplierId;
  final String poNumber;
  final String status;
  final String? notes;
  final DateTime orderedAt;
  final DateTime? expectedAt;
  final DateTime? receivedAt;
  final List<PurchaseOrderLineDto> lines;

  const PurchaseOrderDto({
    required this.id,
    required this.businessId,
    required this.storeId,
    required this.supplierId,
    required this.poNumber,
    required this.status,
    this.notes,
    required this.orderedAt,
    this.expectedAt,
    this.receivedAt,
    this.lines = const [],
  });

  factory PurchaseOrderDto.fromJson(Map<String, dynamic> j) => PurchaseOrderDto(
        id: j['id'] as String,
        businessId: j['business_id'] as String,
        storeId: j['store_id'] as String,
        supplierId: j['supplier_id'] as String,
        poNumber: j['po_number'] as String,
        status: j['status'] as String,
        notes: j['notes'] as String?,
        orderedAt: DateTime.parse(j['ordered_at'] as String),
        expectedAt: _dt(j['expected_at']),
        receivedAt: _dt(j['received_at']),
        lines: switch (j['lines']) {
          final List lines => lines
              .map((e) => PurchaseOrderLineDto.fromJson(e as Map<String, dynamic>))
              .toList(),
          _ => const [],
        },
      );
}

class GoodsReceiptLineInput {
  final String purchaseOrderLineId;
  final Decimal quantityReceived;

  /// Actual price for this delivery — drives weighted-average costing.
  final Decimal unitCost;

  const GoodsReceiptLineInput({
    required this.purchaseOrderLineId,
    required this.quantityReceived,
    required this.unitCost,
  });
}

class GoodsReceiptLineDto {
  final String id;
  final String goodsReceiptId;
  final String purchaseOrderLineId;
  final String itemId;
  final Decimal quantityReceived;
  final Decimal unitCost;
  final String? lotNo;
  final DateTime? expiryDate;

  const GoodsReceiptLineDto({
    required this.id,
    required this.goodsReceiptId,
    required this.purchaseOrderLineId,
    required this.itemId,
    required this.quantityReceived,
    required this.unitCost,
    this.lotNo,
    this.expiryDate,
  });

  factory GoodsReceiptLineDto.fromJson(Map<String, dynamic> j) =>
      GoodsReceiptLineDto(
        id: j['id'] as String,
        goodsReceiptId: j['goods_receipt_id'] as String,
        purchaseOrderLineId: j['purchase_order_line_id'] as String,
        itemId: j['item_id'] as String,
        quantityReceived: _dec(j['quantity_received']),
        unitCost: _dec(j['unit_cost']),
        lotNo: j['lot_no'] as String?,
        expiryDate: _dt(j['expiry_date']),
      );
}

class GoodsReceiptDto {
  final String id;
  final String purchaseOrderId;
  final String grnNumber;
  final DateTime receivedAt;
  final List<GoodsReceiptLineDto> lines;

  const GoodsReceiptDto({
    required this.id,
    required this.purchaseOrderId,
    required this.grnNumber,
    required this.receivedAt,
    this.lines = const [],
  });

  factory GoodsReceiptDto.fromJson(Map<String, dynamic> j) => GoodsReceiptDto(
        id: j['id'] as String,
        purchaseOrderId: j['purchase_order_id'] as String,
        grnNumber: j['grn_number'] as String,
        receivedAt: DateTime.parse(j['received_at'] as String),
        lines: switch (j['lines']) {
          final List lines => lines
              .map((e) => GoodsReceiptLineDto.fromJson(e as Map<String, dynamic>))
              .toList(),
          _ => const [],
        },
      );
}


// ── Service ──────────────────────────────────────────────────────────────

class PurchaseApiService {
  const PurchaseApiService({required this._dio});

  final Dio _dio;

  Never _rethrow(DioException e) {
    final detail = e.response?.data is Map ? (e.response?.data as Map)['detail'] : null;
    throw PurchaseApiException(
      detail?.toString() ?? e.message ?? 'Request failed',
      e.response?.statusCode,
    );
  }

  /// Lists purchase orders. Requires `procurement.view`.
  Future<List<PurchaseOrderDto>> fetchOrders({
    required String businessId,
    String? status,
  }) async {
    try {
      final response = await _dio.get(
        InventoryApiPaths.purchaseOrders(businessId),
        queryParameters: {'status': ?status},
      );
      final items = (response.data as Map<String, dynamic>)['items'] as List;
      return items
          .map((e) => PurchaseOrderDto.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      _rethrow(e);
    }
  }

  /// Fetches one order with lines and receipts.
  /// Requires `procurement.view`.
  Future<PurchaseOrderDto> fetchOrder({
    required String businessId,
    required String orderId,
  }) async {
    try {
      final response = await _dio.get(
        InventoryApiPaths.purchaseOrder(businessId, orderId),
      );
      return PurchaseOrderDto.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      _rethrow(e);
    }
  }

  /// Drafts a multi-line purchase order. Requires `procurement.create`.
  Future<PurchaseOrderDto> createOrder({
    required String businessId,
    required String storeId,
    required String supplierId,
    required List<PurchaseOrderLineInput> lines,
    String? poNumber,
    String? notes,
    DateTime? expectedAt,
  }) async {
    try {
      final response = await _dio.post(
        InventoryApiPaths.purchaseOrders(businessId),
        data: {
          'store_id': storeId,
          'supplier_id': supplierId,
          'po_number': ?poNumber,
          'notes': ?notes,
          if (expectedAt != null) 'expected_at': expectedAt.toIso8601String(),
          'lines': [
            for (final line in lines)
              {
                'item_id': line.itemId,
                'quantity_ordered': line.quantityOrdered.toString(),
                if (line.notes != null) 'notes': line.notes,
              },
          ],
        },
      );
      return PurchaseOrderDto.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      _rethrow(e);
    }
  }

  Future<PurchaseOrderDto> _orderAction({
    required String businessId,
    required String orderId,
    required String action,
  }) async {
    try {
      final response = await _dio.post(
        InventoryApiPaths.purchaseOrderAction(businessId, orderId, action),
      );
      return PurchaseOrderDto.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      _rethrow(e);
    }
  }

  /// Submits a draft order. Requires `procurement.create`.
  Future<PurchaseOrderDto> submitOrder({
    required String businessId,
    required String orderId,
  }) =>
      _orderAction(businessId: businessId, orderId: orderId, action: 'submit');

  /// Approves a submitted order. Requires `procurement.approve`.
  Future<PurchaseOrderDto> approveOrder({
    required String businessId,
    required String orderId,
  }) =>
      _orderAction(businessId: businessId, orderId: orderId, action: 'approve');

  /// Cancels a draft/submitted/approved order. Requires `procurement.create`.
  Future<PurchaseOrderDto> cancelOrder({
    required String businessId,
    required String orderId,
  }) =>
      _orderAction(businessId: businessId, orderId: orderId, action: 'cancel');

  /// Records a goods receipt (partial or full) against an approved order —
  /// adds quantities to stock via the backend's stock-movement engine.
  /// Requires `procurement.receive`.
  Future<GoodsReceiptDto> receiveOrder({
    required String businessId,
    required String orderId,
    required List<GoodsReceiptLineInput> lines,
    String? notes,
  }) async {
    try {
      final response = await _dio.post(
        InventoryApiPaths.purchaseOrderAction(businessId, orderId, 'receive'),
        data: {
          'notes': ?notes,
          'lines': [
            for (final line in lines)
              {
                'purchase_order_line_id': line.purchaseOrderLineId,
                'quantity_received': line.quantityReceived.toString(),
                'unit_cost': line.unitCost.toString(),
              },
          ],
        },
      );
      return GoodsReceiptDto.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      _rethrow(e);
    }
  }
}
