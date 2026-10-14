import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/activity_entry.dart';
import '../constants/app_durations.dart';
import '../models/inventory_item.dart';
import '../models/order.dart';
import '../models/stock_movement.dart';
import 'inventory_provider.dart';
import 'orders_provider.dart';
import 'other_expenses_provider.dart';
import 'other_incomes_provider.dart';
import 'production_provider.dart';
import 'staff_provider.dart';
import 'stock_movement_provider.dart';

@immutable
class DashboardSummary {
  const DashboardSummary({
    required this.takingsToday,
    required this.takingsYesterday,
    required this.ordersToday,
    required this.averageTicket,
    required this.openOrders,
    required this.needsReordering,
    required this.otherIncomeToday,
    required this.otherExpensesToday,
    required this.cogsToday,
  });

  final double takingsToday;
  final double takingsYesterday;
  final int ordersToday;
  final double averageTicket;
  final int openOrders;
  final int needsReordering;
  final double otherIncomeToday;
  final double otherExpensesToday;
  final double cogsToday;

  double? get takingsChange {
    if (takingsYesterday <= 0) return null;
    return (takingsToday - takingsYesterday) / takingsYesterday;
  }

  double get netProfitToday =>
      takingsToday + otherIncomeToday - otherExpensesToday - cogsToday;
}

final dashboardSummaryProvider = Provider<DashboardSummary>((ref) {
  final orders = ref.watch(ordersListProvider);
  final items = ref.watch(inventoryItemsListProvider);
  final expenses = ref.watch(otherExpensesListProvider);
  final incomes = ref.watch(otherIncomesListProvider);

  final now = DateTime.now();
  final startOfToday = DateTime(now.year, now.month, now.day);
  final startOfYesterday = startOfToday.subtract(AppDurations.singleDay);

  var takingsToday = 0.0;
  var takingsYesterday = 0.0;
  var ordersToday = 0;
  var openOrders = 0;
  var otherIncomeToday = 0.0;
  var otherExpensesToday = 0.0;
  var cogsToday = 0.0;

  // Recipe cost per sellable, else the item's own unit cost (resold goods).
  final recipes = ref.watch(recipesCatalogListProvider);
  final recipeCost = <String, double>{
    for (final r in recipes)
      if (r.sellableItemId != null)
        r.sellableItemId!: double.parse(r.costPerUnit.toString()),
  };
  final fallbackCost = <String, double>{for (final i in items) i.id: i.unitCost};

  for (final order in orders) {
    final counts = order.status.countsAsRevenue;

    if (!order.placedAt.isBefore(startOfToday)) {
      ordersToday++;
      if (counts) {
        takingsToday += order.total;
        for (final line in order.lines) {
          cogsToday +=
              (recipeCost[line.itemId] ?? fallbackCost[line.itemId] ?? 0.0) *
              line.quantity;
        }
      }
    } else if (!order.placedAt.isBefore(startOfYesterday)) {
      if (counts) takingsYesterday += order.total;
    }

    if (order.status == OrderStatus.pending) openOrders++;
  }

  for (final expense in expenses) {
    if (!expense.date.isBefore(startOfToday)) {
      otherExpensesToday += expense.amount;
    }
  }

  for (final income in incomes) {
    if (!income.date.isBefore(startOfToday)) {
      otherIncomeToday += income.amount;
    }
  }

  var needsReordering = 0;
  for (final item in items) {
    if (item.status != StockStatus.inStock) needsReordering++;
  }

  return DashboardSummary(
    takingsToday: takingsToday,
    takingsYesterday: takingsYesterday,
    ordersToday: ordersToday,
    averageTicket: ordersToday == 0 ? 0 : takingsToday / ordersToday,
    openOrders: openOrders,
    needsReordering: needsReordering,
    otherIncomeToday: otherIncomeToday,
    otherExpensesToday: otherExpensesToday,
    cogsToday: cogsToday,
  );
});

final reorderListProvider = Provider<List<InventoryItem>>((ref) {
  final items = [
    for (final item in ref.watch(inventoryItemsListProvider))
      if (item.trackStock && item.status != StockStatus.inStock) item,
  ];

  items.sort((a, b) {
    final byStatus = a.status.index.compareTo(b.status.index);
    if (byStatus != 0) return -byStatus;

    double deficit(InventoryItem i) => i.reorderLevel == 0 ? 0 : (i.reorderLevel - i.stock) / i.reorderLevel;
    final byDeficit = deficit(b).compareTo(deficit(a));
    return byDeficit != 0 ? byDeficit : a.name.compareTo(b.name);
  });

  return items;
});

final recentOrdersProvider = Provider<List<Order>>((ref) {
  final orders = [...ref.watch(ordersListProvider)]..sort((a, b) => b.placedAt.compareTo(a.placedAt));
  return orders;
});

final businessActivityProvider = Provider<List<ActivityEntry>>((ref) {
  final movements = ref.watch(stockMovementsProvider);
  final currentUser = ref.watch(currentUserProvider);

  final entries = <ActivityEntry>[
    for (final movement in movements)
      ActivityEntry(
        id: movement.id,
        at: movement.at,
        title: _movementTitle(movement, ref),
        detail: [movement.actor, ?movement.note].join(' · '),
        icon: movement.type.icon,
        tone: movement.type.tone,
      ),
    if (currentUser != null) ...ref.watch(staffActivityProvider(currentUser.id)),
  ]..sort((a, b) => b.at.compareTo(a.at));

  return entries;
});

String _movementTitle(StockMovement movement, Ref ref) {
  final item =
      ref.read(inventoryItemsListProvider).where((i) => i.id == movement.itemId).firstOrNull;
  final name = item?.name ?? 'an item';
  return '${movement.type.label}: $name ${movement.deltaLabel}';
}
