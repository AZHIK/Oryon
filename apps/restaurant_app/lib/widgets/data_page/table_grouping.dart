import 'package:flutter/foundation.dart';

import 'data_column_spec.dart';

/// One group of identical items: every row whose group-by column reads the
/// same value, e.g. all "Beverages" groceries or all "Paid" sales.
@immutable
class GroupSection<T> {
  const GroupSection({
    required this.key,
    required this.label,
    required this.rows,
  });

  /// The raw grouped value (for stable collapse state).
  final String key;

  /// What the header shows: the value, or "No value" when blank.
  final String label;
  final List<T> rows;

  int get count => rows.length;
}

/// Groups [rows] by what [column]'s `value()` reads for each row.
///
/// Order is preserved: groups appear in first-seen order and rows keep
/// their incoming (sorted) order inside each group — so grouping never
/// fights the table's sort, it only gathers identical values together.
List<GroupSection<T>> groupRows<T>(List<T> rows, DataColumnSpec<T> column) {
  final order = <String>[];
  final buckets = <String, List<T>>{};
  for (final row in rows) {
    final key = column.value(row).trim();
    if (!buckets.containsKey(key)) {
      order.add(key);
      buckets[key] = [];
    }
    buckets[key]!.add(row);
  }
  return [
    for (final key in order)
      GroupSection(
        key: key,
        label: key.isEmpty ? 'No value' : key,
        rows: buckets[key]!,
      ),
  ];
}
