import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/identity_service_api.dart' show AuthException;
import '../../models/business_role.dart';
import '../../constants/app_strings.dart';
import '../../models/permission.dart';
import '../../providers/permissions_provider.dart';
import '../../providers/roles_provider.dart';
import '../../router/app_router.dart';
import '../../theme/app_theme.dart';
import '../../theme/breakpoints.dart';
import '../../widgets/data_page/data_column_spec.dart';
import '../../widgets/data_page/data_page_scaffold.dart';
import '../../widgets/data_page/reusable_data_table.dart';
import '../../widgets/data_page/status_badge.dart';
import '../../widgets/data_page/summary_metric_card.dart';
import 'role_form_dialog.dart';
import '../../utils/dialog_helper.dart';

/// Roles and what each one can do.
///
/// Uses [DataPageScaffold] like every other list page, but deliberately omits
/// two things the others carry: exports, because a permission matrix is not
/// something anyone takes to a spreadsheet, and the search/filter toolbar,
/// because a business has a handful of roles and filtering five rows is a
/// control that costs more than it returns.
class RolesScreen extends ConsumerWidget {
  const RolesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(rolesQueryProvider);
    final slice = ref.watch(rolesSliceProvider);
    final summary = ref.watch(rolesSummaryProvider);
    final counts = ref.watch(roleStaffCountsProvider);
    final notifier = ref.read(rolesQueryProvider.notifier);
    final canCreate = ref.watch(hasPermissionProvider(AppPermissions.rolesCreate));

