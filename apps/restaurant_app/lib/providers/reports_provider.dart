/// Reporting state: one shared date window, one notifier per section.
///
/// Every section reads its aggregate from the backend (POS or Inventory
/// Service) — nothing here rolls its own numbers from the local cache, so
/// the screen can never disagree with the server about what a day earned.
/// With no business context every section is empty:
/// invented takings would be worse than a blank report.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';

import '../services/inventory_api_service.dart';
import '../constants/app_durations.dart';
import '../constants/app_strings.dart';
import '../services/pos_reports_api_service.dart';
import '../utils/cogs.dart';
import 'database_providers.dart';
import 'inventory_api_provider.dart';
import 'inventory_provider.dart';
import 'permissions_provider.dart';
import 'pos_api_provider.dart';
import 'production_provider.dart';

// ---------------------------------------------------------------------------
// Shared date window
// ---------------------------------------------------------------------------

/// The window every report section reads. Null ends are open; the default
/// is the last 30 days, which is what an owner opening Reports almost
/// always wants to see first.
@immutable
class ReportsDateFilter {
  const ReportsDateFilter({this.from, this.to});

  final DateTime? from;
  final DateTime? to;

  ReportsDateFilter copyWith({DateTime? from, DateTime? to}) =>
      ReportsDateFilter(from: from ?? this.from, to: to ?? this.to);
}

DateTime _thirtyDaysAgo() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day).subtract(
    AppDurations.reportsDefaultLookback,
  );
}

class ReportsDateFilterNotifier extends Notifier<ReportsDateFilter> {
  @override
  ReportsDateFilter build() =>
      ReportsDateFilter(from: _thirtyDaysAgo(), to: null);

  void setRange(DateTime? from, DateTime? to) =>
      state = ReportsDateFilter(from: from, to: to);

  void clear() => state = ReportsDateFilter(from: _thirtyDaysAgo(), to: null);
}

final reportsDateFilterProvider =
    NotifierProvider<ReportsDateFilterNotifier, ReportsDateFilter>(
      ReportsDateFilterNotifier.new,
    );

// ---------------------------------------------------------------------------
// Sales sections (POS Service)
// ---------------------------------------------------------------------------

/// Mixin-style base is deliberately avoided — each section is a few lines,
/// and a shared abstraction would hide which service and DTO each one
/// reads. Explicit over clever.
class DailyTakingsNotifier extends AsyncNotifier<List<DailyTakingsDayDto>> {
  @override
  Future<List<DailyTakingsDayDto>> build() async {
    final businessId = ref.watch(currentBusinessIdProvider);
    final filter = ref.watch(reportsDateFilterProvider);
    if (businessId == null) return const [];
    return ref.watch(posReportsApiServiceProvider).fetchDailyTakings(
          businessId: businessId,
          from: filter.from,
          to: filter.to,
        );
  }

  Future<void> refresh() async {
    final businessId = ref.read(currentBusinessIdProvider);
    if (businessId == null) return;
    final filter = ref.read(reportsDateFilterProvider);
    state = const AsyncLoading<List<DailyTakingsDayDto>>().copyWithPrevious(
      state,
    );
    state = AsyncData(
      await ref.read(posReportsApiServiceProvider).fetchDailyTakings(
            businessId: businessId,
            from: filter.from,
            to: filter.to,
          ),
    );
  }
}

final dailyTakingsProvider =
    AsyncNotifierProvider<DailyTakingsNotifier, List<DailyTakingsDayDto>>(
      DailyTakingsNotifier.new,
    );

class ItemMixNotifier extends AsyncNotifier<List<ItemMixLineDto>> {
  @override
  Future<List<ItemMixLineDto>> build() async {
    final businessId = ref.watch(currentBusinessIdProvider);
    final filter = ref.watch(reportsDateFilterProvider);
    if (businessId == null) return const [];
    return ref.watch(posReportsApiServiceProvider).fetchItemMix(
          businessId: businessId,
          from: filter.from,
          to: filter.to,
        );
  }

  Future<void> refresh() async {
    final businessId = ref.read(currentBusinessIdProvider);
    if (businessId == null) return;
    final filter = ref.read(reportsDateFilterProvider);
    state = const AsyncLoading<List<ItemMixLineDto>>().copyWithPrevious(state);
    state = AsyncData(
      await ref.read(posReportsApiServiceProvider).fetchItemMix(
            businessId: businessId,
            from: filter.from,
            to: filter.to,
          ),
    );
  }
}

