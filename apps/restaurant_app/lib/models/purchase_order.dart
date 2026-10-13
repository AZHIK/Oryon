/// UI models for the purchases module (two-step POs: create → receive).
///
/// Thin wrappers over `PurchaseApiService` DTOs for the presentation layer.
/// Status strings come straight from the backend enum: `unfulfilled`
/// (open, accepts GRNs), `fulfilled` (terminal, quantities met),
/// `cancelled`.
library;

import 'package:flutter/foundation.dart';

import '../l10n/l10n.dart';
import '../services/purchase_api_service.dart';

enum PurchaseOrderStatus {
  unfulfilled,
  fulfilled,
  cancelled,
  unknown;

  static PurchaseOrderStatus fromBackend(String value) => switch (value) {
        'unfulfilled' => unfulfilled,
        'fulfilled' => fulfilled,
        'cancelled' => cancelled,
        _ => unknown,
      };

  /// Staff-facing labels for the two-step flow.
  String get label => switch (this) {
        unfulfilled => L10n.t('poStatusUnfulfilled', 'Unfulfilled'),
        fulfilled => L10n.t('poStatusFulfilled', 'Fulfilled'),
        cancelled => L10n.t('poStatusCancelled', 'Cancelled'),
        unknown => L10n.t('unknown', 'Unknown'),
      };

  /// Still changeable — unfulfilled orders accept further GRNs.
  bool get isOpen => switch (this) {
        unfulfilled => true,
        fulfilled || cancelled || unknown => false,
      };
}

/// One item line of a purchase order — qty-only. Cost is captured per
/// receipt when goods arrive, never on the order.
@immutable
class PurchaseOrderLine {
  const PurchaseOrderLine({
    required this.id,
    required this.itemId,
    required this.quantityOrdered,
    required this.quantityReceived,
    required this.unit,
  });

  factory PurchaseOrderLine.fromDto(PurchaseOrderLineDto dto) =>
      PurchaseOrderLine(
        id: dto.id,
        itemId: dto.itemId,
        quantityOrdered: dto.quantityOrdered.toDouble(),
        quantityReceived: dto.quantityReceived.toDouble(),
        unit: dto.unit,
      );

  final String id;
  final String itemId;
  final double quantityOrdered;
  final double quantityReceived;
  final String unit;

  double get outstanding => quantityOrdered - quantityReceived;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PurchaseOrderLine && other.id == id);

  @override
  int get hashCode => id.hashCode;
}

/// A multi-line purchase order header with its lines — qty-only, no money.
@immutable
class PurchaseOrder {
  const PurchaseOrder({
    required this.id,
    required this.storeId,
    required this.supplierId,
    required this.poNumber,
    required this.status,
    required this.orderedAt,
    this.expectedAt,
    this.receivedAt,
    this.notes,
    this.lines = const [],
  });

  factory PurchaseOrder.fromDto(PurchaseOrderDto dto) => PurchaseOrder(
        id: dto.id,
        storeId: dto.storeId,
        supplierId: dto.supplierId,
        poNumber: dto.poNumber,
        status: PurchaseOrderStatus.fromBackend(dto.status),
        orderedAt: dto.orderedAt,
        expectedAt: dto.expectedAt,
        receivedAt: dto.receivedAt,
        notes: dto.notes,
        lines: dto.lines.map(PurchaseOrderLine.fromDto).toList(),
      );

  final String id;
  final String storeId;
  final String supplierId;
  final String poNumber;
  final PurchaseOrderStatus status;
  final DateTime orderedAt;
  final DateTime? expectedAt;
  final DateTime? receivedAt;
  final String? notes;
  final List<PurchaseOrderLine> lines;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PurchaseOrder && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
