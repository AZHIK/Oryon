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

  final _target = TextEditingController();
  final _actual = TextEditingController();
  final _waste = TextEditingController();
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
    };
  }

  @override
  void dispose() {
    _target.dispose();
    _actual.dispose();
    _waste.dispose();
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

  bool get _recordValid => (parseQuantity(_actual.text) ?? 0) > 0;

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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppStrings.runFailed(message))),
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
          .createRun(recipeId: recipe.id, targetOutput: target);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _run = run;
        _seedMeasured(run);
        _step = 2;
      });
    } catch (e) {
      _fail(e);
    }
  }

  Future<void> _startRun() async {
    final run = _run;
    if (run == null || !_weighValid) return;
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
    final actual = parseQuantity(_actual.text);
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
      title: AppStrings.cookWizardTitle,
      width: kStockDialogWidth,
      actions: _actions,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _WizardHeader(step: _step + 1, total: _totalSteps, label: _stepLabel),
          const SizedBox(height: Insets.md),
          switch (_step) {
            0 => _RecipeStep(onPick: _pickRecipe),
            1 => _PlanStep(
                recipeName: _recipe?.name ?? _run?.recipeName ?? '',
                target: _target,
                onChanged: () => setState(() {}),
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
              ),
            _ => _ReviewStep(run: _run),
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

/// Step 1 — choose what to cook.
class _RecipeStep extends ConsumerWidget {
  const _RecipeStep({required this.onPick});

  final ValueChanged<RecipeDto> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Runs stock an output item, so only linked recipes can be cooked —
    // standalone formulas 422 server-side until linked to a menu item.
    final recipes = ref.watch(linkedRecipesProvider);
    if (recipes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: Insets.lg),
        child: Text(
          AppStrings.noRecipesYet,
          style: context.text.bodyMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          AppStrings.chooseRecipeHint,
          style: context.text.bodySmall?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
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
              title: Text(recipe.name),
              subtitle: Text(
                AppStrings.batchYieldLine(
                  Fmt.quantity(
                      double.parse(recipe.targetYieldQuantity.toString())),
                  recipe.targetYieldUnit,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => onPick(recipe),
            ),
          ),
      ],
    );
  }
}

/// Step 2 — how many to make. Planning moves no stock.
class _PlanStep extends StatelessWidget {
  const _PlanStep({
    required this.recipeName,
    required this.target,
    required this.onChanged,
  });

  final String recipeName;
  final TextEditingController target;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(recipeName, style: context.text.titleSmall),
        const SizedBox(height: Insets.md),
        LabeledFormField(
          label: AppStrings.howManyToday,
          helper: AppStrings.howManyTodayHint,
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
            decoration: const InputDecoration(hintText: '50'),
            onChanged: (_) => onChanged(),
          ),
        ),
      ],
    );
  }
}

/// Step 3 — weigh every line, then start (this deducts stock now).
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          AppStrings.startCookingHint,
          style: context.text.bodySmall?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: Insets.md),
        for (final line in components)
          _WeighLine(
            line: line,
            controller: measured[line.rawMaterialItemId],
            onHand: stockOf(line.rawMaterialItemId),
            onChanged: onChanged,
          ),
      ],
    );
  }
}

class _WeighLine extends StatelessWidget {
  const _WeighLine({
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
            color:
                short ? context.semantic.warning : context.semantic.success,
          ),
        ],
      ),
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
class _RecordStep extends StatelessWidget {
  const _RecordStep({
    required this.run,
    required this.actual,
    required this.waste,
    required this.onChanged,
  });

  final RunDto? run;
  final TextEditingController actual;
  final TextEditingController waste;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final target = run == null
        ? ''
        : Fmt.quantity(double.parse(run!.targetOutputQuantity.toString()));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          AppStrings.targetWasLine(target, run?.recipeName ?? ''),
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
            key: CookWizardKeys.actualField,
            controller: actual,
            autofocus: true,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
            ],
            onChanged: (_) => onChanged(),
          ),
        ),
        const SizedBox(height: Insets.lg),
        LabeledFormField(
          label: AppStrings.anythingLost,
          helper: AppStrings.anythingLostHint,
          child: TextFormField(
            key: CookWizardKeys.wasteField,
            controller: waste,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => onChanged(),
          ),
        ),
      ],
    );
  }
}

/// Step 6 — verify the numbers, then publish to POS & inventory.
class _ReviewStep extends StatelessWidget {
  const _ReviewStep({required this.run});

  final RunDto? run;

  @override
  Widget build(BuildContext context) {
    final target = run == null
        ? '—'
        : Fmt.quantity(double.parse(run!.targetOutputQuantity.toString()));
    final actual = run?.actualOutputQuantity == null
        ? '—'
        : Fmt.quantity(double.parse(run!.actualOutputQuantity.toString()));
    final verdict = switch (run?.yieldStatus) {
      YieldStatusDto.above => AppStrings.yieldAbove,
      YieldStatusDto.withinThreshold => AppStrings.yieldWithin,
      YieldStatusDto.below => AppStrings.yieldBelow,
      null => '',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          AppStrings.reviewPublishTitle,
          style: context.text.titleSmall,
        ),
        const SizedBox(height: Insets.md),
        _SummaryRow(label: run?.recipeName ?? '', value: '$target → $actual'),
        if (verdict.isNotEmpty)
          _SummaryRow(label: AppStrings.yieldLabel, value: verdict),
        if (run?.wasteReason != null && run!.wasteReason!.trim().isNotEmpty)
          _SummaryRow(label: AppStrings.wasteLabel, value: run!.wasteReason!),
        _SummaryRow(
          label: AppStrings.statusLabel,
          value: (run?.published ?? false)
              ? AppStrings.publishedBadge
              : AppStrings.awaitingPublish,
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
