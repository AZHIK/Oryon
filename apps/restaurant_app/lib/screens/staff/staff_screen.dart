import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/business_role.dart';
import '../../constants/app_strings.dart';
import '../../models/permission.dart';
import '../../models/staff_member.dart';
import '../../providers/permissions_provider.dart';
import '../../providers/roles_provider.dart';
import '../../providers/staff_provider.dart';
import '../../router/app_router.dart';
import '../../theme/app_theme.dart';
import '../../theme/breakpoints.dart';
import '../../utils/formatters.dart';
import '../../widgets/data_page/data_column_spec.dart';
import '../../widgets/data_page/data_page_scaffold.dart';
import '../../widgets/data_page/data_table_toolbar.dart';
import '../../widgets/data_page/export_actions.dart';
import '../../widgets/data_page/reusable_data_table.dart';
import '../../widgets/data_page/status_badge.dart';
import '../../widgets/data_page/summary_metric_card.dart';
import '../../widgets/staff/role_badge.dart';
import 'invite_staff_dialog.dart';
import 'staff_filter_panel.dart';
import '../../utils/dialog_helper.dart';

/// The team list — the third page built entirely from the shared data-page
/// layer, and the proof that the shell generalises past Inventory and Sales.
///
/// Like those two, this file is column config, filters and actions. It writes
/// no layout of its own.
class StaffScreen extends ConsumerWidget {
  const StaffScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(staffQueryProvider);
    final slice = ref.watch(staffSliceProvider);
    final summary = ref.watch(staffSummaryProvider);
    final filters = ref.watch(staffFiltersProvider);
    final roles = ref.watch(rolesProvider).valueOrNull ?? const <BusinessRole>[];
    final notifier = ref.read(staffQueryProvider.notifier);
    final canInvite = ref.watch(hasPermissionProvider(AppPermissions.staffAssign));
    final canRevoke = ref.watch(hasPermissionProvider(AppPermissions.staffRevoke));

    // Resolved once and handed to the column config, so a table of twelve rows
    // does not walk the roles list twelve times per rebuild.
    final rolesById = {for (final role in roles) role.id: role};
    final columns = staffColumns(rolesById);

    return DataPageScaffold(
      title: AppStrings.staffTitle,
      subtitle: AppStrings.staffSubtitle(
        summary.total,
        roles.length,
        summary.active,
      ),
      actions: [
        ...dataPageExportActions<StaffMember>(
          context: context,
          columns: columns,
          rows: ref.watch(filteredStaffProvider),
          title: AppStrings.staffTitle,
          subtitle: _exportSubtitle(filters, query.search, rolesById),
        ),
        context.isMobile
            ? SizedBox(
                // Matches the header bar height so every action sits evenly.
                height: kDataPageActionHeight,
                width: kDataPageActionHeight,
                    child: Tooltip(
                      message: AppStrings.rolesAction,
                  child: Material(
                    color: context.colors.surfaceContainerLowest,
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: context.semantic.hairline),
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      iconSize: 22,
                      onPressed: () => context.pushNamed(AppRoute.rolesName),
                      icon: const Icon(Icons.shield_outlined),
                    ),
                  ),
                ),
              )
            : OutlinedButton.icon(
                onPressed: () => context.pushNamed(AppRoute.rolesName),
                icon: const Icon(Icons.shield_outlined, size: 18),
                label: Text(AppStrings.rolesAction),
              ),
      ],
      // Hidden rather than shown-disabled: an owner who can't invite anyone
      // shouldn't see a control that only ever 403s. On phones the scaffold
      // moves this to the FAB, so no mobile-only icon variant is needed here.
      primaryAction: !canInvite
          ? null
          : FilledButton.icon(
              onPressed: () => showInviteStaffDialog(context),
              icon: const Icon(Icons.person_add_alt_rounded, size: 18),
              label: Text(AppStrings.inviteStaff),
            ),
      onRefresh: () => ref.read(staffMembersProvider.notifier).refresh(),
      fab: !canInvite
          ? null
          : DataPageFab(
              icon: Icons.person_add_alt_rounded,
              label: AppStrings.inviteStaff,
              onPressed: () => showInviteStaffDialog(context),
            ),
      metrics: [
        SummaryMetricCard(
          label: AppStrings.totalStaff,
          value: '${summary.total}',
          trend: AppStrings.rolesInUse(roles.length),
          icon: Icons.groups_outlined,
        ),
        SummaryMetricCard(
          label: AppStrings.activeMetric,
          value: '${summary.active}',
          trend: summary.inactive == 0
              ? AppStrings.everyoneActive
              : AppStrings.deactivatedCount(summary.inactive),
          trendDirection: summary.inactive == 0
              ? TrendDirection.flat
              : TrendDirection.down,
          icon: Icons.check_circle_outline_rounded,
          accent: context.semantic.success,
        ),
        SummaryMetricCard(
          label: AppStrings.pendingInvites,
          value: '${summary.pending}',
          trend: summary.pending == 0
              ? AppStrings.nothingOutstanding
              : AppStrings.awaitingSignIn,
          icon: Icons.mark_email_unread_outlined,
          accent: context.semantic.warning,
        ),
      ],
      toolbar: DataTableToolbar(
        searchHint: AppStrings.searchStaff,
        searchValue: query.search,
        onSearchChanged: notifier.setSearch,
        activeFilterCount: filters.activeCount,
        onClearFilters: ref.read(staffFiltersProvider.notifier).clear,
        filterBuilder: (_) => const StaffFilterPanel(),
        sortOptions: [
          SortOption(label: AppStrings.nameSort, field: StaffSort.name),
          SortOption(label: AppStrings.roleSort, field: StaffSort.role),
          SortOption(label: AppStrings.statusSort, field: StaffSort.status),
          SortOption(
            label: AppStrings.lastActiveSort,
            field: StaffSort.lastActive,
          ),
        ],
        sortField: query.sortField,
        sortAscending: query.ascending,
        onSortChanged: (field, ascending) =>
            notifier.setSort(field, ascending: ascending),
      ),
      table: ReusableDataTable<StaffMember>(
        columns: columns,
        slice: slice,
        query: query,
        onSort: notifier.toggleSort,
        onPageChanged: notifier.setPage,
        groupedItems: ref.watch(filteredStaffProvider),
        onGroupChanged: notifier.setGroup,
        onRowTap: (member) => context.pushNamed(
          AppRoute.staffDetailName,
          pathParameters: {'staffId': member.id},
        ),
        rowActions: _actions(ref, canRevoke: canRevoke),
      ),
    );
  }

  List<DataRowAction<StaffMember>> _actions(
    WidgetRef ref, {
    required bool canRevoke,
  }) => [
    DataRowAction(
      label: AppStrings.viewDetail,
      icon: Icons.open_in_new_rounded,
      onSelected: (context, member) => context.pushNamed(
        AppRoute.staffDetailName,
        pathParameters: {'staffId': member.id},
      ),
    ),
    if (canRevoke)
      DataRowAction(
        label: AppStrings.removeFromTeam,
        icon: Icons.person_off_outlined,
        isDestructive: true,
        // No backend endpoint reactivates a removed member — they'd need a
        // fresh invite — so this only applies to someone currently holding
        // at least one role here.
        isEnabled: (member) => member.roles.isNotEmpty,
        onSelected: (context, member) => _removeFromTeam(context, ref, member),
      ),
  ];

  Future<void> _removeFromTeam(
    BuildContext context,
    WidgetRef ref,
    StaffMember member,
  ) async {
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppStrings.removeMemberTitle(member.name)),
        content: Text(
          AppStrings.revokeRolesBody(member.roles.length),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(AppStrings.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: dialogContext.semantic.danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(AppStrings.removeAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final notifier = ref.read(staffMembersProvider.notifier);
    var failures = 0;
    for (final role in member.roles) {
      try {
        await notifier.revokeRole(userId: member.id, roleId: role.roleId);
      } catch (_) {
        failures++;
      }
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          failures == 0
              ? AppStrings.memberRemoved(member.name)
              : AppStrings.removeRolesFailed(member.name),
        ),
      ),
    );
  }

  /// Records on the exported file which view produced it.
  static String _exportSubtitle(
    StaffFilters filters,
    String search,
    Map<String, BusinessRole> rolesById,
  ) {
    final parts = <String>[
      if (filters.roleIds.isNotEmpty)
        filters.roleIds.map((id) => rolesById[id]?.displayName ?? id).join(', '),
      if (filters.statuses.isNotEmpty)
        filters.statuses.map((s) => s.label).join(', '),
      if (search.trim().isNotEmpty)
        AppStrings.exportMatching(search.trim()),
    ];

    return parts.isEmpty
        ? AppStrings.allStaffExport
        : AppStrings.exportFiltered(parts.join(' · '));
  }
}

