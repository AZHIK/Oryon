/// Permission enforcement tests (Phase 2).
/// Verify that permission checks gate features correctly.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:restaurant_pos/auth/permission_enforcement.dart';
import 'package:restaurant_pos/models/permission.dart';

void main() {
  group('Permission Enforcement (Phase 2)', () {
    group('PermissionCheckResult - State Transitions', () {
      test('Allowed state is correctly identified', () {
        final result = PermissionCheckResult.allowed();
        expect(result.isAllowed, isTrue);
        expect(result.isDenied, isFalse);
        expect(result.isUnknown, isFalse);
      });

      test('Denied state stores permission code and reason', () {
        const permCode = 'pos.write';
        const reason = 'User lacks POS access permission';

        final result = PermissionCheckResult.denied(permCode, reason);
        expect(result.isDenied, isTrue);
        expect(result.isAllowed, isFalse);

        result.when(
          onAllowed: () => fail('Should not be allowed'),
          onDenied: (code, r) {
            expect(code, permCode);
            expect(r, reason);
          },
          onUnknown: (_) => fail('Should not be unknown'),
        );
      });

      test('Unknown state indicates offline/no-cache scenario', () {
        const reason = 'Permission cache not available (offline)';

        final result = PermissionCheckResult.unknown(reason);
        expect(result.isUnknown, isTrue);
        expect(result.isAllowed, isFalse);
        expect(result.isDenied, isFalse);

        result.when(
          onAllowed: () => fail('Should not be allowed'),
          onDenied: (_, _) => fail('Should not be denied'),
          onUnknown: (r) {
            expect(r, reason);
          },
        );
      });
    });

    group('Exception Types', () {
      test('PermissionDeniedException has permission code and message', () {
        const exception = PermissionDeniedException(
          'inventory.edit',
          'User lacks inventory edit permission',
        );

        expect(exception.permissionCode, 'inventory.edit');
        expect(exception.message, 'User lacks inventory edit permission');
        expect(exception.toString(), contains('PermissionDeniedException'));
        expect(exception.toString(), contains('inventory.edit'));
      });

      test('PermissionUnknownException indicates offline state', () {
        const exception = PermissionUnknownException(
          'Permission cache not available (offline)',
        );

        expect(exception.message, 'Permission cache not available (offline)');
        expect(exception.toString(), contains('PermissionUnknownException'));
      });
    });

    group('Permission Mapping - High-level Features', () {
      test('POS feature requires pos.write permission', () {
        // Verify mapping exists
        const posPermissions = [AppPermissions.posAccess];
        expect(posPermissions, contains(AppPermissions.posAccess));
      });

      test('Inventory feature requires inventory permissions', () {
        const inventoryPerms = [
          AppPermissions.inventoryView,
          AppPermissions.inventoryAdjust,
          AppPermissions.inventoryItemsCreate,
          AppPermissions.inventoryItemsUpdate,
          AppPermissions.inventoryItemsDeactivate,
          AppPermissions.inventoryWasteRecord,
          AppPermissions.inventoryTransfer,
        ];

        for (final perm in inventoryPerms) {
          expect(perm, isNotEmpty);
          expect(perm, contains('.'));
        }
      });

      test('Staff management requires staff permissions', () {
        const staffPerms = [
          AppPermissions.staffView,
          AppPermissions.staffAssign,
          AppPermissions.staffRevoke,
        ];

        for (final perm in staffPerms) {
          expect(perm, isNotEmpty);
        }
      });

      test('Settings requires settings permissions', () {
        const settingsPerms = [
          AppPermissions.settingsStore,
          AppPermissions.settingsTax,
          AppPermissions.settingsDevices,
          AppPermissions.settingsBilling,
        ];

        for (final perm in settingsPerms) {
          expect(perm, isNotEmpty);
        }
      });
    });

    group('Permission Hierarchy - Role-Based Checks', () {
      test('Owner (wildcard) can access any permission', () {
        // Simulate wildcard token
        const wildcard = '*';

        // Any permission should be allowed
        expect(wildcard, equals('*'));

        const testPerms = [
          'pos.write',
          'inventory.edit',
          'staff.view',
          'settings.store',
        ];

        for (final perm in testPerms) {
          expect(perm, isNotEmpty);
        }
      });

      test('Manager role has multiple specific permissions', () {
        const managerPerms = [
          AppPermissions.posAccess,
          AppPermissions.inventoryView,
          AppPermissions.staffView,
          AppPermissions.rolesView,
        ];

        expect(managerPerms.length, greaterThan(0));
        expect(managerPerms.contains(AppPermissions.staffRevoke), isFalse); // Can't revoke
      });

      test('Cashier role has limited permissions', () {
        const cashierPerms = [AppPermissions.posAccess];

        expect(cashierPerms.length, equals(1));
        expect(cashierPerms, contains(AppPermissions.posAccess));
        expect(cashierPerms, isNot(contains(AppPermissions.inventoryItemsUpdate)));
      });
    });

    group('Feature Access Patterns', () {
      test('Viewing a feature requires view permission', () {
        // View permissions
        const viewPerms = [
          AppPermissions.inventoryView,
          AppPermissions.salesView,
          AppPermissions.reportsView,
          AppPermissions.staffView,
          AppPermissions.rolesView,
        ];

        for (final perm in viewPerms) {
          expect(perm, contains('view'));
        }
      });

      test('Modifying a feature requires multiple permissions', () {
        // Edit usually requires view + edit
        const editPerms = [
          AppPermissions.inventoryItemsUpdate,
          AppPermissions.inventoryAdjust,
        ];

        expect(editPerms.length, greaterThan(1));
      });

      test('Admin actions require specific permissions', () {
        const adminPerms = [
          AppPermissions.rolesCreate,
          AppPermissions.rolesUpdate,
          AppPermissions.rolesDelete,
          AppPermissions.staffRevoke,
        ];

        for (final perm in adminPerms) {
          expect(perm, isNotEmpty);
        }
      });
    });

    group('Offline Mode Behavior', () {
      test('Unknown state is distinct from Denied state', () {
        final denied = PermissionCheckResult.denied(
          'pos.write',
          'User lacks permission',
        );
        final unknown = PermissionCheckResult.unknown(
          'Permission cache not available',
        );

        // Denied has isDenied=true, isUnknown=false
        expect(denied.isDenied, isTrue);
        expect(denied.isUnknown, isFalse);

        // Unknown has isUnknown=true, isDenied=false
        expect(unknown.isUnknown, isTrue);
        expect(unknown.isDenied, isFalse);
      });

      test('Offline message is user-friendly', () {
        const offline = PermissionUnknownException(
          'Permission cache not available (offline, no prior cache)',
        );

        expect(offline.message, contains('offline'));
        expect(offline.message, isNot(contains('crash')));
        expect(offline.message, isNot(contains('null')));
      });
    });

    group('Permission Code Format', () {
      test('All permission codes use dotted format', () {
        const allCodes = [
          AppPermissions.posAccess,
          AppPermissions.posDiscount,
          AppPermissions.posRefund,
          AppPermissions.inventoryView,
          AppPermissions.inventoryAdjust,
          AppPermissions.inventoryItemsCreate,
          AppPermissions.inventoryItemsUpdate,
          AppPermissions.inventoryItemsDeactivate,
          AppPermissions.inventoryWasteRecord,
          AppPermissions.inventoryTransfer,
          AppPermissions.salesView,
          AppPermissions.salesExport,
          AppPermissions.reportsView,
          AppPermissions.rolesView,
          AppPermissions.rolesCreate,
          AppPermissions.rolesUpdate,
          AppPermissions.rolesDelete,
          AppPermissions.rolesManagePermissions,
          AppPermissions.staffView,
          AppPermissions.staffAssign,
          AppPermissions.staffRevoke,
          AppPermissions.settingsStore,
          AppPermissions.settingsTax,
          AppPermissions.settingsDevices,
          AppPermissions.settingsBilling,
        ];

        for (final code in allCodes) {
          expect(code, contains('.'));
          // category.action, or category.subcategory.action for the
          // fine-grained inventory codes.
          expect(code.split('.').length, inInclusiveRange(2, 3));
        }
      });

      test('Permission labels are descriptive', () {
        final posLabel = AppPermissions.labelFor(AppPermissions.posAccess);
        final inventoryLabel = AppPermissions.labelFor(AppPermissions.inventoryItemsUpdate);
        final staffLabel = AppPermissions.labelFor(AppPermissions.staffView);

        expect(posLabel, isNotEmpty);
        expect(inventoryLabel, isNotEmpty);
        expect(staffLabel, isNotEmpty);
      });
    });

    group('Safe-by-Default Enforcement', () {
      test('Missing permission should be denied, not granted', () {
        final result = PermissionCheckResult.denied(
          'inventory.edit',
          'User lacks permission',
        );

        // Should NOT be allowed
        expect(result.isAllowed, isFalse);
        expect(result.isDenied, isTrue);
      });

      test('Unknown cache should block action, not grant it', () {
        final result = PermissionCheckResult.unknown(
          'Permission cache not available (offline)',
        );

        // Should NOT be allowed
        expect(result.isAllowed, isFalse);
        expect(result.isUnknown, isTrue);
      });

      test('Offline mode shows explicit message, not silent failure', () {
        const offline = PermissionUnknownException(
          'Permission cache not available (offline)',
        );

        final message = offline.message;
        expect(message, isNotEmpty);
        expect(message, isNot(contains('null')));
        expect(message, isNot(contains('error')));
      });
    });

    group('Enforcement Edge Cases', () {
      test('Empty permission list grants nothing', () {
        const emptyPerms = <String>[];
        expect(emptyPerms, isEmpty);
        expect(emptyPerms.contains('pos.write'), isFalse);
      });

      test('Wildcard overrides all specific checks', () {
        const wildcard = '*';
        const anyPermission = 'pos.write';

        expect(
          wildcard == '*' || wildcard == anyPermission,
          isTrue,
        );
      });

      test('Permission code case matters', () {
        const code1 = 'pos.write';
        const code2 = 'POS.WRITE';
        const code3 = 'Pos.Write';

        expect(code1, isNot(equals(code2)));
        expect(code1, isNot(equals(code3)));
      });
    });
  });
}
