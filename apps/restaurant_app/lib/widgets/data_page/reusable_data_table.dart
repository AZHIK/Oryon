import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/table_query.dart';
import '../../constants/app_strings.dart';
import '../../providers/preferences_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/breakpoints.dart';
import 'data_column_spec.dart';
import 'data_row_card.dart';
import 'table_grouping.dart';

/// A sortable, paginated table that collapses to cards on narrow widths.
/// Now also groups identical items: pass [groupedItems] (the page's full
/// filtered + sorted list) and [onGroupChanged], mark low-cardinality
/// columns `groupable`, and the table offers a "Group by" picker that
/// gathers matching rows under one header each.
///
/// Generic over the row type and given its columns as config, so it holds no
/// knowledge of any particular page. It is also *stateless* with respect to
/// the data: sorting, filtering and paging all happen in the page's provider,
/// and this widget renders the slice it is handed and reports intent back
/// through [onSort] and [onPageChanged]. The only state it owns is which
/// group headers are collapsed — pure presentation, reset whenever the
/// grouping or the rows change.
///
/// The one thing it reads for itself is [tableDensityProvider] — row height is
/// a preference the user sets once in App Preferences and expects to see on
/// every table in the app, so making each page pass it down would only be a
/// way for one page to forget.
class ReusableDataTable<T> extends ConsumerStatefulWidget {
  const ReusableDataTable({
    super.key,
    required this.columns,
    required this.slice,
    required this.query,
    required this.onSort,
    required this.onPageChanged,
    this.onRowTap,
    this.rowActions = const [],
    this.emptyState,
    this.forceCards = false,
    this.groupedItems,
    this.onGroupChanged,
    this.header,
  });

  final List<DataColumnSpec<T>> columns;
  final PageSlice<T> slice;
  final TableQuery query;

  /// Called with the tapped column's [DataColumnSpec.field].
  final ValueChanged<String> onSort;
  final ValueChanged<int> onPageChanged;

  /// Full filtered + sorted rows, before pagination. Grouping gathers these
  /// (not just the visible page), so no group is ever split across pages —
  /// the grouped view shows everything and hides the pager.
  final List<T>? groupedItems;

  /// Called with the picked column's [DataColumnSpec.field], or null to
  /// ungroup. Null (default) means this table offers no grouping.
  final ValueChanged<String?>? onGroupChanged;

  final void Function(T row)? onRowTap;
  final List<DataRowAction<T>> rowActions;
  final Widget? emptyState;

  /// Optional strip above everything (e.g. a pending-sync banner).
  /// Rendered even when the table is empty, so a waiting count is never
  /// hidden behind an empty state.
  final Widget? header;

  /// Forces the card layout regardless of width, for embedding the table in a
  /// narrow container on a wide screen.
  final bool forceCards;

  static const double _actionsWidth = 44;

  @override
  ConsumerState<ReusableDataTable<T>> createState() =>
      _ReusableDataTableState<T>();
}

class _ReusableDataTableState<T> extends ConsumerState<ReusableDataTable<T>> {
  /// Group keys currently folded shut. Cleared whenever the grouping or the
  /// underlying rows change, so a stale key can never hide fresh rows.
  final Set<String> _collapsed = {};
  String? _groupFieldSeen;
  int _itemsHashSeen = 0;

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    // Keyed to the window, not to this box. Page padding differs either side
    // of the breakpoint, so available width is not monotonic across it — a
    // 640px window can hand the table less room than a 599px one, which would
    // flip the layout backwards.
    final asCards = widget.forceCards || context.isMobile;
    final density = ref.watch(tableDensityProvider);

