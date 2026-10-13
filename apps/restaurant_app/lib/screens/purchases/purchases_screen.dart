import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../constants/app_strings.dart';
import '../../models/permission.dart';
import '../../models/purchase_order.dart';
import '../../models/table_query.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/permissions_provider.dart';
import '../../providers/purchases_provider.dart';
import '../../providers/suppliers_provider.dart';
import '../../providers/table_query_provider.dart';
import '../../router/app_router.dart';
import '../../theme/app_theme.dart';
import '../../theme/breakpoints.dart';
import '../../utils/formatters.dart';
import '../../widgets/data_page/data_column_spec.dart';
import '../../widgets/data_page/data_page_scaffold.dart';
import '../../widgets/data_page/data_table_toolbar.dart';
import '../../widgets/data_page/export_actions.dart';
import '../../widgets/data_page/filter_controls.dart';
import '../../widgets/data_page/reusable_data_table.dart';
import '../../widgets/data_page/summary_metric_card.dart';
import '../purchasing/requisition_cart_dialog.dart';
import 'purchase_order_dialog.dart';

/// Live search text for the purchases table.
final purchaseSearchProvider = StateProvider<String>((ref) => '');

/// Status filter for the purchases table — empty means "all statuses".
final purchaseStatusFilterProvider =
    StateProvider<Set<PurchaseOrderStatus>>((ref) => {});

/// Query state (page, sort) for the purchases table.
final purchasesQueryProvider = NotifierProvider<TableQueryNotifier, TableQuery>(
  TableQueryNotifier.new,
);

/// Sort field keys for the purchases table.
abstract final class PurchaseSort {
  static const poNumber = 'poNumber';
  static const orderedAt = 'orderedAt';
}

/// A purchase order enriched with its supplier name for display, search,
/// and export — the table layer only sees this row type.
class PurchaseOrderRow {
  const PurchaseOrderRow({required this.order, required this.supplierName});

  final PurchaseOrder order;
  final String supplierName;
}

final _filteredPurchasesProvider = Provider<List<PurchaseOrderRow>>((ref) {
  final orders = ref.watch(purchasesListProvider);
  final suppliers = {for (final s in ref.watch(suppliersListProvider)) s.id: s.name};
  final statuses = ref.watch(purchaseStatusFilterProvider);
  final query = ref.watch(purchaseSearchProvider).trim().toLowerCase();
  final rows = [
    for (final order in orders)
      if (statuses.isEmpty || statuses.contains(order.status))
        PurchaseOrderRow(
          order: order,
          supplierName: suppliers[order.supplierId] ?? AppStrings.unknownSupplier,
        ),
  ];
  if (query.isEmpty) return rows;
  return rows.where((r) {
    return r.order.poNumber.toLowerCase().contains(query) ||
        r.supplierName.toLowerCase().contains(query);
  }).toList();
});

final _purchasesSliceProvider = Provider<PageSlice<PurchaseOrderRow>>((ref) {
  final rows = ref.watch(_filteredPurchasesProvider);
  final query = ref.watch(purchasesQueryProvider);
  var sorted = [...rows]
    ..sort((a, b) => switch (query.sortField) {
      PurchaseSort.poNumber => a.order.poNumber.compareTo(b.order.poNumber),
      _ => b.order.orderedAt.compareTo(a.order.orderedAt),
    });
  if (query.sortField != null && !query.ascending) {
    sorted = sorted.reversed.toList();
  }
  return PageSlice.of(sorted, query);
});

/// Purchase-order tracking, built on the shared data-page layer like
/// Suppliers/Customers/Sales.
///
/// Strictly online-only: the provider holds live API data (no Drift cache),
/// so when `isOnlineProvider` is false the table is replaced by an offline
/// placeholder instead of stale rows. Errors from the live fetch surface
/// with a retry action.
class PurchasesScreen extends ConsumerWidget {
  const PurchasesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const PurchasesTabView();
  }
}

/// The purchases data page without page chrome — reused as a tab inside the
/// merged Purchasing module (`PurchasingScreen` owns the Scaffold there).
class PurchasesTabView extends ConsumerWidget {
  const PurchasesTabView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(isOnlineProvider).valueOrNull ?? true;
    final ordersAsync = ref.watch(purchasesProvider);

