import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/inventory_item.dart';
import '../../constants/app_strings.dart';
import '../../providers/categories_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/stock_movement_provider.dart';
import '../../router/app_router.dart';
import '../../theme/app_theme.dart';
import '../../theme/breakpoints.dart';
import '../../utils/formatters.dart';
import '../../widgets/connection_status_pill.dart';
import '../../widgets/data_page/data_column_spec.dart';
import '../../widgets/data_page/data_page_scaffold.dart';
import '../../widgets/data_page/data_table_toolbar.dart';
import '../../widgets/data_page/export_actions.dart';
import '../../widgets/data_page/reusable_data_table.dart';
import '../../widgets/data_page/status_badge.dart';
import '../../widgets/data_page/summary_metric_card.dart';
import '../../widgets/dialogs/grocery_form_dialog.dart';
import '../../widgets/inventory/add_to_order_cart.dart';
import '../../widgets/item_photo.dart';
import 'inventory_filter_panel.dart';
import 'stock_adjust_dialog.dart';
import 'stock_transfer_dialog.dart';
import 'waste_log_dialog.dart';
import '../../utils/dialog_helper.dart';

/// Maps the stockroom's vocabulary onto the shared badge tones.
extension StockStatusTone on StockStatus {
  StatusTone get tone => switch (this) {
    StockStatus.inStock => StatusTone.positive,
    StockStatus.lowStock => StatusTone.warning,
    StockStatus.outOfStock => StatusTone.danger,
  };

  IconData get badgeIcon => switch (this) {
    StockStatus.inStock => Icons.check_circle_rounded,
    StockStatus.lowStock => Icons.warning_amber_rounded,
    StockStatus.outOfStock => Icons.remove_shopping_cart_outlined,
  };
}

/// Raw materials — everything bought to be used or prepped, never sold
/// as-is.
///
/// A standalone screen under Stock with its own route, form and detail.
/// Strictly `item_type == raw_material`: counted menu lines (`both`, like a
/// bottled drink bought and resold unchanged) live on Menu Items, never
/// here, so the two screens share no rows and neither double-counts.
///
/// Built from the shared data-page layer: this file holds column config,
/// filters and actions, and no layout of its own.
class InventoryGroceriesScreen extends ConsumerWidget {
  const InventoryGroceriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(inventoryQueryProvider);
    final slice = ref.watch(inventorySliceProvider);
    final summary = ref.watch(inventorySummaryProvider);
    final filters = ref.watch(inventoryFiltersProvider);
    final notifier = ref.read(inventoryQueryProvider.notifier);

