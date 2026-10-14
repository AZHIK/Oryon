/// Permission enforcement utilities and helpers.
///
/// This layer sits between the RBAC knowledge system (which knows what
/// permissions exist) and the UI (which needs to decide what to show/hide/disable).
///
/// All permission checks go through here for consistency:
/// - `hasPermission(code)`: true if user has permission
/// - `requirePermission(code)`: throws if user lacks permission
/// - `canAccessFeature(featureName)`: true if user can use a feature
///
/// Offline handling: when permission cache is Unknown (missing offline),
/// features are disabled with an explicit "offline" message, not silently
/// granted or blocked with a generic error.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/permission.dart';
import '../providers/permissions_provider.dart';

/// Exception thrown when a user attempts an action they lack permission for.
class PermissionDeniedException implements Exception {
  const PermissionDeniedException(
    this.permissionCode,
    this.message,
  );

  final String permissionCode;
  final String message;

  @override
  String toString() => 'PermissionDeniedException: $message (required: $permissionCode)';
}

/// Exception thrown when permission state is unknown (offline, no cache).
class PermissionUnknownException implements Exception {
  const PermissionUnknownException(this.message);

  final String message;

  @override
  String toString() => 'PermissionUnknownException: $message';
}

/// Result of a permission check: allowed, denied, or unknown (offline).
sealed class PermissionCheckResult {
  const PermissionCheckResult();

  factory PermissionCheckResult.allowed() = _Allowed;
  factory PermissionCheckResult.denied(String permissionCode, String reason) = _Denied;
  factory PermissionCheckResult.unknown(String reason) = _Unknown;

  T when<T>({
    required T Function() onAllowed,
    required T Function(String permissionCode, String reason) onDenied,
    required T Function(String reason) onUnknown,
  }) {
    return switch (this) {
      _Allowed() => onAllowed(),
      _Denied(permissionCode: final code, reason: final reason) => onDenied(code, reason),
      _Unknown(reason: final reason) => onUnknown(reason),
    };
  }

  bool get isAllowed => this is _Allowed;
  bool get isDenied => this is _Denied;
  bool get isUnknown => this is _Unknown;
}

final class _Allowed extends PermissionCheckResult {
  const _Allowed();
}

final class _Denied extends PermissionCheckResult {
  const _Denied(this.permissionCode, this.reason);

  final String permissionCode;
  final String reason;
}

final class _Unknown extends PermissionCheckResult {
  const _Unknown(this.reason);

  final String reason;
}

/// Permission enforcement service.
///
/// Provides methods to check permissions and guard access to features.
/// All checks go through the RBAC knowledge layer (currentUserPermissionsProvider)
/// which handles online/offline/stale cache cases.
class PermissionEnforcement {
  final Ref ref;

  const PermissionEnforcement(this.ref);

  /// Check if user has permission code.
  ///
  /// Returns:
  /// - Allowed() if user has the permission
  /// - Denied(...) if user lacks the permission
  /// - Unknown(...) if offline with no cache
  Future<PermissionCheckResult> checkPermission(String permissionCode) async {
    final permsResult = await ref.watch(currentUserPermissionsProvider.future);

    return permsResult.when(
      onKnown: (permissions, isStale) {
        if (permissions.contains('*') || permissions.contains(permissionCode)) {
          return PermissionCheckResult.allowed();
        }
        return PermissionCheckResult.denied(
          permissionCode,
          'User lacks permission: $permissionCode${isStale ? ' (offline, cache may be stale)' : ''}',
        );
      },
      onUnknown: () => PermissionCheckResult.unknown(
        'Permission cache not available (offline, no prior cache)',
      ),
    );
  }

  /// Require a permission, throwing if denied or unknown.
  Future<void> requirePermission(String permissionCode) async {
    final result = await checkPermission(permissionCode);

    result.when(
      onAllowed: () {},
      onDenied: (code, reason) => throw PermissionDeniedException(code, reason),
      onUnknown: (reason) => throw PermissionUnknownException(reason),
    );
  }

  /// Check multiple permissions (all must pass).
  Future<PermissionCheckResult> checkPermissions(List<String> permissionCodes) async {
    for (final code in permissionCodes) {
      final result = await checkPermission(code);
      if (!result.isAllowed) return result;
    }
    return PermissionCheckResult.allowed();
  }

