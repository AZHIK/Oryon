import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/app_strings.dart';
import '../../models/inventory_item.dart';
import '../../models/permission.dart';
import '../../providers/categories_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/menu_item_form_provider.dart';
import '../../providers/permissions_provider.dart';
import '../../providers/production_provider.dart';
import '../../providers/units_provider.dart';
import '../../services/inventory_api_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/breakpoints.dart';
import '../../utils/formatters.dart';
import '../image_upload_field.dart';
import '../labeled_form_field.dart';
import '../responsive_form_dialog.dart';
import '../section_label.dart';
import '../selectable_option_card.dart';
import '../../screens/inventory/recipe_form_dialog.dart';

/// Opens the add/edit menu-item form over the current screen.
///
/// Menu items always carry a till price. The one switch is stock tracking:
/// ON counts the line (`both` — ordered and received like a grocery), OFF
/// leaves it a prepared-to-order dish (`sellable`). Pass [existingItemId]
/// to edit, omit it to add. There is no route: the form layers over the
/// list, and closing it returns to the same scroll position, filter and
/// page.
///
/// Returns the saved item, or null when dismissed without saving — callers
/// embedding a menu-item pick (e.g. the recipe form's sellable field) use
/// this to select whoever was just added.
Future<InventoryItem?> showMenuItemFormDialog(
  BuildContext context, {
  String? existingItemId,
}) {
  return showResponsiveFormDialog<InventoryItem>(
    context,
    builder: (_) => MenuItemFormDialog(itemId: existingItemId),
  );
}

/// Widget keys for the menu-item form's controls.
abstract final class MenuItemFormKeys {
  static const name = Key('menuItemForm.name');
  static const sku = Key('menuItemForm.sku');
  static const category = Key('menuItemForm.category');
  static const description = Key('menuItemForm.description');
  static const unitCost = Key('menuItemForm.unitCost');
  static const sellingPrice = Key('menuItemForm.sellingPrice');
  static const trackStock = Key('menuItemForm.trackStock');
  static const lowStockAlert = Key('menuItemForm.lowStockAlert');
  static const reorderQuantity = Key('menuItemForm.reorderQuantity');
  static const allowNegativeStock = Key('menuItemForm.allowNegativeStock');
  static const stock = Key('menuItemForm.stock');
  static const unit = Key('menuItemForm.unit');
  static const cancel = Key('menuItemForm.cancel');
  static const submit = Key('menuItemForm.submit');
  static const costSource = Key('menuItemForm.costSource');
  static const recipe = Key('menuItemForm.recipe');
  static const addRecipe = Key('menuItemForm.addRecipe');
  static const recipeCost = Key('menuItemForm.recipeCost');
}

/// The menu-item form itself. Prefer [showMenuItemFormDialog].
class MenuItemFormDialog extends ConsumerStatefulWidget {
  const MenuItemFormDialog({super.key, this.itemId});

  /// Id of the item being edited, or null to add a new one.
  final String? itemId;

  static const double dialogWidth = 640;

  /// The photo column on tablet and desktop.
  static const double _photoColumn = 190;

  /// On a phone the dropzone goes full-width, but capped.
  static const double _photoMobile = 172;

  @override
  ConsumerState<MenuItemFormDialog> createState() =>
      _MenuItemFormDialogState();
}

class _MenuItemFormDialogState extends ConsumerState<MenuItemFormDialog> {
  final _formKey = GlobalKey<FormState>();

  // The controllers hold what the user is typing; the notifier holds the
  // committed value. One-way, controller to notifier.
  final _name = TextEditingController();
  final _sku = TextEditingController();
  final _unitCost = TextEditingController();
  final _sellingPrice = TextEditingController();
  final _lowStock = TextEditingController();
  final _reorderQuantity = TextEditingController();
  final _stock = TextEditingController();
  final _description = TextEditingController();

  bool _seeded = false;
  bool _saving = false;

  /// Backend id of the item under edit, for matching its recipe. Null when
  /// adding — a new item has no recipe to derive from yet.
  String? _catalogItemId;

  /// Standalone recipe picked for this item (produced in-house). Linked
  /// server-side right after the item saves — the backend link is
  /// set-once, so an already-linked item never offers this picker.
  String? _linkedRecipeId;

