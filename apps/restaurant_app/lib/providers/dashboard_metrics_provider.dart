import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_durations.dart';
import '../constants/app_strings.dart';
import '../constants/app_limits.dart';
import '../models/activity_entry.dart';
import '../models/dashboard_chart_data.dart';
import '../models/inventory_item.dart';
import '../models/order.dart';
import '../models/staff_member.dart';
import '../widgets/data_page/status_badge.dart';
import 'categories_provider.dart';
import 'inventory_provider.dart';
import 'orders_provider.dart';
import 'other_expenses_provider.dart';
import 'other_incomes_provider.dart';
import 'preferences_provider.dart';
import 'production_provider.dart';
import 'roles_provider.dart';
import 'staff_provider.dart';

/// A single KPI: where it stands now, and how that compares with the period
/// before.
///
/// [change] is a fraction, or null when there is nothing to compare against —
/// a first day of trading has no trend, and rendering one as "+100%" would be
/// an invention rather than a measurement.
@immutable
class KpiValue {
  const KpiValue({required this.current, required this.previous});

  final double current;
  final double previous;

  double? get change {
    if (previous <= 0) return null;
    return (current - previous) / previous;
  }

  bool get isUp => (change ?? 0) >= 0;
}

/// Everything the dashboard renders, rolled up in one pass.
///
/// Derived from the same orders, inventory and staff the rest of the app
/// reads — the dashboard is a view over existing state, never a second source
/// of truth that can drift away from the screens it links to.
@immutable
class DashboardMetrics {
  const DashboardMetrics({
    required this.sales,
    required this.orders,
    required this.averageOrderValue,
    required this.netProfit,
    required this.staffOnShift,
    required this.staffTotal,
    required this.revenueSeries,
    required this.categoryBreakdown,
    required this.topItems,
    required this.lowStockItems,
  });

  final KpiValue sales;
  final KpiValue orders;
  final KpiValue averageOrderValue;
  final KpiValue netProfit;

  final int staffOnShift;
  final int staffTotal;

  /// Oldest to newest, one entry per day.
  final List<RevenuePoint> revenueSeries;

  /// Largest share first.
  final List<CategorySlice> categoryBreakdown;

  final List<TopItem> topItems;
  final List<InventoryItem> lowStockItems;

  bool get hasLowStock => lowStockItems.isNotEmpty;
}

/// One row of the "top selling items" list.
@immutable
class TopItem {
  const TopItem({
    required this.name,
    required this.emoji,
    required this.units,
    required this.revenue,
    required this.categoryId,
    required this.colorIndex,
  });

  final String name;
  final String emoji;
  final int units;
  final double revenue;

  /// Drives the rank badge's colour, so an item's colour matches its slice in
  /// the donut beside it: the category's position in the synced taxonomy.
  final String categoryId;
  final int colorIndex;
}

/// How many days the trend and the top-sellers list look back over.
const int _trendDays = AppLimits.trendDays;

/// A staff member counts as on shift if they have been active this recently.
/// Stands in for a real clock-in record.
const Duration _onShiftWindow = AppDurations.onShiftWindow;

