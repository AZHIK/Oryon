import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/app_strings.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/production_provider.dart';
import '../../services/inventory_api_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/breakpoints.dart';
import '../../utils/formatters.dart';
import '../../widgets/labeled_form_field.dart';
import '../../widgets/responsive_form_dialog.dart';
import 'stock_dialog_shared.dart';

/// One guided cook: recipe → plan → weigh & start → cook → record →
/// review & publish, in a single dialog that never drops the cook.
///
/// The Production Zone keeps its cards (and their quick actions) for overview,
/// but every forward motion funnels through here: planning a batch,
/// weighing it, recording its output and publishing it are consecutive
/// steps of one journey with one progress header, not four disconnected
/// dialogs across three tabs. Reopening the wizard from a run card
/// resumes at that run's step, so an interrupted cook never loses its
/// place — the run, not the cook's memory, holds the state.
Future<void> showCookWizard(
  BuildContext context, {
  RecipeDto? recipe,
  RunDto? run,
}) {
  return showResponsiveFormDialog<void>(
    context,
    builder: (_) => _CookWizard(initialRecipe: recipe, initialRun: run),
  );
}

abstract final class CookWizardKeys {
  static const dialog = Key('cookWizard.dialog');
  static const targetField = Key('cookWizard.target');
  static const planContinue = Key('cookWizard.planContinue');
  static const wizardBack = Key('cookWizard.back');
  static const startCooking = Key('cookWizard.startCooking');
  static const recordNow = Key('cookWizard.recordNow');
  static const recordLater = Key('cookWizard.recordLater');
  static const actualField = Key('cookWizard.actual');
  static const wasteField = Key('cookWizard.waste');
  static const completeBatch = Key('cookWizard.complete');
  static const publish = Key('cookWizard.publish');
  static const close = Key('cookWizard.close');

  static Key pickRecipe(String recipeId) => Key('cookWizard.recipe.$recipeId');
}

class _CookWizard extends ConsumerStatefulWidget {
  const _CookWizard({this.initialRecipe, this.initialRun});

  final RecipeDto? initialRecipe;
  final RunDto? initialRun;

  @override
  ConsumerState<_CookWizard> createState() => _CookWizardState();
}

class _CookWizardState extends ConsumerState<_CookWizard> {
  static const int _totalSteps = 6;

  late int _step;
  RecipeDto? _recipe;
  RunDto? _run;
  ProductionEventDto? _published;
  bool _busy = false;
  // Simple words: how exact must this be? Normal / Exact / Relaxed.
  double _howExact = 5;
  // Simple words: use the plan number, or type what you really got?
  bool _usePlanNumber = true;

  final _target = TextEditingController();
  final _actual = TextEditingController();
  final _waste = TextEditingController();
  final _search = TextEditingController();
  final Map<String, TextEditingController> _measured = {};

  @override
  void initState() {
    super.initState();
    // A resumed run already knows its recipe — the name rides the run,
    // so no RecipeDto lookup is needed to continue it.
    _recipe = widget.initialRecipe;
    _run = widget.initialRun;
    _step = _entryStep;
    if (_run != null) _seedMeasured(_run!);
  }

  int get _entryStep {
    final run = _run;
    if (run == null) return _recipe == null ? 0 : 1;
    return switch (run.status) {
      RunStatusDto.pending => 2,
      RunStatusDto.inProgress => 3,
      RunStatusDto.completed => 5,
      RunStatusDto.cancelled => 0,
    };
  }

  @override
  void dispose() {
    _target.dispose();
    _actual.dispose();
    _waste.dispose();
    _search.dispose();
    for (final c in _measured.values) {
      c.dispose();
    }
    super.dispose();
  }

  String get _stepLabel => switch (_step) {
        0 => AppStrings.cookStepRecipe,
        1 => AppStrings.cookStepPlan,
        2 => AppStrings.cookStepWeigh,
        3 => AppStrings.cookStepCook,
        4 => AppStrings.cookStepRecord,
        _ => AppStrings.cookStepReview,
      };

  double? get _targetQty => parseQuantity(_target.text);

