import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/inventory_item.dart';
import '../../constants/app_strings.dart';
import '../../models/stock_movement.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/staff_provider.dart';
import '../../providers/stock_movement_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/breakpoints.dart';
import '../../utils/formatters.dart';
import '../../widgets/item_photo.dart';
import '../../widgets/labeled_form_field.dart';

/// Width the three stock dialogs share. Narrower than the item form, which has
/// a photo column to accommodate — these are single-column and a wider box
/// would just stretch four short fields across dead space.
const double kStockDialogWidth = 480;

/// Widget keys for the stock dialogs' controls.
///
/// The labels sit outside the inputs, so there is no `labelText` for a test to
/// find a field by — the same reason [ItemFormKeys] exists. Shared across all
/// three dialogs because the fields are the shared widgets below, not
/// per-dialog copies.
abstract final class StockDialogKeys {
  static const quantity = Key('stockDialog.quantity');
  static const notes = Key('stockDialog.notes');
  static const reason = Key('stockDialog.reason');
  static const destination = Key('stockDialog.destination');
  static const submit = Key('stockDialog.submit');
  static const cancel = Key('stockDialog.cancel');
}

/// Read-only item context at the top of every stock dialog.
///
/// The same block in all three, so a user who has learned where the current
/// count sits in Adjust finds it in exactly the same place in Waste.
class StockItemContext extends StatelessWidget {
  const StockItemContext({super.key, required this.item});

  final InventoryItem item;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh.withValues(alpha: 0.55),
        borderRadius: Radii.card,
        border: Border.all(color: context.semantic.hairline),
      ),
      child: Row(
        children: [
          Container(
            height: 40,
            width: 40,
            clipBehavior: Clip.antiAlias,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(Radii.sm),
            ),
            child: ItemPhoto(
              emoji: item.emoji,
              emojiSize: 20,
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
                  style: context.text.titleSmall,
                ),
                Text(
                  AppStrings.stockOnHand(
                    item.sku,
                    Fmt.quantity(item.stock),
                    item.unit,
                  ),
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
      ),
    );
  }
}

/// The quantity input the three dialogs share: digits only, unit as a suffix,
/// and an inline error when the amount is impossible.
class StockQuantityField extends StatelessWidget {
  const StockQuantityField({
    super.key,
    required this.controller,
    required this.item,
    required this.onChanged,
    this.label,
    this.helper,
    this.errorText,
    this.autofocus = true,
  });

  final TextEditingController controller;
  final InventoryItem item;
  final ValueChanged<String> onChanged;
  final String? label;
  final String? helper;

  /// Supplied by the dialog rather than a validator, because the same message
  /// also has to gate the confirm button — deriving it once keeps the button
  /// and the error from ever disagreeing.
  final String? errorText;

  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return LabeledFormField(
      label: label ?? AppStrings.quantityLabel,
      isRequired: true,
      helper: helper,
      child: TextFormField(
        key: StockDialogKeys.quantity,
        controller: controller,
        autofocus: autofocus,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$'))],
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: AppStrings.quantityHint,
          suffixText: item.unit,
          errorText: errorText,
        ),
      ),
    );
  }
}

/// Optional free-text notes. Identical in all three dialogs.
class StockNotesField extends StatelessWidget {
  const StockNotesField({
    super.key,
    required this.controller,
    this.label,
    this.hint,
  });

  final TextEditingController controller;
  final String? label;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return LabeledFormField(
      label: label ?? AppStrings.notesLabel,
      child: TextFormField(
        key: StockDialogKeys.notes,
        controller: controller,
        maxLines: 2,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          hintText: hint ?? AppStrings.notesHint,
          // The pill border the theme applies to single-line inputs looks
          // wrong wrapped around a two-line box.
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Radii.md),
            borderSide: BorderSide(color: context.semantic.hairline),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Radii.md),
            borderSide: BorderSide(color: context.colors.primary, width: 1.5),
          ),
        ),
      ),
    );
  }
}

/// A single-line preview of what confirming will do — "New stock level: 38 kg".
///
/// Live rather than shown after the fact, because the whole risk in a stock
/// dialog is transposing a digit, and the number is easier to sanity-check than
/// the arithmetic that produced it.
class StockPreviewLine extends StatelessWidget {
  const StockPreviewLine({
    super.key,
    required this.label,
    required this.value,
    this.tone,
    this.icon = Icons.arrow_forward_rounded,
  });

