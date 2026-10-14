/// Syncs the item catalog and stock levels from Inventory Service and caches
/// them locally.
///
/// `CatalogSyncService` pulls the full item list and stock levels for the
/// current store, upserts into `CachedItems`/`CachedStockLevels` (insert
/// new, update changed), and soft-deletes items no longer in the source
/// (marking `isActive = false` rather than row-deleting, to preserve
/// references from completed sales).
library;

import 'package:drift/drift.dart';
import '../database/app_database.dart';
import 'inventory_catalog_api.dart';

/// Syncs the inventory catalog and stock levels into local cache.
class CatalogSyncService {
  final AppDatabase _db;
  final InventoryCatalogApi _api;

  /// Timestamp of the last successful sync (catalog or stock levels).
  DateTime? lastSyncTime;

  /// Error from the last sync attempt, if any.
  String? lastSyncError;

  CatalogSyncService({required this._db, required this._api});

  /// Runs [syncCatalog] then [syncStockLevels] for [storeId]. Convenience
  /// for call sites (e.g. right after login) that want both in one call.
  Future<void> syncAll({
    required String businessId,
    required String storeId,
  }) async {
    await syncCatalog(storeId: storeId);
    await syncStockLevels(storeId: storeId);
  }

  /// Pulls the full catalog for a store and upserts into cache.
  ///
  /// - Fetches all items from the API.
  /// - Upserts each: insert if new id, update if `updatedAtServer` changed.
  /// - Marks items not in the new pull as inactive (soft-delete).
  Future<void> syncCatalog({required String storeId}) async {
    final runStartedAt = DateTime.now();
    lastSyncError = null;

    try {
      final items = await _api.fetchItems(storeId: storeId);

      final seenIds = <String>{};

      for (final item in items) {
        seenIds.add(item.id);
        await _db
            .into(_db.cachedItems)
            .insertOnConflictUpdate(
              CachedItemsCompanion(
                id: Value(item.id),
                businessId: Value(item.businessId),
                businessLocationId: Value(item.storeId),
                name: Value(item.name),
                unitOfMeasure: const Value('unit'),
                unitId: Value(item.unitId ?? ''),
                category: Value(item.category),
                supplierId: Value(item.supplierId ?? ''),
                reorderThreshold: Value(item.reorderThreshold),
                reorderQuantity: Value(item.reorderQuantity),
                sellingPrice: Value(item.sellingPrice),
                unitCost: Value(item.unitCost),
                allowNegativeStock: Value(item.allowNegativeStock),
                itemType: Value(item.itemType),
                isActive: Value(item.isActive),
                imageUrl: Value(item.imageUrl),
                createdAtServer: Value(item.createdAt),
                updatedAtServer: Value(item.updatedAt),
                lastSeenAt: Value(runStartedAt),
                lastSyncedAt: Value(runStartedAt),
              ),
            );
      }

      // Soft-delete items not in this pull (mark inactive). Scoped to this
      // store only — a soft-delete must not touch another store's items
      // cached from a prior business context on this device.
      final storeItems = await (_db.select(
        _db.cachedItems,
      )..where((row) => row.businessLocationId.equals(storeId))).get();
      for (final item in storeItems) {
        if (!seenIds.contains(item.id) && item.isActive) {
          await (_db.update(_db.cachedItems)
                ..where((row) => row.id.equals(item.id)))
              .write(const CachedItemsCompanion(isActive: Value(false)));
        }
      }

      lastSyncTime = DateTime.now();
    } catch (e) {
      lastSyncError = e.toString();
    }
  }

  /// Pulls current stock levels for a store and upserts into cache.
  ///
  /// Unlike the catalog, stock levels are never soft-deleted on a missing
  /// row — `CachedStockLevels` is a pull-only display hint (see its table
  /// doc comment); a row simply not coming back this pull is not a signal
  /// worth acting on.
  Future<void> syncStockLevels({required String storeId}) async {
    final runStartedAt = DateTime.now();
    lastSyncError = null;

    try {
      final levels = await _api.fetchStockLevels(storeId: storeId);

      for (final level in levels) {
        await _db
            .into(_db.cachedStockLevels)
            .insertOnConflictUpdate(
              CachedStockLevelsCompanion(
                itemId: Value(level.itemId),
                businessLocationId: Value(level.storeId),
                currentQuantity: Value(level.currentQuantity),
                cachedAt: Value(runStartedAt),
              ),
            );
      }

      lastSyncTime = DateTime.now();
    } catch (e) {
      lastSyncError = e.toString();
    }
  }
}
