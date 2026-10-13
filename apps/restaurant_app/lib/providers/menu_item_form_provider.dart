import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/inventory_item.dart';
import '../constants/app_limits.dart';
import '../constants/app_strings.dart';
import 'inventory_provider.dart';

/// Where the menu-item form takes the unit cost from.
///
/// `auto` snapshots the linked recipe's current cost per unit at save time;
/// every display and report already re-derives that recipe cost live (see
/// `lib/utils/cogs.dart`), so the number on screen keeps tracking grocery
/// prices. `manual` keeps today's behaviour: the typed value is the cost.
enum ItemCostSource { auto, manual }

/// Everything the menu-item form is holding, mid-edit.
///
/// Menu items always carry a till price. Stock tracking is the one switch:
/// ON means the line is counted (`both` — a bottled drink bought and
/// resold, ordered and received like a grocery); OFF means a
/// prepared-to-order dish (`sellable`) with no count behind it. The switch
/// maps onto the backend's existing `item_type`, so the choice survives a
/// sync — there is no `track_stock` column to persist instead.
///
/// Numbers stay as the strings the user typed; parsing happens at the
/// validator and at save.
@immutable
class MenuItemFormState {
  const MenuItemFormState({
    required this.isEdit,
    required this.name,
    required this.categoryId,
    required this.sku,
    required this.unitCost,
    required this.sellingPrice,
    required this.trackStock,
    required this.lowStockAlert,
    required this.stock,
    required this.unit,
    required this.isArchived,
    this.costSource = ItemCostSource.manual,
    this.description = '',
    this.image,
    this.imageCleared = false,
    this.reorderQuantity = '',
    this.allowNegativeStock = false,
  });

  /// Blank form for a new menu item: untracked prepared dish until the
  /// cook says otherwise. Manual cost — a new item has no recipe to
  /// derive from yet.
  factory MenuItemFormState.blank() => const MenuItemFormState(
    isEdit: false,
    name: '',
    categoryId: '',
    sku: '',
    unitCost: '',
    sellingPrice: '',
    trackStock: false,
    lowStockAlert: '',
    stock: '0',
    unit: 'ea',
    isArchived: false,
  );

  factory MenuItemFormState.from(InventoryItem item) => MenuItemFormState(
    isEdit: true,
    name: item.name,
    categoryId: item.categoryId,
    sku: item.sku,
    unitCost: item.unitCost.toStringAsFixed(2),
    sellingPrice: item.sellingPrice?.toStringAsFixed(2) ?? '',
    // A `both` line is the tracked kind of menu item; `sellable` is not.
    trackStock: item.itemType != 'sellable',
    lowStockAlert: item.reorderLevel.toString(),
    stock: item.stock.toString(),
    unit: item.unit,
    isArchived: item.isArchived,
    description: item.description,
    image: item.image,
    reorderQuantity: item.reorderQuantity.toString(),
    allowNegativeStock: item.allowNegativeStock,
  );

  final bool isEdit;
  final String name;
  final String categoryId;
  final String sku;
  final String description;
  final String unitCost;

  /// Required: a menu item with no price would silently vanish from the POS
  /// menu instead of reading as "not for sale yet".
  final String sellingPrice;

  /// Auto snapshots the recipe cost at save; manual stores the typed value.
  /// Displayed costs always re-derive live — this only decides the write.
  final ItemCostSource costSource;

  final bool trackStock;
  final String lowStockAlert;
  final String stock;
  final String unit;
  final bool isArchived;
  final ItemImage? image;
  final bool imageCleared;
  final String reorderQuantity;
  final bool allowNegativeStock;

  Uint8List? get imageBytes => image?.bytes;

  /// The backend type this form saves as. The tracking switch is the only
  /// thing that decides it.
  String get effectiveItemType => trackStock ? 'both' : 'sellable';

  // -------------------------------------------------------------------
  // Validation — static and pure so the field validators and the Save
  // button's enabled state answer the same question.
  // -------------------------------------------------------------------

  static String? validateName(String? value) =>
      (value ?? '').trim().isEmpty ? AppStrings.giveItemName : null;

  static String? validateCategory(String? value) =>
      (value ?? '').isEmpty ? AppStrings.pickCategory : null;

