import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:restaurant_pos/database/app_database.dart';
import 'package:restaurant_pos/models/inventory_item.dart';
import 'package:restaurant_pos/providers/database_providers.dart';
import 'package:restaurant_pos/providers/inventory_provider.dart';

/// Local catalog fixtures — a mix of grocery and sellable-only items with
/// varied stock levels, so the query, summary and table tests have real
/// rows to work with. Plain test data, not shared fixtures.
List<InventoryItem> _fixtureItems() => [
  InventoryItem(
    id: 'test-flour',
    sku: 'SKU-FLOUR',
    name: 'All-purpose Flour',
    categoryId: 'dry',
    emoji: '🌾',
    stock: 20,
    reorderLevel: 5,
    unitCost: 1.2,
    unit: 'kg',
    itemType: 'raw_material',
  ),
  InventoryItem(
    id: 'test-tomatoes',
    sku: 'SKU-TOMATO',
    name: 'Heirloom Tomatoes',
    categoryId: 'produce',
    emoji: '🍅',
    stock: 2,
    reorderLevel: 5,
    unitCost: 0.8,
    unit: 'kg',
    itemType: 'both',
    sellingPrice: 3.5,
    isSellable: true,
  ),
  InventoryItem(
    id: 'test-milk',
    sku: 'SKU-MILK',
    name: 'Whole Milk',
    categoryId: 'dairy',
    emoji: '🥛',
    stock: 0,
    reorderLevel: 4,
    unitCost: 1.0,
    unit: 'L',
    itemType: 'raw_material',
  ),
  InventoryItem(
    id: 'test-pizza',
    sku: 'SKU-PIZZA',
    name: 'Margherita Pizza',
    categoryId: 'mains',
    emoji: '🍕',
    stock: 0,
    reorderLevel: 0,
    unitCost: 2.5,
    trackStock: false,
    itemType: 'sellable',
    sellingPrice: 12.0,
    isSellable: true,
  ),
];

void main() {
  group('Groceries query', () {
    Future<ProviderContainer> container() async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final c = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          inventoryItemsListProvider.overrideWithValue(_fixtureItems()),
        ],
      );
      addTearDown(c.dispose);
      await c.read(inventoryItemsProvider.future);
      return c;
    }

    test(
      'only raw_material items appear — never sellable, never both',
      () async {
        final c = await container();
        final all = c.read(inventoryItemsListProvider);
        final groceries = c.read(groceryItemsProvider);

        expect(
          all.any((i) => i.itemType == 'sellable'),
          isTrue,
          reason:
              'the fixture has to actually contain a pure menu item '
              'for this test to mean anything',
        );
        expect(
          all.any((i) => i.itemType == 'both'),
          isTrue,
          reason:
              'the fixture has to contain a both item to prove it stays '
              'on Menu Items',
        );
        expect(groceries.every((i) => i.itemType == 'raw_material'), isTrue);
        expect(groceries.where((i) => i.itemType == 'both'), isEmpty);
        expect(groceries.where((i) => i.itemType == 'sellable'), isEmpty);
      },
    );

    test('summary is scoped to groceries, not the whole catalog', () async {
      final c = await container();
      final groceries = c.read(groceryItemsProvider);
      final summary = c.read(inventorySummaryProvider);

      expect(summary.totalItems, groceries.length);
      expect(
        summary.totalItems,
        lessThan(c.read(inventoryItemsListProvider).length),
      );
      expect(
        summary.lowStockCount,
        groceries.where((i) => i.status == StockStatus.lowStock).length,
      );
      expect(
        summary.outOfStockCount,
        groceries.where((i) => i.status == StockStatus.outOfStock).length,
      );
      expect(
        summary.totalValue,
        groceries.fold<double>(0, (sum, i) => sum + i.totalValue),
      );
    });
  });
}
