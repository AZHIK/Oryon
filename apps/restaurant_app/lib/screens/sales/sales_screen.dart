import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/order.dart';
import '../../constants/app_strings.dart';
import '../../providers/orders_provider.dart';
import '../../providers/outbox_status_provider.dart';
import '../../router/app_router.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/data_page/data_column_spec.dart';
import '../../widgets/data_page/data_page_scaffold.dart';
import '../../widgets/data_page/data_table_toolbar.dart';
import '../../widgets/connection_status_pill.dart';
import '../../widgets/data_page/export_actions.dart';
import '../../widgets/data_page/reusable_data_table.dart';
import '../../widgets/data_page/summary_metric_card.dart';
import '../../widgets/dialogs/assign_courier_dialog.dart';
import '../../widgets/dialogs/refund_confirm_dialog.dart';
import '../../widgets/receipt/receipt_dialog.dart';
import '../../widgets/sales/fulfillment_status_badge.dart';
import '../../widgets/sales/order_status_badge.dart';
import 'sales_date_range_selector.dart';
import 'sales_filter_panel.dart';

/// The order ledger, built on the same shared data-page layer as Inventory.
///
/// This file is column config, filters and row actions — the layout comes
/// entirely from [DataPageScaffold] and [ReusableDataTable].
class SalesScreen extends ConsumerWidget {
  const SalesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(salesQueryProvider);
    final slice = ref.watch(salesSliceProvider);
    final summary = ref.watch(salesSummaryProvider);
    final filters = ref.watch(salesFiltersProvider);
    final notifier = ref.read(salesQueryProvider.notifier);

    final period = filters.range == SalesDateRange.custom
        ? AppStrings.selectedPeriod
        : filters.range.label.toLowerCase();

