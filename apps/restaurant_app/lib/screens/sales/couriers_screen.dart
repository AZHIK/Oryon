import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/courier.dart';
import '../../constants/app_strings.dart';
import '../../models/permission.dart';
import '../../providers/couriers_provider.dart';
import '../../providers/permissions_provider.dart';
import '../../services/courier_api_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/breakpoints.dart';
import '../../utils/dialog_helper.dart';
import '../../widgets/data_page/status_badge.dart';
import '../../widgets/data_page/summary_metric_card.dart';
import 'courier_form_dialog.dart';

class CouriersScreen extends ConsumerWidget {
  const CouriersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final couriersAsync = ref.watch(couriersProvider);
    final couriers = couriersAsync.valueOrNull ?? const <Courier>[];
    final active = couriers.where((c) => c.status == CourierStatus.active).toList();
    final inactive = couriers.where((c) => c.status == CourierStatus.inactive).toList();
    final canCreate = ref.watch(
      hasPermissionProvider(AppPermissions.couriersCreate),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.couriersTitle),
        elevation: 0,
        actions: [
          // Same action as the FAB, for pointer-first layouts.
          if (canCreate)
            IconButton(
              tooltip: AppStrings.addCourier,
              onPressed: () => showCourierFormDialog(context),
              icon: const Icon(Icons.add_rounded),
            ),
        ],
      ),
      // Hidden rather than shown-disabled: someone who can't add couriers
      // shouldn't see a control that only ever 403s.
      floatingActionButton: !canCreate
          ? null
          : FloatingActionButton.extended(
              onPressed: () => showCourierFormDialog(context),
              icon: const Icon(Icons.add_rounded),
              label: Text(AppStrings.addCourier),
            ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(couriersProvider.notifier).refresh(),
        child: couriersAsync.when(
          data: (_) => _body(context, ref, active, inactive, couriers),
          loading: () => couriers.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _body(context, ref, active, inactive, couriers),
          error: (e, _) => couriers.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(Insets.lg),
                  children: [
                    const SizedBox(height: Insets.xl),
                    Center(
                      child: Text(
                        e is CourierApiException
                            ? e.message
                            : AppStrings.noCouriers,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                )
              : _body(context, ref, active, inactive, couriers),
        ),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref,
    List<Courier> active,
    List<Courier> inactive,
    List<Courier> couriers,
  ) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(Insets.lg),
      children: [
        Row(
          children: [
            Expanded(child: SummaryMetricCard(label: AppStrings.availableMetric, value: '${active.length}', trend: AppStrings.readyForDelivery, icon: Icons.two_wheeler_rounded, accent: context.semantic.success)),
            const SizedBox(width: Insets.md),
            Expanded(child: SummaryMetricCard(label: AppStrings.unavailableMetric, value: '${inactive.length}', trend: AppStrings.offlineTrend, icon: Icons.block_outlined, accent: context.semantic.warning)),
            const SizedBox(width: Insets.md),
            Expanded(child: SummaryMetricCard(label: AppStrings.totalMetric, value: '${couriers.length}', trend: AppStrings.couriersOnTeam, icon: Icons.groups_outlined)),
          ],
        ),
        const SizedBox(height: Insets.xl),
        if (active.isNotEmpty) ...[
          Text(AppStrings.activeCount(active.length), style: context.text.titleMedium),
          const SizedBox(height: Insets.md),
          ...active.map((c) => _CourierTile(courier: c)),
          const SizedBox(height: Insets.xl),
        ],
        if (inactive.isNotEmpty) ...[
          Text(AppStrings.inactiveCount(inactive.length), style: context.text.titleMedium),
          const SizedBox(height: Insets.md),
          ...inactive.map((c) => _CourierTile(courier: c)),
        ],
        if (couriers.isEmpty) Center(child: Padding(padding: const EdgeInsets.symmetric(vertical: Insets.xl), child: Column(children: [Icon(Icons.two_wheeler_rounded, size: 48, color: context.colors.onSurfaceVariant), const SizedBox(height: Insets.md), Text(AppStrings.noCouriers, style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant))]))),
      ],
    );
  }
}

class _CourierTile extends ConsumerWidget {
  const _CourierTile({required this.courier});
  final Courier courier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tone = courier.status == CourierStatus.active ? StatusTone.positive : StatusTone.neutral;
    final canUpdate = ref.watch(
      hasPermissionProvider(AppPermissions.couriersUpdate),
    );
    final canDelete = ref.watch(
      hasPermissionProvider(AppPermissions.couriersDelete),
    );
    final showMenu = canUpdate || canDelete;

    return Container(
      margin: const EdgeInsets.only(bottom: Insets.md),
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(border: Border.all(color: context.semantic.hairline), borderRadius: BorderRadius.circular(Insets.md)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 48, height: 48, decoration: BoxDecoration(color: context.colors.surfaceContainerHigh, borderRadius: BorderRadius.circular(Insets.md)), alignment: Alignment.center, child: Icon(Icons.person_rounded, color: context.colors.onSurfaceVariant)),
              const SizedBox(width: Insets.md),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(courier.name, style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w600)), const SizedBox(height: Insets.xs), Text(courier.phone, style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant))])),
              StatusBadge(label: courier.status.label, tone: tone, dense: true),
              if (showMenu)
                PopupMenuButton<String>(
                  tooltip: AppStrings.editCourier,
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        showCourierFormDialog(
                          context,
                          existingCourier: courier,
                        );
                      case 'toggle':
                        _toggleActive(context, ref);
                      case 'delete':
                        _confirmDelete(context, ref);
                    }
                  },
                  itemBuilder: (menuContext) => [
                    if (canUpdate)
                      PopupMenuItem(
                        value: 'edit',
                        child: Text(AppStrings.editCourier),
                      ),
                    if (canUpdate)
                      PopupMenuItem(
                        value: 'toggle',
                        child: Text(
                          courier.status == CourierStatus.active
                              ? AppStrings.unavailableMetric
                              : AppStrings.availableMetric,
                        ),
                      ),
                    if (canDelete)
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(AppStrings.deleteAction),
                      ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: Insets.md),
          Container(padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.sm), decoration: BoxDecoration(color: context.colors.surfaceContainerLowest, borderRadius: BorderRadius.circular(Insets.sm)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.two_wheeler_rounded, size: 16, color: context.colors.onSurfaceVariant), const SizedBox(width: Insets.xs), Text(courier.vehicle.isEmpty ? AppStrings.emDash : courier.vehicle, style: context.text.labelSmall?.copyWith(color: context.colors.onSurfaceVariant))])),
        ],
      ),
    );
  }

  Future<void> _toggleActive(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(couriersProvider.notifier)
          .setActive(
            courier,
            courier.status != CourierStatus.active,
          );
    } on CourierApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(AppStrings.saveFailed(e))),
      );
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppStrings.deleteCourierTitle(courier.name)),
        content: Text(AppStrings.deleteCourierBody),
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

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(couriersProvider.notifier).remove(courier.id);
      messenger.showSnackBar(
        SnackBar(content: Text(AppStrings.courierDeleted(courier.name))),
      );
    } on CourierApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(AppStrings.saveFailed(e))),
      );
    }
  }
}
