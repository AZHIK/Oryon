import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:restaurant_pos/models/order.dart';
import 'package:restaurant_pos/providers/orders_provider.dart';

import 'test_helpers/test_container.dart';

List<Order> _salesFixture() {
  final now = DateTime.now();
  Order order(
    String id,
    int daysAgo,
    PaymentType payment,
    OrderStatus status,
    double total, {
    String item = 'Lunch special',
  }) => Order(
    id: id,
    lines: [
      OrderLine(
        itemId: 'item-$id',
        name: item,
        emoji: '🍽️',
        unitPrice: total,
        quantity: 1,
      ),
    ],
    placedAt: DateTime(now.year, now.month, now.day - daysAgo, 12),
    paymentType: payment,
    status: status,
    taxRate: 0,
  );

  return [
    order('ORD-0005', 0, PaymentType.card, OrderStatus.paid, 35),
    order('ORD-0004', 1, PaymentType.card, OrderStatus.paid, 25),
    order(
      'ORD-0003',
      10,
      PaymentType.giftCard,
      OrderStatus.paid,
      70,
      item: 'Gift basket',
    ),
    order('ORD-0002', 2, PaymentType.card, OrderStatus.refunded, 45),
    order('ORD-0001', 40, PaymentType.cash, OrderStatus.paid, 90),
  ];
}

class _FixtureOrdersNotifier extends OrdersNotifier {
  @override
  Future<List<Order>> build() async => _salesFixture();
}

void main() {
  group('Sales filters', () {
    // `newTestContainer`, not a bare `ProviderContainer`: `OrdersNotifier`
    // watches `currentStoreIdProvider`, which routes through `AuthNotifier`,
    // and that unconditionally needs a working database even to discover
    // there's no session. Also async because `OrdersNotifier.build()`
    // resolves asynchronously even in demo mode (no store context seeded
    // here) — awaiting its `.future` once avoids every call site racing a
    // read against that resolution.
    Future<ProviderContainer> container() async {
      final c = newTestContainer(
        extraOverrides: [
          ordersProvider.overrideWith(_FixtureOrdersNotifier.new),
        ],
      );
      await c.read(ordersProvider.future);
      return c;
    }

    test('date windows widen from today to all time', () async {
      final c = await container();
      final notifier = c.read(salesFiltersProvider.notifier);

      notifier.setRange(SalesDateRange.today);
      final today = c.read(filteredOrdersProvider).length;

      notifier.setRange(SalesDateRange.week);
      final week = c.read(filteredOrdersProvider).length;

      notifier.setRange(SalesDateRange.month);
      final month = c.read(filteredOrdersProvider).length;

      notifier.setRange(SalesDateRange.all);
      final all = c.read(filteredOrdersProvider).length;

      expect(today, greaterThan(0));
      expect(week, greaterThanOrEqualTo(today));
      expect(month, greaterThanOrEqualTo(week));
      expect(all, greaterThan(month));
    });

    test('a custom range includes both end days', () async {
      final c = await container();
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day - 3);

      c
          .read(salesFiltersProvider.notifier)
          .setCustomRange(
            DateTimeRange(
              start: start,
              end: DateTime(now.year, now.month, now.day),
            ),
          );

      final rows = c.read(filteredOrdersProvider);
      expect(rows, isNotEmpty);
      expect(rows.every((o) => !o.placedAt.isBefore(start)), isTrue);
      // Orders placed later today must still be inside the window.
      expect(rows.any((o) => o.placedAt.day == now.day), isTrue);
    });

    test('payment and status multi-selects compose', () async {
      final c = await container();
      final notifier = c.read(salesFiltersProvider.notifier);
      notifier.setRange(SalesDateRange.all);
      notifier.togglePayment(PaymentType.card);
      notifier.toggleStatus(OrderStatus.paid);

      final rows = c.read(filteredOrdersProvider);
      expect(rows, isNotEmpty);
      expect(
        rows.every(
          (o) =>
              o.paymentType == PaymentType.card && o.status == OrderStatus.paid,
        ),
        isTrue,
      );
      expect(c.read(salesFiltersProvider).activeCount, 2);
    });

    test('clearing keeps the date window the user chose', () async {
      final c = await container();
      final notifier = c.read(salesFiltersProvider.notifier);
      notifier.setRange(SalesDateRange.month);
      notifier.togglePayment(PaymentType.cash);

      notifier.clear();

      expect(c.read(salesFiltersProvider).range, SalesDateRange.month);
      expect(c.read(salesFiltersProvider).activeCount, 0);
    });

    test('changing a filter returns to page one', () async {
      final c = await container();
      c.read(salesQueryProvider.notifier).setPage(2);
      c.read(salesFiltersProvider.notifier).toggleStatus(OrderStatus.paid);
      expect(c.read(salesQueryProvider).page, 0);
    });

    test('summary describes exactly what the table shows', () async {
      final c = await container();
      c.read(salesFiltersProvider.notifier).setRange(SalesDateRange.all);

      final rows = c.read(filteredOrdersProvider);
      final summary = c.read(salesSummaryProvider);

      expect(summary.orderCount, rows.length);
      expect(
        summary.revenue,
        closeTo(rows.fold(0.0, (sum, o) => sum + o.netRevenue), 0.001),
      );

      // Refunded and voided tickets contribute nothing to takings.
      c.read(salesFiltersProvider.notifier).toggleStatus(OrderStatus.refunded);
      expect(c.read(salesSummaryProvider).revenue, 0);
    });

    test('sorting by total then flipping direction', () async {
      final c = await container();
      c.read(salesFiltersProvider.notifier).setRange(SalesDateRange.all);
      c
          .read(salesQueryProvider.notifier)
          .setSort(SalesSort.total, ascending: true);

      final up = c.read(filteredOrdersProvider).map((o) => o.total).toList();
      expect(up.first, lessThanOrEqualTo(up.last));

      c.read(salesQueryProvider.notifier).toggleSort(SalesSort.total);
      final down = c.read(filteredOrdersProvider).map((o) => o.total).toList();
      expect(down.first, greaterThanOrEqualTo(down.last));
    });

    test('search matches id, server, payment and line items', () async {
      final c = await container();
      c.read(salesFiltersProvider.notifier).setRange(SalesDateRange.all);
      final target = c.read(ordersListProvider).first;

      c.read(salesQueryProvider.notifier).setSearch(target.id);
      expect(c.read(filteredOrdersProvider).single.id, target.id);

      c.read(salesQueryProvider.notifier).setSearch('gift');
      final byPayment = c.read(filteredOrdersProvider);
      expect(byPayment, isNotEmpty);
      expect(
        byPayment.every((o) => o.paymentType == PaymentType.giftCard),
        isTrue,
      );
    });
  });
}