  AutoDisposeFamilyNotifierProvider<MenuItemFormNotifier, MenuItemFormState, String?>
  get _provider => menuItemFormProvider(widget.itemId);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seeded) return;
    _seeded = true;

    ref.invalidate(_provider);
    final state = ref.read(_provider);

    Future(() {
      if (!mounted) return;
      unawaited(ref.read(categoriesProvider.notifier).refresh());
      unawaited(ref.read(unitsProvider.notifier).refresh());
    });

    _name.text = state.name;
    _sku.text = state.sku;
    _unitCost.text = state.unitCost;
    _sellingPrice.text = state.sellingPrice;
    _lowStock.text = state.lowStockAlert;
    _reorderQuantity.text = state.reorderQuantity;
    _stock.text = state.stock;
    _description.text = state.description;

    if (widget.itemId != null) {
      for (final item in ref.read(inventoryItemsListProvider)) {
        if (item.id == widget.itemId) _catalogItemId = item.catalogItemId;
      }
      // Auto is the default when a complete recipe already prices this
      // item — the number on screen then tracks grocery prices.
      final catalogId = _catalogItemId;
      if (catalogId != null) {
        final hasCompleteRecipe = ref
            .read(recipesCatalogListProvider)
            .any((r) => r.sellableItemId == catalogId && r.costComplete);
        if (hasCompleteRecipe) {
          ref
              .read(_provider.notifier)
              .setCostSource(ItemCostSource.auto);
        }
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _sku.dispose();
    _unitCost.dispose();
    _sellingPrice.dispose();
    _lowStock.dispose();
    _reorderQuantity.dispose();
    _stock.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final form = ref.read(_provider);
    final isEdit = form.isEdit;
    final messenger = ScaffoldMessenger.of(context);

    // Auto never takes a typed cost: a complete recipe snapshots its
    // current cost per unit, anything less stores unknown (zero — the
    // codebase's "no cost on file" sentinel, read as estimated).
    final isAuto = form.costSource == ItemCostSource.auto;
    String? unitCostOverride;
    var autoComplete = false;
    if (isAuto) {
      final recipe = _recipeFor(
        ref.read(recipesCatalogListProvider),
        pickedRecipeId: _linkedRecipeId,
      );
      autoComplete = recipe != null && recipe.costComplete;
      unitCostOverride =
          autoComplete ? recipe.costPerUnit.toString() : "0";
    }
    // An auto item with no complete recipe yet can never be active: it
    // saves archived until a recipe prices it.
    final forceInactive = isAuto && !autoComplete;

    // Backend ids present before the save, so a newly added item's fresh
    // id can be found afterwards for recipe linking (the saved copy is
    // pre-save local state without one).
    final knownIds = {
      for (final item in ref.read(inventoryItemsListProvider))
        if (item.catalogItemId != null) item.catalogItemId!,
    };

    setState(() => _saving = true);
    try {
      final item = await ref
          .read(_provider.notifier)
          .save(
            unitCostOverride: unitCostOverride,
            forceArchived: forceInactive ? true : null,
          );
      // A produced-in-house item links its picked standalone recipe now
      // that the menu item exists server-side.
      final pickedRecipeId = _linkedRecipeId;
      if (pickedRecipeId != null) {
        var sellableId = _catalogItemId;
        if (!isEdit) {
          for (final candidate in ref.read(inventoryItemsListProvider)) {
            final id = candidate.catalogItemId;
            if (id != null && !knownIds.contains(id)) {
              sellableId = id;
              break;
            }
          }
        }
        if (sellableId == null) {
          throw StateError(
            'Item saved but its fresh record was not found — link the recipe from Production instead',
          );
        }
        await ref.read(recipesCatalogProvider.notifier).linkRecipe(
              recipeId: pickedRecipeId,
              sellableItemId: sellableId,
            );
      }
      if (!mounted) return;
      Navigator.of(context).pop(item);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            isEdit
                ? '${item.name} updated'
                : forceInactive
                ? AppStrings.menuItemAddedInactive(item.name)
                : '${item.name} added to inventory',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(AppStrings.saveFailed(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(_provider);
    final isMobile = MediaQuery.sizeOf(context).width < Breakpoints.tablet;

    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: ResponsiveFormDialog(
        title: state.isEdit ? AppStrings.editItemTitle : AppStrings.addMenuItem,
        width: MenuItemFormDialog.dialogWidth,
        actions: [
          OutlinedButton(
            key: MenuItemFormKeys.cancel,
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppStrings.cancel),
          ),
          FilledButton(
            key: MenuItemFormKeys.submit,
            onPressed: state.canSave && !_saving ? _save : null,
            child: Text(
              state.isEdit ? AppStrings.saveChanges : AppStrings.addMenuItem,
            ),
          ),
        ],
        child: isMobile ? _mobileBody(state) : _wideBody(state),
      ),
    );
  }

  /// The recipe pricing the item, if any — matched by backend id, or the
  /// standalone recipe picked in this form (which prices a new item before
  /// it exists server-side). Null when the item is bought, not produced.
  RecipeDto? _recipeFor(List<RecipeDto> recipes, {String? pickedRecipeId}) {
    if (pickedRecipeId != null) {
      for (final recipe in recipes) {
        if (recipe.id == pickedRecipeId) return recipe;
      }
    }
    final catalogId = _catalogItemId;
    if (catalogId == null) return null;
    for (final recipe in recipes) {
      if (recipe.sellableItemId == catalogId) return recipe;
    }
    return null;
  }

  Widget _wideBody(MenuItemFormState state) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: MenuItemFormDialog._photoColumn,
          child: _PhotoSection(
            state: state,
            size: MenuItemFormDialog._photoColumn,
            notifier: ref.read(_provider.notifier),
          ),
        ),
        const SizedBox(width: Insets.xl),
        Expanded(child: _fields(state)),
      ],
    );
  }

  Widget _mobileBody(MenuItemFormState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PhotoSection(
          state: state,
          size: MenuItemFormDialog._photoMobile,
          centered: true,
          notifier: ref.read(_provider.notifier),
        ),
        const SizedBox(height: Insets.xl),
        _fields(state),
      ],
    );
  }

  Widget _fields(MenuItemFormState state) {
    final notifier = ref.read(_provider.notifier);
    final categories = ref.watch(categoriesListProvider);
    // The recipe pricing this item in auto mode. Watched, so a recipe
    // saved moments ago (or a refresh landing mid-dialog) swaps the cost
    // box in without reopening the form. A picked standalone recipe
    // prices a new item before it exists server-side.
    final recipes = ref.watch(recipesCatalogListProvider);
    final autoRecipe =
        _recipeFor(recipes, pickedRecipeId: _linkedRecipeId);
    final isAuto = state.costSource == ItemCostSource.auto;
    final autoComplete = autoRecipe?.costComplete ?? false;
    // Mirrors `_save`'s forcing rule so the toggle never promises an
    // active state the save won't keep.
    final forceInactiveNotice = isAuto && !autoComplete;
    // The till price is always required — auto defers only the unit cost.
    final priceField = LabeledFormField(
      label: AppStrings.sellingPrice,
      isRequired: true,
      helper: AppStrings.priceRequiredTill,
      child: TextFormField(
        key: MenuItemFormKeys.sellingPrice,
        controller: _sellingPrice,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textInputAction: TextInputAction.next,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
        ],
        decoration: InputDecoration(
          hintText: AppStrings.moneyHint,
          prefixText: Fmt.currencySymbol,
        ),
        onChanged: notifier.setSellingPrice,
        validator: MenuItemFormState.validateSellingPrice,
      ),
    );
    final initialCategory =
        state.categoryId.isNotEmpty &&
            categories.any((c) => c.id == state.categoryId)
        ? state.categoryId
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(AppStrings.basicInfo),
        const SizedBox(height: Insets.md),
        LabeledFormField(
          label: AppStrings.itemNameLabel,
          isRequired: true,
          child: TextFormField(
            key: MenuItemFormKeys.name,
            controller: _name,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(hintText: AppStrings.itemNameExample),
            onChanged: notifier.setName,
            validator: MenuItemFormState.validateName,
          ),
        ),
        const SizedBox(height: Insets.lg),
        _RecipeLinkSection(
          existingLink: _recipeFor(recipes),
          linkedRecipeId: _linkedRecipeId,
          draftName: _name.text,
          onChanged: (value) => setState(() => _linkedRecipeId = value),
        ),
        const SizedBox(height: Insets.lg),
        _FieldPair(
          left: LabeledFormField(
            label: AppStrings.categoryLabel,
            isRequired: true,
            child: DropdownButtonFormField<String>(
              key: MenuItemFormKeys.category,
              initialValue: initialCategory,
              isExpanded: true,
              hint: Text(AppStrings.selectOption),
              items: [
                for (final category in categories)
                  DropdownMenuItem(
                    value: category.id,
                    child: Text(
                      category.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) => notifier.setCategory(value ?? ''),
              validator: MenuItemFormState.validateCategory,
            ),
          ),
          right: LabeledFormField(
            label: AppStrings.skuLabel2,
            helper: state.isEdit ? null : AppStrings.skuHelper,
            child: TextFormField(
              key: MenuItemFormKeys.sku,
              controller: _sku,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(hintText: AppStrings.skuExample),
              onChanged: notifier.setSku,
            ),
          ),
        ),
        const SizedBox(height: Insets.lg),
        LabeledFormField(
          label: AppStrings.descriptionLabel,
          helper: AppStrings.descriptionHelper,
          child: TextFormField(
            key: MenuItemFormKeys.description,
            controller: _description,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: AppStrings.descriptionExample,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Radii.md),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Radii.md),
                borderSide: BorderSide(color: context.semantic.hairline),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Radii.md),
                borderSide: BorderSide(
                  color: context.colors.primary,
                  width: 1.5,
                ),
              ),
            ),
            onChanged: notifier.setDescription,
          ),
        ),
        const SizedBox(height: Insets.xl),
        SectionLabel(AppStrings.pricingSection),
        const SizedBox(height: Insets.md),
        Text(
          AppStrings.costSourceLabel,
          style: context.text.bodySmall?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: Insets.xs),
        SegmentedButton<ItemCostSource>(
          key: MenuItemFormKeys.costSource,
          segments: [
            ButtonSegment(
              value: ItemCostSource.auto,
              label: Text(AppStrings.costSourceAuto),
              icon: const Icon(Icons.soup_kitchen_outlined, size: 16),
            ),
            ButtonSegment(
              value: ItemCostSource.manual,
              label: Text(AppStrings.costSourceManual),
              icon: const Icon(Icons.edit_outlined, size: 16),
            ),
          ],
          selected: {state.costSource},
          showSelectedIcon: false,
          onSelectionChanged: (selected) =>
              notifier.setCostSource(selected.first),
        ),
        if (isAuto && autoComplete) ...[
          const SizedBox(height: Insets.sm),
          Text(
            AppStrings.costAutoHelper(autoRecipe!.components.length),
            style: context.text.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ] else if (isAuto) ...[
          const SizedBox(height: Insets.sm),
          Text(
            autoRecipe == null
                ? AppStrings.costNoRecipeHint
                : AppStrings.costAutoIncompleteHint,
            style: context.text.bodySmall?.copyWith(
              color: context.semantic.warning,
            ),
          ),
        ],
        const SizedBox(height: Insets.lg),
        // Auto shows the recipe's live cost beside the price so the margin
        // is visible while typing — manual keeps the cost+price pair with
        // a typed cost. Without a complete recipe there is no cost to show,
        // so the price takes the full width under the warning above.
        if (isAuto && autoComplete)
          _FieldPair(
            left: _ReadOnlyCost(
              cost: double.parse(autoRecipe!.costPerUnit.toString()),
              helper: AppStrings.costAutoHelper(autoRecipe.components.length),
            ),
            right: priceField,
          )
        else if (isAuto)
          priceField
        else
          _FieldPair(
            left: LabeledFormField(
              label: AppStrings.unitCostLabel,
              isRequired: true,
              child: TextFormField(
                key: MenuItemFormKeys.unitCost,
                controller: _unitCost,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.next,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*\.?\d{0,2}')),
                ],
                decoration: InputDecoration(
                  hintText: AppStrings.moneyHint,
                  prefixText: Fmt.currencySymbol,
                ),
                onChanged: notifier.setUnitCost,
                validator: MenuItemFormState.validateUnitCost,
              ),
            ),
            right: priceField,
          ),
        if (isAuto && autoComplete) ...[
          const SizedBox(height: Insets.sm),
          _MarginPreview(
            cost: double.parse(autoRecipe!.costPerUnit.toString()),
            sellingPrice: double.tryParse(state.sellingPrice.trim()),
          ),
        ],
        const SizedBox(height: Insets.xl),
        SectionLabel(AppStrings.stockSection),
        const SizedBox(height: Insets.md),
        // The one switch on this form: counted (`both`) or
        // prepared-to-order (`sellable`). It governs the fields under it.
        _SwitchTile(
          key: MenuItemFormKeys.trackStock,
          title: AppStrings.trackStockLabel,
          subtitleOn: AppStrings.trackStockOn,
          subtitleOff: AppStrings.trackStockOff,
          value: state.trackStock,
          onChanged: notifier.setTrackStock,
        ),
        if (state.trackStock) ...[
          const SizedBox(height: Insets.lg),
          _FieldPair(
            left: state.isEdit
                ? _ReadOnlyStock(value: state.stock, unit: state.unit)
                : LabeledFormField(
                    label: AppStrings.openingStock,
                    helper: AppStrings.openingStockHelper,
                    child: TextFormField(
                      key: MenuItemFormKeys.stock,
                      controller: _stock,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        hintText: AppStrings.quantityHint,
                      ),
                      onChanged: notifier.setStock,
                      validator: MenuItemFormState.validateStock,
                    ),
                  ),
            right: LabeledFormField(
              label: AppStrings.unitLabel,
              child: Builder(
                builder: (_) {
                  final abbreviations = [
                    for (final unit in ref.watch(unitsListProvider))
                      unit.abbreviation,
                  ];
                  final options = abbreviations.isEmpty
                      ? [state.unit]
                      : abbreviations;
                  return DropdownButtonFormField<String>(
                    key: MenuItemFormKeys.unit,
                    initialValue: options.contains(state.unit)
                        ? state.unit
                        : options.first,
                    isExpanded: true,
                    items: [
                      for (final unit in options)
                        DropdownMenuItem(value: unit, child: Text(unit)),
                    ],
                    onChanged: (value) =>
                        notifier.setUnit(value ?? state.unit),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: Insets.lg),
          _FieldPair(
            left: LabeledFormField(
              label: AppStrings.lowAlertLabel,
              helper: AppStrings.lowAlertHelper,
              child: TextFormField(
                key: MenuItemFormKeys.lowStockAlert,
                controller: _lowStock,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  hintText: AppStrings.quantityHint,
                ),
                onChanged: notifier.setLowStockAlert,
                validator: MenuItemFormState.validateLowStockAlert,
              ),
            ),
            right: LabeledFormField(
              label: AppStrings.reorderQtyLabel,
              helper: AppStrings.reorderQtyHelper,
              child: TextFormField(
                key: MenuItemFormKeys.reorderQuantity,
                controller: _reorderQuantity,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  hintText: AppStrings.quantityHint,
                ),
                onChanged: notifier.setReorderQuantity,
                validator: MenuItemFormState.validateReorderQuantity,
              ),
            ),
          ),
          const SizedBox(height: Insets.lg),
          _SwitchTile(
            key: MenuItemFormKeys.allowNegativeStock,
            title: AppStrings.allowNegativeLabel,
            subtitleOn: AppStrings.allowNegativeOn,
            subtitleOff: AppStrings.allowNegativeOff,
            value: state.allowNegativeStock,
            onChanged: notifier.setAllowNegativeStock,
          ),
        ],
        const SizedBox(height: Insets.xl),
        SectionLabel(AppStrings.statusSection),
        const SizedBox(height: Insets.md),
        if (forceInactiveNotice)
          const _InactiveNotice()
        else
          SelectableOptionGrid(
          perRow: 2,
          children: [
            SelectableOptionCard(
              label: AppStrings.activeOption,
              subtitle: AppStrings.activeOptionBlurb,
              icon: Icons.check_circle_outline_rounded,
              selected: !state.isArchived,
              onTap: () => notifier.setArchived(false),
            ),
            SelectableOptionCard(
              label: AppStrings.archivedOption,
              subtitle: AppStrings.archivedOptionBlurb,
              icon: Icons.archive_outlined,
              selected: state.isArchived,
              onTap: () => notifier.setArchived(true),
            ),
          ],
        ),
      ],
    );
  }
}

