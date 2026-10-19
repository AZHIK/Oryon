/// What this device still owes the server: one count per outbox.
///
/// Sales, finance entries and customers each have their own outbox table
/// (`pendingSales`, `expenseEntries`/`otherIncomeEntries`,
/// `customerEntries`); rows sit in `pending`/`failed` until a sync drain
/// marks them `synced`. This snapshot adds the four counts up so every
/// screen can say, in plain words, what is sent and what is still waiting.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_durations.dart';
import '../sync/sync_tick.dart';
import 'customer_api_provider.dart';
import 'database_providers.dart';
import 'finance_api_provider.dart';
import 'permissions_provider.dart';
import 'sync_status_provider.dart';

/// A day in hours — past this without a successful sync, the app warns.
const outboxStaleAfterHours = 24;

/// How many rows per area are still waiting to be sent.
class OutboxStatus {
  const OutboxStatus({
    this.pendingSales = 0,
    this.pendingExpenses = 0,
    this.pendingIncomes = 0,
    this.pendingCustomers = 0,
    this.isSyncing = false,
    this.lastError,
    this.lastSynced,
  });

  final int pendingSales;
  final int pendingExpenses;
  final int pendingIncomes;
  final int pendingCustomers;
  final bool isSyncing;
  final String? lastError;

  /// Freshest successful exchange with the server across every area
  /// (sends and pulls). Null = never synced on this device.
  final DateTime? lastSynced;

  static const idle = OutboxStatus();

  int get total =>
      pendingSales + pendingExpenses + pendingIncomes + pendingCustomers;

  bool get hasPending => total > 0;

  /// True when the last good sync is more than a day ago (or never).
  /// Callers check connectivity separately — being offline explains it.
  bool get isStale {
    final last = lastSynced;
    if (last == null) return true;
    return DateTime.now().difference(last).inHours >= outboxStaleAfterHours;
  }

  /// Whole days since the last good sync, for "Not synced for N days".
  int get staleDays {
    final last = lastSynced;
    if (last == null) return -1;
    return DateTime.now().difference(last).inHours ~/ 24;
  }
}

/// Plain words for [OutboxStatus.lastSynced]: "Today 14:32",
/// "Yesterday 09:10", "3 days ago", "Never synced yet".
String lastSyncedLabel(DateTime? last) {
  if (last == null) return 'Never synced yet';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(last.year, last.month, last.day);
  final days = today.difference(day).inDays;
  final time =
      '${last.hour.toString().padLeft(2, '0')}:${last.minute.toString().padLeft(2, '0')}';
  if (days <= 0) return 'Today $time';
  if (days == 1) return 'Yesterday $time';
  return '$days days ago';
}

/// Live outbox counts, polled every couple of seconds.
///
/// Safe to watch before sign-in: with no business context there is no
/// ledger to report on, so it yields an idle snapshot instead of throwing.
final outboxStatusProvider = StreamProvider<OutboxStatus>((ref) {
  final db = ref.watch(appDatabaseProvider);
  if (ref.watch(currentBusinessIdProvider) == null) {
    return Stream.value(OutboxStatus.idle);
  }

  final sales = ref.watch(syncServiceProvider);
  final finance = ref.watch(financeSyncServiceProvider);
  final customers = ref.watch(customerSyncServiceProvider);

  return Stream<OutboxStatus>.multi((controller) {
    var cancelled = false;
    Timer? timer;

    Future<void> poll() async {
      try {
        final results = await Future.wait([
          (db.select(db.pendingSales)..where(
                (row) => row.syncStatus.isIn(const ['pending', 'failed']),
              ))
              .get(),
          (db.select(db.expenseEntries)..where(
                (row) => row.syncStatus.isIn(const ['pending', 'failed']),
              ))
              .get(),
          (db.select(db.otherIncomeEntries)..where(
                (row) => row.syncStatus.isIn(const ['pending', 'failed']),
              ))
              .get(),
          (db.select(db.customerEntries)..where(
                (row) => row.syncStatus.isIn(const ['pending', 'failed']),
              ))
              .get(),
        ]);
        final counts = [for (final rows in results) rows.length];

        final error =
            sales.lastSyncError ??
            finance.lastSyncError ??
            customers.lastSyncError;
        final status = OutboxStatus(
          pendingSales: counts[0],
          pendingExpenses: counts[1],
          pendingIncomes: counts[2],
          pendingCustomers: counts[3],
          isSyncing:
              sales.isSyncing || finance.isSyncing || customers.isSyncing,
          lastError: error,
          lastSynced: await readLastSynced(db),
        );
        if (!cancelled) controller.add(status);
      } catch (error, stackTrace) {
        if (!cancelled) controller.addError(error, stackTrace);
      }
      if (!cancelled) timer = Timer(AppDurations.syncPollDelay, poll);
    }

    controller.onCancel = () {
      cancelled = true;
      timer?.cancel();
    };
    unawaited(poll());
  });
});

/// Sends everything waiting, in dependency order: customers first (sales
/// reference them), then sales, then finance entries.
Future<void> syncNowAll(WidgetRef ref) async {
  if (ref.read(currentBusinessIdProvider) == null) return;
  try {
    await ref.read(customerSyncServiceProvider).syncNow();
  } catch (_) {
    // Each drain records its own error; one area failing must not stop
    // the others from trying.
  }
  try {
    await ref.read(syncServiceProvider).syncNow();
  } catch (_) {}
  try {
    await ref.read(financeSyncServiceProvider).syncNow();
  } catch (_) {}
}