    return DataPageScaffold(
      title: AppStrings.groceriesTitle,
      subtitle: AppStrings.groceriesSubtitle(
        summary.totalItems,
        ref.watch(categoriesListProvider).length,
      ),
      // Exports the filtered, sorted list — every matching row, not
      // just the page on screen.
      actions: dataPageExportActions<InventoryItem>(
        context: context,
        columns: groceryColumns,
        rows: ref.watch(filteredInventoryProvider),
        title: AppStrings.groceriesTitle,
        subtitle: _exportSubtitle(filters, query.search),
      ),
      // On phones the scaffold moves this to the FAB, so no mobile-only
      // icon variant is needed here.
      primaryAction: FilledButton.icon(
        onPressed: () => showGroceryFormDialog(context),
        icon: const Icon(Icons.add_rounded, size: 18),
        label: Text(AppStrings.addItem),
      ),
      onRefresh: () =>
          ref.read(inventoryItemsProvider.notifier).refresh(),
      fab: DataPageFab(
        icon: Icons.add_rounded,
        label: AppStrings.addGroceryItem,
        onPressed: () => showGroceryFormDialog(context),
      ),
      metrics: [
        SummaryMetricCard(
          label: AppStrings.groceryItemsMetric,
          value: '${summary.totalItems}',
          trend: AppStrings.fullyStocked(
            summary.totalItems - summary.needsAttention,
          ),
          icon: Icons.shopping_basket_outlined,
        ),
        SummaryMetricCard(
          label: AppStrings.belowThreshold,
          value: '${summary.lowStockCount}',
          trend: summary.outOfStockCount == 0
              ? AppStrings.nothingOutOfStock
              : AppStrings.outOfStockTrend(summary.outOfStockCount),
          trendDirection: summary.needsAttention == 0
              ? TrendDirection.flat
              : TrendDirection.down,
          icon: Icons.warning_amber_rounded,
          accent: context.semantic.warning,
        ),
        SummaryMetricCard(
          label: AppStrings.outOfStockMetric,
          value: '${summary.outOfStockCount}',
          trend: summary.outOfStockCount == 0
              ? AppStrings.allLinesCovered
              : AppStrings.needsDelivery,
          trendDirection: summary.outOfStockCount == 0
              ? TrendDirection.flat
              : TrendDirection.down,
          icon: Icons.remove_shopping_cart_outlined,
          accent: context.semantic.danger,
        ),
        SummaryMetricCard(
          label: AppStrings.stockValueMetric,
          value: Fmt.moneyCompact(summary.totalValue),
          // Cost basis is the item's own unit cost — the last price it
          // was recorded at, not a fabricated figure.
          trend: AppStrings.atLastKnownCost,
          icon: Icons.savings_outlined,
          accent: context.semantic.success,
        ),
      ],
      toolbar: DataTableToolbar(
        searchHint: AppStrings.searchItemsSkuSupplier,
        searchValue: query.search,
        onSearchChanged: notifier.setSearch,
        activeFilterCount: filters.activeCount,
        onClearFilters: ref.read(inventoryFiltersProvider.notifier).clear,
        filterBuilder: (_) => const InventoryFilterPanel(),
        sortOptions: [
          SortOption(label: AppStrings.nameColumn, field: InventorySort.name),
          SortOption(
            label: AppStrings.categoryColumn,
            field: InventorySort.category,
          ),
          SortOption(label: AppStrings.stockColumn, field: InventorySort.stock),
          SortOption(
            label: AppStrings.reorderAtColumn,
            field: InventorySort.reorderLevel,
          ),
          SortOption(
            label: AppStrings.statusColumn,
            field: InventorySort.status,
          ),
        ],
        sortField: query.sortField,
        sortAscending: query.ascending,
        onSortChanged: (field, ascending) =>
            notifier.setSort(field, ascending: ascending),
      ),
      table: ReusableDataTable<InventoryItem>(
        columns: groceryColumns,
        slice: slice,
        query: query,
        onSort: notifier.toggleSort,
        onPageChanged: notifier.setPage,
        groupedItems: ref.watch(filteredInventoryProvider),
        onGroupChanged: notifier.setGroup,
        header: const OfflineCacheNote(),
        // The row body opens the grocery detail screen; the row's
        // own "Edit" action still goes straight to the form.
        onRowTap: (item) => context.pushNamed(
          AppRoute.groceryDetailName,
          pathParameters: {'itemId': item.id},
        ),
        rowActions: _actions(ref),
      ),
    );
  }

  List<DataRowAction<InventoryItem>> _actions(WidgetRef ref) => [
    DataRowAction(
      label: AppStrings.viewDetail,
      icon: Icons.open_in_new_rounded,
      onSelected: (context, item) => context.pushNamed(
        AppRoute.groceryDetailName,
        pathParameters: {'itemId': item.id},
      ),
    ),
    DataRowAction(
      label: AppStrings.editItem,
      icon: Icons.edit_outlined,
      onSelected: (context, item) =>
          showGroceryFormDialog(context, existingItemId: item.id),
    ),
    DataRowAction(
      label: AppStrings.adjustStock,
      icon: Icons.tune_rounded,
      // Untracked lines have no count to adjust.
      isEnabled: (item) => item.trackStock,
      onSelected: (context, item) => showStockAdjustDialog(context, item),
    ),
    DataRowAction(
      label: AppStrings.addToOrderCart,
      icon: Icons.add_shopping_cart,
      // Untracked lines have no count to base a quantity on.
      isEnabled: (item) => item.trackStock,
      onSelected: (context, item) => addItemToOrderCart(context, ref, item),
    ),
    DataRowAction(
      label: AppStrings.logWaste,
      icon: Icons.delete_sweep_outlined,
      isEnabled: (item) => item.trackStock && item.stock > 0,
      onSelected: (context, item) => showWasteLogDialog(context, item),
    ),
    DataRowAction(
      label: AppStrings.transferStock,
      icon: Icons.swap_horiz_rounded,
      isEnabled: (item) => item.trackStock && item.stock > 0,
      onSelected: (context, item) => showStockTransferDialog(context, item),
    ),
    DataRowAction(
      label: AppStrings.deleteAction,
      icon: Icons.delete_outline_rounded,
      isDestructive: true,
      onSelected: (context, item) => _confirmDelete(context, ref, item),
    ),
  ];

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    InventoryItem item,
  ) async {
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppStrings.deleteItemTitle(item.name)),
        content: Text(AppStrings.deleteGroceryBody),
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
      await ref.read(inventoryItemsProvider.notifier).delete(item.id);
      // The ledger goes with the item — orphaned movements would keep
      // counting against a line that no longer exists.
      ref.read(stockMovementsProvider.notifier).clearForItem(item.id);
      messenger.showSnackBar(
        SnackBar(content: Text(AppStrings.itemDeleted(item.name))),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(AppStrings.deleteFailed(e))),
      );
    }
  }

  /// Records on the exported file which view produced it — an unqualified
  /// stock report is easy to mistake for the whole stockroom.
  static String _exportSubtitle(InventoryFilters filters, String search) {
    final parts = <String>[
      if (filters.categoryIds.isNotEmpty)
        AppStrings.exportCategories(filters.categoryIds.length),
      if (filters.statuses.isNotEmpty)
        filters.statuses.map((s) => s.label).join(', '),
      if (filters.hasStockRange)
        AppStrings.exportStockRange(
          filters.minStock != null
              ? Fmt.quantity(filters.minStock!)
              : '0',
          filters.maxStock != null
              ? Fmt.quantity(filters.maxStock!)
              : AppStrings.exportAny,
        ),
      if (search.trim().isNotEmpty)
        AppStrings.exportMatching(search.trim()),
    ];

    return parts.isEmpty
        ? AppStrings.exportAllGroceries
        : AppStrings.exportFiltered(parts.join(' · '));
  }
}