    final groupColumn = _groupColumn();
    final allItems = widget.groupedItems;
    final grouped = groupColumn != null && allItems != null;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Nothing to page through, so the footer would only be noise.
        // The header (e.g. pending-sync banner) still renders on empty,
        // so a waiting count is never hidden behind an empty state.
        if (widget.slice.items.isEmpty && !grouped) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.header != null) widget.header!,
              widget.emptyState ?? const _DefaultEmptyState(),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.header != null) widget.header!,
            if (_groupChoices().isNotEmpty && widget.onGroupChanged != null)
              _GroupBar<T>(
                choices: _groupChoices(),
                active: widget.query.groupField,
                onChanged: widget.onGroupChanged!,
              ),
            if (grouped)
              _GroupedBody<T>(
                sections: groupRows(allItems, groupColumn),
                columns: asCards
                    ? widget.columns
                    : _visibleColumns(constraints.maxWidth),
                collapsed: _collapsedFor(groupColumn.field, allItems),
                onToggle: _toggle,
                asCards: asCards,
                query: widget.query,
                onSort: widget.onSort,
                onRowTap: widget.onRowTap,
                rowActions: widget.rowActions,
                density: density,
                emptyState: widget.emptyState,
              )
            else ...[
              if (asCards)
                _Cards<T>(
                  columns: widget.columns,
                  rows: widget.slice.items,
                  onRowTap: widget.onRowTap,
                  rowActions: widget.rowActions,
                  density: density,
                )
              else
                _Table<T>(
                  columns: _visibleColumns(constraints.maxWidth),
                  rows: widget.slice.items,
                  query: widget.query,
                  onSort: widget.onSort,
                  onRowTap: widget.onRowTap,
                  rowActions: widget.rowActions,
                  density: density,
                ),
              _Pagination(
                  slice: widget.slice,
                  onPageChanged: widget.onPageChanged),
            ],
          ],
        );
      },
    );
  }

  List<DataColumnSpec<T>> _groupChoices() =>
      [for (final c in widget.columns) if (c.groupable) c];

  DataColumnSpec<T>? _groupColumn() {
    final field = widget.query.groupField;
    if (field == null || widget.onGroupChanged == null) return null;
    for (final c in widget.columns) {
      if (c.field == field && c.groupable) return c;
    }
    return null;
  }

  Set<String> _collapsedFor(String field, List<T> items) {
    final hash = Object.hashAll(items);
    if (_groupFieldSeen != field || _itemsHashSeen != hash) {
      _groupFieldSeen = field;
      _itemsHashSeen = hash;
      _collapsed.clear();
    }
    return _collapsed;
  }

  void _toggle(String key) {
    setState(() {
      if (!_collapsed.remove(key)) _collapsed.add(key);
    });
  }

  List<DataColumnSpec<T>> _visibleColumns(double width) => [
    for (final column in widget.columns)
      if (width >= column.minTableWidth) column,
  ];
}

// ---------------------------------------------------------------------------
// Table form
// ---------------------------------------------------------------------------

class _Table<T> extends StatelessWidget {
  const _Table({
    required this.columns,
    required this.rows,
    required this.query,
    required this.onSort,
    required this.onRowTap,
    required this.rowActions,
    required this.density,
  });

  final List<DataColumnSpec<T>> columns;
  final List<T> rows;
  final TableQuery query;
  final ValueChanged<String> onSort;
  final void Function(T row)? onRowTap;
  final List<DataRowAction<T>> rowActions;
  final TableDensity density;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: Radii.card,
        border: Border.all(color: context.semantic.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _HeaderRow<T>(
            columns: columns,
            query: query,
            onSort: onSort,
            showActions: rowActions.isNotEmpty,
            density: density,
          ),
          for (var i = 0; i < rows.length; i++) ...[
            const Divider(height: 1),
            _BodyRow<T>(
              row: rows[i],
              columns: columns,
              onTap: onRowTap,
              rowActions: rowActions,
              density: density,
            ),
          ],
        ],
      ),
    );
  }
}

class _HeaderRow<T> extends StatelessWidget {
  const _HeaderRow({
    required this.columns,
    required this.query,
    required this.onSort,
    required this.showActions,
    required this.density,
  });

