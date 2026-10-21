import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_pos/models/business_role.dart';
import 'package:restaurant_pos/models/staff_member.dart';
import 'package:restaurant_pos/utils/role_name.dart';

void main() {
  group('humanizeRoleName', () {
    test('turns a snake_case identifier into words', () {
      expect(humanizeRoleName('restaurant_owner'), 'Restaurant Owner');
    });

    test('handles kebab-case as well', () {
      expect(humanizeRoleName('store-manager'), 'Store Manager');
    });

    test('keeps words that are already human', () {
      expect(humanizeRoleName('Cashier'), 'Cashier');
      expect(humanizeRoleName('Shift supervisor'), 'Shift supervisor');
    });

    test('trims stray whitespace', () {
      expect(humanizeRoleName('  restaurant_owner  '), 'Restaurant Owner');
    });
  });

  test('BusinessRole exposes the humanized name for the UI', () {
    const role = BusinessRole(
      id: 'role-owner',
      name: 'restaurant_owner',
      description: '',
    );

    expect(role.name, 'restaurant_owner');
    expect(role.displayName, 'Restaurant Owner');
  });

  test('a staff role label is humanized and keeps its store scope', () {
    const businessWide = StaffRoleAssignment(
      roleId: 'role-owner',
      roleName: 'restaurant_owner',
    );
    const storeScoped = StaffRoleAssignment(
      roleId: 'role-manager',
      roleName: 'store_manager',
      storeName: 'Branch Two',
    );

    expect(businessWide.label, 'Restaurant Owner');
    expect(storeScoped.label, 'Store Manager · Branch Two');
  });
}
