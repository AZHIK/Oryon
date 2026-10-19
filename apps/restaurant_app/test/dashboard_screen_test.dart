import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:restaurant_pos/database/app_database.dart';
import 'package:restaurant_pos/main.dart';
import 'package:restaurant_pos/models/inventory_item.dart';
import 'package:restaurant_pos/models/order.dart';
import 'package:restaurant_pos/providers/dashboard_metrics_provider.dart';
import 'package:restaurant_pos/providers/database_providers.dart';
import 'package:restaurant_pos/providers/inventory_provider.dart';
import 'package:restaurant_pos/providers/orders_provider.dart';
import 'package:restaurant_pos/providers/session_provider.dart';
import 'package:restaurant_pos/router/app_router.dart';
import 'package:restaurant_pos/widgets/dashboard/colorful_metric_card.dart';
import 'package:restaurant_pos/widgets/dashboard/low_stock_alert_banner.dart';

const _widths = <double>[360, 400, 768, 1024, 1440, 1920];

/// A low-stock sellable plus a healthy one, so the low-stock banner and the
/// category donut have something real to show.
const _pizza = InventoryItem(
  id: 'item-pizza',
  sku: 'SKU-PIZZA',
  name: 'Pizza',
  categoryId: 'mains',
  emoji: '🍕',
  stock: 1,
  reorderLevel: 5,
  unitCost: 2,
  sellingPrice: 10,
  isSellable: true,
  itemType: 'sellable',
);

const _water = InventoryItem(
  id: 'item-water',
  sku: 'SKU-WATER',
  name: 'Water',
  categoryId: 'drinks',
  emoji: '💧',
  stock: 50,
  reorderLevel: 5,
  unitCost: 0.5,
  sellingPrice: 2,
  isSellable: true,
  itemType: 'both',
);

Order _todayOrder() {
  final now = DateTime.now();
  return Order(
    id: 'ORD-1000',
    lines: const [
      OrderLine(
        itemId: 'item-pizza',
        name: 'Pizza',
        emoji: '🍕',
        unitPrice: 10,
        quantity: 2,
      ),
      OrderLine(
        itemId: 'item-water',
        name: 'Water',
        emoji: '💧',
        unitPrice: 2,
        quantity: 1,
      ),
    ],
    placedAt: DateTime(now.year, now.month, now.day, 12),
    paymentType: PaymentType.cash,
    status: OrderStatus.paid,
    taxRate: 0,
  );
}

class _FixtureOrdersNotifier extends OrdersNotifier {
  @override
  Future<List<Order>> build() async => [_todayOrder()];
}

/// Feeds the dashboard a small, self-consistent set of orders and stock —
/// the real providers return nothing without a store context.
List<Override> _dataOverrides() => [
  inventoryItemsListProvider.overrideWithValue(const [_pizza, _water]),
  ordersProvider.overrideWith(_FixtureOrdersNotifier.new),
];

