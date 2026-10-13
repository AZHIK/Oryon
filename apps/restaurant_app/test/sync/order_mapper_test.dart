/// Tests for the sales read-side mapper: the enum round-trips and
/// `orderFromCachedRow`'s assembly of a cached sale + lines into an `Order`.
library;

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:restaurant_pos/database/app_database.dart';
import 'package:restaurant_pos/models/order.dart';
import 'package:restaurant_pos/sync/order_mapper.dart';

CachedItem _item(String id, String name) => CachedItem(
      id: id,
      businessId: 'biz-1',
      businessLocationId: 'store-1',
      name: name,
      unitOfMeasure: 'unit',
      unitId: '',
      reorderThreshold: Decimal.zero,
      reorderQuantity: Decimal.zero,
      allowNegativeStock: false,
      itemType: 'sellable',
      isActive: true,
      createdAtServer: DateTime(2026),
      updatedAtServer: DateTime(2026),
      lastSeenAt: DateTime(2026),
      lastSyncedAt: DateTime(2026),
      supplierId: '',
    );

void main() {
  group('orderStatusFromBackend / orderStatusToBackend', () {
    test('round-trip for voided and refunded', () {
      for (final status in [OrderStatus.voided, OrderStatus.refunded]) {
        final backend = orderStatusToBackend(status);
        expect(orderStatusFromBackend(backend), status);
      }
    });

    test('a completed sale maps to paid, never to the local pending state', () {
      expect(orderStatusFromBackend('completed'), OrderStatus.paid);
      expect(orderStatusToBackend(OrderStatus.paid), 'completed');
      expect(orderStatusToBackend(OrderStatus.pending), 'completed');
    });
  });

  group('paymentMethodToBackend / paymentMethodFromBackend', () {
    test('round-trip for the tenders the backend actually distinguishes', () {
      for (final type in [PaymentType.cash, PaymentType.card, PaymentType.mobile]) {
        final backend = paymentMethodToBackend(type);
        expect(paymentMethodFromBackend(backend), type);
      }
    });

    test('qris and giftCard both collapse to other outbound', () {
      expect(paymentMethodToBackend(PaymentType.qris), 'other');
      expect(paymentMethodToBackend(PaymentType.giftCard), 'other');
    });

    test('other maps back to giftCard, never silently to a real card swipe', () {
      expect(paymentMethodFromBackend('other'), PaymentType.giftCard);
    });
  });

  group('orderFromCachedRow', () {
    final sale = CachedSale(
      id: 'sale-server-1',
      businessId: 'biz-1',
      storeId: 'store-1',
      clientSaleId: 'client-uuid-1',
      status: 'completed',
      subtotal: Decimal.parse('20.00'),
      discountAmount: Decimal.parse('2.00'),
      taxAmount: Decimal.parse('1.44'),
      total: Decimal.parse('19.44'),
      paymentMethod: 'cash',
      occurredAt: DateTime(2026, 1, 2, 12),
      syncedAt: DateTime(2026, 1, 2, 12, 1),
      createdAt: DateTime(2026, 1, 2, 12),
      lastSyncedAt: DateTime(2026, 1, 2, 12, 1),
    );

    final lines = [
      CachedSaleLineItem(
        id: 'line-1',
        saleId: 'sale-server-1',
        itemId: 'item-1',
        quantity: Decimal.fromInt(2),
        unitPrice: Decimal.parse('10.00'),
        discountAmount: Decimal.zero,
        lineTotal: Decimal.parse('20.00'),
      ),
    ];

    final itemsById = {'item-1': _item('item-1', 'Pilau')};

    test('uses the recovered local ticket number when this device placed it', () {
      final order = orderFromCachedRow(
        sale: sale,
        lines: lines,
        itemsById: itemsById,
        localOrderId: 'ORD-0007',
      );

      expect(order.id, 'ORD-0007');
      expect(order.serverSaleId, 'sale-server-1');
    });

    test('falls back to the clientSaleId for a sale from another device', () {
      final order = orderFromCachedRow(sale: sale, lines: lines, itemsById: itemsById);
      expect(order.id, 'client-uuid-1');
    });

    test('resolves line item names from the catalog, not the backend', () {
      final order = orderFromCachedRow(sale: sale, lines: lines, itemsById: itemsById);
      expect(order.lines.single.name, 'Pilau');
      expect(order.lines.single.quantity, 2);
      expect(order.lines.single.unitPrice, 10.0);
    });

    test('a line whose item is missing from the cache falls back gracefully', () {
      final order = orderFromCachedRow(sale: sale, lines: lines, itemsById: const {});
      expect(order.lines.single.name, 'Removed item');
    });

    test('discount and tax rates reproduce the server totals', () {
      final order = orderFromCachedRow(sale: sale, lines: lines, itemsById: itemsById);
      expect(order.subtotal, closeTo(20.00, 0.001));
      expect(order.discount, closeTo(2.00, 0.001));
      expect(order.tax, closeTo(1.44, 0.001));
      expect(order.total, closeTo(19.44, 0.001));
    });

    test('status and payment method carry through', () {
      final order = orderFromCachedRow(sale: sale, lines: lines, itemsById: itemsById);
      expect(order.status, OrderStatus.paid);
      expect(order.paymentType, PaymentType.cash);
    });

    test('a sale with no customer attributed maps to a null customerId', () {
      final order = orderFromCachedRow(sale: sale, lines: lines, itemsById: itemsById);
      expect(order.customerId, null);
    });

    test('a line without a snapshot maps to a null unitCost', () {
      final order = orderFromCachedRow(sale: sale, lines: lines, itemsById: itemsById);
      expect(order.lines.single.unitCost, null);
    });

    test('a line snapshot carries through onto the mapped OrderLine', () {
      final snapshotted = [
        CachedSaleLineItem(
          id: 'line-1',
          saleId: 'sale-server-1',
          itemId: 'item-1',
          quantity: Decimal.fromInt(2),
          unitPrice: Decimal.parse('10.00'),
          discountAmount: Decimal.zero,
          lineTotal: Decimal.parse('20.00'),
          unitCost: Decimal.parse('3.50'),
        ),
      ];
      final order = orderFromCachedRow(
        sale: sale,
        lines: snapshotted,
        itemsById: itemsById,
      );
      expect(order.lines.single.unitCost, 3.5);
    });

    test('customerId carries through onto the mapped Order', () {
      final attributedSale = CachedSale(
        id: 'sale-server-2',
        businessId: 'biz-1',
        storeId: 'store-1',
        clientSaleId: 'client-uuid-2',
        customerId: 'cust-uuid-1',
        status: 'completed',
        subtotal: Decimal.parse('20.00'),
        discountAmount: Decimal.parse('2.00'),
        taxAmount: Decimal.parse('1.44'),
        total: Decimal.parse('19.44'),
        paymentMethod: 'cash',
        occurredAt: DateTime(2026, 1, 2, 12),
        syncedAt: DateTime(2026, 1, 2, 12, 1),
        createdAt: DateTime(2026, 1, 2, 12),
        lastSyncedAt: DateTime(2026, 1, 2, 12, 1),
      );

      final order = orderFromCachedRow(sale: attributedSale, lines: lines, itemsById: itemsById);
      expect(order.customerId, 'cust-uuid-1');
    });
  });
}
