/// Line items of a cached sale, pulled from POS Service's per-sale detail
/// endpoint.
///
/// `CachedSaleLineItems` mirrors the backend's `SaleLineItemRead` schema
/// (from `services/pos-service/app/schemas/line_items.py`) — the read-side
/// counterpart to `PendingSaleLineItems`. Fetched once per sale (line items
/// on a synced sale never change) rather than on every list pull, since
/// `GET /sales` returns the ledger row without line items.
library;

import 'package:drift/drift.dart';
import '../converters/decimal_converter.dart';
import 'cached_sales.dart';

/// Line items of a cached sale.
class CachedSaleLineItems extends Table {
  /// Line item UUID, assigned by POS Service (primary key).
  TextColumn get id => text()();

  /// The sale this line belongs to.
  TextColumn get saleId => text().references(CachedSales, #id, onDelete: KeyAction.cascade)();

  /// Item UUID from the inventory catalog.
  /// Soft-references `CachedItems.id` without an FK constraint, matching
  /// `PendingSaleLineItems` — a completed sale's line stays valid even if
  /// the item is later retired from the catalog.
  TextColumn get itemId => text()();

  TextColumn get quantity => text().map(const DecimalConverter())();

  TextColumn get unitPrice => text().map(const DecimalConverter())();

  TextColumn get discountAmount => text().map(const DecimalConverter())();

  /// Server-computed `quantity*unitPrice - discountAmount`.
  TextColumn get lineTotal => text().map(const DecimalConverter())();

  /// Per-unit production cost snapshot at sale time. Zero means
  /// unknown-but-frozen; null is legacy sales synced before snapshots
  /// existed — profit figures value those rows at live recipe costs and
  /// flag the total estimated.
  TextColumn get unitCost =>
      text().map(const DecimalConverter()).nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