final itemMixProvider =
    AsyncNotifierProvider<ItemMixNotifier, List<ItemMixLineDto>>(
      ItemMixNotifier.new,
    );

// ---------------------------------------------------------------------------
// Snapshot COGS (frozen sale-time costs)
// ---------------------------------------------------------------------------

/// Frozen sale-time production costs for the current report window.
///
/// Sums cached sale lines of completed sales in the window: each line's
/// snapshot when present, otherwise the live recipe/fallback cost for its
/// item (legacy rows synced before snapshots existed) — same fallback
/// semantics as `CogsIndex`, so a window mixing both reads exact where
/// frozen, estimated where derived. New sales always carry a snapshot
/// (zero when unknown), so the fallback only fires for legacy rows.
/// `covered` is false when the cache holds no usable lines in the window
/// (nothing synced yet) — the caller then falls back to live costs over
/// item-mix rather than reporting zero. `frozenLines` / `fallbackLines`
/// expose the unsnapshotted tail so owners can see how soft the number is.
@immutable
class SnapshotCogs {
  const SnapshotCogs({
    required this.cogs,
    required this.estimated,
    required this.covered,
    this.frozenLines = 0,
    this.fallbackLines = 0,
  });

  final Decimal cogs;
  final bool estimated;
  final bool covered;
  final int frozenLines;
  final int fallbackLines;

  static final uncovered = SnapshotCogs(
    cogs: Decimal.zero,
    estimated: false,
    covered: false,
  );
}

final snapshotCogsProvider = FutureProvider<SnapshotCogs>((ref) async {
  final businessId = ref.watch(currentBusinessIdProvider);
  final filter = ref.watch(reportsDateFilterProvider);
  if (businessId == null) return SnapshotCogs.uncovered;

  final db = ref.watch(appDatabaseProvider);
  final sales =
      await (db.select(db.cachedSales)
            ..where((s) {
              var expr = s.businessId.equals(businessId) &
                  s.status.equals('completed');
              if (filter.from != null) {
                expr =
                    expr &
                    s.occurredAt.isBiggerOrEqualValue(filter.from!);
              }
              if (filter.to != null) {
                expr =
                    expr & s.occurredAt.isSmallerOrEqualValue(filter.to!);
              }
              return expr;
            }))
          .get();
  if (sales.isEmpty) return SnapshotCogs.uncovered;

  final lines =
      await (db.select(db.cachedSaleLineItems)..where(
            (l) => l.saleId.isIn(sales.map((s) => s.id)),
          ))
          .get();
  // Sales cached with no lines (a line pull that never completed) carry
  // no cost information at all — live costs over item-mix stay closer to
  // the truth than a partial snapshot sum.
  if (lines.isEmpty) return SnapshotCogs.uncovered;

  final recipes = ref.watch(recipesCatalogListProvider);
  final items = ref.watch(inventoryItemsListProvider);
  final index = CogsIndex(
    recipeCost: {
      for (final r in recipes)
        if (r.sellableItemId != null)
          r.sellableItemId!: r.costPerUnit,
    },
    recipeComplete: {
      for (final r in recipes)
        if (r.sellableItemId != null)
          r.sellableItemId!: r.costComplete,
    },
    fallbackCost: {
      for (final i in items)
        if (i.catalogItemId != null)
          i.catalogItemId!: Decimal.parse(i.unitCost.toString()),
    },
  );

  var cogs = Decimal.zero;
  var estimated = false;
  var frozenLines = 0;
  var fallbackLines = 0;
  for (final line in lines) {
    final snap = line.unitCost;
    if (snap != null) {
      cogs += snap * line.quantity;
      frozenLines++;
      if (snap == Decimal.zero && line.quantity != Decimal.zero) {
        estimated = true;
      }
    } else {
      fallbackLines++;
      final unit = index.unitCostFor(line.itemId);
      if (unit.cost != Decimal.zero) {
        cogs += unit.cost * line.quantity;
      } else if (line.quantity != Decimal.zero) {
        estimated = true;
      }
      if (unit.estimated) estimated = true;
    }
  }
  return SnapshotCogs(
    cogs: cogs,
    estimated: estimated,
    covered: true,
    frozenLines: frozenLines,
    fallbackLines: fallbackLines,
  );
});

