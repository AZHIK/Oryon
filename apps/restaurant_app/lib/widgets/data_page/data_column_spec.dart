import 'package:flutter/material.dart';

/// What a column means to the mobile card layout.
///
/// The table renders every column the same way; the card layout needs to know
/// which value leads, which is the status, and which are supporting detail.
enum ColumnRole {
  /// The headline field — becomes the card's title. Exactly one per table.
  primary,

  /// Rendered as a badge, pinned to the card's top-right corner.
  status,

  /// Supporting detail, listed under the title on a card.
  secondary,

  /// Shown in the table only; omitted from cards to keep them scannable.
  tableOnly,
}

/// One column of a [ReusableDataTable].
///
/// A page supplies a list of these and nothing else about presentation. The
/// same list drives the header, the cells, the mobile cards and the exports,
/// so those four can never drift out of sync.
@immutable
class DataColumnSpec<T> {
  const DataColumnSpec({
    required this.label,
    required this.field,
    required this.value,
    this.cellBuilder,
    this.sortable = true,
    this.groupable = false,
    this.role = ColumnRole.secondary,
    this.flex = 3,
    this.width,
    this.numeric = false,
    this.minTableWidth = 0,
  }) : assert(
         flex > 0 || width != null,
         'a column needs either a flex share or a fixed width',
       );

  /// Column heading, and the header used by PDF/Excel export.
  final String label;

  /// Stable key used for sorting. Matches [TableQuery.sortField].
  final String field;

  /// Plain-text value for this row. Used by the cell when there is no
  /// [cellBuilder], by search, and by both exporters — so an exported sheet
  /// always says what the screen said.
  final String Function(T row) value;

  /// Optional rich cell (thumbnail, badge, two-line stack).
  final Widget Function(BuildContext context, T row)? cellBuilder;

  final bool sortable;

  /// Whether "Group by" can gather this column's identical values together.
  /// Only low-cardinality text columns (status, category, supplier) earn
  /// this — grouping by a unique id or an amount makes one group per row.
  final bool groupable;
  final ColumnRole role;

  /// Share of the leftover width. Ignored when [width] is set.
  final int flex;

  /// Fixed width, for columns whose content has a known bound (badges).
  final double? width;

  /// Right-aligns the cell, the convention for money and counts.
  final bool numeric;

  /// Table width below which this column is dropped. Columns disappear in
  /// order of what a reader can most easily do without, rather than the table
  /// scrolling sideways.
  final double minTableWidth;

  Widget build(BuildContext context, T row) =>
      cellBuilder?.call(context, row) ?? const SizedBox.shrink();

  bool get hasCustomCell => cellBuilder != null;
}

/// An entry in a row's "…" overflow menu.
@immutable
class DataRowAction<T> {
  const DataRowAction({
    required this.label,
    required this.icon,
    required this.onSelected,
    this.isDestructive = false,
    this.isEnabled,
  });

  final String label;
  final IconData icon;
  final void Function(BuildContext context, T row) onSelected;

  /// Renders in the danger colour.
  final bool isDestructive;

  /// Greys the entry out for rows it cannot apply to — refunding an order
  /// that was already refunded, say.
  final bool Function(T row)? isEnabled;

  bool enabledFor(T row) => isEnabled?.call(row) ?? true;
}