final dashboardMetricsProvider = Provider<DashboardMetrics>((ref) {
  // Category slice labels are localized, so recompute them on toggle.
  ref.watch(appLanguageProvider);
  final orders = ref.watch(ordersListProvider);
  final items = ref.watch(inventoryItemsListProvider);
  final expenses = ref.watch(otherExpensesListProvider);
  final incomes = ref.watch(otherIncomesListProvider);
  final staff = ref.watch(staffMembersProvider).valueOrNull ?? const [];

  final now = DateTime.now();
  final startOfToday = DateTime(now.year, now.month, now.day);
  final startOfYesterday = startOfToday.subtract(AppDurations.singleDay);

  // ---- KPIs -------------------------------------------------------------
  // COGS comes from recipes (cost per unit × qty sold), falling back to
  // each item's own unit cost for resold goods with no formula. See
  // `utils/cogs.dart` — profit without it counts takings as profit.
  final recipes = ref.watch(recipesCatalogListProvider);
  final recipeCost = <String, double>{
    for (final r in recipes)
      if (r.sellableItemId != null)
        r.sellableItemId!: double.parse(r.costPerUnit.toString()),
  };
  final fallbackCost = <String, double>{for (final i in items) i.id: i.unitCost};
  double cogsOf(Order order) {
    var cogs = 0.0;
    for (final line in order.lines) {
      // Frozen sale-time cost first — live prices must not rewrite a
      // closed ticket's history. Falls back to live recipe/fallback costs
      // for legacy lines synced before snapshots existed.
      final snapshot = line.unitCost;
      if (snapshot != null) {
        cogs += snapshot * line.quantity;
        continue;
      }
      final unit =
          recipeCost[line.itemId] ?? fallbackCost[line.itemId] ?? 0.0;
      cogs += unit * line.quantity;
    }
    return cogs;
  }

  var salesToday = 0.0;
  var salesYesterday = 0.0;
  var cogsToday = 0.0;
  var cogsYesterday = 0.0;
  var ordersToday = 0;
  var ordersYesterday = 0;
  var otherIncomeToday = 0.0;
  var otherIncomeYesterday = 0.0;
  var otherExpensesToday = 0.0;
  var otherExpensesYesterday = 0.0;

  for (final order in orders) {
    // Deferred to the status enum, which already knows voided and refunded
    // tickets are both excluded. Restating that rule here is how a dashboard
    // ends up disagreeing with the Sales ledger.
    if (!order.status.countsAsRevenue) continue;

    if (!order.placedAt.isBefore(startOfToday)) {
      ordersToday++;
      salesToday += order.total;
      cogsToday += cogsOf(order);
    } else if (!order.placedAt.isBefore(startOfYesterday)) {
      ordersYesterday++;
      salesYesterday += order.total;
      cogsYesterday += cogsOf(order);
    }
  }

  for (final expense in expenses) {
    if (!expense.date.isBefore(startOfToday)) {
      otherExpensesToday += expense.amount;
    } else if (!expense.date.isBefore(startOfYesterday)) {
      otherExpensesYesterday += expense.amount;
    }
  }

  for (final income in incomes) {
    if (!income.date.isBefore(startOfToday)) {
      otherIncomeToday += income.amount;
    } else if (!income.date.isBefore(startOfYesterday)) {
      otherIncomeYesterday += income.amount;
    }
  }

  // ---- 7-day revenue series --------------------------------------------
  final dayTotals = <DateTime, double>{
    for (var i = _trendDays - 1; i >= 0; i--)
      startOfToday.subtract(Duration(days: i)): 0,
  };
  final windowStart = startOfToday.subtract(
    const Duration(days: _trendDays - 1),
  );

  for (final order in orders) {
    if (!order.status.countsAsRevenue) continue;
    if (order.placedAt.isBefore(windowStart)) continue;

    final day = DateTime(
      order.placedAt.year,
      order.placedAt.month,
      order.placedAt.day,
    );
    if (dayTotals.containsKey(day)) {
      dayTotals[day] = dayTotals[day]! + order.total;
    }
  }

  final revenueSeries = [
    for (final entry in dayTotals.entries)
      RevenuePoint(day: entry.key, amount: entry.value),
  ]..sort((a, b) => a.day.compareTo(b.day));

  // ---- Category breakdown + top sellers --------------------------------
  // Both walk the same lines over the same window, so the donut and the list
  // beside it are always describing the same trading period. Categories
  // resolve against the synced taxonomy and the local inventory — never a
  // bundled sample catalogue.
  final categories = ref.watch(categoriesListProvider);
  final categoryIndexById = {
    for (var i = 0; i < categories.length; i++) categories[i].id: i,
  };
  // Anything uncategorised lands after the known categories rather than
  // stealing the first one's colour.
  int colorIndexFor(String categoryId) =>
      categoryIndexById[categoryId] ?? categories.length;
  final categoryOf = {
    for (final item in items) item.id: item.categoryId,
  };
  final categoryTotals = <String, double>{};
  final unitsByItem = <String, int>{};
  final revenueByItem = <String, double>{};
  final emojiByItem = <String, String>{};
  final nameByItem = <String, String>{};

  for (final order in orders) {
    if (!order.status.countsAsRevenue) continue;
    if (order.placedAt.isBefore(windowStart)) continue;

    for (final line in order.lines) {
      final categoryId = categoryOf[line.itemId] ?? 'other';
      final lineTotal = line.unitPrice * line.quantity;

      categoryTotals[categoryId] = (categoryTotals[categoryId] ?? 0) + lineTotal;
      unitsByItem[line.itemId] = (unitsByItem[line.itemId] ?? 0) + line.quantity;
      revenueByItem[line.itemId] =
          (revenueByItem[line.itemId] ?? 0) + lineTotal;
      emojiByItem[line.itemId] = line.emoji;
      nameByItem[line.itemId] = line.name;
    }
  }

  final categoryBreakdown =
      [
        for (final entry in categoryTotals.entries)
          CategorySlice(
            label: categoryLabelFrom(categories, entry.key),
            value: entry.value,
            colorIndex: colorIndexFor(entry.key),
          ),
      ]..sort((a, b) => b.value.compareTo(a.value));

  final topItems =
      [
        for (final entry in unitsByItem.entries)
          TopItem(
            name: nameByItem[entry.key] ?? entry.key,
            emoji: emojiByItem[entry.key] ?? '🍽️',
            units: entry.value,
            revenue: revenueByItem[entry.key] ?? 0,
            categoryId: categoryOf[entry.key] ?? 'other',
            colorIndex: colorIndexFor(categoryOf[entry.key] ?? 'other'),
          ),
      ]..sort((a, b) {
        final byUnits = b.units.compareTo(a.units);
        return byUnits != 0 ? byUnits : b.revenue.compareTo(a.revenue);
      });

  // ---- Staff ------------------------------------------------------------
  var onShift = 0;
  var activeTotal = 0;
  for (final member in staff) {
    if (member.status != StaffStatus.active) continue;
    activeTotal++;

    final lastActive = member.lastActiveAt;
    if (lastActive != null && now.difference(lastActive) <= _onShiftWindow) {
      onShift++;
    }
  }

  // ---- Stock ------------------------------------------------------------
  final lowStock =
      [
        for (final item in items)
          if (item.trackStock && item.status != StockStatus.inStock) item,
      ]..sort((a, b) {
        // Out of stock before merely low.
        final byStatus = b.status.index.compareTo(a.status.index);
        return byStatus != 0 ? byStatus : a.name.compareTo(b.name);
      });

  return DashboardMetrics(
    sales: KpiValue(current: salesToday, previous: salesYesterday),
    orders: KpiValue(
      current: ordersToday.toDouble(),
      previous: ordersYesterday.toDouble(),
    ),
    averageOrderValue: KpiValue(
      current: ordersToday == 0 ? 0 : salesToday / ordersToday,
      previous: ordersYesterday == 0 ? 0 : salesYesterday / ordersYesterday,
    ),
    netProfit: KpiValue(
      current:
          salesToday + otherIncomeToday - otherExpensesToday - cogsToday,
      previous:
          salesYesterday +
          otherIncomeYesterday -
          otherExpensesYesterday -
          cogsYesterday,
    ),
    staffOnShift: onShift,
    staffTotal: activeTotal,
    revenueSeries: revenueSeries,
    categoryBreakdown: categoryBreakdown,
    topItems: topItems,
    lowStockItems: lowStock,
  );
});