/// An item-mix line with its catalog name resolved. The backend returns ids
/// (Inventory Service owns names); this join is display-only — the numbers
/// stay exactly what the server reported.
@immutable
class ResolvedItemMixLine {
  const ResolvedItemMixLine({required this.line, required this.name});

  final ItemMixLineDto line;
  final String name;
}

final resolvedItemMixProvider = Provider<List<ResolvedItemMixLine>>((ref) {
  final lines = ref.watch(itemMixProvider).valueOrNull ?? const [];
  final items = ref.watch(inventoryItemsListProvider);
  final nameByCatalogId = {
    for (final item in items)
      if (item.catalogItemId != null) item.catalogItemId!: item.name,
  };
  return [
    for (final line in lines)
      ResolvedItemMixLine(
        line: line,
        name: nameByCatalogId[line.itemId] ?? AppStrings.unknownItem,
      ),
  ];
});

class StaffPerformanceNotifier
    extends AsyncNotifier<List<StaffPerformanceLineDto>> {
  @override
  Future<List<StaffPerformanceLineDto>> build() async {
    final businessId = ref.watch(currentBusinessIdProvider);
    final filter = ref.watch(reportsDateFilterProvider);
    if (businessId == null) return const [];
    return ref.watch(posReportsApiServiceProvider).fetchStaffPerformance(
          businessId: businessId,
          from: filter.from,
          to: filter.to,
        );
  }

  Future<void> refresh() async {
    final businessId = ref.read(currentBusinessIdProvider);
    if (businessId == null) return;
    final filter = ref.read(reportsDateFilterProvider);
    state = const AsyncLoading<List<StaffPerformanceLineDto>>().copyWithPrevious(
      state,
    );
    state = AsyncData(
      await ref.read(posReportsApiServiceProvider).fetchStaffPerformance(
            businessId: businessId,
            from: filter.from,
            to: filter.to,
          ),
    );
  }
}

final staffPerformanceProvider =
    AsyncNotifierProvider<StaffPerformanceNotifier, List<StaffPerformanceLineDto>>(
      StaffPerformanceNotifier.new,
    );

class FinanceSummaryNotifier extends AsyncNotifier<FinanceSummaryDto?> {
  @override
  Future<FinanceSummaryDto?> build() async {
    final businessId = ref.watch(currentBusinessIdProvider);
    final filter = ref.watch(reportsDateFilterProvider);
    if (businessId == null) return null;
    return ref.watch(posReportsApiServiceProvider).fetchFinanceSummary(
          businessId: businessId,
          from: filter.from,
          to: filter.to,
        );
  }

  Future<void> refresh() async {
    final businessId = ref.read(currentBusinessIdProvider);
    if (businessId == null) return;
    final filter = ref.read(reportsDateFilterProvider);
    state = const AsyncLoading<FinanceSummaryDto?>().copyWithPrevious(state);
    state = AsyncData(
      await ref.read(posReportsApiServiceProvider).fetchFinanceSummary(
            businessId: businessId,
            from: filter.from,
            to: filter.to,
          ),
    );
  }
}

final financeSummaryProvider =
    AsyncNotifierProvider<FinanceSummaryNotifier, FinanceSummaryDto?>(
      FinanceSummaryNotifier.new,
    );

// ---------------------------------------------------------------------------
// Inventory sections (Inventory Service)
// ---------------------------------------------------------------------------

class WasteSummaryNotifier extends AsyncNotifier<WasteSummaryDto?> {
  @override
  Future<WasteSummaryDto?> build() async {
    final businessId = ref.watch(currentBusinessIdProvider);
    final filter = ref.watch(reportsDateFilterProvider);
    if (businessId == null) return null;
    return ref.watch(inventoryApiServiceProvider).fetchWasteSummary(
          businessId: businessId,
          from: filter.from,
          to: filter.to,
        );
  }

  Future<void> refresh() async {
    final businessId = ref.read(currentBusinessIdProvider);
    if (businessId == null) return;
    final filter = ref.read(reportsDateFilterProvider);
    state = const AsyncLoading<WasteSummaryDto?>().copyWithPrevious(state);
    state = AsyncData(
      await ref.read(inventoryApiServiceProvider).fetchWasteSummary(
            businessId: businessId,
            from: filter.from,
            to: filter.to,
          ),
    );
  }
}

final wasteSummaryProvider =
    AsyncNotifierProvider<WasteSummaryNotifier, WasteSummaryDto?>(
      WasteSummaryNotifier.new,
    );