  static String? validateUnitCost(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return AppStrings.enterUnitCost;
    final parsed = double.tryParse(text);
    if (parsed == null) return AppStrings.enterNumberError;
    if (parsed < 0) return AppStrings.negativeCost;
    return null;
  }

  static String? validateSellingPrice(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return AppStrings.sellingPriceRequired;
    final parsed = double.tryParse(text);
    if (parsed == null) return AppStrings.enterNumberError;
    if (parsed < 0) return AppStrings.negativeNumber;
    return null;
  }

  static String? validateLowStockAlert(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    final parsed = double.tryParse(text);
    if (parsed == null) return AppStrings.enterNumberError;
    if (parsed < 0) return AppStrings.negativeNumber;
    return null;
  }

  static String? validateStock(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    final parsed = double.tryParse(text);
    if (parsed == null) return AppStrings.enterNumberError;
    if (parsed < 0) return AppStrings.negativeNumber;
    return null;
  }

  static String? validateReorderQuantity(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    final parsed = double.tryParse(text);
    if (parsed == null) return AppStrings.enterNumberError;
    if (parsed < 0) return AppStrings.negativeNumber;
    return null;
  }

  bool get canSave =>
      validateName(name) == null &&
      validateCategory(categoryId) == null &&
      // Auto never asks for a cost: a complete recipe snapshots at save,
      // anything less saves unknown (zero — the codebase's "no cost on
      // file" sentinel, read as estimated everywhere). Manual keeps the
      // required typed field.
      (costSource == ItemCostSource.manual
          ? validateUnitCost(unitCost) == null
          : true) &&
      validateSellingPrice(sellingPrice) == null &&
      (!trackStock ||
          (validateLowStockAlert(lowStockAlert) == null &&
              validateStock(stock) == null &&
              validateReorderQuantity(reorderQuantity) == null));

  MenuItemFormState copyWith({
    String? name,
    String? categoryId,
    String? sku,
    String? unitCost,
    String? sellingPrice,
    bool? trackStock,
    String? lowStockAlert,
    String? stock,
    String? unit,
    bool? isArchived,
    ItemCostSource? costSource,
    String? description,
    ItemImage? image,
    String? reorderQuantity,
    bool? allowNegativeStock,
    bool clearImage = false,
  }) {
    return MenuItemFormState(
      isEdit: isEdit,
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
      sku: sku ?? this.sku,
      unitCost: unitCost ?? this.unitCost,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      trackStock: trackStock ?? this.trackStock,
      lowStockAlert: lowStockAlert ?? this.lowStockAlert,
      stock: stock ?? this.stock,
      unit: unit ?? this.unit,
      isArchived: isArchived ?? this.isArchived,
      costSource: costSource ?? this.costSource,
      description: description ?? this.description,
      image: clearImage ? null : (image ?? this.image),
      imageCleared: clearImage ? true : (image != null ? false : imageCleared),
      reorderQuantity: reorderQuantity ?? this.reorderQuantity,
      allowNegativeStock: allowNegativeStock ?? this.allowNegativeStock,
    );
  }
}

