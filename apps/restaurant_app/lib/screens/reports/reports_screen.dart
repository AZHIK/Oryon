import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../constants/app_durations.dart';
import '../../router/app_router.dart';
import 'report_registry.dart';
import '../../constants/app_strings.dart';
import '../../models/inventory_item.dart';
import '../../models/permission.dart';
import '../../constants/app_limits.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/permissions_provider.dart';
import '../../providers/production_provider.dart';
import '../../providers/reports_provider.dart';
import '../../services/inventory_api_service.dart';
import '../../services/pos_reports_api_service.dart';
import '../../utils/cogs.dart';
import '../../theme/app_theme.dart';
import '../../theme/breakpoints.dart';
import '../../utils/formatters.dart';
import '../../widgets/data_page/data_column_spec.dart';
import '../../widgets/data_page/export_actions.dart';
import '../../widgets/data_page/summary_metric_card.dart';

/// Opens the shared date-window picker and refreshes the open report.
///
/// The window lives in [reportsDateFilterProvider], so every report —
/// menu or detail — reads the same period. Public so the detail screen
/// shares the exact behaviour (and never drifts from it).
Future<void> pickReportsRange(BuildContext context, WidgetRef ref) async {
  final current = ref.read(reportsDateFilterProvider);
  final picked = await showDateRangePicker(
    context: context,
    firstDate: DateTime(2020),
    lastDate: DateTime.now().add(AppDurations.singleDay),
    initialDateRange: current.from == null && current.to == null
        ? null
        : DateTimeRange(
            start:
                current.from ??
                DateTime.now().subtract(AppDurations.analyticsWindow),
            end: current.to ?? DateTime.now(),
          ),
  );
  if (picked == null) return;
  ref
      .read(reportsDateFilterProvider.notifier)
      .setRange(picked.start, picked.end);
  await refreshAllReports(ref);
}

/// The calendar action shared by the menu and detail app bars.
class ReportsDateAction extends ConsumerWidget {
  const ReportsDateAction({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(reportsDateFilterProvider);
    return IconButton(
      tooltip: AppStrings.filterByDate,
      onPressed: () => pickReportsRange(context, ref),
      icon: Badge(
        isLabelVisible: filter.from != null || filter.to != null,
        child: const Icon(Icons.calendar_month_outlined),
      ),
    );
  }
}

/// The active-window bar. Renders nothing when the window is fully open.
///
/// A full-width card — never a single-line chip — so the whole range is
/// always visible: no truncation, no ellipsis, year included.
class ReportsDateChip extends ConsumerWidget {
  const ReportsDateChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(reportsDateFilterProvider);
    if (filter.from == null && filter.to == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.md),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Insets.md,
            vertical: Insets.sm,
          ),
          child: Row(
            children: [
              Icon(
                Icons.calendar_month_outlined,
                size: 20,
                color: context.colors.onSurfaceVariant,
              ),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.filterByDate,
                      style: context.text.labelSmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      _periodLabel(filter.from, filter.to),
                      softWrap: true,
                      style: context.text.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
                iconSize: 20,
                onPressed: () async {
                  ref.read(reportsDateFilterProvider.notifier).clear();
                  await refreshAllReports(ref);
                },
                icon: const Icon(Icons.clear_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Business reports menu.
///
/// Lists every report; tapping one opens its detail screen, which reads
/// live server-side aggregates for the shared date window and offers the
/// usual PDF/Excel export. The menu itself fetches nothing — numbers load
/// only when a report is opened, so landing here is always instant.
class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.reportsTitle),
        elevation: 0,
        actions: const [ReportsDateAction()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(Insets.lg),
        children: [
          const ReportsDateChip(),
          for (final report in allReports)
            Card(
              margin: const EdgeInsets.only(bottom: Insets.sm),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(Insets.sm),
                  decoration: BoxDecoration(
                    color: context.colors.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    report.icon,
                    color: context.colors.onPrimaryContainer,
                  ),
                ),
                title: Text(report.title),
                subtitle: Text(report.subtitle),
                trailing: const Icon(Icons.chevron_right_outlined),
                onTap: () => context.push(AppRoute.reportDetail(report.id)),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared section chrome
// ---------------------------------------------------------------------------

/// A report section: title, optional export buttons, and its body.
///
/// Export buttons appear only for `reports.export` holders; everyone else
/// still reads the numbers. Columns drive the exporters, so the file says
/// what the screen said.
class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.columns,
    required this.rows,
    required this.exportTitle,
    required this.body,
  });

  final String title;
  final List<DataColumnSpec<dynamic>> columns;
  final List<dynamic> rows;
  final String exportTitle;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: context.text.titleMedium)),
              if (ref.watch(
                hasPermissionProvider(AppPermissions.reportsExport),
              ))
                ...dataPageExportActions<dynamic>(
                  context: context,
                  columns: columns,
                  rows: rows,
                  title: exportTitle,
                  subtitle: title,
                ),
            ],
          ),
          const SizedBox(height: Insets.md),
          body,
        ],
      ),
    );
  }
}

double _d(Decimal value) => double.parse(value.toString());

String _money(Decimal value) => Fmt.money(_d(value));

// ---------------------------------------------------------------------------
// Takings
// ---------------------------------------------------------------------------

