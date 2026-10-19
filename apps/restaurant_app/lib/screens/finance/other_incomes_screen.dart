import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/finance_categories.dart';
import '../../constants/app_strings.dart';
import '../../models/other_income.dart';
import '../../models/permission.dart';
import '../../providers/other_expenses_provider.dart' show FinanceOfflineMutationException;
import '../../providers/other_incomes_provider.dart';
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
import 'other_income_filter_panel.dart';
import '../../widgets/dialogs/other_income_form_dialog.dart';
import '../../utils/dialog_helper.dart';

class OtherIncomesScreen extends ConsumerWidget {
  const OtherIncomesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(otherIncomesQueryProvider);
    final slice = ref.watch(otherIncomesSliceProvider);
    final summary = ref.watch(otherIncomesSummaryProvider);
    final filters = ref.watch(otherIncomeFiltersProvider);
    final notifier = ref.read(otherIncomesQueryProvider.notifier);
    final canCreate = ref.watch(hasPermissionProvider(AppPermissions.financeIncomesCreate));
    final canUpdate = ref.watch(hasPermissionProvider(AppPermissions.financeIncomesUpdate));
    final canDelete = ref.watch(hasPermissionProvider(AppPermissions.financeIncomesDelete));

    return Column(
      children: [
        const FinanceTabBar(active: FinanceTab.incomes),
        Expanded(
          child: DataPageScaffold(
            title: AppStrings.otherIncomesTitle,
            subtitle: AppStrings.otherIncomesSubtitle,
            actions: dataPageExportActions<OtherIncome>(
              context: context,
              columns: otherIncomeColumns,
              rows: ref.watch(filteredOtherIncomesProvider),
              title: AppStrings.otherIncomesTitle,
              subtitle: _exportSubtitle(filters, query.search),
            ),
            // Hidden rather than shown-disabled — see other_expenses_screen.dart.
            // On phones the scaffold moves this to the FAB.
            primaryAction: !canCreate
                ? null
                : FilledButton.icon(
                    onPressed: () => showOtherIncomeFormDialog(context),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text(AppStrings.addIncome),
                  ),
            onRefresh: () =>
                ref.read(otherIncomesProvider.notifier).refresh(),
            fab: !canCreate
                ? null
                : DataPageFab(
                    icon: Icons.add_rounded,
                    label: AppStrings.addIncome,
                    onPressed: () => showOtherIncomeFormDialog(context),
                  ),
            metrics: [
              SummaryMetricCard(
                label: AppStrings.totalOtherIncome,
                value: Fmt.moneyCompact(summary.total),
                trend: AppStrings.inCurrentView,
                icon: Icons.arrow_downward_rounded,
              ),
              SummaryMetricCard(
                label: AppStrings.entriesMetric,
                value: '${summary.entryCount}',
                trend: AppStrings.trackedInView,
                icon: Icons.receipt_long_rounded,
                accent: context.colors.tertiary,
              ),
              SummaryMetricCard(
                label: AppStrings.averageEntry,
                value: Fmt.money(summary.average),
                trend: summary.entryCount == 0
                    ? AppStrings.noEntries
                    : AppStrings.entrySources(summary.entryCount),
                icon: Icons.trending_up_rounded,
                accent: context.semantic.success,
              ),
            ],
            toolbar: DataTableToolbar(
              searchHint: AppStrings.searchIncomes,
              searchValue: query.search,
              onSearchChanged: notifier.setSearch,
              activeFilterCount: filters.activeCount,
              onClearFilters: ref.read(otherIncomeFiltersProvider.notifier).clear,
              filterBuilder: (_) => const OtherIncomeFilterPanel(),
              sortOptions: [
                SortOption(label: AppStrings.dateSort, field: OtherIncomeSort.date),
                SortOption(
                  label: AppStrings.categorySort,
                  field: OtherIncomeSort.category,
                ),
                SortOption(
                  label: AppStrings.descriptionSort,
                  field: OtherIncomeSort.description,
                ),
                SortOption(
                  label: AppStrings.amountSort,
                  field: OtherIncomeSort.amount,
                ),
                SortOption(
                  label: AppStrings.paymentSort,
                  field: OtherIncomeSort.payment,
                ),
              ],
              sortField: query.sortField,
              sortAscending: query.ascending,
              onSortChanged: (field, ascending) => notifier.setSort(field, ascending: ascending),
            ),
            table: ReusableDataTable<OtherIncome>(
              columns: otherIncomeColumns,
              slice: slice,
              query: query,
              onSort: notifier.toggleSort,
              onPageChanged: notifier.setPage,
              groupedItems: ref.watch(filteredOtherIncomesProvider),
              onGroupChanged: notifier.setGroup,
              header: PendingSyncBanner(
                pendingCount:
                    ref.watch(outboxStatusProvider).valueOrNull?.pendingIncomes ??
                        0,
                itemWord: 'income',
              ),
              rowActions: [
                if (canUpdate)
                  DataRowAction(
                    label: AppStrings.editAction,
                    icon: Icons.edit_outlined,
                    onSelected: (c, i) => showOtherIncomeFormDialog(c, existingIncome: i),
                  ),
                if (canDelete)
                  DataRowAction(
                    label: AppStrings.deleteAction,
                    icon: Icons.delete_outline_rounded,
                    isDestructive: true,
                    onSelected: (c, i) => _confirmDelete(c, ref, i),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, OtherIncome income) async {
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.deleteIncomeTitle(income.description)),
        content: Text(AppStrings.deleteIncomeBody),
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
      await ref.read(otherIncomesProvider.notifier).delete(income.id);
      messenger.showSnackBar(
        SnackBar(
          content: Text(AppStrings.incomeDeleted(income.description)),
        ),
      );
    } on FinanceOfflineMutationException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  static String _exportSubtitle(OtherIncomeFilters filters, String search) {
    final parts = <String>[
      if (filters.categoryIds.isNotEmpty) filters.categoryIds.map((id) => FinanceCategories.incomeLabel(id)).join(', '),
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

final otherIncomeColumns = <DataColumnSpec<OtherIncome>>[
  DataColumnSpec(label: AppStrings.dateSort, field: OtherIncomeSort.date, flex: 2, value: (i) => Fmt.dayMonth(i.date)),
  DataColumnSpec(label: AppStrings.descriptionSort, field: OtherIncomeSort.description, role: ColumnRole.primary, flex: 5, value: (i) => i.description, cellBuilder: (c, i) => _DescriptionCell(income: i)),
  DataColumnSpec(label: AppStrings.categorySort, field: OtherIncomeSort.category, flex: 3, groupable: true, minTableWidth: 700, value: (i) => FinanceCategories.incomeLabel(i.categoryId)),
  DataColumnSpec(label: AppStrings.paymentSort, field: OtherIncomeSort.payment, flex: 2, groupable: true, minTableWidth: 860, value: (i) => i.paymentType.label),
  DataColumnSpec(label: AppStrings.amountSort, field: OtherIncomeSort.amount, flex: 2, numeric: true, value: (i) => Fmt.money(i.amount)),
];

class _DescriptionCell extends StatelessWidget {
  const _DescriptionCell({required this.income});
  final OtherIncome income;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(child: Text(income.description, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w700))),
            if (income.receipt != null) ...[const SizedBox(width: 8), Icon(Icons.attach_file_rounded, size: 14, color: context.colors.onSurfaceVariant)],
          ],
        ),
        Text(income.source.isNotEmpty ? income.source : AppStrings.emDash, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant)),
        // Sent ticks = safely on the server, amber tag = this device only.
        if (income.syncStatus != 'synced')
          const NotSentTag()
        else
          const SentTicks(),
      ],
    );
  }
}
