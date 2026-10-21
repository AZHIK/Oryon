import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import 'dart:convert';

import '../auth/staff_rbac_api.dart';
import '../auth/staff_rbac_dtos.dart';
import '../constants/app_limits.dart';
import '../database/app_database.dart';
import '../models/business_role.dart';
import '../models/table_query.dart';
import 'auth_provider.dart';
import 'database_providers.dart';
import 'permissions_provider.dart';
import 'staff_provider.dart';
import 'table_query_provider.dart';

abstract final class RoleSort {
  static const name = 'roleName';
  static const staffCount = 'roleStaffCount';
  static const permissions = 'rolePermissions';
}

/// The one real client for every business-RBAC call (roles, role
/// permissions, staff assignment) — built on the shared, interceptor-backed
/// `identityServiceDioProvider`, not a second HTTP setup.
final staffRbacApiProvider = Provider<StaffRbacApi>(
  (ref) => StaffRbacApi(dio: ref.watch(identityServiceDioProvider)),
);

/// The single source of truth for roles, backed by the real
/// identity-service business-RBAC endpoints.
///
/// `GET /businesses/{id}/roles` doesn't return each role's permissions
/// (that's a separate endpoint, one call per role) — `build()` fetches both
/// and joins them, so every other provider here still reads a plain
/// `List<BusinessRole>` with `permissionIds` already populated, same as
/// the pre-integration shape.
///
/// The UI always reads roles from the local cache — `build()` never blocks
/// on the network. A live fetch runs in the background on every read to
/// keep that cache current; if it fails (no permission, offline, a 401
/// whose retry-with-refresh-token also fails) the screen just keeps
/// showing whatever was last cached instead of going blank or erroring.
class RolesNotifier extends AsyncNotifier<List<BusinessRole>> {
  StaffRbacApi get _api => ref.read(staffRbacApiProvider);

  String get _businessId {
    final id = ref.read(currentBusinessIdProvider);
    if (id == null) throw StateError('No active business context');
    return id;
  }

  @override
  Future<List<BusinessRole>> build() async {
    final businessId = ref.watch(currentBusinessIdProvider);
    if (businessId == null) return const [];

    // Fire-and-forget: updates `state` itself once it lands (or leaves the
    // cached read below untouched if it fails). Sending this request goes
    // through the shared dio client, whose `TokenRefreshInterceptor`
    // transparently exchanges the refresh token if the access token has
    // gone stale — this doesn't need to do that itself.
    var disposed = false;
    ref.onDispose(() => disposed = true);
    unawaited(_refreshFromApi(businessId, isDisposed: () => disposed));

    return _loadFromCache(businessId);
  }

  Future<void> _refreshFromApi(String businessId, {required bool Function() isDisposed}) async {
    try {
      final roles = await _api.listRoles(businessId: businessId);
      final loadedRoles =
          await Future.wait(roles.map((dto) => _withPermissions(businessId, dto)));

      await _cacheRoles(businessId, loadedRoles);

      if (!isDisposed()) {
        state = AsyncData(loadedRoles);
      }
    } catch (_) {
      // No permission, offline, or a transient failure — the cached read
      // from `build()` is what the UI already shows; nothing more to do.
    }
  }

  Future<void> _cacheRoles(String businessId, List<BusinessRole> roles) async {
    try {
      final repo = ref.read(localProfileRepositoryProvider);
      final companions = roles.map((role) {
        return CachedBusinessRolesCompanion(
          businessId: Value(businessId),
          roleId: Value(role.id),
          name: Value(role.name),
          description: Value(role.description),
          isProtected: Value(role.isProtected),
          permissionCodes: Value(jsonEncode(role.permissionIds.toList())),
          cachedAt: Value(DateTime.now()),
        );
      }).toList();
      await repo.setCachedRoles(businessId, companions);
    } catch (e) {
      // Cache save failed, but we still have the API response so return it.
      // The cache will be repopulated on the next successful API call.
    }
  }

