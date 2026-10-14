import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/app_strings.dart';
import '../../models/permission.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/permissions_provider.dart';
import '../../providers/production_provider.dart';
import '../../services/inventory_api_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/breakpoints.dart';
import '../../utils/formatters.dart';
import '../../widgets/labeled_form_field.dart';
import '../../widgets/responsive_form_dialog.dart';
import 'cook_wizard_dialog.dart';
import 'recipe_form_dialog.dart';
import 'stock_dialog_shared.dart';
import '../../utils/dialog_helper.dart';

/// The kitchen's Production Module, arranged as one left-to-right flow:
///
/// 1. Recipes (blueprints, rarely changed) → 2. Production Zone (today's
/// batches: plan, weigh, cook, record) → 3. Output (verify + publish).
///
/// The tabs are numbered journey stages, not separate sections — and the
/// module opens in the Production Zone, where the daily work happens.
/// Every forward motion runs inside the cook wizard; the tabs are for
/// overview and resume.
class ProductionModuleScreen extends ConsumerStatefulWidget {
  const ProductionModuleScreen({super.key});

  @override
  ConsumerState<ProductionModuleScreen> createState() =>
      _ProductionModuleScreenState();
}

abstract final class ProductionModuleKeys {
  static const recipesTab = Key('productionModule.recipesTab');
  static const runsTab = Key('productionModule.runsTab');
  static const outputTab = Key('productionModule.outputTab');
  static const newRun = Key('productionModule.newRun');
  static const addRecipe = Key('productionModule.addRecipe');
  static const runTarget = Key('productionModule.runTarget');
  static const runRecipe = Key('productionModule.runRecipe');
  static const planSubmit = Key('productionModule.planSubmit');
  static const runActual = Key('productionModule.runActual');
  static const runWaste = Key('productionModule.runWaste');
  static const completeSubmit = Key('productionModule.completeSubmit');
  static const startSubmit = Key('productionModule.startSubmit');

  static Key runCard(String runId) => Key('productionModule.runCard.$runId');
  static Key runStart(String runId) => Key('productionModule.runStart.$runId');
  static Key runComplete(String runId) =>
      Key('productionModule.runComplete.$runId');
  static Key runPublish(String runId) =>
      Key('productionModule.runPublish.$runId');
  static Key runContinue(String runId) =>
      Key('productionModule.runContinue.$runId');
  static Key runDelete(String runId) =>
      Key('productionModule.runDelete.$runId');
  static Key recipeCard(String recipeId) =>
      Key('productionModule.recipeCard.$recipeId');
  static const planSaved = Key('productionModule.planSaved');
  static const seeWhatToWeigh = Key('productionModule.seeWhatToWeigh');
  static const cookLater = Key('productionModule.cookLater');
  static const cookingDone = Key('productionModule.cookingDone');
}

/// One tab of the production journey: a stage number plus its name.
///
/// The numbers are the point — Recipes → Production Zone → Output reads as
/// a flow the cook walks left to right, not three unrelated sections.
class _FlowTab extends StatelessWidget {
  const _FlowTab({
    required this.number,
    required this.label,
    required this.active,
  });

  final int number;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active
                ? context.colors.primary
                : Colors.transparent,
            border: Border.all(
              color: active
                  ? context.colors.primary
                  : context.colors.onSurfaceVariant,
            ),
          ),
          child: Text(
            '$number',
            style: context.text.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: active
                  ? context.colors.onPrimary
                  : context.colors.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: Insets.xs),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// "Step X of Y" header with progress dots — every guided dialog shows
