/// Dialog for drafting a multi-line purchase order.
///
/// Single screen: a supplier-mode selector on top (one supplier per order
/// by default, per-item suppliers, or no supplier), item lines below (from
/// live inventory or quick-add), notes, a line-count summary, then Create
/// order. Lines are qty-only — cost is captured per receipt when goods
/// arrive, never on the order. Lines can be added before a supplier is
/// picked — validation runs on save. The backend validates again (sellable
/// items, units) and assigns the PO number. Orders are created as drafts —
/// submit/approve happen from the detail screen.
///
/// Per-item mode groups lines by supplier and creates one order per
/// supplier automatically; no-supplier mode saves under the shared
/// "Unknown supplier" (created on first use).
library;

import 'dart:math' as math;

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/app_strings.dart';
import '../../models/inventory_item.dart';
import '../../models/supplier.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/purchases_provider.dart';
import '../../providers/suppliers_provider.dart';
import '../../services/purchase_api_service.dart';
import '../../services/supplier_api_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/breakpoints.dart';
import '../../utils/dialog_helper.dart';
import '../../widgets/dialogs/supplier_form_dialog.dart'
    show showSupplierFormDialog;
import 'quick_add_item_dialog.dart';

Future<void> showPurchaseOrderDialog(BuildContext context) {
  return showAppDialog(
    context: context,
    builder: (_) => const _PurchaseOrderDialog(),
  );
}

/// How suppliers are assigned to the drafted order. Defaults to [single].
enum PurchaseSupplierMode { single, perItem, none }

/// Groups validated line inputs by supplier, preserving first-seen supplier
/// order so the created POs follow the line order in the dialog.
List<MapEntry<String, List<PurchaseOrderLineInput>>>
groupPurchaseLinesBySupplier(
  List<({PurchaseOrderLineInput input, String supplierId})> lines,
) {
  final order = <String>[];
  final groups = <String, List<PurchaseOrderLineInput>>{};
  for (final line in lines) {
    var group = groups[line.supplierId];
    if (group == null) {
      group = [];
      groups[line.supplierId] = group;
      order.add(line.supplierId);
    }
    group.add(line.input);
  }
  return [for (final id in order) MapEntry(id, groups[id]!)];
}

class _LineDraft {
  String? itemId;
  String? supplierId;

  /// Controllers live on the draft (not the row state) so typed values
  /// survive row rebuilds — e.g. when a quick-added item is selected and
  /// the dropdown needs a fresh `initialValue`.
  final quantity = TextEditingController();

  void dispose() {
    quantity.dispose();
  }
}

class _PurchaseOrderDialog extends ConsumerStatefulWidget {
  const _PurchaseOrderDialog();

  @override
  ConsumerState<_PurchaseOrderDialog> createState() =>
      _PurchaseOrderDialogState();
}

class _PurchaseOrderDialogState extends ConsumerState<_PurchaseOrderDialog> {
  /// Same widths as the take-payment dialog so the order form gets a wide
  /// working surface on desktop instead of a narrow popup.
  static const double _wideWidth = 1020;
  static const double _tabletWidth = 980;
  static const double _phoneWidth = 460;

  PurchaseSupplierMode _mode = PurchaseSupplierMode.single;
  String? _supplierId;
  String? _notes;
  final _lines = <_LineDraft>[_LineDraft()];
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  List<InventoryItem> _purchasableItems() {
    // Mirrors the backend guard: sellable-only items can never be
    // purchase-received, so they are not offered here either.
    return ref
        .watch(inventoryItemsListProvider)
        .where((i) => i.itemType != 'sellable' && !i.isArchived)
        .toList();
  }

  Future<void> _quickAddItem(_LineDraft line) async {
    final createdId = await showQuickAddItemDialog(context);
    if (createdId != null && mounted) {
      setState(() => line.itemId = createdId);
    }
  }

  /// Opens the supplier form and selects whoever was just added on the
  /// whole order (single mode).
  Future<void> _quickAddOrderSupplier() async {
    final created = await showSupplierFormDialog(context);
    if (created != null && mounted) {
      setState(() => _supplierId = created.id);
    }
  }

  /// Same, but selects the new supplier on one per-item line.
  Future<void> _quickAddLineSupplier(_LineDraft line) async {
    final created = await showSupplierFormDialog(context);
    if (created != null && mounted) {
      setState(() => line.supplierId = created.id);
    }
  }