  Future<List<BusinessRole>> _loadFromCache(String businessId) async {
    try {
      final repo = ref.read(localProfileRepositoryProvider);
      final cached = await repo.getCachedRoles(businessId);
      return cached.map((row) {
        final permissionIds = (jsonDecode(row.permissionCodes) as List<dynamic>)
            .map((e) => e.toString())
            .toSet();
        return BusinessRole(
          id: row.roleId,
          name: row.name,
          description: row.description,
          permissionIds: permissionIds,
          isProtected: row.isProtected,
        );
      }).toList();
    } catch (e) {
      return const [];
    }
  }

  Future<BusinessRole> _withPermissions(String businessId, BusinessRoleDto dto) async {
    final perms = await _api.listRolePermissions(businessId: businessId, roleId: dto.id);
    return BusinessRole(
      id: dto.id,
      name: dto.name,
      description: dto.description ?? '',
      permissionIds: perms.map((p) => p.permissionCode).toSet(),
      isProtected: dto.isProtected,
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }

  /// Creates a role and grants it [permissionCodes] in one batch (as few
  /// calls as the backend allows — one per code, since there's no bulk
  /// endpoint), then reloads once. Returns the created role.
  Future<BusinessRole> create({
    required String name,
    String? description,
    Set<String> permissionCodes = const {},
  }) async {
    final businessId = _businessId;
    final created = await _api.createRole(
      businessId: businessId,
      input: CreateRoleInput(name: name, description: description),
    );
    for (final code in permissionCodes) {
      await _api.assignRolePermission(
        businessId: businessId,
        roleId: created.id,
        permissionCode: code,
      );
    }
    await refresh();
    return byId(created.id) ??
        BusinessRole(
          id: created.id,
          name: created.name,
          description: created.description ?? '',
          permissionIds: permissionCodes,
        );
  }

  Future<void> updateRole(
    String roleId, {
    required String name,
    String? description,
  }) async {
    await _api.updateRole(
      businessId: _businessId,
      roleId: roleId,
      input: UpdateRoleInput(name: name, description: description),
    );
    await refresh();
  }

  /// Deletes a role. The backend itself refuses a protected role (403) or
  /// one with active staff assignments (409) — this doesn't duplicate that
  /// check client-side beyond what the UI needs to disable the action.
  Future<void> delete(String id) async {
    await _api.deleteRole(businessId: _businessId, roleId: id);
    await refresh();
  }

  /// Copies a role's permissions under a new name — the backend has no
  /// duplicate endpoint, so this is a real create-then-copy-each-permission
  /// sequence (not instant/atomic), never optimistically faked.
  Future<BusinessRole> duplicate(String id) async {
    final source = byId(id);
    if (source == null) throw StateError('Role $id not found');

    final businessId = _businessId;
    final name = _uniqueName('${source.displayName} copy');
    final created = await _api.createRole(
      businessId: businessId,
      input: CreateRoleInput(name: name, description: source.description),
    );
    for (final code in source.permissionIds) {
      await _api.assignRolePermission(
        businessId: businessId,
        roleId: created.id,
        permissionCode: code,
      );
    }
    await refresh();
    return byId(created.id) ??
        BusinessRole(id: created.id, name: created.name, description: created.description ?? '');
  }

  /// Appends "2", "3", … until the name is free. Two roles called "Manager
  /// copy" would be indistinguishable in every picker in the app.
  String _uniqueName(String preferred) {
    final taken = {
      for (final role in state.valueOrNull ?? const <BusinessRole>[])
        role.displayName.toLowerCase(),
    };
    if (!taken.contains(preferred.toLowerCase())) return preferred;

    for (var n = 2; n < 100; n++) {
      final candidate = '$preferred $n';
      if (!taken.contains(candidate.toLowerCase())) return candidate;
    }
    return preferred;
  }

  /// Applies a full permission-set diff for one role in as few calls as
  /// possible (one per changed code — the backend has no bulk-set
  /// endpoint), then reloads once, not once per toggle.
  Future<void> syncPermissions(String roleId, Set<String> desired) async {
    final current = byId(roleId)?.permissionIds ?? const <String>{};
    final businessId = _businessId;
    for (final code in desired.difference(current)) {
      await _api.assignRolePermission(
        businessId: businessId,
        roleId: roleId,
        permissionCode: code,
      );
    }
    for (final code in current.difference(desired)) {
      await _api.removeRolePermission(
        businessId: businessId,
        roleId: roleId,
        permissionCode: code,
      );
    }
    await refresh();
  }

  /// Grants or revokes a single permission on a role, then reloads so
  /// `permissionIds` reflects the real, current set — not an optimistic
  /// local toggle that could drift from what the backend actually stored.
  Future<void> setPermission(String roleId, String permissionCode, bool granted) async {
    if (granted) {
      await _api.assignRolePermission(
        businessId: _businessId,
        roleId: roleId,
        permissionCode: permissionCode,
      );
    } else {
      await _api.removeRolePermission(
        businessId: _businessId,
        roleId: roleId,
        permissionCode: permissionCode,
      );
    }
    await refresh();
  }

  BusinessRole? byId(String id) {
    for (final role in state.valueOrNull ?? const <BusinessRole>[]) {
      if (role.id == id) return role;
    }
    return null;
  }
}

final rolesProvider = AsyncNotifierProvider<RolesNotifier, List<BusinessRole>>(
  RolesNotifier.new,
);

/// A single role by id. Null once a role has been deleted (or while still
/// loading), which is what lets a detail screen show a "not found"/loading
/// state instead of throwing.
final roleByIdProvider = Provider.family<BusinessRole?, String>((ref, id) {
  for (final role in ref.watch(rolesProvider).valueOrNull ?? const <BusinessRole>[]) {
    if (role.id == id) return role;
  }
  return null;
});

/// How many staff wear each role, keyed by role id.
///
/// A staff member holding more than one role counts once toward each of
/// them — reflects the real multi-role model directly.
final roleStaffCountsProvider = Provider<Map<String, int>>((ref) {
  final counts = <String, int>{};
  for (final member in ref.watch(staffMembersProvider).valueOrNull ?? const []) {
    for (final role in member.roles) {
      counts[role.roleId] = (counts[role.roleId] ?? 0) + 1;
    }
  }
  return counts;
});

// ---------------------------------------------------------------------------
// Table state
// ---------------------------------------------------------------------------

/// The roles list is inherently short, so it shows every role on one page
/// rather than paginating five rows across two pages.
final rolesQueryProvider = NotifierProvider<TableQueryNotifier, TableQuery>(
  () => TableQueryNotifier(
    const TableQuery(sortField: RoleSort.name, pageSize: AppLimits.rolesPageSize),
  ),
);

final sortedRolesProvider = Provider<List<BusinessRole>>((ref) {
  final roles = [...ref.watch(rolesProvider).valueOrNull ?? const <BusinessRole>[]];
  final query = ref.watch(rolesQueryProvider);
  final counts = ref.watch(roleStaffCountsProvider);
  final direction = query.ascending ? 1 : -1;

  roles.sort((a, b) {
    final cmp = switch (query.sortField) {
      RoleSort.staffCount => (counts[a.id] ?? 0).compareTo(counts[b.id] ?? 0),
      RoleSort.permissions => a.permissionCount.compareTo(b.permissionCount),
      _ => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    };
    return cmp != 0 ? cmp * direction : a.id.compareTo(b.id);
  });

  return roles;
});

final rolesSliceProvider = Provider<PageSlice<BusinessRole>>(
  (ref) => PageSlice.of(
    ref.watch(sortedRolesProvider),
    ref.watch(rolesQueryProvider),
  ),
);

@immutable
class RolesSummary {
  const RolesSummary({
    required this.totalRoles,
    required this.customRoles,
    required this.staffAssigned,
  });

  final int totalRoles;
  final int customRoles;
  final int staffAssigned;
}

final rolesSummaryProvider = Provider<RolesSummary>((ref) {
  final roles = ref.watch(rolesProvider).valueOrNull ?? const <BusinessRole>[];
  final counts = ref.watch(roleStaffCountsProvider);

  var custom = 0;
  var assigned = 0;
  for (final role in roles) {
    if (!role.isProtected) custom++;
    assigned += counts[role.id] ?? 0;
  }

  return RolesSummary(
    totalRoles: roles.length,
    customRoles: custom,
    staffAssigned: assigned,
  );
});
