import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/app_strings.dart';
import '../../models/staff_member.dart';
import '../../providers/roles_provider.dart';
import '../../providers/staff_provider.dart';
import '../../theme/breakpoints.dart';
import '../../widgets/section_label.dart';

/// Role and status filters for the Staff table.
///
/// Rendered inside the toolbar's popover on desktop and its sheet on mobile —
/// this widget supplies only the fields, exactly as the Inventory filter panel
/// does, and knows nothing about which container it landed in.
class StaffFilterPanel extends ConsumerWidget {
  const StaffFilterPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(staffFiltersProvider);
    final notifier = ref.read(staffFiltersProvider.notifier);
    final roles = ref.watch(rolesProvider).valueOrNull ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SectionLabel(AppStrings.roleFilter),
        const SizedBox(height: Insets.sm),
        Wrap(
          spacing: Insets.sm,
          runSpacing: Insets.sm,
          children: [
            for (final role in roles)
              FilterChip(
                label: Text(role.displayName),
                selected: filters.roleIds.contains(role.id),
                onSelected: (_) => notifier.toggleRole(role.id),
              ),
          ],
        ),
        const SizedBox(height: Insets.xl),
        SectionLabel(AppStrings.statusFilter),
        const SizedBox(height: Insets.sm),
        Wrap(
          spacing: Insets.sm,
          runSpacing: Insets.sm,
          children: [
            for (final status in StaffStatus.values)
              FilterChip(
                label: Text(status.label),
                selected: filters.statuses.contains(status),
                onSelected: (_) => notifier.toggleStatus(status),
              ),
          ],
        ),
      ],
    );
  }
}
