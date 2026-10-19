import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:restaurant_pos/database/app_database.dart';
import 'package:restaurant_pos/models/cart.dart';
import 'package:restaurant_pos/models/inventory_item.dart';
import 'package:restaurant_pos/models/menu_item.dart';
import 'package:restaurant_pos/providers/cart_provider.dart';
import 'package:restaurant_pos/providers/database_providers.dart';
import 'package:restaurant_pos/providers/inventory_provider.dart';
import 'package:restaurant_pos/providers/menu_providers.dart';
import 'package:restaurant_pos/providers/permissions_provider.dart';
import 'package:restaurant_pos/providers/session_provider.dart';
import 'package:restaurant_pos/main.dart';

import 'test_helpers/test_container.dart';

const _burger = MenuItem(
  id: 'test-1',
  name: 'Test Burger',
  description: 'For tests',
  price: 10.00,
  categoryId: 'mains',
  emoji: '🍔',
);

/// The menu (`inventoryItemsListProvider`) is empty without a store context —
/// there is no bundled demo catalogue — so the filtering tests seed their own
/// small one. It includes one raw material so "sellable only" is meaningful.
const _catalog = <InventoryItem>[
  InventoryItem(
    id: 'catalog-risotto',
    sku: 'SKU-RISOTTO',
    name: 'Risotto',
    description: 'Creamy mushroom risotto',
    categoryId: 'mains',
    emoji: '🍚',
    stock: 10,
    reorderLevel: 2,
    unitCost: 4,
    sellingPrice: 12,
    isSellable: true,
    itemType: 'sellable',
  ),
  InventoryItem(
    id: 'catalog-cola',
    sku: 'SKU-COLA',
    name: 'Cola',
    description: 'Chilled bottle',
    categoryId: 'drinks',
    emoji: '🥤',
    stock: 20,
    reorderLevel: 5,
    unitCost: 1,
    sellingPrice: 3,
    isSellable: true,
    itemType: 'both',
  ),
  InventoryItem(
    id: 'catalog-flour',
    sku: 'SKU-FLOUR',
    name: 'Flour',
    description: 'Baking flour',
    categoryId: 'dry_goods',
    emoji: '🌾',
    stock: 5,
    reorderLevel: 1,
    unitCost: 2,
    itemType: 'raw_material',
  ),
];

ProviderContainer _menuContainer() => newTestContainer(
  extraOverrides: [inventoryItemsListProvider.overrideWithValue(_catalog)],
);

void main() {
  group('Cart totals', () {
    test('subtotal, tax and total compose correctly', () {
      const cart = Cart(
        items: [CartItem(item: _burger, quantity: 3)],
        taxRate: 0.10,
      );

      expect(cart.itemCount, 3);
      expect(cart.subtotal, 30.00);
      expect(cart.tax, closeTo(3.00, 0.001));
      expect(cart.total, closeTo(33.00, 0.001));
    });

    test('discount applies before tax', () {
      const cart = Cart(
        items: [CartItem(item: _burger, quantity: 2)],
        taxRate: 0.10,
        discountRate: 0.50,
      );

      expect(cart.subtotal, 20.00);
      expect(cart.discount, 10.00);
      expect(cart.tax, closeTo(1.00, 0.001));
      expect(cart.total, closeTo(11.00, 0.001));
    });
  });

  group('CartNotifier', () {
    test('adding the same item merges into one line', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(cartProvider.notifier)
        ..add(_burger)
        ..add(_burger, quantity: 2);

      final cart = container.read(cartProvider);
      expect(cart.items, hasLength(1));
      expect(cart.quantityOf(_burger.id), 3);
    });

    test('decrementing to zero removes the line', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(cartProvider.notifier)..add(_burger);
      notifier.decrement(_burger.id);

      expect(container.read(cartProvider).isEmpty, isTrue);
    });

    test('unavailable items are rejected', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container
          .read(cartProvider.notifier)
          .add(_burger.copyWith(isAvailable: false));

      expect(container.read(cartProvider).isEmpty, isTrue);
    });
  });

  group('Menu filtering', () {
    // The menu is derived from `inventoryItemsListProvider`, which is empty
    // with no store context (there is no bundled demo catalogue any more), so
    // each test seeds a small catalogue via [_menuContainer].
    test('search matches name and description', () {
      final container = _menuContainer();

      container.read(searchQueryProvider.notifier).state = 'risotto';
      final results = container.read(filteredMenuItemsProvider);

      expect(results, isNotEmpty);
      expect(
        results.every(
          (i) =>
              i.name.toLowerCase().contains('risotto') ||
              i.description.toLowerCase().contains('risotto'),
        ),
        isTrue,
      );
    });

    test('category filter narrows to one category', () {
      final container = _menuContainer();

      container.read(selectedCategoryProvider.notifier).state = 'drinks';
      final results = container.read(filteredMenuItemsProvider);

      expect(results, isNotEmpty);
      expect(results.every((i) => i.categoryId == 'drinks'), isTrue);
    });
  });

  group('Shell navigation adapts to width', () {
    /// Drives the app at a fixed logical window size.
    ///
    /// Seeds an onboarded session: `SessionNotifier.build()` now returns a
    /// fresh *signed-out* device, so without this the app lands on OTP login
    /// rather than the shell. [overrides] lets a test grant permissions (the
    /// POS tab, for one, is `pos.access`-gated).
    Future<void> pumpAt(
      WidgetTester tester,
      Size size, {
      List<Override> overrides = const [],
    }) async {
      tester.view.physicalSize = size * tester.view.devicePixelRatio;
      tester.view.devicePixelRatio = tester.view.devicePixelRatio;
      addTearDown(tester.view.reset);

      // The shell lands on the dashboard, which reads inventory data —
      // InventoryNotifier now watches authProvider (via currentStoreIdProvider),
      // which needs a working database even with no context seeded.
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          ...overrides,
        ],
      );
      addTearDown(container.dispose);
      container.read(sessionProvider.notifier).state = SessionNotifier.seed;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const RestaurantPosApp(),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('phone width shows the bottom navigation bar', (tester) async {
      await pumpAt(
        tester,
        const Size(390, 844),
        // POS is permission-gated, so grant it for this one — the point is
        // that a phone shows the bottom bar with its primary destinations.
        overrides: [hasPermissionProvider.overrideWith((ref, code) => true)],
      );

      expect(find.text('POS'), findsWidgets);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
    });

    testWidgets('tablet width hides nav behind a drawer', (tester) async {
      await pumpAt(tester, const Size(834, 1112));

      expect(find.byType(NavigationRail), findsNothing);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(NavigationDrawer), findsNothing, reason: 'closed');
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold).first).drawer,
        isNotNull,
      );
    });

    testWidgets('wide desktop groups the sidebar into dropdowns', (
      tester,
    ) async {
      await pumpAt(tester, const Size(1440, 900));

      expect(find.byType(NavigationRail), findsNothing);
      expect(find.byType(NavigationBar), findsNothing);
      // No permissions seeded, so only the permission-free Dashboard shows
      // and every dropdown stays hidden.
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Sell'), findsNothing);
    });

    testWidgets('narrow desktop keeps the icon rail', (tester) async {
      await pumpAt(tester, const Size(1100, 800));

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('no overflow at common breakpoints', (tester) async {
      for (final width in [360.0, 400.0, 768.0, 1024.0, 1440.0, 1920.0]) {
        await pumpAt(tester, Size(width, 800));
        expect(
          tester.takeException(),
          isNull,
          reason: 'overflow or error at ${width}px',
        );
      }
    });
  });
}
