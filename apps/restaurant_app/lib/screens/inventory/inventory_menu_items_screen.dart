import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:decimal/decimal.dart';

import '../../models/inventory_item.dart';
import '../../constants/app_strings.dart';
import '../../models/permission.dart';
import '../../providers/categories_provider.dart';
import '../../providers/dashboard_metrics_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/permissions_provider.dart';
import '../../providers/production_provider.dart';
import '../../providers/stock_movement_provider.dart';
import '../../router/app_router.dart';
import '../../services/inventory_api_service.dart';
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
import '../../widgets/dialogs/menu_item_form_dialog.dart';
import '../../widgets/item_photo.dart';
import 'menu_item_filter_panel.dart';
import 'recipe_form_dialog.dart';
import '../../utils/dialog_helper.dart';

/// Sellable items — everything a customer can order at the till.
///
/// A standalone screen under Stock with its own route, form and detail.
/// Strictly `item_type IN (sellable, both)`: counted resold lines (`both`)
/// live here, never on Groceries, so the two screens share no rows.
///
/// Price and recipe are this screen's actions — stock adjust, purchase
/// ordering, waste and transfers belong to counted lines and live on
/// Groceries. Production recording lives on the menu-item detail screen.
class InventoryMenuItemsScreen extends ConsumerWidget {
  const InventoryMenuItemsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(menuItemsQueryProvider);
    final slice = ref.watch(menuItemsSliceProvider);
    final totalItems = ref.watch(menuCatalogItemsProvider).length;
    final filters = ref.watch(menuItemFiltersProvider);
    final notifier = ref.read(menuItemsQueryProvider.notifier);
    final sales = ref.watch(_menuSalesSummaryProvider);
    // Production cost per sellable at current raw prices — raw-materials
    // only, no labour yet. The table resolves each row against these.
    final recipes = ref.watch(recipesCatalogListProvider);
    final columns = menuItemColumns(
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
    );

