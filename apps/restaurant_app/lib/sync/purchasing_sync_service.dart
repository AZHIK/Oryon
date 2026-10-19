/// Syncs the supplier directory from Inventory Service and caches it
/// locally.
///
/// `PurchasingSyncService` pulls the supplier directory, upserting into
/// `CachedSuppliers`. Mirrors `CatalogSyncService`'s shape but kept as its
/// own class rather than folded into it — that class's constructor is keyed
/// to a single `InventoryCatalogApi`, and adding another unrelated API
/// dependency to it would widen every existing call site for a feature
/// that doesn't need it.
library;

import 'package:drift/drift.dart';
import '../database/app_database.dart';
import 'suppliers_catalog_api.dart';

class PurchasingSyncService {
  final AppDatabase _db;
  final SuppliersCatalogApi _suppliersApi;

  DateTime? lastSyncTime;
  String? lastSyncError;

  PurchasingSyncService({
    required this._db,
    required this._suppliersApi,
  });

  /// Pulls the full supplier directory and upserts into cache. Suppliers
  /// have no soft-delete-on-missing logic to run here — deletion is a
  /// server-side flag (`isDeleted`) already present on every pulled row,
  /// always requested via `include_deleted=true`.
  Future<void> syncSuppliers() async {
    final runStartedAt = DateTime.now();
    lastSyncError = null;

    try {
      final suppliers = await _suppliersApi.fetchSuppliers();

      for (final supplier in suppliers) {
        await _db.into(_db.cachedSuppliers).insertOnConflictUpdate(
          CachedSuppliersCompanion(
            id: Value(supplier.id),
            businessId: Value(supplier.businessId),
            name: Value(supplier.name),
            phone: Value(supplier.phone),
            email: Value(supplier.email),
            addressLine1: Value(supplier.addressLine1),
            notes: Value(supplier.notes),
            updatedAt: Value(supplier.updatedAt),
            isDeleted: Value(supplier.isDeleted),
            createdAt: Value(supplier.createdAt),
            lastSyncedAt: Value(runStartedAt),
          ),
        );
      }

      lastSyncTime = DateTime.now();
    } catch (e) {
      lastSyncError = e.toString();
    }
  }
}
