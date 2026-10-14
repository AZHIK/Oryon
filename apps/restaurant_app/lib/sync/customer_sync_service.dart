/// Core sync engine for offline-first customer sync.
///
/// `CustomerSyncService` implements the same outbox pattern as
/// `SyncService`/`FinanceSyncService` (claim → batch → API call → per-row
/// status update → retry), duplicated rather than generalized — Drift's
/// generated table/companion classes share no supertype exposing
/// `syncStatus`/`syncAttemptCount`, so a type-safe shared implementation
/// would cost more than the ~100 duplicated lines saved, and risks the
/// working, tested sales/finance sync paths in the attempt. Roughly half
/// the size of `FinanceSyncService` — one entity, no receipt-upload step.
///
/// **Must drain before `SyncService`** (the sales outbox): a sale carrying
/// a `customerId` whose row hasn't reached the server yet fails its FK
/// insert and has to retry. See `sync_trigger_provider.dart` and
/// `OrdersNotifier._writeAndSync` for where that ordering is enforced.
library;

import 'package:drift/drift.dart';
import '../constants/app_limits.dart';
import '../database/app_database.dart';
import 'customer_sync_api.dart';
import 'customer_sync_dtos.dart';

/// Core sync engine for customers.
class CustomerSyncService {
  static const int _maxBatchSize = AppLimits.syncBatchSize;

  final AppDatabase _db;
  final CustomerSyncApi _api;

  Future<void>? _inFlight;

  DateTime? lastSyncTime;
  String? lastSyncError;

  bool get isSyncing => _inFlight != null;

  CustomerSyncService({required this._db, required this._api});

  /// Syncs pending customers with the backend. Returns the same Future if
  /// a sync is already in progress (reentrancy guard).
  Future<void> syncNow() {
    if (_inFlight != null) return _inFlight!;
    _inFlight = _doSync();
    return _inFlight!.whenComplete(() => _inFlight = null);
  }

  Future<void> _doSync() async {
    lastSyncError = null;

    while (true) {
      final claimed = await _claimBatch();
      if (claimed.isEmpty) break;

      try {
        final dtos = [for (final row in claimed) _customerDto(row)];
        final result = await _api.syncCustomers(dtos);
        final byId = {for (final r in result.results) r.clientCustomerId: r};

        for (final row in claimed) {
          final apiResult = byId[row.customerId];
          await _applyResult(row, apiResult);
        }

        lastSyncTime = DateTime.now();

        if (claimed.length < _maxBatchSize) break;
      } catch (e) {
        for (final row in claimed) {
          await (_db.update(_db.customerEntries)
                ..where((r) => r.id.equals(row.id)))
              .write(CustomerEntriesCompanion(
                syncStatus: const Value('pending'),
                syncAttemptCount: Value(row.syncAttemptCount + 1),
                lastAttemptAt: Value(DateTime.now()),
              ));
        }
        lastSyncError = e.toString();
        break;
      }
    }
  }

  Future<List<CustomerEntry>> _claimBatch() async {
    return await _db.transaction(() async {
      final pending = await (_db.select(_db.customerEntries)
            ..where((row) => row.syncStatus.isIn(const ['pending', 'failed']))
            ..orderBy([(row) => OrderingTerm(
              expression: row.createdAt,
              mode: OrderingMode.asc,
            )])
            ..limit(_maxBatchSize))
          .get();

      if (pending.isEmpty) return <CustomerEntry>[];

      final ids = pending.map((p) => p.id).toList();
      await (_db.update(_db.customerEntries)..where((row) => row.id.isIn(ids)))
          .write(const CustomerEntriesCompanion(syncStatus: Value('syncing')));

      return pending;
    });
  }

  CustomerDto _customerDto(CustomerEntry row) => CustomerDto(
        id: row.customerId,
        name: row.name,
        phone: row.phone,
        email: row.email,
        addressLine1: row.addressLine1,
        joinedAt: row.joinedAt,
      );

  Future<void> _applyResult(
    CustomerEntry row,
    CustomerSyncRowResult? apiResult,
  ) async {
    if (apiResult == null) {
      await (_db.update(_db.customerEntries)..where((r) => r.id.equals(row.id)))
          .write(const CustomerEntriesCompanion(syncStatus: Value('pending')));
    } else if (apiResult.status == 'failed') {
      await (_db.update(_db.customerEntries)..where((r) => r.id.equals(row.id)))
          .write(CustomerEntriesCompanion(
            syncStatus: const Value('failed'),
            syncError: Value(apiResult.reason),
            syncAttemptCount: Value(row.syncAttemptCount + 1),
            lastAttemptAt: Value(DateTime.now()),
          ));
      lastSyncError = apiResult.reason;
    } else {
      await (_db.update(_db.customerEntries)..where((r) => r.id.equals(row.id)))
          .write(CustomerEntriesCompanion(
            syncStatus: const Value('synced'),
            syncedAt: Value(DateTime.now()),
          ));
    }
  }
}
