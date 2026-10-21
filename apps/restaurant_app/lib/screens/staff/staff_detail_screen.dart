import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/identity_service_api.dart' show AuthException;
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
import '../../widgets/activity_timeline_tile.dart';
import '../../widgets/data_page/status_badge.dart';
import '../../widgets/data_page/summary_metric_card.dart';
import '../../widgets/detail_page/detail_page_scaffold.dart';
import '../../widgets/staff/role_badge.dart';
import 'invite_staff_dialog.dart';
import '../../utils/dialog_helper.dart';

/// One staff member: who they are, what they can do, and what they have done.
///
/// Same structural pattern as Sale Detail — header, main content, side panel —
/// so moving between the two detail screens feels like one app rather than two.
class StaffDetailScreen extends ConsumerWidget {
  const StaffDetailScreen({super.key, required this.staffId});

  final String staffId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final member = ref.watch(staffByIdProvider(staffId));
    if (member == null) return _NotFound(staffId: staffId);

    final role = ref.watch(roleByIdProvider(member.roleId));
    final activity = ref.watch(staffActivityProvider(staffId));
    final performance = ref.watch(staffPerformanceProvider(staffId));

    return DetailPageScaffold(
      header: _Header(member: member, role: role),
      sidePanel: [
        _ContactPanel(member: member),
        _AccessPanel(member: member, role: role),
      ],
      onRefresh: () => ref.read(staffMembersProvider.notifier).refresh(),
      children: [
        // Omitted entirely for a role without till access — three zeroes would
        // imply a stock controller is bad at selling rather than not doing it.
        if (performance.applies) _PerformanceBlock(performance: performance),
        DetailPanel(
          title: AppStrings.recentActivity,
          child: ActivityTimeline(
            entries: activity,
            emptyState: _NoActivity(member: member),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _Header extends ConsumerWidget {
  const _Header({required this.member, required this.role});

  final StaffMember member;
  final BusinessRole? role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canAssign = ref.watch(hasPermissionProvider(AppPermissions.staffAssign));

    return DetailPageHeader(
      title: member.name,
      subtitle: member.email,
      onBack: () => context.canPop()
          ? context.pop()
          : context.goNamed(AppRoute.staffName),
      leading: StaffAvatar(initials: member.initials, role: role, size: 48),
      badges: [
        StatusBadge(
          label: member.status.label,
          tone: member.status.tone,
          icon: member.status.badgeIcon,
          dense: true,
        ),
        RoleBadge(
          role: role,
          scopeLabel: member.primaryRole?.storeName,
          dense: true,
        ),
      ],
      actions: [
        if (canAssign)
          OutlinedButton.icon(
            onPressed: () => showAddRoleDialog(context, member),
            icon: const Icon(Icons.badge_outlined, size: 18),
            label: Text(AppStrings.addRole),
          ),
        _OverflowMenu(member: member),
      ],
    );
  }
}

class _OverflowMenu extends ConsumerWidget {
  const _OverflowMenu({required this.member});

  final StaffMember member;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canRevoke = ref.watch(hasPermissionProvider(AppPermissions.staffRevoke));
    // Nothing on this menu means anything without revoke — hide it rather
    // than show a menu with one disabled item.
    if (!canRevoke || member.roles.isEmpty) return const SizedBox.shrink();

    return PopupMenuButton<String>(
      tooltip: AppStrings.moreActions,
      position: PopupMenuPosition.under,
      icon: const Icon(Icons.more_horiz_rounded),
      onSelected: (value) => switch (value) {
        'remove' => _confirmRemove(context, ref),
        _ => null,
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'remove',
          child: Row(
            children: [
              Icon(
                Icons.person_remove_outlined,
                size: 17,
                color: context.semantic.danger,
              ),
              const SizedBox(width: Insets.md),
              Text(
                AppStrings.removeFromTeam,
                style: TextStyle(color: context.semantic.danger),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _confirmRemove(BuildContext context, WidgetRef ref) async {
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
        await notifier.revokeRole(
          userId: member.id,
          roleId: role.roleId,
          storeId: role.storeId,
        );
      } catch (_) {
        failures++;
      }
    }
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    if (failures == 0) {
      // Leave before the record disappears out from under this screen.
      context.canPop() ? context.pop() : context.goNamed(AppRoute.staffName);
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          failures == 0
              ? AppStrings.memberRemoved(member.name)
              : AppStrings.removeRolesFailed(member.name),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Side panel
// ---------------------------------------------------------------------------

class _ContactPanel extends StatelessWidget {
  const _ContactPanel({required this.member});

  final StaffMember member;

  @override
  Widget build(BuildContext context) {
    return DetailPanel(
      title: AppStrings.contactPanel,
      child: LabeledValueGrid(
        maxColumns: 2,
        minColumnWidth: 240,
        children: [
          LabeledValue(
            label: AppStrings.emailField,
            value: member.email,
            icon: Icons.mail_outline_rounded,
          ),
          LabeledValue(
            label: AppStrings.phoneLabel,
            value: member.phone,
            icon: Icons.phone_outlined,
          ),
          LabeledValue(
            label: member.isPending
                ? AppStrings.invitedValue
                : AppStrings.joinedValue,
            value: Fmt.dayMonthTime(member.joinedAt),
            icon: Icons.event_outlined,
          ),
          LabeledValue(
            label: AppStrings.lastActiveField,
            value: member.lastActiveAt == null
                ? AppStrings.neverSignedIn
                : Fmt.relativeDateTime(member.lastActiveAt!),
            icon: Icons.schedule_rounded,
          ),
        ],
      ),
    );
  }
}

class _AccessPanel extends ConsumerWidget {
  const _AccessPanel({required this.member, required this.role});

  final StaffMember member;
  final BusinessRole? role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final allRoles = ref.watch(rolesProvider).valueOrNull ?? const <BusinessRole>[];
    final canAssign = ref.watch(hasPermissionProvider(AppPermissions.staffAssign));
    final canRevoke = ref.watch(hasPermissionProvider(AppPermissions.staffRevoke));

    return DetailPanel(
      title: AppStrings.accessPanel,
      trailing: canAssign
          ? TextButton(
              onPressed: () => showAddRoleDialog(context, member),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
                minimumSize: const Size(0, 32),
                visualDensity: VisualDensity.compact,
              ),
              child: Text(AppStrings.addAction),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (member.roles.isEmpty)
            Text(
              AppStrings.noRolesHere,
              style: context.text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            )
          else
            for (var i = 0; i < member.roles.length; i++) ...[
              if (i > 0) const SizedBox(height: Insets.lg),
              _RoleRow(
                assignment: member.roles[i],
                role: allRoles.where((r) => r.id == member.roles[i].roleId).firstOrNull,
                canRevoke: canRevoke,
                onRevoke: () => _revokeOne(context, ref, member.roles[i]),
              ),
            ],
          if (member.inviteNote case final note?) ...[
            const SizedBox(height: Insets.lg),
            const Divider(height: 1),
            const SizedBox(height: Insets.lg),
            LabeledValue(
              label: AppStrings.inviteMessage,
              value: note,
              icon: Icons.chat_bubble_outline_rounded,
              maxLines: 5,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _revokeOne(
    BuildContext context,
    WidgetRef ref,
    StaffRoleAssignment assignment,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(staffMembersProvider.notifier).revokeRole(
        userId: member.id,
        roleId: assignment.roleId,
        storeId: assignment.storeId,
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            AppStrings.roleRemovedFrom(assignment.displayName, member.name),
          ),
        ),
      );
    } on AuthException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(content: Text(AppStrings.couldNotRemoveRole)),
      );
    }
  }
}

class _RoleRow extends StatelessWidget {
  const _RoleRow({
    required this.assignment,
    required this.role,
    required this.canRevoke,
    required this.onRevoke,
  });

  final StaffRoleAssignment assignment;
  final BusinessRole? role;
  final bool canRevoke;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              RoleBadge(role: role, scopeLabel: assignment.storeName),
              const SizedBox(height: Insets.sm),
              Text(
                role?.description ?? AppStrings.roleGone,
                style: context.text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
              if (role != null) ...[
                const SizedBox(height: Insets.md),
                Text(
                  role!.permissionSummary,
                  style: context.text.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ],
          ),
        ),
        if (canRevoke)
          IconButton(
            tooltip: AppStrings.removeRoleTooltip,
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.close_rounded, size: 18, color: colors.onSurfaceVariant),
            onPressed: onRevoke,
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Performance
// ---------------------------------------------------------------------------

class _PerformanceBlock extends StatelessWidget {
  const _PerformanceBlock({required this.performance});

  final StaffPerformance performance;

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[
      SummaryMetricCard(
        label: AppStrings.ordersToday,
        value: '${performance.ordersToday}',
        trend: performance.ordersToday == 0
            ? AppStrings.notOnShift
            : AppStrings.onTheTill,
        icon: Icons.receipt_long_outlined,
      ),
      SummaryMetricCard(
        label: AppStrings.ordersThisWeek,
        value: '${performance.ordersThisWeek}',
        trend: AppStrings.last7Days,
        icon: Icons.date_range_outlined,
      ),
      SummaryMetricCard(
        label: AppStrings.salesHandled,
        value: Fmt.moneyCompact(performance.salesHandled),
        trend: AppStrings.last7Days,
        icon: Icons.payments_outlined,
        accent: context.semantic.success,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = Insets.md;
        // Three across where there is room, otherwise stacked — two of three
        // side by side with one orphaned below reads as a layout accident.
        final columns = constraints.maxWidth >= 640 ? 3 : 1;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final tile in tiles) SizedBox(width: width, child: tile),
          ],
        );
      },
    );
  }
}

class _NoActivity extends StatelessWidget {
  const _NoActivity({required this.member});

  final StaffMember member;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Insets.xl),
      child: Column(
        children: [
          Icon(
            member.isPending
                ? Icons.mark_email_unread_outlined
                : Icons.history_toggle_off_rounded,
            size: 28,
            color: colors.onSurfaceVariant.withValues(alpha: 0.6),
          ),
          const SizedBox(height: Insets.sm),
          Text(
            member.isPending
                ? AppStrings.noInviteActivity
                : AppStrings.noActivityRecorded,
            textAlign: TextAlign.center,
            style: context.text.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotFound extends StatelessWidget {
  const _NotFound({required this.staffId});

  final String staffId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(Insets.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.person_search_outlined,
                  size: 36,
                  color: context.colors.onSurfaceVariant,
                ),
                const SizedBox(height: Insets.md),
                Text(
                  AppStrings.staffNotFound(staffId),
                  textAlign: TextAlign.center,
                  style: context.text.titleMedium,
                ),
                const SizedBox(height: Insets.lg),
                FilledButton.icon(
                  onPressed: () => context.goNamed(AppRoute.staffName),
                  icon: const Icon(Icons.groups_outlined, size: 18),
                  label: Text(AppStrings.backToStaff),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
