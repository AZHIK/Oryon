/// Stamps "this area synced fine just now" into the local database.
///
/// Called next to every service's in-memory `lastSyncTime = now`, so the
/// whole-app "last synced" survives restarts. Never throws — a stamp that
/// fails must never fail the sync it records.
library;

import 'package:drift/drift.dart';

import '../database/app_database.dart';

/// Area keys. Keep in sync with the sheet's per-area rows.
abstract final class SyncArea {
  static const sales = 'sales';
  static const finance = 'finance';
  static const customers = 'customers';

  /// A ledger pull (branch refresh), not an outbox drain.
  static const pull = 'pull';
}

Future<void> recordSyncTick(AppDatabase db, String area) async {
  try {
    await db.into(db.syncState).insertOnConflictUpdate(
          SyncStateCompanion(
            key: Value(area),
            syncedAt: Value(DateTime.now()),
          ),
        );
  } catch (_) {
    // Stamp is informational only.
  }
}

/// The freshest stamp across all areas, or null when nothing ever synced.
Future<DateTime?> readLastSynced(AppDatabase db) async {
  try {
    final rows = await db.select(db.syncState).get();
    if (rows.isEmpty) return null;
    var latest = rows.first.syncedAt;
    for (final row in rows) {
      if (row.syncedAt.isAfter(latest)) latest = row.syncedAt;
    }
    return latest;
  } catch (_) {
    return null;
  }
}
