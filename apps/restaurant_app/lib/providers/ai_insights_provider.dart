import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_durations.dart';
import '../constants/app_limits.dart';
import '../constants/app_strings.dart';
import '../models/ai_insight.dart';
import '../models/inventory_item.dart';
import '../models/stock_movement.dart';
import '../router/app_router.dart';
import '../utils/formatters.dart';
import 'dashboard_provider.dart';
import 'inventory_provider.dart';
import 'preferences_provider.dart';
import 'stock_movement_provider.dart';

/// Generates the assistant's observations from the app's real state.
///
/// Nothing here is canned copy: every insight is computed from the same
/// providers the rest of the app reads, so if the stockroom changes the advice
/// changes with it. That is also what keeps the feature honest — an insight
/// can always be checked against the screen it links to.
///
/// A real build would send this context to a model and render its reply. The
/// shape of the output is the same either way, which is the point of putting
/// the derivation behind a provider.
final aiInsightsProvider = Provider<List<AiInsight>>((ref) {
  // Language is read for its side effect only: insight titles/bodies are
  // localized at build time, so the cached list must recompute on toggle.
  // Without this, widgets rebuild but keep receiving the old-language objects.
  ref.watch(appLanguageProvider);
  final items = ref.watch(inventoryItemsListProvider);
  final movements = ref.watch(stockMovementsProvider);
  final summary = ref.watch(dashboardSummaryProvider);

  final insights = <AiInsight>[
    ..._stockInsights(ref, items),
    ..._wasteInsights(items, movements),
    ..._salesInsights(summary),
  ];

  // Most urgent first; ties keep their derivation order, which groups the
  // stock items together rather than interleaving categories.
  insights.sort((a, b) => a.priority.index.compareTo(b.priority.index));
  return insights;
});

// ---------------------------------------------------------------------------
// Stock
// ---------------------------------------------------------------------------

List<AiInsight> _stockInsights(Ref ref, List<InventoryItem> items) {
  final reorder = ref.watch(reorderListProvider);
  if (reorder.isEmpty) {
    return [
      AiInsight(
        id: 'stock-healthy',
        title: AppStrings.insightStockHealthyTitle,
        body: AppStrings.insightStockHealthyBody,
        category: InsightCategory.stock,
        priority: InsightPriority.informational,
      ),
    ];
  }

  final out = reorder.where((i) => i.status == StockStatus.outOfStock).toList();
  final worst = reorder.first;

  return [
    if (out.isNotEmpty)
      AiInsight(
        id: 'stock-out',
        title: AppStrings.insightStockOutTitle(
          out.length,
          out.length == 1
              ? AppStrings.insightStockOutOne
              : AppStrings.insightStockOutMany,
        ),
        body: AppStrings.insightStockOutBody(
          out.take(AppLimits.lowStockNamesShown).map((i) => i.name).join(', '),
          out.length > AppLimits.lowStockNamesShown
              ? AppStrings.insightStockOutMore(
                  out.length - AppLimits.lowStockNamesShown)
              : '',
        ),
        category: InsightCategory.stock,
        priority: InsightPriority.urgent,
        evidence: [
          (label: AppStrings.evidenceOutOfStock, value: '${out.length}'),
          (
            label: AppStrings.evidenceValueAtRisk,
            value: Fmt.moneyCompact(
              out.fold<double>(0, (sum, i) => sum + i.reorderLevel * i.unitCost),
            ),
          ),
        ],
        actionLabel: AppStrings.actionOpenInventory,
        // Always Groceries: an out-of-stock insight is about raw materials,
        // never a till item.
        actionRoute: AppRoute.groceriesName,
      ),
    AiInsight(
      id: 'stock-reorder',
      title: AppStrings.insightReorderTitle(worst.name),
      body: AppStrings.insightReorderBody(
        Fmt.quantity(worst.stock),
        worst.unit,
        Fmt.quantity(worst.reorderLevel),
        Fmt.money((worst.reorderLevel - worst.stock).clamp(0, 1 << 30) *
            worst.unitCost),
      ),
      category: InsightCategory.stock,
      priority: worst.status == StockStatus.outOfStock
          ? InsightPriority.urgent
          : InsightPriority.advisory,
      evidence: [
        (
          label: AppStrings.evidenceOnHand,
          value: '${Fmt.quantity(worst.stock)} ${worst.unit}'
        ),
        (
          label: AppStrings.evidenceThreshold,
          value: '${Fmt.quantity(worst.reorderLevel)} ${worst.unit}'
        ),
        (label: AppStrings.evidenceUnitCost, value: Fmt.money(worst.unitCost)),
      ],
      actionLabel: AppStrings.actionViewItem,
      actionRoute: worst.itemType == 'raw_material'
          ? AppRoute.groceryDetailName
          : AppRoute.menuItemDetailName,
      actionParams: {'itemId': worst.id},
    ),
  ];
}

// ---------------------------------------------------------------------------
// Waste
// ---------------------------------------------------------------------------