  double? _measuredOf(String id) => parseQuantity(_measured[id]?.text ?? '');

  bool get _planValid => (_targetQty ?? 0) > 0;

  bool get _weighValid {
    final run = _run;
    if (run == null || _measured.length != run.components.length) {
      return false;
    }
    for (final line in run.components) {
      final v = _measuredOf(line.rawMaterialItemId);
      if (v == null || v <= 0) return false;
    }
    return true;
  }

  bool get _recordValid {
    if (_usePlanNumber) return true;
    return (parseQuantity(_actual.text) ?? 0) > 0;
  }

  double _stockOf(String catalogItemId) {
    for (final item in ref.read(inventoryItemsListProvider)) {
      if (item.catalogItemId == catalogItemId) return item.stock;
    }
    return 0;
  }

  void _seedMeasured(RunDto run) {
    for (final c in _measured.values) {
      c.dispose();
    }
    _measured.clear();
    for (final line in run.components) {
      _measured[line.rawMaterialItemId] = TextEditingController(
        text: _plain(double.parse(line.plannedQuantity.toString())),
      );
    }
  }

  void _fail(Object e) {
    if (!mounted) return;
    setState(() => _busy = false);
    final message = e is InventoryApiException ? e.message : e.toString();
    final offline = message.toLowerCase().contains('socket') ||
        message.toLowerCase().contains('connection') ||
        message.toLowerCase().contains('timeout') ||
        message.toLowerCase().contains('network');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(offline ? AppStrings.noInternetCook : 'Could not save: $message'),
        action: SnackBarAction(label: AppStrings.tryAgain, onPressed: () {}),
      ),
    );
  }

  Future<void> _createRun() async {
    final recipe = _recipe;
    final target = _targetQty;
    if (recipe == null || target == null || target <= 0) return;
    setState(() => _busy = true);
    try {
      final run = await ref
          .read(productionRunsProvider.notifier)
          .createRun(recipeId: recipe.id, targetOutput: target, yieldTolerancePercent: _howExact);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _run = run;
        _seedMeasured(run);
        _actual.text = _plain(target);
        _usePlanNumber = true;
        _step = 2;
      });
    } catch (e) {
      _fail(e);
    }
  }

  Future<void> _startRun() async {
    final run = _run;
    if (run == null || !_weighValid) return;
    // Simple words: warn first when short, then cook anyway or stop.
    final shorts = <String>[
      for (final line in run.components)
        if ((_measuredOf(line.rawMaterialItemId) ?? 0) >
            _stockOf(line.rawMaterialItemId))
          '• ${line.rawMaterialName}',
    ];
    if (shorts.isNotEmpty && mounted) {
      final go = await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
          title: Text(AppStrings.notEnoughStockTitle),
          content: Text(AppStrings.notEnoughStockBody(shorts.join('\n'))),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(d).pop(false),
              child: Text(AppStrings.buyFirst),
            ),
            FilledButton(
              onPressed: () => Navigator.of(d).pop(true),
              child: Text(AppStrings.cookAnyway),
            ),
          ],
        ),
      );
      if (go != true || !mounted) return;
    }
    final leadingId = run.components.first.rawMaterialItemId;
    setState(() => _busy = true);
    try {
      final updated = await ref.read(productionRunsProvider.notifier).startRun(
            runId: run.id,
            leadingItemId: leadingId,
            leadingQuantity: _measuredOf(leadingId)!,
            measuredByItemId: {
              for (final line in run.components)
                line.rawMaterialItemId: _measuredOf(line.rawMaterialItemId)!,
            },
          );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _run = updated;
        _step = 3;
      });
    } catch (e) {
      _fail(e);
    }
  }

  Future<void> _completeRun() async {
    final run = _run;
    // Simple words: "Use plan number" means actual = plan. No blank magic.
    final actual = _usePlanNumber
        ? double.tryParse(run?.targetOutputQuantity.toString() ?? '')
        : parseQuantity(_actual.text);
    if (run == null || actual == null || actual <= 0) return;
    setState(() => _busy = true);
    try {
      final updated =
          await ref.read(productionRunsProvider.notifier).completeRun(
                runId: run.id,
                actualOutput: actual,
                wasteReason: _waste.text.trim().isEmpty ? null : _waste.text,
              );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _run = updated;
        _step = 5;
      });
    } catch (e) {
      _fail(e);
    }
  }

  Future<void> _publishRun() async {
    final run = _run;
    if (run == null) return;
    setState(() => _busy = true);
    try {
      final event = await ref
          .read(productionRunsProvider.notifier)
          .publishRun(runId: run.id);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _published = event;
      });
    } catch (e) {
      _fail(e);
    }
  }

  void _pickRecipe(RecipeDto recipe) {
    setState(() {
      _recipe = recipe;
      _step = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_published != null) return _donePage();
    return ResponsiveFormDialog(
      key: CookWizardKeys.dialog,
      title: 'Cook food',
      width: kStockDialogWidth,
      actions: _actions,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _WizardHeader(step: _step + 1, total: _totalSteps, label: _stepLabel),
          const SizedBox(height: Insets.md),
          switch (_step) {
            0 => _RecipeStep(
                onPick: _pickRecipe,
                search: _search,
                onSearch: () => setState(() {}),
              ),
            1 => _PlanStep(
                recipeName: _recipe?.name ?? _run?.recipeName ?? '',
                target: _target,
                onChanged: () => setState(() {}),
                howExact: _howExact,
                onExact: (v) => setState(() => _howExact = v),
                recipe: _recipe,
              ),
            2 => _WeighStep(
                run: _run,
                measured: _measured,
                stockOf: _stockOf,
                onChanged: () => setState(() {}),
              ),
            3 => const _CookStep(),
            4 => _RecordStep(
                run: _run,
                actual: _actual,
                waste: _waste,
                onChanged: () => setState(() {}),
                usePlan: _usePlanNumber,
                onUsePlan: (v) => setState(() => _usePlanNumber = v),
                recipe: _recipe,
              ),
            _ => _ReviewStep(run: _run, recipe: _recipe),
          },
        ],
      ),
    );
  }

  List<Widget> get _actions {
    final back = OutlinedButton(
      key: CookWizardKeys.wizardBack,
      onPressed: _busy
          ? null
          : () => setState(() => _step = switch (_step) {
                4 => 3,
                _ => _step - 1,
              }),
      child: Text(AppStrings.back),
    );
    switch (_step) {
      case 0:
        return [
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppStrings.cancel),
          ),
        ];
      case 1:
        return [
          back,
          FilledButton(
            key: CookWizardKeys.planContinue,
            onPressed: _busy || !_planValid ? null : _createRun,
            child: Text(AppStrings.continueAction),
          ),
        ];
      case 2:
        // The run already exists server-side from here on: no going back
        // to re-plan it — close and continue from the Production Zone instead.
        return [
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppStrings.illCookLater),
          ),
          FilledButton(
            key: CookWizardKeys.startCooking,
            onPressed: _busy || !_weighValid ? null : _startRun,
            child: Text(AppStrings.startRun),
          ),
        ];
      case 3:
        return [
          OutlinedButton(
            key: CookWizardKeys.recordLater,
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppStrings.illRecordLater),
          ),
          FilledButton(
            key: CookWizardKeys.recordNow,
            onPressed: () => setState(() => _step = 4),
            child: Text(AppStrings.recordOutputNow),
          ),
        ];
      case 4:
        return [
          back,
          FilledButton(
            key: CookWizardKeys.completeBatch,
            onPressed: _busy || !_recordValid ? null : _completeRun,
            child: Text(AppStrings.completeRun),
          ),
        ];
      default:
        final published = _run?.published ?? false;
        return [
          if (!published)
            FilledButton(
              key: CookWizardKeys.publish,
              onPressed: _busy ? null : _publishRun,
              child: Text(AppStrings.publishAction),
            ),
          FilledButton.tonal(
            key: CookWizardKeys.close,
            onPressed: () => Navigator.of(context).pop(),
            child: Text(published ? AppStrings.gotIt : AppStrings.cancel),
          ),
        ];
    }
  }

  Widget _donePage() {
    final event = _published!;
    final verdict = switch (event.yieldStatus) {
      YieldStatusDto.above => AppStrings.yieldAbove,
      YieldStatusDto.withinThreshold => AppStrings.yieldWithin,
      YieldStatusDto.below => AppStrings.yieldBelow,
    };
    return ResponsiveFormDialog(
      title: AppStrings.cookWizardTitle,
      width: kStockDialogWidth,
      actions: [
        FilledButton(
          key: CookWizardKeys.close,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppStrings.gotIt),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            size: 44,
            color: context.semantic.success,
          ),
          const SizedBox(height: Insets.md),
          Text(
            AppStrings.publishedTitle,
            style: context.text.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Insets.sm),
          Text(
            AppStrings.runPublishedVerdict(
              Fmt.quantity(
                  double.parse(event.actualOutputQuantity.toString())),
              event.sellableItemName,
              verdict,
            ),
            style: context.text.bodyMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Progress dots + "Step X of 6" + the step's name.
class _WizardHeader extends StatelessWidget {
  const _WizardHeader({
    required this.step,
    required this.total,
    required this.label,
  });

  final int step;
  final int total;
  final String label;

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
        const SizedBox(height: Insets.xs),
        Text(label, style: context.text.titleSmall),
      ],
    );
  }
}