/// where the cook is in the journey, so nothing feels like a surprise.
class _StepsHeader extends StatelessWidget {
  const _StepsHeader({required this.step, required this.total});

  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 1; i <= total; i++)
              Container(
                margin: const EdgeInsets.only(right: Insets.xs),
                width: 24,
                height: 4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(Radii.pill),
                  color: i <= step
                      ? context.colors.primary
                      : context.semantic.hairline,
                ),
              ),
          ],
        ),
        const SizedBox(height: Insets.xs),
        Text(
          AppStrings.guidedStepOf(step, total),
          style: context.text.labelSmall?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Big friendly outcome page inside a dialog: what just happened, what to
/// do next, one button to leave. Cooking takes hours — the app says so.
class _DonePage extends StatelessWidget {
  const _DonePage({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 44, color: context.semantic.success),
        const SizedBox(height: Insets.md),
        Text(
          title,
          style: context.text.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: Insets.sm),
        Text(
          body,
          style: context.text.bodyMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _ProductionModuleScreenState extends ConsumerState<ProductionModuleScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    // The daily work happens in the Production Zone (index 1) — recipes
    // are set up once and rarely touched, so the module lands there.
    _tabs = TabController(length: 3, vsync: this, initialIndex: 1);
    _tabs.addListener(_syncFilterWithTab);
    // The FAB depends on the selected tab — rebuild as it changes.
    _tabs.addListener(_refreshAction);
  }

  void _refreshAction() {
    if (mounted) setState(() {});
  }

  /// The Output tab IS the completed filter — switching tabs keeps the two
  /// in agreement instead of fighting over the shared filter.
  void _syncFilterWithTab() {
    if (!_tabs.indexIsChanging) return;
    final filter = ref.read(productionRunStatusFilterProvider.notifier);
    if (_tabs.index == 2) {
      filter.set(RunStatusDto.completed);
    } else if (_tabs.index == 1 &&
        ref.read(productionRunStatusFilterProvider) ==
            RunStatusDto.completed) {
      filter.clear();
    }
  }

  @override
  void dispose() {
    _tabs.removeListener(_syncFilterWithTab);
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canProduce =
        ref.watch(hasPermissionProvider(AppPermissions.productionCreate));
    final canEditRecipes =
        ref.watch(hasPermissionProvider(AppPermissions.recipesCreate));

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.productionTitle),
        elevation: 0,
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(
              key: ProductionModuleKeys.recipesTab,
              child: _FlowTab(
                number: 1,
                label: AppStrings.recipesTab,
                active: _tabs.index == 0,
              ),
            ),
            Tab(
              key: ProductionModuleKeys.runsTab,
              child: _FlowTab(
                number: 2,
                label: AppStrings.productionZoneTab,
                active: _tabs.index == 1,
              ),
            ),
            Tab(
              key: ProductionModuleKeys.outputTab,
              child: _FlowTab(
                number: 3,
                label: AppStrings.outputTab,
                active: _tabs.index == 2,
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _tabs.index == 0
          ? (canEditRecipes
              ? FloatingActionButton.extended(
                  key: ProductionModuleKeys.addRecipe,
                  onPressed: () => showRecipeFormDialog(context),
                  icon: const Icon(Icons.add_rounded),
                  label: Text(AppStrings.addRecipe),
                )
              : null)
          : (canProduce
              ? FloatingActionButton.extended(
                  key: ProductionModuleKeys.newRun,
                  onPressed: () => showCookWizard(context),
                  icon: const Icon(Icons.add_rounded),
                  label: Text(AppStrings.newRun),
                )
              : null),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _RecipesTab(),
          _ProductionZoneTab(),
          _OutputTab(),
        ],
      ),
    );
  }

}

// ---------------------------------------------------------------------------
// Stage 1: Recipes (blueprints, rarely changed)
// ---------------------------------------------------------------------------

class _RecipesTab extends ConsumerWidget {
  const _RecipesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipes = ref.watch(recipesCatalogListProvider);
    final loading = ref.watch(recipesCatalogProvider).isLoading;

