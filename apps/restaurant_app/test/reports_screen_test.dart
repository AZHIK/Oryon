import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:restaurant_pos/auth/permission_enforcement.dart';
import 'package:restaurant_pos/models/inventory_item.dart';
import 'package:restaurant_pos/models/permission.dart';
import 'package:restaurant_pos/providers/inventory_provider.dart';
import 'package:restaurant_pos/providers/permissions_provider.dart';
import 'package:restaurant_pos/providers/reports_provider.dart';
import 'package:restaurant_pos/screens/reports/report_detail_screen.dart';
import 'package:restaurant_pos/screens/reports/report_registry.dart';
import 'package:restaurant_pos/screens/reports/reports_screen.dart';
import 'package:restaurant_pos/services/pos_reports_api_service.dart';
import 'package:restaurant_pos/theme/app_theme.dart';

import 'test_helpers/test_container.dart';

ItemMixLineDto mixLine(String itemId, String qty, String revenue) =>
    ItemMixLineDto(
      itemId: itemId,
      quantity: Decimal.parse(qty),
      revenue: Decimal.parse(revenue),
      lines: 1,
    );

InventoryItem catalogItem(String id, String name) => InventoryItem(
      id: 'local-$id',
      sku: 'SKU-$id',
      name: name,
      categoryId: 'mains',
      emoji: '🍚',
      stock: 5,
      reorderLevel: 1,
      unitCost: 2,
      catalogItemId: id,
    );

class _MixWithLines extends ItemMixNotifier {
  @override
  Future<List<ItemMixLineDto>> build() async => [
        mixLine('backend-burger', '3', '30.00'),
        mixLine('backend-ghost', '1', '5.00'),
      ];
}

class _FinanceWithData extends FinanceSummaryNotifier {
  @override
  Future<FinanceSummaryDto?> build() async => FinanceSummaryDto(
        salesRevenue: Decimal.parse('1000'),
        incomeTotal: Decimal.parse('200'),
        expenseTotal: Decimal.parse('300'),
        net: Decimal.parse('900'),
        expensesByCategory: [
          FinanceCategoryTotalDto(category: 'rent', total: Decimal.parse('300')),
        ],
        incomesByCategory: const [],
      );
}

Future<void> pumpReportsMenu(WidgetTester tester) async {
  final container = newTestContainer();
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const ReportsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Pumps a report detail with every permission granted — no business
/// context needed since nothing here fetches.
Future<void> pumpDetail(
  WidgetTester tester,
  String reportId, {
  List<Override> extraOverrides = const [],
  Set<String> permissions = const {},
}) async {
  final container = newTestContainer(
    extraOverrides: [
      // Grant the screen-level `reports.view` gate.
      canPerformActionProvider.overrideWith((ref, arg) => Future.value(true)),
      hasPermissionProvider.overrideWith(
        (ref, code) => permissions.contains(code),
      ),
      ...extraOverrides,
    ],
  );

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: ReportDetailScreen(reportId: reportId),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('ReportsScreen menu', () {
    testWidgets('lists all nineteen reports', (tester) async {
      await pumpReportsMenu(tester);

      // The lazy list only builds visible rows, so drag through the
      // whole menu collecting every title that appears.
      final seen = <String>{};
      for (var i = 0; i < 15; i++) {
        for (final report in allReports) {
          if (find.text(report.title).evaluate().isNotEmpty) {
            seen.add(report.title);
          }
        }
        await tester.drag(find.byType(ListView), const Offset(0, -400));
        await tester.pumpAndSettle();
      }
      expect(seen, hasLength(allReports.length));
      expect(allReports, hasLength(19));
    });
  });

  group('ReportDetailScreen', () {
    testWidgets('product-sell resolves catalog names', (tester) async {
      await pumpDetail(
        tester,
        'product-sell',
        extraOverrides: [
          itemMixProvider.overrideWith(_MixWithLines.new),
          inventoryItemsListProvider.overrideWithValue([
            catalogItem('backend-burger', 'House Burger'),
          ]),
        ],
      );

      expect(find.text('Product Sell Report'), findsWidgets);
      // Catalog join resolves the known id; the unknown one stays honest.
      expect(find.text('House Burger'), findsOneWidget);
      expect(find.text('Unknown item'), findsOneWidget);
    });

    testWidgets('profit-loss renders a formal statement', (tester) async {
      await pumpDetail(
        tester,
        'profit-loss',
        extraOverrides: [
          financeSummaryProvider.overrideWith(_FinanceWithData.new),
        ],
      );

      expect(find.text('Statement of profit and loss'), findsOneWidget);
      expect(find.text('Total revenue  (A)'), findsOneWidget);
      expect(find.text('Gross profit  (A − B)'), findsOneWidget);
      expect(
        find.text('Total operating expenses  (C)'),
        findsOneWidget,
      );
      expect(find.text('NET PROFIT'), findsWidgets);
      // 1200 revenue − 0 purchases − 300 expenses = 900 net, 75% margin.
      expect(find.textContaining('Margin 75.0% of revenue'), findsOneWidget);
    });

    testWidgets('unknown id shows a fallback', (tester) async {
      await pumpDetail(tester, 'no-such-report');
      expect(find.text('Unknown report'), findsOneWidget);
    });

    testWidgets('export actions need the export permission', (tester) async {
      await pumpDetail(
        tester,
        'product-sell',
        extraOverrides: [
          itemMixProvider.overrideWith(_MixWithLines.new),
          inventoryItemsListProvider.overrideWithValue([
            catalogItem('backend-burger', 'House Burger'),
          ]),
        ],
      );
      expect(find.text('Export PDF'), findsNothing);

      await pumpDetail(
        tester,
        'product-sell',
        extraOverrides: [
          itemMixProvider.overrideWith(_MixWithLines.new),
          inventoryItemsListProvider.overrideWithValue([
            catalogItem('backend-burger', 'House Burger'),
          ]),
        ],
        permissions: {AppPermissions.reportsExport},
      );
      expect(find.text('Export PDF'), findsWidgets);
    });
  });
}
