/// Core sync engine for offline-first expense/income sync.
///
/// `FinanceSyncService` implements the same outbox pattern as `SyncService`
/// (claim → batch → API call → per-row status update → retry), duplicated
/// rather than generalized: Drift's generated table/companion classes share
/// no supertype exposing `syncStatus`/`syncAttemptCount`, so a type-safe
/// shared implementation would cost more than the ~120 duplicated lines
/// saved, and risks the working, tested sales sync path in the attempt.
///
/// One addition `SyncService` doesn't need: a claimed row with a
/// `localReceiptPath` but no `receiptAttachmentId` yet gets its receipt
/// uploaded *before* the batch sync call, so the entry payload can carry a
/// resolved `receipt_attachment_id`. If the upload fails, that row is left
/// `failed` for this pass rather than synced without its receipt — losing
/// the receipt-entry link permanently once an entry is `synced` is worse
/// than retrying the whole row next sync.
library;

import 'dart:io';

import 'package:drift/drift.dart';
import '../constants/app_limits.dart';
import '../database/app_database.dart';
import 'finance_sync_api.dart';
import 'finance_sync_dtos.dart';
import 'sync_tick.dart';

/// Core sync engine for other-expenses/other-incomes.
class FinanceSyncService {
  static const int _maxBatchSize = AppLimits.syncBatchSize;

  final AppDatabase _db;
  final FinanceSyncApi _api;

  Future<void>? _inFlight;

  DateTime? lastSyncTime;
  String? lastSyncError;

  bool get isSyncing => _inFlight != null;

  FinanceSyncService({required this._db, required this._api});

  /// Syncs pending expenses and incomes with the backend. Returns the same
  /// Future if a sync is already in progress (reentrancy guard).
  Future<void> syncNow() {
    if (_inFlight != null) return _inFlight!;
    _inFlight = _doSync();
    return _inFlight!.whenComplete(() => _inFlight = null);
  }

  Future<void> _doSync() async {
    lastSyncError = null;
    await _drainExpenses();
    await _drainIncomes();
    lastSyncTime = DateTime.now();
    await recordSyncTick(_db, SyncArea.finance);
  }

  // ── Expenses ────────────────────────────────────────────────────────

