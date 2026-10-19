import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/permission.dart';
import '../../models/store_location.dart';
import '../../constants/app_strings.dart';
import '../../providers/permissions_provider.dart';
import '../../providers/store_api_provider_real.dart';
import '../../providers/store_locations_provider.dart';
import '../../router/app_router.dart';
import 'store_switch_flow.dart';
import '../../theme/app_theme.dart';
import '../../theme/breakpoints.dart';
import '../../widgets/data_page/data_column_spec.dart';
import '../../widgets/data_page/data_page_scaffold.dart';
import '../../widgets/data_page/reusable_data_table.dart';
import '../../widgets/data_page/status_badge.dart';
import '../../widgets/data_page/summary_metric_card.dart';
import 'location_form_dialog.dart';
import '../../utils/dialog_helper.dart';

/// Every site the business trades from.
///
/// Uses [DataPageScaffold] like Inventory, Sales and Staff even though a
/// business has four locations rather than four hundred: the value of the
/// shared shell is that a list page looks like a list page, and a bespoke
/// layout for a short list is a second thing to maintain for no gain.
///
/// This screen edits the same provider the stock transfer dialog reads, so a
/// site added here is a transfer destination on the next frame.
class StoreManagementScreen extends ConsumerWidget {
  const StoreManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(locationsQueryProvider);
    final slice = ref.watch(locationsSliceProvider);
    final summary = ref.watch(locationsSummaryProvider);
    final managers = ref.watch(locationManagerNamesProvider);
    final notifier = ref.read(locationsQueryProvider.notifier);

    return DataPageScaffold(
      title: AppStrings.storeLocationsTitle,
      subtitle: AppStrings.storeLocationsSubtitle,
      actions: [
        OutlinedButton.icon(
          onPressed: () => context.canPop()
              ? context.pop()
              : context.goNamed(AppRoute.settingsName),
          icon: const Icon(Icons.arrow_back_rounded, size: 18),
          label: Text(AppStrings.backToSettings),
        ),
      ],
      primaryAction: FilledButton.icon(
        onPressed: () => showLocationFormDialog(context),
        icon: const Icon(Icons.add_rounded, size: 18),
        label: Text(AppStrings.addLocationAction),
      ),
      onRefresh: () => refreshStores(ref),
      fab: DataPageFab(
        icon: Icons.add_rounded,
        label: AppStrings.addLocationAction,
        onPressed: () => showLocationFormDialog(context),
      ),
      metrics: [
        SummaryMetricCard(
          label: AppStrings.totalLocations,
          value: '${summary.total}',
          trend: summary.total == 1
              ? AppStrings.singleSite
              : AppStrings.acrossBusiness,
          icon: Icons.storefront_outlined,
        ),
        SummaryMetricCard(
          label: AppStrings.activeLocations,
          value: '${summary.active}',
          trend: summary.active == summary.total
              ? AppStrings.allTrading
              : AppStrings.inactiveLocations(summary.total - summary.active),
          icon: Icons.check_circle_outline_rounded,
          accent: context.semantic.success,
        ),
        SummaryMetricCard(
          label: AppStrings.totalStaffMetric,
          value: '${summary.staff}',
          trend: AppStrings.basedAllSites,
          icon: Icons.groups_outlined,
          accent: context.colors.tertiary,
        ),
      ],
      // No search or filters: filtering four rows is a control that costs more
      // than it returns, the same call the Roles page makes.
      toolbar: const _LocationsCaption(),
      table: ReusableDataTable<StoreLocation>(
        columns: locationColumns(managers),
        slice: slice,
        query: query,
        onSort: notifier.toggleSort,
        onPageChanged: notifier.setPage,
        groupedItems: ref.watch(sortedLocationsProvider),
        onGroupChanged: notifier.setGroup,
        // Straight into the edit form rather than a detail screen — six fields
        // is a dialog, not a page.
        onRowTap: (location) =>
            showLocationFormDialog(context, existing: location),
        rowActions: _actions(ref),
      ),
    );
  }

  List<DataRowAction<StoreLocation>> _actions(WidgetRef ref) {
    final currentId = ref.watch(currentStoreIdProvider);
    final switchAllowed =
        ref.watch(hasPermissionProvider(AppPermissions.storesSwitch)) &&
        (ref.watch(currentClaimsProvider)?.isBusinessStaff ?? false);

    return [
      DataRowAction(
        label: AppStrings.switchStoreAction,
        icon: Icons.swap_horiz_rounded,
        // The terminal's own store is already current; anyone without the
        // switch permission (or store staff, who can never hold it
        // usefully) gets no affordance at all.
        isEnabled: (location) =>
            switchAllowed &&
            (currentId == null || location.id != currentId),
        onSelected: (context, location) =>
            runStoreSwitchFlow(context, ref, location),
      ),
      DataRowAction(
        label: AppStrings.editLocationAction,
        icon: Icons.edit_outlined,
        onSelected: (context, location) =>
            showLocationFormDialog(context, existing: location),
      ),
    DataRowAction(
      label: AppStrings.toggleActiveAction,
      icon: Icons.toggle_on_outlined,
      // The current store and the last active site both stay switched on: a
      // business with nowhere to trade is not a reachable state.
      isEnabled: (location) =>
          !location.isCurrent &&
          (!location.isActive ||
              ref.read(storeLocationsProvider.notifier).canDeactivate(
                location.id,
              )),
      onSelected: (context, location) {
        final wasActive = location.isActive;
        final done = ref
            .read(storeLocationsProvider.notifier)
            .toggleActive(location.id);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              done
                  ? AppStrings.locationToggled(location.name, wasActive)
                  : AppStrings.oneActiveRequired,
            ),
          ),
        );
      },
    ),
    DataRowAction(
      label: AppStrings.deleteLocationAction,
      icon: Icons.delete_outline_rounded,
      isDestructive: true,
      isEnabled: (location) =>
          ref.read(storeLocationsProvider.notifier).canDelete(location.id),
      onSelected: (context, location) => _confirmDelete(context, ref, location),
    ),
    ];
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    StoreLocation location,
  ) async {
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppStrings.deleteLocationTitle(location.name)),
        content: Text(
          location.staffCount == 0
              ? AppStrings.deleteLocationEmpty
              : AppStrings.deleteLocationStaffed(location.staffCount),
        ),
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

    final done = ref.read(storeLocationsProvider.notifier).delete(location.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          done
              ? AppStrings.locationDeleted(location.name)
              : AppStrings.lastActiveNoDelete,
        ),
      ),
    );
  }
}