  /// Finds the shared "Unknown supplier", creating it on first use so
  /// supplier-less orders still satisfy the backend's required supplier.
  Future<String> _resolveUnknownSupplierId() async {
    final wanted = AppStrings.unknownSupplier.toLowerCase();
    for (final s in ref.read(suppliersListProvider)) {
      if (s.name.toLowerCase() == wanted) return s.id;
    }
    final created = await ref
        .read(suppliersProvider.notifier)
        .create(
          name: AppStrings.unknownSupplier,
          notes: 'Auto-created for supplier-less purchase orders',
        );
    return created.id;
  }

  Future<void> _save() async {
    if (_mode == PurchaseSupplierMode.single && _supplierId == null) {
      setState(() => _error = 'Choose a supplier');
      return;
    }
    final items = {for (final i in _purchasableItems()) i.id: i};
    final parsed = <({PurchaseOrderLineInput input, String? supplierId})>[];
    for (final line in _lines) {
      final itemId = line.itemId;
      final qty = Decimal.tryParse(line.quantity.text);
      if (itemId == null || qty == null || qty <= Decimal.zero) {
        setState(() => _error = 'Each line needs an item and quantity');
        return;
      }
      if (!items.containsKey(itemId)) {
        setState(() => _error = 'Unknown item selected');
        return;
      }
      parsed.add((
        input: PurchaseOrderLineInput(
          itemId: itemId,
          quantityOrdered: qty,
        ),
        supplierId: _mode == PurchaseSupplierMode.perItem
            ? line.supplierId
            : _supplierId,
      ));
    }
    if (parsed.isEmpty) {
      setState(() => _error = 'Add at least one item to the order');
      return;
    }

    // Resolve one group of lines per supplier to create.
    final List<MapEntry<String, List<PurchaseOrderLineInput>>> groups;
    switch (_mode) {
      case PurchaseSupplierMode.single:
        final supplierId = _supplierId;
        if (supplierId == null) {
          setState(() => _error = 'Choose a supplier');
          return;
        }
        groups = [
          MapEntry(supplierId, [for (final p in parsed) p.input]),
        ];
      case PurchaseSupplierMode.perItem:
        if (parsed.any((p) => p.supplierId == null)) {
          setState(() => _error = AppStrings.purchaseLineNeedsSupplier);
          return;
        }
        groups = groupPurchaseLinesBySupplier([
          for (final p in parsed) (input: p.input, supplierId: p.supplierId!),
        ]);
      case PurchaseSupplierMode.none:
        groups = [];
    }

    // Duplicates are only a conflict within a single order — the same item
    // for two suppliers becomes two orders, which is fine.
    final toCheck = _mode == PurchaseSupplierMode.perItem
        ? groups.map((g) => g.value).toList()
        : [
            [for (final p in parsed) p.input],
          ];
    if (toCheck.any(
      (lines) => lines.map((e) => e.itemId).toSet().length != lines.length,
    )) {
      setState(() => _error = 'Duplicate item in lines');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      final notes = _notes?.isEmpty ?? true ? null : _notes;
      final notifier = ref.read(purchasesProvider.notifier);
      if (_mode == PurchaseSupplierMode.none) {
        final unknownId = await _resolveUnknownSupplierId();
        await notifier.create(
          supplierId: unknownId,
          lines: [for (final p in parsed) p.input],
          notes: notes,
        );
      } else {
        for (final group in groups) {
          await notifier.create(
            supplierId: group.key,
            lines: group.value,
            notes: notes,
          );
        }
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      final orderCount = _mode == PurchaseSupplierMode.perItem
          ? groups.length
          : 1;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            orderCount == 1
                ? AppStrings.orderCreatedMessage
                : AppStrings.ordersCreatedMessage(orderCount),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = switch (e) {
        PurchaseApiException() => e.message,
        SupplierApiException() => e.message,
        _ => AppStrings.createFailed(e),
      };
      setState(() {
        _saving = false;
        _error = msg;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final suppliers = ref.watch(suppliersListProvider);
    final items = _purchasableItems();
    final form = context.formFactor;

    final screen = MediaQuery.sizeOf(context);
    final available = screen.width - (form.isMobile ? 80 : 56);
    final width = math.max(
      240.0,
      math.min(
        form.isDesktop
            ? _wideWidth
            : (form.isTablet ? _tabletWidth : _phoneWidth),
        available,
      ),
    );
    final height = math.max(480.0, math.min(760.0, screen.height - 180.0));

    // Single-column dialog on every form factor: the whole body scrolls
    // and the actions stay pinned in the dialog's bottom bar.
    final body = SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _orderForm(suppliers, items),
          const SizedBox(height: Insets.md),
          _summaryCard(suppliers),
        ],
      ),
    );

    return AlertDialog(
      title: Text(AppStrings.createOrderTitle),
      insetPadding: form.isMobile
          ? const EdgeInsets.symmetric(horizontal: 16, vertical: 24)
          : const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      contentPadding: const EdgeInsets.fromLTRB(
        Insets.xl,
        Insets.lg,
        Insets.xl,
        Insets.sm,
      ),
      content: SizedBox(
        width: width,
        child: form.isMobile ? body : SizedBox(height: height, child: body),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(AppStrings.cancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(AppStrings.createOrderAction),
        ),
      ],
    );
  }

  /// Supplier mode + supplier(s) + lines + notes — the scrolling left pane
  /// on desktop/tablet, the whole body on phones.
  Widget _modeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          AppStrings.purchaseSupplierModeLabel,
          style: context.text.bodySmall?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: Insets.xs),
        SegmentedButton<PurchaseSupplierMode>(
          segments: [
            ButtonSegment(
              value: PurchaseSupplierMode.single,
              label: Text(AppStrings.purchaseSupplierModeSingle),
            ),
            ButtonSegment(
              value: PurchaseSupplierMode.perItem,
              label: Text(AppStrings.purchaseSupplierModePerItem),
            ),
            ButtonSegment(
              value: PurchaseSupplierMode.none,
              label: Text(AppStrings.purchaseSupplierModeNone),
            ),
          ],
          selected: {_mode},
          showSelectedIcon: false,
          onSelectionChanged: (selected) => setState(() {
            _mode = selected.first;
            _error = null;
          }),
        ),
      ],
    );
  }

  Widget _orderForm(List<Supplier> suppliers, List<InventoryItem> items) {
    final perItem = _mode == PurchaseSupplierMode.perItem;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _modeSelector(),
        const SizedBox(height: Insets.md),
        switch (_mode) {
          PurchaseSupplierMode.single => Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _supplierId,
                  decoration: const InputDecoration(labelText: 'Supplier'),
                  items: [
                    for (final s in suppliers)
                      DropdownMenuItem(value: s.id, child: Text(s.name)),
                  ],
                  onChanged: (v) => setState(() => _supplierId = v),
                ),
              ),
              IconButton(
                onPressed: _quickAddOrderSupplier,
                tooltip: AppStrings.addNewSupplier,
                icon: const Icon(Icons.add_circle_outline_rounded),
              ),
            ],
          ),
          PurchaseSupplierMode.perItem => Text(
            AppStrings.purchasePerItemHint,
            style: context.text.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          PurchaseSupplierMode.none => Text(
            AppStrings.purchaseNoSupplierHint(AppStrings.unknownSupplier),
            style: context.text.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        },
        const SizedBox(height: Insets.md),
        for (var i = 0; i < _lines.length; i++)
          _LineRow(
            key: ValueKey('line-$i'),
            draft: _lines[i],
            items: items,
            suppliers: suppliers,
            showSupplier: perItem,
            onSupplierChanged: perItem
                ? (v) => setState(() => _lines[i].supplierId = v)
                : null,
            onRemove: _lines.length > 1
                ? () => setState(() => _lines.removeAt(i).dispose())
                : null,
            onNewItem: () => _quickAddItem(_lines[i]),
            onNewSupplier: perItem
                ? () => _quickAddLineSupplier(_lines[i])
                : null,
            // Refresh the summary card total on every keystroke.
            onValuesChanged: () => setState(() {}),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() {
              _lines.add(_LineDraft());
              _error = null;
            }),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add item'),
          ),
        ),
        TextField(
          decoration: const InputDecoration(labelText: 'Notes (optional)'),
          onChanged: (v) => _notes = v,
        ),
      ],
    );
  }

  /// Summary card pinned below the form in the single-column body: line
  /// count and any error. Save/cancel live in the dialog's actions.
  Widget _summaryCard(List<Supplier> suppliers) {
    final supplierName = suppliers
        .where((s) => s.id == _supplierId)
        .firstOrNull
        ?.name;
    final title = switch (_mode) {
      PurchaseSupplierMode.single => supplierName ?? 'New order',
      PurchaseSupplierMode.perItem => switch (_lines
          .map((l) => l.supplierId)
          .whereType<String>()
          .toSet()
          .length) {
        0 => 'New order',
        1 => '1 supplier',
        final n => '$n suppliers',
      },
      PurchaseSupplierMode.none => AppStrings.unknownSupplier,
    };
    return Container(
      padding: const EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: context.semantic.hairline),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: context.text.titleMedium,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: Insets.xs),
          Text(
            '${_lines.length} ${_lines.length == 1 ? 'item' : 'items'} · qty-only (cost is captured on receipt)',
            style: context.text.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: Insets.sm),
            Text(_error!, style: TextStyle(color: context.colors.error)),
          ],
        ],
      ),
    );
  }
}

