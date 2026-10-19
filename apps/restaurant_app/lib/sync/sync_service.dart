/// Core sync engine for offline-first sales sync.
///
/// `SyncService` implements the outbox pattern: reads pending sales from
/// the local database, batches them, calls the API, and updates local
/// status based on the response. It handles:
/// - Concurrency safety (row-claim pattern for cross-isolate safety)
/// - Partial batch failure (per-row status updates)
/// - Retry logic (failed sales are retried on the next sync)
/// - Idempotency (synced rows are never re-uploaded)
library;

import 'package:drift/drift.dart';
import '../constants/app_limits.dart';
import '../database/app_database.dart';
import 'pos_sync_api.dart';
import 'sync_dtos.dart';
import 'sync_tick.dart';

/// Core sync engine for POS sales.
class SyncService {
  static const int _maxBatchSize = AppLimits.syncBatchSize;

  final AppDatabase _db;
  final PosSyncApi _api;

  /// In-isolate reentrancy guard.
  Future<void>? _inFlight;

  /// Timestamp of the last successful sync.
  DateTime? lastSyncTime;

  /// Error message from the last sync attempt (if any).
  String? lastSyncError;

  /// Whether a sync is currently in progress.
  bool get isSyncing => _inFlight != null;

  SyncService({
    required this._db,
    required this._api,
  });

  /// Returns pending sales in sync order (created first).
  Future<List> queryPendingSales() {
    return (_db.select(_db.pendingSales)
          ..where((row) =>
              row.syncStatus.isIn(const ['pending', 'failed']))
          ..orderBy([(row) => OrderingTerm(
            expression: row.createdAt,
            mode: OrderingMode.asc,
          )]))
        .get();
  }

  /// Syncs pending sales with the backend.
  ///
  /// - Claims pending rows with a row-claim transaction (cross-isolate safety)
  /// - Batches up to `_maxBatchSize` rows per API call
  /// - Updates status based on response
  /// - Retries failed rows on subsequent calls
  /// - Returns the same Future if a sync is already in progress (reentrancy guard)
  Future<void> syncNow() {
    if (_inFlight != null) {
      return _inFlight!;
    }

    _inFlight = _doSync();
    return _inFlight!.whenComplete(() {
      _inFlight = null;
    });
  }

  Future<void> _doSync() async {
    lastSyncError = null;

    while (true) {
      // Claim the next batch in a transaction.
      final claimed = await _claimBatch();
      if (claimed.isEmpty) {
        break; // No more pending sales.
      }

      // Build DTOs for the API call.
      final dtos = <PendingSaleDto>[];
      for (final row in claimed) {
        final lineItems = await (_db.select(_db.pendingSaleLineItems)
              ..where((li) => li.pendingSaleId.equals(row.id)))
            .get();

        dtos.add(PendingSaleDto(
          clientSaleId: row.clientSaleId,
          status: row.status,
          storeId: row.storeId,
          lineItems: lineItems
              .map((li) => PendingSaleLineItemDto(
                itemId: li.itemId,
                quantity: li.quantity,
                unitPrice: li.unitPrice,
                discountAmount: li.discountAmount,
                unitCost: li.unitCost,
              ))
              .toList(),
          discountAmount: row.discountAmount,
          paymentMethod: row.paymentMethod,
          customerId: row.customerId,
          occurredAt: row.occurredAt,
          deviceSequence: row.deviceSequence,
          voidOrRefundReason: row.voidOrRefundReason,
        ));
      }

      // Try to sync.
      try {
        final result = await _api.syncSales(dtos);

        // Update rows based on API response.
        final resultsByClientId = {
          for (final r in result.results) r.clientSaleId: r,
        };

        for (final row in claimed) {
          final apiResult = resultsByClientId[row.clientSaleId];
          if (apiResult == null) {
            // Defensive: API didn't return a result for this sale.
            await (_db.update(_db.pendingSales)
                  ..where((r) => r.id.equals(row.id)))
                .write(PendingSalesCompanion(
                  syncStatus: const Value('pending'),
                ));
          } else if (apiResult.status == 'failed') {
            // Sync failed for this sale.
            await (_db.update(_db.pendingSales)
                  ..where((r) => r.id.equals(row.id)))
                .write(PendingSalesCompanion(
                  syncStatus: const Value('failed'),
                  syncError: Value(apiResult.reason),
                  syncAttemptCount: Value(row.syncAttemptCount + 1),
                  lastAttemptAt: Value(DateTime.now()),
                ));
            lastSyncError = apiResult.reason;
          } else {
            // Sync succeeded (created or duplicate).
            await (_db.update(_db.pendingSales)
                  ..where((r) => r.id.equals(row.id)))
                .write(PendingSalesCompanion(
                  syncStatus: const Value('synced'),
                  syncedAt: Value(DateTime.now()),
                ));
          }
        }

        lastSyncTime = DateTime.now();
        await recordSyncTick(_db, SyncArea.sales);

        // If we got fewer than max batch size, we're done.
        if (claimed.length < _maxBatchSize) {
          break;
        }
      } catch (e) {
        // Network error: revert claimed rows to pending.
        for (final row in claimed) {
          await (_db.update(_db.pendingSales)
                ..where((r) => r.id.equals(row.id)))
              .write(PendingSalesCompanion(
                syncStatus: const Value('pending'),
                syncAttemptCount: Value(row.syncAttemptCount + 1),
                lastAttemptAt: Value(DateTime.now()),
              ));
        }
        lastSyncError = e.toString();
        break; // Stop retrying on network error.
      }
    }
  }

  /// Claims up to `_maxBatchSize` pending rows in one transaction.
  Future<List> _claimBatch() async {
    return await _db.transaction(() async {
      final pending = await (_db.select(_db.pendingSales)
            ..where((row) =>
                row.syncStatus.isIn(const ['pending', 'failed']))
            ..orderBy([(row) => OrderingTerm(
              expression: row.createdAt,
              mode: OrderingMode.asc,
            )])
            ..limit(_maxBatchSize))
          .get();

      if (pending.isEmpty) {
        return [];
      }

      // Flip all to 'syncing' in the same transaction.
      final ids = pending.map((p) => p.id).toList();
      await (_db.update(_db.pendingSales)
            ..where((row) => row.id.isIn(ids)))
          .write(const PendingSalesCompanion(
            syncStatus: Value('syncing'),
          ));

      return pending;
    });
  }
}
