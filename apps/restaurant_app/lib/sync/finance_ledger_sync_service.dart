/// Pulls the other-expenses/other-incomes ledgers from POS Service and
/// caches them locally.
///
/// `FinanceLedgerSyncService` is the read-side counterpart to
/// `FinanceSyncService` (which pushes pending entries), mirroring how
/// `SalesSyncService` pairs with `SyncService`. Unlike `SalesSyncService`,
/// a finance entry CAN be soft-deleted server-side, so the pull always
/// requests `include_deleted=true` (see `HttpFinanceCatalogApi`) and mirrors
/// `isDeleted` straight into the cache — the simplest correct way for a
/// delete made on one device to reach every other device's list, without a
/// separate missing-row soft-delete pass like `CatalogSyncService`'s.
library;

import 'package:drift/drift.dart';
import '../database/app_database.dart';
import 'finance_catalog_api.dart';

/// Syncs the other-expenses/other-incomes ledgers into local cache.
class FinanceLedgerSyncService {
  final AppDatabase _db;
  final FinanceCatalogApi _api;

  DateTime? lastSyncTime;
  String? lastSyncError;

  FinanceLedgerSyncService({required this._db, required this._api});

  /// Pulls other expenses for [storeId] and upserts into cache.
  Future<void> syncExpenses({required String storeId}) async {
    final runStartedAt = DateTime.now();
    lastSyncError = null;
    try {
      final expenses = await _api.fetchExpenses(storeId: storeId);
      for (final expense in expenses) {
        await _db.into(_db.cachedOtherExpenses).insertOnConflictUpdate(
          CachedOtherExpensesCompanion(
            id: Value(expense.id),
            businessId: Value(expense.businessId),
            storeId: Value(expense.storeId),
            clientExpenseId: Value(expense.clientExpenseId),
            category: Value(expense.category),
            amount: Value(expense.amount),
            description: Value(expense.description),
            payee: Value(expense.payee),
            note: Value(expense.note),
            paymentMethod: Value(expense.paymentMethod),
            receiptAttachmentId: Value(expense.receiptAttachmentId),
            actorId: Value(expense.actorId),
            occurredAt: Value(expense.occurredAt),
            syncedAt: Value(expense.syncedAt),
            updatedAt: Value(expense.updatedAt),
            isDeleted: Value(expense.isDeleted),
            createdAt: Value(expense.createdAt),
            lastSyncedAt: Value(runStartedAt),
          ),
        );
      }
      lastSyncTime = DateTime.now();
    } catch (e) {
      lastSyncError = e.toString();
    }
  }

  /// Pulls other incomes for [storeId] and upserts into cache.
  Future<void> syncIncomes({required String storeId}) async {
    final runStartedAt = DateTime.now();
    lastSyncError = null;
    try {
      final incomes = await _api.fetchIncomes(storeId: storeId);
      for (final income in incomes) {
        await _db.into(_db.cachedOtherIncomes).insertOnConflictUpdate(
          CachedOtherIncomesCompanion(
            id: Value(income.id),
            businessId: Value(income.businessId),
            storeId: Value(income.storeId),
            clientIncomeId: Value(income.clientIncomeId),
            category: Value(income.category),
            amount: Value(income.amount),
            description: Value(income.description),
            source: Value(income.source),
            note: Value(income.note),
            paymentMethod: Value(income.paymentMethod),
            receiptAttachmentId: Value(income.receiptAttachmentId),
            actorId: Value(income.actorId),
            occurredAt: Value(income.occurredAt),
            syncedAt: Value(income.syncedAt),
            updatedAt: Value(income.updatedAt),
            isDeleted: Value(income.isDeleted),
            createdAt: Value(income.createdAt),
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