/// Step 1 — choose what to cook. Simple search box on top.
class _RecipeStep extends ConsumerWidget {
  const _RecipeStep({required this.onPick, required this.search, required this.onSearch});

  final ValueChanged<RecipeDto> onPick;
  final TextEditingController search;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Runs stock an output item, so only linked recipes can be cooked —
    // standalone formulas 422 server-side until linked to a menu item.
    final all = ref.watch(linkedRecipesProvider);
    final q = search.text.trim().toLowerCase();
    final recipes = [
      for (final r in all)
        if (q.isEmpty || r.name.toLowerCase().contains(q)) r,
    ];
    if (all.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: Insets.lg),
        child: Text(
          AppStrings.askManagerCook,
          textAlign: TextAlign.center,
          style: context.text.bodyLarge?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextFormField(
          controller: search,
          decoration: InputDecoration(
            hintText: AppStrings.searchHint,
            prefixIcon: const Icon(Icons.search_rounded),
          ),
          onChanged: (_) => onSearch(),
        ),
        const SizedBox(height: Insets.md),
        Text(
          'What are we cooking?',
          style: context.text.bodyLarge,
        ),
        const SizedBox(height: Insets.md),
        for (final recipe in recipes)
          Card(
            margin: const EdgeInsets.only(bottom: Insets.sm),
            child: ListTile(
              key: CookWizardKeys.pickRecipe(recipe.id),
              leading: Icon(
                Icons.soup_kitchen_outlined,
                color: context.colors.primary,
              ),
              title: Text(recipe.name, style: context.text.bodyLarge),
              subtitle: Text(
                'Makes ${Fmt.quantity(double.parse(recipe.targetYieldQuantity.toString()))} ${recipe.targetYieldUnit} · ${Fmt.money(double.parse(recipe.costPerUnit.toString()))} each',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => onPick(recipe),
            ),
          ),
        if (recipes.isEmpty) const Text('Nothing found. Try another word.'),
      ],
    );
  }
}