final _takingsColumns = <DataColumnSpec<DailyTakingsDayDto>>[
  DataColumnSpec(
    label: AppStrings.dateColumn,
    field: 'date',
    value: (r) => r.date.toIso8601String().substring(0, 10),
  ),
  DataColumnSpec(
    label: AppStrings.revenueColumn,
    field: 'revenue',
    numeric: true,
    value: (r) => _money(r.revenue),
  ),
  DataColumnSpec(
    label: AppStrings.ordersColumn,
    field: 'count',
    numeric: true,
    value: (r) => '${r.salesCount}',
  ),
  DataColumnSpec(
    label: AppStrings.avgTicketColumn,
    field: 'avg',
    numeric: true,
    value: (r) => _money(r.avgTicket),
  ),
];

class TakingsSection extends ConsumerWidget {
  const TakingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = ref.watch(dailyTakingsProvider).valueOrNull ?? const [];
    var revenue = 0.0;
    var orders = 0;
    for (final day in days) {
      revenue += _d(day.revenue);
      orders += day.salesCount;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: SummaryMetricCard(
                label: AppStrings.revenueMetric,
                value: Fmt.money(revenue),
                trend: AppStrings.ordersTrend(orders),
                icon: Icons.payments_outlined,
                accent: context.semantic.success,
              ),
            ),
            const SizedBox(width: Insets.md),
            Expanded(
              child: SummaryMetricCard(
                label: AppStrings.avgTicketMetric,
                value: Fmt.money(orders == 0 ? 0 : revenue / orders),
                trend: AppStrings.perOrderTrend,
                icon: Icons.receipt_long_outlined,
                accent: context.colors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: Insets.md),
        _Section(
          title: AppStrings.dailyTakingsSection,
          columns: _takingsColumns,
          rows: days,
          exportTitle: AppStrings.dailyTakingsSection,
          body: days.isEmpty
              ? _EmptySection(hint: AppStrings.noSalesInWindow)
              : Column(
                  children: [
                    for (final day in days)
                      _KeyValueRow(
                        label: Fmt.dayMonth(day.date),
                        value: AppStrings.takingsRow(
                          _money(day.revenue),
                          day.salesCount,
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Item mix
// ---------------------------------------------------------------------------

final _itemMixColumns = <DataColumnSpec<ResolvedItemMixLine>>[
  DataColumnSpec(
    label: AppStrings.itemColumn,
    field: 'name',
    value: (r) => r.name,
  ),
  DataColumnSpec(
    label: AppStrings.qtyColumn,
    field: 'qty',
    numeric: true,
    value: (r) => '${_d(r.line.quantity)}',
  ),
  DataColumnSpec(
    label: AppStrings.revenueColumn,
    field: 'revenue',
    numeric: true,
    value: (r) => _money(r.line.revenue),
  ),
];

class ItemMixSection extends ConsumerWidget {
  const ItemMixSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lines = ref.watch(resolvedItemMixProvider);

    return _Section(
      // Exact drawer name: Product Sell Report (backed by item-mix).
      title: 'Product Sell Report',
      columns: _itemMixColumns,
      rows: lines,
      exportTitle: AppStrings.itemMixSection,
      body: lines.isEmpty
          ? _EmptySection(hint: AppStrings.nothingSold)
          : Column(
              children: [
                for (final line in lines)
                  _KeyValueRow(
                    label: line.name,
                    value: AppStrings.itemMixRow(
                      Fmt.quantity(_d(line.line.quantity)),
                      _money(line.line.revenue),
                    ),
                  ),
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Staff
// ---------------------------------------------------------------------------

final _staffColumns = <DataColumnSpec<StaffPerformanceLineDto>>[
  DataColumnSpec(
    label: AppStrings.staffColumn,
    field: 'actor',
    value: (r) => r.actorId == null ? AppStrings.unknown : _shortId(r.actorId!),
  ),
  DataColumnSpec(
    label: AppStrings.salesColumn,
    field: 'count',
    numeric: true,
    value: (r) => '${r.salesCount}',
  ),
  DataColumnSpec(
    label: AppStrings.revenueColumn,
    field: 'revenue',
    numeric: true,
    value: (r) => _money(r.revenue),
  ),
  DataColumnSpec(
    label: AppStrings.voidRefundColumn,
    field: 'reversals',
    numeric: true,
    value: (r) => '${r.voidedCount + r.refundedCount}',
  ),
];

class StaffSection extends ConsumerWidget {
  const StaffSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lines = ref.watch(staffPerformanceProvider).valueOrNull ?? const [];

    return _Section(
      // Exact drawer name: Service Staff Report (staff-performance leg).
      title: 'Service Staff Report',
      columns: _staffColumns,
      rows: lines,
      exportTitle: AppStrings.staffPerformanceSection,
      body: lines.isEmpty
          ? _EmptySection(hint: AppStrings.noStaffSales)
          : Column(
              children: [
                for (final line in lines)
                  _KeyValueRow(
                    // Till logins resolve to names elsewhere; here the
                    // backend only knows actor ids, so the row shows a
                    // stable short id rather than a wrong name.
                    label: line.actorId == null
                        ? AppStrings.unknown
                        : _shortId(line.actorId!),
                    value: AppStrings.staffRow(
                      line.salesCount,
                      _money(line.revenue),
                    ),
                  ),
              ],
            ),
    );
  }
}

String _shortId(String id) => id.length <= AppLimits.shortIdLength
    ? id
    : id.substring(0, AppLimits.shortIdLength);

// ---------------------------------------------------------------------------
// Finance
// ---------------------------------------------------------------------------

final _financeExpenseColumns = <DataColumnSpec<FinanceCategoryTotalDto>>[
  DataColumnSpec(
    label: AppStrings.categoryColumn,
    field: 'category',
    value: (r) => r.category,
  ),
  DataColumnSpec(
    label: AppStrings.totalColumn,
    field: 'total',
    numeric: true,
    value: (r) => _money(r.total),
  ),
];

class FinanceSection extends ConsumerWidget {
  const FinanceSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(financeSummaryProvider).valueOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: SummaryMetricCard(
                label: AppStrings.netMetric,
                value: Fmt.money(summary == null ? 0 : _d(summary.net)),
                trend: AppStrings.netTrend,
                icon: Icons.account_balance_wallet_outlined,
                accent: context.semantic.success,
              ),
            ),
            const SizedBox(width: Insets.md),
            Expanded(
              child: SummaryMetricCard(
                label: AppStrings.expensesMetric,
                value: Fmt.money(
                  summary == null ? 0 : _d(summary.expenseTotal),
                ),
                trend: AppStrings.adhocSpend,
                icon: Icons.trending_down_rounded,
                accent: context.semantic.warning,
              ),
            ),
          ],
        ),
        const SizedBox(height: Insets.md),
        _Section(
          title: AppStrings.spendByCategory,
          columns: _financeExpenseColumns,
          rows: summary?.expensesByCategory ?? const [],
          exportTitle: AppStrings.spendByCategory,
          body: (summary == null || summary.expensesByCategory.isEmpty)
              ? _EmptySection(hint: AppStrings.noExpenses)
              : Column(
                  children: [
                    for (final line in summary.expensesByCategory)
                      _KeyValueRow(
                        label: line.category,
                        value: _money(line.total),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Waste
// ---------------------------------------------------------------------------

final _wasteColumns = <DataColumnSpec<WasteLineDto>>[
  DataColumnSpec(
    label: AppStrings.itemColumn,
    field: 'name',
    value: (r) => r.itemName,
  ),
  DataColumnSpec(
    label: AppStrings.wastedColumn,
    field: 'qty',
    numeric: true,
    value: (r) => '${_d(r.quantityWasted)} ${r.itemUnit}',
  ),
  DataColumnSpec(
    label: AppStrings.costColumn,
    field: 'cost',
    numeric: true,
    value: (r) => r.costEstimated ? '${_money(r.costWasted)} (est.)' : _money(r.costWasted),
  ),
];

class WasteSection extends ConsumerWidget {
  const WasteSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(wasteSummaryProvider).valueOrNull;
    final lines = summary?.lines ?? const [];

    return _Section(
      title: AppStrings.wasteSection,
      columns: _wasteColumns,
      rows: lines,
      exportTitle: AppStrings.wasteSection,
      body: lines.isEmpty
          ? _EmptySection(hint: AppStrings.noWaste)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  summary!.estimated
                      ? '${AppStrings.costWasted(_money(summary.totalCostWasted))} — estimated (some rows predate frozen costs)'
                      : AppStrings.costWasted(_money(summary.totalCostWasted)),
                  style: context.text.titleSmall?.copyWith(
                    color: context.semantic.warning,
                  ),
                ),
                const SizedBox(height: Insets.sm),
                for (final line in lines)
                  _KeyValueRow(
                    label: line.itemName,
                    value: line.costEstimated
                        ? '${AppStrings.wasteRow(
                            Fmt.quantity(_d(line.quantityWasted)),
                            line.itemUnit,
                            _money(line.costWasted),
                          )} (est.)'
                        : AppStrings.wasteRow(
                            Fmt.quantity(_d(line.quantityWasted)),
                            line.itemUnit,
                            _money(line.costWasted),
                          ),
                  ),
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Production
// ---------------------------------------------------------------------------

final _productionColumns = <DataColumnSpec<IngredientConsumptionDto>>[
  DataColumnSpec(
    label: AppStrings.ingredientColumn,
    field: 'name',
    value: (r) => r.rawMaterialName,
  ),
  DataColumnSpec(
    label: AppStrings.consumedColumn,
    field: 'qty',
    numeric: true,
    value: (r) => '${_d(r.quantityConsumed)} ${r.rawMaterialUnit}',
  ),
];

class ProductionSection extends ConsumerWidget {
  const ProductionSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(productionSummaryProvider).valueOrNull;
    final over = summary == null ? 0.0 : _d(summary.overPortionedBy);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: SummaryMetricCard(
                label: AppStrings.runsMetric,
                value: '${summary?.runs ?? 0}',
                trend: AppStrings.productionRunsTrend,
                icon: Icons.soup_kitchen_outlined,
                accent: context.colors.primary,
              ),
            ),
            const SizedBox(width: Insets.md),
            Expanded(
              child: SummaryMetricCard(
                label: AppStrings.overPortioned,
                value: AppStrings.overPortionedValue(over, Fmt.quantity(over)),
                trend: AppStrings.actualVsSuggested,
                icon: Icons.tune_rounded,
                accent: over > 0
                    ? context.semantic.warning
                    : context.semantic.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: Insets.md),
        _Section(
          title: AppStrings.ingredientsConsumed,
          columns: _productionColumns,
          rows: summary?.ingredientsConsumed ?? const [],
          exportTitle: AppStrings.ingredientsConsumed,
          body: (summary == null || summary.ingredientsConsumed.isEmpty)
              ? _EmptySection(hint: AppStrings.noProduction)
              : Column(
                  children: [
                    for (final line in summary.ingredientsConsumed)
                      _KeyValueRow(
                        label: line.rawMaterialName,
                        value: AppStrings.consumedRow(
                          Fmt.quantity(_d(line.quantityConsumed)),
                          line.rawMaterialUnit,
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Valuation
// ---------------------------------------------------------------------------

final _valuationColumns = <DataColumnSpec<StockValuationLineDto>>[
  DataColumnSpec(
    label: AppStrings.categoryColumn,
    field: 'category',
    value: (r) => r.category ?? AppStrings.uncategorized,
  ),
  DataColumnSpec(
    label: AppStrings.linesColumn,
    field: 'count',
    numeric: true,
    value: (r) => '${r.itemCount}',
  ),
  DataColumnSpec(
    label: AppStrings.valueColumn,
    field: 'value',
    numeric: true,
    value: (r) => _money(r.totalValue),
  ),
];

class ValuationSection extends ConsumerWidget {
  const ValuationSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final valuation = ref.watch(stockValuationProvider).valueOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SummaryMetricCard(
          label: AppStrings.inventoryValueMetric,
          value: Fmt.money(valuation == null ? 0 : _d(valuation.totalValue)),
          trend: AppStrings.onHandAtCost,
          icon: Icons.inventory_2_outlined,
          accent: context.colors.primary,
        ),
        const SizedBox(height: Insets.md),
        _Section(
          title: AppStrings.valueByCategory,
          columns: _valuationColumns,
          rows: valuation?.lines ?? const [],
          exportTitle: AppStrings.inventoryValuation,
          body: (valuation == null || valuation.lines.isEmpty)
              ? _EmptySection(hint: AppStrings.nothingOnHand)
              : Column(
                  children: [
                    for (final line in valuation.lines)
                      _KeyValueRow(
                        label: line.category ?? AppStrings.uncategorized,
                        value: AppStrings.valuationRow(
                          line.itemCount,
                          _money(line.totalValue),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// New reports — exact drawer names from the menu spec
// ---------------------------------------------------------------------------

/// One printed line of the profit-and-loss statement.
///
/// The statement body is custom layout, but PDF/Excel exporters only
/// understand columns + rows — so the same figures are flattened into
/// [_PLRow]s and handed to [_Section] for export. Screen and file always
/// agree because both read this one list.
class _PLRow {
  const _PLRow(this.particulars, this.amount);

  final String particulars;
  final Decimal amount;
}

final _plColumns = <DataColumnSpec<_PLRow>>[
  DataColumnSpec(
    label: 'Particulars',
    field: 'particulars',
    value: (r) => r.particulars,
  ),
  DataColumnSpec(
    label: 'Amount',
    field: 'amount',
    numeric: true,
    value: (r) => _money(r.amount),
  ),
];

String _periodLabel(DateTime? from, DateTime? to) {
  String day(DateTime dt) => '${Fmt.dayMonth(dt)} ${dt.year}';
  if (from == null && to == null) return 'All time';
  if (from == null) return 'Up to ${day(to!)}';
  if (to == null) return 'From ${day(from)}';
  return '${day(from)} – ${day(to)}';
}

/// A muted uppercase heading for one block of the statement.
class _PLBlockTitle extends StatelessWidget {
  const _PLBlockTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Insets.md, bottom: Insets.xs),
      child: Text(
        text,
        style: context.text.labelMedium?.copyWith(
          letterSpacing: 1.2,
          fontWeight: FontWeight.w700,
          color: context.colors.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// One statement line: particulars left, tabular amount right, with an
/// optional second-line note (e.g. "% of revenue").
class _PLLine extends StatelessWidget {
  const _PLLine({required this.label, required this.amount, this.note});

  final String label;
  final Decimal amount;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Insets.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: context.text.bodyMedium),
                if (note != null)
                  Text(
                    note!,
                    style: context.text.bodySmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: Insets.md),
          Text(
            _money(amount),
            style: context.text.bodyMedium?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// A ruled subtotal/total line: amount row with a top border.
///
/// Pass [amountColor] for profit/loss totals so a profit reads green and a
/// loss reads red — the label and amount share the colour.
class _PLTotal extends StatelessWidget {
  const _PLTotal({required this.label, required this.amount, this.amountColor});

  final String label;
  final Decimal amount;
  final Color? amountColor;

  @override
  Widget build(BuildContext context) {
    final style = context.text.bodyMedium?.copyWith(
      fontWeight: FontWeight.w700,
      color: amountColor,
    );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: Insets.xs),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: context.colors.outlineVariant)),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(
            _money(amount),
            style: style?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Profit / Loss Report — a formal statement of profit and loss.
///
/// Revenue and operating expenses come from POS Service's finance
/// summary; cost of goods sold is units sold (item-mix) valued at each
/// recipe's cost per unit, falling back to the item's own unit cost for
/// resold goods with no formula. Goods purchased in the period ride below
/// as a memo line (procurement ≠ consumption). Waste and on-hand value
/// are memo lines too: real figures, explicitly outside the formal totals.
class ProfitLossSection extends ConsumerWidget {
  const ProfitLossSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(reportsDateFilterProvider);
    final summary = ref.watch(financeSummaryProvider).valueOrNull;
    final purchases =
        ref.watch(productPurchasesProvider).valueOrNull ?? const [];
    final itemMix = ref.watch(itemMixProvider).valueOrNull ?? const [];
    final recipes = ref.watch(recipesCatalogListProvider);
    final items = ref.watch(inventoryItemsListProvider);
    final waste = ref.watch(wasteSummaryProvider).valueOrNull;
    final valuation = ref.watch(stockValuationProvider).valueOrNull;

    final revenue = summary == null
        ? Decimal.zero
        : summary.salesRevenue + summary.incomeTotal;
    // Frozen sale-time costs where the cache has them; live recipe costs
    // over item-mix where it doesn't (nothing synced for the window yet).
    // New sales always freeze (zero when unknown), so only legacy rows
    // without snapshots still ride live prices — `fallbackLines` sizes that
    // tail.
    final snapshot = ref.watch(snapshotCogsProvider).valueOrNull;
    final useSnapshot = snapshot != null && snapshot.covered;
    Decimal cogs;
    bool cogsEstimated;
    if (useSnapshot) {
      cogs = snapshot.cogs;
      cogsEstimated = snapshot.estimated;
    } else {
      // Recipe cost per sellable at current raw prices; fallback is the
      // item's own unit cost (bought-and-resold lines).
      final recipeCost = <String, Decimal>{
        for (final r in recipes)
          if (r.sellableItemId != null)
            r.sellableItemId!: r.costPerUnit,
      };
      final recipeComplete = <String, bool>{
        for (final r in recipes)
          if (r.sellableItemId != null)
            r.sellableItemId!: r.costComplete,
      };
      final fallbackCost = <String, Decimal>{
        for (final i in items)
          if (i.catalogItemId != null)
            i.catalogItemId!: Decimal.parse(i.unitCost.toString()),
      };
      final index = CogsIndex(
        recipeCost: recipeCost,
        recipeComplete: recipeComplete,
        fallbackCost: fallbackCost,
      );
      final cogsResult = index.cogsForQuantities({
        for (final line in itemMix) line.itemId: line.quantity,
      });
      cogs = cogsResult.cogs;
      cogsEstimated = cogsResult.estimated;
    }
    var purchaseCost = Decimal.zero;
    for (final p in purchases) {
      purchaseCost += p.totalCost;
    }
    final grossProfit = revenue - cogs;
    final expenseTotal = summary?.expenseTotal ?? Decimal.zero;
    final net = grossProfit - expenseTotal;
    final isGrossLoss = grossProfit < Decimal.zero;
    final isNetLoss = net < Decimal.zero;

    double pct(Decimal part) {
      final r = _d(revenue);
      if (r == 0) return 0;
      return _d(part) / r * 100;
    }

    final exportRows = <_PLRow>[
      _PLRow('Sales revenue', summary?.salesRevenue ?? Decimal.zero),
      _PLRow('Other income', summary?.incomeTotal ?? Decimal.zero),
      _PLRow('TOTAL REVENUE', revenue),
      _PLRow(
        cogsEstimated
            ? 'Cost of goods sold (recipes, estimated)'
            : 'Cost of goods sold (recipes)',
        cogs,
      ),
      _PLRow(isGrossLoss ? 'GROSS LOSS' : 'GROSS PROFIT', grossProfit),
      for (final e
          in summary?.expensesByCategory ?? const <FinanceCategoryTotalDto>[])
        _PLRow('Expense — ${e.category}', e.total),
      _PLRow('TOTAL OPERATING EXPENSES', expenseTotal),
      _PLRow(isNetLoss ? 'NET LOSS' : 'NET PROFIT', net),
    ];

    final hasData =
        revenue != Decimal.zero ||
        cogs != Decimal.zero ||
        expenseTotal != Decimal.zero;

    return _Section(
      title: 'Profit / Loss Report',
      columns: _plColumns,
      rows: exportRows,
      exportTitle: 'Profit / Loss Report',
      body: !hasData
          ? _EmptySection(hint: AppStrings.noSalesInWindow)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Statement of profit and loss',
                  style: context.text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: Insets.xs),
                Text(
                  _periodLabel(filter.from, filter.to),
                  style: context.text.bodySmall?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
                const _PLBlockTitle('Revenue'),
                _PLLine(
                  label: 'Sales revenue',
                  amount: summary?.salesRevenue ?? Decimal.zero,
                ),
                _PLLine(
                  label: 'Other income',
                  amount: summary?.incomeTotal ?? Decimal.zero,
                ),
                _PLTotal(label: 'Total revenue  (A)', amount: revenue),
                const _PLBlockTitle('Cost of goods'),
                _PLLine(
                  label: 'Cost of goods sold (recipes × qty)',
                  amount: cogs,
                  note: cogsEstimated
                      ? (useSnapshot && snapshot.fallbackLines > 0
                          ? 'Estimated — ${snapshot.fallbackLines} of ${snapshot.frozenLines + snapshot.fallbackLines} lines use live costs (legacy sales)'
                          : 'Estimated — some sales lack a recipe cost')
                      : (useSnapshot && snapshot.frozenLines > 0
                          ? 'Frozen at sale time (${snapshot.frozenLines} lines)'
                          : 'Units sold valued at recipe cost'),
                ),
                _PLTotal(
                  label: isGrossLoss
                      ? 'Gross loss  (A − B)'
                      : 'Gross profit  (A − B)',
                  amount: grossProfit,
                  amountColor: isGrossLoss
                      ? context.semantic.danger
                      : context.semantic.success,
                ),
                const _PLBlockTitle('Operating expenses'),
                for (final e
                    in summary?.expensesByCategory ??
                        const <FinanceCategoryTotalDto>[])
                  _PLLine(
                    label: _capitalize(e.category),
                    amount: e.total,
                    note: '${pct(e.total).toStringAsFixed(1)}% of revenue',
                  ),
                if ((summary?.expensesByCategory ?? const []).isEmpty)
                  _PLLine(label: 'No expenses recorded', amount: Decimal.zero),
                _PLTotal(
                  label: 'Total operating expenses  (C)',
                  amount: expenseTotal,
                ),
                const SizedBox(height: Insets.md),
                Container(
                  padding: const EdgeInsets.all(Insets.md),
                  decoration: BoxDecoration(
                    color:
                        (isNetLoss
                                ? context.semantic.danger
                                : context.semantic.success)
                            .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color:
                          (isNetLoss
                                  ? context.semantic.danger
                                  : context.semantic.success)
                              .withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isNetLoss ? 'NET LOSS' : 'NET PROFIT',
                              style: context.text.labelMedium?.copyWith(
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.w700,
                                color: isNetLoss
                                    ? context.semantic.danger
                                    : context.semantic.success,
                              ),
                            ),
                            Text(
                              'Margin ${pct(net).toStringAsFixed(1)}% of revenue',
                              style: context.text.bodySmall?.copyWith(
                                color: context.colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        _money(net),
                        style: context.text.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: isNetLoss
                              ? context.semantic.danger
                              : context.semantic.success,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Insets.md),
                _PLLine(
                  label: 'Memo — goods purchased in period',
                  amount: purchaseCost,
                ),
                _PLLine(
                  label: 'Memo — waste cost in period',
                  amount: waste?.totalCostWasted ?? Decimal.zero,
                ),
                _PLLine(
                  label: 'Memo — inventory on hand (at cost)',
                  amount: valuation?.totalValue ?? Decimal.zero,
                ),
                const SizedBox(height: Insets.sm),
                Text(
                  'Note: cost of goods is units sold valued at recipe cost '
                  '(fallback: item unit cost for resold goods); purchases, '
                  'waste and on-hand value are memo lines, not part of the '
                  'totals.',
                  style: context.text.bodySmall?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
    );
  }
}

String _capitalize(String value) =>
    value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);

/// Register Report — shift-close view over daily takings.
class RegisterSection extends ConsumerWidget {
  const RegisterSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = ref.watch(dailyTakingsProvider).valueOrNull ?? const [];
    return _Section(
      title: 'Register Report',
      columns: _takingsColumns,
      rows: days,
      exportTitle: 'Register Report',
      body: days.isEmpty
          ? _EmptySection(hint: AppStrings.noSalesInWindow)
          : Column(
              children: [
                for (final day in days)
                  _KeyValueRow(
                    label: Fmt.dayMonth(day.date),
                    value: AppStrings.takingsRow(
                      _money(day.revenue),
                      day.salesCount,
                    ),
                  ),
              ],
            ),
    );
  }
}

/// Trending Products — item-mix ranked by quantity.
class TrendingSection extends ConsumerWidget {
  const TrendingSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lines = ref.watch(trendingProductsProvider).valueOrNull ?? const [];
    final items = ref.watch(inventoryItemsListProvider);
    final nameById = {
      for (final item in items)
        if (item.catalogItemId != null) item.catalogItemId!: item.name,
    };
    return _Section(
      title: 'Trending Products',
      columns: const [],
      rows: lines,
      exportTitle: 'Trending Products',
      body: lines.isEmpty
          ? _EmptySection(hint: AppStrings.nothingSold)
          : Column(
              children: [
                for (final line in lines)
                  _KeyValueRow(
                    label: nameById[line.itemId] ?? AppStrings.unknownItem,
                    value: Fmt.quantity(_d(line.quantity)),
                  ),
              ],
            ),
    );
  }
}

/// Sales Representative Report — same staff-performance leg, rep view.
class SalesRepSection extends ConsumerWidget {
  const SalesRepSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lines = ref.watch(staffPerformanceProvider).valueOrNull ?? const [];
    return _Section(
      title: 'Sales Representative Report',
      columns: _staffColumns,
      rows: lines,
      exportTitle: 'Sales Representative Report',
      body: lines.isEmpty
          ? _EmptySection(hint: AppStrings.noStaffSales)
          : Column(
              children: [
                for (final line in lines)
                  _KeyValueRow(
                    label: line.actorId == null
                        ? AppStrings.unknown
                        : _shortId(line.actorId!),
                    value: AppStrings.staffRow(
                      line.salesCount,
                      _money(line.revenue),
                    ),
                  ),
              ],
            ),
    );
  }
}

/// Expense Report — ad-hoc spend lines via finance summary categories.
class ExpenseSection extends ConsumerWidget {
  const ExpenseSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(financeSummaryProvider).valueOrNull;
    final lines = summary?.expensesByCategory ?? const [];
    return _Section(
      title: 'Expense Report',
      columns: _financeExpenseColumns,
      rows: lines,
      exportTitle: 'Expense Report',
      body: lines.isEmpty
          ? _EmptySection(hint: AppStrings.noExpenses)
          : Column(
              children: [
                for (final line in lines)
                  _KeyValueRow(label: line.category, value: _money(line.total)),
              ],
            ),
    );
  }
}

/// Sell Payment Report — revenue by payment method.
class SellPaymentsSection extends ConsumerWidget {
  const SellPaymentsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lines = ref.watch(sellPaymentsProvider).valueOrNull ?? const [];
    return _Section(
      title: 'Sell Payment Report',
      columns: const [],
      rows: lines,
      exportTitle: 'Sell Payment Report',
      body: lines.isEmpty
          ? _EmptySection(hint: AppStrings.noSalesInWindow)
          : Column(
              children: [
                for (final line in lines)
                  _KeyValueRow(
                    label: line.paymentMethod,
                    value: _money(line.revenue),
                  ),
              ],
            ),
    );
  }
}

/// Tax Report — tax collected per day.
class TaxSection extends ConsumerWidget {
  const TaxSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = ref.watch(taxReportProvider).valueOrNull ?? const [];
    return _Section(
      title: 'Tax Report',
      columns: const [],
      rows: days,
      exportTitle: 'Tax Report',
      body: days.isEmpty
          ? _EmptySection(hint: AppStrings.noSalesInWindow)
          : Column(
              children: [
                for (final day in days)
                  _KeyValueRow(
                    label: Fmt.dayMonth(day.date),
                    value: _money(day.taxCollected),
                  ),
              ],
            ),
    );
  }
}

/// Product Purchase Report — what was bought, from whom.
class ProductPurchasesSection extends ConsumerWidget {
  const ProductPurchasesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lines = ref.watch(productPurchasesProvider).valueOrNull ?? const [];
    return _Section(
      title: 'Product Purchase Report',
      columns: const [],
      rows: lines,
      exportTitle: 'Product Purchase Report',
      body: lines.isEmpty
          ? _EmptySection(hint: AppStrings.noProduction)
          : Column(
              children: [
                for (final line in lines)
                  _KeyValueRow(
                    label: '${line.itemName} · ${line.supplierName}',
                    value:
                        '${Fmt.quantity(_d(line.quantityOrdered))} · ${_money(line.totalCost)}',
                  ),
              ],
            ),
    );
  }
}

/// Purchase & Sale — purchases side-by-side with sales in the window.
class PurchaseSaleSection extends ConsumerWidget {
  const PurchaseSaleSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final purchases =
        ref.watch(productPurchasesProvider).valueOrNull ?? const [];
    final takings = ref.watch(dailyTakingsProvider).valueOrNull ?? const [];
    var purchaseTotal = 0.0;
    for (final p in purchases) {
      purchaseTotal += _d(p.totalCost);
    }
    var salesTotal = 0.0;
    for (final day in takings) {
      salesTotal += _d(day.revenue);
    }
    return _Section(
      title: 'Purchase & Sale',
      columns: const [],
      rows: const [],
      exportTitle: 'Purchase & Sale',
      body: (purchases.isEmpty && takings.isEmpty)
          ? _EmptySection(hint: AppStrings.noSalesInWindow)
          : Column(
              children: [
                _KeyValueRow(
                  label: 'Purchases',
                  value: Fmt.money(purchaseTotal),
                ),
                _KeyValueRow(label: 'Sales', value: Fmt.money(salesTotal)),
              ],
            ),
    );
  }
}

/// Items Report — every catalog item with its stock on hand.
class ItemsSection extends ConsumerWidget {
  const ItemsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(inventoryItemsListProvider);
    return _Section(
      title: 'Items Report',
      columns: <DataColumnSpec<InventoryItem>>[
        DataColumnSpec(label: 'Item', field: 'name', value: (r) => r.name),
        DataColumnSpec(
          label: 'Stock',
          field: 'stock',
          numeric: true,
          value: (r) => '${r.stock}',
        ),
        DataColumnSpec(
          label: 'Reorder level',
          field: 'reorder',
          numeric: true,
          value: (r) => '${r.reorderLevel}',
        ),
      ],
      rows: items,
      exportTitle: 'Items Report',
      body: items.isEmpty
          ? _EmptySection(hint: AppStrings.nothingOnHand)
          : Column(
              children: [
                for (final item in items)
                  _KeyValueRow(
                    label: item.name,
                    value: 'Stock ${item.stock} · Reorder ${item.reorderLevel}',
                  ),
              ],
            ),
    );
  }
}

/// Stock Report — current on-hand value by category.
class StockReportSection extends ConsumerWidget {
  const StockReportSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final valuation = ref.watch(stockValuationProvider).valueOrNull;
    final lines = valuation?.lines ?? const [];
    return _Section(
      title: 'Stock Report',
      columns: _valuationColumns,
      rows: lines,
      exportTitle: 'Stock Report',
      body: lines.isEmpty
          ? _EmptySection(hint: AppStrings.nothingOnHand)
          : Column(
              children: [
                for (final line in lines)
                  _KeyValueRow(
                    label: line.category ?? AppStrings.uncategorized,
                    value: AppStrings.valuationRow(
                      line.itemCount,
                      _money(line.totalValue),
                    ),
                  ),
              ],
            ),
    );
  }
}

/// Stock Adjustment Report — manual corrections.
class StockAdjustmentsSection extends ConsumerWidget {
  const StockAdjustmentsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lines = ref.watch(stockAdjustmentsProvider).valueOrNull ?? const [];
    return _Section(
      title: 'Stock Adjustment Report',
      columns: const [],
      rows: lines,
      exportTitle: 'Stock Adjustment Report',
      body: lines.isEmpty
          ? _EmptySection(hint: AppStrings.noProduction)
          : Column(
              children: [
                for (final line in lines)
                  _KeyValueRow(
                    label: line.itemName,
                    value:
                        '${Fmt.quantity(_d(line.quantityDelta))} · ${line.reason ?? ''}',
                  ),
              ],
            ),
    );
  }
}

/// Lot Report — received batches with frozen receipt costs.
class LotSection extends ConsumerWidget {
  const LotSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lines = ref.watch(lotReportProvider).valueOrNull ?? const [];
    return _Section(
      title: 'Lot Report',
      columns: const [],
      rows: lines,
      exportTitle: 'Lot Report',
      body: lines.isEmpty
          ? _EmptySection(hint: AppStrings.nothingOnHand)
          : Column(
              children: [
                for (final line in lines)
                  _KeyValueRow(
                    label: '${line.lotNo} · ${line.itemName}',
                    value:
                        '${Fmt.quantity(_d(line.quantityReceived))} · ${_money(line.totalCost)} (@ ${_money(line.unitCost)})',
                  ),
              ],
            ),
    );
  }
}

/// Stock Expiry Report — lots expiring in the window.
class ExpirySection extends ConsumerWidget {
  const ExpirySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lines = ref.watch(expiryReportProvider).valueOrNull ?? const [];
    return _Section(
      title: 'Stock Expiry Report',
      columns: const [],
      rows: lines,
      exportTitle: 'Stock Expiry Report',
      body: lines.isEmpty
          ? _EmptySection(hint: AppStrings.nothingOnHand)
          : Column(
              children: [
                for (final line in lines)
                  _KeyValueRow(
                    label: '${line.lotNo} · ${line.itemName}',
                    value: line.expiryDate ?? '',
                  ),
              ],
            ),
    );
  }
}

/// Customer Groups Report.
class CustomerGroupsSection extends ConsumerWidget {
  const CustomerGroupsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lines = ref.watch(customerGroupsProvider).valueOrNull ?? const [];
    return _Section(
      title: 'Customer Groups Report',
      columns: const [],
      rows: lines,
      exportTitle: 'Customer Groups Report',
      body: lines.isEmpty
          ? _EmptySection(hint: AppStrings.noStaffSales)
          : Column(
              children: [
                for (final line in lines)
                  _KeyValueRow(label: line.group, value: _money(line.revenue)),
              ],
            ),
    );
  }
}

/// Supplier & Customer Report — both legs side by side.
class SupplierCustomerSection extends ConsumerWidget {
  const SupplierCustomerSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suppliers =
        ref.watch(supplierPurchasesProvider).valueOrNull ?? const [];
    final customers = ref.watch(customerSpendProvider).valueOrNull ?? const [];
    return _Section(
      title: 'Supplier & Customer Report',
      columns: const [],
      rows: const [],
      exportTitle: 'Supplier & Customer Report',
      body: (suppliers.isEmpty && customers.isEmpty)
          ? _EmptySection(hint: AppStrings.noStaffSales)
          : Column(
              children: [
                for (final s in suppliers)
                  _KeyValueRow(
                    label: 'SUP · ${s.supplierName}',
                    value: _money(s.totalReceived),
                  ),
                for (final c in customers)
                  _KeyValueRow(
                    label: 'CUS · ${c.customerName}',
                    value: _money(c.totalSpent),
                  ),
              ],
            ),
    );
  }
}

/// Activity Log — recent stock movements.
class ActivityLogSection extends ConsumerWidget {
  const ActivityLogSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lines = ref.watch(activityLogProvider).valueOrNull ?? const [];
    return _Section(
      title: 'Activity Log',
      columns: const [],
      rows: lines,
      exportTitle: 'Activity Log',
      body: lines.isEmpty
          ? _EmptySection(hint: AppStrings.noProduction)
          : Column(
              children: [
                for (final line in lines)
                  _KeyValueRow(
                    label: '${line.movementType} · ${line.itemName}',
                    value: Fmt.quantity(_d(line.quantityDelta)),
                  ),
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared bits
// ---------------------------------------------------------------------------

class _EmptySection extends StatelessWidget {
  const _EmptySection({required this.hint});

  final String hint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Insets.md),
      child: Text(
        hint,
        style: context.text.bodySmall?.copyWith(
          color: context.colors.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _KeyValueRow extends StatelessWidget {
  const _KeyValueRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Insets.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodyMedium,
            ),
          ),
          const SizedBox(width: Insets.md),
          Text(
            value,
            style: context.text.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