/// One form's worth of edit state, keyed by the id being edited — or null
/// for add mode.
class MenuItemFormNotifier
    extends AutoDisposeFamilyNotifier<MenuItemFormState, String?> {
  @override
  MenuItemFormState build(String? itemId) {
    if (itemId == null) return MenuItemFormState.blank();

    // `read`, not `watch`: the form is a snapshot taken when it opened.
    for (final item in ref.read(inventoryItemsListProvider)) {
      if (item.id == itemId) return MenuItemFormState.from(item);
    }
    return MenuItemFormState.blank();
  }

  void setName(String value) => state = state.copyWith(name: value);
  void setCategory(String value) => state = state.copyWith(categoryId: value);
  void setSku(String value) => state = state.copyWith(sku: value);
  void setDescription(String value) =>
      state = state.copyWith(description: value);
  void setUnitCost(String value) => state = state.copyWith(unitCost: value);
  void setSellingPrice(String value) =>
      state = state.copyWith(sellingPrice: value);
  void setUnit(String value) => state = state.copyWith(unit: value);
  void setStock(String value) => state = state.copyWith(stock: value);
  void setArchived(bool value) => state = state.copyWith(isArchived: value);

  void setLowStockAlert(String value) =>
      state = state.copyWith(lowStockAlert: value);

  void setReorderQuantity(String value) =>
      state = state.copyWith(reorderQuantity: value);

  void setAllowNegativeStock(bool value) =>
      state = state.copyWith(allowNegativeStock: value);

  void setTrackStock(bool value) => state = state.copyWith(trackStock: value);

  void setCostSource(ItemCostSource value) =>
      state = state.copyWith(costSource: value);

  void setImage(String name, Uint8List bytes) => state = state.copyWith(
    image: ItemImage(name: name, bytes: bytes),
  );

  void clearImage() => state = state.copyWith(clearImage: true);

  /// Writes the form back to the inventory list and returns what was saved.
  ///
  /// [unitCostOverride] carries auto mode: the recipe's computed cost per
  /// unit, stored as the item's fallback cost. Displays and reports keep
  /// re-deriving the live recipe cost (see `lib/utils/cogs.dart`), so the
  /// number on screen tracks grocery prices while this column stays a
  /// fallback for items whose recipe is removed or incomplete.
  ///
  /// [forceArchived] pins the item inactive regardless of the status
  /// toggle — the dialog passes true when auto mode has no complete
  /// recipe yet, so a dish that can't be costed can never reach the till.
  Future<InventoryItem> save({
    String? unitCostOverride,
    bool? forceArchived,
  }) async {
    final inventory = ref.read(inventoryItemsProvider.notifier);

    InventoryItem? existing;
    if (arg != null) {
      for (final item in ref.read(inventoryItemsListProvider)) {
        if (item.id == arg) existing = item;
      }
    }

    final name = state.name.trim();
    final unitCost =
        double.tryParse((unitCostOverride ?? state.unitCost).trim()) ?? 0;
    final reorderLevel = double.tryParse(state.lowStockAlert.trim()) ?? 0;
    final reorderQuantity = double.tryParse(state.reorderQuantity.trim()) ?? 0;
    final sku = state.sku.trim();
    final sellingPrice = double.tryParse(state.sellingPrice.trim());
    final itemType = state.effectiveItemType;

    final item = existing != null
        ? existing.copyWith(
            name: name,
            categoryId: state.categoryId,
            sku: sku.isEmpty ? existing.sku : sku,
            unitCost: unitCost,
            reorderLevel: reorderLevel,
            reorderQuantity: reorderQuantity,
            allowNegativeStock: state.allowNegativeStock,
            unit: state.unit,
            trackStock: state.trackStock,
            isArchived: forceArchived ?? state.isArchived,
            description: state.description.trim(),
            image: state.image,
            clearImage: state.image == null,
            sellingPrice: sellingPrice,
            clearSellingPrice: sellingPrice == null,
            isSellable: sellingPrice != null,
            itemType: itemType,
            // Stock moves through the Stock Adjust flow, which records why.
          )
        : InventoryItem(
            id: inventory.nextId(),
            sku: sku.isEmpty ? _generatedSku(name) : sku,
            name: name,
            categoryId: state.categoryId,
            emoji: '📦',
            stock: double.tryParse(state.stock.trim()) ?? 0,
            reorderLevel: reorderLevel,
            reorderQuantity: reorderQuantity,
            allowNegativeStock: state.allowNegativeStock,
            unitCost: unitCost,
            unit: state.unit,
            trackStock: state.trackStock,
            isArchived: forceArchived ?? state.isArchived,
            description: state.description.trim(),
            image: state.image,
            sellingPrice: sellingPrice,
            isSellable: sellingPrice != null,
            itemType: itemType,
          );

    await inventory.upsert(
      item,
      deleteRemoteImage: state.imageCleared && (existing?.imageUrl != null),
    );
    return item;
  }

  static String _generatedSku(String name) {
    final letters = name.toUpperCase().replaceAll(RegExp('[^A-Z]'), '');
    final prefix = letters.isEmpty
        ? 'NEW'
        : letters.substring(0, letters.length < 3 ? letters.length : 3);
    return '$prefix-${DateTime.now().millisecondsSinceEpoch % AppLimits.skuSuffixMod}';
  }
}

/// Keyed by the item id under edit, or null when adding.
final menuItemFormProvider = NotifierProvider.autoDispose
    .family<MenuItemFormNotifier, MenuItemFormState, String?>(
      MenuItemFormNotifier.new,
    );
