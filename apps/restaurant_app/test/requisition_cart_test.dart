/// Tests for the requisition (unified multi-supplier order) flow.
///
/// - Cart state machine (pure provider logic, no network): add/merge,
///   per-item assignment, bulk scopes + the explicit override toggle,
///   submit blockers, session clearing.
/// - `SubmittedRequisition.fromJson`: PO-number parsing (kept for the export
///   view only), group building, badge mapping.
/// - Submit success path with a fake API: lines carry supplier_ids, the
///   cart clears, and the response parses into supplier groups.
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:restaurant_pos/models/requisition.dart';
import 'package:restaurant_pos/models/supplier.dart';
import 'package:restaurant_pos/providers/permissions_provider.dart';
import 'package:restaurant_pos/providers/requisition_cart_provider.dart';
import 'package:restaurant_pos/providers/suppliers_provider.dart';
import 'package:restaurant_pos/services/requisition_api_service.dart';

import 'test_helpers/test_container.dart';

Map<String, dynamic> _submitResponse() => {
      'requisition': {
        'id': 'req-1',
        'business_id': 'biz-1',
        'store_id': 'store-1',
        'notes': 'weekly restock',
        'expected_at': '2026-10-05T08:00:00Z',
        'idempotency_key': 'key-1',
        'created_at': '2026-09-28T10:00:00Z',
      },
      'purchase_orders': [
        {
          'id': 'po-a',
          'supplier_id': 'sup-a',
          'po_number': 'PO-0042',
          'status': 'unfulfilled',
          'requisition_id': 'req-1',
        },
        {
          'id': 'po-b',
          'supplier_id': 'sup-b',
          'po_number': 'PO-0043',
          'status': 'unfulfilled',
          'requisition_id': 'req-1',
        },
      ],
      'messages': [
        {
          'id': 'msg-a',
          'po_id': 'po-a',
          'direction': 'outbound',
          'channel': 'whatsapp',
          'payload': {
            'po_id': 'po-a',
            'supplier': {
              'name': 'Supplier A',
              'whatsapp_number': '+255700000001'
            },
            'message_type': 'purchase_order',
            'text_preview': 'Hello Supplier A, new order…',
            'structured_data': {
              'po_number': 'PO-0042',
              'restaurant_name': 'Mama Kitchen',
              'order_date': '2026-09-28',
              'delivery_requested_date': '2026-10-05',
              'items': [
                {
                  'name': 'Flour',
                  'qty': '20.000',
                  'unit': 'kg',
                },
                {
                  'name': 'Sugar',
                  'qty': '10.000',
                  'unit': 'kg',
                },
              ],
              'notes': 'weekly restock',
            },
            'deep_link': 'https://wa.me/255700000001?text=Hello',
          },
          'status': 'ready',
          'created_at': '2026-09-28T10:00:00Z',
          'sent_at': null,
        },
      ],
      'price_unconfirmed_items': ['Sugar'],
      'rollup_status': 'Unfulfilled',
    };

class FakeRequisitionApi extends RequisitionApiService {
  FakeRequisitionApi() : super(dio: Dio());

  List<Map<String, dynamic>>? capturedLines;
  int submitCount = 0;

  @override
  Future<Map<String, dynamic>> submit({
    required String businessId,
    required String storeId,
    required List<Map<String, dynamic>> lines,
    required String idempotencyKey,
    String? notes,
    DateTime? expectedAt,
  }) async {
    submitCount++;
    capturedLines = lines;
    return _submitResponse();
  }
}

Supplier _supplier(String id, String name) => Supplier(
      id: id,
      name: name,
      phone: '+255700000000',
      createdAt: DateTime.utc(2026, 1, 1),
    );

ProviderContainer _cartContainer(FakeRequisitionApi fake) =>
    newTestContainer(
      extraOverrides: [
        requisitionApiServiceProvider.overrideWithValue(fake),
        currentBusinessIdProvider.overrideWithValue('biz-1'),
        currentStoreIdProvider.overrideWithValue('store-1'),
        suppliersListProvider.overrideWithValue(
            [_supplier('sup-a', 'Supplier A'), _supplier('sup-b', 'Supplier B')]),
      ],
    );