    return DataPageScaffold(
      title: AppStrings.menuItemsTitle,
      subtitle: AppStrings.menuItemsSubtitle(totalItems),
      actions: dataPageExportActions<InventoryItem>(
        context: context,
        columns: columns,
        rows: ref.watch(filteredMenuCatalogProvider),
        title: AppStrings.menuItemsTitle,
        subtitle: _exportSubtitle(filters, query.search),
      ),
      // On phones the scaffold moves this to the FAB, so no mobile-only
      // icon variant is needed here.
      primaryAction: FilledButton.icon(
        onPressed: () => showMenuItemFormDialog(context),
        icon: const Icon(Icons.add_rounded, size: 18),
        label: Text(AppStrings.addItem),
      ),
      onRefresh: () =>
          ref.read(inventoryItemsProvider.notifier).refresh(),
      fab: DataPageFab(
        icon: Icons.add_rounded,
        label: AppStrings.addMenuItem,
        onPressed: () => showMenuItemFormDialog(context),
      ),
      // Three cards: the till count plus real sales from
      // `dashboardMetricsProvider` (top items by units over the trailing
      // 7 days) — aggregate figures only, since per-row sales attribution
      // needs a per-item sales join this screen doesn't have yet.
      metrics: [
        SummaryMetricCard(
          label: AppStrings.menuItemsTitle,
          value: '$totalItems',
          trend: AppStrings.availableAtTill,
          icon: Icons.restaurant_menu_rounded,
        ),
        SummaryMetricCard(
          label: AppStrings.topSeller,
          value: sales.topSellerName ?? AppStrings.emDash,
          trend: sales.topSellerName == null
              ? AppStrings.last7Days
              : AppStrings.unitsSold(sales.topSellerUnits),
          icon: Icons.trending_up_rounded,
          accent: context.colors.tertiary,
        ),
        SummaryMetricCard(
          label: AppStrings.menuRevenue,
          value: Fmt.moneyCompact(sales.totalRevenue),
          trend: AppStrings.last7Days,
          icon: Icons.payments_outlined,
          accent: context.semantic.success,
        ),
      ],
      toolbar: DataTableToolbar(
        searchHint: AppStrings.searchItemsCategory,
        searchValue: query.search,
        onSearchChanged: notifier.setSearch,
        activeFilterCount: filters.activeCount,
        onClearFilters: ref.read(menuItemFiltersProvider.notifier).clear,
        filterBuilder: (_) => const MenuItemFilterPanel(),
        sortOptions: [
          SortOption(
            label: AppStrings.nameColumn,
            field: MenuItemSort.name,
          ),
          SortOption(
            label: AppStrings.categoryColumn,
            field: MenuItemSort.category,
          ),
          SortOption(
            label: AppStrings.priceColumn,
            field: MenuItemSort.price,
          ),
        ],
        sortField: query.sortField,
        sortAscending: query.ascending,
        onSortChanged: (field, ascending) =>
            notifier.setSort(field, ascending: ascending),
      ),
      table: ReusableDataTable<InventoryItem>(
        columns: columns,
        slice: slice,
        query: query,
        onSort: notifier.toggleSort,
        onPageChanged: notifier.setPage,
        groupedItems: ref.watch(filteredMenuCatalogProvider),
        onGroupChanged: notifier.setGroup,
        header: const OfflineCacheNote(),
        onRowTap: (item) => context.pushNamed(
          AppRoute.menuItemDetailName,
          pathParameters: {'itemId': item.id},
        ),
        rowActions: _actions(ref),
      ),
    );
  }

  List<DataRowAction<InventoryItem>> _actions(WidgetRef ref) {
    final recipe = _recipeActionFor(ref);
    return [
      DataRowAction(
        label: AppStrings.viewDetail,
        icon: Icons.open_in_new_rounded,
        onSelected: (context, item) => context.pushNamed(
          AppRoute.menuItemDetailName,
          pathParameters: {'itemId': item.id},
        ),
      ),
      DataRowAction(
        label: AppStrings.editItem,
        icon: Icons.edit_outlined,
        onSelected: (context, item) =>
            showMenuItemFormDialog(context, existingItemId: item.id),
      ),
      if (recipe != null)
        DataRowAction(
          label: AppStrings.pickRecipe,
          icon: Icons.receipt_long_outlined,
          isEnabled: recipe.appliesTo,
          onSelected: (context, item) => recipe.open(context, item),
        ),
      DataRowAction(
        label: AppStrings.deleteAction,
        icon: Icons.delete_outline_rounded,
        isDestructive: true,
        onSelected: (context, item) => _confirmDelete(context, ref, item),
      ),
    ];
  }

  /// The recipe row action, resolved per row: "Edit recipe" where one is
  /// defined (needs `recipes.update`), "Add recipe" where none is (needs
  /// `recipes.create`). Null when the session may do neither — a row with
  /// no recipe action simply has none, rather than a dead button.
  _MenuRecipeAction? _recipeActionFor(WidgetRef ref) {
    final canEdit =
        ref.watch(hasPermissionProvider(AppPermissions.recipesUpdate));
    final canCreate =
        ref.watch(hasPermissionProvider(AppPermissions.recipesCreate));
    if (!canEdit && !canCreate) return null;
    final recipes = ref.watch(recipesCatalogListProvider);
    return _MenuRecipeAction(
      recipes: recipes,
      canEdit: canEdit,
      canCreate: canCreate,
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    InventoryItem item,
  ) async {
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppStrings.deleteItemTitle(item.name)),
        content: Text(AppStrings.deleteMenuItemBody),
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

  static String _exportSubtitle(MenuItemFilters filters, String search) {
    final parts = <String>[
      if (filters.categoryIds.isNotEmpty)
        AppStrings.exportCategories(filters.categoryIds.length),
      if (search.trim().isNotEmpty)
        AppStrings.exportMatching(search.trim()),
    ];
    return parts.isEmpty
        ? AppStrings.exportAllMenuItems
        : AppStrings.exportFiltered(parts.join(' · '));
  }
}

// ---------------------------------------------------------------------------
// Per-row recipe action — "Edit recipe" where the backend has one for the
// row's catalog id, "Add recipe" where none is. Resolved per row because
// the catalog, not the table, knows which lines have a formula.
// ---------------------------------------------------------------------------

class _MenuRecipeAction {
  const _MenuRecipeAction({
    required this.recipes,
    required this.canEdit,
    required this.canCreate,
  });

  final List<RecipeDto> recipes;
  final bool canEdit;
  final bool canCreate;

  RecipeDto? _editFor(InventoryItem item) {
    final catalogId = item.catalogItemId;
    if (catalogId == null || !canEdit) return null;
    return recipes.where((r) => r.sellableItemId == catalogId).firstOrNull;
  }

  /// Whether this row shows the Recipe entry at all: an existing formula
  /// to edit, or permission to add one. Demo-mode rows without a backend
  /// id never do — recipes need the backend's atomic catalog.
  bool appliesTo(InventoryItem item) =>
      _editFor(item) != null ||
      (item.catalogItemId != null && canCreate);

