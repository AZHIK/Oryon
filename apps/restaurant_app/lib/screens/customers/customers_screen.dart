import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/customer.dart';
import '../../constants/app_strings.dart';
import '../../models/permission.dart';
import '../../providers/customers_provider.dart';
import '../../providers/outbox_status_provider.dart';
import '../../providers/permissions_provider.dart';
import '../../router/app_router.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/connection_status_pill.dart';
import '../../widgets/data_page/data_column_spec.dart';
import '../../widgets/data_page/data_page_scaffold.dart';
import '../../widgets/data_page/data_table_toolbar.dart';
import '../../widgets/data_page/export_actions.dart';
import '../../widgets/data_page/reusable_data_table.dart';
import '../../widgets/data_page/summary_metric_card.dart';
import 'customer_form_dialog.dart';
import '../../utils/dialog_helper.dart';

/// Customer list built on the shared data-page layer, modeled on InventoryScreen.
class CustomersScreen extends ConsumerWidget {
  const CustomersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(customersQueryProvider);
    final slice = ref.watch(customersSliceProvider);
    final summary = ref.watch(customerSummaryProvider);
    final notifier = ref.read(customersQueryProvider.notifier);
    final canCreate = ref.watch(hasPermissionProvider(AppPermissions.customersCreate));
    final canUpdate = ref.watch(hasPermissionProvider(AppPermissions.customersUpdate));
    final canDelete = ref.watch(hasPermissionProvider(AppPermissions.customersDelete));

    return DataPageScaffold(
      title: AppStrings.customersTitle,
      subtitle: AppStrings.customersSubtitle,
      // Exports the filtered list — every matching row, not just the page
      // on screen.
      actions: dataPageExportActions<Customer>(
        context: context,
        columns: _columns,
        rows: ref.watch(filteredCustomersProvider),
        title: AppStrings.customersTitle,
        subtitle: _exportSubtitle(ref.watch(customerSearchProvider)),
      ),
      // Hidden rather than shown-disabled: someone who can't add customers
      // shouldn't see a control that only ever 403s.
      primaryAction: !canCreate
          ? null
          : FilledButton.icon(
              onPressed: () => showCustomerFormDialog(context),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(AppStrings.addCustomer),
            ),
      onRefresh: () => ref.read(customersProvider.notifier).refresh(),
      // Same action as the header button, moved to the thumb zone on phones.
      fab: !canCreate
          ? null
          : DataPageFab(
              icon: Icons.add_rounded,
              label: AppStrings.addCustomer,
              onPressed: () => showCustomerFormDialog(context),
            ),
      metrics: [
        SummaryMetricCard(
          label: AppStrings.totalCustomers,
          value: '${summary.totalCustomers}',
          trend: AppStrings.registeredProfiles,
          icon: Icons.people_alt_outlined,
        ),
        SummaryMetricCard(
          label: AppStrings.lifetimeSpend,
          value: Fmt.moneyCompact(summary.totalLifetimeSpend),
          trend: AppStrings.totalRevenueFromCustomers,
          icon: Icons.trending_up_rounded,
          accent: context.semantic.success,
        ),
        SummaryMetricCard(
          label: AppStrings.averageSpend,
          value: Fmt.money(summary.averageOrderValue),
          trend: AppStrings.perCustomer,
          icon: Icons.balance_rounded,
        ),
      ],
      toolbar: DataTableToolbar(
        searchHint: AppStrings.searchCustomers,
        searchValue: ref.watch(customerSearchProvider),
        onSearchChanged: (value) =>
            ref.read(customerSearchProvider.notifier).state = value,
        activeFilterCount: 0,
        onClearFilters: () {},
        filterBuilder: (_) => const SizedBox.shrink(),
        sortOptions: [
          SortOption(label: AppStrings.nameColumn, field: CustomerSort.name),
          SortOption(label: AppStrings.phoneColumn, field: CustomerSort.phone),
          SortOption(
            label: AppStrings.lastOrderSort,
            field: CustomerSort.lastOrder,
          ),
          SortOption(
            label: AppStrings.totalSpentSort,
            field: CustomerSort.totalSpent,
          ),
        ],
        sortField: query.sortField,
        sortAscending: query.ascending,
        onSortChanged: (field, ascending) =>
            notifier.setSort(field, ascending: ascending),
      ),
      table: ReusableDataTable<Customer>(
        columns: _columns,
        slice: slice,
        query: query,
        onSort: notifier.toggleSort,
        onPageChanged: notifier.setPage,
        header: PendingSyncBanner(
          pendingCount:
              ref.watch(outboxStatusProvider).valueOrNull?.pendingCustomers ??
                  0,
          itemWord: 'customer',
        ),
        onRowTap: (customer) =>
            context.go(AppRoute.customerDetail(customer.id)),
        rowActions: _actions(ref, canUpdate: canUpdate, canDelete: canDelete),
      ),
    );
  }

  List<DataRowAction<Customer>> _actions(
    WidgetRef ref, {
    required bool canUpdate,
    required bool canDelete,
  }) => [
    DataRowAction(
      label: AppStrings.viewDetail,
      icon: Icons.open_in_new_rounded,
      onSelected: (context, customer) =>
          context.go(AppRoute.customerDetail(customer.id)),
    ),
    if (canUpdate)
      DataRowAction(
        label: AppStrings.editAction,
        icon: Icons.edit_outlined,
        onSelected: (context, customer) =>
            showCustomerFormDialog(context, existingCustomer: customer),
      ),
    if (canDelete)
      DataRowAction(
        label: AppStrings.deleteAction,
        icon: Icons.delete_outline_rounded,
        isDestructive: true,
        onSelected: (context, customer) =>
            _confirmDelete(context, ref, customer),
      ),
  ];

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Customer customer,
  ) async {
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppStrings.deleteCustomerTitle(customer.name)),
        content: Text(AppStrings.deleteCustomerBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(AppStrings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(AppStrings.deleteAction),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(customersProvider.notifier).delete(customer.id);
      messenger.showSnackBar(
        SnackBar(
          content: Text(AppStrings.customerDeleted(customer.name)),
        ),
      );
    } on CustomerOfflineMutationException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  /// Records on the exported file which view produced it.
  static String _exportSubtitle(String search) {
    if (search.trim().isEmpty) return AppStrings.allCustomersExport;
    return AppStrings.exportFiltered(
      AppStrings.exportMatching(search.trim()),
    );
  }
}