void _addTwoLines(RequisitionCartNotifier notifier) {
  notifier.addItem(
      itemId: 'flour', itemName: 'Flour', unit: 'kg', qty: 2);
  notifier.addItem(
      itemId: 'sugar', itemName: 'Sugar', unit: 'kg', qty: 1);
}

void main() {
  group('RequisitionCartState', () {
    test('addItem merges duplicate items by summing qty', () {
      final container = _cartContainer(FakeRequisitionApi());
      final notifier = container.read(requisitionCartProvider.notifier);
      notifier.addItem(
          itemId: 'flour', itemName: 'Flour', unit: 'kg', qty: 2);
      notifier.addItem(
          itemId: 'flour', itemName: 'Flour', unit: 'kg', qty: 3);
      final lines = container.read(requisitionCartProvider).lines;
      expect(lines, hasLength(1));
      expect(lines.first.qty, 5);
    });

    test('setQty to zero removes the line', () {
      final container = _cartContainer(FakeRequisitionApi());
      final notifier = container.read(requisitionCartProvider.notifier);
      _addTwoLines(notifier);
      notifier.setQty('flour', 0);
      expect(
          container.read(requisitionCartProvider).lines.map((l) => l.itemId),
          ['sugar']);
    });

    test('empty cart blocks submit with the add-items message', () {
      final container = _cartContainer(FakeRequisitionApi());
      final state = container.read(requisitionCartProvider);
      expect(state.canSubmit, isFalse);
      expect(state.submitBlocker, isNotNull);
    });

    test('unassigned lines block submit and name the count', () {
      final container = _cartContainer(FakeRequisitionApi());
      final notifier = container.read(requisitionCartProvider.notifier);
      _addTwoLines(notifier);
      notifier.assignSupplierToLine(
          itemId: 'flour', supplierId: 'sup-a', supplierName: 'Supplier A');
      final state = container.read(requisitionCartProvider);
      expect(state.unassignedCount, 1);
      expect(state.canSubmit, isFalse);
      expect(state.submitBlocker, contains('1'));
    });

    test('per-item assignment overrides that line only', () {
      final container = _cartContainer(FakeRequisitionApi());
      final notifier = container.read(requisitionCartProvider.notifier);
      _addTwoLines(notifier);
      notifier.assignSupplierToLine(
          itemId: 'flour', supplierId: 'sup-a', supplierName: 'Supplier A');
      final lines = container.read(requisitionCartProvider).lines;
      expect(lines.firstWhere((l) => l.itemId == 'flour').supplierId,
          'sup-a');
      expect(
          lines.firstWhere((l) => l.itemId == 'sugar').supplierId, isNull);
    });

    test('bulk unassigned-only preserves manual picks', () {
      final container = _cartContainer(FakeRequisitionApi());
      final notifier = container.read(requisitionCartProvider.notifier);
      _addTwoLines(notifier);
      notifier.assignSupplierToLine(
          itemId: 'sugar', supplierId: 'sup-b', supplierName: 'Supplier B');
      notifier.bulkAssign(
          supplierId: 'sup-a', supplierName: 'Supplier A');
      final lines = container.read(requisitionCartProvider).lines;
      expect(lines.firstWhere((l) => l.itemId == 'flour').supplierId,
          'sup-a');
      // Manual pick survives the default bulk scope.
      expect(lines.firstWhere((l) => l.itemId == 'sugar').supplierId,
          'sup-b');
    });

    test('bulk all-items without overwrite keeps manual picks', () {
      final container = _cartContainer(FakeRequisitionApi());
      final notifier = container.read(requisitionCartProvider.notifier);
      _addTwoLines(notifier);
      notifier.assignSupplierToLine(
          itemId: 'sugar', supplierId: 'sup-b', supplierName: 'Supplier B');
      notifier.bulkAssign(
        supplierId: 'sup-a',
        supplierName: 'Supplier A',
        scope: BulkScope.all,
      );
      expect(
          container
              .read(requisitionCartProvider)
              .lines
              .firstWhere((l) => l.itemId == 'sugar')
              .supplierId,
          'sup-b');
    });

    test('bulk all-items with overwrite replaces manual picks', () {
      final container = _cartContainer(FakeRequisitionApi());
      final notifier = container.read(requisitionCartProvider.notifier);
      _addTwoLines(notifier);
      notifier.assignSupplierToLine(
          itemId: 'sugar', supplierId: 'sup-b', supplierName: 'Supplier B');
      notifier.bulkAssign(
        supplierId: 'sup-a',
        supplierName: 'Supplier A',
        scope: BulkScope.all,
        overwriteAll: true,
      );
      final lines = container.read(requisitionCartProvider).lines;
      expect(lines.every((l) => l.supplierId == 'sup-a'), isTrue);
      expect(lines.every((l) => l.assignmentSource == 'bulk_all'), isTrue);
    });

    test('submit sends supplier_ids and clears the cart', () async {
      final fake = FakeRequisitionApi();
      final container = _cartContainer(fake);
      final notifier = container.read(requisitionCartProvider.notifier);
      _addTwoLines(notifier);
      notifier.assignSupplierToLine(
          itemId: 'flour', supplierId: 'sup-a', supplierName: 'Supplier A');
      notifier.assignSupplierToLine(
          itemId: 'sugar', supplierId: 'sup-b', supplierName: 'Supplier B');

      final submitted = await notifier.submit();

      expect(fake.submitCount, 1);
      expect(fake.capturedLines, hasLength(2));
      expect(
          fake.capturedLines!
              .firstWhere((l) => l['item_id'] == 'flour')['supplier_id'],
          'sup-a');
      // Two POs, one per supplier; payload only for the supplier that has
      // a WhatsApp number on file.
      expect(submitted.groups, hasLength(2));
      expect(submitted.groups.first.poNumber, 'PO-0042');
      expect(submitted.priceUnconfirmedItems, ['Sugar']);
      // Session cart cleared after submit.
      expect(container.read(requisitionCartProvider).lines, isEmpty);
      expect(container.read(requisitionCartProvider).lastSubmitted?.id,
          'req-1');
    });

    test('submit without suppliers throws the blocker', () async {
      final container = _cartContainer(FakeRequisitionApi());
      final notifier = container.read(requisitionCartProvider.notifier);
      _addTwoLines(notifier);
      await expectLater(notifier.submit(), throwsA(isA<Exception>()));
    });
  });

  group('preferred-supplier prefill', () {
    test('addItem with supplier params pre-assigns the line', () {
      final container = _cartContainer(FakeRequisitionApi());
      final notifier = container.read(requisitionCartProvider.notifier);
      notifier.addItem(
        itemId: 'flour',
        itemName: 'Flour',
        unit: 'kg',
        qty: 2,
        supplierId: 'sup-a',
        supplierName: 'Supplier A',
        assignmentSource: 'preferred',
      );
      final line =
          container.read(requisitionCartProvider).lines.single;
      expect(line.supplierId, 'sup-a');
      expect(line.supplierName, 'Supplier A');
      expect(line.assignmentSource, 'preferred');
      expect(container.read(requisitionCartProvider).unassignedCount, 0);
    });

    test('re-add fills a still-unassigned line but never overwrites', () {
      final container = _cartContainer(FakeRequisitionApi());
      final notifier = container.read(requisitionCartProvider.notifier);
      // No supplier on first add (directory not loaded yet, say).
      notifier.addItem(
          itemId: 'flour', itemName: 'Flour', unit: 'kg', qty: 2);
      // Second add resolves the preferred supplier → fills it in.
      notifier.addItem(
        itemId: 'flour',
        itemName: 'Flour',
        unit: 'kg',
        qty: 1,
        supplierId: 'sup-a',
        supplierName: 'Supplier A',
        assignmentSource: 'preferred',
      );
      var line = container.read(requisitionCartProvider).lines.single;
      expect(line.qty, 3);
      expect(line.supplierId, 'sup-a');

      // A manual change wins over any later prefill.
      notifier.assignSupplierToLine(
          itemId: 'flour',
          supplierId: 'sup-b',
          supplierName: 'Supplier B');
      notifier.addItem(
        itemId: 'flour',
        itemName: 'Flour',
        unit: 'kg',
        qty: 1,
        supplierId: 'sup-a',
        supplierName: 'Supplier A',
        assignmentSource: 'preferred',
      );
      line = container.read(requisitionCartProvider).lines.single;
      expect(line.qty, 4);
      expect(line.supplierId, 'sup-b');
      expect(line.assignmentSource, 'manual_per_item');
    });

    test('prefilled line stays changeable per line and in bulk', () {
      final container = _cartContainer(FakeRequisitionApi());
      final notifier = container.read(requisitionCartProvider.notifier);
      notifier.addItem(
        itemId: 'flour',
        itemName: 'Flour',
        unit: 'kg',
        qty: 2,
        supplierId: 'sup-a',
        supplierName: 'Supplier A',
        assignmentSource: 'preferred',
      );
      // Per-line change.
      notifier.assignSupplierToLine(
          itemId: 'flour',
          supplierId: 'sup-b',
          supplierName: 'Supplier B');
      expect(
          container
              .read(requisitionCartProvider)
              .lines
              .single
              .supplierId,
          'sup-b');
      // One supplier for all (explicit override).
      notifier.bulkAssign(
        supplierId: 'sup-a',
        supplierName: 'Supplier A',
        scope: BulkScope.all,
        overwriteAll: true,
      );
      expect(
          container
              .read(requisitionCartProvider)
              .lines
              .single
              .supplierId,
          'sup-a');
    });

    test('findPreferredSupplier matches the directory only', () {
      final directory = [_supplier('sup-a', 'Supplier A')];
      expect(
          findPreferredSupplier(directory, 'sup-a')?.name, 'Supplier A');
      expect(findPreferredSupplier(directory, 'sup-unknown'), isNull);
      expect(findPreferredSupplier(directory, null), isNull);
      expect(findPreferredSupplier(directory, ''), isNull);
      expect(findPreferredSupplier(const [], 'sup-a'), isNull);
    });
  });

  group('SubmittedRequisition.fromJson', () {
    test('parses groups, badges, line counts and TBC flags', () {
      final order = SubmittedRequisition.fromJson(
        _submitResponse(),
        {'sup-a': 'Supplier A', 'sup-b': 'Supplier B'},
      );
      expect(order.id, 'req-1');
      expect(order.rollupStatus, 'Unfulfilled');
      expect(order.totalLines, 2);

      final groupA = order.groups.firstWhere((g) => g.poId == 'po-a');
      expect(groupA.poNumber, 'PO-0042');
      expect(groupA.supplierName, 'Supplier A');
      expect(groupA.badge, 'Unfulfilled');
      expect(groupA.isTerminal, isFalse);
      expect(groupA.hasWhatsapp, isTrue);
      expect(groupA.deepLink, startsWith('https://wa.me/'));
      expect(groupA.lines, hasLength(2));
      expect(groupA.lines.last.priceUnconfirmed, isTrue);

      // No message row for sup-b → WhatsApp unavailable, PO still listed.
      final groupB = order.groups.firstWhere((g) => g.poId == 'po-b');
      expect(groupB.hasWhatsapp, isFalse);
      expect(groupB.deepLink, isNull);
    });

    test('badge maps backend lifecycle to staff-facing states', () {
      RequisitionSupplierGroup groupWith(String status) =>
          RequisitionSupplierGroup(
            poId: 'po',
            poNumber: 'PO-1',
            supplierId: 'sup',
            supplierName: 'S',
            status: status,
            lines: const [],
          );
      expect(groupWith('unfulfilled').badge, 'Unfulfilled');
      expect(groupWith('fulfilled').badge, 'Fulfilled');
      expect(groupWith('cancelled').badge, 'Cancelled');
      expect(groupWith('fulfilled').isTerminal, isTrue);
      expect(groupWith('unfulfilled').isTerminal, isFalse);
    });
  });
}
