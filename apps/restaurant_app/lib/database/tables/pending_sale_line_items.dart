/// Line items within a pending sale.
///
/// `PendingSaleLineItems` mirrors the backend's `SaleLineItemInput` schema
/// (from `services/pos-service/app/schemas/line_items.py`), storing the
/// item, quantity, price, and discount for each line in a sale.
///
/// The `itemId` soft-references `CachedItems.id` **without an FK constraint**
/// (see `CachedItems` table comments for why). An item may be marked inactive
/// in the cache, but any `PendingSaleLineItems` rows that reference it remain
/// valid (the sale is complete and synced; removing the item from the cache
/// should not invalidate completed sales).
library;

import 'package:drift/drift.dart';
import '../converters/decimal_converter.dart';
import 'pending_sales.dart';

/// Line items within a pending sale.
class PendingSaleLineItems extends Table {
  /// Local row ID (autoincrement).
  IntColumn get id => integer().autoIncrement()();

  /// Foreign key to the sale this line belongs to.
  IntColumn get pendingSaleId =>
      integer()
          .references(PendingSales, #id, onDelete: KeyAction.cascade)();

  /// Item UUID from the inventory catalog.
  /// Soft-references `CachedItems.id` without an FK constraint
  /// (see `CachedItems` for rationale).
  TextColumn get itemId => text()();

  /// Quantity sold (strictly positive, validated app-side).
  TextColumn get quantity => text().map(const DecimalConverter())();

  /// Unit price of the item.
  TextColumn get unitPrice => text().map(const DecimalConverter())();

  /// Discount applied to this line.
  TextColumn get discountAmount =>
      text().map(const DecimalConverter()).withDefault(const Constant('0'))();

  /// Per-unit production cost snapshot at sale time. Zero means
  /// unknown-but-frozen (no recipe, nothing on file — flagged estimated
  /// downstream); null is legacy rows synced before snapshots existed.
  /// Synced as JSON number (never null for new sales) and stored
  /// server-side for frozen profit history.
  TextColumn get unitCost =>
      text().map(const DecimalConverter()).nullable()();
}