/// Step 2 — how many to make. Planning moves no stock.
/// Simple words + how-exact picker + cost preview.
class _PlanStep extends StatelessWidget {
  const _PlanStep({
    required this.recipeName,
    required this.target,
    required this.onChanged,
    required this.howExact,
    required this.onExact,
    required this.recipe,
  });

  final String recipeName;
  final TextEditingController target;
  final VoidCallback onChanged;
  final double howExact;
  final ValueChanged<double> onExact;
  final RecipeDto? recipe;

  @override
  Widget build(BuildContext context) {
    final qty = parseQuantity(target.text) ?? 0;
    final each = recipe == null
        ? 0.0
        : double.parse(recipe!.costPerUnit.toString());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(recipeName, style: context.text.titleMedium),
        const SizedBox(height: Insets.md),
        LabeledFormField(
          label: 'How many do you need?',
          helper: 'Just the number — we work out the rest.',
          isRequired: true,
          child: TextFormField(
            key: CookWizardKeys.targetField,
            controller: target,
            autofocus: true,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
            ],
            style: Theme.of(context).textTheme.titleLarge,
            decoration: const InputDecoration(hintText: '50'),
            onChanged: (_) => onChanged(),
          ),
        ),
        const SizedBox(height: Insets.md),
        Text(AppStrings.howExact, style: context.text.bodyMedium),
        const SizedBox(height: Insets.xs),
        Wrap(
          spacing: Insets.sm,
          children: [
            for (final (label, value) in [
              (AppStrings.exactNormal, 5.0),
              (AppStrings.exactStrict, 2.0),
              (AppStrings.exactRelaxed, 10.0),
            ])
              FilterChip(
                label: Text(label),
                selected: howExact == value,
                onSelected: (_) => onExact(value),
              ),
          ],
        ),
        if (qty > 0 && each > 0) ...[
          const SizedBox(height: Insets.md),
          Text(
            'Cost for this batch: ${Fmt.money(each * qty)} (each one: ${Fmt.money(each)})',
            style: context.text.bodyMedium?.copyWith(
              color: context.semantic.success,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}

/// Step 3 — weigh every line, then start (this deducts stock now).
/// Uses the shared SimpleWeighLine: main item tagged, big text.
class _WeighStep extends StatelessWidget {
  const _WeighStep({
    required this.run,
    required this.measured,
    required this.stockOf,
    required this.onChanged,
  });

  final RunDto? run;
  final Map<String, TextEditingController> measured;
  final double Function(String catalogItemId) stockOf;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final components = run?.components ?? const <RunComponentDto>[];
    final mainId = components.isEmpty ? null : components.first.rawMaterialItemId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          AppStrings.mainItemLabel,
          style: context.text.bodySmall?.copyWith(
            color: context.colors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: Insets.md),
        for (final line in components)
          SimpleWeighLine(
            name: line.rawMaterialName,
            unit: line.rawMaterialUnit,
            controller: measured[line.rawMaterialItemId],
            onHand: stockOf(line.rawMaterialItemId),
            onChanged: onChanged,
            isMainItem: line.rawMaterialItemId == mainId,
          ),
      ],
    );
  }
}