class ProductionSummaryNotifier extends AsyncNotifier<ProductionSummaryDto?> {
  @override
  Future<ProductionSummaryDto?> build() async {
    final businessId = ref.watch(currentBusinessIdProvider);
    final filter = ref.watch(reportsDateFilterProvider);
    if (businessId == null) return null;
    return ref.watch(inventoryApiServiceProvider).fetchProductionSummary(
          businessId: businessId,
          from: filter.from,
          to: filter.to,
        );
  }

  Future<void> refresh() async {
    final businessId = ref.read(currentBusinessIdProvider);
    if (businessId == null) return;
    final filter = ref.read(reportsDateFilterProvider);
    state = const AsyncLoading<ProductionSummaryDto?>().copyWithPrevious(state);
    state = AsyncData(
      await ref.read(inventoryApiServiceProvider).fetchProductionSummary(
            businessId: businessId,
            from: filter.from,
            to: filter.to,
          ),
    );
  }
}

final productionSummaryProvider =
    AsyncNotifierProvider<ProductionSummaryNotifier, ProductionSummaryDto?>(
      ProductionSummaryNotifier.new,
    );

class StockValuationNotifier extends AsyncNotifier<StockValuationDto?> {
  @override
  Future<StockValuationDto?> build() async {
    final businessId = ref.watch(currentBusinessIdProvider);
    // A snapshot — the date window deliberately does not apply.
    if (businessId == null) return null;
    return ref.watch(inventoryApiServiceProvider).fetchStockValuation(
          businessId: businessId,
        );
  }

  Future<void> refresh() async {
    final businessId = ref.read(currentBusinessIdProvider);
    if (businessId == null) return;
    state = const AsyncLoading<StockValuationDto?>().copyWithPrevious(state);
    state = AsyncData(
      await ref.read(inventoryApiServiceProvider).fetchStockValuation(
            businessId: businessId,
          ),
    );
  }
}

final stockValuationProvider =
    AsyncNotifierProvider<StockValuationNotifier, StockValuationDto?>(
      StockValuationNotifier.new,
    );

class SellPaymentsNotifier extends AsyncNotifier<List<SellPaymentLineDto>> {
  @override
  Future<List<SellPaymentLineDto>> build() async {
    final businessId = ref.watch(currentBusinessIdProvider);
    final filter = ref.watch(reportsDateFilterProvider);
    if (businessId == null) return const [];
    return ref.watch(posReportsApiServiceProvider).fetchSellPayments(
          businessId: businessId,
          from: filter.from,
          to: filter.to,
        );
  }

  Future<void> refresh() async {
    final businessId = ref.read(currentBusinessIdProvider);
    if (businessId == null) return;
    final filter = ref.read(reportsDateFilterProvider);
    state = const AsyncLoading<List<SellPaymentLineDto>>().copyWithPrevious(state);
    state = AsyncData(
      await ref.read(posReportsApiServiceProvider).fetchSellPayments(
            businessId: businessId,
            from: filter.from,
            to: filter.to,
          ),
    );
  }
}

final sellPaymentsProvider =
    AsyncNotifierProvider<SellPaymentsNotifier, List<SellPaymentLineDto>>(
      SellPaymentsNotifier.new,
    );

class TaxReportNotifier extends AsyncNotifier<List<TaxDayDto>> {
  @override
  Future<List<TaxDayDto>> build() async {
    final businessId = ref.watch(currentBusinessIdProvider);
    final filter = ref.watch(reportsDateFilterProvider);
    if (businessId == null) return const [];
    return ref.watch(posReportsApiServiceProvider).fetchTaxReport(
          businessId: businessId,
          from: filter.from,
          to: filter.to,
        );
  }

  Future<void> refresh() async {
    final businessId = ref.read(currentBusinessIdProvider);
    if (businessId == null) return;
    final filter = ref.read(reportsDateFilterProvider);
    state = const AsyncLoading<List<TaxDayDto>>().copyWithPrevious(state);
    state = AsyncData(
      await ref.read(posReportsApiServiceProvider).fetchTaxReport(
            businessId: businessId,
            from: filter.from,
            to: filter.to,
          ),
    );
  }
}

final taxReportProvider =
    AsyncNotifierProvider<TaxReportNotifier, List<TaxDayDto>>(
      TaxReportNotifier.new,
    );

