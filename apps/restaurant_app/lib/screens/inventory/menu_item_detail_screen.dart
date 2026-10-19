import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/inventory_item.dart';
import '../../constants/app_limits.dart';
import '../../constants/app_strings.dart';
import '../../models/permission.dart';
import '../../models/stock_movement.dart';
import '../../models/table_query.dart';
import '../../providers/categories_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/permissions_provider.dart';
import '../../providers/production_provider.dart';
import '../../providers/stock_movement_provider.dart';
import '../../router/app_router.dart';
import '../../theme/app_theme.dart';
import '../../theme/breakpoints.dart';
import '../../utils/formatters.dart';
import '../../widgets/data_page/data_column_spec.dart';
import '../../widgets/data_page/reusable_data_table.dart';
import '../../widgets/data_page/status_badge.dart';
import '../../widgets/data_page/summary_metric_card.dart';
import '../../widgets/detail_page/detail_page_scaffold.dart';
import '../../widgets/dialogs/menu_item_form_dialog.dart';
import '../../widgets/item_photo.dart';
import 'recipe_form_dialog.dart';
import 'cook_wizard_dialog.dart';
import '../../utils/dialog_helper.dart';

/// Read-only view of one menu item: its till figures, its recipe and
/// production, and — for counted lines — its movement ledger.
///
/// Reached by tapping a row body in the Menu Items table. The row's "Edit"
/// action still opens the menu-item form directly.
///
/// A line that is not a menu item (deep link, stale bookmark) redirects to
/// its Grocery detail — this screen never renders a raw-material row.
class MenuItemDetailScreen extends ConsumerWidget {
  const MenuItemDetailScreen({super.key, required this.itemId});

  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref
        .watch(inventoryItemsListProvider)
        .where((i) => i.id == itemId)
        .firstOrNull;

    if (item == null) return _NotFound(itemId: itemId);

    if (item.itemType == 'raw_material') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          context.goNamed(
            AppRoute.groceryDetailName,
            pathParameters: {'itemId': itemId},
          );
        }
      });
      return const SizedBox.shrink();
    }

    final history = ref.watch(itemStockHistoryProvider(itemId));

    return DetailPageScaffold(
      sideFirstOnMobile: false,
      header: _Header(item: item),
      sidePanel: [_AboutPanel(item: item)],
      onRefresh: () => ref.read(inventoryItemsProvider.notifier).refresh(),
      children: [
        _KeyStats(item: item),
        _QuickActions(item: item),
        if (item.trackStock)
          _StockHistoryPanel(item: item, history: history),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _Header extends ConsumerWidget {
  const _Header({required this.item});

  final InventoryItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DetailPageHeader(
      title: item.name,
      subtitle: item.sku,
      onBack: () => context.canPop()
          ? context.pop()
          : context.goNamed(AppRoute.menuItemsName),
      leading: _Thumbnail(item: item),
      badges: [
        StatusBadge(
          label: item.isArchived
              ? AppStrings.archivedBadge
              : AppStrings.activeBadge,
          tone: item.isArchived ? StatusTone.neutral : StatusTone.positive,
          icon: item.isArchived
              ? Icons.archive_outlined
              : Icons.check_circle_rounded,
          dense: true,
        ),
        StatusBadge(
          label: item.status.label,
          tone: item.status.tone,
          icon: item.status.badgeIcon,
          dense: true,
        ),
      ],
      actions: [
        OutlinedButton.icon(
          onPressed: () =>
              showMenuItemFormDialog(context, existingItemId: item.id),
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: Text(AppStrings.editAction),
        ),
        _OverflowMenu(item: item),
      ],
    );
  }
}

/// Maps the stockroom's vocabulary onto the shared badge tones. Local to
/// this screen — Groceries and Menu Items render their own badges.
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

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.item});

  final InventoryItem item;

  static const double _size = 48;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _size,
      width: _size,
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: context.semantic.hairline),
      ),
      child: ItemPhoto(
        emoji: item.emoji,
        emojiSize: 24,
        bytes: item.image?.bytes,
        imageUrl: item.imageUrl,
        catalogItemId: item.catalogItemId,
      ),
    );
  }
}

class _OverflowMenu extends ConsumerWidget {
  const _OverflowMenu({required this.item});