    if (!online) {
      return _OfflineBody(
        onRetry: () => ref.read(purchasesProvider.notifier).refresh(),
      );
    }

    return ordersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorBody(
        message: e.toString(),
        onRetry: () => ref.read(purchasesProvider.notifier).refresh(),
      ),
      data: (_) => const _PurchasesDataPage(),
    );
  }
}

class _PurchasesDataPage extends ConsumerWidget {
  const _PurchasesDataPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(purchasesQueryProvider);
    final slice = ref.watch(_purchasesSliceProvider);
    final notifier = ref.read(purchasesQueryProvider.notifier);
    final all = ref.watch(purchasesListProvider);
    final canCreate =
        ref.watch(hasPermissionProvider(AppPermissions.procurementCreate));
    final statuses = ref.watch(purchaseStatusFilterProvider);

    final open = all.where((o) => o.status.isOpen).length;
    final received =
        all.where((o) => o.status == PurchaseOrderStatus.fulfilled).length;

    return DataPageScaffold(
      title: AppStrings.purchasesTitle,
      subtitle: AppStrings.purchasesSubtitle,
      actions: dataPageExportActions<PurchaseOrderRow>(
        context: context,
        columns: _columns,
        rows: _exportRows(ref),
        title: AppStrings.purchasesTitle,
        subtitle: _exportSubtitle(ref.watch(purchaseSearchProvider)),
      ),
      // Hidden rather than shown-disabled: someone who can't draft orders
      // shouldn't see a control that only ever 403s.
      primaryAction: !canCreate
          ? null
          : Wrap(
              spacing: Insets.sm,
              runSpacing: Insets.sm,
              alignment: WrapAlignment.end,
              children: [
                const RequisitionCartButton(),
                FilledButton.icon(
                  onPressed: () => showPurchaseOrderDialog(context),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(AppStrings.newOrderAction),
                ),
              ],
            ),
      onRefresh: () => ref.read(purchasesProvider.notifier).refresh(),
      metrics: [
        SummaryMetricCard(
          label: AppStrings.openOrdersMetric,
          value: '$open',
          trend: AppStrings.awaitingApproval,
          icon: Icons.shopping_bag_outlined,
          accent: context.semantic.warning,
        ),
        SummaryMetricCard(
          label: AppStrings.receivedMetric,
          value: '$received',
          trend: AppStrings.stockAdded,
          icon: Icons.check_circle_rounded,
          accent: context.semantic.success,
        ),
      ],
      toolbar: DataTableToolbar(
        searchHint: AppStrings.searchPurchases,
        searchValue: ref.watch(purchaseSearchProvider),
        onSearchChanged: (value) =>
            ref.read(purchaseSearchProvider.notifier).state = value,
        activeFilterCount: statuses.length,
        onClearFilters: () {
          ref.read(purchaseStatusFilterProvider.notifier).state = {};
          ref.read(purchasesQueryProvider.notifier).resetPage();
        },
        filterBuilder: (_) => const _PurchasesFilterPanel(),
        sortOptions: [
          SortOption(label: AppStrings.poNumberColumn, field: PurchaseSort.poNumber),
          SortOption(label: AppStrings.orderedColumn, field: PurchaseSort.orderedAt),
        ],
        sortField: query.sortField,
        sortAscending: query.ascending,
        onSortChanged: (field, ascending) =>
            notifier.setSort(field, ascending: ascending),
      ),
      table: ReusableDataTable<PurchaseOrderRow>(
        columns: _columns,
        slice: slice,
        query: query,
        onSort: notifier.toggleSort,
        onPageChanged: notifier.setPage,
        onRowTap: (row) =>
            context.push(AppRoute.purchaseDetail(row.order.id)),
        rowActions: _actions(ref, canCreate: canCreate),
      ),
    );
  }

  List<DataRowAction<PurchaseOrderRow>> _actions(
    WidgetRef ref, {
    required bool canCreate,
  }) =>
      [
        DataRowAction(
          label: AppStrings.viewDetail,
          icon: Icons.open_in_new_rounded,
          onSelected: (context, row) =>
              context.push(AppRoute.purchaseDetail(row.order.id)),
        ),
        if (canCreate)
          DataRowAction(
            label: AppStrings.cancel,
            icon: Icons.cancel_outlined,
            isDestructive: true,
            onSelected: (context, row) =>
                _transition(context, ref, row, 'cancel'),
          ),
      ];

  Future<void> _transition(
    BuildContext context,
    WidgetRef ref,
    PurchaseOrderRow row,
    String action,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final notifier = ref.read(purchasesProvider.notifier);
      switch (action) {
        case 'cancel':
          await notifier.cancel(row.order.id);
          messenger.showSnackBar(
            SnackBar(content: Text(AppStrings.orderCancelledMessage)),
          );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(AppStrings.transitionFailed(action, e))),
      );
    }
  }

  /// Search-filtered rows in table order for the exporters.
  static List<PurchaseOrderRow> _exportRows(WidgetRef ref) {
    return [...ref.watch(_filteredPurchasesProvider)];
  }

  /// Records on the exported file which view produced it.
  static String _exportSubtitle(String search) {
    if (search.trim().isEmpty) return AppStrings.allPurchasesExport;
    return AppStrings.exportFiltered(
      AppStrings.exportMatching(search.trim()),
    );
  }
}

