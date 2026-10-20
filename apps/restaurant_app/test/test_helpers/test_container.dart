/// A bare `ProviderContainer` pre-wired with an in-memory database.
///
/// Every widget test that mounts `RestaurantPosApp` lands on the dashboard
/// first (even ones that immediately navigate elsewhere), and the dashboard
/// reads inventory data. `InventoryNotifier` watches `authProvider` (via
/// `currentStoreIdProvider`) to know whether a business/store context
/// exists, and `AuthNotifier.build()` unconditionally needs a working
/// database — so a bare `ProviderContainer()` with no override throws before
/// any of that context-detection logic ever runs, even for tests that don't
/// care about auth at all.
///
/// This does not seed any session/business/store state — callers that need
/// a real business context (roles, staff, permissions) still set that up
/// themselves (see `fake_identity_backend.dart`); this only stops the
/// database's "must be overridden" guard from firing.
library;

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:restaurant_pos/database/app_database.dart';
import 'package:restaurant_pos/providers/database_providers.dart';

/// Creates a `ProviderContainer` with an in-memory `appDatabaseProvider`
/// override, disposing both the container and the database via [addTearDown].
/// [extraOverrides] are appended after the database override, so a caller can
/// still override the same provider again if a test needs to. Pass [database]
/// to reuse an existing instance (e.g. simulating an app restart) instead of
/// opening a second connection to the same executor.
ProviderContainer newTestContainer({
  List<Override> extraOverrides = const [],
  AppDatabase? database,
}) {
  final db = database ?? AppDatabase(NativeDatabase.memory());
  if (database == null) addTearDown(db.close);

  final container = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      ...extraOverrides,
    ],
  );
  addTearDown(container.dispose);
  return container;
}