class ProfitLossNotifier extends AsyncNotifier<ProfitLossDto?> {
  @override
  Future<ProfitLossDto?> build() async {
    final businessId = ref.watch(currentBusinessIdProvider);
    final filter = ref.watch(reportsDateFilterProvider);
    if (businessId == null) return null;
    return ref.watch(posReportsApiServiceProvider).fetchProfitLoss(
          businessId: businessId,
          from: filter.from,
          to: filter.to,
        );
  }

  Future<void> refresh() async {
    final businessId = ref.read(currentBusinessIdProvider);
    if (businessId == null) return;
    final filter = ref.read(reportsDateFilterProvider);
    state = const AsyncLoading<ProfitLossDto?>().copyWithPrevious(state);
    state = AsyncData(
      await ref.read(posReportsApiServiceProvider).fetchProfitLoss(
            businessId: businessId,
            from: filter.from,
            to: filter.to,
          ),
    );
  }
}

final profitLossProvider =
    AsyncNotifierProvider<ProfitLossNotifier, ProfitLossDto?>(
      ProfitLossNotifier.new,
    );

class TrendingProductsNotifier extends AsyncNotifier<List<ItemMixLineDto>> {
  @override
  Future<List<ItemMixLineDto>> build() async {
    final businessId = ref.watch(currentBusinessIdProvider);
    final filter = ref.watch(reportsDateFilterProvider);
    if (businessId == null) return const [];
    return ref.watch(posReportsApiServiceProvider).fetchItemMixOrdered(
          businessId: businessId,
          from: filter.from,
          to: filter.to,
          orderBy: 'quantity',
        );
  }

  Future<void> refresh() async {
    final businessId = ref.read(currentBusinessIdProvider);
    if (businessId == null) return;
    final filter = ref.read(reportsDateFilterProvider);
    state = const AsyncLoading<List<ItemMixLineDto>>().copyWithPrevious(state);
    state = AsyncData(
      await ref.read(posReportsApiServiceProvider).fetchItemMixOrdered(
            businessId: businessId,
            from: filter.from,
            to: filter.to,
            orderBy: 'quantity',
          ),
    );
  }
}

final trendingProductsProvider =
    AsyncNotifierProvider<TrendingProductsNotifier, List<ItemMixLineDto>>(
      TrendingProductsNotifier.new,
    );

class CustomerGroupsNotifier
    extends AsyncNotifier<List<CustomerGroupLineDto>> {
  @override
  Future<List<CustomerGroupLineDto>> build() async {
    final businessId = ref.watch(currentBusinessIdProvider);
    final filter = ref.watch(reportsDateFilterProvider);
    if (businessId == null) return const [];
    return ref.watch(posReportsApiServiceProvider).fetchCustomerGroups(
          businessId: businessId,
          from: filter.from,
          to: filter.to,
        );
  }

  Future<void> refresh() async {
    final businessId = ref.read(currentBusinessIdProvider);
    if (businessId == null) return;
    final filter = ref.read(reportsDateFilterProvider);
    state =
        const AsyncLoading<List<CustomerGroupLineDto>>().copyWithPrevious(state);
    state = AsyncData(
      await ref.read(posReportsApiServiceProvider).fetchCustomerGroups(
            businessId: businessId,
            from: filter.from,
            to: filter.to,
          ),
    );
  }
}

final customerGroupsProvider =
    AsyncNotifierProvider<CustomerGroupsNotifier, List<CustomerGroupLineDto>>(
      CustomerGroupsNotifier.new,
    );

class CustomerSpendNotifier
    extends AsyncNotifier<List<CustomerSpendLineDto>> {
  @override
  Future<List<CustomerSpendLineDto>> build() async {
    final businessId = ref.watch(currentBusinessIdProvider);
    final filter = ref.watch(reportsDateFilterProvider);
    if (businessId == null) return const [];
    return ref.watch(posReportsApiServiceProvider).fetchCustomerSpend(
          businessId: businessId,
          from: filter.from,
          to: filter.to,
        );
  }

  Future<void> refresh() async {
    final businessId = ref.read(currentBusinessIdProvider);
    if (businessId == null) return;
    final filter = ref.read(reportsDateFilterProvider);
    state =
        const AsyncLoading<List<CustomerSpendLineDto>>().copyWithPrevious(state);
    state = AsyncData(
      await ref.read(posReportsApiServiceProvider).fetchCustomerSpend(
            businessId: businessId,
            from: filter.from,
            to: filter.to,
          ),
    );
  }
}

