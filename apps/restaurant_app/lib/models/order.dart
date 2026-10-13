import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import 'cart.dart';
import 'order_totals.dart';
import 'payment.dart';

enum PaymentType {
  cash('cashLabel', 'Cash', Icons.payments_outlined),
  card('cardLabel', 'Card', Icons.credit_card_rounded),
  qris('qrisLabel', 'QRIS', Icons.qr_code_2_rounded),
  mobile('mobilePayLabel', 'Mobile Pay', Icons.contactless_rounded),
  giftCard('giftCardLabel', 'Gift Card', Icons.card_giftcard_rounded);

  const PaymentType(this.labelKey, this.labelDefault, this.icon);
  final String labelKey;
  final String labelDefault;
  final IconData icon;

  String get label => L10n.t(labelKey, labelDefault);

  /// The tenders a terminal offers at the counter, in the order they appear on
  /// the payment screen. The rest of the enum still exists because historical
  /// sales were taken on them.
  static const counterTenders = [cash, card, qris];

  /// Card and QRIS settle through a simulated terminal here: no amount is
  /// keyed in, the payment is simply approved or not.
  bool get isTerminal => this == card || this == qris || this == mobile;
}

enum OrderStatus {
  paid('paidStatus', 'Paid'),
  refunded('refundedStatus', 'Refunded'),

  /// Cancelled before payment settled — distinct from a refund, which returns
  /// money that was actually taken.
  voided('voidedStatus', 'Voided'),
  pending('pendingStatus', 'Pending');

  const OrderStatus(this.labelKey, this.labelDefault);
  final String labelKey;
  final String labelDefault;

  String get label => L10n.t(labelKey, labelDefault);

  /// Voided and refunded tickets are both excluded from takings.
  bool get countsAsRevenue => this == OrderStatus.paid;
}

/// Fulfillment stage of an order (kitchen workflow), independent of payment status.
enum FulfillmentStatus {
  new_('newStatus', 'New', Icons.inbox_rounded),
  preparing('preparingStatus', 'Preparing', Icons.schedule_rounded),
  ready('readyStatus', 'Ready', Icons.check_circle_rounded),
  outForDelivery('outForDeliveryStatus', 'Out for Delivery', Icons.two_wheeler_rounded),
  completed('completedStatus', 'Completed', Icons.done_all_rounded);

  const FulfillmentStatus(this.labelKey, this.labelDefault, this.icon);
  final String labelKey;
  final String labelDefault;
  final IconData icon;

  String get label => L10n.t(labelKey, labelDefault);
}

/// How the order leaves the counter. Drives the table-number field on the POS
/// order panel and is recorded on the finished sale.
enum OrderType {
  dineIn('dineInType', 'Dine-in', Icons.restaurant_rounded),
  takeaway('takeawayType', 'Takeaway', Icons.takeout_dining_rounded),
  delivery('deliveryType', 'Delivery', Icons.delivery_dining_rounded);

  const OrderType(this.labelKey, this.labelDefault, this.icon);
  final String labelKey;
  final String labelDefault;
  final IconData icon;

  String get label => L10n.t(labelKey, labelDefault);

  /// Only dine-in orders are seated, so only they take a table number.
  bool get usesTable => this == OrderType.dineIn;
}

/// A denormalised snapshot of a menu item at the time of sale.
///
/// Sales history must not change when the menu is edited, so the name and
/// price are copied rather than referenced. [unitCost] is the same idea
/// for production cost: the recipe cost at current grocery prices when the
/// ticket closed. Null means unknown (no recipe and no cost on file) —
/// profit figures fall back to live costs for those lines.
@immutable
class OrderLine {
  const OrderLine({
    required this.itemId,
    required this.name,
    required this.emoji,
    required this.unitPrice,
    required this.quantity,
    this.note,
    this.unitCost,
  });

  final String itemId;
  final String name;
  final String emoji;
  final double unitPrice;
  final int quantity;
  final String? note;
  final double? unitCost;

  double get lineTotal => unitPrice * quantity;

  /// This line's production cost at sale time, or null when unknown.
  double? get lineCost =>
      unitCost == null ? null : unitCost! * quantity;
}

/// A completed sale.
@immutable
class Order {
  const Order({
    required this.id,
    required this.lines,
    required this.placedAt,
    required this.paymentType,
    required this.status,
    required this.taxRate,
    this.orderType = OrderType.dineIn,
    this.discountRate = 0,
    this.fulfillmentStatus = FulfillmentStatus.new_,
    this.tableLabel,
    this.serverName = 'House',
    this.amountTendered,
    this.customerId,
    this.courierId,
    this.serverSaleId,
  });

  final String id;
  final List<OrderLine> lines;
  final DateTime placedAt;
  final PaymentType paymentType;
  final OrderStatus status;
  final double taxRate;
  final OrderType orderType;
  final double discountRate;
  final FulfillmentStatus fulfillmentStatus;

