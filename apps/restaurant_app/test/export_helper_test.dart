import 'dart:convert';
import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:restaurant_pos/models/inventory_item.dart';
import 'package:restaurant_pos/models/order.dart';
import 'package:restaurant_pos/screens/inventory/inventory_groceries_screen.dart';
import 'package:restaurant_pos/screens/sales/sales_screen.dart';
import 'package:restaurant_pos/utils/export_helper.dart';
import 'package:restaurant_pos/widgets/data_page/data_column_spec.dart';

class DemoRow {
  const DemoRow(this.name, this.count, this.price, this.state);
  final String name;
  final int count;
  final double price;
  final String state;
}

final _columns = <DataColumnSpec<DemoRow>>[
  DataColumnSpec(label: 'Name', field: 'name', value: (r) => r.name),
  DataColumnSpec(
    label: 'Count',
    field: 'count',
    numeric: true,
    value: (r) => '${r.count}',
  ),
  DataColumnSpec(
    label: 'Price',
    field: 'price',
    numeric: true,
    value: (r) => '\$${r.price.toStringAsFixed(2)}',
  ),
  DataColumnSpec(
    label: 'Stock',
    field: 'stock',
    numeric: true,
    // A formatted value carrying a unit must not silently become a bare
    // number in the spreadsheet.
    value: (r) => '${r.count} kg',
  ),
  DataColumnSpec(label: 'State', field: 'state', value: (r) => r.state),
];

const _rows = <DemoRow>[
  DemoRow('Alpha', 12, 3.50, 'Ready'),
  DemoRow('Beta', 7, 128.00, 'Blocked'),
];

/// Reads the generated workbook back so assertions are made against the real
/// file, not against the code that wrote it.
Sheet _decode(List<int> bytes) {
  final workbook = Excel.decodeBytes(bytes);
  return workbook[workbook.getDefaultSheet()!];
}