/// Status filter contents of the shared filter popover/sheet.
class _PurchasesFilterPanel extends ConsumerWidget {
  const _PurchasesFilterPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(purchaseStatusFilterProvider);
    final notifier = ref.read(purchaseStatusFilterProvider.notifier);
    final query = ref.read(purchasesQueryProvider.notifier);
    return FilterSection(
      title: AppStrings.statusFilter,
      child: FilterChipGroup<PurchaseOrderStatus>(
        options: PurchaseOrderStatus.values
            .where((s) => s != PurchaseOrderStatus.unknown)
            .toList(),
        selected: selected,
        labelOf: (status) => status.label,
        onToggle: (status) {
          final next = {...selected};
          if (!next.remove(status)) next.add(status);
          notifier.state = next;
          query.resetPage();
        },
      ),
    );
  }
}

/// Shown whenever the device is offline — purchases cannot run on cache.
class _OfflineBody extends StatelessWidget {
  const _OfflineBody({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(Insets.lg),
      children: [
        const SizedBox(height: Insets.xl * 2),
        Icon(Icons.cloud_off_outlined,
            size: 48, color: context.colors.onSurfaceVariant),
        const SizedBox(height: Insets.md),
        Text(
          AppStrings.purchasesOfflineTitle,
          style: context.text.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: Insets.sm),
        Text(
          AppStrings.purchasesOfflineBody,
          style: context.text.bodyMedium
              ?.copyWith(color: context.colors.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: Insets.lg),
        Center(
          child: FilledButton.tonal(
            onPressed: onRetry,
            child: Text(AppStrings.retryAction),
          ),
        ),
      ],
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(Insets.lg),
      children: [
        const SizedBox(height: Insets.xl * 2),
        Icon(Icons.error_outline_rounded,
            size: 48, color: context.colors.onSurfaceVariant),
        const SizedBox(height: Insets.md),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: Insets.lg),
        Center(
          child: FilledButton.tonal(
            onPressed: onRetry,
            child: Text(AppStrings.retryAction),
          ),
        ),
      ],
    );
  }
}

/// Column config for the purchases table.
///
/// A getter (not a top-level `final`) so `AppStrings` labels are re-evaluated
/// on every build — same rationale as the suppliers table. Exporters reuse
/// the same definitions.
List<DataColumnSpec<PurchaseOrderRow>> get _columns =>
    <DataColumnSpec<PurchaseOrderRow>>[
      DataColumnSpec(
        label: AppStrings.poNumberColumn,
        field: PurchaseSort.poNumber,
        role: ColumnRole.primary,
        flex: 3,
        value: (row) => row.order.poNumber,
      ),
      DataColumnSpec(
        label: AppStrings.supplierColumn,
        field: 'supplier',
        flex: 4,
        value: (row) => row.supplierName,
      ),
      DataColumnSpec(
        label: AppStrings.statusColumn,
        field: 'status',
        flex: 3,
        value: (row) => row.order.status.label,
      ),
      DataColumnSpec(
        label: AppStrings.linesColumn,
        field: 'lines',
        flex: 2,
        value: (row) => '${row.order.lines.length}',
      ),
      DataColumnSpec(
        label: AppStrings.orderedColumn,
        field: PurchaseSort.orderedAt,
        flex: 3,
        value: (row) => Fmt.relativeDateTime(row.order.orderedAt),
      ),
    ];