/// Column config for the Groceries table.
///
/// Top-level so the exporters can reuse the exact same definitions — the
/// spreadsheet then carries the same columns and the same formatting the
/// screen shows. No "last purchase date/cost" column: Inventory Service does
/// not track a purchase-order history yet, only the current `unit_cost`
/// basis (used in the Stock value stat) — a per-purchase figure would have
/// to be fabricated, so it is left out rather than shown as a guess.
final groceryColumns = <DataColumnSpec<InventoryItem>>[
  DataColumnSpec(
    label: AppStrings.itemColumn,
    field: InventorySort.name,
    role: ColumnRole.primary,
    flex: 5,
    value: (item) => item.name,
    cellBuilder: (context, item) => _ItemCell(item: item),
  ),
  DataColumnSpec(
    label: AppStrings.categoryColumn,
    field: InventorySort.category,
    flex: 2,
    groupable: true,
    minTableWidth: 760,
    value: (item) => categoryLabelForId(item.categoryId),
  ),
  DataColumnSpec(
    label: AppStrings.unitColumn,
    field: 'unit',
    sortable: false,
    flex: 1,
    minTableWidth: 620,
    value: (item) => item.unit,
  ),
  DataColumnSpec(
    label: AppStrings.stockColumn,
    field: InventorySort.stock,
    flex: 2,
    numeric: true,
    value: (item) => '${Fmt.quantity(item.stock)} ${item.unit}',
    cellBuilder: (context, item) => _StockCell(item: item),
  ),
  DataColumnSpec(
    label: AppStrings.reorderAtColumn,
    field: InventorySort.reorderLevel,
    flex: 2,
    numeric: true,
    minTableWidth: 900,
    value: (item) =>
        item.trackStock ? Fmt.quantity(item.reorderLevel) : AppStrings.notTracked,
  ),
  DataColumnSpec(
    label: AppStrings.statusColumn,
    field: InventorySort.status,
    role: ColumnRole.status,
    width: 132,
    groupable: true,
    value: (item) => item.status.label,
    cellBuilder: (context, item) => StatusBadge(
      label: item.status.label,
      tone: item.status.tone,
      icon: item.status.badgeIcon,
      dense: true,
    ),
  ),
  DataColumnSpec(
    label: AppStrings.activeColumn,
    field: 'isActive',
    sortable: false,
    role: ColumnRole.tableOnly,
    width: 96,
    minTableWidth: 1080,
    value: (item) => item.isArchived ? AppStrings.archivedBadge : AppStrings.activeBadge,
    cellBuilder: (context, item) => StatusBadge(
      label: item.isArchived ? AppStrings.archivedBadge : AppStrings.activeBadge,
      tone: item.isArchived ? StatusTone.neutral : StatusTone.positive,
      icon: item.isArchived ? Icons.archive_outlined : Icons.check_circle_rounded,
      dense: true,
    ),
  ),
];

class _ItemCell extends StatelessWidget {
  const _ItemCell({required this.item});

  final InventoryItem item;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Row(
      children: [
        Container(
          height: 36,
          width: 36,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: colors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(Radii.sm),
          ),
          alignment: Alignment.center,
          child: ItemPhoto(
            emoji: item.emoji,
            emojiSize: 18,
            bytes: item.image?.bytes,
            imageUrl: item.imageUrl,
            catalogItemId: item.catalogItemId,
          ),
        ),
        const SizedBox(width: Insets.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                item.sku,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StockCell extends StatelessWidget {
  const _StockCell({required this.item});

  final InventoryItem item;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final short = item.status != StockStatus.inStock;

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Flexible(
          child: Text(
            Fmt.quantity(item.stock),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: short ? context.semantic.warning : null,
            ),
          ),
        ),
        const SizedBox(width: 3),
        Text(
          item.unit,
          maxLines: 1,
          style: context.text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
        ),
      ],
    );
  }
}
