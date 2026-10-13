import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/app_strings.dart';
import '../../providers/categories_provider.dart';
import '../../providers/grocery_form_provider.dart';
import '../../providers/units_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/breakpoints.dart';
import '../../utils/formatters.dart';
import '../image_upload_field.dart';
import '../labeled_form_field.dart';
import '../responsive_form_dialog.dart';
import '../section_label.dart';
import '../selectable_option_card.dart';

/// Opens the add/edit grocery form over the current screen.
///
/// Groceries are `raw_material` lines and always stock-tracked — this form
/// has no type choice and no tracking toggle. Pass [existingItemId] to
/// edit, omit it to add. There is no route: the form layers over the list,
/// and closing it returns to the same scroll position, filter and page.
Future<void> showGroceryFormDialog(
  BuildContext context, {
  String? existingItemId,
}) {
  return showResponsiveFormDialog<void>(
    context,
    builder: (_) => GroceryFormDialog(itemId: existingItemId),
  );
}

/// Widget keys for the grocery form's controls.
abstract final class GroceryFormKeys {
  static const name = Key('groceryForm.name');
  static const sku = Key('groceryForm.sku');
  static const category = Key('groceryForm.category');
  static const description = Key('groceryForm.description');
  static const unitCost = Key('groceryForm.unitCost');
  static const lowStockAlert = Key('groceryForm.lowStockAlert');
  static const reorderQuantity = Key('groceryForm.reorderQuantity');
  static const allowNegativeStock = Key('groceryForm.allowNegativeStock');
  static const stock = Key('groceryForm.stock');
  static const unit = Key('groceryForm.unit');
  static const cancel = Key('groceryForm.cancel');
  static const submit = Key('groceryForm.submit');
}

/// The grocery form itself. Prefer [showGroceryFormDialog].
class GroceryFormDialog extends ConsumerStatefulWidget {
  const GroceryFormDialog({super.key, this.itemId});

  /// Id of the item being edited, or null to add a new one.
  final String? itemId;

  static const double dialogWidth = 640;

  /// The photo column on tablet and desktop.
  static const double _photoColumn = 190;

  /// On a phone the dropzone goes full-width, but capped.
  static const double _photoMobile = 172;

  @override
  ConsumerState<GroceryFormDialog> createState() => _GroceryFormDialogState();
}

class _GroceryFormDialogState extends ConsumerState<GroceryFormDialog> {
  final _formKey = GlobalKey<FormState>();

  // The controllers hold what the user is typing; the notifier holds the
  // committed value. One-way, controller to notifier.
  final _name = TextEditingController();
  final _sku = TextEditingController();
  final _unitCost = TextEditingController();
  final _lowStock = TextEditingController();
  final _reorderQuantity = TextEditingController();
  final _stock = TextEditingController();
  final _description = TextEditingController();

  bool _seeded = false;
  bool _saving = false;