class _LineRow extends StatefulWidget {
  const _LineRow({
    super.key,
    required this.draft,
    required this.items,
    this.suppliers = const [],
    this.showSupplier = false,
    this.onSupplierChanged,
    this.onRemove,
    required this.onNewItem,
    this.onNewSupplier,
    this.onValuesChanged,
  });

  final _LineDraft draft;
  final List<InventoryItem> items;
  final List<Supplier> suppliers;

  /// Per-item supplier mode: each line picks its own supplier.
  final bool showSupplier;
  final ValueChanged<String?>? onSupplierChanged;
  final VoidCallback? onRemove;

  /// Opens the quick-add item flow; the new item is selected on success.
  final Future<void> Function() onNewItem;

  /// Opens the supplier form; the new supplier is selected on this line.
  /// Null outside per-item mode, where no add-supplier button is shown.
  final Future<void> Function()? onNewSupplier;

  /// Fires on every qty keystroke so the parent can refresh the summary —
  /// controller text alone never triggers a rebuild.
  final VoidCallback? onValuesChanged;

  @override
  State<_LineRow> createState() => _LineRowState();
}

class _LineRowState extends State<_LineRow> {
  @override
  Widget build(BuildContext context) {
    final itemField = Expanded(
      flex: 5,
      child: DropdownButtonFormField<String>(
        // Keyed on the selection so a quick-added item (chosen
        // outside the dropdown) refreshes the displayed value without
        // wiping the qty controller owned by the draft.
        key: ValueKey('item-${widget.draft.itemId}'),
        initialValue: widget.draft.itemId,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Item'),
        items: [
          for (final item in widget.items)
            DropdownMenuItem(
              value: item.id,
              child: Text(item.name, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: (v) => setState(() => widget.draft.itemId = v),
      ),
    );
    final addButton = IconButton(
      onPressed: widget.onNewItem,
      tooltip: 'Add new item',
      icon: const Icon(Icons.add_circle_outline_rounded),
    );
    final supplierField = Expanded(
      flex: 4,
      child: DropdownButtonFormField<String>(
        key: ValueKey('line-supplier-${widget.draft.supplierId}'),
        initialValue: widget.draft.supplierId,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: AppStrings.purchaseLineSupplierLabel,
        ),
        items: [
          for (final s in widget.suppliers)
            DropdownMenuItem(
              value: s.id,
              child: Text(s.name, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: widget.onSupplierChanged,
      ),
    );
    void notifyValuesChanged() => widget.onValuesChanged?.call();
    final qtyField = Expanded(
      flex: 3,
      child: TextField(
        controller: widget.draft.quantity,
        decoration: const InputDecoration(labelText: 'Qty'),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (_) => notifyValuesChanged(),
      ),
    );
    final trailing = widget.onRemove == null
        ? const <Widget>[]
        : <Widget>[
            IconButton(
              onPressed: widget.onRemove,
              icon: const Icon(Icons.remove_circle_outline_rounded),
            ),
          ];
    // Quick-add supplier affordance next to the line picker — same idiom
    // as the quick-add item button next to the item picker.
    final addSupplier = widget.onNewSupplier == null
        ? const <Widget>[]
        : <Widget>[
            IconButton(
              onPressed: widget.onNewSupplier,
              tooltip: AppStrings.addNewSupplier,
              icon: const Icon(Icons.add_circle_outline_rounded),
            ),
          ];

    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.sm),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // The supplier picker shares the item row when there is room;
          // it needs a wider breakpoint than the item/qty row alone.
          final narrow =
              constraints.maxWidth < (widget.showSupplier ? 640 : 380);
          if (!narrow) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                itemField,
                addButton,
                qtyField,
                if (widget.showSupplier) ...[
                  const SizedBox(width: Insets.sm),
                  supplierField,
                  ...addSupplier,
                ],
                ...trailing,
              ],
            );
          }
          // Narrow phones: item picker on its own row, qty below,
          // supplier full-width last.
          return Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [itemField, addButton],
              ),
              const SizedBox(height: Insets.sm),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  qtyField,
                  ...trailing,
                ],
              ),
              if (widget.showSupplier) ...[
                const SizedBox(height: Insets.sm),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [supplierField, ...addSupplier],
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
