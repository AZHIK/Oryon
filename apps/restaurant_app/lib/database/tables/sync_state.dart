/// Last successful server exchange per area, in plain words.
///
/// One row per key (`sales`, `finance`, `customers`, `pull`): when the
/// matching sync last finished without error. The app's "last synced"
/// is the freshest of these — and the stale warning ("not synced for
/// more than a day") reads it, so it must survive restarts (unlike the
/// services' in-memory `lastSyncTime`).
library;

import 'package:drift/drift.dart';

/// Last-good-sync stamps, one row per area key.
class SyncState extends Table {
  /// Area key: `sales` | `finance` | `customers` | `pull`.
  TextColumn get key => text()();

  /// When that area last finished a sync without error.
  DateTimeColumn get syncedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {key};
}
