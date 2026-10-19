import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_strings.dart';
import '../models/order_totals.dart';
import '../models/payment.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../theme/breakpoints.dart';
import '../utils/formatters.dart';
import 'section_label.dart';

/// One label/value line in a totals block.
///
/// Public because every screen in the checkout flow needs the same row, and a
/// private copy per screen is exactly how four subtly different "Subtotal"
/// rows come to exist.
class TotalsRow extends StatelessWidget {
  const TotalsRow({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.muted = false,
    this.valueColor,
    this.emphasis = false,
  });

  final String label;
  final String value;

  /// Optional leading glyph, e.g. the tender's icon on the "Method" row.
  final IconData? icon;
  final bool muted;
  final Color? valueColor;

  /// Steps the row up a size — for the one number the reader is looking for.
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final base = emphasis ? context.text.bodyMedium : context.text.bodySmall;
    final style = base?.copyWith(
      color: muted ? context.colors.onSurfaceVariant : null,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: style?.color),
            const SizedBox(width: Insets.xs + 2),
          ],
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
          const SizedBox(width: Insets.sm),
          // Flexible rather than fixed: at 360px a five-figure total still has
          // to give way to an ellipsis instead of painting past the panel.
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: style?.copyWith(
                fontWeight: emphasis ? FontWeight.w700 : FontWeight.w600,
                color: valueColor ?? style.color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Subtotal, discount, tax, total — and, when a payment is supplied, how it
/// was settled.
///
/// The one totals rendering in the app. The POS ticket footer, the payment
/// screen's panel, the printed receipt and the sale-detail breakdown are all
/// this widget with different arguments, which is what stops the tax line
/// drifting between the screen a customer is shown and the receipt they take
/// away.
class PaymentBreakdown extends ConsumerWidget {
  const PaymentBreakdown({
    super.key,
    required this.totals,
    this.payment,
    this.compact = false,
    this.highlightChange = false,
  });

  final OrderTotals totals;

  /// Appends the tender rows: method, and for cash the amount handed over and
  /// the change due. Null while the order is still being built.
  final PaymentDetails? payment;

  /// Drops the total to a size that survives the narrowed tablet panel.
  final bool compact;

  /// Renders change due as the row the cashier's eye lands on. On for the
  /// payment screen, where counting out the right money is the live task; off
  /// for the receipt, where it is a record.
  final bool highlightChange;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payment = this.payment;
    final change = payment?.changeFor(totals);
    // Tax switch: off = no tax row anywhere this widget is used
    // (POS footer, charge dialog, cart sheet, receipt preview).
    final showTax = ref.watch(taxEnabledProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TotalsRow(
          label: AppStrings.subtotalLabel,
          value: Fmt.money(totals.subtotal),
          muted: true,
        ),
        if (totals.hasDiscount)
          TotalsRow(
            label: AppStrings.discountLabel(Fmt.percent(totals.discountRate)),
            value: AppStrings.discountValue(Fmt.money(totals.discount)),
            muted: true,
            valueColor: context.semantic.success,
          ),
        if (showTax)
          TotalsRow(
            label: AppStrings.taxLabel(Fmt.percent(totals.taxRate)),
            value: Fmt.money(totals.tax),
            muted: true,
          ),
        const _Rule(),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: SectionLabel(AppStrings.totalLabel)),
            const SizedBox(width: Insets.sm),
            Flexible(
              child: Text(
                Fmt.money(totals.total),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style:
                    (compact
                            ? context.text.moneyLarge
                            : context.text.headlineSmall)
                        ?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
        if (payment != null) ...[
          const _Rule(),
          TotalsRow(
            label: AppStrings.methodLabel,
            value: payment.method.label,
            icon: payment.method.icon,
            muted: true,
          ),
          if (payment.isCash && payment.amountTendered != null)
            TotalsRow(
              label: AppStrings.tenderedLabel,
              value: Fmt.money(payment.amountTendered!),
              muted: true,
            ),
          if (change != null)
            TotalsRow(
              label: AppStrings.changeDue,
              value: Fmt.money(change),
              muted: !highlightChange,
              emphasis: highlightChange,
              valueColor: highlightChange ? context.semantic.success : null,
            ),
        ],
      ],
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: Insets.sm),
    child: Divider(height: 1),
  );
}

/// A titled block around a [PaymentBreakdown], with room for actions beneath.
///
/// This is the form the receipt's totals and the sale-detail side panel take.
/// The POS and payment side panels do not use it — they put the same
/// [PaymentBreakdown] inside the ticket footer they already own, so the panel
/// keeps its single unbroken edge.
class PaymentSummaryPanel extends StatelessWidget {
  const PaymentSummaryPanel({
    super.key,
    required this.totals,
    this.payment,
    this.title,
    this.action,
    this.compact = false,
    this.highlightChange = false,
    this.bordered = true,
  });

  final OrderTotals totals;
  final PaymentDetails? payment;

  /// Section heading. Omitted where the surrounding layout already names the
  /// block, as the receipt does.
  final String? title;

  /// Buttons or a note below the rows — "Confirm payment", a refund notice.
  final Widget? action;

  final bool compact;
  final bool highlightChange;

  /// Off when the panel is nested inside another card, where a second border
  /// would read as a box in a box.
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (title != null) ...[
          SectionLabel(title!),
          const SizedBox(height: Insets.md),
        ],
        PaymentBreakdown(
          totals: totals,
          payment: payment,
          compact: compact,
          highlightChange: highlightChange,
        ),
        if (action != null) ...[const SizedBox(height: Insets.lg), action!],
      ],
    );

    if (!bordered) return content;

    return Container(
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerLowest,
        borderRadius: Radii.card,
        border: Border.all(color: context.semantic.hairline),
      ),
      padding: const EdgeInsets.all(Insets.lg),
      child: content,
    );
  }
}