    return DataPageScaffold(
      title: AppStrings.rolesPermissionsTitle,
      subtitle: AppStrings.rolesSubtitle(
        summary.totalRoles,
        summary.staffAssigned,
      ),
      actions: [
        OutlinedButton.icon(
          onPressed: () => context.canPop()
              ? context.pop()
              : context.goNamed(AppRoute.staffName),
          icon: const Icon(Icons.arrow_back_rounded, size: 18),
          label: Text(AppStrings.backToStaffButton),
        ),
      ],
      primaryAction: !canCreate
          ? null
          : FilledButton.icon(
              onPressed: () => showRoleFormDialog(context),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(AppStrings.createRoleButton),
            ),
      onRefresh: () => ref.read(rolesProvider.notifier).refresh(),
      fab: !canCreate
          ? null
          : DataPageFab(
              icon: Icons.add_rounded,
              label: AppStrings.createRoleButton,
              onPressed: () => showRoleFormDialog(context),
            ),
      metrics: [
        SummaryMetricCard(
          label: AppStrings.totalRoles,
          value: '${summary.totalRoles}',
          trend: AppStrings.builtInCount(
            summary.totalRoles - summary.customRoles,
          ),
          icon: Icons.shield_outlined,
        ),
        SummaryMetricCard(
          label: AppStrings.customRoles,
          value: '${summary.customRoles}',
          trend: summary.customRoles == 0
              ? AppStrings.noneCreatedYet
              : AppStrings.createdForBusiness,
          icon: Icons.tune_rounded,
          accent: context.colors.tertiary,
        ),
        SummaryMetricCard(
          label: AppStrings.staffAssigned,
          value: '${summary.staffAssigned}',
          trend: AppStrings.acrossAllRoles,
          icon: Icons.groups_outlined,
          accent: context.semantic.success,
        ),
      ],
      // The scaffold requires a toolbar slot; this page has no use for search
      // or filters, so it spends the space on the one thing that does help —
      // saying what the table below is counting.
      toolbar: const _RolesCaption(),
      table: ReusableDataTable<BusinessRole>(
        columns: roleColumns(counts),
        slice: slice,
        query: query,
        onSort: notifier.toggleSort,
        onPageChanged: notifier.setPage,
        groupedItems: ref.watch(sortedRolesProvider),
        onGroupChanged: notifier.setGroup,
        onRowTap: (role) => showRoleFormDialog(context, existingRole: role),
        rowActions: _actions(ref),
      ),
    );
  }

  List<DataRowAction<BusinessRole>> _actions(WidgetRef ref) => [
    if (ref.watch(hasPermissionProvider(AppPermissions.rolesUpdate)))
      DataRowAction(
        label: AppStrings.editRoleAction,
        icon: Icons.edit_outlined,
        onSelected: (context, role) =>
            showRoleFormDialog(context, existingRole: role),
      ),
    if (ref.watch(hasPermissionProvider(AppPermissions.rolesCreate)))
      DataRowAction(
        label: AppStrings.duplicateAction,
        icon: Icons.copy_all_outlined,
        onSelected: (context, role) => _duplicate(context, ref, role),
      ),
    if (ref.watch(hasPermissionProvider(AppPermissions.rolesDelete)))
      DataRowAction(
        label: AppStrings.deleteRoleAction,
        icon: Icons.delete_outline_rounded,
        isDestructive: true,
        // The backend refuses a protected role (403) or one with active
        // staff assignments (409) — disabled here for the same reasons,
        // matching what the row's tooltip already explains.
        isEnabled: (role) =>
            !role.isProtected && (ref.read(roleStaffCountsProvider)[role.id] ?? 0) == 0,
        onSelected: (context, role) => _confirmDelete(context, ref, role),
      ),
  ];

  Future<void> _duplicate(BuildContext context, WidgetRef ref, BusinessRole role) async {
    try {
      final copy = await ref.read(rolesProvider.notifier).duplicate(role.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.roleDuplicated(copy.name))),
      );
    } on AuthException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    BusinessRole role,
  ) async {
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppStrings.deleteRoleTitle(role.name)),
        content: Text(AppStrings.deleteRoleBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(AppStrings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(AppStrings.deleteAction),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(rolesProvider.notifier).delete(role.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(content: Text(AppStrings.roleDeleted(role.name))),
      );
    } on AuthException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

/// Stands in for the toolbar on a page that does not need one.
class _RolesCaption extends StatelessWidget {
  const _RolesCaption();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.info_outline_rounded,
          size: 16,
          color: context.colors.onSurfaceVariant,
        ),
        const SizedBox(width: Insets.sm),
        Expanded(
          child: Text(
            AppStrings.builtinCaption,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.text.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

List<DataColumnSpec<BusinessRole>> roleColumns(Map<String, int> counts) => [
  DataColumnSpec(
    label: AppStrings.roleColumn,
    field: RoleSort.name,
    role: ColumnRole.primary,
    flex: 5,
    value: (role) => role.name,
    cellBuilder: (context, role) => _RoleCell(role: role),
  ),
  DataColumnSpec(
    label: AppStrings.staffColumn,
    field: RoleSort.staffCount,
    flex: 2,
    numeric: true,
    value: (role) => '${counts[role.id] ?? 0}',
  ),
  DataColumnSpec(
    label: AppStrings.permissionsColumn,
    field: RoleSort.permissions,
    flex: 3,
    minTableWidth: 620,
    value: (role) => role.permissionSummary,
    cellBuilder: (context, role) => _PermissionsCell(role: role),
  ),
  DataColumnSpec(
    label: AppStrings.typeColumn,
    field: 'roleType',
    role: ColumnRole.status,
    sortable: false,
    width: 120,
    groupable: true,
    value: (role) =>
        role.isProtected ? AppStrings.builtInBadge : AppStrings.customBadge,
    // Says the same thing the column's value says — a badge showing the role's
    // name here would put a different word on screen from the one an export
    // carries for the same cell.
    cellBuilder: (context, role) => Tooltip(
      message: role.isProtected
          ? AppStrings.builtinLockedTooltip
          : AppStrings.createdForBusiness,
      child: StatusBadge(
        label: role.isProtected
            ? AppStrings.builtInBadge
            : AppStrings.customBadge,
        tone: role.isProtected ? StatusTone.neutral : StatusTone.info,
        icon: role.isProtected
            ? Icons.lock_outline_rounded
            : Icons.auto_awesome_outlined,
        dense: true,
      ),
    ),
  ),
];

class _RoleCell extends StatelessWidget {
  const _RoleCell({required this.role});

  final BusinessRole role;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          role.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        Text(
          role.description,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: context.text.bodySmall?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// The permission count with a bar behind it, so relative reach across roles is
/// legible without reading four numbers.
class _PermissionsCell extends StatelessWidget {
  const _PermissionsCell({required this.role});

  final BusinessRole role;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final total = role.permissionCount;
    final fraction = total == 0 ? 0.0 : total / AppPermissions.count;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          role.permissionSummary,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.text.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: Insets.xs + 1),
        ClipRRect(
          borderRadius: BorderRadius.circular(Radii.pill),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 4,
            backgroundColor: colors.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation(
              fraction == 1 ? context.semantic.success : colors.primary,
            ),
          ),
        ),
      ],
    );
  }
}
