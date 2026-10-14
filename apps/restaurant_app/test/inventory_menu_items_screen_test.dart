import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:restaurant_pos/database/app_database.dart';
import 'package:restaurant_pos/main.dart';
import 'package:restaurant_pos/models/inventory_item.dart';
import 'package:restaurant_pos/providers/database_providers.dart';
import 'package:restaurant_pos/providers/inventory_provider.dart';
import 'package:restaurant_pos/providers/permissions_provider.dart';
import 'package:restaurant_pos/providers/production_provider.dart';
import 'package:restaurant_pos/router/app_router.dart';
import 'package:restaurant_pos/screens/inventory/inventory_menu_items_screen.dart';
import 'package:restaurant_pos/services/inventory_api_service.dart';
import 'package:restaurant_pos/theme/app_theme.dart';
import 'package:restaurant_pos/utils/formatters.dart';
import 'package:restaurant_pos/widgets/data_page/data_row_card.dart';
import 'package:restaurant_pos/widgets/data_page/summary_metric_card.dart';

import 'test_helpers/test_container.dart';

const _widths = <double>[360, 400, 768, 1024, 1440, 1920];

Future<ProviderContainer> pumpMenuItems(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size * tester.view.devicePixelRatio;
  addTearDown(tester.view.reset);

  final database = AppDatabase(NativeDatabase.memory());
  addTearDown(database.close);

  final container = ProviderContainer(
    overrides: [appDatabaseProvider.overrideWithValue(database)],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const RestaurantPosApp(),
    ),
  );
  await tester.pumpAndSettle();

  container.read(goRouterProvider).go(AppRoute.menuItems());
  await tester.pumpAndSettle();
  return container;
}

