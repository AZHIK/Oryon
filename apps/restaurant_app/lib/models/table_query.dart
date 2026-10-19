import 'package:flutter/foundation.dart';

import '../constants/app_limits.dart';

/// Search + sort + pagination state for one data page.
///
/// Deliberately free of any UI or domain types: a page's provider owns one of
/// these, derives its rows from it, and the table widget only reads it. That
/// is what lets Inventory, Sales and any future page share the same machinery.
@immutable
class TableQuery {
  const TableQuery({
    this.search = '',
    this.sortField,
    this.ascending = true,
    this.groupField,
    this.page = 0,
    this.pageSize = AppLimits.tablePageSize,
  });

  final String search;

  /// Matches [DataColumnSpec.field] on the column being sorted by.
  final String? sortField;
  final bool ascending;

  /// Matches [DataColumnSpec.field] on the group-by column, or null for a
  /// flat list. Grouping shows every matching row under its value header,
  /// so it resets pagination like search and sort do.
  final String? groupField;

  /// Zero-based.
  final int page;
  final int pageSize;

  TableQuery copyWith({
    String? search,
    String? sortField,
    bool? ascending,
    String? groupField,
    bool clearGroup = false,
    int? page,
    int? pageSize,
  }) {
    return TableQuery(
      search: search ?? this.search,
      sortField: sortField ?? this.sortField,
      ascending: ascending ?? this.ascending,
      groupField: clearGroup ? null : (groupField ?? this.groupField),
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
    );
  }

  /// Anything that changes which rows match must send the user back to page
  /// one — otherwise a filter can strand them on a page that no longer exists.
  TableQuery withSearch(String value) => copyWith(search: value, page: 0);

  /// Tapping the active column flips direction; a new column starts ascending.
  TableQuery toggledSort(String field) => sortField == field
      ? copyWith(ascending: !ascending, page: 0)
      : copyWith(sortField: field, ascending: true, page: 0);

  /// Picking a group (or clearing it with null) shows the whole list from
  /// the top — grouped view pages nothing away.
  TableQuery withGroup(String? field) => field == null
      ? copyWith(clearGroup: true, page: 0)
      : copyWith(groupField: field, page: 0);

  @override
  bool operator ==(Object other) =>
      other is TableQuery &&
      other.search == search &&
      other.sortField == sortField &&
      other.ascending == ascending &&
      other.groupField == groupField &&
      other.page == page &&
      other.pageSize == pageSize;

  @override
  int get hashCode =>
      Object.hash(search, sortField, ascending, groupField, page, pageSize);
}

/// One page of results plus the counts the pagination footer needs.
@immutable
class PageSlice<T> {
  const PageSlice({
    required this.items,
    required this.totalCount,
    required this.page,
    required this.pageSize,
  });

  final List<T> items;

  /// Rows matching the search and filters, before pagination.
  final int totalCount;
  final int page;
  final int pageSize;

  int get pageCount => totalCount == 0 ? 1 : (totalCount / pageSize).ceil();

  bool get hasPrevious => page > 0;
  bool get hasNext => page < pageCount - 1;

  /// One-based, inclusive, for "Showing 11–20 of 34".
  int get firstRow => totalCount == 0 ? 0 : page * pageSize + 1;
  int get lastRow => (page * pageSize + items.length).clamp(0, totalCount);

  /// Slices [all] for [query], clamping the page so a shrinking result set
  /// can never leave the caller on an empty page.
  static PageSlice<T> of<T>(List<T> all, TableQuery query) {
    final pageSize = query.pageSize <= 0 ? AppLimits.tablePageSize : query.pageSize;
    final pageCount = all.isEmpty ? 1 : (all.length / pageSize).ceil();
    final page = query.page.clamp(0, pageCount - 1);
    final start = page * pageSize;

    return PageSlice(
      items: all.skip(start).take(pageSize).toList(),
      totalCount: all.length,
      page: page,
      pageSize: pageSize,
    );
  }
}
