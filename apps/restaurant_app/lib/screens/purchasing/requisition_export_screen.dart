/// Order details / export view (secondary, opt-in).
///
/// The ONLY place PO numbers and procurement detail appear: real PO numbers,
/// per-PO timestamps, full `text_preview` (viewable + copyable), share, and
/// a print-friendly layout. Full page/route — a deliberate secondary
/// destination, not a dialog — rendering well in print/PDF regardless of
/// device.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../constants/app_strings.dart';
import '../../models/requisition.dart';
import '../../providers/requisition_order_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/breakpoints.dart';
import '../../utils/formatters.dart';

class RequisitionExportScreen extends ConsumerWidget {
  const RequisitionExportScreen({super.key, required this.requisitionId});

  final String requisitionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(requisitionOrderProvider(requisitionId));
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.reqExportTitle)),
      body: orderAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(Insets.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(AppStrings.reqExportLoadFailed,
                    style: context.text.titleSmall),
                const SizedBox(height: Insets.sm),
                Text(e.toString(),
                    style: context.text.bodySmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center),
                const SizedBox(height: Insets.lg),
                FilledButton.tonal(
                  onPressed: () => ref
                      .refresh(requisitionOrderProvider(requisitionId)),
                  child: Text(AppStrings.retryAction),
                ),
              ],
            ),
          ),
        ),
        data: (order) => _ExportBody(order: order),
      ),
    );
  }
}

class _ExportBody extends StatelessWidget {
  const _ExportBody({required this.order});

  final SubmittedRequisition order;

  @override
  Widget build(BuildContext context) {
    final form = context.formFactor;
    return SingleChildScrollView(
      padding: EdgeInsets.all(Insets.page(form)),
      child: Center(
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(maxWidth: Breakpoints.maxContentWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _MetaCard(order: order),
              const SizedBox(height: Insets.lg),
              for (final group in order.groups) ...[
                _PoCard(group: group, order: order),
                const SizedBox(height: Insets.lg),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaCard extends StatelessWidget {
  const _MetaCard({required this.order});

  final SubmittedRequisition order;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Insets.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppStrings.reqReconTitle, style: context.text.titleSmall),
            const SizedBox(height: Insets.sm),
            _MetaRow(
                label: AppStrings.reqMetaRequisition,
                value: order.id.substring(0, 8).toUpperCase()),
            _MetaRow(label: AppStrings.reqMetaStatus, value: order.rollupStatus),
            _MetaRow(
                label: AppStrings.reqMetaPlaced,
                value: order.orderedAt == null
                    ? '—'
                    : Fmt.relativeDateTime(order.orderedAt!)),
            _MetaRow(
                label: AppStrings.reqMetaDelivery,
                value: order.expectedAt == null
                    ? '—'
                    : '${order.expectedAt!.day}/${order.expectedAt!.month}/${order.expectedAt!.year}'),
            _MetaRow(
                label: AppStrings.linesColumn,
                value:
                    '${order.totalLines}'),
            _MetaRow(
                label: AppStrings.reqMetaPoCount,
                value: '${order.groups.length}'),
          ],
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Insets.xs),
      child: Row(
        children: [
          SizedBox(
            width: 160,
            child: Text(label,
                style: context.text.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                )),
          ),
          Expanded(
            child: Text(value,
                style: context.text.bodyMedium,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

class _PoCard extends StatelessWidget {
  const _PoCard({required this.group, required this.order});

  final RequisitionSupplierGroup group;
  final SubmittedRequisition order;

  @override
  Widget build(BuildContext context) {
    // PO number: intentionally exposed ONLY here, never on the primary
    // order screen. The backend returns it inside the payload's
    // structured_data; fall back to the short PO id when absent.
    final poNumber = _poNumberOf(group);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Insets.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SelectableText('PO $poNumber',
                          style: context.text.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          )),
                      Text(group.supplierName,
                          style: context.text.bodySmall?.copyWith(
                            color: context.colors.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Text('${group.lines.length} ${AppStrings.linesColumn.toLowerCase()}',
                    style: context.text.titleSmall),
              ],
            ),
            const SizedBox(height: Insets.sm),
            const Divider(height: 1),
            for (final line in group.lines)
              Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: Insets.xs),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${line.name} · ${line.qty} ${line.unit}',
                        style: context.text.bodyMedium,
                      ),
                    ),
                    if (line.priceUnconfirmed)
                      Text(
                        'TBC',
                        style: context.text.bodyMedium?.copyWith(
                          color: context.semantic.warning,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
            if (group.textPreview != null) ...[
              const SizedBox(height: Insets.sm),
              const Divider(height: 1),
              const SizedBox(height: Insets.sm),
              Text(AppStrings.reqMessageTitle,
                  style: context.text.labelMedium?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  )),
              const SizedBox(height: Insets.xs),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(Insets.md),
                decoration: BoxDecoration(
                  color:
                      context.colors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(Radii.sm),
                  border:
                      Border.all(color: context.semantic.hairline),
                ),
                child: SelectableText(
                  group.textPreview!,
                  style: context.text.bodySmall?.copyWith(
                    fontFeatures: const [],
                  ),
                ),
              ),
              const SizedBox(height: Insets.sm),
              Wrap(
                spacing: Insets.sm,
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(
                          ClipboardData(text: group.textPreview!));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content:
                                  Text(AppStrings.reqCopied)),
                        );
                      }
                    },
                    icon:
                        const Icon(Icons.copy_rounded, size: 18),
                    label: Text(AppStrings.reqCopyMessage),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => SharePlus.instance.share(
                      ShareParams(
                        text: group.textPreview!,
                        subject:
                            'Order $poNumber for ${group.supplierName}',
                      ),
                    ),
                    icon:
                        const Icon(Icons.share_outlined, size: 18),
                    label: Text(AppStrings.reqSharePrint),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _poNumberOf(RequisitionSupplierGroup group) {
    // Authoritative PO number from the backend; rendered ONLY in this
    // secondary view, never on the primary order screen (Option 2 UX).
    return group.poNumber.isEmpty
        ? group.poId.substring(0, 8).toUpperCase()
        : group.poNumber;
  }
}
