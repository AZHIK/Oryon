/// Tests for the online-only purchases module.
///
/// - DTO parsing against sample backend payloads.
/// - `PurchasesNotifier` with a fake `PurchaseApiService` (no network):
///   fetch ordering, create/refresh, error passthrough.
/// - `PurchasesScreen` widget: empty state with no business context, and
///   the offline placeholder when `isOnlineProvider` is false (purchases
///   never render cached data).
library;

import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:restaurant_pos/auth/permission_enforcement.dart';
import 'package:restaurant_pos/models/purchase_order.dart';
import 'package:restaurant_pos/providers/connectivity_provider.dart';
import 'package:restaurant_pos/models/inventory_item.dart';
import 'package:restaurant_pos/models/supplier.dart';
import 'package:restaurant_pos/providers/inventory_api_provider.dart';
import 'package:restaurant_pos/providers/inventory_provider.dart';
import 'package:restaurant_pos/providers/suppliers_provider.dart';
import 'package:restaurant_pos/providers/permissions_provider.dart';
import 'package:restaurant_pos/providers/purchases_provider.dart';
import 'package:restaurant_pos/screens/purchases/purchase_order_dialog.dart';
import 'package:restaurant_pos/screens/purchases/purchases_screen.dart';
import 'package:restaurant_pos/screens/purchasing/purchasing_screen.dart';
import 'package:restaurant_pos/services/purchase_api_service.dart';
import 'package:restaurant_pos/theme/app_theme.dart';

import 'test_helpers/test_container.dart';

Map<String, dynamic> _orderJson(String id, String status) => {
  'id': id,
  'business_id': 'biz-1',
  'store_id': 'store-1',
  'supplier_id': 'sup-1',
  'po_number': 'PO-$id',
  'status': status,
  'invoice_status': 'unbilled',
  'notes': null,
  'ordered_at': '2026-09-20T10:00:00Z',
  'expected_at': null,
  'received_at': null,
  'lines': [
    {
      'id': 'line-$id',
      'purchase_order_id': id,
      'item_id': 'item-1',
      'quantity_ordered': '20.000',
      'quantity_received': status == 'fulfilled' ? '20.000' : '0.000',
      'unit': 'kg',
      'notes': null,
    },
  ],
};

class FakePurchaseApi extends PurchaseApiService {
  FakePurchaseApi({this.orders = const [], this.throwOnFetch = false})
    : super(dio: Dio());

  List<Map<String, dynamic>> orders;
  bool throwOnFetch;
  int fetchCount = 0;

  /// Supplier ids requested by [createOrder], in call order — for asserting
  /// per-item mode fans out to one order per supplier.
  final createdSupplierIds = <String>[];

  @override
  Future<List<PurchaseOrderDto>> fetchOrders({
    required String businessId,
    String? status,
  }) async {
    fetchCount++;
    if (throwOnFetch) throw PurchaseApiException('offline', 0);
    return orders.map(PurchaseOrderDto.fromJson).toList();
  }

  @override
  Future<PurchaseOrderDto> createOrder({
    required String businessId,
    required String storeId,
    required String supplierId,
    required List<PurchaseOrderLineInput> lines,
    String? poNumber,
    String? notes,
    DateTime? expectedAt,
  }) async {
    createdSupplierIds.add(supplierId);
    final created = _orderJson('new-${createdSupplierIds.length}', 'unfulfilled');
    orders = [...orders, created];
    return PurchaseOrderDto.fromJson(created);
  }
}

ProviderContainer _containerWithFake(FakePurchaseApi fake) {
  return newTestContainer(
    extraOverrides: [
      purchaseApiServiceProvider.overrideWithValue(fake),
      currentBusinessIdProvider.overrideWithValue('biz-1'),
      currentStoreIdProvider.overrideWithValue('store-1'),
    ],
  );
}