/// Stands in for the toolbar on a page that does not need one, and carries the
/// rule the row actions enforce so it is stated before someone hits it.
class _LocationsCaption extends ConsumerWidget {
  const _LocationsCaption();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(currentStoreProvider);

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
            current == null
                ? AppStrings.lastActiveLocked
                : AppStrings.terminalHereLocked(current.name),
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

List<DataColumnSpec<StoreLocation>> locationColumns(
  Map<String, String> managers,
) => [
  DataColumnSpec(
    label: AppStrings.locationColumn,
    field: LocationSort.name,
    role: ColumnRole.primary,
    flex: 4,
    value: (location) => location.name,
    cellBuilder: (context, location) => _NameCell(location: location),
  ),
  DataColumnSpec(
    label: AppStrings.addressColumn,
    field: 'locationAddress',
    sortable: false,
    flex: 5,
    minTableWidth: 760,
    value: (location) => location.address ?? AppStrings.emDash,
  ),
  DataColumnSpec(
    label: AppStrings.managerColumn,
    field: LocationSort.manager,
    flex: 3,
    minTableWidth: 560,
    value: (location) =>
        managers[location.id] ?? StoreLocation.unassignedManager,
  ),
  DataColumnSpec(
    label: AppStrings.locationStaffColumn,
    field: LocationSort.staff,
    flex: 2,
    numeric: true,
    value: (location) => '${location.staffCount}',
  ),
  DataColumnSpec(
    label: AppStrings.statusColumn,
    field: LocationSort.status,
    role: ColumnRole.status,
    width: 116,
    groupable: true,
    value: (location) => location.isActive
        ? AppStrings.activeValue
        : AppStrings.inactiveValue,
    cellBuilder: (context, location) => StatusBadge(
      label: location.isActive
          ? AppStrings.activeValue
          : AppStrings.inactiveValue,
      tone: location.isActive ? StatusTone.positive : StatusTone.neutral,
      dense: true,
    ),
  ),
];

/// The site's name, with the terminal's own site called out — the one fact
/// about this table that changes what the other screens do.
///
/// Compared against the live store id, not [StoreLocation.isCurrent]: that
/// flag is never set on backend-loaded rows, so it can never mark anything.
class _NameCell extends ConsumerWidget {
  const _NameCell({required this.location});

  final StoreLocation location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCurrent = ref.watch(currentStoreIdProvider) == location.id;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          location.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        Text(
          isCurrent
              ? AppStrings.thisStoreMarker
              : (location.phone ?? '').isEmpty
              ? AppStrings.emDash
              : location.phone!,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.text.bodySmall?.copyWith(
            color: isCurrent
                ? context.colors.primary
                : context.colors.onSurfaceVariant,
            fontWeight: isCurrent ? FontWeight.w600 : null,
          ),
        ),
      ],
    );
  }
}