  AutoDisposeFamilyNotifierProvider<GroceryFormNotifier, GroceryFormState, String?>
  get _provider => groceryFormProvider(widget.itemId);

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
    _lowStock.text = state.lowStockAlert;
    _reorderQuantity.text = state.reorderQuantity;
    _stock.text = state.stock;
    _description.text = state.description;
  }

  @override
  void dispose() {
    _name.dispose();
    _sku.dispose();
    _unitCost.dispose();
    _lowStock.dispose();
    _reorderQuantity.dispose();
    _stock.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final isEdit = ref.read(_provider).isEdit;
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _saving = true);
    try {
      final item = await ref.read(_provider.notifier).save();
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            isEdit ? '${item.name} updated' : '${item.name} added to inventory',
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
        title: state.isEdit
            ? AppStrings.editItemTitle
            : AppStrings.addGroceryItem,
        width: GroceryFormDialog.dialogWidth,
        actions: [
          OutlinedButton(
            key: GroceryFormKeys.cancel,
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppStrings.cancel),
          ),
          FilledButton(
            key: GroceryFormKeys.submit,
            onPressed: state.canSave && !_saving ? _save : null,
            child: Text(
              state.isEdit
                  ? AppStrings.saveChanges
                  : AppStrings.addGroceryItem,
            ),
          ),
        ],
        child: isMobile ? _mobileBody(state) : _wideBody(state),
      ),
    );
  }

  Widget _wideBody(GroceryFormState state) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: GroceryFormDialog._photoColumn,
          child: _PhotoSection(
            state: state,
            size: GroceryFormDialog._photoColumn,
            notifier: ref.read(_provider.notifier),
          ),
        ),
        const SizedBox(width: Insets.xl),
        Expanded(child: _fields(state)),
      ],
    );
  }

  Widget _mobileBody(GroceryFormState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PhotoSection(
          state: state,
          size: GroceryFormDialog._photoMobile,
          centered: true,
          notifier: ref.read(_provider.notifier),
        ),
        const SizedBox(height: Insets.xl),
        _fields(state),
      ],
    );
  }

  Widget _fields(GroceryFormState state) {
    final notifier = ref.read(_provider.notifier);
    final categories = ref.watch(categoriesListProvider);
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
            key: GroceryFormKeys.name,
            controller: _name,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(hintText: AppStrings.itemNameExample),
            onChanged: notifier.setName,
            validator: GroceryFormState.validateName,
          ),
        ),
        const SizedBox(height: Insets.lg),
        _FieldPair(
          left: LabeledFormField(
            label: AppStrings.categoryLabel,
            isRequired: true,
            child: DropdownButtonFormField<String>(
              key: GroceryFormKeys.category,
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
              validator: GroceryFormState.validateCategory,
            ),
          ),
          right: LabeledFormField(
            label: AppStrings.skuLabel2,
            helper: state.isEdit ? null : AppStrings.skuHelper,
            child: TextFormField(
              key: GroceryFormKeys.sku,
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
            key: GroceryFormKeys.description,
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
        LabeledFormField(
          label: AppStrings.unitCostLabel,
          isRequired: true,
          child: TextFormField(
            key: GroceryFormKeys.unitCost,
            controller: _unitCost,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            decoration: InputDecoration(
              hintText: AppStrings.moneyHint,
              prefixText: Fmt.currencySymbol,
            ),
            onChanged: notifier.setUnitCost,
            validator: GroceryFormState.validateUnitCost,
          ),
        ),
        const SizedBox(height: Insets.xl),
        SectionLabel(AppStrings.stockSection),
        const SizedBox(height: Insets.md),
        _FieldPair(
          left: state.isEdit
              ? _ReadOnlyStock(value: state.stock, unit: state.unit)
              : LabeledFormField(
                  label: AppStrings.openingStock,
                  helper: AppStrings.openingStockHelper,
                  child: TextFormField(
                    key: GroceryFormKeys.stock,
                    controller: _stock,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      hintText: AppStrings.quantityHint,
                    ),
                    onChanged: notifier.setStock,
                    validator: GroceryFormState.validateStock,
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
                  key: GroceryFormKeys.unit,
                  initialValue: options.contains(state.unit)
                      ? state.unit
                      : options.first,
                  isExpanded: true,
                  items: [
                    for (final unit in options)
                      DropdownMenuItem(value: unit, child: Text(unit)),
                  ],
                  onChanged: (value) => notifier.setUnit(value ?? state.unit),
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
              key: GroceryFormKeys.lowStockAlert,
              controller: _lowStock,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(hintText: AppStrings.quantityHint),
              onChanged: notifier.setLowStockAlert,
              validator: GroceryFormState.validateLowStockAlert,
            ),
          ),
          right: LabeledFormField(
            label: AppStrings.reorderQtyLabel,
            helper: AppStrings.reorderQtyHelper,
            child: TextFormField(
              key: GroceryFormKeys.reorderQuantity,
              controller: _reorderQuantity,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(hintText: AppStrings.quantityHint),
              onChanged: notifier.setReorderQuantity,
              validator: GroceryFormState.validateReorderQuantity,
            ),
          ),
        ),
        const SizedBox(height: Insets.lg),
        _SwitchTile(
          key: GroceryFormKeys.allowNegativeStock,
          title: AppStrings.allowNegativeLabel,
          subtitleOn: AppStrings.allowNegativeOn,
          subtitleOff: AppStrings.allowNegativeOff,
          value: state.allowNegativeStock,
          onChanged: notifier.setAllowNegativeStock,
        ),
        const SizedBox(height: Insets.xl),
        SectionLabel(AppStrings.statusSection),
        const SizedBox(height: Insets.md),
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

class _PhotoSection extends StatelessWidget {
  const _PhotoSection({
    required this.state,
    required this.size,
    required this.notifier,
    this.centered = false,
  });

  final GroceryFormState state;
  final double size;
  final GroceryFormNotifier notifier;
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
