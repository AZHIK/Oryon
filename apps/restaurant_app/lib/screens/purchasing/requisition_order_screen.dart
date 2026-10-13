/// Order screen (post-submit), Option 2 UX: ONE order grouped by supplier.
///
/// No PO numbers, no procurement terminology in this primary view — just the
/// date, the rollup status, the line count, and one card per supplier with
/// its lines, status badge, and primary action.
///
/// Layout only reflows by device: single-column stacked cards on mobile, a
/// multi-column grid on tablet/desktop as width allows (same components —
/// [LayoutBuilder] + [Breakpoints.of] on the available width).
///
/// "Send via WhatsApp" opens the wa.me deep link (native app on mobile,
/// WhatsApp Web/desktop-app prompt on desktop/tablet) with the message
/// pre-filled. There is no send lifecycle — receiving happens from the
/// purchases list.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants/app_strings.dart';
import '../../models/requisition.dart';
import '../../providers/requisition_cart_provider.dart';
import '../../providers/requisition_order_provider.dart';
import '../../router/app_router.dart';
import '../../theme/app_theme.dart';
import '../../theme/breakpoints.dart';
import '../../utils/formatters.dart';

/// Entry route: shows the just-submitted order when [requisitionId] matches
/// the cart's last submit, otherwise fetches from the backend.
class RequisitionOrderScreen extends ConsumerWidget {
  const RequisitionOrderScreen({super.key, required this.requisitionId});

  final String requisitionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cached = ref.watch(
      requisitionCartProvider.select((c) => c.lastSubmitted),
    );
    if (cached != null && cached.id == requisitionId) {
      return _OrderView(order: cached);
    }
    final orderAsync = ref.watch(requisitionOrderProvider(requisitionId));
    return orderAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: _OrderError(message: e.toString(), requisitionId: requisitionId),
      ),
      data: (order) => _OrderView(order: order),
    );
  }
}

class _OrderError extends ConsumerWidget {
  const _OrderError({required this.message, required this.requisitionId});

  final String message;
  final String requisitionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(Insets.lg),
      children: [
        const SizedBox(height: Insets.xl * 2),
        Icon(
          Icons.error_outline_rounded,
          size: 48,
          color: context.colors.onSurfaceVariant,
        ),
        const SizedBox(height: Insets.md),
        Text(
          AppStrings.reqOrderLoadFailed,
          style: context.text.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: Insets.sm),
        Text(
          message,
          style: context.text.bodySmall?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: Insets.lg),
        Center(
          child: FilledButton.tonal(
            onPressed: () =>
                ref.refresh(requisitionOrderProvider(requisitionId)),
            child: Text(AppStrings.retryAction),
          ),
        ),
      ],
    );
  }
}

class _OrderView extends ConsumerWidget {
  const _OrderView({required this.order});

