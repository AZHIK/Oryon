/// Pulls the customer ledger from POS Service and caches it locally.
///
/// `CustomerLedgerSyncService` is the read-side counterpart to
/// `CustomerSyncService` (which pushes pending customers), mirroring how
/// `FinanceLedgerSyncService` pairs with `FinanceSyncService`. Always
/// pulls with `include_deleted=true` and mirrors `isDeleted` straight into
/// the cache — a delete made on one device removes the customer from
/// every other device's list on next sync.
library;

import 'package:drift/drift.dart';
import '../database/app_database.dart';
import 'customer_catalog_api.dart';

/// Syncs the customer ledger into local cache.
class CustomerLedgerSyncService {
  final AppDatabase _db;
  final CustomerCatalogApi _api;

  DateTime? lastSyncTime;
  String? lastSyncError;

  CustomerLedgerSyncService({required this._db, required this._api});

  /// Pulls all customers for the business and upserts into cache.
  Future<void> syncCustomers() async {
    final runStartedAt = DateTime.now();
    lastSyncError = null;
    try {
      final customers = await _api.fetchCustomers();
      for (final customer in customers) {
        await _db.into(_db.cachedCustomers).insertOnConflictUpdate(
          CachedCustomersCompanion(
            id: Value(customer.id),
            businessId: Value(customer.businessId),
            name: Value(customer.name),
            phone: Value(customer.phone),
            email: Value(customer.email),
            addressLine1: Value(customer.addressLine1),
            actorId: Value(customer.actorId),
            joinedAt: Value(customer.joinedAt),
            syncedAt: Value(customer.syncedAt),
            updatedAt: Value(customer.updatedAt),
            isDeleted: Value(customer.isDeleted),
            createdAt: Value(customer.createdAt),
            totalOrders: Value(customer.totalOrders),
            totalSpent: Value(customer.totalSpent),
            lastOrderAt: Value(customer.lastOrderAt),
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
