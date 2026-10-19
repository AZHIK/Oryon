/// Syncs the unit-of-measure taxonomy from Inventory Service and caches it
/// locally.
///
/// Kept as its own tiny class, mirroring `CategoriesSyncService` — same
/// reasoning: a global pull with no overlap with any business/store-scoped
/// sync service.
library;

import 'package:drift/drift.dart';
import '../database/app_database.dart';
import 'units_catalog_api.dart';

class UnitsSyncService {
  final AppDatabase _db;
  final UnitsCatalogApi _api;

  DateTime? lastSyncTime;
  String? lastSyncError;

  UnitsSyncService({
    required this._db,
    required this._api,
  });

  /// Pulls the full unit taxonomy and upserts into cache. No missing-row
  /// handling — units are never hard-deleted server-side (see
  /// `app/models/units.py`'s module docstring), only retired via
  /// `isActive`, which is itself a pulled field.
  Future<void> syncUnits() async {
    final runStartedAt = DateTime.now();
    lastSyncError = null;

    try {
      final units = await _api.fetchUnits();

      for (final unit in units) {
        await _db.into(_db.cachedUnits).insertOnConflictUpdate(
          CachedUnitsCompanion(
            id: Value(unit.id),
            code: Value(unit.code),
            name: Value(unit.name),
            abbreviation: Value(unit.abbreviation),
            sortOrder: Value(unit.sortOrder),
            isActive: Value(unit.isActive),
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