  final List<DataColumnSpec<T>> columns;
  final TableQuery query;
  final ValueChanged<String> onSort;
  final bool showActions;
  final TableDensity density;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.colors.surfaceContainerHigh,
      padding: EdgeInsets.symmetric(
        horizontal: Insets.lg,
        vertical: density.headerPadding,
      ),
      child: Row(
        children: [
          for (final column in columns)
            _cell(
              column,
              child: _HeaderCell<T>(
                column: column,
                active: query.sortField == column.field,
                ascending: query.ascending,
                onTap: column.sortable ? () => onSort(column.field) : null,
              ),
            ),
          if (showActions)
            const SizedBox(width: ReusableDataTable._actionsWidth),
        ],
      ),
    );
  }

  Widget _cell(DataColumnSpec<T> column, {required Widget child}) =>
      column.width != null
      ? Padding(
          padding: const EdgeInsets.only(right: Insets.sm),
          child: SizedBox(width: column.width, child: child),
        )
      : Expanded(flex: column.flex, child: child);
}

class _HeaderCell<T> extends StatelessWidget {
  const _HeaderCell({
    required this.column,
    required this.active,
    required this.ascending,
    required this.onTap,
  });

  final DataColumnSpec<T> column;
  final bool active;
  final bool ascending;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Insets.xs),
        child: Row(
          mainAxisAlignment: column.numeric
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: [
            Flexible(
              child: Text(
                column.label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: column.numeric ? TextAlign.right : TextAlign.left,
                style: context.text.eyebrow.copyWith(
                  color: active ? colors.onSurface : colors.onSurfaceVariant,
                ),
              ),
            ),
            // The arrow's width is reserved on every sortable column, so
            // headings do not shuffle sideways when the sort column changes.
            if (column.sortable)
              SizedBox(
                width: 16,
                child: active
                    ? Icon(
                        ascending
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        size: 13,
                        color: colors.primary,
                      )
                    : null,
              ),
          ],
        ),
      ),
    );
  }
}

class _BodyRow<T> extends StatelessWidget {
  const _BodyRow({
    required this.row,
    required this.columns,
    required this.onTap,
    required this.rowActions,
    required this.density,
  });

  final T row;
  final List<DataColumnSpec<T>> columns;
  final void Function(T row)? onTap;
  final List<DataRowAction<T>> rowActions;
  final TableDensity density;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap == null ? null : () => onTap!(row),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: Insets.lg,
          vertical: density.rowPadding,
        ),
        child: Row(
          children: [
            for (final column in columns)
              _cell(
                column,
                child: Align(
                  alignment: column.numeric
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: column.hasCustomCell
                      ? column.build(context, row)
                      : Text(
                          column.value(row),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: column.numeric
                              ? TextAlign.right
                              : TextAlign.left,
                          style: context.text.bodyMedium,
                        ),
                ),
              ),
            if (rowActions.isNotEmpty)
              SizedBox(
                width: ReusableDataTable._actionsWidth,
                child: RowActionsMenu<T>(row: row, actions: rowActions),
              ),
          ],
        ),
      ),
    );
  }

  Widget _cell(DataColumnSpec<T> column, {required Widget child}) =>
      column.width != null
      ? Padding(
          padding: const EdgeInsets.only(right: Insets.sm),
          child: SizedBox(width: column.width, child: child),
        )
      : Expanded(
          flex: column.flex,
          child: Padding(
            padding: const EdgeInsets.only(right: Insets.sm),
            child: child,
          ),
        );
}

// ---------------------------------------------------------------------------
// Card form
// ---------------------------------------------------------------------------

class _Cards<T> extends StatelessWidget {
  const _Cards({
    required this.columns,
    required this.rows,
    required this.onRowTap,
    required this.rowActions,
    required this.density,
  });

