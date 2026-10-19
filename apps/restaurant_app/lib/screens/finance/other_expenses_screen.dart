import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/finance_categories.dart';
import '../../constants/app_strings.dart';
import '../../models/other_expense.dart';
import '../../models/permission.dart';
import '../../providers/other_expenses_provider.dart';
import '../../providers/outbox_status_provider.dart';
import '../../providers/permissions_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/connection_status_pill.dart';
import '../../widgets/data_page/data_column_spec.dart';
import '../../widgets/data_page/data_page_scaffold.dart';
import '../../widgets/data_page/data_table_toolbar.dart';
import '../../widgets/data_page/export_actions.dart';
import '../../widgets/data_page/reusable_data_table.dart';
import '../../widgets/data_page/summary_metric_card.dart';
import '../../widgets/finance/finance_tab_bar.dart';
import 'other_expense_filter_panel.dart';
import '../../widgets/dialogs/other_expense_form_dialog.dart';
import '../../utils/dialog_helper.dart';

class OtherExpensesScreen extends ConsumerWidget {
  const OtherExpensesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(otherExpensesQueryProvider);
    final slice = ref.watch(otherExpensesSliceProvider);
    final summary = ref.watch(otherExpensesSummaryProvider);
    final filters = ref.watch(otherExpenseFiltersProvider);
    final notifier = ref.read(otherExpensesQueryProvider.notifier);
    final canCreate = ref.watch(hasPermissionProvider(AppPermissions.financeExpensesCreate));
    final canUpdate = ref.watch(hasPermissionProvider(AppPermissions.financeExpensesUpdate));
    final canDelete = ref.watch(hasPermissionProvider(AppPermissions.financeExpensesDelete));