  final InventoryItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      tooltip: AppStrings.moreActions,
      position: PopupMenuPosition.under,
      icon: const Icon(Icons.more_horiz_rounded),
      onSelected: (value) => switch (value) {
        'archive' => _toggleArchive(context, ref),
        'delete' => _confirmDelete(context, ref),
        _ => null,
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'archive',
          child: Row(
            children: [
              Icon(
                item.isArchived
                    ? Icons.unarchive_outlined
                    : Icons.archive_outlined,
                size: 17,
                color: context.colors.onSurfaceVariant,
              ),
              const SizedBox(width: Insets.md),
              Text(
                item.isArchived
                    ? AppStrings.restoreItem
                    : AppStrings.archiveItem,
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(
                Icons.delete_outline_rounded,
                size: 17,
                color: context.semantic.danger,
              ),
              const SizedBox(width: Insets.md),
              Text(
                AppStrings.deleteItem,
                style: TextStyle(color: context.semantic.danger),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _toggleArchive(BuildContext context, WidgetRef ref) async {
    final archived = !item.isArchived;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(inventoryItemsProvider.notifier)
          .upsert(item.copyWith(isArchived: archived));
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            archived
                ? AppStrings.itemArchived(item.name)
                : AppStrings.itemRestored(item.name),
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(AppStrings.saveFailed(e))));
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppStrings.deleteItemTitle(item.name)),
        content: Text(AppStrings.deleteItemBodyFull),
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
    context.canPop()
        ? context.pop()
        : context.goNamed(AppRoute.menuItemsName);

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
}

// ---------------------------------------------------------------------------
// Key stats — till figures plus the recipe's production cost. Stock counts
// are meaningless for an untracked prepared dish, so they never lead here.
// ---------------------------------------------------------------------------

class _KeyStats extends ConsumerWidget {
  const _KeyStats({required this.item});

  final InventoryItem item;

  static const double _fourAcross = 860;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final semantic = context.semantic;
    final onMenu = item.isSellable && !item.isArchived;

    // Production cost from the recipe's raw materials — no labour yet.
    // Resold lines with no formula fall back to their own unit cost; a
    // line with neither reads as an estimate rather than a free dish.
    final recipe = ref
        .watch(recipesCatalogListProvider)
        .where((r) => r.sellableItemId == item.catalogItemId)
        .firstOrNull;
    final productionCost = recipe != null
        ? double.parse(recipe.costPerUnit.toString())
        : item.unitCost;
    final costEstimated =
        recipe == null ? item.unitCost <= 0 : !recipe.costComplete;
    final margin = item.sellingPrice == null
        ? null
        : item.sellingPrice! - productionCost;

    final tiles = [
      SummaryMetricCard(
        label: AppStrings.sellingPrice,
        value: item.sellingPrice == null
            ? AppStrings.emDash
            : Fmt.money(item.sellingPrice!),
        trend: item.sellingPrice == null
            ? AppStrings.notSet
            : AppStrings.atTheTill,
        icon: Icons.point_of_sale_rounded,
      ),
      SummaryMetricCard(
        label: AppStrings.costColumn,
        value: Fmt.money(productionCost),
        trend: recipe == null
            ? AppStrings.costBasis
            : '${recipe.components.length} ingredients${costEstimated ? ' · ${AppStrings.costEstimated}' : ''}',
        icon: Icons.soup_kitchen_outlined,
      ),
      SummaryMetricCard(
        label: AppStrings.marginLabel,
        value: margin == null ? AppStrings.emDash : Fmt.money(margin),
        trend: margin == null
            ? AppStrings.setPriceForMargin
            : AppStrings.perItemSold,
        icon: Icons.trending_up_rounded,
        accent: margin == null
            ? null
            : (margin >= 0 ? semantic.success : semantic.danger),
      ),
      SummaryMetricCard(
        label: AppStrings.posAvailability,
        value: onMenu ? AppStrings.availableValue : AppStrings.notListed,
        trend: onMenu ? AppStrings.showingAtTill : AppStrings.archivedNoPrice,
        icon: onMenu
            ? Icons.check_circle_rounded
            : Icons.remove_circle_outline_rounded,
        accent: onMenu ? semantic.success : semantic.warning,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = Insets.md;
        final columns = constraints.maxWidth >= _fourAcross ? 4 : 2;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final tile in tiles) SizedBox(width: width, child: tile),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Quick actions — production and recipe management only. Stock operations
// belong to counted lines, and counted menu lines are managed from
// Groceries-style flows, not from the till item.
// ---------------------------------------------------------------------------

class _QuickActions extends ConsumerWidget {
  const _QuickActions({required this.item});

  final InventoryItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipeAction = _recipeAction(context, ref);
    final buttons = <Widget>[
      if (_canProduce(ref)) _RecordProductionButton(item: item),
      ?recipeAction,
    ];
    if (buttons.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 520) {
          return Wrap(
            spacing: Insets.md,
            runSpacing: Insets.md,
            children: buttons,
          );
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            children: [
              for (var i = 0; i < buttons.length; i++) ...[
                if (i > 0) const SizedBox(width: Insets.md),
                buttons[i],
              ],
            ],
          ),
        );
      },
    );
  }

  bool _canProduce(WidgetRef ref) {
    final catalogId = item.catalogItemId;
    if (catalogId == null) return false;
    if (!ref.watch(hasPermissionProvider(AppPermissions.productionCreate))) {
      return false;
    }
    return ref
            .watch(recipesCatalogProvider)
            .valueOrNull
            ?.any((recipe) => recipe.sellableItemId == catalogId) ??
        false;
  }

  Widget? _recipeAction(BuildContext context, WidgetRef ref) {
    final catalogId = item.catalogItemId;
    if (catalogId == null) return null;
    final recipe = ref
        .watch(recipesCatalogProvider)
        .valueOrNull
        ?.where((r) => r.sellableItemId == catalogId)
        .firstOrNull;
    if (recipe != null &&
        ref.watch(hasPermissionProvider(AppPermissions.recipesUpdate))) {
      return OutlinedButton.icon(
        onPressed: () => showRecipeFormDialog(context, recipe: recipe),
        icon: const Icon(Icons.receipt_long_outlined, size: 18),
        label: Text(AppStrings.editRecipe),
      );
    }
    if (recipe == null &&
        ref.watch(hasPermissionProvider(AppPermissions.recipesCreate))) {
      return OutlinedButton.icon(
        onPressed: () => showRecipeFormDialog(context, sellable: item),
        icon: const Icon(Icons.add_rounded, size: 18),
        label: Text(AppStrings.addRecipe),
      );
    }
    return null;
  }
}

class _RecordProductionButton extends ConsumerWidget {
  const _RecordProductionButton({required this.item});

