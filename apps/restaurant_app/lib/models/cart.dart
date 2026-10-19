import 'package:flutter/foundation.dart';

import 'menu_item.dart';
import 'order_totals.dart';
import 'payment.dart';

/// One line in the open order.
@immutable
class CartItem {
  const CartItem({
    required this.item,
    required this.quantity,
    this.note,
  });

  final MenuItem item;
  final int quantity;

  /// Kitchen note, e.g. "no onions".
  final String? note;

  double get lineTotal => item.price * quantity;

  CartItem copyWith({int? quantity, String? note}) => CartItem(
    item: item,
    quantity: quantity ?? this.quantity,
    note: note ?? this.note,
  );
}

/// The open order being built on the POS screen.
///
/// Money maths is delegated to [OrderTotals] rather than spelled out here, so
/// the same rules apply once this becomes a completed sale. What the cart owns
/// is the *inputs* to that sum — the lines, the rates — plus how it is being
/// paid for.
@immutable
class Cart {
  const Cart({
    this.items = const [],
    this.taxRate = 0,
    this.discountRate = 0,
    this.payment = const PaymentDetails(),
  });

  final List<CartItem> items;

  /// Sales tax as a fraction, e.g. 0.0825 for 8.25%.
  final double taxRate;

  /// Order-level discount as a fraction of [subtotal].
  final double discountRate;

  /// Tender, amount handed over and settlement time for this ticket. Default
  /// (unsettled) until the payment screen fills it in.
  final PaymentDetails payment;

  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;

  /// True once payment has been confirmed and the sale written to the ledger.
  /// The cart deliberately keeps its lines afterwards — the receipt screen is
  /// still reading them.
  bool get isPaid => payment.isPaid;

  /// Total number of physical items, not lines.
  int get itemCount => items.fold(0, (sum, line) => sum + line.quantity);

  double get subtotal => items.fold(0.0, (sum, line) => sum + line.lineTotal);

  /// This ticket's money, computed by the one implementation of the rules.
  OrderTotals get totals => OrderTotals.from(
    subtotal: subtotal,
    taxRate: taxRate,
    discountRate: discountRate,
  );

  double get discount => totals.discount;

  double get taxableAmount => subtotal - totals.discount;

  double get tax => totals.tax;

  double get total => totals.total;

  /// Quantity of [itemId] currently in the cart, or 0. Used by menu cards to
  /// show their stepper without scanning the list themselves.
  int quantityOf(String itemId) {
    for (final line in items) {
      if (line.item.id == itemId) return line.quantity;
    }
    return 0;
  }

  Cart copyWith({
    List<CartItem>? items,
    double? taxRate,
    double? discountRate,
    PaymentDetails? payment,
  }) {
    return Cart(
      items: items ?? this.items,
      taxRate: taxRate ?? this.taxRate,
      discountRate: discountRate ?? this.discountRate,
      payment: payment ?? this.payment,
    );
  }
}
