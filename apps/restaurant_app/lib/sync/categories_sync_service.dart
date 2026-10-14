/// Syncs the product-category taxonomy from Inventory Service and caches it
/// locally.
///
/// Kept as its own tiny class rather than folded into `PurchasingSyncService`
/// or `CatalogSyncService` — same reasoning as `PurchasingSyncService`'s own
/// doc comment: those classes are each keyed to unrelated API dependencies,
/// and categories are a global (not business/store-scoped) pull with no
/// overlap with either.
library;

import 'package:drift/drift.dart';
import '../database/app_database.dart';
import 'categories_catalog_api.dart';

class CategoriesSyncService {
  final AppDatabase _db;
  final CategoriesCatalogApi _api;

  DateTime? lastSyncTime;
  String? lastSyncError;

  CategoriesSyncService({
    required this._db,
    required CategoriesCatalogApi api,
  })  : _api = api;

  /// Pulls the full category taxonomy and upserts into cache. No
  /// missing-row handling — categories are never hard-deleted server-side
  /// (see `app/models/categories.py`'s module docstring), only retired via
  /// `isActive`, which is itself a pulled field.
  Future<void> syncCategories() async {
    final runStartedAt = DateTime.now();
    lastSyncError = null;

    try {
      final categories = await _api.fetchCategories();

      for (final category in categories) {
        await _db.into(_db.cachedCategories).insertOnConflictUpdate(
          CachedCategoriesCompanion(
            id: Value(category.id),
            code: Value(category.code),
            name: Value(category.name),
            sortOrder: Value(category.sortOrder),
            isActive: Value(category.isActive),
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