  final InventoryItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipe = ref
        .watch(recipesCatalogProvider)
        .valueOrNull
        ?.where((r) => r.sellableItemId == item.catalogItemId)
        .firstOrNull;
    // Simple words, not an empty box: tell staff what to do.
    if (recipe == null) {
      if (!ref.watch(hasPermissionProvider(AppPermissions.recipesCreate))) {
        return const SizedBox.shrink();
      }
      return OutlinedButton.icon(
        onPressed: () => showRecipeFormDialog(context, sellable: item),
        icon: const Icon(Icons.add_rounded, size: 18),
        label: const Text('Add recipe first'),
      );
    }
    if (!ref.watch(hasPermissionProvider(AppPermissions.productionCreate))) {
      return const Text('Ask your manager to cook this.');
    }

    // One simple path: the guided cook wizard, starting at this recipe.
    return FilledButton.icon(
      onPressed: () => showCookWizard(context, recipe: recipe),
      icon: const Icon(Icons.soup_kitchen_outlined, size: 18),
      label: const Text('Cook'),
    );
  }
}

// ---------------------------------------------------------------------------
// Stock history — counted lines only; untracked dishes have no ledger.
// ---------------------------------------------------------------------------

class _StockHistoryPanel extends StatefulWidget {
  const _StockHistoryPanel({required this.item, required this.history});

  final InventoryItem item;
  final List<StockMovement> history;

  @override
  State<_StockHistoryPanel> createState() => _StockHistoryPanelState();
}

class _StockHistoryPanelState extends State<_StockHistoryPanel> {
  int _page = 0;
  String? _group;

  @override
  Widget build(BuildContext context) {
    final query = TableQuery(
      page: _page,
      pageSize: AppLimits.tablePageSizeDense,
      groupField: _group,
    );
    final slice = PageSlice.of(widget.history, query);

    return DetailPanel(
      title: AppStrings.stockHistory,
      trailing: Text(
        AppStrings.movementsCount(widget.history.length),
        style: context.text.bodySmall?.copyWith(
          color: context.colors.onSurfaceVariant,
        ),
      ),
      child: ReusableDataTable<StockMovement>(
        columns: _columns(widget.item),
        slice: slice,
        query: query,
        onSort: (_) {},
        onPageChanged: (page) => setState(() => _page = page),
        groupedItems: widget.history,
        onGroupChanged: (field) => setState(() {
          _group = field;
          _page = 0;
        }),
        emptyState: const _NoHistory(),
      ),
    );
  }

  static List<DataColumnSpec<StockMovement>> _columns(InventoryItem item) => [
    DataColumnSpec(
      label: AppStrings.whenColumn,
      field: 'when',
      role: ColumnRole.primary,
      sortable: false,
      flex: 4,
      value: (m) => Fmt.relativeDateTime(m.at),
      cellBuilder: (context, m) => _WhenCell(movement: m),
    ),
    DataColumnSpec(
      label: AppStrings.typeColumn,
      field: 'type',
      role: ColumnRole.status,
      sortable: false,
      groupable: true,
      width: 132,
      value: (m) => m.type.label,
      cellBuilder: (context, m) => StatusBadge(
        label: m.type.label,
        tone: m.type.tone,
        icon: m.type.icon,
        dense: true,
      ),
    ),
    DataColumnSpec(
      label: AppStrings.changeColumn,
      field: 'delta',
      sortable: false,
      numeric: true,
      flex: 2,
      value: (m) => '${m.deltaLabel} ${item.unit}',
      cellBuilder: (context, m) => _DeltaCell(movement: m),
    ),
    DataColumnSpec(
      label: AppStrings.balanceColumn,
      field: 'balance',
      sortable: false,
      numeric: true,
      flex: 2,
      minTableWidth: 560,
      value: (m) => '${Fmt.quantity(m.balance)} ${item.unit}',
    ),
    DataColumnSpec(
      label: AppStrings.byColumn,
      field: 'actor',
      sortable: false,
      flex: 3,
      minTableWidth: 720,
      value: (m) => m.actor,
    ),
  ];
}