    return RefreshIndicator(
      onRefresh: () => ref.read(recipesCatalogProvider.notifier).refresh(),
      child: ListView(
        padding: const EdgeInsets.all(Insets.lg),
        children: [
          if (loading && recipes.isEmpty)
            const Center(child: CircularProgressIndicator()),
          for (final recipe in recipes) _RecipeCard(recipe: recipe),
          if (!loading && recipes.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Insets.xl),
                child: Text(
                  AppStrings.noRecipesYet,
                  style: context.text.bodyMedium?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RecipeCard extends ConsumerWidget {
  const _RecipeCard({required this.recipe});

  final RecipeDto recipe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canEdit =
        ref.watch(hasPermissionProvider(AppPermissions.recipesUpdate));
    final cost = double.parse(recipe.costPerUnit.toString());
    final batch = Fmt.quantity(double.parse(recipe.targetYieldQuantity.toString()));

    return Card(
      key: ProductionModuleKeys.recipeCard(recipe.id),
      margin: const EdgeInsets.only(bottom: Insets.md),
      child: InkWell(
        borderRadius: Radii.card,
        onTap: canEdit
            ? () => showRecipeFormDialog(context, recipe: recipe)
            : null,
        child: Padding(
          padding: const EdgeInsets.all(Insets.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      recipe.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleSmall,
                    ),
                  ),
                  if (recipe.category != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Insets.sm,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: context.colors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(Radii.pill),
                      ),
                      child: Text(
                        AppStrings.recipeCategoryName(recipe.category!),
                        style: context.text.labelSmall,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: Insets.xs),
              Text(
                '${AppStrings.batchYieldLine(batch, recipe.targetYieldUnit)}'
                ' · ${recipe.sellableItemName ?? AppStrings.recipeUnlinkedBadge}'
                ' · ${recipe.components.length} lines',
                style: context.text.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Insets.xs),
              Text(
                '${AppStrings.costPerUnit(Fmt.money(cost))}'
                '${recipe.costComplete ? '' : ' ${AppStrings.costEstimated}'}',
                style: context.text.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: recipe.costComplete
                      ? context.semantic.success
                      : context.semantic.warning,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stage 2: Production Zone (today's batches)
// ---------------------------------------------------------------------------

class _ProductionZoneTab extends ConsumerWidget {
  const _ProductionZoneTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runs = ref.watch(productionRunsListProvider);
    final loading = ref.watch(productionRunsProvider).isLoading;
    final filter = ref.watch(productionRunStatusFilterProvider);
    final canProduce =
        ref.watch(hasPermissionProvider(AppPermissions.productionCreate));

    Widget chip(String label, RunStatusDto? status) {
      final selected = filter == status;
      return Padding(
        padding: const EdgeInsets.only(right: Insets.sm),
        child: FilterChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => ref
              .read(productionRunStatusFilterProvider.notifier)
              .set(selected ? null : status),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(productionRunsProvider.notifier).refresh(),
      child: ListView(
        padding: const EdgeInsets.all(Insets.lg),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                chip(AppStrings.allFilter, null),
                chip(AppStrings.pendingBadge, RunStatusDto.pending),
                chip(AppStrings.inProgressBadge, RunStatusDto.inProgress),
                chip(AppStrings.completedBadge, RunStatusDto.completed),
              ],
            ),
          ),
          const SizedBox(height: Insets.md),
          if (loading && runs.isEmpty)
            const Center(child: CircularProgressIndicator()),
          for (final run in runs)
            _RunCard(run: run, canProduce: canProduce),
          if (!loading && runs.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Insets.xl),
                child: Column(
                  children: [
                    Text(
                      AppStrings.noRunsYetFilter,
                      style: context.text.bodyMedium?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: Insets.xs),
                    Text(
                      AppStrings.scheduleFirstRun,
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
    );
  }
}

class _RunCard extends ConsumerWidget {
  const _RunCard({required this.run, required this.canProduce});

  final RunDto run;
  final bool canProduce;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final target = Fmt.quantity(double.parse(run.targetOutputQuantity.toString()));
    final (badge, tone) = switch (run.status) {
      RunStatusDto.pending => (AppStrings.pendingBadge, context.colors.primary),
      RunStatusDto.inProgress =>
        (AppStrings.inProgressBadge, context.semantic.warning),
      RunStatusDto.completed =>
        (AppStrings.completedBadge, context.semantic.success),
    };

    return Card(
      key: ProductionModuleKeys.runCard(run.id),
      margin: const EdgeInsets.only(bottom: Insets.md),
      child: Padding(
        padding: const EdgeInsets.all(Insets.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    run.recipeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleSmall,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Insets.sm,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: tone.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(Radii.pill),
                  ),
                  child: Text(
                    badge,
                    style: context.text.labelSmall?.copyWith(
                      color: tone,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Insets.xs),
            Text(
              _nextAction(context, run, target),
              style: context.text.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            if (run.status == RunStatusDto.completed &&
                run.yieldStatus != null) ...[
              const SizedBox(height: Insets.xs),
              _YieldLine(run: run),
            ],
            if (canProduce) ...[
              const SizedBox(height: Insets.sm),
              Wrap(
                spacing: Insets.sm,
                children: [
                  if (run.status == RunStatusDto.pending) ...[
                    FilledButton.tonal(
                      key: ProductionModuleKeys.runStart(run.id),
                      onPressed: () => showResponsiveFormDialog<void>(
                        context,
                        builder: (_) => _StartRunDialog(run: run),
                      ),
                      child: Text(AppStrings.startRun),
                    ),
                    TextButton(
                      key: ProductionModuleKeys.runDelete(run.id),
                      onPressed: () => _confirmDelete(context, ref),
                      child: Text(AppStrings.deleteAction),
                    ),
                  ],
                  if (run.status == RunStatusDto.inProgress)
                    FilledButton.tonal(
                      key: ProductionModuleKeys.runComplete(run.id),
                      onPressed: () => showResponsiveFormDialog<void>(
                        context,
                        builder: (_) => _CompleteRunDialog(run: run),
                      ),
                      child: Text(AppStrings.completeRun),
                    ),
                  // Guided path: resumes the cook wizard at this run's
                  // step (weigh → cook → record → publish in one place).
                  TextButton(
                    key: ProductionModuleKeys.runContinue(run.id),
                    onPressed: () => showCookWizard(context, run: run),
                    child: Text(AppStrings.continueAction),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// What the cook should do next, in plain words — the card's job is
  /// guidance, not just status.
  String _nextAction(BuildContext context, RunDto run, String target) {
    final base = '$target × ${run.sellableItemName}';
    return switch (run.status) {
      RunStatusDto.pending => AppStrings.plannedNext(target, run.sellableItemName),
      RunStatusDto.inProgress => run.startedAt == null
          ? '$base · tap Record output when done'
          : AppStrings.cookingNext(
              Fmt.dayMonthTime(run.startedAt!.toLocal())),
      RunStatusDto.completed => run.published
          ? '$base · ${AppStrings.publishedBadge}'
          : '$base · verify on the ${AppStrings.outputTab} tab',
    };
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppStrings.deleteRunTitle),
        content: Text(AppStrings.deleteRunBody(
          run.recipeName,
          Fmt.quantity(double.parse(run.targetOutputQuantity.toString())),
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(AppStrings.keepAction),
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
      await ref.read(productionRunsProvider.notifier).deleteRun(run.id);
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(AppStrings.runDeletedLine(run.recipeName))),
      );
    } catch (e) {
      if (!context.mounted) return;
      final message = e is InventoryApiException ? e.message : e.toString();
      messenger.showSnackBar(
          SnackBar(content: Text(AppStrings.runFailed(message))));
    }
  }
}

class _YieldLine extends StatelessWidget {
  const _YieldLine({required this.run});

  final RunDto run;

  @override
  Widget build(BuildContext context) {
    final label = switch (run.yieldStatus) {
      YieldStatusDto.above => AppStrings.yieldAbove,
      YieldStatusDto.withinThreshold => AppStrings.yieldWithin,
      YieldStatusDto.below => AppStrings.yieldBelow,
      null => '',
    };
    final tone = switch (run.yieldStatus) {
      YieldStatusDto.withinThreshold => context.semantic.success,
      YieldStatusDto.below => context.semantic.warning,
      _ => context.colors.primary,
    };
    return Text(
      label,
      style: context.text.bodySmall?.copyWith(
        color: tone,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

/// Start dialog: every planned line weighed, each adjustable.
class _StartRunDialog extends ConsumerStatefulWidget {
  const _StartRunDialog({required this.run});

  final RunDto run;

  @override
  ConsumerState<_StartRunDialog> createState() => _StartRunDialogState();
}

class _StartRunDialogState extends ConsumerState<_StartRunDialog> {
  final Map<String, TextEditingController> _ctrls = {};
  bool _submitting = false;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    for (final line in widget.run.components) {
      _ctrls[line.rawMaterialItemId] = TextEditingController(
        text: _plain(double.parse(line.plannedQuantity.toString())),
      );
    }
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  double? _of(String id) => parseQuantity(_ctrls[id]?.text ?? '');

  bool get _valid {
    if (_ctrls.length != widget.run.components.length) return false;
    for (final line in widget.run.components) {
      final v = _of(line.rawMaterialItemId);
      if (v == null || v <= 0) return false;
    }
    return true;
  }

  double _stockOf(String catalogItemId) {
    for (final item in ref.read(inventoryItemsListProvider)) {
      if (item.catalogItemId == catalogItemId) return item.stock;
    }
    return 0;
  }

  Future<void> _submit() async {
    final messenger = ScaffoldMessenger.of(context);
    if (!_valid) return;
    final leadingId = widget.run.components.first.rawMaterialItemId;
    final leadingQty = _of(leadingId);
    if (leadingQty == null || leadingQty <= 0) return;
    setState(() => _submitting = true);
    try {
      await ref.read(productionRunsProvider.notifier).startRun(
            runId: widget.run.id,
            leadingItemId: leadingId,
            leadingQuantity: leadingQty,
            measuredByItemId: {
              for (final line in widget.run.components)
                line.rawMaterialItemId: _of(line.rawMaterialItemId)!,
            },
          );
      if (!mounted) return;
      // Stay open: say plainly that the food needs hours and where to
      // finish — the most common confusion in this flow.
      setState(() {
        _submitting = false;
        _started = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      final message = e is InventoryApiException ? e.message : e.toString();
      messenger.showSnackBar(
          SnackBar(content: Text(AppStrings.runFailed(message))));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_started) {
      return ResponsiveFormDialog(
        key: ProductionModuleKeys.cookingDone,
        title: AppStrings.startRunTitle,
        width: kStockDialogWidth,
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppStrings.gotIt),
          ),
        ],
        child: _DonePage(
          icon: Icons.soup_kitchen_outlined,
          title: AppStrings.cookingTitle,
          body: AppStrings.cookingBody,
        ),
      );
    }
    return ResponsiveFormDialog(
      title: AppStrings.weighAndStart,
      width: kStockDialogWidth,
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppStrings.cancel),
        ),
        FilledButton(
          key: ProductionModuleKeys.startSubmit,
          onPressed: _submitting || !_valid ? null : _submit,
          child: Text(AppStrings.startRun),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const _StepsHeader(step: 2, total: 3),
          const SizedBox(height: Insets.sm),
          Text(
            AppStrings.startCookingHint,
            style: context.text.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Insets.md),
          for (final line in widget.run.components)
            _MeasuredLine(
              line: line,
              controller: _ctrls[line.rawMaterialItemId],
              onHand: _stockOf(line.rawMaterialItemId),
              onChanged: () => setState(() {}),
            ),
        ],
      ),
    );
  }
}

class _MeasuredLine extends StatelessWidget {
  const _MeasuredLine({
    required this.line,
    required this.controller,
    required this.onHand,
    required this.onChanged,
  });

  final RunComponentDto line;
  final TextEditingController? controller;
  final double onHand;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final needed = parseQuantity(controller?.text ?? '') ?? 0;
    final short = needed > onHand;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Insets.xs),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.rawMaterialName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodyMedium,
                ),
                Text(
                  AppStrings.consumptionLine(
                    Fmt.quantity(onHand),
                    line.rawMaterialUnit,
                    'in stock',
                  ),
                  style: context.text.bodySmall?.copyWith(
                    color: short
                        ? context.semantic.warning
                        : context.colors.onSurfaceVariant,
                    fontWeight: short ? FontWeight.w700 : null,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: Insets.sm),
          SizedBox(
            width: 130,
            child: TextFormField(
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
              ],
              decoration: InputDecoration(
                suffixText: line.rawMaterialUnit,
                isDense: true,
              ),
              onChanged: (_) => onChanged(),
            ),
          ),
          const SizedBox(width: Insets.sm),
          Icon(
            short
                ? Icons.warning_amber_rounded
                : Icons.check_circle_outline_rounded,
            size: 16,
            color: short ? context.semantic.warning : context.semantic.success,
          ),
        ],
      ),
    );
  }
}

/// Complete dialog: actual yield + optional waste/variance reason.
class _CompleteRunDialog extends ConsumerStatefulWidget {
  const _CompleteRunDialog({required this.run});

  final RunDto run;

  @override
  ConsumerState<_CompleteRunDialog> createState() => _CompleteRunDialogState();
}

class _CompleteRunDialogState extends ConsumerState<_CompleteRunDialog> {
  late final TextEditingController _actual;
  final _waste = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _actual = TextEditingController(
      text: _plain(double.parse(widget.run.targetOutputQuantity.toString())),
    );
  }

  @override
  void dispose() {
    _actual.dispose();
    _waste.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final messenger = ScaffoldMessenger.of(context);
    final actual = parseQuantity(_actual.text);
    if (actual == null || actual <= 0) return;
    setState(() => _submitting = true);
    try {
      await ref.read(productionRunsProvider.notifier).completeRun(
            runId: widget.run.id,
            actualOutput: actual,
            wasteReason: _waste.text.trim().isEmpty ? null : _waste.text,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            AppStrings.savedVerify(
              Fmt.quantity(actual),
              widget.run.recipeName,
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      final message = e is InventoryApiException ? e.message : e.toString();
      messenger.showSnackBar(
          SnackBar(content: Text(AppStrings.runFailed(message))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final valid = (parseQuantity(_actual.text) ?? 0) > 0;
    final target =
        Fmt.quantity(double.parse(widget.run.targetOutputQuantity.toString()));
    return ResponsiveFormDialog(
      title: AppStrings.welcomeBack,
      width: kStockDialogWidth,
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppStrings.cancel),
        ),
        FilledButton(
          key: ProductionModuleKeys.completeSubmit,
          onPressed: _submitting || !valid ? null : _submit,
          child: Text(AppStrings.completeRun),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const _StepsHeader(step: 3, total: 3),
          const SizedBox(height: Insets.sm),
          Text(
            AppStrings.targetWasLine(target, widget.run.recipeName),
            style: context.text.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Insets.md),
          LabeledFormField(
            label: AppStrings.howManyGot,
            helper: AppStrings.actualYieldHint,
            isRequired: true,
            child: TextFormField(
              key: ProductionModuleKeys.runActual,
              controller: _actual,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
              ],
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: Insets.lg),
          LabeledFormField(
            label: AppStrings.anythingLost,
            helper: AppStrings.anythingLostHint,
            child: TextFormField(
              key: ProductionModuleKeys.runWaste,
              controller: _waste,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stage 3: Output & publish
// ---------------------------------------------------------------------------

class _OutputTab extends ConsumerWidget {
  const _OutputTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The tab switch already scoped the shared filter to completed; the
    // local filter below is a backstop, never a second fetch.
    final runs = [
      for (final r in ref.watch(productionRunsListProvider))
        if (r.status == RunStatusDto.completed) r,
    ];
    final loading = ref.watch(productionRunsProvider).isLoading;
    final canProduce =
        ref.watch(hasPermissionProvider(AppPermissions.productionCreate));

    return RefreshIndicator(
      onRefresh: () => ref.read(productionRunsProvider.notifier).refresh(),
      child: ListView(
        padding: const EdgeInsets.all(Insets.lg),
        children: [
          Text(
            AppStrings.verifyQueueHint,
            style: context.text.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Insets.md),
          if (loading && runs.isEmpty)
            const Center(child: CircularProgressIndicator()),
          for (final run in runs)
            _OutputCard(run: run, canProduce: canProduce),
          if (!loading && runs.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Insets.xl),
                child: Text(
                  AppStrings.noRunsYetFilter,
                  style: context.text.bodyMedium?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _OutputCard extends ConsumerStatefulWidget {
  const _OutputCard({required this.run, required this.canProduce});

  final RunDto run;
  final bool canProduce;

  @override
  ConsumerState<_OutputCard> createState() => _OutputCardState();
}

class _OutputCardState extends ConsumerState<_OutputCard> {
  bool _publishing = false;

  Future<void> _publish() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _publishing = true);
    try {
      final event = await ref
          .read(productionRunsProvider.notifier)
          .publishRun(runId: widget.run.id);
      if (!mounted) return;
      setState(() => _publishing = false);
      final verdict = switch (event.yieldStatus) {
        YieldStatusDto.above => AppStrings.yieldAbove,
        YieldStatusDto.withinThreshold => AppStrings.yieldWithin,
        YieldStatusDto.below => AppStrings.yieldBelow,
      };
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            AppStrings.runPublishedVerdict(
              Fmt.quantity(
                  double.parse(event.actualOutputQuantity.toString())),
              event.sellableItemName,
              verdict,
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _publishing = false);
      final message = e is InventoryApiException ? e.message : e.toString();
      messenger.showSnackBar(
          SnackBar(content: Text(AppStrings.runFailed(message))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final run = widget.run;
    final target =
        Fmt.quantity(double.parse(run.targetOutputQuantity.toString()));
    final actual = run.actualOutputQuantity == null
        ? '—'
        : Fmt.quantity(double.parse(run.actualOutputQuantity.toString()));

    return Card(
      key: ProductionModuleKeys.runCard('output-${run.id}'),
      margin: const EdgeInsets.only(bottom: Insets.md),
      child: Padding(
        padding: const EdgeInsets.all(Insets.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    run.recipeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleSmall,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Insets.sm,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: (run.published
                            ? context.semantic.success
                            : context.semantic.warning)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(Radii.pill),
                  ),
                  child: Text(
                    run.published
                        ? AppStrings.publishedBadge
                        : AppStrings.awaitingPublish,
                    style: context.text.labelSmall?.copyWith(
                      color: run.published
                          ? context.semantic.success
                          : context.semantic.warning,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Insets.xs),
            Text(
              'Target $target × ${run.sellableItemName} · achieved $actual',
              style: context.text.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            if (run.yieldStatus != null) ...[
              const SizedBox(height: Insets.xs),
              _YieldLine(run: run),
            ],
            if (run.wasteReason != null &&
                run.wasteReason!.trim().isNotEmpty) ...[
              const SizedBox(height: Insets.xs),
              Row(
                children: [
                  Icon(
                    Icons.delete_outline_rounded,
                    size: 16,
                    color: context.semantic.warning,
                  ),
                  const SizedBox(width: Insets.xs),
                  Expanded(
                    child: Text(
                      run.wasteReason!,
                      style: context.text.bodySmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (widget.canProduce && !run.published) ...[
              const SizedBox(height: Insets.sm),
              FilledButton.icon(
                key: ProductionModuleKeys.runPublish(run.id),
                onPressed: _publishing ? null : _publish,
                icon: const Icon(Icons.publish_rounded, size: 18),
                label: Text(AppStrings.publishAction),
              ),
              const SizedBox(height: Insets.xs),
              TextButton(
                key: ProductionModuleKeys.runContinue(run.id),
                onPressed: () => showCookWizard(context, run: run),
                child: Text(AppStrings.continueAction),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Display-plain number for prefilling: `10`, not `10.0`, never grouped.
String _plain(double value) =>
    value == value.roundToDouble() ? value.round().toString() : '$value';