/// Column config for the customers table.
///
/// A getter (not a top-level `final`) so `AppStrings` labels are re-evaluated
/// on every build — a cached list would snapshot the launch language and
/// ignore later toggles. Exporters reuse the same definitions, so the
/// spreadsheet carries the same columns the screen shows.
List<DataColumnSpec<Customer>> get _columns => <DataColumnSpec<Customer>>[
  DataColumnSpec(
    label: AppStrings.nameColumn,
    field: CustomerSort.name,
    role: ColumnRole.primary,
    flex: 4,
    value: (customer) => customer.name,
    cellBuilder: (context, customer) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          customer.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.text.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        // Sent ticks = safely on the server, amber tag = this device only.
        if (customer.syncStatus != 'synced')
          const NotSentTag()
        else
          const SentTicks(),
      ],
    ),
  ),
  DataColumnSpec(
    label: AppStrings.phoneColumn,
    field: CustomerSort.phone,
    flex: 3,
    value: (customer) => customer.phone,
  ),
  DataColumnSpec(
    label: AppStrings.lastOrderColumn,
    field: CustomerSort.lastOrder,
    flex: 3,
    minTableWidth: 640,
    value: (customer) => customer.lastOrderAt == null
        ? AppStrings.emDash
        : Fmt.relativeDateTime(customer.lastOrderAt!),
  ),
  DataColumnSpec(
    label: AppStrings.ordersColumn,
    field: 'orders',
    flex: 2,
    numeric: true,
    minTableWidth: 780,
    value: (customer) => '${customer.totalOrders}',
  ),
  DataColumnSpec(
    label: AppStrings.totalSpentColumn,
    field: CustomerSort.totalSpent,
    flex: 2,
    numeric: true,
    value: (customer) => Fmt.money(customer.totalSpent),
  ),
];