class _WhenCell extends StatelessWidget {
  const _WhenCell({required this.movement});

  final StockMovement movement;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          Fmt.relativeDateTime(movement.at),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.text.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        if (movement.note case final note?)
          Text(
            note,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

class _DeltaCell extends StatelessWidget {
  const _DeltaCell({required this.movement});

  final StockMovement movement;

  @override
  Widget build(BuildContext context) {
    final up = movement.delta >= 0;

    return Text(
      movement.deltaLabel,
      maxLines: 1,
      textAlign: TextAlign.right,
      style: context.text.bodyMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: up ? context.semantic.success : context.semantic.danger,
      ),
    );
  }
}

class _NoHistory extends StatelessWidget {
  const _NoHistory();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Insets.xl),
      child: Column(
        children: [
          Icon(
            Icons.history_rounded,
            size: 28,
            color: context.colors.onSurfaceVariant.withValues(alpha: 0.6),
          ),
          const SizedBox(height: Insets.sm),
          Text(
            AppStrings.noMovementsRecorded,
            style: context.text.bodyMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// About
// ---------------------------------------------------------------------------

class _AboutPanel extends ConsumerWidget {
  const _AboutPanel({required this.item});

  final InventoryItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final hasDescription = item.description.trim().isNotEmpty;
    final onPosMenu = item.isSellable && !item.isArchived;

    return DetailPanel(
      title: AppStrings.aboutThisItem,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            hasDescription
                ? item.description
                : AppStrings.noDescription,
            style: context.text.bodyMedium?.copyWith(
              color: hasDescription ? null : colors.onSurfaceVariant,
              fontStyle: hasDescription ? null : FontStyle.italic,
            ),
          ),
          const SizedBox(height: Insets.lg),
          const Divider(height: 1),
          const SizedBox(height: Insets.lg),
          LabeledValueGrid(
            maxColumns: 2,
            minColumnWidth: 220,
            children: [
              LabeledValue(
                label: AppStrings.itemTypeLabel,
                value: item.itemType == 'sellable'
                    ? AppStrings.itemTypeMenuItem
                    : AppStrings.itemTypeBoth,
                icon: item.itemType == 'sellable'
                    ? Icons.restaurant_menu_rounded
                    : Icons.swap_horiz_rounded,
              ),
              LabeledValue(
                label: AppStrings.categoryLabel,
                value: categoryLabelFrom(
                  ref.watch(categoriesListProvider),
                  item.categoryId,
                ),
                icon: ref.watch(categoryByIdProvider(item.categoryId))?.icon ??
                    Icons.category_outlined,
              ),
              LabeledValue(
                label: AppStrings.skuLabel,
                value: item.sku,
                icon: Icons.qr_code_2_rounded,
              ),
              LabeledValue(
                label: AppStrings.countedIn,
                value: item.unit,
                icon: Icons.straighten_rounded,
              ),
              LabeledValue(
                label: AppStrings.stockTracking,
                value: item.trackStock
                    ? AppStrings.onValue
                    : AppStrings.offValue,
                icon: item.trackStock
                    ? Icons.toggle_on_outlined
                    : Icons.toggle_off_outlined,
              ),
              LabeledValue(
                label: AppStrings.posMenu,
                value: onPosMenu
                    ? AppStrings.availableForSale(
                        Fmt.money(item.sellingPrice ?? 0),
                      )
                    : AppStrings.notForSaleTill,
                icon: onPosMenu
                    ? Icons.point_of_sale_rounded
                    : Icons.point_of_sale_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NotFound extends StatelessWidget {
  const _NotFound({required this.itemId});

  final String itemId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(Insets.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.search_off_rounded,
                  size: 36,
                  color: context.colors.onSurfaceVariant,
                ),
                const SizedBox(height: Insets.md),
                Text(
                  AppStrings.itemNotFound(itemId),
                  style: context.text.titleMedium,
                ),
                const SizedBox(height: Insets.lg),
                FilledButton.icon(
                  onPressed: () => context.goNamed(AppRoute.menuItemsName),
                  icon: const Icon(Icons.restaurant_menu_rounded, size: 18),
                  label: Text(AppStrings.menuItemsTab),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
