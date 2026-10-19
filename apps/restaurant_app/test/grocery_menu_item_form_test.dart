import 'package:flutter_test/flutter_test.dart';

import 'package:restaurant_pos/models/inventory_item.dart';
import 'package:restaurant_pos/providers/grocery_form_provider.dart';
import 'package:restaurant_pos/providers/menu_item_form_provider.dart';

void main() {
  group('GroceryFormState', () {
    test('required fields gate saving', () {
      var state = GroceryFormState.blank();
      expect(state.canSave, isFalse);

      state = state.copyWith(name: 'Paprika');
      expect(state.canSave, isFalse, reason: 'no category or cost yet');

      state = state.copyWith(categoryId: 'dry');
      expect(state.canSave, isFalse, reason: 'no cost yet');

      state = state.copyWith(unitCost: '4.50');
      expect(state.canSave, isTrue);
    });

    test('a blank low-stock threshold is allowed, a malformed one is not', () {
      final valid = GroceryFormState.blank().copyWith(
        name: 'Paprika',
        categoryId: 'dry',
        unitCost: '4.50',
      );

      expect(valid.copyWith(lowStockAlert: '').canSave, isTrue);
      expect(valid.copyWith(lowStockAlert: '12').canSave, isTrue);
      expect(GroceryFormState.validateLowStockAlert('abc'), isNotNull);
    });

    test('an untracked item never reports as low stock', () {
      const item = InventoryItem(
        id: 'x',
        sku: 'X',
        name: 'X',
        categoryId: 'dry',
        emoji: '📦',
        stock: 0,
        reorderLevel: 10,
        unitCost: 1,
        trackStock: false,
      );

      expect(item.status, StockStatus.inStock);
      expect(item.copyWith(trackStock: true).status, StockStatus.outOfStock);
    });
  });

  group('MenuItemFormState', () {
    test('a fresh form is an untracked dish until the toggle flips', () {
      final state = MenuItemFormState.blank();
      expect(state.trackStock, isFalse);
      expect(state.effectiveItemType, 'sellable');
      expect(state.copyWith(trackStock: true).effectiveItemType, 'both');
    });

    test('name, category, cost and till price gate saving', () {
      var state = MenuItemFormState.blank();
      expect(state.canSave, isFalse);

      state = state.copyWith(name: 'House Salad', categoryId: 'starters');
      expect(state.canSave, isFalse, reason: 'no cost or price yet');

      state = state.copyWith(unitCost: '2.10');
      expect(state.canSave, isFalse, reason: 'no till price yet');

      state = state.copyWith(sellingPrice: '9.50');
      expect(state.canSave, isTrue);
    });

    test('tracked items validate the stock fields, untracked skip them', () {
      final tracked = MenuItemFormState.blank().copyWith(
        name: 'Bottled Cola',
        categoryId: 'drinks',
        unitCost: '0.90',
        sellingPrice: '2.50',
        trackStock: true,
        lowStockAlert: 'nonsense',
      );
      expect(tracked.canSave, isFalse);

      expect(tracked.copyWith(trackStock: false).canSave, isTrue);
    });
  });
}