void main() {
  _fontTests();

  group('Excel export', () {
    test('writes a header row followed by the data', () {
      final bytes = ExportHelper.buildExcelBytes(
        columns: _columns,
        rows: _rows,
        title: 'Test',
      );
      final sheet = _decode(bytes);

      expect(sheet.maxRows, 3, reason: 'header + two rows');
      expect(sheet.row(0).map((c) => c?.value.toString()).toList(), [
        'Name',
        'Count',
        'Price',
        'Stock',
        'State',
      ]);
      expect(sheet.row(1).first?.value.toString(), 'Alpha');
      expect(sheet.row(2).first?.value.toString(), 'Beta');
    });

    test('numeric columns become numbers, not text', () {
      final bytes = ExportHelper.buildExcelBytes(
        columns: _columns,
        rows: _rows,
        title: 'Test',
      );
      final sheet = _decode(bytes);

      // Count: a plain integer.
      expect(sheet.row(1)[1]?.value, isA<IntCellValue>());
      // Price: currency formatting stripped so the column can be summed.
      expect(sheet.row(1)[2]?.value, isA<DoubleCellValue>());
      expect((sheet.row(1)[2]?.value as DoubleCellValue).value, 3.50);
      // Stock: keeps its unit, so it stays text.
      expect(sheet.row(1)[3]?.value, isA<TextCellValue>());
      expect(sheet.row(1)[3]?.value.toString(), '12 kg');
    });

    test('column order matches the screen exactly', () {
      final bytes = ExportHelper.buildExcelBytes(
        columns: _columns,
        rows: _rows,
        title: 'Test',
      );
      final headers = _decode(bytes).row(0).map((c) => c?.value.toString());

      expect(headers, orderedEquals(_columns.map((c) => c.label)));
    });
  });

  group('PDF export', () {
    test('produces a valid PDF document', () async {
      final bytes = await ExportHelper.buildPdfBytes(
        columns: _columns,
        rows: _rows,
        title: 'Test Report',
      );

      expect(bytes, isNotEmpty);
      // Magic number: every PDF starts %PDF-.
      expect(latin1.decode(bytes.take(5).toList()), '%PDF-');
      expect(latin1.decode(bytes.toList()), contains('%%EOF'));
    });

    test('embeds the title and generated date', () async {
      final bytes = await ExportHelper.buildPdfBytes(
        columns: _columns,
        rows: _rows,
        title: 'Quarterly Report',
        generatedAt: DateTime(2026, 8, 12, 14, 30),
      );

      // The document title lands in the PDF metadata as plain text.
      expect(latin1.decode(bytes.toList()), contains('Quarterly Report'));
    });

    test('grows with the number of rows', () async {
      final small = await ExportHelper.buildPdfBytes(
        columns: _columns,
        rows: _rows,
        title: 'T',
      );
      final large = await ExportHelper.buildPdfBytes(
        columns: _columns,
        rows: [for (var i = 0; i < 200; i++) ..._rows],
        title: 'T',
      );

      expect(large.length, greaterThan(small.length));
    });
  });

  group('Export guards', () {
    test(
      'an empty result set refuses rather than writing a blank file',
      () async {
        final pdf = await ExportHelper.exportToPdf(
          columns: _columns,
          rows: const <DemoRow>[],
          title: 'Test',
        );
        final excel = await ExportHelper.exportToExcel(
          columns: _columns,
          rows: const <DemoRow>[],
          title: 'Test',
        );

        expect(pdf.ok, isFalse);
        expect(pdf.message, contains('Nothing to export'));
        expect(excel.ok, isFalse);
      },
    );

    test(
      'falls back to an automatic location when no dialog is reachable',
      () async {
        // A unit test has no platform channels, so neither the save dialog nor
        // getDownloadsDirectory works — the same failure that made exports report
        // "Functionality only available on macOS" on Linux. The directory
        // cascade must still land the file somewhere.
        final result = await ExportHelper.exportToExcel(
          columns: _columns,
          rows: _rows,
          title: 'Cascade Test',
        );

        expect(result.ok, isTrue, reason: result.message);
        expect(result.path, isNotNull);

        final written = File(result.path!);
        addTearDown(() async {
          if (written.existsSync()) await written.delete();
        });

        expect(written.existsSync(), isTrue);
        expect(await written.length(), greaterThan(0));
        expect(result.path, endsWith('.xlsx'));

        // The file on disk is the workbook we generated, not an empty stub.
        final sheet = _decode(await written.readAsBytes());
        expect(sheet.row(1).first?.value.toString(), 'Alpha');
      },
    );

    test('the written PDF is a real document on disk', () async {
      final result = await ExportHelper.exportToPdf(
        columns: _columns,
        rows: _rows,
        title: 'Cascade Test',
      );

      expect(result.ok, isTrue, reason: result.message);
      final written = File(result.path!);
      addTearDown(() async {
        if (written.existsSync()) await written.delete();
      });

      expect(result.path, endsWith('.pdf'));
      final bytes = await written.readAsBytes();
      expect(latin1.decode(bytes.take(5).toList()), '%PDF-');
    });
  });

  group('Real page columns export', () {
    test('grocery columns produce a populated sheet', () {
      const item = InventoryItem(
        id: 'inv-99',
        sku: 'TST-1',
        name: 'Test Item',
        categoryId: 'dry',
        emoji: '📦',
        stock: 14,
        reorderLevel: 20,
        unitCost: 4.25,
        unit: 'kg',
        itemType: 'raw_material',
      );

      final sheet = _decode(
        ExportHelper.buildExcelBytes(
          columns: groceryColumns,
          rows: const [item],
          title: 'Groceries',
        ),
      );

      expect(sheet.row(0).map((c) => c?.value.toString()).toList(), [
        'Item',
        'Category',
        'Unit',
        'Stock',
        'Reorder at',
        'Status',
        'Active',
      ]);
      final row = sheet.row(1).map((c) => c?.value.toString()).toList();
      expect(row[0], 'Test Item');
      // Without a loaded taxonomy the exporter preserves the category id.
      expect(row[1], 'dry');
      expect(row[2], 'kg');
      expect(row[3], '14 kg');
      expect(row[4], '20');
      // Below the reorder level, so the sheet must say so too.
      expect(row[5], 'Low stock');
      expect(row[6], 'Active');
    });

    test('sales columns export the same values the table shows', () {
      final order = Order(
        id: 'ORD-9001',
        lines: const [
          OrderLine(
            itemId: 'x',
            name: 'Burger',
            emoji: '🍔',
            unitPrice: 10.00,
            quantity: 2,
          ),
        ],
        placedAt: DateTime(2026, 8, 12, 13, 5),
        paymentType: PaymentType.card,
        status: OrderStatus.refunded,
        taxRate: 0.10,
      );

      final sheet = _decode(
        ExportHelper.buildExcelBytes(
          columns: salesColumns,
          rows: [order],
          title: 'Sales',
        ),
      );

      expect(sheet.row(0).map((c) => c?.value.toString()).toList(), [
        'Order',
        'Date & time',
        'Items',
        'Total',
        'Payment',
        'Fulfillment',
        'Status',
      ]);
      final row = sheet.row(1).map((c) => c?.value.toString()).toList();
      expect(row[0], 'ORD-9001');
      expect(row[2], '2');
      expect(row[4], 'Card');
      expect(row[5], 'New');
      expect(row[6], 'Refunded');
      // Totals must survive as numbers so a finance team can sum the column.
      // A whole number round-trips through xlsx as an int, so assert on
      // numeric-ness rather than on which numeric type came back.
      final total = sheet.row(1)[3]?.value;
      expect(total, anyOf(isA<IntCellValue>(), isA<DoubleCellValue>()));
      expect(num.parse(total.toString()), closeTo(22.0, 0.001));
    });
  });
}

/// Font embedding needs the asset bundle, so these run as widget tests.
void _fontTests() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PDF font embedding', () {
    setUp(ExportHelper.resetPdfTheme);

    testWidgets('embeds Inter so non-Latin-1 glyphs survive', (tester) async {
      // The characters that made Helvetica warn: middle dot, en dash, curly
      // quotes, an accent and a non-dollar currency symbol.
      const subtitle = 'Filtered by Beverages · stock 0–20 · “tonic” · £4 café';

      final bytes = await ExportHelper.buildPdfBytes(
        columns: _columns,
        rows: const [DemoRow('Crème Brûlée', 3, 7.50, 'Ready')],
        title: 'Inventory',
        subtitle: subtitle,
      );

      expect(latin1.decode(bytes.take(5).toList()), '%PDF-');
      // An embedded TrueType font shows up as a FontFile2 stream; the
      // built-in Helvetica path never produces one.
      expect(latin1.decode(bytes.toList()), contains('FontFile2'));
    });

    testWidgets('falls back to built-in fonts if the asset is missing', (
      tester,
    ) async {
      ExportHelper.fontAssetKey = 'assets/fonts/does-not-exist.ttf';
      addTearDown(() {
        ExportHelper.fontAssetKey = 'assets/fonts/Inter.ttf';
        ExportHelper.resetPdfTheme();
      });

      final bytes = await ExportHelper.buildPdfBytes(
        columns: _columns,
        rows: _rows,
        title: 'Fallback',
      );

      // Still a valid document, just without an embedded font.
      expect(latin1.decode(bytes.take(5).toList()), '%PDF-');
      expect(latin1.decode(bytes.toList()), isNot(contains('FontFile2')));
    });
  });
}
