/// Writes completed orders to the PendingSales table for sync.
///
/// After `orders_provider.dart`'s `placeOrder()` creates an Order,
/// `PendingSaleWriter` converts it to a `PendingSales` + `PendingSaleLineItems`
/// row so it can be synced to the backend. If the order's items don't resolve
/// to valid catalog items, the entire sale is skipped (never partial/wrong).
library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../models/order.dart';
import 'order_mapper.dart';

/// Writes orders to the pending-sales sync table.
class PendingSaleWriter {
  final AppDatabase _db;

  PendingSaleWriter(this._db);

  /// Converts [order] to `PendingSales` + line items if every line's item
  /// resolves to an active, cached catalog item for [storeId].
  ///
  /// Returns true if written, false if skipped. A line fails to resolve when
  /// there's no store context at all (nothing is cached to resolve against)
  /// or an item was archived between
  /// being rung up and the order completing; either way, skipping the whole
  /// sale is correct — a partially-resolved sale would understate what was
  /// actually sold.
  Future<bool> writeIfMappable(Order order, {required String storeId}) async {
    final itemIds = order.lines.map((line) => line.itemId).toSet();
    final cachedItems = await (_db.select(_db.cachedItems)
          ..where(
            (row) =>
                row.id.isIn(itemIds) &
                row.businessLocationId.equals(storeId) &
                row.isActive.equals(true),
          ))
        .get();
    final resolvedIds = cachedItems.map((item) => item.id).toSet();
    if (!itemIds.every(resolvedIds.contains)) return false;

    final clientSaleId = const Uuid().v4();

    await _db.transaction(() async {
      final pendingSaleId = await _db.into(_db.pendingSales).insert(
        PendingSalesCompanion.insert(
          clientSaleId: clientSaleId,
          status: orderStatusToBackend(order.status),
          storeId: storeId,
          discountAmount: Value(Decimal.parse(order.discount.toStringAsFixed(2))),
          paymentMethod: paymentMethodToBackend(order.paymentType),
          customerId: Value(order.customerId),
          occurredAt: order.placedAt,
          localOrderId: Value(order.id),
          createdAt: DateTime.now(),
        ),
      );

      for (final line in order.lines) {
        await _db.into(_db.pendingSaleLineItems).insert(
          PendingSaleLineItemsCompanion.insert(
            pendingSaleId: pendingSaleId,
            itemId: line.itemId,
            quantity: Decimal.parse(line.quantity.toString()),
            unitPrice: Decimal.parse(line.unitPrice.toStringAsFixed(2)),
            unitCost: Value(
              line.unitCost == null
                  ? null
                  : Decimal.parse(line.unitCost.toString()),
            ),
          ),
        );
      }
    });

    return true;
  }
}
