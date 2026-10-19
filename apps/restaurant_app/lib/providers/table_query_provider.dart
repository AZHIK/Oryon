import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_limits.dart';
import '../models/table_query.dart';

/// Owns the search/sort/pagination state for a single data page.
///
/// One class, one provider per page:
///
/// ```dart
/// final inventoryQueryProvider =
///     NotifierProvider<TableQueryNotifier, TableQuery>(
///       () => TableQueryNotifier(
///         const TableQuery(sortField: 'name', pageSize: 8),
///       ),
///     );
/// ```
///
/// Adding a third data page later means one more line like that — no new
/// notifier, no copied filtering code.
class TableQueryNotifier extends Notifier<TableQuery> {
  TableQueryNotifier([this.initial = const TableQuery()]);

  final TableQuery initial;

  @override
  TableQuery build() => initial;

  void setSearch(String value) => state = state.withSearch(value);

  void toggleSort(String field) => state = state.toggledSort(field);

  void setSort(String field, {required bool ascending}) =>
      state = state.copyWith(sortField: field, ascending: ascending, page: 0);

  /// Groups identical values together (or clears back to a flat list).
  void setGroup(String? field) => state = state.withGroup(field);

  void setPage(int page) => state = state.copyWith(page: page < 0 ? 0 : page);

  void nextPage() => setPage(state.page + 1);

  void previousPage() => setPage(state.page - 1);

  void setPageSize(int size) =>
      state = state.copyWith(pageSize: size <= 0 ? AppLimits.tablePageSize : size, page: 0);

  /// Called when a page's filters change, so the user is never left looking at
  /// a page index the new result set no longer has.
  void resetPage() => setPage(0);

  void clearSearch() => setSearch('');
}
