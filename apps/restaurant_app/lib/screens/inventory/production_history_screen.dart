import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/app_durations.dart';
import '../../constants/app_strings.dart';

import '../../providers/production_provider.dart';
import '../../services/inventory_api_service.dart';
import '../../models/permission.dart';
import '../../providers/permissions_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/breakpoints.dart';
import '../../utils/formatters.dart';
import '../../widgets/data_page/summary_metric_card.dart';
import '../../widgets/responsive_form_dialog.dart';
import 'record_production_dialog.dart';
import 'stock_dialog_shared.dart';
import '../../utils/dialog_helper.dart';

/// The kitchen's production ledger: every recorded run, newest first.
///
/// Amounts come pre-resolved from the backend (names and units, not ids),
/// so this screen formats rather than joins — the same read-only posture
/// as the sales ledger.
class ProductionHistoryScreen extends ConsumerWidget {
  const ProductionHistoryScreen({super.key});

  Future<void> _pickRange(BuildContext context, WidgetRef ref) async {
    final current = ref.read(productionDateFilterProvider);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(AppDurations.singleDay),
      initialDateRange: current.from == null && current.to == null
          ? null
          : DateTimeRange(
              start: current.from ??
                  DateTime.now().subtract(AppDurations.analyticsWindow),
              end: current.to ?? DateTime.now(),
            ),
    );
    if (picked == null) return;
    ref
        .read(productionDateFilterProvider.notifier)
        .setRange(picked.start, picked.end);
    await ref.read(productionHistoryProvider.notifier).refresh();
  }

  Future<void> _clearRange(WidgetRef ref) async {
    ref.read(productionDateFilterProvider.notifier).clear();
    await ref.read(productionHistoryProvider.notifier).refresh();
  }

  /// Starts a run from this screen: pick which recipe, then measure.
  ///
  /// A two-step flow rather than a recipe dropdown inside the record dialog —
  /// the dialog's job is measuring and confirming, and overloading it with
  /// catalog picking would tangle two unrelated states.
  Future<void> _startRun(BuildContext context, WidgetRef ref) async {
    final recipe = await showAppDialog<RecipeDto>(
      context: context,
      builder: (_) => const _RecipePickerDialog(),
    );
    if (recipe == null || !context.mounted) return;
    await showRecordProductionDialog(context, recipe);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(productionHistoryListProvider);
    final filter = ref.watch(productionDateFilterProvider);
    final loading = ref.watch(productionHistoryProvider).isLoading;
    final adjusted = events
        .where(
          (e) =>
              e.actualOutputQuantity.toString() !=
              e.suggestedOutputQuantity.toString(),
        )
        .length;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.productionTitle),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: AppStrings.filterByDate,
            onPressed: () => _pickRange(context, ref),
            icon: Badge(
              isLabelVisible: filter.from != null || filter.to != null,
              child: const Icon(Icons.calendar_month_outlined),
            ),
          ),
        ],
      ),
      floatingActionButton:
          ref.watch(hasPermissionProvider(AppPermissions.productionCreate))
              ? FloatingActionButton.extended(
                  key: const Key('productionHistory.record'),
                  onPressed: () => _startRun(context, ref),
                  icon: const Icon(Icons.add_rounded),
                  label: Text(AppStrings.recordAction),
                )
              : null,
      body: RefreshIndicator(
        onRefresh: () => ref.read(productionHistoryProvider.notifier).refresh(),
        child: ListView(
          padding: const EdgeInsets.all(Insets.lg),
          children: [
            Row(
              children: [
                Expanded(
                  child: SummaryMetricCard(
                    label: AppStrings.runsMetric,
                    value: '${events.length}',
                    trend: AppStrings.recordedProductions,
                    icon: Icons.soup_kitchen_outlined,
                    accent: context.colors.primary,
                  ),
                ),
                const SizedBox(width: Insets.md),
                Expanded(
                  child: SummaryMetricCard(
                    label: AppStrings.adjustedMetric,
                    value: '$adjusted',
                    trend: AppStrings.portionsDiffered,
                    icon: Icons.tune_rounded,
                    accent: context.semantic.warning,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Insets.md),
            if (filter.from != null || filter.to != null)
              Padding(
                padding: const EdgeInsets.only(bottom: Insets.md),
                child: InputChip(
                  label: Text(
                    AppStrings.dateChip(
                      filter.from == null
                          ? AppStrings.ellipsis
                          : Fmt.dayMonth(filter.from!),
                      filter.to == null
                          ? AppStrings.ellipsis
                          : Fmt.dayMonth(filter.to!),
                    ),
                  ),
                  deleteIcon: const Icon(Icons.clear_rounded, size: 16),
                  onDeleted: () => _clearRange(ref),
                ),
              ),
            if (loading && events.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: Insets.xl),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (events.isNotEmpty) ...[
              Text(
                AppStrings.runsWithCount(events.length),
                style: context.text.titleMedium,
              ),
              const SizedBox(height: Insets.md),
              ...events.map((e) => _ProductionTile(event: e)),
            ],
            if (!loading && events.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: Insets.xl),
                  child: Column(
                    children: [
                      Icon(
                        Icons.soup_kitchen_outlined,
                        size: 48,
                        color: context.colors.onSurfaceVariant,
                      ),
                      const SizedBox(height: Insets.md),
                      Text(
                        AppStrings.noRunsYet,
                        style: context.text.bodyMedium?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: Insets.xs),
                      Text(
                        AppStrings.recordFromMenuItem,
                        style: context.text.bodySmall?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Picks which recipe to produce. Returns the chosen recipe, or null when
/// the user backs out — the record dialog opens only after a choice, so a
/// dismissed picker records nothing.
class _RecipePickerDialog extends ConsumerWidget {
  const _RecipePickerDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Only linked recipes can be produced (the output needs a menu item
    // to stock) — standalone formulas stay in Production until linked.
    final recipes = ref.watch(linkedRecipesProvider);

    return ResponsiveFormDialog(
      title: AppStrings.whatMaking,
      width: kStockDialogWidth,
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppStrings.cancel),
        ),
      ],
      child: recipes.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: Insets.lg),
              child: Text(
                AppStrings.noRecipesYet,
                style: context.text.bodyMedium?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final recipe in recipes)
                  Card(
                    margin: const EdgeInsets.only(bottom: Insets.sm),
                    child: ListTile(
                      leading: Icon(
                        Icons.soup_kitchen_outlined,
                        color: context.colors.primary,
                      ),
                      title: Text(recipe.name),
                      subtitle: Text(
                        AppStrings.recipeSubtitle(
                          recipe.components.length,
                          recipe.sellableItemName,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.of(context).pop(recipe),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _ProductionTile extends StatelessWidget {
  const _ProductionTile({required this.event});

  final ProductionEventDto event;

  @override
  Widget build(BuildContext context) {
    final recorded = double.parse(event.actualOutputQuantity.toString());
    final suggested = double.parse(event.suggestedOutputQuantity.toString());
    final adjusted = recorded != suggested;
    final leading = _leadingComponent();

    return Card(
      margin: const EdgeInsets.only(bottom: Insets.md),
      child: InkWell(
        borderRadius: Radii.card,
        onTap: () => showProductionEventDetail(context, event),
        child: Padding(
          padding: const EdgeInsets.all(Insets.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      event.recipeName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleSmall,
                    ),
                  ),
                  if (adjusted)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Insets.sm,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: context.semantic.warning.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(Radii.pill),
                      ),
                      child: Text(
                        AppStrings.adjustedBadge,
                        style: context.text.labelSmall?.copyWith(
                          color: context.semantic.warning,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: Insets.xs),
              Text(
                AppStrings.tileDetail(
                  Fmt.quantity(_asDouble(event.leadingQuantityUsed)),
                  leading?.rawMaterialUnit ?? '',
                  leading?.rawMaterialName ?? '',
                  Fmt.quantity(recorded),
                  event.sellableItemName,
                ),
                style: context.text.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Insets.xs),
              Text(
                AppStrings.tileDate(
                  Fmt.dayMonthTime(event.occurredAt.toLocal()),
                  adjusted,
                  Fmt.quantity(suggested),
                ),
                style: context.text.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  ProductionComponentDto? _leadingComponent() {
    for (final component in event.components) {
      if (component.rawMaterialItemId == event.leadingComponentItemId) {
        return component;
      }
    }
    return null;
  }
}

/// Full detail for one run: every consumed ingredient plus the
/// suggested-vs-actual output that future insights will read.
Future<void> showProductionEventDetail(
  BuildContext context,
  ProductionEventDto event,
) {
  // NOTE: pop via dialogContext, not the outer `context`. showDialog
  // lands on the root Navigator while the screen lives in its shell
  // branch — popping the outer context pops the page itself.
  return showResponsiveFormDialog<void>(
    context,
    builder: (dialogContext) => ResponsiveFormDialog(
      title: event.recipeName,
      width: kStockDialogWidth,
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(AppStrings.close),
        ),
      ],
      child: _ProductionDetailBody(event: event),
    ),
  );
}

class _ProductionDetailBody extends StatelessWidget {
  const _ProductionDetailBody({required this.event});

  final ProductionEventDto event;

  @override
  Widget build(BuildContext context) {
    final recorded = double.parse(event.actualOutputQuantity.toString());
    final suggested = double.parse(event.suggestedOutputQuantity.toString());
    final goal = double.parse(event.yieldGoalQuantity.toString());
    final variancePct = event.yieldVariancePercent == null
        ? '—'
        : '${double.parse(event.yieldVariancePercent.toString()).toStringAsFixed(1)}%';
    final verdictLabel = switch (event.yieldStatus) {
      YieldStatusDto.above => AppStrings.yieldAbove,
      YieldStatusDto.withinThreshold => AppStrings.yieldWithin,
      YieldStatusDto.below => AppStrings.yieldBelow,
    };
    final verdictTone = switch (event.yieldStatus) {
      YieldStatusDto.withinThreshold => context.semantic.success,
      YieldStatusDto.below => context.semantic.warning,
      YieldStatusDto.above => context.colors.primary,
    };
    final verdictIcon = switch (event.yieldStatus) {
      YieldStatusDto.withinThreshold => Icons.check_circle_outline_rounded,
      YieldStatusDto.below => Icons.warning_amber_rounded,
      YieldStatusDto.above => Icons.trending_up_rounded,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        StockPreviewLine(
          label: AppStrings.outputLabel,
          value: AppStrings.outputValue(
            Fmt.quantity(recorded),
            event.sellableItemName,
          ),
          tone: context.semantic.success,
          icon: Icons.soup_kitchen_outlined,
        ),
        if (event.targetOutputQuantity != null) ...[
          const SizedBox(height: Insets.md),
          StockPreviewLine(
            label: AppStrings.targetQuantity,
            value: AppStrings.outputValue(
              Fmt.quantity(goal),
              event.sellableItemName,
            ),
            tone: context.colors.primary,
            icon: Icons.flag_outlined,
          ),
        ],
        const SizedBox(height: Insets.md),
        StockPreviewLine(
          label: verdictLabel,
          value: AppStrings.yieldVarianceLine(
            Fmt.quantity(recorded - goal),
            variancePct,
          ),
          tone: verdictTone,
          icon: verdictIcon,
        ),
        if (recorded != suggested) ...[
          const SizedBox(height: Insets.md),
          StockPreviewLine(
            label: AppStrings.suggestedWas(Fmt.quantity(suggested)),
            value: AppStrings.portionDiff(
              Fmt.quantity((recorded - suggested).abs()),
              recorded > suggested,
            ),
            tone: context.semantic.warning,
            icon: Icons.tune_rounded,
          ),
        ],
        const SizedBox(height: Insets.lg),
        Text(AppStrings.consumedSection, style: context.text.labelLarge),
        const SizedBox(height: Insets.sm),
        for (final component in event.components)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Insets.xs),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    component.rawMaterialName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodyMedium,
                  ),
                ),
                Text(
                  '${Fmt.quantity(_asDouble(component.quantityConsumed))} '
                  '${component.rawMaterialUnit}',
                  style: context.text.bodySmall?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: Insets.md),
        Text(
          AppStrings.recordedAt(
            Fmt.dayMonthTime(event.occurredAt.toLocal()),
          ),
          style: context.text.bodySmall?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Renders a backend decimal for display. The DTOs carry `Decimal`
/// (exact on the wire); screens only ever need the nearest double.
double _asDouble(Decimal value) => double.parse(value.toString());