List<AiInsight> _wasteInsights(
  List<InventoryItem> items,
  List<StockMovement> movements,
) {
  final since = DateTime.now().subtract(AppDurations.analyticsWindow);
  final costById = {for (final item in items) item.id: item.unitCost};
  final nameById = {for (final item in items) item.id: item.name};
  final typeById = {for (final item in items) item.id: item.itemType};

  final wastedUnits = <String, double>{};
  var totalCost = 0.0;

  for (final movement in movements) {
    if (movement.type != StockMovementType.waste) continue;
    if (movement.at.isBefore(since)) continue;

    final units = movement.delta.abs();
    wastedUnits[movement.itemId] = (wastedUnits[movement.itemId] ?? 0) + units;
    totalCost += units * (costById[movement.itemId] ?? 0);
  }

  if (wastedUnits.isEmpty) {
    return [
      AiInsight(
        id: 'waste-none',
        title: AppStrings.insightWasteNoneTitle,
        body: AppStrings.insightWasteNoneBody,
        category: InsightCategory.waste,
        priority: InsightPriority.advisory,
        evidence: [
          (label: AppStrings.evidenceWasteRecords, value: '0'),
        ],
      ),
    ];
  }

  // The line losing the most money, which is not always the one losing the
  // most units — that distinction is the whole value of the insight.
  var worstId = wastedUnits.keys.first;
  var worstCost = 0.0;
  for (final entry in wastedUnits.entries) {
    final double cost = entry.value * (costById[entry.key] ?? 0);
    if (cost > worstCost) {
      worstCost = cost;
      worstId = entry.key;
    }
  }

  return [
    AiInsight(
      id: 'waste-top',
      title: AppStrings.insightWasteTopTitle(
          nameById[worstId] ?? AppStrings.insightWasteFallbackName),
      body: AppStrings.insightWasteTopBody(
        Fmt.money(worstCost),
        Fmt.money(totalCost),
      ),
      category: InsightCategory.waste,
      priority: worstCost > totalCost * 0.4
          ? InsightPriority.advisory
          : InsightPriority.informational,
      evidence: [
        (label: AppStrings.evidenceThisLine, value: Fmt.money(worstCost)),
        (label: AppStrings.evidenceAllWaste, value: Fmt.money(totalCost)),
        (
          label: AppStrings.evidenceUnitsLost,
          value: Fmt.quantity(wastedUnits[worstId] ?? 0)
        ),
      ],
      actionLabel: AppStrings.actionViewItem,
      actionRoute: typeById[worstId] == 'sellable' || typeById[worstId] == 'both'
          ? AppRoute.menuItemDetailName
          : AppRoute.groceryDetailName,
      actionParams: {'itemId': worstId},
    ),
  ];
}

// ---------------------------------------------------------------------------
// Sales
// ---------------------------------------------------------------------------

List<AiInsight> _salesInsights(DashboardSummary summary) {
  final change = summary.takingsChange;

  return [
    if (change != null)
      AiInsight(
        id: 'sales-trend',
        title: change >= 0
            ? AppStrings.insightSalesUpTitle(Fmt.percent(change))
            : AppStrings.insightSalesDownTitle(Fmt.percent(change.abs())),
        body: change >= 0
            ? AppStrings.insightSalesUpBody(
                Fmt.money(summary.takingsToday), summary.ordersToday)
            : AppStrings.insightSalesDownBody(
                Fmt.money(summary.takingsToday), summary.ordersToday),
        category: InsightCategory.sales,
        priority: change >= 0
            ? InsightPriority.informational
            : InsightPriority.advisory,
        evidence: [
          (
            label: AppStrings.evidenceToday,
            value: Fmt.money(summary.takingsToday)
          ),
          (
            label: AppStrings.evidenceYesterday,
            value: Fmt.money(summary.takingsYesterday)
          ),
          (
            label: AppStrings.evidenceAvgTicket,
            value: Fmt.money(summary.averageTicket)
          ),
        ],
        actionLabel: AppStrings.actionOpenSales,
        actionRoute: AppRoute.salesName,
      ),
    if (summary.openOrders > 0)
      AiInsight(
        id: 'sales-open',
        title: AppStrings.insightOpenTicketsTitle(
          summary.openOrders,
          summary.openOrders == 1
              ? AppStrings.insightOpenOne
              : AppStrings.insightOpenMany,
        ),
        body: AppStrings.insightOpenTicketsBody,
        category: InsightCategory.sales,
        priority: InsightPriority.advisory,
        evidence: [
          (label: AppStrings.evidenceOpen, value: '${summary.openOrders}')
        ],
        actionLabel: AppStrings.actionOpenSales,
        actionRoute: AppRoute.salesName,
      ),
  ];
}

/// Questions the assistant offers as starting points.
///
/// Written against data the app actually holds, so none of them promise an
/// answer the insight engine above could not produce.
final suggestedPromptsProvider = Provider<List<String>>(
  (ref) {
    // Same caching trap as above: prompts are localized strings, so they
    // must recompute when the language changes.
    ref.watch(appLanguageProvider);
    return [
      AppStrings.promptReorderWeekend,
      AppStrings.promptWasteMoney,
      AppStrings.promptTodayVsYesterday,
      AppStrings.promptDeadStock,
      AppStrings.promptTopServer,
    ];
  },
);
