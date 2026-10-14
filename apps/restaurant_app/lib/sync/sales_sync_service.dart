/// Pulls completed sales from POS Service and caches them locally.
///
/// `SalesSyncService` is the read-side counterpart to `SyncService` (which
/// pushes pending sales), mirroring how `CatalogSyncService` pairs with
/// Inventory Service's write-side `InventoryApiService`. It pulls the sales
/// ledger for a store, upserts into `CachedSales`, and fetches+caches line
/// items for any sale not already cached.
///
/// Unlike `CatalogSyncService.syncCatalog`, there is no soft-delete pass: a
/// sale is immutable history once created — a void/refund updates the same
/// row's `status`/`voidedAt`/`refundedAt` rather than removing it, so simply
/// re-pulling and overwriting keeps the cache correct.
library;

import 'package:drift/drift.dart';
import '../database/app_database.dart';
import 'pos_catalog_api.dart';

/// Syncs the completed-sales ledger into local cache.
class SalesSyncService {
  final AppDatabase _db;
  final PosCatalogApi _api;

  /// Timestamp of the last successful sync.
  DateTime? lastSyncTime;

  /// Error from the last sync attempt, if any.
  String? lastSyncError;

  SalesSyncService({required this._db, required this._api});

  /// Pulls the sales ledger for [storeId] and upserts into cache, then
  /// fetches line items for any sale seen for the first time.
  Future<void> syncSales({required String storeId}) async {
    final runStartedAt = DateTime.now();
    lastSyncError = null;

    try {
      final sales = await _api.fetchSales(storeId: storeId);
      final existingIds = (await (_db.select(_db.cachedSales)
                ..where((row) => row.storeId.equals(storeId)))
              .get())
          .map((row) => row.id)
          .toSet();

      for (final sale in sales) {
        await _db.into(_db.cachedSales).insertOnConflictUpdate(
          CachedSalesCompanion(
            id: Value(sale.id),
            businessId: Value(sale.businessId),
            storeId: Value(sale.storeId),
            clientSaleId: Value(sale.clientSaleId),
            status: Value(sale.status),
            subtotal: Value(sale.subtotal),
            discountAmount: Value(sale.discountAmount),
            taxAmount: Value(sale.taxAmount),
            total: Value(sale.total),
            paymentMethod: Value(sale.paymentMethod),
            actorId: Value(sale.actorId),
            customerId: Value(sale.customerId),
            occurredAt: Value(sale.occurredAt),
            syncedAt: Value(sale.syncedAt),
            voidedAt: Value(sale.voidedAt),
            refundedAt: Value(sale.refundedAt),
            voidOrRefundReason: Value(sale.voidOrRefundReason),
            createdAt: Value(sale.createdAt),
            lastSyncedAt: Value(runStartedAt),
          ),
        );

        if (!existingIds.contains(sale.id)) {
          final lines = await _api.fetchSaleLineItems(saleId: sale.id);
          for (final line in lines) {
            await _db.into(_db.cachedSaleLineItems).insertOnConflictUpdate(
              CachedSaleLineItemsCompanion(
                id: Value(line.id),
                saleId: Value(line.saleId),
                itemId: Value(line.itemId),
                quantity: Value(line.quantity),
                unitPrice: Value(line.unitPrice),
                discountAmount: Value(line.discountAmount),
                lineTotal: Value(line.lineTotal),
                unitCost: Value(line.unitCost),
              ),
            );
          }
        }
      }

      lastSyncTime = DateTime.now();
    } catch (e) {
      lastSyncError = e.toString();
    }
  }
}