/// Produced-in-house link: pick the standalone recipe this menu item is
/// made from, if any — or create the formula on the spot. Sits right under
/// the item name so a produced dish gets its recipe before anything else.
///
/// Hidden when the item is already linked (links are set-once server-side,
/// never moved) and when the session may neither link nor create — a dead
/// control would only ever 403. The create button stays visible even with
/// no standalone recipes yet: the first formula has to come from somewhere.
class _RecipeLinkSection extends ConsumerWidget {
  const _RecipeLinkSection({
    required this.existingLink,
    required this.linkedRecipeId,
    required this.onChanged,
    this.draftName,
  });

  final RecipeDto? existingLink;
  final String? linkedRecipeId;
  final ValueChanged<String?> onChanged;

  /// What the user has typed as the item name so far — offered as the new
  /// recipe's default name so the kitchen doesn't type it twice.
  final String? draftName;

  /// Opens a blank recipe form above this dialog and selects whatever was
  /// just created. The new row is found by diffing standalone ids:
  /// `createRecipe()` refreshes the catalog before the recipe form pops,
  /// which makes the new id appear exactly once.
  Future<void> _createRecipe(BuildContext context, WidgetRef ref) async {
    final before = {
      for (final recipe in ref.read(standaloneRecipesProvider)) recipe.id,
    };
    final trimmed = (draftName ?? '').trim();
    await showRecipeFormDialog(
      context,
      initialName: trimmed.isEmpty ? null : trimmed,
    );
    if (!context.mounted) return;
    String? freshId;
    for (final recipe in ref.read(standaloneRecipesProvider)) {
      if (!before.contains(recipe.id)) {
        freshId = recipe.id;
        break;
      }
    }
    if (freshId != null) onChanged(freshId);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (existingLink != null) {
      return LabeledFormField(
        label: AppStrings.menuItemRecipeLabel,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
          decoration: BoxDecoration(
            color:
                context.colors.surfaceContainerHigh.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(Radii.pill),
            border: Border.all(color: context.semantic.hairline),
          ),
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              Icon(
                Icons.soup_kitchen_outlined,
                size: 15,
                color: context.colors.onSurfaceVariant,
              ),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: Text(
                  existingLink!.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final canLink =
        ref.watch(hasPermissionProvider(AppPermissions.recipesUpdate));
    final canCreate =
        ref.watch(hasPermissionProvider(AppPermissions.recipesCreate));
    if (!canLink && !canCreate) return const SizedBox.shrink();
    final standalone = ref.watch(standaloneRecipesProvider);

    return LabeledFormField(
      label: AppStrings.menuItemRecipeLabel,
      helper: AppStrings.menuItemRecipeHelper,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: canLink
                ? DropdownButtonFormField<String>(
                    key: MenuItemFormKeys.recipe,
                    initialValue:
                        standalone.any((r) => r.id == linkedRecipeId)
                            ? linkedRecipeId
                            : null,
                    isExpanded: true,
                    hint: Text(AppStrings.selectHint),
                    items: [
                      DropdownMenuItem(
                        child: Text(
                          AppStrings.menuItemRecipeNone,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      for (final recipe in standalone)
                        DropdownMenuItem(
                          value: recipe.id,
                          child: Text(
                            recipe.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: onChanged,
                  )
                : const SizedBox.shrink(),
          ),
          if (canCreate) ...[
            if (canLink) const SizedBox(width: Insets.sm),
            IconButton.filledTonal(
              key: MenuItemFormKeys.addRecipe,
              tooltip: AppStrings.addRecipeTitle,
              onPressed: () => _createRecipe(context, ref),
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ],
      ),
    );
  }
}

class _PhotoSection extends StatelessWidget {
  const _PhotoSection({
    required this.state,
    required this.size,
    required this.notifier,
    this.centered = false,
  });

  final MenuItemFormState state;
  final double size;
  final MenuItemFormNotifier notifier;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final field = ImageUploadField(
      image: state.imageBytes,
      size: size,
      onPicked: notifier.setImage,
      onRemoved: notifier.clearImage,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(AppStrings.photoSection),
        const SizedBox(height: Insets.md),
        if (centered) Center(child: field) else field,
        if (state.image != null) ...[
          const SizedBox(height: Insets.sm),
          Text(
            state.image!.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: centered ? TextAlign.center : TextAlign.start,
            style: context.text.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _FieldPair extends StatelessWidget {
  const _FieldPair({required this.left, required this.right});

  final Widget left;
  final Widget right;

  static const double _stackBelow = 280;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < _stackBelow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              left,
              const SizedBox(height: Insets.lg),
              right,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: left),
            const SizedBox(width: Insets.md),
            Expanded(child: right),
          ],
        );
      },
    );
  }
}

class _ReadOnlyStock extends StatelessWidget {
  const _ReadOnlyStock({required this.value, required this.unit});
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return LabeledFormField(
      label: AppStrings.currentStockReadonly,
      helper: AppStrings.adjustFlowHint,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHigh.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(Radii.pill),
          border: Border.all(color: context.semantic.hairline),
        ),
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Icon(
              Icons.lock_outline_rounded,
              size: 15,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(width: Insets.sm),
            Expanded(
              child: Text(
                AppStrings.stockValue(value, unit),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The recipe's live cost per unit in auto mode: read-only, re-derived on
/// every build so grocery price changes landing mid-dialog show at once.
/// Mirrors [_ReadOnlyStock]'s surface so the pair reads as family.
class _ReadOnlyCost extends StatelessWidget {
  const _ReadOnlyCost({required this.cost, required this.helper});

  final double cost;
  final String helper;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return LabeledFormField(
      key: MenuItemFormKeys.recipeCost,
      label: AppStrings.unitCostLabel,
      helper: helper,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHigh.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(Radii.pill),
          border: Border.all(color: context.semantic.hairline),
        ),
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Icon(
              Icons.soup_kitchen_outlined,
              size: 15,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(width: Insets.sm),
            Expanded(
              child: Text(
                Fmt.money(cost),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Live margin under the auto cost+price pair: what the till keeps per item
/// at the typed price. Rebuilds with the form state, so typing the price
/// prices the margin at once.
class _MarginPreview extends StatelessWidget {
  const _MarginPreview({required this.cost, required this.sellingPrice});

  final double cost;
  final double? sellingPrice;

  @override
  Widget build(BuildContext context) {
    final price = sellingPrice;
    if (price == null || price <= 0) {
      return Text(
        AppStrings.setPriceForMargin,
        style: context.text.bodySmall?.copyWith(
          color: context.colors.onSurfaceVariant,
        ),
      );
    }
    final margin = price - cost;
    return Text(
      '${AppStrings.marginLabel}: ${Fmt.money(margin)} (${Fmt.percent(margin / price)})',
      style: context.text.bodySmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: margin >= 0
            ? context.semantic.success
            : context.semantic.danger,
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    super.key,
    required this.title,
    required this.subtitleOn,
    required this.subtitleOff,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitleOn;
  final String subtitleOff;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Material(
      color: colors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        side: BorderSide(color: context.semantic.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        dense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Insets.lg,
          vertical: Insets.xs,
        ),
        title: Text(title, style: context.text.bodyMedium),
        subtitle: Text(
          value ? subtitleOn : subtitleOff,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: context.text.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// Replaces the Active/Archived toggle while auto mode can't activate the
/// item yet — a toggle there would promise a state the save won't keep.
/// Mirrors `_SwitchTile`'s surface so the section keeps its shape.
class _InactiveNotice extends StatelessWidget {
  const _InactiveNotice();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Material(
      color: colors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        side: BorderSide(color: context.semantic.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.lg,
          vertical: Insets.md,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.archive_outlined,
              size: 20,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(width: Insets.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.inactiveUntilReadyTitle,
                    style: context.text.bodyMedium,
                  ),
                  const SizedBox(height: Insets.xs),
                  Text(
                    AppStrings.inactiveUntilReadyBody,
                    style: context.text.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