final customerSpendProvider =
    AsyncNotifierProvider<CustomerSpendNotifier, List<CustomerSpendLineDto>>(
      CustomerSpendNotifier.new,
    );

/// Inventory-side list reports share one shape: build + refresh against
/// [InventoryApiService]. One notifier per report keeps the provider graph
/// explicit (which endpoint backs which drawer entry).
class ProductPurchasesNotifier
    extends AsyncNotifier<List<ProductPurchaseLineDto>> {
  @override
  Future<List<ProductPurchaseLineDto>> build() async {
    final businessId = ref.watch(currentBusinessIdProvider);
    final filter = ref.watch(reportsDateFilterProvider);
    if (businessId == null) return const [];
    return ref.watch(inventoryApiServiceProvider).fetchProductPurchases(
          businessId: businessId,
          from: filter.from,
          to: filter.to,
        );
  }

  Future<void> refresh() async {
    final businessId = ref.read(currentBusinessIdProvider);
    if (businessId == null) return;
    final filter = ref.read(reportsDateFilterProvider);
    state =
        const AsyncLoading<List<ProductPurchaseLineDto>>().copyWithPrevious(state);
    state = AsyncData(
      await ref.read(inventoryApiServiceProvider).fetchProductPurchases(
            businessId: businessId,
            from: filter.from,
            to: filter.to,
          ),
    );
  }
}

final productPurchasesProvider = AsyncNotifierProvider<
    ProductPurchasesNotifier, List<ProductPurchaseLineDto>>(
  ProductPurchasesNotifier.new,
);

class StockAdjustmentsNotifier
    extends AsyncNotifier<List<StockAdjustmentLineDto>> {
  @override
  Future<List<StockAdjustmentLineDto>> build() async {
    final businessId = ref.watch(currentBusinessIdProvider);
    final filter = ref.watch(reportsDateFilterProvider);
    if (businessId == null) return const [];
    return ref.watch(inventoryApiServiceProvider).fetchStockAdjustments(
          businessId: businessId,
          from: filter.from,
          to: filter.to,
        );
  }

  Future<void> refresh() async {
    final businessId = ref.read(currentBusinessIdProvider);
    if (businessId == null) return;
    final filter = ref.read(reportsDateFilterProvider);
    state = const AsyncLoading<List<StockAdjustmentLineDto>>()
        .copyWithPrevious(state);
    state = AsyncData(
      await ref.read(inventoryApiServiceProvider).fetchStockAdjustments(
            businessId: businessId,
            from: filter.from,
            to: filter.to,
          ),
    );
  }
}

final stockAdjustmentsProvider = AsyncNotifierProvider<
    StockAdjustmentsNotifier, List<StockAdjustmentLineDto>>(
  StockAdjustmentsNotifier.new,
);

class LotReportNotifier extends AsyncNotifier<List<LotLineDto>> {
  @override
  Future<List<LotLineDto>> build() async {
    final businessId = ref.watch(currentBusinessIdProvider);
    final filter = ref.watch(reportsDateFilterProvider);
    if (businessId == null) return const [];
    return ref.watch(inventoryApiServiceProvider).fetchLotReport(
          businessId: businessId,
          from: filter.from,
          to: filter.to,
        );
  }

  Future<void> refresh() async {
    final businessId = ref.read(currentBusinessIdProvider);
    if (businessId == null) return;
    final filter = ref.read(reportsDateFilterProvider);
    state = const AsyncLoading<List<LotLineDto>>().copyWithPrevious(state);
    state = AsyncData(
      await ref.read(inventoryApiServiceProvider).fetchLotReport(
            businessId: businessId,
            from: filter.from,
            to: filter.to,
          ),
    );
  }
}

final lotReportProvider =
    AsyncNotifierProvider<LotReportNotifier, List<LotLineDto>>(
      LotReportNotifier.new,
    );

class ExpiryReportNotifier extends AsyncNotifier<List<LotLineDto>> {
  @override
  Future<List<LotLineDto>> build() async {
    final businessId = ref.watch(currentBusinessIdProvider);
    final filter = ref.watch(reportsDateFilterProvider);
    if (businessId == null) return const [];
    return ref.watch(inventoryApiServiceProvider).fetchExpiryReport(
          businessId: businessId,
          from: filter.from,
          to: filter.to,
        );
  }

