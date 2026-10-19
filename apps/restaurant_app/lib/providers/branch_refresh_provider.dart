import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ai_insights_provider.dart';
import 'couriers_provider.dart';
import 'customers_provider.dart';
import 'dashboard_metrics_provider.dart';
import 'database_providers.dart';
import 'inventory_provider.dart';
import 'orders_provider.dart';
import 'other_expenses_provider.dart';
import 'other_incomes_provider.dart';
import 'production_provider.dart';
import 'purchases_provider.dart';
import 'reports_provider.dart';
import 'roles_provider.dart';
import 'staff_provider.dart';
import 'stock_movement_provider.dart';
import 'store_api_provider_real.dart';
import 'suppliers_provider.dart';
import '../sync/sync_tick.dart';

/// Shell branch indices, in the order the tabs are declared.
///
/// These MUST stay in lockstep with [_destinations] in
/// `widgets/responsive_scaffold.dart` and the `branches` list in
/// `router/app_router.dart` — all three line up index-for-index.
abstract final class ShellBranch {
  static const dashboard = 0;
  static const pos = 1;
  static const sales = 2;
  static const customers = 3;
  static const purchasing = 4;
  static const production = 5;
  static const suppliers = 6;
  static const couriers = 7;
  static const finance = 8;
  static const reports = 9;
  static const insights = 10;
  static const groceries = 11;
  static const menuItems = 12;
  static const staff = 13;
  static const settings = 14;
}

/// The branch the shell is currently showing, as an index into [ShellBranch].
///
/// Written by `ResponsiveScaffold` on every tab switch and read by the
/// top bar's refresh button, so the button always refreshes the visible tab
/// without needing the navigation shell itself.
final currentBranchIndexProvider = StateProvider<int>((ref) => 0);

/// Re-reads whatever backs [branchIndex] and completes when it has.
///
/// Every list notifier in this app follows the same stale-while-revalidate
/// contract — `build()` returns the cached rows immediately and syncs in the
/// background — so awaiting here never blanks the screen the user is looking
/// at; the spinner only reflects real completion.
///
/// Re-reads whatever backs [branchIndex] and completes when it has.
///
/// Every list notifier in this app follows the same stale-while-revalidate
/// contract — `build()` returns the cached rows immediately and syncs in the
/// background — so awaiting here never blanks the screen the user is looking
/// at; the spinner only reflects real completion.
///
/// Never throws: nav taps and the top-bar button have no error UI, and an
/// unhandled throw in a fire-and-forget refresh crashes the app (a 401 from
/// an expired session must stay a silent empty screen, not a red screen).
/// Screens keep showing their cached data; the next tap retries.
///
/// Takes a [WidgetRef] (rather than a bare [Ref]) because the reports and
/// store refresh helpers it delegates to are typed that way.
Future<void> refreshBranch(WidgetRef ref, int branchIndex) async {
  try {
    await _refreshBranchUnchecked(ref, branchIndex);
    // The pull finished without error — stamp it, so "last synced"
    // stays fresh even on days nobody sells anything.
    await recordSyncTick(ref.read(appDatabaseProvider), SyncArea.pull);
  } catch (_) {
    // Swallowed by design — see above.
  }
}

/// The actual per-branch refresh. Must stay exception-free to callers via
/// [refreshBranch]'s guard — do not call directly from UI handlers.
Future<void> _refreshBranchUnchecked(WidgetRef ref, int branchIndex) async {
  switch (branchIndex) {
    case ShellBranch.dashboard:
      // Derived read models recompute; the invalidated sources below pull
      // fresh rows behind them.
      ref
        ..invalidate(ordersProvider)
        ..invalidate(inventoryItemsProvider)
        ..invalidate(otherExpensesProvider)
        ..invalidate(otherIncomesProvider)
        ..invalidate(stockMovementsProvider)
        ..invalidate(dashboardMetricsProvider)
        ..invalidate(dashboardActivityProvider)
        ..invalidate(aiInsightsProvider);
    case ShellBranch.pos:
      // The till menu derives from the inventory cache.
      await ref.read(inventoryItemsProvider.notifier).refresh();
    case ShellBranch.sales:
      await ref.read(ordersProvider.notifier).checkForNewOrders();
    case ShellBranch.customers:
      await ref.read(customersProvider.notifier).refresh();
    case ShellBranch.purchasing:
      await ref.read(purchasesProvider.notifier).refresh();
    case ShellBranch.production:
      await Future.wait([
        ref.read(recipesCatalogProvider.notifier).refresh(),
        ref.read(productionRunsProvider.notifier).refresh(),
        ref.read(productionHistoryProvider.notifier).refresh(),
      ]);
    case ShellBranch.suppliers:
      await ref.read(suppliersProvider.notifier).refresh();
    case ShellBranch.couriers:
      ref.invalidate(couriersProvider);
    case ShellBranch.finance:
      await Future.wait([
        ref.read(otherExpensesProvider.notifier).refresh(),
        ref.read(otherIncomesProvider.notifier).refresh(),
      ]);
    case ShellBranch.reports:
      await refreshAllReports(ref);
    case ShellBranch.insights:
      ref.invalidate(aiInsightsProvider);
    case ShellBranch.groceries:
    case ShellBranch.menuItems:
      await ref.read(inventoryItemsProvider.notifier).refresh();
    case ShellBranch.staff:
      await Future.wait([
        ref.read(staffMembersProvider.notifier).refresh(),
        ref.read(rolesProvider.notifier).refresh(),
      ]);
    case ShellBranch.settings:
      await refreshStores(ref);
    default:
      break;
  }
}

/// Fire-and-forget variant for navigation taps, where awaiting would only
/// delay a switch that is already showing cached data.
void refreshBranchInBackground(WidgetRef ref, int branchIndex) {
  unawaited(refreshBranch(ref, branchIndex));
}
