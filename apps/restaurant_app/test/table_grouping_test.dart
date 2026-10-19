import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_pos/models/table_query.dart';
import 'package:restaurant_pos/theme/app_theme.dart';
import 'package:restaurant_pos/widgets/data_page/data_column_spec.dart';
import 'package:restaurant_pos/widgets/data_page/reusable_data_table.dart';
import 'package:restaurant_pos/widgets/data_page/table_grouping.dart';

const _status = DataColumnSpec<String>(
  label: 'Status',
  field: 'status',
  groupable: true,
  value: _statusOf,
);

String _statusOf(String row) => row.split(':').first;

void main() {
  group('groupRows', () {
    test('gathers identical values under one header each', () {
      final sections = groupRows(
        ['paid:a', 'refunded:b', 'paid:c'],
        _status,
      );

      expect(sections.map((s) => s.key), ['paid', 'refunded']);
      expect(sections.first.rows, ['paid:a', 'paid:c']);
      expect(sections.first.count, 2);
      expect(sections.last.label, 'refunded');
    });

    test('keeps incoming row order inside each group', () {
      final sections = groupRows(['b:y', 'a:x', 'b:z'], _status);

      expect(sections.map((s) => s.key), ['b', 'a']);
      expect(sections.first.rows, ['b:y', 'b:z']);
    });

    test('blank values read as "No value"', () {
      final sections = groupRows([':a'], _status);

      expect(sections.single.label, 'No value');
    });

    test('empty list makes no sections', () {
      expect(groupRows(const <String>[], _status), isEmpty);
    });
  });

  group('TableQuery.withGroup', () {    test('picking a group resets the page', () {
      const query = TableQuery(page: 3);

      final grouped = query.withGroup('status');

      expect(grouped.groupField, 'status');
      expect(grouped.page, 0);
    });

    test('clearing with null drops the group and resets the page', () {
      const query = TableQuery(groupField: 'status', page: 2);

      final flat = query.withGroup(null);

      expect(flat.groupField, isNull);
      expect(flat.page, 0);
    });
  });

  group('ReusableDataTable grouping', () {
    Future<void> pumpTable(
      WidgetTester tester, {
      required TableQuery query,
      ValueChanged<String?>? onGroupChanged,
    }) async {
      final slice = PageSlice.of(
        ['paid:a', 'refunded:b', 'paid:c'],
        const TableQuery(),
      );
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: ReusableDataTable<String>(
                columns: const [
                  DataColumnSpec(
                    label: 'Name',
                    field: 'name',
                    value: _nameOf,
                  ),
                  _status,
                ],
                slice: slice,
                query: query,
                onSort: (_) {},
                onPageChanged: (_) {},
                groupedItems: const ['paid:a', 'refunded:b', 'paid:c'],
                onGroupChanged: onGroupChanged,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('offers a Group by picker only when wired', (tester) async {
      await pumpTable(tester, query: const TableQuery(), onGroupChanged: (_) {});

      expect(find.text('Group by'), findsOneWidget);
    });

    testWidgets('hides the picker when no callback is wired', (tester) async {
      await pumpTable(tester, query: const TableQuery());

      expect(find.text('Group by'), findsNothing);
    });

    testWidgets('groups identical items under counted headers', (tester) async {
      await pumpTable(
        tester,
        query: const TableQuery(groupField: 'status'),
        onGroupChanged: (_) {},
      );

      // Header + one cell per paid row read "paid".
      expect(find.text('paid'), findsNWidgets(3));
      expect(find.text('refunded'), findsNWidgets(2));
      // Header counts: paid 2, refunded 1.
      expect(find.text('2'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2 groups · 3 items'), findsOneWidget);
    });

    testWidgets('tapping a header folds its rows shut', (tester) async {
      await pumpTable(
        tester,
        query: const TableQuery(groupField: 'status'),
        onGroupChanged: (_) {},
      );

      // First "paid" in tree order is the group header above its rows.
      await tester.tap(find.text('paid').first);
      await tester.pumpAndSettle();

      // Paid header + its folded-away rows: only the header text remains.
      expect(find.text('paid'), findsOneWidget);
      expect(find.text('refunded'), findsNWidgets(2));
    });
  });
}

String _nameOf(String row) => row;