  Future<void> refresh() async {
    final businessId = ref.read(currentBusinessIdProvider);
    if (businessId == null) return;
    final filter = ref.read(reportsDateFilterProvider);
    state = const AsyncLoading<List<LotLineDto>>().copyWithPrevious(state);
    state = AsyncData(
      await ref.read(inventoryApiServiceProvider).fetchExpiryReport(
            businessId: businessId,
            from: filter.from,
            to: filter.to,
          ),
    );
  }
}

final expiryReportProvider =
    AsyncNotifierProvider<ExpiryReportNotifier, List<LotLineDto>>(
      ExpiryReportNotifier.new,
    );

class SupplierPurchasesNotifier
    extends AsyncNotifier<List<SupplierPurchaseLineDto>> {
  @override
  Future<List<SupplierPurchaseLineDto>> build() async {
    final businessId = ref.watch(currentBusinessIdProvider);
    final filter = ref.watch(reportsDateFilterProvider);
    if (businessId == null) return const [];
    return ref.watch(inventoryApiServiceProvider).fetchSupplierPurchases(
          businessId: businessId,
          from: filter.from,
          to: filter.to,
        );
  }

  Future<void> refresh() async {
    final businessId = ref.read(currentBusinessIdProvider);
    if (businessId == null) return;
    final filter = ref.read(reportsDateFilterProvider);
    state = const AsyncLoading<List<SupplierPurchaseLineDto>>()
        .copyWithPrevious(state);
    state = AsyncData(
      await ref.read(inventoryApiServiceProvider).fetchSupplierPurchases(
            businessId: businessId,
            from: filter.from,
            to: filter.to,
          ),
    );
  }
}

final supplierPurchasesProvider = AsyncNotifierProvider<
    SupplierPurchasesNotifier, List<SupplierPurchaseLineDto>>(
  SupplierPurchasesNotifier.new,
);

class ActivityLogNotifier extends AsyncNotifier<List<ActivityLogLineDto>> {
  @override
  Future<List<ActivityLogLineDto>> build() async {
    final businessId = ref.watch(currentBusinessIdProvider);
    final filter = ref.watch(reportsDateFilterProvider);
    if (businessId == null) return const [];
    return ref.watch(inventoryApiServiceProvider).fetchActivityLog(
          businessId: businessId,
          from: filter.from,
          to: filter.to,
        );
  }

  Future<void> refresh() async {
    final businessId = ref.read(currentBusinessIdProvider);
    if (businessId == null) return;
    final filter = ref.read(reportsDateFilterProvider);
    state =
        const AsyncLoading<List<ActivityLogLineDto>>().copyWithPrevious(state);
    state = AsyncData(
      await ref.read(inventoryApiServiceProvider).fetchActivityLog(
            businessId: businessId,
            from: filter.from,
            to: filter.to,
          ),
    );
  }
}

final activityLogProvider =
    AsyncNotifierProvider<ActivityLogNotifier, List<ActivityLogLineDto>>(
      ActivityLogNotifier.new,
    );

/// Re-reads every section — pull-to-refresh on the Reports screen.
Future<void> refreshAllReports(WidgetRef ref) async {
  await Future.wait([
    ref.read(dailyTakingsProvider.notifier).refresh(),
    ref.read(itemMixProvider.notifier).refresh(),
    ref.read(staffPerformanceProvider.notifier).refresh(),
    ref.read(financeSummaryProvider.notifier).refresh(),
    ref.read(wasteSummaryProvider.notifier).refresh(),
    ref.read(productionSummaryProvider.notifier).refresh(),
    ref.read(stockValuationProvider.notifier).refresh(),
    ref.read(sellPaymentsProvider.notifier).refresh(),
    ref.read(taxReportProvider.notifier).refresh(),
    ref.read(profitLossProvider.notifier).refresh(),
    ref.read(trendingProductsProvider.notifier).refresh(),
    ref.read(customerGroupsProvider.notifier).refresh(),
    ref.read(customerSpendProvider.notifier).refresh(),
    ref.read(productPurchasesProvider.notifier).refresh(),
    ref.read(stockAdjustmentsProvider.notifier).refresh(),
    ref.read(lotReportProvider.notifier).refresh(),
    ref.read(expiryReportProvider.notifier).refresh(),
    ref.read(supplierPurchasesProvider.notifier).refresh(),
    ref.read(activityLogProvider.notifier).refresh(),
  ]);
}