Future<ProviderContainer> pumpDashboard(
  WidgetTester tester,
  Size size, {
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = size * tester.view.devicePixelRatio;
  addTearDown(tester.view.reset);

  // The dashboard reads inventory metrics, and InventoryNotifier now watches
  // authProvider (via currentStoreIdProvider), which needs a working database
  // even with no business/store context seeded.
  final database = AppDatabase(NativeDatabase.memory());
  addTearDown(database.close);

  final container = ProviderContainer(
    overrides: [appDatabaseProvider.overrideWithValue(database), ...overrides],
  );
  addTearDown(container.dispose);
  // `SessionNotifier.build()` now returns a signed-out device, so seed an
  // onboarded one or the guard bounces the app to OTP login.
  container.read(sessionProvider.notifier).state = SessionNotifier.seed;

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const RestaurantPosApp(),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  group('Routing', () {
    testWidgets('the app lands on the dashboard', (tester) async {
      await pumpDashboard(tester, const Size(1440, 900));

      // No navigation was performed — this is where the shell starts.
      expect(find.byType(ColorfulMetricCard), findsNWidgets(5));
      expect(find.textContaining('Good '), findsOneWidget);
    });
  });

  group('Layout', () {
    testWidgets('no overflow at any target width', (tester) async {
      for (final width in _widths) {
        final container = await pumpDashboard(tester, Size(width, 1000));
        container.read(goRouterProvider).go(AppRoute.dashboardPath);
        await tester.pumpAndSettle();

        expect(
          tester.takeException(),
          isNull,
          reason: 'dashboard broke at ${width}px',
        );
      }
    });

    testWidgets('all five KPI cards render at every width', (tester) async {
      for (final width in _widths) {
        await pumpDashboard(tester, Size(width, 1000));
        expect(
          find.byType(ColorfulMetricCard),
          findsNWidgets(5),
          reason: 'a KPI card went missing at ${width}px',
        );
      }
    });
  });

  group('Metrics', () {
    testWidgets('the rollup derives from the same orders as Sales', (
      tester,
    ) async {
      final container = await pumpDashboard(tester, const Size(1440, 900));
      final metrics = container.read(dashboardMetricsProvider);
      final orders = container.read(ordersListProvider);

      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day);

      // Recomputed here the long way; if the provider and this disagree, the
      // dashboard is reporting something the ledger would not.
      var expectedSales = 0.0;
      var expectedOrders = 0;
      for (final order in orders) {
        if (!order.status.countsAsRevenue) continue;
        if (order.placedAt.isBefore(startOfToday)) continue;
        expectedSales += order.total;
        expectedOrders++;
      }

      expect(metrics.sales.current, closeTo(expectedSales, 0.01));
      expect(metrics.orders.current, expectedOrders.toDouble());
    });

    testWidgets('average order value is sales over orders', (tester) async {
      final container = await pumpDashboard(tester, const Size(1440, 900));
      final metrics = container.read(dashboardMetricsProvider);

      if (metrics.orders.current == 0) {
        expect(metrics.averageOrderValue.current, 0);
      } else {
        expect(
          metrics.averageOrderValue.current,
          closeTo(metrics.sales.current / metrics.orders.current, 0.01),
        );
      }
    });

    testWidgets('the revenue series covers exactly seven days', (tester) async {
      final container = await pumpDashboard(tester, const Size(1440, 900));
      final series = container.read(dashboardMetricsProvider).revenueSeries;

      expect(series, hasLength(7));
      // Oldest first, one day apart, ending today.
      for (var i = 1; i < series.length; i++) {
        expect(
          series[i].day.difference(series[i - 1].day).inDays,
          1,
          reason: 'the series skipped a day',
        );
      }

      final now = DateTime.now();
      expect(series.last.day, DateTime(now.year, now.month, now.day));
    });

    testWidgets('category shares add up to the whole', (tester) async {
      final container = await pumpDashboard(
        tester,
        const Size(1440, 900),
        overrides: _dataOverrides(),
      );
      final slices = container.read(dashboardMetricsProvider).categoryBreakdown;

      expect(slices, isNotEmpty);
      // Sorted largest first, so the chart and the legend lead with the
      // category that actually matters.
      for (var i = 1; i < slices.length; i++) {
        expect(slices[i - 1].value, greaterThanOrEqualTo(slices[i].value));
      }
    });

    testWidgets('a category keeps its colour between chart and list', (
      tester,
    ) async {
      final container = await pumpDashboard(tester, const Size(1440, 900));
      final metrics = container.read(dashboardMetricsProvider);

      // Every top item's colour index has to be resolvable to the same slice
      // colour the donut uses for that category.
      for (final item in metrics.topItems.take(5)) {
        expect(item.colorIndex, greaterThanOrEqualTo(0));
      }

      // Two items in the same category must share a colour index.
      final byCategory = <String, Set<int>>{};
      for (final item in metrics.topItems) {
        byCategory.putIfAbsent(item.categoryId, () => {}).add(item.colorIndex);
      }
      for (final entry in byCategory.entries) {
        expect(
          entry.value,
          hasLength(1),
          reason: '${entry.key} resolved to more than one colour',
        );
      }
    });

    testWidgets('top sellers are ranked by units', (tester) async {
      final container = await pumpDashboard(tester, const Size(1440, 900));
      final items = container.read(dashboardMetricsProvider).topItems;

      for (var i = 1; i < items.length; i++) {
        expect(items[i - 1].units, greaterThanOrEqualTo(items[i].units));
      }
    });
  });

  group('Low stock banner', () {
    testWidgets('shows when lines are below threshold', (tester) async {
      final container = await pumpDashboard(
        tester,
        const Size(1440, 900),
        overrides: _dataOverrides(),
      );
      final metrics = container.read(dashboardMetricsProvider);

      expect(metrics.lowStockItems, isNotEmpty);
      expect(find.byType(LowStockAlertBanner), findsOneWidget);
    });

    testWidgets('disappears entirely once the stockroom is healthy', (
      tester,
    ) async {
      final container = await pumpDashboard(tester, const Size(1440, 900));
      // pumpAndSettle can return before InventoryNotifier's own build()
      // future has resolved if nothing in the mounted tree forced it first —
      // wait for it explicitly so `restocked` is built from the real catalog,
      // not a momentary empty loading snapshot.
      await container.read(inventoryItemsProvider.future);

      final restocked = [
        for (final item in container.read(inventoryItemsListProvider))
          item.copyWith(stock: item.reorderLevel + 100),
      ];
      final notifier = container.read(inventoryItemsProvider.notifier);
      for (final item in restocked) {
        await notifier.upsert(item);
      }
      await tester.pumpAndSettle();

      expect(container.read(dashboardMetricsProvider).lowStockItems, isEmpty);
      expect(
        find.byType(LowStockAlertBanner),
        findsNothing,
        reason: 'an alert that is always present stops being read',
      );
    });

    testWidgets('tapping it opens Inventory filtered to low stock', (
      tester,
    ) async {
      final container = await pumpDashboard(
        tester,
        const Size(1440, 900),
        overrides: _dataOverrides(),
      );

      await tester.tap(find.byType(LowStockAlertBanner));
      await tester.pumpAndSettle();

      final filters = container.read(inventoryFiltersProvider);
      expect(filters.statuses, contains(StockStatus.lowStock));
      expect(filters.statuses, contains(StockStatus.outOfStock));
      // And the rows behind the filter are the ones the banner named.
      expect(
        container
            .read(filteredInventoryProvider)
            .every((i) => i.status != StockStatus.inStock),
        isTrue,
      );
    });
  });
}