  /// e.g. "Table 12" or null for counter/takeaway orders.
  final String? tableLabel;
  final String serverName;

  /// Cash handed over, kept so a reprinted receipt still shows the change
  /// given. Null for card, QRIS and every other terminal tender.
  final double? amountTendered;

  /// Associated customer id, if the order was placed by a registered customer.
  final String? customerId;

  /// Assigned courier id, for delivery orders.
  final String? courierId;

  /// POS Service's own `Sale.id`, once this order has been synced. Null for
  /// an order that only exists locally (not yet synced, or placed with no
  /// store context at all) — refund/void target this id directly rather
  /// than [id], which stays this device's stable "ORD-0042" ticket number
  /// across the whole lifecycle (see `order_mapper.dart`).
  final String? serverSaleId;

  /// The numeric part of the ticket id, for composing a receipt number under
  /// whatever prefix Store Settings is configured with.
  ///
  /// The order id and the receipt number are deliberately different strings
  /// for the same sale: the ledger keys on "ORD-0042" forever, while the paper
  /// the customer takes away carries the venue's own numbering ("INV-0042").
  String get receiptSuffix => id.split('-').last;

  int get itemCount => lines.fold(0, (sum, line) => sum + line.quantity);

  double get subtotal => lines.fold(0.0, (sum, line) => sum + line.lineTotal);

  /// The same arithmetic the open ticket used, so a sale never re-adds to a
  /// different number than the receipt it was printed from.
  OrderTotals get totals => OrderTotals.from(
    subtotal: subtotal,
    taxRate: taxRate,
    discountRate: discountRate,
  );

  /// How this sale was settled, in the shape the shared payment widgets take.
  PaymentDetails get payment => PaymentDetails(
    method: paymentType,
    amountTendered: amountTendered,
    orderId: id,
    settledAt: placedAt,
  );

  double get discount => totals.discount;

  double get tax => totals.tax;

  double get total => totals.total;

  /// Refunded and voided tickets are excluded from revenue totals.
  double get netRevenue => status.countsAsRevenue ? total : 0;

  /// Whether this order was placed recently (within the last 15 minutes).
  bool isRecent(DateTime now) =>
      now.difference(placedAt).inMinutes < 15;

  Order copyWith({
    List<OrderLine>? lines,
    PaymentType? paymentType,
    OrderStatus? status,
    OrderType? orderType,
    FulfillmentStatus? fulfillmentStatus,
    String? tableLabel,
    String? serverName,
    double? amountTendered,
    String? customerId,
    String? courierId,
  }) {
    return Order(
      id: id,
      lines: lines ?? this.lines,
      placedAt: placedAt,
      paymentType: paymentType ?? this.paymentType,
      status: status ?? this.status,
      taxRate: taxRate,
      orderType: orderType ?? this.orderType,
      fulfillmentStatus: fulfillmentStatus ?? this.fulfillmentStatus,
      discountRate: discountRate,
      tableLabel: tableLabel ?? this.tableLabel,
      serverName: serverName ?? this.serverName,
      amountTendered: amountTendered ?? this.amountTendered,
      customerId: customerId ?? this.customerId,
      courierId: courierId ?? this.courierId,
      serverSaleId: serverSaleId,
    );
  }

  /// Builds a completed sale from the open [cart].
  ///
  /// The tender defaults to whatever the cart was paid with, so the payment
  /// screen does not have to restate what it already recorded.
  ///
  /// [unitCosts] snapshots each line's production cost (item id → per-unit
  /// cost at sale time). Absent ids stay null — unknown, not zero.
  factory Order.fromCart({
    required String id,
    required Cart cart,
    required DateTime placedAt,
    PaymentType? paymentType,
    double? amountTendered,
    OrderType orderType = OrderType.dineIn,
    String? tableLabel,
    String serverName = 'House',
    OrderStatus status = OrderStatus.paid,
    String? customerId,
    String? courierId,
    Map<String, double>? unitCosts,
  }) {
    return Order(
      id: id,
      placedAt: placedAt,
      paymentType: paymentType ?? cart.payment.method,
      status: status,
      taxRate: cart.taxRate,
      orderType: orderType,
      discountRate: cart.discountRate,
      tableLabel: tableLabel,
      serverName: serverName,
      amountTendered: amountTendered ?? cart.payment.amountTendered,
      customerId: customerId,
      courierId: courierId,
      lines: [
        for (final line in cart.items)
          OrderLine(
            itemId: line.item.id,
            name: line.item.name,
            emoji: line.item.emoji,
            unitPrice: line.item.price,
            quantity: line.quantity,
            note: line.note,
            unitCost: unitCosts?[line.item.id],
          ),
      ],
    );
  }
}
