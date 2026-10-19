import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/permission.dart';
import '../../constants/app_strings.dart';
import '../../models/supplier.dart';
import '../../models/table_query.dart';
import '../../providers/permissions_provider.dart';
import '../../providers/suppliers_provider.dart';
import '../../providers/table_query_provider.dart';
import '../../widgets/data_page/data_column_spec.dart';
import '../../widgets/data_page/data_page_scaffold.dart';
import '../../widgets/data_page/data_table_toolbar.dart';
import '../../widgets/data_page/export_actions.dart';
import '../../widgets/data_page/reusable_data_table.dart';
import '../../widgets/data_page/summary_metric_card.dart';
import '../../widgets/dialogs/supplier_form_dialog.dart';
import '../../utils/dialog_helper.dart';
import '../../widgets/connection_status_pill.dart';

/// Live search text for the suppliers table.
final supplierSearchProvider = StateProvider<String>((ref) => '');

/// Query state (page, sort) for the suppliers table.
final suppliersQueryProvider = NotifierProvider<TableQueryNotifier, TableQuery>(
  TableQueryNotifier.new,
);

final _filteredSuppliersProvider = Provider<List<Supplier>>((ref) {
  final suppliers = ref.watch(suppliersListProvider);
  final query = ref.watch(supplierSearchProvider).trim().toLowerCase();
  if (query.isEmpty) return suppliers;
  return suppliers.where((s) {
    return s.name.toLowerCase().contains(query) ||
        (s.phone?.toLowerCase().contains(query) ?? false) ||
        (s.email?.toLowerCase().contains(query) ?? false);
  }).toList();
});

final _suppliersSliceProvider = Provider<PageSlice<Supplier>>((ref) {
  final suppliers = ref.watch(_filteredSuppliersProvider);
  final query = ref.watch(suppliersQueryProvider);
  var sorted = [...suppliers]..sort((a, b) => a.name.compareTo(b.name));
  if (!query.ascending) sorted = sorted.reversed.toList();
  return PageSlice.of(sorted, query);
});

/// Supplier directory, built on the shared data-page layer.
class SuppliersScreen extends ConsumerWidget {
  const SuppliersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(suppliersQueryProvider);
    final slice = ref.watch(_suppliersSliceProvider);
    final notifier = ref.read(suppliersQueryProvider.notifier);
    final canCreate = ref.watch(hasPermissionProvider(AppPermissions.suppliersCreate));
    final canUpdate = ref.watch(hasPermissionProvider(AppPermissions.suppliersUpdate));
    final canDelete = ref.watch(hasPermissionProvider(AppPermissions.suppliersDelete));

    return DataPageScaffold(
      title: AppStrings.suppliersTitle,
      subtitle: AppStrings.suppliersSubtitle,
      // Exports the filtered list — every matching row, not just the page
      // on screen.
      actions: dataPageExportActions<Supplier>(
        context: context,
        columns: _columns,
        rows: _exportRows(ref),
        title: AppStrings.suppliersTitle,
        subtitle: _exportSubtitle(ref.watch(supplierSearchProvider)),
      ),
      // Hidden rather than shown-disabled: someone who can't add suppliers
      // shouldn't see a control that only ever 403s.
      primaryAction: !canCreate
          ? null
          : FilledButton.icon(
              onPressed: () => showSupplierFormDialog(context),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(AppStrings.addSupplier),
            ),
      onRefresh: () => ref.read(suppliersProvider.notifier).refresh(),
      fab: !canCreate
          ? null
          : DataPageFab(
              icon: Icons.add_rounded,
              label: AppStrings.addSupplier,
              onPressed: () => showSupplierFormDialog(context),
            ),
      metrics: [
        SummaryMetricCard(
          label: AppStrings.totalSuppliers,
          value: '${ref.watch(suppliersListProvider).length}',
          trend: AppStrings.activeVendorRecords,
          icon: Icons.storefront_outlined,
        ),
      ],
      toolbar: DataTableToolbar(
        searchHint: AppStrings.searchSupplier,
        searchValue: ref.watch(supplierSearchProvider),
        onSearchChanged: (value) => ref.read(supplierSearchProvider.notifier).state = value,
        activeFilterCount: 0,
        onClearFilters: () {},
        filterBuilder: (_) => const SizedBox.shrink(),
        sortOptions: [SortOption(label: AppStrings.nameColumn, field: 'name')],
        sortField: query.sortField,
        sortAscending: query.ascending,
        onSortChanged: (field, ascending) => notifier.setSort(field, ascending: ascending),
      ),
      table: ReusableDataTable<Supplier>(
        columns: _columns,
        slice: slice,
        query: query,
        onSort: notifier.toggleSort,
        onPageChanged: notifier.setPage,
        header: const OfflineCacheNote(),
        rowActions: _actions(ref, canUpdate: canUpdate, canDelete: canDelete),
      ),
    );
  }

  List<DataRowAction<Supplier>> _actions(
    WidgetRef ref, {
    required bool canUpdate,
    required bool canDelete,
  }) => [
    if (canUpdate)
      DataRowAction(
        label: AppStrings.editAction,
        icon: Icons.edit_outlined,
        onSelected: (context, supplier) =>
            showSupplierFormDialog(context, existingSupplier: supplier),
      ),
    if (canDelete)
      DataRowAction(
        label: AppStrings.deleteAction,
        icon: Icons.delete_outline_rounded,
        isDestructive: true,
        onSelected: (context, supplier) => _confirmDelete(context, ref, supplier),
      ),
  ];

  /// Search-filtered suppliers in table order for the exporters.
  static List<Supplier> _exportRows(WidgetRef ref) {
    final rows = [...ref.watch(_filteredSuppliersProvider)]
      ..sort((a, b) => a.name.compareTo(b.name));
    return rows;
  }

  /// Records on the exported file which view produced it.
  static String _exportSubtitle(String search) {
    if (search.trim().isEmpty) return AppStrings.allSuppliersExport;
    return AppStrings.exportFiltered(
      AppStrings.exportMatching(search.trim()),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Supplier supplier,
  ) async {
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppStrings.deleteSupplierTitle(supplier.name)),
        content: Text(AppStrings.deleteSupplierBody),
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
      await ref.read(suppliersProvider.notifier).delete(supplier.id);
      messenger.showSnackBar(
        SnackBar(content: Text(AppStrings.supplierDeleted(supplier.name))),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(AppStrings.deleteFailed(e))),
      );
    }
  }
}

/// Column config for the suppliers table.
///
/// A getter (not a top-level `final`) so `AppStrings` labels are re-evaluated
/// on every build — a cached list would snapshot the launch language and
/// ignore later toggles. Exporters reuse the same definitions, so the
/// spreadsheet carries the same columns the screen shows.
List<DataColumnSpec<Supplier>> get _columns => <DataColumnSpec<Supplier>>[
  DataColumnSpec(
    label: AppStrings.nameColumn,
    field: 'name',
    role: ColumnRole.primary,
    flex: 4,
    value: (supplier) => supplier.name,
  ),
  DataColumnSpec(
    label: AppStrings.phoneColumn,
    field: 'phone',
    flex: 3,
    value: (supplier) => supplier.phone ?? AppStrings.emDash,
  ),
  DataColumnSpec(
    label: AppStrings.emailColumn,
    field: 'email',
    flex: 3,
    value: (supplier) => supplier.email ?? AppStrings.emDash,
  ),
];
