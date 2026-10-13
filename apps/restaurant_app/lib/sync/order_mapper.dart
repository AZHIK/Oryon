/// Maps POS Service's cached sale rows onto the UI's `Order` model.
///
/// The read-side counterpart to `inventory_item_mapper.dart`. Two enum
/// mappings do the real work here: the app's `OrderStatus`/`PaymentType`
/// carry UI concerns the backend correctly has no reason to know about (a
/// local-only `pending` status, icons, `qris`/`giftCard` tenders), so a
/// synced sale is translated rather than made to fit the backend's smaller
/// enums directly.
library;

import 'package:decimal/decimal.dart';

import '../database/app_database.dart';
import '../models/order.dart';

double _toDouble(Decimal value) => double.parse(value.toString());

/// Backend `SaleStatus` ("completed"|"voided"|"refunded") to [OrderStatus].
/// A `CachedSale` row only ever exists once the backend has accepted it, so
/// the app's local-only [OrderStatus.pending] never applies to one.
OrderStatus orderStatusFromBackend(String status) => switch (status) {
      'voided' => OrderStatus.voided,
      'refunded' => OrderStatus.refunded,
      _ => OrderStatus.paid, // 'completed'
    };

/// The reverse of [orderStatusFromBackend], for building a sync payload.
/// [OrderStatus.pending] has no backend equivalent — a sale is never synced
/// while pending, so this case is unreachable in practice.
String orderStatusToBackend(OrderStatus status) => switch (status) {
      OrderStatus.voided => 'voided',
      OrderStatus.refunded => 'refunded',
      _ => 'completed',
    };

/// The app's [PaymentType] to the backend's smaller `PaymentMethod` enum.
/// `qris` and `giftCard` have no backend equivalent and both collapse to
/// `other` — lossy by necessity, since pos-service only distinguishes
/// cash/mobile_money/card/other.
String paymentMethodToBackend(PaymentType type) => switch (type) {
      PaymentType.cash => 'cash',
      PaymentType.card => 'card',
      PaymentType.mobile => 'mobile_money',
      PaymentType.qris || PaymentType.giftCard => 'other',
    };

/// The reverse of [paymentMethodToBackend]. Recovering which original tender
/// an `other` sale used is impossible once collapsed; it maps back to
/// [PaymentType.giftCard] rather than [PaymentType.card] so a lossily-synced
/// sale is never mistaken for an exact card swipe in reporting that keys off
/// tender type.
PaymentType paymentMethodFromBackend(String method) => switch (method) {
      'cash' => PaymentType.cash,
      'card' => PaymentType.card,
      'mobile_money' => PaymentType.mobile,
      _ => PaymentType.giftCard, // 'other'
    };

/// Maps one cached sale and its already-loaded line items onto an [Order].
///
/// [itemsById] resolves each line's `itemId` to its catalog name — the
/// backend doesn't denormalize a name onto the sale the way the app's own
/// `Order.fromCart` does, so it's looked up from `CachedItems` at read time
/// instead. A line whose item has since been removed from the local cache
/// (a cross-device sale synced before this device ever cached that item)
/// falls back to a placeholder name rather than failing the whole mapping.
///
/// [localOrderId] is this sale's original `PendingSales.localOrderId`
/// ("ORD-0042"), when this device is the one that placed it — recovered by
/// the caller via a join on `clientSaleId`, so an order placed at this till
/// keeps the exact same human-readable id across the whole "place it,
/// prepend it locally, sync it, reload it from cache" lifecycle, rather than
/// silently swapping identity to the backend's UUID the moment a background
/// refresh reloads state from `CachedSales`. A sale synced from a different
/// device has no such row on this one — it falls back to `clientSaleId`
/// itself, which is not a pretty ticket number, but that sale was never
/// rung up on this till in the first place.
///
/// Quantity is rounded to an [int]: the backend's `Decimal` quantity exists
/// to support fractional stock (kg/L raw materials), but every sale this
/// app itself creates comes from the till's cart, which only ever sells
/// whole units (`lib/models/cart.dart`'s `CartItem.quantity` is `int`) — so
/// a fractional quantity here would only ever come from another system
/// entirely, which is out of scope.
///
/// `discountRate`/`taxRate` are derived from the server's authoritative
/// `discountAmount`/`taxAmount` against the recomputed subtotal (sum of line
/// totals) rather than stored directly, since `Order.totals` always
/// recomputes from `OrderTotals.from(subtotal, taxRate, discountRate)` — this
/// keeps a synced-back `Order`'s totals matching what the server actually
/// charged, without adding a second, parallel "totals" representation to the
/// model.
Order orderFromCachedRow({
  required CachedSale sale,
  required List<CachedSaleLineItem> lines,
  required Map<String, CachedItem> itemsById,
  String? localOrderId,
}) {
  final orderLines = [
    for (final line in lines)
      OrderLine(
        itemId: line.itemId,
        name: itemsById[line.itemId]?.name ?? 'Removed item',
        emoji: '📦',
        unitPrice: _toDouble(line.unitPrice),
        quantity: _toDouble(line.quantity).round(),
        unitCost: line.unitCost == null ? null : _toDouble(line.unitCost!),
      ),
  ];

  final subtotal = orderLines.fold(0.0, (sum, line) => sum + line.lineTotal);
  final discountAmount = _toDouble(sale.discountAmount);
  final taxAmount = _toDouble(sale.taxAmount);
  final taxableAmount = subtotal - discountAmount;

  return Order(
    id: localOrderId ?? sale.clientSaleId,
    serverSaleId: sale.id,
    lines: orderLines,
    placedAt: sale.occurredAt,
    paymentType: paymentMethodFromBackend(sale.paymentMethod),
    status: orderStatusFromBackend(sale.status),
    taxRate: taxableAmount > 0 ? taxAmount / taxableAmount : 0,
    discountRate: subtotal > 0 ? discountAmount / subtotal : 0,
    customerId: sale.customerId,
  );
}