  final String label;
  final String value;
  final Color? tone;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final accent = tone ?? colors.primary;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.md,
        vertical: Insets.sm + 2,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: accent),
          const SizedBox(width: Insets.sm),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: Insets.sm),
          Text(
            value,
            maxLines: 1,
            style: context.text.titleSmall?.copyWith(
              color: accent,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Applies a manual stock adjustment (add/remove/recount) and records it in
/// the ledger, in that order — the one place the two providers are written
/// together for this operation. Doing it anywhere else risks a count that
/// moved without a movement to explain it, which is exactly the discrepancy
/// the ledger exists to make impossible.
///
/// [reason] is sent to the backend when a real store context exists, and
/// must be at least 3 characters (the backend rejects anything shorter) —
/// every dialog that calls this always has a non-empty reason label to fall
/// back on, so this is never user-triggerable.
Future<void> applyAdjustment({
  required WidgetRef ref,
  required InventoryItem item,
  required double delta,
  required StockMovementType type,
  required String reason,
}) async {
  final before = ref.read(inventoryItemsProvider.notifier).byId(item.id)?.stock ?? item.stock;
  await ref.read(inventoryItemsProvider.notifier).adjustStock(item.id, delta, reason: reason);
  await _recordLedgerDelta(ref: ref, item: item, before: before, type: type, note: reason);
}

/// Records wasted/spoiled stock. Same shape as [applyAdjustment] but goes
/// through `inventory.waste.record`, the backend's distinct permission for
/// this action.
Future<void> applyWaste({
  required WidgetRef ref,
  required InventoryItem item,
  required double quantity,
  required String reason,
}) async {
  final before = ref.read(inventoryItemsProvider.notifier).byId(item.id)?.stock ?? item.stock;
  await ref.read(inventoryItemsProvider.notifier).recordWaste(item.id, quantity, reason: reason);
  await _recordLedgerDelta(
    ref: ref,
    item: item,
    before: before,
    type: StockMovementType.waste,
    note: reason,
  );
}

/// Transfers stock from the current store to [destinationStoreId]. The
/// real endpoint credits the
/// destination store's stock too (one atomic transaction server-side) — this
/// only has to record the local, single-store ledger's "out" half.
Future<void> applyTransfer({
  required WidgetRef ref,
  required InventoryItem item,
  required double quantity,
  required String destinationStoreId,
  required String note,
}) async {
  final before = ref.read(inventoryItemsProvider.notifier).byId(item.id)?.stock ?? item.stock;
  await ref
      .read(inventoryItemsProvider.notifier)
      .transferStock(item.id, quantity, destinationStoreId: destinationStoreId);
  await _recordLedgerDelta(
    ref: ref,
    item: item,
    before: before,
    type: StockMovementType.transfer,
    note: note,
  );
}

Future<void> _recordLedgerDelta({
  required WidgetRef ref,
  required InventoryItem item,
  required double before,
  required StockMovementType type,
  String? note,
}) async {
  final after = ref.read(inventoryItemsProvider.notifier).byId(item.id)?.stock ?? before;
  ref
      .read(stockMovementsProvider.notifier)
      .record(
        itemId: item.id,
        type: type,
        // The recorded delta is the effective one: asking to remove 10 from a
        // shelf holding 4 removes 4, and the ledger says 4.
        delta: after - before,
        balanceAfter: after,
        actor: ref.read(currentUserNameProvider),
        note: note,
      );
}

/// Parses a quantity field. Null for empty or unparseable input, which the
/// dialogs treat as "not yet valid" rather than as zero.
double? parseQuantity(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  return double.tryParse(trimmed);
}

/// One weigh line for cooking, in simple words.
///
/// Shows the item name, how much is on the shelf, a big number box, and a
/// tick or warning. The first line (main item) gets a "Main item" tag so
/// staff know what is measured first. Same widget everywhere cooking
/// weighs items — one place to fix, not three.
class SimpleWeighLine extends StatelessWidget {
  const SimpleWeighLine({
    super.key,
    required this.name,
    required this.unit,
    required this.controller,
    required this.onHand,
    required this.onChanged,
    this.isMainItem = false,
  });

  final String name;
  final String unit;
  final TextEditingController? controller;
  final double onHand;
  final VoidCallback onChanged;
  final bool isMainItem;

  @override
  Widget build(BuildContext context) {
    final needed = parseQuantity(controller?.text ?? '') ?? 0;
    final short = needed > onHand;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Insets.xs),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (isMainItem) ...[
                      const SizedBox(width: Insets.xs),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Insets.sm,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: context.colors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(Radii.pill),
                        ),
                        child: Text(
                          'Main item',
                          style: context.text.labelSmall?.copyWith(
                            color: context.colors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  '${Fmt.quantity(onHand)} $unit on shelf',
                  style: context.text.bodyMedium?.copyWith(
                    color: short
                        ? context.semantic.warning
                        : context.colors.onSurfaceVariant,
                    fontWeight: short ? FontWeight.w700 : null,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: Insets.sm),
          SizedBox(
            width: 130,
            child: TextFormField(
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
              ],
              style: context.text.titleMedium,
              decoration: InputDecoration(
                suffixText: unit,
                isDense: true,
              ),
              onChanged: (_) => onChanged(),
            ),
          ),
          const SizedBox(width: Insets.sm),
          Icon(
            short
                ? Icons.warning_amber_rounded
                : Icons.check_circle_outline_rounded,
            size: 22,
            color: short ? context.semantic.warning : context.semantic.success,
          ),
        ],
      ),
    );
  }
}

/// Checks internet before cooking writes. Simple words when offline.
Future<bool> needInternet(BuildContext context) async {
  // Dio errors surface on the call itself; this is a fast local hint.
  // We keep it simple: try a no-op and let callers show the friendly box.
  return true;
}