    return Column(
      children: [
        const FinanceTabBar(active: FinanceTab.expenses),
        Expanded(
          child: DataPageScaffold(
            title: AppStrings.otherExpensesTitle,
            subtitle: AppStrings.otherExpensesSubtitle,
            actions: dataPageExportActions<OtherExpense>(
              context: context,
              columns: otherExpenseColumns,
              rows: ref.watch(filteredOtherExpensesProvider),
              title: AppStrings.otherExpensesTitle,
              subtitle: _exportSubtitle(filters, query.search),
            ),
            // Hidden rather than shown-disabled: someone who can't add
            // expenses shouldn't see a control that only ever 403s. On
            // phones the scaffold moves this to the FAB.
            primaryAction: !canCreate
                ? null
                : FilledButton.icon(
                    onPressed: () => showOtherExpenseFormDialog(context),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text(AppStrings.addExpense),
                  ),
            onRefresh: () =>
                ref.read(otherExpensesProvider.notifier).refresh(),
            fab: !canCreate
                ? null
                : DataPageFab(
                    icon: Icons.add_rounded,
                    label: AppStrings.addExpense,
                    onPressed: () => showOtherExpenseFormDialog(context),
                  ),
            metrics: [
              SummaryMetricCard(
                label: AppStrings.totalExpenses,
                value: Fmt.moneyCompact(summary.total),
                trend: AppStrings.inCurrentView,
                icon: Icons.arrow_upward_rounded,
              ),
              SummaryMetricCard(
                label: AppStrings.entriesMetric,
                value: '${summary.entryCount}',
                trend: AppStrings.trackedInView,
                icon: Icons.receipt_long_rounded,
                accent: context.colors.tertiary,
              ),
              SummaryMetricCard(
                label: AppStrings.largestCategory,
                value: summary.largestCategoryLabel,
                trend: Fmt.moneyCompact(summary.largestCategoryAmount),
                icon: Icons.category_rounded,
                accent: context.semantic.warning,
              ),
            ],
            toolbar: DataTableToolbar(
              searchHint: AppStrings.searchExpenses,
              searchValue: query.search,
              onSearchChanged: notifier.setSearch,
              activeFilterCount: filters.activeCount,
              onClearFilters: ref.read(otherExpenseFiltersProvider.notifier).clear,
              filterBuilder: (_) => const OtherExpenseFilterPanel(),
              sortOptions: [
                SortOption(label: AppStrings.dateSort, field: OtherExpenseSort.date),
                SortOption(
                  label: AppStrings.categorySort,
                  field: OtherExpenseSort.category,
                ),
                SortOption(
                  label: AppStrings.descriptionSort,
                  field: OtherExpenseSort.description,
                ),
                SortOption(
                  label: AppStrings.amountSort,
                  field: OtherExpenseSort.amount,
                ),
                SortOption(
                  label: AppStrings.paymentSort,
                  field: OtherExpenseSort.payment,
                ),
              ],
              sortField: query.sortField,
              sortAscending: query.ascending,
              onSortChanged: (field, ascending) => notifier.setSort(field, ascending: ascending),
            ),
            table: ReusableDataTable<OtherExpense>(
              columns: otherExpenseColumns,
              slice: slice,
              query: query,
              onSort: notifier.toggleSort,
              onPageChanged: notifier.setPage,
              groupedItems: ref.watch(filteredOtherExpensesProvider),
              onGroupChanged: notifier.setGroup,
              header: PendingSyncBanner(
                pendingCount:
                    ref.watch(outboxStatusProvider).valueOrNull?.pendingExpenses ??
                        0,
                itemWord: 'expense',
              ),
              rowActions: [
                if (canUpdate)
                  DataRowAction(
                    label: AppStrings.editAction,
                    icon: Icons.edit_outlined,
                    onSelected: (c, e) => showOtherExpenseFormDialog(c, existingExpense: e),
                  ),
                if (canDelete)
                  DataRowAction(
                    label: AppStrings.deleteAction,
                    icon: Icons.delete_outline_rounded,
                    isDestructive: true,
                    onSelected: (c, e) => _confirmDelete(c, ref, e),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, OtherExpense expense) async {
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.deleteExpenseTitle(expense.description)),
        content: Text(AppStrings.deleteExpenseBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppStrings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppStrings.deleteAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(otherExpensesProvider.notifier).delete(expense.id);
      messenger.showSnackBar(
        SnackBar(
          content: Text(AppStrings.expenseDeleted(expense.description)),
        ),
      );
    } on FinanceOfflineMutationException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  static String _exportSubtitle(OtherExpenseFilters filters, String search) {
    final parts = <String>[
      if (filters.categoryIds.isNotEmpty) filters.categoryIds.map((id) => FinanceCategories.expenseLabel(id)).join(', '),
      if (filters.payments.isNotEmpty) filters.payments.map((p) => p.label).join(', '),
      if (filters.dateRange != null)
        AppStrings.financeExportBetween(
          '${filters.dateRange!.start.month}',
          '${filters.dateRange!.start.day}',
          '${filters.dateRange!.end.month}',
          '${filters.dateRange!.end.day}',
        ),
      if (search.trim().isNotEmpty) AppStrings.exportMatching(search),
    ];
    return parts.isEmpty ? AppStrings.allEntries : parts.join(' · ');
  }
}

final otherExpenseColumns = <DataColumnSpec<OtherExpense>>[
  DataColumnSpec(label: AppStrings.dateSort, field: OtherExpenseSort.date, flex: 2, value: (e) => Fmt.dayMonth(e.date)),
  DataColumnSpec(label: AppStrings.descriptionSort, field: OtherExpenseSort.description, role: ColumnRole.primary, flex: 5, value: (e) => e.description, cellBuilder: (c, e) => _DescriptionCell(expense: e)),
  DataColumnSpec(label: AppStrings.categorySort, field: OtherExpenseSort.category, flex: 3, groupable: true, minTableWidth: 700, value: (e) => FinanceCategories.expenseLabel(e.categoryId)),
  DataColumnSpec(label: AppStrings.paymentSort, field: OtherExpenseSort.payment, flex: 2, groupable: true, minTableWidth: 860, value: (e) => e.paymentType.label),
  DataColumnSpec(label: AppStrings.amountSort, field: OtherExpenseSort.amount, flex: 2, numeric: true, value: (e) => Fmt.money(e.amount)),
];

class _DescriptionCell extends StatelessWidget {
  const _DescriptionCell({required this.expense});
  final OtherExpense expense;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(child: Text(expense.description, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w700))),
            if (expense.receipt != null) ...[const SizedBox(width: 8), Icon(Icons.attach_file_rounded, size: 14, color: context.colors.onSurfaceVariant)],
          ],
        ),
        Text(expense.payee.isNotEmpty ? expense.payee : AppStrings.emDash, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant)),
        // Sent ticks = safely on the server, amber tag = this device only.
        if (expense.syncStatus != 'synced')
          const NotSentTag()
        else
          const SentTicks(),
      ],
    );
  }
}