  /// Check if user can access a high-level feature (may require multiple permissions).
  Future<PermissionCheckResult> checkFeature(String featureName) async {
    final requiredPerms = _featureRequirements[featureName] ?? [];
    return checkPermissions(requiredPerms);
  }

  /// Get a user-facing message for a permission result.
  String messageFor(PermissionCheckResult result) {
    return result.when(
      onAllowed: () => 'Permission granted',
      onDenied: (code, reason) {
        final label = AppPermissions.labelFor(code);
        return 'You do not have permission to: $label';
      },
      onUnknown: (reason) =>
          'Permission check unavailable (offline). Some features may be disabled.',
    );
  }
}

/// High-level feature requirements (mapped to permission codes).
///
/// A feature may require one or more permissions. Used for checking
/// whether a user can access an entire feature area.
const Map<String, List<String>> _featureRequirements = {
  'pos': [AppPermissions.posAccess],
  'pos_discount': [AppPermissions.posDiscount],
  'pos_refund': [AppPermissions.posRefund],
  'inventory_view': [AppPermissions.inventoryView],
  'inventory_items_create': [AppPermissions.inventoryItemsCreate],
  'inventory_items_update': [AppPermissions.inventoryItemsUpdate],
  'inventory_items_deactivate': [AppPermissions.inventoryItemsDeactivate],
  'inventory_adjust': [AppPermissions.inventoryAdjust],
  'inventory_waste_record': [AppPermissions.inventoryWasteRecord],
  'inventory_transfer': [AppPermissions.inventoryTransfer],
  'sales_view': [AppPermissions.posView],
  'sales_export': [AppPermissions.salesExport],
  'reports_view': [AppPermissions.reportsView],
  'staff_view': [AppPermissions.staffView],
  'staff_assign': [AppPermissions.staffAssign],
  'staff_revoke': [AppPermissions.staffRevoke],
  'roles_view': [AppPermissions.rolesView],
  'roles_create': [AppPermissions.rolesCreate],
  'roles_update': [AppPermissions.rolesUpdate],
  'roles_delete': [AppPermissions.rolesDelete],
  'settings_store': [AppPermissions.settingsStore],
  'settings_tax': [AppPermissions.settingsTax],
  'settings_devices': [AppPermissions.settingsDevices],
  'settings_billing': [AppPermissions.settingsBilling],
  'finance_view': [AppPermissions.financeView],
  'customers_view': [AppPermissions.customersView],
  'customers_create': [AppPermissions.customersCreate],
  'customers_update': [AppPermissions.customersUpdate],
  'customers_delete': [AppPermissions.customersDelete],
  'finance_expenses_create': [AppPermissions.financeExpensesCreate],
  'finance_expenses_update': [AppPermissions.financeExpensesUpdate],
  'finance_expenses_delete': [AppPermissions.financeExpensesDelete],
  'finance_incomes_create': [AppPermissions.financeIncomesCreate],
  'finance_incomes_update': [AppPermissions.financeIncomesUpdate],
  'finance_incomes_delete': [AppPermissions.financeIncomesDelete],
  'finance_attachments_upload': [AppPermissions.financeAttachmentsUpload],
  'procurement_view': [AppPermissions.procurementView],
  'procurement_create': [AppPermissions.procurementCreate],
  'procurement_approve': [AppPermissions.procurementApprove],
  'procurement_receive': [AppPermissions.procurementReceive],
  'suppliers_view': [AppPermissions.suppliersView],
  'suppliers_create': [AppPermissions.suppliersCreate],
  'suppliers_update': [AppPermissions.suppliersUpdate],
  'suppliers_delete': [AppPermissions.suppliersDelete],
};

/// Provider for permission enforcement service.
final permissionEnforcementProvider = Provider<PermissionEnforcement>((ref) {
  return PermissionEnforcement(ref);
});

/// Async provider: check if user can perform action (returns bool, not result).
/// Use this in widgets to decide whether to show/enable features.
final canPerformActionProvider = FutureProvider.family<bool, String>((ref, permissionCode) async {
  final enforcement = ref.watch(permissionEnforcementProvider);
  final result = await enforcement.checkPermission(permissionCode);
  return result.isAllowed;
});

/// Async provider: get feature access status (allowed/denied/unknown).
final featureAccessProvider = FutureProvider.family<PermissionCheckResult, String>(
  (ref, featureName) async {
    final enforcement = ref.watch(permissionEnforcementProvider);
    return enforcement.checkFeature(featureName);
  },
);