  final SubmittedRequisition order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final form = context.formFactor;
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.reqOrderReady),
        actions: [
          IconButton(
            tooltip: AppStrings.reqExportTitle,
            onPressed: () => context.push(AppRoute.requisitionExport(order.id)),
            icon: const Icon(Icons.receipt_long_outlined),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final gridForm = Breakpoints.of(constraints.maxWidth);
          final columns = gridForm.isMobile
              ? 1
              : (constraints.maxWidth >= 1100 ? 3 : 2);
          return SingleChildScrollView(
            padding: EdgeInsets.all(Insets.page(form)),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: Breakpoints.maxContentWidth,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _OrderHeader(order: order, rollup: order.rollupStatus),
                    const SizedBox(height: Insets.lg),
                    if (order.priceUnconfirmedItems.isNotEmpty)
                      _TbcBanner(items: order.priceUnconfirmedItems),
                    if (order.priceUnconfirmedItems.isNotEmpty)
                      const SizedBox(height: Insets.lg),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: Insets.lg,
                        mainAxisSpacing: Insets.lg,
                        // Cards size to content; enough height for lines +
                        // action row without inner scrolling.
                        mainAxisExtent: 340,
                      ),
                      itemCount: order.groups.length,
                      itemBuilder: (context, i) {
                        final group = order.groups[i];
                        return _SupplierCard(group: group);
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _OrderHeader extends StatelessWidget {
  const _OrderHeader({required this.order, required this.rollup});

  final SubmittedRequisition order;
  final String rollup;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Insets.lg),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: Insets.lg,
          runSpacing: Insets.sm,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.orderedAt == null
                      ? AppStrings.reqTodaysOrder
                      : 'Order · ${Fmt.relativeDateTime(order.orderedAt!)}',
                  style: context.text.titleMedium,
                ),
                if (order.expectedAt != null)
                  Text(
                    AppStrings.reqDeliverySet(
                      '${order.expectedAt!.day}/${order.expectedAt!.month}/${order.expectedAt!.year}',
                    ),
                    style: context.text.bodySmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            _RollupChip(status: rollup),
            Text(
              '${order.totalLines} ${order.totalLines == 1 ? 'item' : 'items'}',
              style: context.text.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RollupChip extends StatelessWidget {
  const _RollupChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'Fulfilled' => context.semantic.success,
      'Unfulfilled' => context.colors.primary,
      'Cancelled' => context.colors.error,
      _ => context.colors.onSurfaceVariant,
    };
    return Chip(
      avatar: Icon(
        status == 'Fulfilled'
            ? Icons.check_circle_rounded
            : Icons.pending_outlined,
        size: 18,
        color: color,
      ),
      label: Text(status),
      side: BorderSide(color: color),
    );
  }
}

class _TbcBanner extends StatelessWidget {
  const _TbcBanner({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: context.semantic.warningContainer,
      child: Padding(
        padding: const EdgeInsets.all(Insets.md),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: context.semantic.onWarning),
            const SizedBox(width: Insets.sm),
            Expanded(
              child: Text(
                AppStrings.reqTbcBanner(items.join(', ')),
                style: context.text.bodySmall?.copyWith(
                  color: context.semantic.onWarning,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One supplier card: name/icon, lines, item count, badge, send action.
///
/// The only action is the manual wa.me send — there is no PO send
/// lifecycle. Receiving happens from the purchases list.
class _SupplierCard extends ConsumerStatefulWidget {
  const _SupplierCard({required this.group});

  final RequisitionSupplierGroup group;

  @override
  ConsumerState<_SupplierCard> createState() => _SupplierCardState();
}

class _SupplierCardState extends ConsumerState<_SupplierCard> {
  String? _actionError;

  RequisitionSupplierGroup get group => widget.group;

  String get badge {
    return switch (group.status) {
      'fulfilled' => 'Fulfilled',
      'cancelled' => 'Cancelled',
      _ => 'Unfulfilled',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(Insets.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: context.colors.surfaceContainerHighest,
                  child: Text(
                    group.supplierName.isEmpty
                        ? '?'
                        : group.supplierName.characters.first.toUpperCase(),
                    style: context.text.titleSmall,
                  ),
                ),
                const SizedBox(width: Insets.sm),
                Expanded(
                  child: Text(
                    group.supplierName,
                    style: context.text.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _StatusBadge(label: badge),
              ],
            ),
            const SizedBox(height: Insets.sm),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: Insets.sm),
                children: [
                  for (final line in group.lines)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: Insets.xs),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${line.name} · ${line.qty} ${line.unit}',
                              style: context.text.bodyMedium,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (line.priceUnconfirmed)
                            Text(
                              'price TBC',
                              style: context.text.labelSmall?.copyWith(
                                color: context.semantic.warning,
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Items', style: context.text.bodyMedium),
                Text(
                  '${group.lines.length}',
                  style: context.text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Insets.sm),
            if (_actionError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: Insets.xs),
                child: Text(
                  _actionError!,
                  style: context.text.bodySmall?.copyWith(
                    color: context.colors.error,
                  ),
                ),
              ),
            if (!group.hasWhatsapp)
              Text(
                AppStrings.reqAddWhatsappToSend,
                style: context.text.bodySmall?.copyWith(
                  color: context.semantic.warning,
                ),
              )
            else
              FilledButton.icon(
                onPressed: _sendViaWhatsapp,
                icon: const Icon(Icons.send_rounded, size: 18),
                label: Text(AppStrings.reqSendWhatsapp),
                style:
                    FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendViaWhatsapp() async {
    final link = group.deepLink;
    if (link == null) return;
    final uri = Uri.tryParse(link);
    if (uri == null) {
      setState(() => _actionError = AppStrings.reqLinkInvalid);
      return;
    }
    // Mobile: native WhatsApp app. Desktop/tablet: WhatsApp Web or the
    // desktop-app prompt. Both open with the message pre-filled.
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      setState(() => _actionError = AppStrings.reqWhatsappFailed);
      return;
    }
    if (mounted) {
      setState(() => _actionError = null);
    }
  }
}


class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final color = switch (label) {
      'Fulfilled' => context.semantic.success,
      'Unfulfilled' => context.colors.primary,
      'Cancelled' => context.colors.error,
      _ => context.colors.onSurfaceVariant,
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.sm,
        vertical: Insets.xs,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Text(
        label,
        style: context.text.labelSmall?.copyWith(color: color),
      ),
    );
  }
}