  final List<DataColumnSpec<T>> columns;
  final List<T> rows;
  final void Function(T row)? onRowTap;
  final List<DataRowAction<T>> rowActions;
  final TableDensity density;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) SizedBox(height: density.cardGap),
          DataRowCard<T>(
            row: rows[i],
            columns: columns,
            actions: rowActions,
            onTap: onRowTap == null ? null : () => onRowTap!(rows[i]),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Pagination
// ---------------------------------------------------------------------------

class _Pagination extends StatelessWidget {
  const _Pagination({required this.slice, required this.onPageChanged});

  final PageSlice slice;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final showing = slice.totalCount == 0
        ? AppStrings.noResults
        : AppStrings.showingRange(
            slice.firstRow,
            slice.lastRow,
            slice.totalCount,
          );

    return Padding(
      padding: const EdgeInsets.only(top: Insets.md),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final label = Text(
            showing,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          );

          final controls = _PageControls(
            slice: slice,
            onPageChanged: onPageChanged,
            // Numbered buttons need room; below this only the arrows fit.
            compact: constraints.maxWidth < 420,
          );

          if (constraints.maxWidth < 340) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [label, const SizedBox(height: Insets.sm), controls],
            );
          }

          return Row(
            children: [
              Expanded(child: label),
              const SizedBox(width: Insets.md),
              controls,
            ],
          );
        },
      ),
    );
  }
}

class _PageControls extends StatelessWidget {
  const _PageControls({
    required this.slice,
    required this.onPageChanged,
    required this.compact,
  });

  final PageSlice slice;
  final ValueChanged<int> onPageChanged;
  final bool compact;

  /// A window of page numbers around the current page, so a 40-page table
  /// does not render 40 buttons.
  List<int> get _window {
    const span = 5;
    if (slice.pageCount <= span) {
      return [for (var i = 0; i < slice.pageCount; i++) i];
    }
    var start = slice.page - 2;
    if (start < 0) start = 0;
    if (start + span > slice.pageCount) start = slice.pageCount - span;
    return [for (var i = start; i < start + span; i++) i];
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: AppStrings.previousPage,
          visualDensity: VisualDensity.compact,
          onPressed: slice.hasPrevious
              ? () => onPageChanged(slice.page - 1)
              : null,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        if (compact)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
            child: Text(
              AppStrings.pagerPosition(slice.page + 1, slice.pageCount),
              style: context.text.labelLarge,
            ),
          )
        else
          for (final page in _window)
            _PageButton(
              page: page,
              selected: page == slice.page,
              onTap: () => onPageChanged(page),
            ),
        IconButton(
          tooltip: AppStrings.nextPage,
          visualDensity: VisualDensity.compact,
          onPressed: slice.hasNext ? () => onPageChanged(slice.page + 1) : null,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}

class _PageButton extends StatelessWidget {
  const _PageButton({
    required this.page,
    required this.selected,
    required this.onTap,
  });

  final int page;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: selected ? colors.primary : Colors.transparent,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.sm),
          side: BorderSide(
            color: selected ? colors.primary : context.semantic.hairline,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 32,
            width: 32,
            child: Center(
              child: Text(
                '${page + 1}',
                style: context.text.labelLarge?.copyWith(
                  color: selected ? colors.onPrimary : colors.onSurface,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Grouping: gather identical items under one header each
// ---------------------------------------------------------------------------

/// The "Group by" picker above the table. Only rendered when the page marks
/// at least one column groupable and wires [onChanged] — every other table
/// is untouched.
class _GroupBar<T> extends StatelessWidget {
  const _GroupBar({
    required this.choices,
    required this.active,
    required this.onChanged,
  });

  final List<DataColumnSpec<T>> choices;
  final String? active;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final current = choices.where((c) => c.field == active).firstOrNull;

    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.sm),
      child: Row(
        children: [
          Icon(
            Icons.group_work_outlined,
            size: 18,
            color: colors.onSurfaceVariant,
          ),
          const SizedBox(width: Insets.xs),
          Text(
            'Group by',
            style: context.text.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: Insets.sm),
          PopupMenuButton<String?>(
            tooltip: 'Group identical items together',
            position: PopupMenuPosition.under,
            onSelected: onChanged,
            itemBuilder: (context) => [
              const PopupMenuItem<String?>(
                value: null,
                child: Text('No grouping'),
              ),
              const PopupMenuDivider(),
              for (final choice in choices)
                CheckedPopupMenuItem<String?>(
                  value: choice.field,
                  checked: choice.field == active,
                  child: Text(choice.label),
                ),
            ],
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: Insets.md),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Radii.md),
                border: Border.all(
                  color: current != null
                      ? colors.primary
                      : colors.outlineVariant,
                ),
                color: current != null
                    ? colors.primaryContainer.withValues(alpha: 0.4)
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      current?.label ?? 'No grouping',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.labelLarge?.copyWith(
                        color: current != null ? colors.primary : null,
                        fontWeight: current != null ? FontWeight.w700 : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_drop_down_rounded, size: 20),
                ],
              ),
            ),
          ),
          if (current != null) ...[
            const SizedBox(width: Insets.xs),
            IconButton(
              tooltip: 'Clear grouping',
              visualDensity: VisualDensity.compact,
              onPressed: () => onChanged(null),
              icon: const Icon(Icons.close_rounded, size: 18),
            ),
          ],
        ],
      ),
    );
  }
}