/// The dashboard's activity feed.
///
/// Blends three real streams — settled tickets, stock that has fallen through
/// its threshold, and staff sessions — into one chronological list, which is
/// the shape a manager actually scans: "what happened", not three separate
/// per-domain logs.
final dashboardActivityProvider = Provider<List<ActivityEntry>>((ref) {
  // Titles/details are localized at build time, so recompute on toggle.
  // Otherwise the feed keeps serving the previous language from cache.
  ref.watch(appLanguageProvider);
  final orders = ref.watch(ordersListProvider);
  final metrics = ref.watch(dashboardMetricsProvider);
  final staff = ref.watch(staffMembersProvider).valueOrNull ?? const [];
  final roles = ref.watch(rolesProvider).valueOrNull ?? const [];

  final entries = <ActivityEntry>[];

  final recentOrders = [...orders]
    ..sort((a, b) => b.placedAt.compareTo(a.placedAt));

  for (final order in recentOrders.take(AppLimits.dashboardRecentOrders)) {
    final refunded = order.status == OrderStatus.refunded;
    entries.add(
      ActivityEntry(
        id: 'act-order-${order.id}',
        at: order.placedAt,
        title: refunded
            ? AppStrings.orderRefundedFeed(order.id)
            : AppStrings.orderPaid(order.id),
        detail: AppStrings.orderFeedDetail(
          order.itemCount,
          order.serverName,
          order.paymentType.label,
        ),
        icon: refunded
            ? Icons.undo_rounded
            : Icons.receipt_long_outlined,
        tone: refunded ? StatusTone.danger : StatusTone.positive,
      ),
    );
  }

  for (final item in metrics.lowStockItems.take(AppLimits.lowStockNamesShown)) {
    entries.add(
      ActivityEntry(
        id: 'act-stock-${item.id}',
        // Stock alerts have no event time of their own; anchoring them to the
        // last count keeps them in a sensible place in the feed.
        at: item.lastCountedAt ?? DateTime.now(),
        title: item.status == StockStatus.outOfStock
            ? AppStrings.stockOutFeed(item.name)
            : AppStrings.stockLowFeed(item.name),
        detail: AppStrings.stockRemaining(
          item.stock,
          item.reorderLevel,
          item.unit,
        ),
        icon: Icons.warning_amber_rounded,
        tone: item.status == StockStatus.outOfStock
            ? StatusTone.danger
            : StatusTone.warning,
      ),
    );
  }

  final roleName = {for (final role in roles) role.id: role.name};
  final clockedIn = [
    for (final member in staff)
      if (member.status == StaffStatus.active && member.lastActiveAt != null)
        member,
  ]..sort((a, b) => b.lastActiveAt!.compareTo(a.lastActiveAt!));

  for (final member in clockedIn.take(AppLimits.activeStaffShown)) {
    entries.add(
      ActivityEntry(
        id: 'act-staff-${member.id}',
        at: member.lastActiveAt!,
        title: AppStrings.staffClockedIn(member.name),
        detail: roleName[member.roleId] ?? AppStrings.staffFallbackRole,
        icon: Icons.login_rounded,
        tone: StatusTone.info,
      ),
    );
  }

  entries.sort((a, b) => b.at.compareTo(a.at));
  return entries;
});