  /// Opens the formula for edit where one exists, else the add flow for
  /// this row's line.
  void open(BuildContext context, InventoryItem item) {
    final recipe = _editFor(item);
    if (recipe != null) {
      showRecipeFormDialog(context, recipe: recipe);
    } else {
      showRecipeFormDialog(context, sellable: item);
    }
  }
}

// ---------------------------------------------------------------------------
// Trailing-7-day sales summary — aggregates from `dashboardMetricsProvider`
// (real synced sales), shown without per-row attribution, which would need
// a per-item sales join this screen doesn't have yet.
// ---------------------------------------------------------------------------

class _MenuSalesSummary {
  const _MenuSalesSummary({
    required this.topSellerName,
    required this.topSellerUnits,
    required this.totalRevenue,
  });

  final String? topSellerName;
  final int topSellerUnits;
  final double totalRevenue;
}

final _menuSalesSummaryProvider = Provider<_MenuSalesSummary>((ref) {
  final topItems = ref.watch(dashboardMetricsProvider).topItems;
  final top = topItems.isEmpty ? null : topItems.first;
  final total = topItems.fold<double>(0, (sum, item) => sum + item.revenue);

  return _MenuSalesSummary(
    topSellerName: top?.name,
    topSellerUnits: top?.units ?? 0,
    totalRevenue: total,
  );
});

// ---------------------------------------------------------------------------
// Columns
// ---------------------------------------------------------------------------

/// Column config for the Menu Items table.
///
/// The Cost column values each row at its recipe's cost per unit —
/// raw-materials cost only, no labour yet — falling back to the line's own
/// unit cost for resold goods with no formula. A row with neither reads as
/// an estimate rather than a confident zero.
///
/// No units-sold/revenue columns: per-row sales data would need a per-item
/// sales join — showing dashboard aggregates against a specific row would
/// name the wrong item's numbers. Once real per-item sales reach this
/// screen, add them here without restructuring anything else.
List<DataColumnSpec<InventoryItem>> menuItemColumns({
  required Map<String, Decimal> recipeCost,
  required Map<String, bool> recipeComplete,
}) {
  String costValue(InventoryItem item) {
    final key = item.catalogItemId ?? item.id;
    final recipe = recipeCost[key];
    if (recipe != null) {
      final value = Fmt.money(double.parse(recipe.toString()));
      return recipeComplete[key] == false
          ? '$value (${AppStrings.costEstimated})'
          : value;
    }
    if (item.unitCost > 0) return Fmt.money(item.unitCost);
    return '${Fmt.money(0)} (${AppStrings.costEstimated})';
  }

  return <DataColumnSpec<InventoryItem>>[
    DataColumnSpec(
      label: AppStrings.itemColumn,
      field: MenuItemSort.name,
      role: ColumnRole.primary,
      flex: 3,
      value: (item) => item.name,
      cellBuilder: (context, item) => _ItemCell(item: item),
    ),
  DataColumnSpec(
    label: AppStrings.categoryColumn,
    field: MenuItemSort.category,
    flex: 2,
    groupable: true,
    minTableWidth: 700,
    value: (item) => categoryLabelForId(item.categoryId),
  ),
  DataColumnSpec(
    label: AppStrings.costColumn,
    field: 'cost',
    sortable: false,
    flex: 2,
    numeric: true,
    minTableWidth: 700,
    value: costValue,
  ),
  DataColumnSpec(
    label: AppStrings.priceColumn,
    field: MenuItemSort.price,
    flex: 2,
    numeric: true,
    value: (item) => item.sellingPrice == null
        ? AppStrings.notForSale
        : Fmt.money(item.sellingPrice!),
  ),
  DataColumnSpec(
    label: AppStrings.activeColumn,
    field: 'isActive',
    sortable: false,
    role: ColumnRole.status,
    width: 128,
    groupable: true,
    value: (item) =>
        item.isArchived ? AppStrings.archivedBadge : AppStrings.activeBadge,
    // Fixed-width cells get no gutter from the table (flex cells carry
    // their own right padding), so the badge brings its own left inset —
    // otherwise right-aligned prices sit right on top of it.
    cellBuilder: (context, item) => Padding(
      padding: const EdgeInsets.only(left: Insets.md),
      child: StatusBadge(
        label: item.isArchived ? AppStrings.archivedBadge : AppStrings.activeBadge,
        tone: item.isArchived ? StatusTone.neutral : StatusTone.positive,
        icon: item.isArchived ? Icons.archive_outlined : Icons.check_circle_rounded,
        dense: true,
      ),
    ),
  ),
  ];
}

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
          child: Text(
            item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