Future<void> pumpScreen(
  WidgetTester tester,
  ProviderContainer container,
  Widget screen,
) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: screen),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('PurchaseOrderDto', () {
    test('parses backend payload including lines', () {
      final dto = PurchaseOrderDto.fromJson(_orderJson('o1', 'unfulfilled'));
      expect(dto.poNumber, 'PO-o1');
      expect(dto.status, 'unfulfilled');
      expect(dto.lines, hasLength(1));
      expect(dto.lines.first.outstanding, Decimal.parse('20.000'));
    });

    test('model maps status and open flag', () {
      final order = PurchaseOrder.fromDto(
        PurchaseOrderDto.fromJson(_orderJson('o1', 'unfulfilled')),
      );
      expect(order.status, PurchaseOrderStatus.unfulfilled);
      expect(order.status.isOpen, isTrue);
      expect(order.lines.first.outstanding, 20.0);

      final fulfilled = PurchaseOrder.fromDto(
        PurchaseOrderDto.fromJson(_orderJson('o2', 'fulfilled')),
      );
      expect(fulfilled.status.isOpen, isFalse);
    });

    test('maps the two-step lifecycle, never unknown', () {
      // Regression guard for orders showing "Unknown" in the list.
      final expected = {
        'unfulfilled': PurchaseOrderStatus.unfulfilled,
        'fulfilled': PurchaseOrderStatus.fulfilled,
        'cancelled': PurchaseOrderStatus.cancelled,
      };
      expected.forEach((wire, status) {
        final order = PurchaseOrder.fromDto(
          PurchaseOrderDto.fromJson(_orderJson('o-$wire', wire)),
        );
        expect(order.status, status, reason: wire);
        expect(order.status.label, isNot('Unknown'), reason: wire);
      });

      // Truly unrecognized values still fall back to unknown (closed).
      final strange = PurchaseOrder.fromDto(
        PurchaseOrderDto.fromJson(_orderJson('o-x', 'flying_carpet')),
      );
      expect(strange.status, PurchaseOrderStatus.unknown);
      expect(strange.status.isOpen, isFalse);
    });

    test('open flag covers unfulfilled orders only', () {
      expect(PurchaseOrderStatus.unfulfilled.isOpen, isTrue);
      expect(PurchaseOrderStatus.fulfilled.isOpen, isFalse);
      expect(PurchaseOrderStatus.cancelled.isOpen, isFalse);
    });
  });

  group('PurchasesNotifier', () {
    test('returns empty list with no business context', () async {
      final container = newTestContainer();
      expect(await container.read(purchasesProvider.future), isEmpty);
    });

    test('fetches newest-first and refreshes after create', () async {
      final fake = FakePurchaseApi(
        orders: [_orderJson('older', 'fulfilled'), _orderJson('newer', 'unfulfilled')],
      );
      // Make ordering deterministic via ordered_at.
      fake.orders[1] = {
        ...fake.orders[1],
        'ordered_at': '2026-09-21T10:00:00Z',
      };
      final container = _containerWithFake(fake);

      final orders = await container.read(purchasesProvider.future);
      expect(orders.map((o) => o.id), ['newer', 'older']);
      expect(container.read(openPurchasesProvider).map((o) => o.id), ['newer']);

      await container
          .read(purchasesProvider.notifier)
          .create(
            supplierId: 'sup-1',
            lines: [
              PurchaseOrderLineInput(
                itemId: 'item-1',
                quantityOrdered: Decimal.parse('5'),
              ),
            ],
          );
      expect(fake.fetchCount, greaterThanOrEqualTo(2));
      expect(
        container.read(purchasesListProvider).any((o) => o.id == 'new-1'),
        isTrue,
      );
    });

    test('fetch errors surface instead of cached data', () async {
      final fake = FakePurchaseApi(throwOnFetch: true);
      final container = _containerWithFake(fake);
      await expectLater(
        container.read(purchasesProvider.future),
        throwsA(isA<PurchaseApiException>()),
      );
    });
  });

  group('PurchasesScreen', () {
    testWidgets('shows empty table state with no business context', (
      tester,
    ) async {
      final container = newTestContainer();
      await pumpScreen(tester, container, const PurchasesScreen());
      expect(find.text('Purchases'), findsOneWidget);
      expect(find.text('No results'), findsOneWidget);
    });

    testWidgets('shows offline placeholder instead of data', (tester) async {
      final fake = FakePurchaseApi(orders: [_orderJson('o1', 'unfulfilled')]);
      final container = newTestContainer(
        extraOverrides: [
          purchaseApiServiceProvider.overrideWithValue(fake),
          currentBusinessIdProvider.overrideWithValue('biz-1'),
          currentStoreIdProvider.overrideWithValue('store-1'),
          isOnlineProvider.overrideWith((ref) => Stream.value(false)),
        ],
      );
      await pumpScreen(tester, container, const PurchasesScreen());
      expect(find.text('Purchases need internet'), findsOneWidget);
      expect(find.text('PO-o1'), findsNothing);
    });

    testWidgets('lists orders when online', (tester) async {
      final fake = FakePurchaseApi(orders: [_orderJson('o1', 'unfulfilled')]);
      final container = _containerWithFake(fake);
      await pumpScreen(tester, container, const PurchasesScreen());
      expect(find.text('PO-o1'), findsOneWidget);
    });

    testWidgets('order dialog shows supplier, items and total on one screen', (
      tester,
    ) async {
      final container = newTestContainer(
        extraOverrides: [
          suppliersListProvider.overrideWithValue([
            Supplier(
              id: 'sup-1',
              name: 'Acme Foods',
              createdAt: DateTime.utc(2026, 1, 1),
            ),
          ]),
          inventoryItemsListProvider.overrideWithValue([
            const InventoryItem(
              id: 'item-1',
              sku: 'SKU-1',
              name: 'Flour',
              categoryId: 'cat-1',
              emoji: '🌾',
              stock: 10,
              reorderLevel: 2,
              unitCost: 2.5,
              itemType: 'raw_material',
            ),
          ]),
        ],
      );
      await pumpScreen(
        tester,
        container,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showPurchaseOrderDialog(context),
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('New purchase order'), findsOneWidget);
      // Single screen: supplier picker, qty-only item lines with
      // quick-add — no cost field, no Continue step.
      expect(find.text('Continue — add items'), findsNothing);
      expect(find.byTooltip('Add new item'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Cost'), findsNothing);
      expect(find.widgetWithText(TextField, 'Qty'), findsOneWidget);
      expect(find.text('Add item'), findsOneWidget);

      // Lines are editable before a supplier is picked: add a second row.
      await tester.tap(find.text('Add item'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Add new item'), findsNWidgets(2));

      // Saving without a supplier stays in the dialog with an error.
      await tester.tap(find.text('Create order'));
      await tester.pumpAndSettle();
      expect(find.text('Choose a supplier'), findsOneWidget);
    });
  });

  group('PurchaseSupplierMode', () {
    test('groupPurchaseLinesBySupplier preserves first-seen order', () {
      PurchaseOrderLineInput line(String item) => PurchaseOrderLineInput(
        itemId: item,
        quantityOrdered: Decimal.parse('1'),
      );
      final groups = groupPurchaseLinesBySupplier([
        (input: line('a'), supplierId: 'sup-2'),
        (input: line('b'), supplierId: 'sup-1'),
        (input: line('c'), supplierId: 'sup-2'),
      ]);
      expect(groups.map((g) => g.key), ['sup-2', 'sup-1']);
      expect(groups.first.value.map((l) => l.itemId), ['a', 'c']);
      expect(groups.last.value.map((l) => l.itemId), ['b']);
    });

    ProviderContainer dialogContainer(
      FakePurchaseApi fake, {
      List<Supplier> suppliers = const [],
      List<InventoryItem> items = const [],
    }) {
      return newTestContainer(
        extraOverrides: [
          purchaseApiServiceProvider.overrideWithValue(fake),
          currentBusinessIdProvider.overrideWithValue('biz-1'),
          currentStoreIdProvider.overrideWithValue('store-1'),
          suppliersListProvider.overrideWithValue(suppliers),
          inventoryItemsListProvider.overrideWithValue(items),
        ],
      );
    }

    Supplier supplier(String id, String name) =>
        Supplier(id: id, name: name, createdAt: DateTime.utc(2026, 1, 1));

    const flour = InventoryItem(
      id: 'item-1',
      sku: 'SKU-1',
      name: 'Flour',
      categoryId: 'cat-1',
      emoji: '🌾',
      stock: 10,
      reorderLevel: 2,
      unitCost: 2.5,
      itemType: 'raw_material',
    );

    const sugar = InventoryItem(
      id: 'item-2',
      sku: 'SKU-2',
      name: 'Sugar',
      categoryId: 'cat-1',
      emoji: '🍬',
      stock: 10,
      reorderLevel: 2,
      unitCost: 1.5,
      itemType: 'raw_material',
    );

    Future<void> openDialog(
      WidgetTester tester,
      ProviderContainer container,
    ) async {
      await pumpScreen(
        tester,
        container,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showPurchaseOrderDialog(context),
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('New purchase order'), findsOneWidget);
    }

    Future<void> selectOption(
      WidgetTester tester, {
      required String fieldLabel,
      required int index,
      required String option,
    }) async {
      await tester.tap(
        find
            .widgetWithText(DropdownButtonFormField<String>, fieldLabel)
            .at(index),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(option).last);
      await tester.pumpAndSettle();
    }

    testWidgets('defaults to one supplier with a top-level picker', (
      tester,
    ) async {
      final container = dialogContainer(
        FakePurchaseApi(),
        suppliers: [supplier('sup-1', 'Acme Foods')],
        items: [flour],
      );
      await openDialog(tester, container);
      expect(find.text('One supplier'), findsOneWidget);
      expect(find.text('Per item'), findsOneWidget);
      expect(find.text('No supplier'), findsOneWidget);
      expect(
        find.widgetWithText(DropdownButtonFormField<String>, 'Supplier'),
        findsOneWidget,
      );
      expect(find.text('Line supplier'), findsNothing);
      // Quick-add supplier next to the single-supplier picker.
      expect(find.byTooltip('Add new supplier'), findsOneWidget);
    });

    testWidgets('add supplier button opens the supplier form', (tester) async {
      final container = dialogContainer(
        FakePurchaseApi(),
        suppliers: [supplier('sup-1', 'Acme Foods')],
        items: [flour],
      );
      await openDialog(tester, container);
      await tester.tap(find.byTooltip('Add new supplier'));
      await tester.pumpAndSettle();
      expect(find.text('Add supplier'), findsWidgets);
    });

    testWidgets('per-item mode shows a supplier picker on every line', (
      tester,
    ) async {
      final container = dialogContainer(
        FakePurchaseApi(),
        suppliers: [supplier('sup-1', 'Acme Foods')],
        items: [flour],
      );
      await openDialog(tester, container);
      await tester.tap(find.text('Per item'));
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(DropdownButtonFormField<String>, 'Supplier'),
        findsNothing,
      );
      expect(find.text('Line supplier'), findsOneWidget);
      expect(find.byTooltip('Add new supplier'), findsOneWidget);
      await tester.tap(find.text('Add item'));
      await tester.pumpAndSettle();
      expect(find.text('Line supplier'), findsNWidgets(2));
      // One quick-add supplier button per line, after the picker.
      expect(find.byTooltip('Add new supplier'), findsNWidgets(2));
    });

    testWidgets('lines are qty-only with no cost field', (tester) async {
      final container = dialogContainer(
        FakePurchaseApi(),
        suppliers: [supplier('sup-1', 'Acme Foods')],
        items: [flour],
      );
      await openDialog(tester, container);
      expect(find.widgetWithText(TextField, 'Qty'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Cost'), findsNothing);
      expect(find.textContaining('qty-only'), findsOneWidget);
    });

    testWidgets('no-supplier mode hides pickers and names Unknown supplier', (
      tester,
    ) async {
      final container = dialogContainer(
        FakePurchaseApi(),
        suppliers: [supplier('sup-1', 'Acme Foods')],
        items: [flour],
      );
      await openDialog(tester, container);
      await tester.tap(find.text('No supplier'));
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(DropdownButtonFormField<String>, 'Supplier'),
        findsNothing,
      );
      expect(find.text('Line supplier'), findsNothing);
      expect(find.textContaining('Unknown supplier'), findsWidgets);
    });

    testWidgets('per-item mode creates one order per supplier', (tester) async {
      final fake = FakePurchaseApi();
      final container = dialogContainer(
        fake,
        suppliers: [
          supplier('sup-1', 'Acme Foods'),
          supplier('sup-2', 'Globex'),
        ],
        items: [flour, sugar],
      );
      await openDialog(tester, container);
      await tester.tap(find.text('Per item'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add item'));
      await tester.pumpAndSettle();

      await selectOption(tester, fieldLabel: 'Item', index: 0, option: 'Flour');
      await tester.enterText(find.widgetWithText(TextField, 'Qty').at(0), '5');
      await selectOption(
        tester,
        fieldLabel: 'Line supplier',
        index: 0,
        option: 'Acme Foods',
      );

      await selectOption(tester, fieldLabel: 'Item', index: 1, option: 'Sugar');
      await tester.enterText(find.widgetWithText(TextField, 'Qty').at(1), '3');
      await selectOption(
        tester,
        fieldLabel: 'Line supplier',
        index: 1,
        option: 'Globex',
      );

      await tester.tap(find.text('Create order'));
      await tester.pumpAndSettle();
      expect(find.text('New purchase order'), findsNothing);
      expect(fake.createdSupplierIds, ['sup-1', 'sup-2']);
      expect(find.text('2 orders created — one per supplier.'), findsOneWidget);
    });

    testWidgets('per-item mode requires a supplier on every line', (
      tester,
    ) async {
      final fake = FakePurchaseApi();
      final container = dialogContainer(
        fake,
        suppliers: [supplier('sup-1', 'Acme Foods')],
        items: [flour],
      );
      await openDialog(tester, container);
      await tester.tap(find.text('Per item'));
      await tester.pumpAndSettle();
      await selectOption(tester, fieldLabel: 'Item', index: 0, option: 'Flour');
      await tester.enterText(find.widgetWithText(TextField, 'Qty').at(0), '5');
      await tester.tap(find.text('Create order'));
      await tester.pumpAndSettle();
      expect(find.text('Each line needs a supplier'), findsOneWidget);
      expect(fake.createdSupplierIds, isEmpty);
    });

    testWidgets('no-supplier mode saves under the Unknown supplier', (
      tester,
    ) async {
      final fake = FakePurchaseApi();
      final container = dialogContainer(
        fake,
        suppliers: [supplier('sup-0', 'Unknown supplier')],
        items: [flour],
      );
      await openDialog(tester, container);
      await tester.tap(find.text('No supplier'));
      await tester.pumpAndSettle();
      await selectOption(tester, fieldLabel: 'Item', index: 0, option: 'Flour');
      await tester.enterText(find.widgetWithText(TextField, 'Qty').at(0), '5');
      await tester.tap(find.text('Create order'));
      await tester.pumpAndSettle();
      expect(find.text('New purchase order'), findsNothing);
      expect(fake.createdSupplierIds, ['sup-0']);
    });
  });

  group('PurchasingScreen — purchases only', () {
    ProviderContainer gatedContainer() {
      return newTestContainer(
        extraOverrides: [
          // Grant every permission check so the screen renders content.
          canPerformActionProvider.overrideWith(
            (ref, arg) => Future.value(true),
          ),
        ],
      );
    }

    testWidgets('shows purchases with no reorder tab', (tester) async {
      final container = gatedContainer();
      await pumpScreen(tester, container, const PurchasingScreen());
      expect(find.text('Purchasing'), findsOneWidget);
      // No business context → empty table state.
      expect(find.text('No results'), findsOneWidget);
      // Reorder section is gone.
      expect(find.text('Reorders'), findsNothing);
      expect(find.text('New purchase'), findsNothing);
      expect(find.text('Pending'), findsNothing);
    });
  });
}