    return DataPageScaffold(
      title: AppStrings.salesTitle,
      subtitle: AppStrings.salesSubtitle(Fmt.longDate(DateTime.now())),
      // Exports the filtered, sorted list — every matching row, not just the
      // page on screen.
      actions: [
        SizedBox(
          height: kDataPageActionHeight,
          width: kDataPageActionHeight,
          child: IconButton(
            padding: EdgeInsets.zero,
            iconSize: 20,
            onPressed: () async =>
                ref.read(ordersProvider.notifier).checkForNewOrders(),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: AppStrings.checkNewOrders,
          ),
        ),
        ...dataPageExportActions<Order>(
          context: context,
          columns: salesColumns,
          rows: ref.watch(filteredOrdersProvider),
          title: AppStrings.salesTitle,
          subtitle: _exportSubtitle(filters, query.search),
        ),
      ],
      // No "Add" here — a sale is created at the till, not in the ledger. The
      // period selector earns the slot instead.
      primaryAction: const SalesDateRangeSelector(),
      onRefresh: () =>
          ref.read(ordersProvider.notifier).checkForNewOrders(),
      metrics: [
        SummaryMetricCard(
          label: AppStrings.totalSales,
          value: Fmt.moneyCompact(summary.revenue),
          trend: AppStrings.netOfRefunds(period),
          icon: Icons.payments_rounded,
        ),
        SummaryMetricCard(
          label: AppStrings.ordersMetric,
          value: '${summary.orderCount}',
          trend: AppStrings.itemsSold(summary.itemCount),
          icon: Icons.receipt_long_rounded,
          accent: context.colors.tertiary,
        ),
        SummaryMetricCard(
          label: AppStrings.averageOrder,
          value: Fmt.money(summary.averageOrderValue),
          trend: summary.refundedCount == 0
              ? AppStrings.noRefundsInView
              : AppStrings.refundedCount(summary.refundedCount),
          trendDirection: summary.refundedCount == 0
              ? TrendDirection.flat
              : TrendDirection.down,
          icon: Icons.trending_up_rounded,
          accent: context.semantic.success,
        ),
      ],
      toolbar: DataTableToolbar(
        searchHint: AppStrings.searchOrders,
        searchValue: query.search,
        onSearchChanged: notifier.setSearch,
        activeFilterCount: filters.activeCount,
        onClearFilters: ref.read(salesFiltersProvider.notifier).clear,
        filterBuilder: (_) => const SalesFilterPanel(),
        sortOptions: [
          SortOption(label: AppStrings.dateSort, field: SalesSort.date),
          SortOption(label: AppStrings.orderSort, field: SalesSort.orderId),
          SortOption(label: AppStrings.itemsSort, field: SalesSort.items),
          SortOption(label: AppStrings.totalSort, field: SalesSort.total),
          SortOption(label: AppStrings.paymentSort, field: SalesSort.payment),
          SortOption(
            label: AppStrings.fulfillmentSort,
            field: SalesSort.fulfillment,
          ),
          SortOption(label: AppStrings.statusSort, field: SalesSort.status),
        ],
        sortField: query.sortField,
        sortAscending: query.ascending,
        onSortChanged: (field, ascending) =>
            notifier.setSort(field, ascending: ascending),
      ),
      table: ReusableDataTable<Order>(
        columns: salesColumns,
        slice: slice,
        query: query,
        onSort: notifier.toggleSort,
        onPageChanged: notifier.setPage,
        groupedItems: ref.watch(filteredOrdersProvider),
        onGroupChanged: notifier.setGroup,
        header: PendingSyncBanner(
          pendingCount:
              ref.watch(outboxStatusProvider).valueOrNull?.pendingSales ?? 0,
          itemWord: 'sale',
        ),
        onRowTap: (order) => context.go(AppRoute.orderDetail(order.id)),
        rowActions: _actions(ref),
      ),
    );
  }

  List<DataRowAction<Order>> _actions(WidgetRef ref) => [
    DataRowAction(
      label: AppStrings.viewDetail,
      icon: Icons.open_in_new_rounded,
      onSelected: (context, order) =>
          context.go(AppRoute.orderDetail(order.id)),
    ),
    DataRowAction(
      label: AppStrings.assignCourier,
      icon: Icons.two_wheeler_rounded,
      isEnabled: (order) => order.orderType == OrderType.delivery,
      onSelected: (context, order) => showAssignCourierDialog(context, order),
    ),
    DataRowAction(
      label: AppStrings.refundOrder,
      icon: Icons.undo_rounded,
      isDestructive: true,
      // A ticket can only be refunded once, and a voided one never took money.
      isEnabled: (order) => order.status == OrderStatus.paid,
      onSelected: (context, order) => _confirmRefund(context, ref, order),
    ),
    DataRowAction(
      label: AppStrings.printReceipt,
      icon: Icons.print_outlined,
      // Numbered under the store's configured prefix rather than by ticket id,
      // so a reprint carries the same number the original paper did.
      onSelected: (context, order) =>
          showReceiptPreviewDialog(context, ref, order),
    ),
  ];

  Future<void> _confirmRefund(
    BuildContext context,
    WidgetRef ref,
    Order order,
  ) async {
    final reason = await showRefundConfirmDialog(
      context,
      title: AppStrings.refundTitle(order.id),
      message: AppStrings.refundBody(
        Fmt.money(order.total),
        order.paymentType.label,
      ),
    );

    if (reason == null || !context.mounted) return;
    await ref.read(ordersProvider.notifier).refund(order.id, reason: reason);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(content: Text(AppStrings.orderRefunded(order.id))),
    );
  }

  /// Records on the exported file which view produced it — a takings report
  /// with no period on it is worse than useless to whoever receives it.
  static String _exportSubtitle(SalesFilters filters, String search) {
    final parts = <String>[
      SalesDateRangeSelector.labelFor(filters),
      if (filters.payments.isNotEmpty)
        filters.payments.map((p) => p.label).join(', '),
      if (filters.statuses.isNotEmpty)
        filters.statuses.map((s) => s.label).join(', '),
      if (search.trim().isNotEmpty)
        AppStrings.exportMatching(search.trim()),
    ];

    return parts.join(' · ');
  }
}