/// Step 4 — the cooking wait: food needs hours; record now or later.
class _CookStep extends StatelessWidget {
  const _CookStep();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.soup_kitchen_outlined,
          size: 44,
          color: context.colors.primary,
        ),
        const SizedBox(height: Insets.md),
        Text(
          AppStrings.cookingTitle,
          style: context.text.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: Insets.sm),
        Text(
          AppStrings.cookingBody,
          style: context.text.bodyMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Step 5 — what came out of the pot, plus anything lost.
/// Simple words: two big buttons (Use plan number / Type real number),
/// live difference preview, loss quick-picks, cost preview.
class _RecordStep extends StatelessWidget {
  const _RecordStep({
    required this.run,
    required this.actual,
    required this.waste,
    required this.onChanged,
    required this.usePlan,
    required this.onUsePlan,
    required this.recipe,
  });

  final RunDto? run;
  final TextEditingController actual;
  final TextEditingController waste;
  final VoidCallback onChanged;
  final bool usePlan;
  final ValueChanged<bool> onUsePlan;
  final RecipeDto? recipe;

  @override
  Widget build(BuildContext context) {
    final target = run == null
        ? 0.0
        : double.parse(run!.targetOutputQuantity.toString());
    final typed = parseQuantity(actual.text) ?? target;
    final got = usePlan ? target : typed;
    final diff = got - target;
    final diffText = diff == 0
        ? 'Same as plan'
        : '${diff > 0 ? '+' : ''}${Fmt.quantity(diff)} vs plan';
    final each = recipe == null
        ? 0.0
        : double.parse(recipe!.costPerUnit.toString());
    const losses = ['Spilled', 'Burnt', 'Too much made', 'Taste bad'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Plan was ${Fmt.quantity(target)} × ${run?.recipeName ?? ''}',
          style: context.text.bodyLarge,
        ),
        const SizedBox(height: Insets.md),
        Row(
          children: [
            Expanded(
              child: FilterChip(
                label: Text(AppStrings.usePlanNumber),
                selected: usePlan,
                onSelected: (_) => onUsePlan(true),
              ),
            ),
            const SizedBox(width: Insets.sm),
            Expanded(
              child: FilterChip(
                label: Text(AppStrings.typeRealNumber),
                selected: !usePlan,
                onSelected: (_) => onUsePlan(false),
              ),
            ),
          ],
        ),
        if (!usePlan) ...[
          const SizedBox(height: Insets.md),
          LabeledFormField(
            label: 'How many did you get?',
            isRequired: true,
            child: TextFormField(
              key: CookWizardKeys.actualField,
              controller: actual,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
              ],
              style: Theme.of(context).textTheme.titleLarge,
              onChanged: (_) => onChanged(),
            ),
          ),
        ],
        const SizedBox(height: Insets.sm),
        Text(diffText, style: context.text.bodyMedium),
        if (each > 0 && got > 0)
          Text(
            'Worth about ${Fmt.money(each * got)}',
            style: context.text.bodyMedium?.copyWith(
              color: context.semantic.success,
              fontWeight: FontWeight.w700,
            ),
          ),
        const SizedBox(height: Insets.lg),
        Text(AppStrings.pickLossReason, style: context.text.bodyMedium),
        const SizedBox(height: Insets.xs),
        Wrap(
          spacing: Insets.sm,
          children: [
            for (final loss in losses)
              FilterChip(
                label: Text(loss),
                selected: waste.text == loss,
                onSelected: (_) {
                  waste.text = waste.text == loss ? '' : loss;
                  onChanged();
                },
              ),
          ],
        ),
      ],
    );
  }
}