/// Every group in full: tappable header (name + count) over that group's
/// rows. Tap folds a group shut; switching group or rows reopens all.
class _GroupedBody<T> extends StatelessWidget {
  const _GroupedBody({
    required this.sections,
    required this.columns,
    required this.collapsed,
    required this.onToggle,
    required this.asCards,
    required this.query,
    required this.onSort,
    required this.onRowTap,
    required this.rowActions,
    required this.density,
    required this.emptyState,
  });

  final List<GroupSection<T>> sections;
  final List<DataColumnSpec<T>> columns;
  final Set<String> collapsed;
  final ValueChanged<String> onToggle;
  final bool asCards;
  final TableQuery query;
  final ValueChanged<String> onSort;
  final void Function(T row)? onRowTap;
  final List<DataRowAction<T>> rowActions;
  final TableDensity density;
  final Widget? emptyState;

  @override
  Widget build(BuildContext context) {
    if (sections.isEmpty) return emptyState ?? const _DefaultEmptyState();

    final total = sections.fold(0, (sum, s) => sum + s.count);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: Insets.sm),
          child: Text(
            '${sections.length} groups · $total items',
            style: context.text.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ),
        for (final section in sections) ...[
          _GroupHeader(
            label: section.label,
            count: section.count,
            folded: collapsed.contains(section.key),
            onTap: () => onToggle(section.key),
          ),
          if (!collapsed.contains(section.key)) ...[
            const SizedBox(height: Insets.xs),
            if (asCards)
              _Cards<T>(
                columns: columns,
                rows: section.rows,
                onRowTap: onRowTap,
                rowActions: rowActions,
                density: density,
              )
            else
              _Table<T>(
                columns: columns,
                rows: section.rows,
                query: query,
                onSort: onSort,
                onRowTap: onRowTap,
                rowActions: rowActions,
                density: density,
              ),
          ],
          const SizedBox(height: Insets.md),
        ],
      ],
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.label,
    required this.count,
    required this.folded,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool folded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Material(
      color: colors.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(Radii.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Insets.md,
            vertical: Insets.sm,
          ),
          child: Row(
            children: [
              Icon(
                folded
                    ? Icons.chevron_right_rounded
                    : Icons.expand_more_rounded,
                size: 20,
                color: colors.primary,
              ),
              const SizedBox(width: Insets.xs),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Insets.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(Radii.pill),
                ),
                child: Text(
                  '$count',
                  style: context.text.labelSmall?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DefaultEmptyState extends StatelessWidget {
  const _DefaultEmptyState();
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: Insets.xxl),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: Radii.card,
        border: Border.all(color: context.semantic.hairline),
      ),
      child: Column(
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 32,
            color: colors.onSurfaceVariant.withValues(alpha: 0.6),
          ),
          const SizedBox(height: Insets.md),
          Text(AppStrings.noResults, style: context.text.titleSmall),
          const SizedBox(height: Insets.xs),
          Text(
            AppStrings.tryDifferentSearch,
            textAlign: TextAlign.center,
            style: context.text.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
