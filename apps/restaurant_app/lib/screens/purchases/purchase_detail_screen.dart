import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/app_strings.dart';
import '../../models/permission.dart';
import '../../models/purchase_order.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/permissions_provider.dart';
import '../../providers/purchases_provider.dart';
import '../../providers/suppliers_provider.dart';
import '../../services/purchase_api_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/breakpoints.dart';
import '../../utils/dialog_helper.dart';
import '../../utils/formatters.dart';
import '../../widgets/data_page/status_badge.dart';

/// Detail for one purchase order: lines, receive, and cancel.
///
/// Online-only like the list screen: without connectivity the detail shows
/// the offline placeholder (its numbers drive stock and money).
class PurchaseDetailScreen extends ConsumerStatefulWidget {
  const PurchaseDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<PurchaseDetailScreen> createState() =>
      _PurchaseDetailScreenState();
}

class _PurchaseDetailScreenState extends ConsumerState<PurchaseDetailScreen> {
  PurchaseOrder? _order;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Prefer list state for instant paint; fetch full detail in background.
    final cached = ref.read(purchaseByIdProvider(widget.orderId));
    if (cached != null) {
      _order = cached;
      _loading = cached.lines.isEmpty;
    }
    _load();
  }

  Future<void> _load() async {
    try {
      final order =
          await ref.read(purchasesProvider.notifier).fetchDetail(widget.orderId);
      if (!mounted) return;
      setState(() {
        _order = order;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _run(
    Future<void> Function() action,
    String ok,
    String Function(Object) fail,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      await _load();
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(ok)));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(fail(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final online = ref.watch(isOnlineProvider).valueOrNull ?? true;
    final order = _order;

    return Scaffold(
      appBar: AppBar(
        title: Text(order?.poNumber ?? AppStrings.purchasesTitle),
        elevation: 0,
        actions: [
          if (online && !_loading)
            IconButton(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
            ),
        ],
      ),
      body: !online
          ? _offline()
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null && order == null
                  ? _failure(_error!)
                  : _DetailBody(
                      order: order!,
                      onAction: _run,
                      onChanged: _load,
                    ),
    );
  }

  Widget _offline() {
    return ListView(
      padding: const EdgeInsets.all(Insets.lg),
      children: [
        const SizedBox(height: Insets.xl * 2),
        Icon(Icons.cloud_off_outlined,
            size: 48, color: context.colors.onSurfaceVariant),
        const SizedBox(height: Insets.md),
        Text(AppStrings.purchasesOfflineTitle,
            style: context.text.titleMedium, textAlign: TextAlign.center),
        const SizedBox(height: Insets.sm),
        Text(
          AppStrings.purchasesOfflineBody,
          style: context.text.bodyMedium
              ?.copyWith(color: context.colors.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _failure(String message) {
    return ListView(
      padding: const EdgeInsets.all(Insets.lg),
      children: [
        const SizedBox(height: Insets.xl * 2),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: Insets.lg),
        Center(
          child: FilledButton.tonal(
            onPressed: () {
              setState(() {
                _loading = true;
                _error = null;
              });
              _load();
            },
            child: Text(AppStrings.retryAction),
          ),
        ),
      ],
    );
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({
    required this.order,
    required this.onAction,
    required this.onChanged,
  });

  final PurchaseOrder order;
  final Future<void> Function(
    Future<void> Function(),
    String,
    String Function(Object),
  ) onAction;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supplier = ref.watch(supplierByIdProvider(order.supplierId));
    final canCreate =
        ref.watch(hasPermissionProvider(AppPermissions.procurementCreate));
    final canReceive =
        ref.watch(hasPermissionProvider(AppPermissions.procurementReceive));
    final tone = switch (order.status) {
      PurchaseOrderStatus.unfulfilled => StatusTone.warning,
      PurchaseOrderStatus.fulfilled => StatusTone.positive,
      PurchaseOrderStatus.cancelled => StatusTone.neutral,
      PurchaseOrderStatus.unknown => StatusTone.neutral,
    };
    final notifier = ref.read(purchasesProvider.notifier);
    final hasReceipts = order.lines.any((l) => l.quantityReceived > 0);

    return ListView(
      padding: const EdgeInsets.all(Insets.lg),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(order.poNumber, style: context.text.titleLarge),
                  const SizedBox(height: Insets.xs),
                  Text(
                    supplier?.name ?? AppStrings.unknownSupplier,
                    style: context.text.bodyMedium?.copyWith(
                        color: context.colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            StatusBadge(label: order.status.label, tone: tone, dense: true),
          ],
        ),
        const SizedBox(height: Insets.sm),
        Text(
          Fmt.relativeDateTime(order.orderedAt),
          style: context.text.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: context.colors.primary,
          ),
        ),
        if (order.notes != null) ...[
          const SizedBox(height: Insets.sm),
          Text(
            AppStrings.notesLine(order.notes!),
            style: context.text.bodySmall?.copyWith(
              fontStyle: FontStyle.italic,
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: Insets.md),
        Wrap(
          spacing: Insets.sm,
          runSpacing: Insets.sm,
          children: [
            if (order.status == PurchaseOrderStatus.unfulfilled && canReceive)
              FilledButton.icon(
                onPressed: () => _showReceive(context, ref),
                icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                label: Text(AppStrings.receiveAction),
              ),
            if (order.status == PurchaseOrderStatus.unfulfilled &&
                !hasReceipts &&
                canCreate)
              TextButton(
                onPressed: () => onAction(
                  () => notifier.cancel(order.id),
                  AppStrings.orderCancelledMessage,
                  (e) => AppStrings.transitionFailed('cancel', e),
                ),
                child: Text(AppStrings.cancel),
              ),
          ],
        ),
        const SizedBox(height: Insets.xl),
        Text('Lines (${order.lines.length})', style: context.text.titleMedium),
        const SizedBox(height: Insets.md),
        ...order.lines.map((line) => _LineTile(line: line)),
      ],
    );
  }

  Future<void> _showReceive(BuildContext context, WidgetRef ref) {
    return showAppDialog(
      context: context,
      builder: (_) => _ReceiveDialog(order: order, onDone: onChanged),
    );
  }
}

class _LineTile extends ConsumerWidget {
  const _LineTile({required this.line});

  final PurchaseOrderLine line;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(inventoryItemsListProvider);
    final item = items.where((i) => i.id == line.itemId).firstOrNull;
    return Container(
      margin: const EdgeInsets.only(bottom: Insets.sm),
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        border: Border.all(color: context.semantic.hairline),
        borderRadius: BorderRadius.circular(Insets.md),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item?.name ?? line.itemId,
                  style: context.text.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: Insets.xs),
                Text(
                  '${Fmt.quantity(line.quantityReceived)} / ${Fmt.quantity(line.quantityOrdered)} ${line.unit} received',
                  style: context.text.bodySmall?.copyWith(
                      color: context.colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiveDialog extends ConsumerStatefulWidget {
  const _ReceiveDialog({required this.order, required this.onDone});

  final PurchaseOrder order;
  final Future<void> Function() onDone;

  @override
  ConsumerState<_ReceiveDialog> createState() => _ReceiveDialogState();
}

class _ReceiveDialogState extends ConsumerState<_ReceiveDialog> {
  /// Lines that still have something outstanding — fully received lines are
  /// shown read-only below the editable ones.
  late final List<PurchaseOrderLine> _openLines;
  late final Map<String, TextEditingController> _qtyControllers;
  late final Map<String, TextEditingController> _costControllers;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _openLines = [
      for (final line in widget.order.lines)
        if (line.outstanding > 0) line,
    ];
    _qtyControllers = {
      for (final line in _openLines)
        line.id: TextEditingController(text: line.outstanding.toString()),
    };
    _costControllers = {
      for (final line in _openLines)
        line.id: TextEditingController(text: _initialCostFor(line.itemId)),
    };
  }

  /// Actual price per receipt line — cost enters the system here, never on
  /// the order. Prefilled from the item's known cost basis when available.
  String _initialCostFor(String itemId) {
    final items = ref.read(inventoryItemsListProvider);
    final item = items.where((i) => i.id == itemId).firstOrNull;
    if (item == null || item.unitCost <= 0) return '';
    return item.unitCost.toString();
  }

  @override
  void dispose() {
    for (final c in _qtyControllers.values) {
      c.dispose();
    }
    for (final c in _costControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final inputs = <GoodsReceiptLineInput>[];
    for (final line in _openLines) {
      final raw = _qtyControllers[line.id]!.text;
      if (raw.trim().isEmpty) continue;
      final qty = Decimal.tryParse(raw);
      if (qty == null || qty <= Decimal.zero) {
        setState(() => _error = 'Quantities must be positive numbers');
        return;
      }
      if (qty > Decimal.parse(line.outstanding.toString())) {
        setState(() => _error = 'Cannot receive more than outstanding');
        return;
      }
      final cost = Decimal.tryParse(_costControllers[line.id]!.text);
      if (cost == null || cost < Decimal.zero) {
        setState(() => _error = 'Enter the actual unit cost for each line');
        return;
      }
      inputs.add(GoodsReceiptLineInput(
        purchaseOrderLineId: line.id,
        quantityReceived: qty,
        unitCost: cost,
      ));
    }
    if (inputs.isEmpty) {
      setState(() => _error = 'Enter at least one quantity');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(purchasesProvider.notifier)
          .receive(orderId: widget.order.id, lines: inputs);
      await widget.onDone();
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(content: Text(AppStrings.goodsReceivedMessage)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e is PurchaseApiException
            ? e.message
            : AppStrings.receiveFailedGeneric(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(inventoryItemsListProvider);
    final names = {for (final i in items) i.id: i.name};
    final form = context.formFactor;

    // Wide working surface on desktop/tablet, full-width sheet on phones.
    final screen = MediaQuery.sizeOf(context);
    final available = screen.width - (form.isMobile ? 64 : 96);
    final width = (form.isDesktop
            ? 880.0
            : (form.isTablet ? 720.0 : 480.0))
        .clamp(300.0, available);
    final height = (screen.height - 200.0).clamp(420.0, 720.0);

    final closedLines = [
      for (final line in widget.order.lines)
        if (line.outstanding <= 0) line,
    ];

    return AlertDialog(
      title: Text(AppStrings.receiveTitle),
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
        child: form.isMobile
            ? _dialogBody(names, closedLines)
            : SizedBox(height: height, child: _dialogBody(names, closedLines)),
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
              : Text(AppStrings.receiveGrnAction),
        ),
      ],
    );
  }

  Widget _dialogBody(
    Map<String, String> names,
    List<PurchaseOrderLine> closedLines,
  ) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final line in _openLines) _ReceiveLineCard(
            line: line,
            itemName: names[line.itemId] ?? line.itemId,
            qtyController: _qtyControllers[line.id]!,
            costController: _costControllers[line.id]!,
          ),
          if (closedLines.isNotEmpty) ...[
            const SizedBox(height: Insets.sm),
            Text(
              'Already fully received',
              style: context.text.labelMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Insets.xs),
            for (final line in closedLines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Insets.xs),
                child: Text(
                  '${names[line.itemId] ?? line.itemId} — '
                  '${Fmt.quantity(line.quantityOrdered)} ${line.unit} received',
                  style: context.text.bodySmall?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ),
          ],
          if (_error != null) ...[
            const SizedBox(height: Insets.sm),
            Text(_error!,
                style: TextStyle(color: context.colors.error)),
          ],
        ],
      ),
    );
  }
}

/// One line of the receive dialog: ordered / received / outstanding figures
/// with a progress bar on top, then the qty + actual-cost inputs below.
class _ReceiveLineCard extends StatelessWidget {
  const _ReceiveLineCard({
    required this.line,
    required this.itemName,
    required this.qtyController,
    required this.costController,
  });

  final PurchaseOrderLine line;
  final String itemName;
  final TextEditingController qtyController;
  final TextEditingController costController;

  @override
  Widget build(BuildContext context) {
    final ordered = line.quantityOrdered;
    final received = line.quantityReceived;
    final outstanding = line.outstanding;
    final progress =
        ordered <= 0 ? 0.0 : (received / ordered).clamp(0.0, 1.0);
    return Container(
      margin: const EdgeInsets.only(bottom: Insets.md),
      padding: const EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: context.semantic.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            itemName,
            style: context.text.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: Insets.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.pill),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: context.colors.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: Insets.sm),
          Row(
            children: [
              Expanded(
                child: _Stat(
                  label: 'Ordered',
                  value: '${Fmt.quantity(ordered)} ${line.unit}',
                ),
              ),
              Expanded(
                child: _Stat(
                  label: 'Received',
                  value: '${Fmt.quantity(received)} ${line.unit}',
                  highlight: true,
                ),
              ),
              Expanded(
                child: _Stat(
                  label: 'Outstanding',
                  value: '${Fmt.quantity(outstanding)} ${line.unit}',
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.md),
          LayoutBuilder(
            builder: (context, constraints) {
              final sideBySide = constraints.maxWidth >= 420;
              final qtyField = TextField(
                controller: qtyController,
                decoration: const InputDecoration(
                  labelText: 'Qty received',
                  helperText: 'Max outstanding',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              );
              final costField = TextField(
                controller: costController,
                decoration: const InputDecoration(
                  labelText: 'Unit cost (actual)',
                  helperText: 'Price on this delivery',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              );
              if (!sideBySide) {
                return Column(
                  children: [
                    qtyField,
                    const SizedBox(height: Insets.sm),
                    costField,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: qtyField),
                  const SizedBox(width: Insets.md),
                  Expanded(child: costField),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: context.text.labelSmall?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: context.text.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: highlight ? context.colors.primary : null,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