/// Step 6 — check the numbers, then sell. Simple words + cost.
class _ReviewStep extends StatelessWidget {
  const _ReviewStep({required this.run, required this.recipe});

  final RunDto? run;
  final RecipeDto? recipe;

  @override
  Widget build(BuildContext context) {
    final target = run == null
        ? '—'
        : Fmt.quantity(double.parse(run!.targetOutputQuantity.toString()));
    final actual = run?.actualOutputQuantity == null
        ? '—'
        : Fmt.quantity(double.parse(run!.actualOutputQuantity.toString()));
    final verdict = switch (run?.yieldStatus) {
      YieldStatusDto.above => 'Got more than planned',
      YieldStatusDto.withinThreshold => 'Got what we planned',
      YieldStatusDto.below => 'Got less than planned',
      null => '',
    };
    final each = recipe == null
        ? 0.0
        : double.parse(recipe!.costPerUnit.toString());
    final gotQty = run?.actualOutputQuantity == null
        ? 0.0
        : double.parse(run!.actualOutputQuantity.toString());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Check, then sell',
          style: context.text.titleMedium,
        ),
        const SizedBox(height: Insets.md),
        _SummaryRow(label: run?.recipeName ?? '', value: '$target → $actual'),
        if (verdict.isNotEmpty)
          _SummaryRow(label: 'Result', value: verdict),
        if (each > 0 && gotQty > 0)
          _SummaryRow(
            label: 'Worth about',
            value: Fmt.money(each * gotQty),
          ),
        if (run?.wasteReason != null && run!.wasteReason!.trim().isNotEmpty)
          _SummaryRow(label: 'Lost', value: run!.wasteReason!),
        _SummaryRow(
          label: 'Now',
          value: (run?.published ?? false) ? 'Selling' : 'Wait to sell',
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Insets.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: context.text.bodyMedium,
            ),
          ),
          const SizedBox(width: Insets.md),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: context.text.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Display-plain number for prefilling: `10`, not `10.0`, never grouped.
String _plain(double value) =>
    value == value.roundToDouble() ? value.round().toString() : '$value';
