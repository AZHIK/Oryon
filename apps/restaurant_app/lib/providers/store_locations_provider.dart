import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/store_location.dart';
import '../constants/app_limits.dart';
import '../models/table_query.dart';
import 'staff_provider.dart';
import 'store_api_provider_real.dart';
import 'table_query_provider.dart';

abstract final class LocationSort {
  static const name = 'locationName';
  static const manager = 'locationManager';
  static const staff = 'locationStaff';
  static const status = 'locationStatus';
}

/// The single source of truth for where this business trades.
///
/// Loaded from the backend on startup. Store Management edits this list and
/// the stock transfer dialog reads it, so a site added on the management screen
/// is a transfer destination immediately.
class StoreLocationsNotifier extends Notifier<List<StoreLocation>> {
  @override
  List<StoreLocation> build() {
    // Load stores from backend provider
    final stores = ref.watch(storesProvider);
    return stores.maybeWhen(
      data: (data) => data
          .map((store) => StoreLocation.fromDto(store))
          .toList(),
      loading: () => [],
      error: (_, _) => [],
      orElse: () => [],
    );
  }

  void upsert(StoreLocation location) {
    final index = state.indexWhere((l) => l.id == location.id);
    if (index == -1) {
      state = [...state, location];
      return;
    }
    final next = [...state];
    next[index] = location;
    state = next;
  }

  /// Removes a site, refusing to remove the last active one or the site this
  /// terminal is standing in.
  ///
  /// The refusal lives here rather than only in the row's menu: stock
  /// movements, sales and staff records all reference a location id, and a
  /// business with nowhere to trade is not a state the app should be able to
  /// reach because a button forgot to ask.
  bool delete(String id) {
    if (!canDelete(id)) return false;
    state = state.where((l) => l.id != id).toList();
    return true;
  }

  /// Flips active ↔ inactive, refusing to deactivate the last active site for
  /// the same reason [delete] refuses to remove it.
  bool toggleActive(String id) {
    final location = byId(id);
    if (location == null) return false;
    if (location.isActive && !canDeactivate(id)) return false;

    upsert(location.toggleStatus());
    return true;
  }

  bool canDelete(String id) {
    final location = byId(id);
    if (location == null) return false;
    if (location.isCurrent) return false;
    return !location.isActive || _activeCount > 1;
  }

  bool canDeactivate(String id) {
    final location = byId(id);
    if (location == null || !location.isActive) return false;
    return _activeCount > 1;
  }

  StoreLocation? byId(String id) {
    for (final location in state) {
      if (location.id == id) return location;
    }
    return null;
  }

  String nextId() {
    var highest = 0;
    for (final location in state) {
      final n = int.tryParse(location.id.split('-').last);
      if (n != null && n > highest) highest = n;
    }
    return 'st-${(highest + 1).toString().padLeft(2, '0')}';
  }

  int get _activeCount => state.where((l) => l.isActive).length;
}

final storeLocationsProvider =
    NotifierProvider<StoreLocationsNotifier, List<StoreLocation>>(
      StoreLocationsNotifier.new,
    );

/// The site this terminal is installed at.
///
/// Falls back to the first location so a directory whose "current" flag has
/// been edited away still resolves to somewhere rather than throwing.
final currentStoreProvider = Provider<StoreLocation?>((ref) {
  final locations = ref.watch(storeLocationsProvider);
  if (locations.isEmpty) return null;
  for (final location in locations) {
    if (location.isCurrent) return location;
  }
  return locations.first;
});

/// Everywhere stock can be sent from here: every other site that is still
/// trading. An inactive location keeps its history but takes no deliveries.
final transferTargetsProvider = Provider<List<StoreLocation>>((ref) {
  final current = ref.watch(currentStoreProvider);
  return [
    for (final location in ref.watch(storeLocationsProvider))
      if (location.isActive && location.id != current?.id) location,
  ];
});

/// Manager names by location id, resolved against the staff list so renaming
/// someone on the Staff screen renames them here too.
final locationManagerNamesProvider = Provider<Map<String, String>>((ref) {
  final staff = ref.watch(staffMembersProvider).valueOrNull ?? const [];
  final names = {for (final member in staff) member.id: member.name};

  return {
    for (final location in ref.watch(storeLocationsProvider))
      location.id:
          names[location.managerId] ?? StoreLocation.unassignedManager,
  };
});

// ---------------------------------------------------------------------------
// Table state
// ---------------------------------------------------------------------------

/// A business has a handful of sites, so the table shows them all on one page
/// rather than paginating four rows across two.
final locationsQueryProvider = NotifierProvider<TableQueryNotifier, TableQuery>(
  () => TableQueryNotifier(
    const TableQuery(sortField: LocationSort.name, pageSize: AppLimits.locationsPageSize),
  ),
);

final sortedLocationsProvider = Provider<List<StoreLocation>>((ref) {
  final locations = [...ref.watch(storeLocationsProvider)];
  final query = ref.watch(locationsQueryProvider);
  final managers = ref.watch(locationManagerNamesProvider);
  final direction = query.ascending ? 1 : -1;

  locations.sort((a, b) {
    final cmp = switch (query.sortField) {
      LocationSort.manager => (managers[a.id] ?? '').toLowerCase().compareTo(
        (managers[b.id] ?? '').toLowerCase(),
      ),
      LocationSort.staff => a.staffCount.compareTo(b.staffCount),
      // Active before inactive, so ascending reads as "trading now first".
      LocationSort.status => (a.isActive ? 0 : 1).compareTo(b.isActive ? 0 : 1),
      _ => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    };
    return cmp != 0 ? cmp * direction : a.id.compareTo(b.id);
  });

  return locations;
});

final locationsSliceProvider = Provider<PageSlice<StoreLocation>>(
  (ref) => PageSlice.of(
    ref.watch(sortedLocationsProvider),
    ref.watch(locationsQueryProvider),
  ),
);

@immutable
class LocationsSummary {
  const LocationsSummary({
    required this.total,
    required this.active,
    required this.staff,
  });

  final int total;
  final int active;

  /// Headcount across every site, active or not — people do not stop existing
  /// when a location is mothballed.
  final int staff;
}

final locationsSummaryProvider = Provider<LocationsSummary>((ref) {
  var active = 0;
  var staff = 0;

  final locations = ref.watch(storeLocationsProvider);
  for (final location in locations) {
    if (location.isActive) active++;
    staff += location.staffCount;
  }

  return LocationsSummary(
    total: locations.length,
    active: active,
    staff: staff,
  );
});