/// Column config for the ledger.
///
/// A getter (not a top-level `final`) so `AppStrings` labels are re-evaluated
/// on every build — a cached list would snapshot the launch language and
/// ignore later toggles. Exporters reuse the same definitions, so the
/// spreadsheet carries the same columns the screen shows.
List<DataColumnSpec<Order>> get salesColumns => <DataColumnSpec<Order>>[
  DataColumnSpec(
    label: AppStrings.orderColumn,
    field: SalesSort.orderId,
    role: ColumnRole.primary,
    flex: 4,
    value: (order) => order.id,
    cellBuilder: (context, order) => _OrderCell(order: order),
  ),
  DataColumnSpec(
    label: AppStrings.dateTimeColumn,
    field: SalesSort.date,
    flex: 4,
    minTableWidth: 640,
    value: (order) => Fmt.dayMonthTime(order.placedAt),
    cellBuilder: (context, order) => Text(
      Fmt.relativeDateTime(order.placedAt),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: context.text.bodySmall?.copyWith(
        color: context.colors.onSurfaceVariant,
      ),
    ),
  ),
  DataColumnSpec(
    label: AppStrings.itemsSort,
    field: SalesSort.items,
    flex: 2,
    numeric: true,
    minTableWidth: 780,
    value: (order) => '${order.itemCount}',
  ),
  DataColumnSpec(
    label: AppStrings.totalSort,
    field: SalesSort.total,
    flex: 3,
    numeric: true,
    value: (order) => Fmt.money(order.total),
    cellBuilder: (context, order) => _TotalCell(order: order),
  ),
  DataColumnSpec(
    label: AppStrings.paymentSort,
    field: SalesSort.payment,
    flex: 3,
    groupable: true,
    minTableWidth: 900,
    value: (order) => order.paymentType.label,
  ),
  DataColumnSpec(
    label: AppStrings.fulfillmentSort,
    field: SalesSort.fulfillment,
    role: ColumnRole.status,
    width: 124,
    groupable: true,
    minTableWidth: 1000,
    value: (order) => order.fulfillmentStatus.label,
    cellBuilder: (context, order) =>
        FulfillmentStatusBadge(status: order.fulfillmentStatus, dense: true),
  ),
  DataColumnSpec(
    label: AppStrings.statusSort,
    field: SalesSort.status,
    role: ColumnRole.status,
    width: 124,
    groupable: true,
    value: (order) => order.status.label,
    cellBuilder: (context, order) =>
        OrderStatusBadge(status: order.status, dense: true),
  ),
];

class _OrderCell extends StatelessWidget {
  const _OrderCell({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final isRecent = order.isRecent(DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                order.id,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (isRecent) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: context.colors.primaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  AppStrings.recentBadge,
                  style: context.text.labelSmall?.copyWith(
                    color: context.colors.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ],
        ),
        Text(
          order.tableLabel ?? order.orderType.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.text.bodySmall?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        // Delivery state in plain sight: two green ticks = safely on the
        // server, amber tag = still on this device only.
        if (order.serverSaleId == null)
          const NotSentTag()
        else
          const SentTicks(),
      ],
    );
  }
}

class _TotalCell extends StatelessWidget {
  const _TotalCell({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    // Money that left again must never read with the same weight as takings.
    final struck = order.status != OrderStatus.paid;

    return Text(
      Fmt.money(order.total),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.right,
      style: context.text.bodyMedium?.copyWith(
        fontWeight: FontWeight.w700,
        decoration: order.status == OrderStatus.refunded
            ? TextDecoration.lineThrough
            : null,
        color: struck ? context.colors.onSurfaceVariant : null,
      ),
    );
  }
}