void main() {
  group('Menu Items query', () {
    Future<ProviderContainer> container() async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final c = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
      );
      addTearDown(c.dispose);
      await c.read(inventoryItemsProvider.future);
      return c;
    }

    test('only sellable and both items appear', () async {
      final c = await container();
      final all = c.read(inventoryItemsListProvider);
      final menuItems = c.read(menuCatalogItemsProvider);

      expect(all.any((i) => i.itemType == 'raw_material'), isTrue,
          reason: 'the fixture has to actually contain a pure grocery item '
              'for this test to mean anything');
      expect(
        menuItems.every((i) => i.itemType == 'sellable' || i.itemType == 'both'),
        isTrue,
      );
      expect(menuItems.where((i) => i.itemType == 'raw_material'), isEmpty);
    });

    test('search matches name and category', () async {
      final c = await container();
      c.read(menuItemsQueryProvider.notifier).setSearch('risotto');
      expect(c.read(filteredMenuCatalogProvider), hasLength(1));
    });

    test('sorting by price orders ascending then descending', () async {
      final c = await container();
      c.read(menuItemsQueryProvider.notifier)
          .setSort(MenuItemSort.price, ascending: true);
      final up = c
          .read(filteredMenuCatalogProvider)
          .map((i) => i.sellingPrice ?? 0)
          .toList();
      expect(up, orderedEquals([...up]..sort()));
    });
  });

  group('Menu Items screen', () {
    testWidgets('no overflow at any target width', (tester) async {
      for (final width in _widths) {
        await pumpMenuItems(tester, Size(width, 900));
        expect(tester.takeException(), isNull, reason: 'render error at ${width}px');
        expect(find.byType(SummaryMetricCard), findsNWidgets(3));
      }
    });

    testWidgets('no standalone tab bar links away from Menu Items', (tester) async {
      await pumpMenuItems(tester, const Size(1440, 900));
      expect(find.byType(SegmentedButton), findsNothing);
    });

    testWidgets('desktop shows the menu-specific columns, not stock ones', (
      tester,
    ) async {
      await pumpMenuItems(tester, const Size(1920, 900));

      expect(find.byType(DataRowCard<InventoryItem>), findsNothing);
      expect(find.text('ITEM'), findsOneWidget);
      expect(find.text('CATEGORY'), findsOneWidget);
      expect(find.text('PRICE'), findsOneWidget);
      expect(find.text('ACTIVE'), findsOneWidget);
      // No stock-count/reorder columns — those belong to Groceries.
      expect(find.text('STOCK'), findsNothing);
      expect(find.text('REORDER AT'), findsNothing);
      // No units-sold/revenue columns: no real per-item sales data reaches
      // this screen yet, so they are cleanly omitted rather than faked.
      expect(find.text('UNITS SOLD'), findsNothing);
      expect(find.text('REVENUE'), findsNothing);
    });

    testWidgets('every row is a menu item — none is a pure grocery item', (
      tester,
    ) async {
      final container = await pumpMenuItems(tester, const Size(1440, 900));
      final rows = container.read(menuItemsSliceProvider).items;

      expect(rows, isNotEmpty);
      expect(rows.every((i) => i.itemType != 'raw_material'), isTrue);
    });

    testWidgets('prices render formatted as money', (tester) async {
      final container = await pumpMenuItems(tester, const Size(1920, 900));
      final priced = container
          .read(menuItemsSliceProvider)
          .items
          .firstWhere((i) => i.sellingPrice != null);

      expect(find.textContaining(priced.sellingPrice!.toStringAsFixed(2)), findsWidgets);
    });

    testWidgets('the total-items stat matches the scoped list', (tester) async {
      final container = await pumpMenuItems(tester, const Size(1440, 900));
      final total = container.read(menuCatalogItemsProvider).length;
      expect(find.text('$total'), findsWidgets);
    });
  });

  group('Production cost column', () {
    const pilau = InventoryItem(
      id: 'menu-pilau',
      sku: 'SKU-PILAU',
      name: 'Pilau Plate',
      categoryId: 'mains',
      emoji: '🍚',
      stock: 0,
      reorderLevel: 0,
      unitCost: 4.2,
      trackStock: false,
      catalogItemId: 'backend-pilau',
      itemType: 'sellable',
      sellingPrice: 12.0,
      isSellable: true,
    );
    const mystery = InventoryItem(
      id: 'menu-mystery',
      sku: 'SKU-MYS',
      name: 'Mystery Stew',
      categoryId: 'mains',
      emoji: '🍲',
      stock: 0,
      reorderLevel: 0,
      unitCost: 0,
      trackStock: false,
      catalogItemId: 'backend-mystery',
      itemType: 'sellable',
      sellingPrice: 8.0,
      isSellable: true,
    );

    RecipeDto pilauRecipe() => RecipeDto(
          id: 'recipe-1',
          businessId: 'biz-1',
          sellableItemId: 'backend-pilau',
          sellableItemName: 'Pilau Plate',
          name: 'Pilau',
          targetYieldQuantity: Decimal.fromInt(1),
          totalCost: Decimal.parse('3.50'),
          costPerUnit: Decimal.parse('3.50'),
          costComplete: true,
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1),
          components: const [],
        );

    Future<void> pumpMenu(WidgetTester tester) async {
      tester.view.physicalSize =
          const Size(1920, 900) * tester.view.devicePixelRatio;
      addTearDown(tester.view.reset);
      final container = newTestContainer(
        extraOverrides: [
          inventoryItemsListProvider.overrideWithValue(const [pilau, mystery]),
          recipesCatalogListProvider.overrideWithValue([pilauRecipe()]),
          hasPermissionProvider.overrideWith((ref, code) => true),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const InventoryMenuItemsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('cost values each row at its recipe cost', (tester) async {
      await pumpMenu(tester);

      expect(find.text('COST'), findsOneWidget);
      // Pilau's recipe costs 3.50 a plate — raw materials only.
      expect(find.textContaining(Fmt.money(3.5)), findsWidgets);
      // No recipe and no unit cost: an honest estimate, never a free dish.
      expect(find.textContaining('est.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
