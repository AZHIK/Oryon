import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:restaurant_pos/models/permission.dart';
import 'package:restaurant_pos/providers/permissions_provider.dart';
import 'package:restaurant_pos/theme/app_theme.dart';
import 'package:restaurant_pos/widgets/responsive_scaffold.dart';

import 'test_helpers/test_container.dart';

/// Same Sell membership as the sidebar: POS, Sales, Customers.
/// Couriers is hidden from navigation (kept, not deleted), so it is
/// deliberately absent here too. Open by default, like in the app.
const _sellGroup = NavGroupSpec(
  label: 'Sell',
  icon: Icons.shopping_basket_outlined,
  children: [1, 2, 3],
  expandedByDefault: true,
);

/// Same Stock membership as the sidebar — collapsed until opened.
const _stockGroup = NavGroupSpec(
  label: 'Stock',
  icon: Icons.warehouse_outlined,
  children: [11, 12, 5, 6, 4],
);

const _stockPermissions = {
  AppPermissions.inventoryView,
  AppPermissions.productionView,
  AppPermissions.suppliersView,
  AppPermissions.procurementView,
};

const _allSellPermissions = {
  AppPermissions.posAccess,
  AppPermissions.posView,
  AppPermissions.customersView,
};

Future<List<int>> pumpGroup(
  WidgetTester tester, {
  NavGroupSpec group = _sellGroup,
  int currentIndex = 0,
  Set<String> permissions = _allSellPermissions,
}) async {
  final container = newTestContainer(
    extraOverrides: [
      hasPermissionProvider.overrideWith(
        (ref, code) => permissions.contains(code),
      ),
    ],
  );
  final picked = <int>[];
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: NavGroupTile(group: group, currentIndex: currentIndex, onSelected: picked.add)),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return picked;
}

void main() {
  group('NavGroupTile dropdown', () {
    testWidgets('Sell starts open; tapping a child navigates', (
      tester,
    ) async {
      final picked = await pumpGroup(tester);

      expect(find.text('Sell'), findsOneWidget);
      expect(find.text('POS'), findsOneWidget);
      expect(find.text('Sales'), findsOneWidget);
      expect(find.text('Customers'), findsOneWidget);
      // Couriers hidden from navigation — kept, not deleted.
      expect(find.text('Couriers'), findsNothing);

      await tester.tap(find.text('Customers'));
      await tester.pumpAndSettle();
      expect(picked, [3]);
    });

    testWidgets('other groups start collapsed until tapped', (tester) async {
      await pumpGroup(
        tester,
        group: _stockGroup,
        permissions: _stockPermissions,
      );

      expect(find.text('Stock'), findsOneWidget);
      expect(find.text('Groceries'), findsNothing);

      await tester.tap(find.text('Stock'));
      await tester.pumpAndSettle();

      expect(find.text('Groceries'), findsOneWidget);
      expect(find.text('Menu items'), findsOneWidget);
      expect(find.text('Production'), findsOneWidget);
      expect(find.text('Suppliers'), findsOneWidget);
      expect(find.text('Purchasing'), findsOneWidget);
    });

    testWidgets('opens itself when it holds the current branch', (
      tester,
    ) async {
      await pumpGroup(tester, currentIndex: 2);

      // No tap needed — Sales is already visible.
      expect(find.text('Sales'), findsOneWidget);
    });

    testWidgets('hides destinations the staff may not see', (tester) async {
      await pumpGroup(
        tester,
        permissions: {AppPermissions.posAccess},
      );

      expect(find.text('POS'), findsOneWidget);
      expect(find.text('Sales'), findsNothing);
      expect(find.text('Customers'), findsNothing);
      expect(find.text('Couriers'), findsNothing);
    });

    testWidgets('renders nothing when no child is visible', (tester) async {
      await pumpGroup(tester, permissions: {});

      expect(find.text('Sell'), findsNothing);
      expect(find.byType(ExpansionTile), findsNothing);
    });
  });
}