  Future<void> _drainExpenses() async {
    while (true) {
      final claimed = await _claimExpenseBatch();
      if (claimed.isEmpty) break;

      final resolved = await _resolveExpenseReceipts(claimed);

      try {
        final dtos = [for (final row in resolved) _expenseDto(row)];
        final result = await _api.syncExpenses(dtos);
        final byClientId = {for (final r in result.results) r.clientEntryId: r};

        for (final row in resolved) {
          final apiResult = byClientId[row.expenseId];
          await _applyExpenseResult(row, apiResult);
        }

        if (claimed.length < _maxBatchSize) break;
      } catch (e) {
        for (final row in claimed) {
          await (_db.update(_db.expenseEntries)
                ..where((r) => r.id.equals(row.id)))
              .write(ExpenseEntriesCompanion(
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

  Future<List<ExpenseEntry>> _claimExpenseBatch() async {
    return await _db.transaction(() async {
      final pending = await (_db.select(_db.expenseEntries)
            ..where((row) => row.syncStatus.isIn(const ['pending', 'failed']))
            ..orderBy([(row) => OrderingTerm(
              expression: row.createdAt,
              mode: OrderingMode.asc,
            )])
            ..limit(_maxBatchSize))
          .get();

      if (pending.isEmpty) return <ExpenseEntry>[];

      final ids = pending.map((p) => p.id).toList();
      await (_db.update(_db.expenseEntries)..where((row) => row.id.isIn(ids)))
          .write(const ExpenseEntriesCompanion(syncStatus: Value('syncing')));

      return pending;
    });
  }

  /// Uploads any claimed row's local receipt that hasn't been uploaded yet,
  /// persisting the returned attachment id immediately so a crash between
  /// upload and the batch sync call orphans at most one server-side file.
  /// Returns the rows with their in-memory `receiptAttachmentId` refreshed.
  Future<List<ExpenseEntry>> _resolveExpenseReceipts(
    List<ExpenseEntry> rows,
  ) async {
    final resolved = <ExpenseEntry>[];
    for (var row in rows) {
      if (row.localReceiptPath != null && row.receiptAttachmentId == null) {
        try {
          final attachmentId = await _uploadReceiptFile(row.localReceiptPath!);
          await (_db.update(_db.expenseEntries)
                ..where((r) => r.id.equals(row.id)))
              .write(ExpenseEntriesCompanion(
                receiptAttachmentId: Value(attachmentId),
              ));
          row = row.copyWith(receiptAttachmentId: Value(attachmentId));
        } catch (e) {
          await (_db.update(_db.expenseEntries)
                ..where((r) => r.id.equals(row.id)))
              .write(ExpenseEntriesCompanion(
                syncStatus: const Value('failed'),
                syncError: Value('Receipt upload failed: $e'),
                syncAttemptCount: Value(row.syncAttemptCount + 1),
                lastAttemptAt: Value(DateTime.now()),
              ));
          continue; // Skip this row for this pass; it'll retry next sync.
        }
      }
      resolved.add(row);
    }
    return resolved;
  }

  OtherExpenseDto _expenseDto(ExpenseEntry row) => OtherExpenseDto(
        clientExpenseId: row.expenseId,
        storeId: row.storeId,
        category: row.category,
        amount: row.amount,
        description: row.description ?? '',
        paymentMethod: row.paymentMethod,
        payee: row.payee,
        note: row.note,
        receiptAttachmentId: row.receiptAttachmentId,
        occurredAt: row.occurredAt,
      );

  Future<void> _applyExpenseResult(
    ExpenseEntry row,
    FinanceSyncRowResult? apiResult,
  ) async {
    if (apiResult == null) {
      await (_db.update(_db.expenseEntries)..where((r) => r.id.equals(row.id)))
          .write(const ExpenseEntriesCompanion(syncStatus: Value('pending')));
    } else if (apiResult.status == 'failed') {
      await (_db.update(_db.expenseEntries)..where((r) => r.id.equals(row.id)))
          .write(ExpenseEntriesCompanion(
            syncStatus: const Value('failed'),
            syncError: Value(apiResult.reason),
            syncAttemptCount: Value(row.syncAttemptCount + 1),
            lastAttemptAt: Value(DateTime.now()),
          ));
      lastSyncError = apiResult.reason;
    } else {
      await (_db.update(_db.expenseEntries)..where((r) => r.id.equals(row.id)))
          .write(ExpenseEntriesCompanion(
            syncStatus: const Value('synced'),
            syncedAt: Value(DateTime.now()),
          ));
    }
  }

  // ── Incomes ─────────────────────────────────────────────────────────

  Future<void> _drainIncomes() async {
    while (true) {
      final claimed = await _claimIncomeBatch();
      if (claimed.isEmpty) break;

      final resolved = await _resolveIncomeReceipts(claimed);

      try {
        final dtos = [for (final row in resolved) _incomeDto(row)];
        final result = await _api.syncIncomes(dtos);
        final byClientId = {for (final r in result.results) r.clientEntryId: r};

        for (final row in resolved) {
          final apiResult = byClientId[row.incomeId];
          await _applyIncomeResult(row, apiResult);
        }

        if (claimed.length < _maxBatchSize) break;
      } catch (e) {
        for (final row in claimed) {
          await (_db.update(_db.otherIncomeEntries)
                ..where((r) => r.id.equals(row.id)))
              .write(OtherIncomeEntriesCompanion(
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

  Future<List<OtherIncomeEntry>> _claimIncomeBatch() async {
    return await _db.transaction(() async {
      final pending = await (_db.select(_db.otherIncomeEntries)
            ..where((row) => row.syncStatus.isIn(const ['pending', 'failed']))
            ..orderBy([(row) => OrderingTerm(
              expression: row.createdAt,
              mode: OrderingMode.asc,
            )])
            ..limit(_maxBatchSize))
          .get();

      if (pending.isEmpty) return <OtherIncomeEntry>[];

      final ids = pending.map((p) => p.id).toList();
      await (_db.update(_db.otherIncomeEntries)..where((row) => row.id.isIn(ids)))
          .write(const OtherIncomeEntriesCompanion(syncStatus: Value('syncing')));

      return pending;
    });
  }

  Future<List<OtherIncomeEntry>> _resolveIncomeReceipts(
    List<OtherIncomeEntry> rows,
  ) async {
    final resolved = <OtherIncomeEntry>[];
    for (var row in rows) {
      if (row.localReceiptPath != null && row.receiptAttachmentId == null) {
        try {
          final attachmentId = await _uploadReceiptFile(row.localReceiptPath!);
          await (_db.update(_db.otherIncomeEntries)
                ..where((r) => r.id.equals(row.id)))
              .write(OtherIncomeEntriesCompanion(
                receiptAttachmentId: Value(attachmentId),
              ));
          row = row.copyWith(receiptAttachmentId: Value(attachmentId));
        } catch (e) {
          await (_db.update(_db.otherIncomeEntries)
                ..where((r) => r.id.equals(row.id)))
              .write(OtherIncomeEntriesCompanion(
                syncStatus: const Value('failed'),
                syncError: Value('Receipt upload failed: $e'),
                syncAttemptCount: Value(row.syncAttemptCount + 1),
                lastAttemptAt: Value(DateTime.now()),
              ));
          continue;
        }
      }
      resolved.add(row);
    }
    return resolved;
  }

  OtherIncomeDto _incomeDto(OtherIncomeEntry row) => OtherIncomeDto(
        clientIncomeId: row.incomeId,
        storeId: row.storeId,
        category: row.category,
        amount: row.amount,
        description: row.description ?? '',
        paymentMethod: row.paymentMethod,
        source: row.source,
        note: row.note,
        receiptAttachmentId: row.receiptAttachmentId,
        occurredAt: row.occurredAt,
      );

  Future<void> _applyIncomeResult(
    OtherIncomeEntry row,
    FinanceSyncRowResult? apiResult,
  ) async {
    if (apiResult == null) {
      await (_db.update(_db.otherIncomeEntries)..where((r) => r.id.equals(row.id)))
          .write(const OtherIncomeEntriesCompanion(syncStatus: Value('pending')));
    } else if (apiResult.status == 'failed') {
      await (_db.update(_db.otherIncomeEntries)..where((r) => r.id.equals(row.id)))
          .write(OtherIncomeEntriesCompanion(
            syncStatus: const Value('failed'),
            syncError: Value(apiResult.reason),
            syncAttemptCount: Value(row.syncAttemptCount + 1),
            lastAttemptAt: Value(DateTime.now()),
          ));
      lastSyncError = apiResult.reason;
    } else {
      await (_db.update(_db.otherIncomeEntries)..where((r) => r.id.equals(row.id)))
          .write(OtherIncomeEntriesCompanion(
            syncStatus: const Value('synced'),
            syncedAt: Value(DateTime.now()),
          ));
    }
  }

  // ── Shared ──────────────────────────────────────────────────────────

  Future<String> _uploadReceiptFile(String localPath) async {
    final file = File(localPath);
    final bytes = await file.readAsBytes();
    return _api.uploadReceipt(
      bytes: Uint8List.fromList(bytes),
      filename: file.uri.pathSegments.isNotEmpty
          ? file.uri.pathSegments.last
          : 'receipt',
      contentType: _contentTypeFor(localPath),
    );
  }

  String _contentTypeFor(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    return 'image/jpeg';
  }
}