/// Column config for the staff table.
///
/// A function rather than a top-level list because the role badge needs the
/// roles map — the exporters call it with the same map, so a spreadsheet
/// carries the same columns the screen shows.
List<DataColumnSpec<StaffMember>> staffColumns(
  Map<String, BusinessRole> rolesById,
) => [
  DataColumnSpec(
    label: AppStrings.nameCol,
    field: StaffSort.name,
    role: ColumnRole.primary,
    flex: 5,
    value: (member) => member.name,
    cellBuilder: (context, member) =>
        _NameCell(member: member, role: rolesById[member.roleId]),
  ),
  DataColumnSpec(
    label: AppStrings.roleCol,
    field: StaffSort.role,
    flex: 3,
    groupable: true,
    // A staff member can hold more than one role — join every name for
    // sorting/search/export, and render every badge in the cell.
    value: (member) => member.roles.map((r) => r.label).join(', '),
    cellBuilder: (context, member) => Align(
      alignment: Alignment.centerLeft,
      child: member.roles.isEmpty
          ? const RoleBadge(role: null, dense: true)
          : Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final assignment in member.roles)
                  RoleBadge(
                    role: rolesById[assignment.roleId],
                    scopeLabel: assignment.storeName,
                    dense: true,
                  ),
              ],
            ),
    ),
  ),
  DataColumnSpec(
    label: AppStrings.emailCol,
    field: StaffSort.email,
    flex: 4,
    minTableWidth: 940,
    value: (member) => member.email,
  ),
  DataColumnSpec(
    label: AppStrings.lastActiveCol,
    field: StaffSort.lastActive,
    flex: 3,
    minTableWidth: 720,
    value: (member) => member.lastActiveAt == null
        ? AppStrings.neverActive
        : Fmt.relativeDateTime(member.lastActiveAt!),
  ),
  DataColumnSpec(
    label: AppStrings.statusCol,
    field: StaffSort.status,
    role: ColumnRole.status,
    width: 150,
    groupable: true,
    value: (member) => member.status.label,
    cellBuilder: (context, member) => StatusBadge(
      label: member.status.label,
      tone: member.status.tone,
      icon: member.status.badgeIcon,
      dense: true,
    ),
  ),
];

class _NameCell extends StatelessWidget {
  const _NameCell({required this.member, required this.role});

  final StaffMember member;
  final BusinessRole? role;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        StaffAvatar(initials: member.initials, role: role),
        const SizedBox(width: Insets.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                member.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                member.email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
