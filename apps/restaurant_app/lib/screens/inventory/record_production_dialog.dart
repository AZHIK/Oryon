import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/inventory_provider.dart';
import '../../constants/app_strings.dart';
import '../../providers/production_provider.dart';
import '../../services/inventory_api_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/breakpoints.dart';
import '../../utils/formatters.dart';
import '../../widgets/labeled_form_field.dart';
import '../../widgets/responsive_form_dialog.dart';
import 'stock_dialog_shared.dart';

/// Opens the target-based record-production dialog for [recipe].
///
/// Three steps: (1) how many products are needed — the target; (2) measure
/// every recommended grocery amount, adjusting any line; (3) after cooking,
/// confirm the amount actually achieved and see the above / within / below
/// threshold verdict computed server-side.
Future<void> showRecordProductionDialog(
  BuildContext context,
  RecipeDto recipe,
) {
  return showResponsiveFormDialog<void>(
    context,
    builder: (_) => RecordProductionDialog(recipe: recipe),
  );
}

/// Widget keys for the dialog's controls. Same rationale as [StockDialogKeys]:
/// labels sit outside the inputs, so tests find fields by key, not copy.
abstract final class ProductionDialogKeys {
  static const targetQty = Key('productionDialog.targetQty');
  static const tolerance = Key('productionDialog.tolerance');
  static const toMeasure = Key('productionDialog.toMeasure');
  static const leading = Key('productionDialog.leading');
  static const leadingQty = Key('productionDialog.leadingQty');
  static const toConfirm = Key('productionDialog.toConfirm');
  static const actualQty = Key('productionDialog.actualQty');
  static const finishLater = Key('productionDialog.finishLater');
  static const cancel = Key('productionDialog.cancel');
  static const submit = Key('productionDialog.submit');
  static const done = Key('productionDialog.done');

  /// Key for the adjustable field of ingredient [rawMaterialItemId].
  static Key ingredientQty(String rawMaterialItemId) =>
      Key('productionDialog.ingredientQty.$rawMaterialItemId');
}

enum _Step { target, measure, confirm }

class RecordProductionDialog extends ConsumerStatefulWidget {
  const RecordProductionDialog({super.key, required this.recipe});

  final RecipeDto recipe;

  @override
  ConsumerState<RecordProductionDialog> createState() =>
      _RecordProductionDialogState();
}

class _RecordProductionDialogState
    extends ConsumerState<RecordProductionDialog> {
  final _targetCtrl = TextEditingController();
  final _toleranceCtrl = TextEditingController(text: '5');
  final _actualCtrl = TextEditingController();
  final Map<String, TextEditingController> _measuredCtrls = {};

  _Step _step = _Step.target;
  bool _planning = false;
  bool _submitting = false;
  bool _actualEdited = false;
  ProductionEventDto? _result;

  @override
  void dispose() {
    _targetCtrl.dispose();
    _toleranceCtrl.dispose();
    _actualCtrl.dispose();
    for (final c in _measuredCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  double? get _target => parseQuantity(_targetCtrl.text);
  double? get _tolerance => parseQuantity(_toleranceCtrl.text);

  double? _measuredOf(String itemId) {
    final ctrl = _measuredCtrls[itemId];
    if (ctrl == null) return null;
    return parseQuantity(ctrl.text);
  }

  double? get _actualAmount {
    final trimmed = _actualCtrl.text.trim();
    // Blank means "plan held" — the server commits the target, so an empty
    // field is valid input, not a missing one.
    if (trimmed.isEmpty) return null;
    return parseQuantity(_actualCtrl.text);
  }

  /// The confirmed output that will be sent: typed value or the target.
  double? get _effectiveActual {
    final actual = _actualAmount ?? _target;
    if (actual == null || actual <= 0) return null;
    return actual;
  }

  bool get _targetValid => _target != null && _target! > 0;

  bool get _toleranceValid {
    final t = _tolerance;
    return t != null && t >= 0 && t <= 100;
  }

  bool get _measuredValid {
    if (_measuredCtrls.length != widget.recipe.components.length) return false;
    for (final component in widget.recipe.components) {
      final v = _measuredOf(component.rawMaterialItemId);
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

  /// Seed the adjustable fields from the plan (`requirement × target`),
  /// then ask the server for its authoritative recommendation and adopt
  /// any line the cook has not touched yet (controllers are all fresh at
  /// this point, so the server wins where it answers).
  Future<void> _goToMeasure() async {
    final target = _target;
    if (target == null || target <= 0) return;
    final planned = ProductionPreview.plannedForTarget(
      recipe: widget.recipe,
      target: target,
    );
    for (final component in widget.recipe.components) {
      final id = component.rawMaterialItemId;
      _measuredCtrls[id]?.dispose();
      _measuredCtrls[id] = TextEditingController(
        text: _plain(planned[id] ?? 0),
      );
    }
    setState(() {
      _step = _Step.measure;
      _planning = true;
    });
    try {
      final plan = await ref
          .read(productionHistoryProvider.notifier)
          .planProduction(recipeId: widget.recipe.id, targetOutput: target);
      if (!mounted) return;
      for (final line in plan.components) {
        final ctrl = _measuredCtrls[line.rawMaterialItemId];
        if (ctrl != null) {
          ctrl.text = _plain(double.parse(line.plannedQuantity.toString()));
        }
      }
    } catch (_) {
      // Local math mirrors the server (`requirement × target`), so the
      // seeded values stand when the plan call cannot be reached.
    } finally {
      if (mounted) setState(() => _planning = false);
    }
  }

  void _goToConfirm() {
    final target = _target;
    if (target == null) return;
    if (!_actualEdited) _actualCtrl.text = _plain(target);
    setState(() => _step = _Step.confirm);
  }

  /// Local preview of the verdict (the server decides authoritatively on
  /// submit): above / within / below the ±tolerance band around the target.
  ({String label, bool good, bool bad})? get _verdictPreview {
    final target = _target;
    final actual = _effectiveActual;
    final tol = _tolerance ?? 5;
    if (target == null || target <= 0 || actual == null) return null;
    final variancePct = (actual - target) / target * 100;
    if (variancePct.abs() <= tol) {
      return (label: AppStrings.yieldWithin, good: true, bad: false);
    }
    if (variancePct > 0) {
      return (label: AppStrings.yieldAbove, good: false, bad: false);
    }
    return (label: AppStrings.yieldBelow, good: false, bad: true);
  }

  Future<void> _submit() async {
    final messenger = ScaffoldMessenger.of(context);
    final target = _target;
    final actual = _effectiveActual;
    if (target == null || actual == null || !_measuredValid) return;

    // The leading ingredient anchors the ratio/audit: the first recipe line.
    final leadingId = widget.recipe.components.first.rawMaterialItemId;
    final leadingQty = _measuredOf(leadingId);
    if (leadingQty == null || leadingQty <= 0) return;

    setState(() => _submitting = true);
    try {
      final event =
          await ref.read(productionHistoryProvider.notifier).recordProduction(
                recipeId: widget.recipe.id,
                leadingItemId: leadingId,
                leadingQuantity: leadingQty,
                targetOutput: target,
                measuredByItemId: {
                  for (final component in widget.recipe.components)
                    component.rawMaterialItemId:
                        _measuredOf(component.rawMaterialItemId)!,
                },
                actualOutput:
                    _actualCtrl.text.trim().isEmpty ? null : actual,
                yieldTolerancePercent: _tolerance,
              );
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _result = event;
      });
    } catch (e) {
      // Backend messages are written for owners ("Insufficient stock for
      // 'Meat'..."), so they go on the snackbar verbatim rather than behind
      // a generic "something went wrong".
      if (!mounted) return;
      setState(() => _submitting = false);
      final message = e is InventoryApiException ? e.message : e.toString();
      messenger.showSnackBar(
        SnackBar(content: Text(AppStrings.recordFailed(message))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final recipe = widget.recipe;
    return ResponsiveFormDialog(
      title: AppStrings.recordProductionTitle,
      width: kStockDialogWidth,
      actions: _actions,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _RecipeContext(recipe: recipe),
          const SizedBox(height: Insets.xl),
          if (_result != null)
            _VerdictPanel(event: _result!)
          else
            switch (_step) {
              _Step.target => _TargetStep(
                  targetCtrl: _targetCtrl,
                  toleranceCtrl: _toleranceCtrl,
                  targetValid: _targetValid,
                  toleranceValid: _toleranceValid,
                  onChanged: () => setState(() {}),
                ),
              _Step.measure => _MeasureStep(
                  recipe: recipe,
                  ctrls: _measuredCtrls,
                  planning: _planning,
                  stockOf: _stockOf,
                  onChanged: () => setState(() {}),
                ),
              _Step.confirm => _ConfirmStep(
                  recipe: recipe,
                  target: _target ?? 0,
                  measured: {
                    for (final c in recipe.components)
                      c.rawMaterialItemId:
                          _measuredOf(c.rawMaterialItemId) ?? 0,
                  },
                  actualCtrl: _actualCtrl,
                  verdict: _verdictPreview,
                  onActualChanged: (v) {
                    _actualEdited = v.trim().isNotEmpty;
                    setState(() {});
                  },
                ),
            },
        ],
      ),
    );
  }

  List<Widget> get _actions {
    if (_result != null) {
      return [
        FilledButton(
          key: ProductionDialogKeys.done,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ];
    }
    switch (_step) {
      case _Step.target:
        return [
          OutlinedButton(
            key: ProductionDialogKeys.cancel,
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppStrings.cancel),
          ),
          FilledButton(
            key: ProductionDialogKeys.toMeasure,
            onPressed:
                _targetValid && _toleranceValid && !_planning ? _goToMeasure : null,
            child: Text(AppStrings.continueToMeasure),
          ),
        ];
      case _Step.measure:
        return [
          OutlinedButton(
            key: ProductionDialogKeys.cancel,
            onPressed: () => setState(() => _step = _Step.target),
            child: Text(AppStrings.backToTarget),
          ),
          FilledButton(
            key: ProductionDialogKeys.toConfirm,
            onPressed: _measuredValid && !_planning ? _goToConfirm : null,
            child: Text(AppStrings.continueToConfirm),
          ),
        ];
      case _Step.confirm:
        return [
          OutlinedButton(
            key: ProductionDialogKeys.cancel,
            onPressed:
                _submitting ? null : () => setState(() => _step = _Step.measure),
            child: Text(AppStrings.backToTarget),
          ),
          TextButton(
            key: ProductionDialogKeys.finishLater,
            onPressed: _submitting || !_measuredValid ? null : _finishLater,
            child: Text(AppStrings.finishLater),
          ),
          FilledButton(
            key: ProductionDialogKeys.submit,
            onPressed: _submitting || !_measuredValid ? null : _submit,
            child: Text(AppStrings.confirmAchieved),
          ),
        ];
    }
  }

  /// Cooking takes hours — save the weighed plan as a run and record the
  /// output later instead of confirming now. The run starts immediately
  /// (ingredients leave stock, as the cook is about to use them) and waits
  /// on the Runs tab for its actual yield.
  Future<void> _finishLater() async {
    final messenger = ScaffoldMessenger.of(context);
    final target = _target;
    if (target == null || target <= 0 || !_measuredValid) return;
    final leadingId = widget.recipe.components.first.rawMaterialItemId;
    final leadingQty = _measuredOf(leadingId);
    if (leadingQty == null || leadingQty <= 0) return;

    setState(() => _submitting = true);
    try {
      final run = await ref.read(productionRunsProvider.notifier).createRun(
            recipeId: widget.recipe.id,
            targetOutput: target,
            yieldTolerancePercent: _tolerance,
          );
      await ref.read(productionRunsProvider.notifier).startRun(
            runId: run.id,
            leadingItemId: leadingId,
            leadingQuantity: leadingQty,
            measuredByItemId: {
              for (final component in widget.recipe.components)
                component.rawMaterialItemId:
                    _measuredOf(component.rawMaterialItemId)!,
            },
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(content: Text(AppStrings.savedCooking)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      final message = e is InventoryApiException ? e.message : e.toString();
      messenger.showSnackBar(
        SnackBar(content: Text(AppStrings.recordFailed(message))),
      );
    }
  }
}

/// Step 1: how many products are needed, plus the threshold band.
class _TargetStep extends StatelessWidget {
  const _TargetStep({
    required this.targetCtrl,
    required this.toleranceCtrl,
    required this.targetValid,
    required this.toleranceValid,
    required this.onChanged,
  });

  final TextEditingController targetCtrl;
  final TextEditingController toleranceCtrl;
  final bool targetValid;
  final bool toleranceValid;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LabeledFormField(
          label: AppStrings.howManyNeeded,
          helper: AppStrings.howManyNeededHint,
          isRequired: true,
          child: TextFormField(
            key: ProductionDialogKeys.targetQty,
            controller: targetCtrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
            ],
            decoration: InputDecoration(
              hintText: AppStrings.targetQuantity,
              errorText: targetCtrl.text.isEmpty || targetValid
                  ? null
                  : AppStrings.amountPositive,
            ),
            onChanged: (_) => onChanged(),
          ),
        ),
        const SizedBox(height: Insets.lg),
        LabeledFormField(
          label: AppStrings.toleranceLabel,
          helper: AppStrings.toleranceHint,
          child: TextFormField(
            key: ProductionDialogKeys.tolerance,
            controller: toleranceCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
            ],
            decoration: InputDecoration(
              hintText: '5',
              suffixText: '%',
              errorText: toleranceCtrl.text.isEmpty || toleranceValid
                  ? null
                  : AppStrings.amountPositive,
            ),
            onChanged: (_) => onChanged(),
          ),
        ),
      ],
    );
  }
}

/// Step 2: every recommended grocery amount, each adjustable.
class _MeasureStep extends StatelessWidget {
  const _MeasureStep({
    required this.recipe,
    required this.ctrls,
    required this.planning,
    required this.stockOf,
    required this.onChanged,
  });

  final RecipeDto recipe;
  final Map<String, TextEditingController> ctrls;
  final bool planning;
  final double Function(String catalogItemId) stockOf;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          AppStrings.measureIngredientsHint,
          style: context.text.bodySmall?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        if (planning) ...[
          const SizedBox(height: Insets.sm),
          const LinearProgressIndicator(),
        ],
        const SizedBox(height: Insets.md),
        for (var i = 0; i < recipe.components.length; i++)
          _MeasuredLine(
            component: recipe.components[i],
            controller: ctrls[recipe.components[i].rawMaterialItemId],
            // First line keeps the legacy key so existing tests/callers
            // that look for `leadingQty` keep working.
            keyOverride: i == 0 ? ProductionDialogKeys.leadingQty : null,
            onHand: stockOf(recipe.components[i].rawMaterialItemId),
            onChanged: onChanged,
          ),
      ],
    );
  }
}

class _MeasuredLine extends StatelessWidget {
  const _MeasuredLine({
    required this.component,
    required this.controller,
    required this.onHand,
    required this.onChanged,
    this.keyOverride,
  });

  final RecipeIngredientDto component;
  final TextEditingController? controller;
  final double onHand;
  final VoidCallback onChanged;
  final Key? keyOverride;

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
                  component.rawMaterialName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodyMedium,
                ),
                Text(
                  AppStrings.consumptionLine(
                    Fmt.quantity(onHand),
                    component.rawMaterialUnit,
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
              key: keyOverride ??
                  ProductionDialogKeys.ingredientQty(
                    component.rawMaterialItemId,
                  ),
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
              ],
              decoration: InputDecoration(
                suffixText: component.rawMaterialUnit,
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

/// Step 3: confirm what cooking actually produced, with a live verdict
/// preview (the server's verdict on submit is authoritative).
class _ConfirmStep extends StatelessWidget {
  const _ConfirmStep({
    required this.recipe,
    required this.target,
    required this.measured,
    required this.actualCtrl,
    required this.verdict,
    required this.onActualChanged,
  });

  final RecipeDto recipe;
  final double target;
  final Map<String, double> measured;
  final TextEditingController actualCtrl;
  final ({String label, bool good, bool bad})? verdict;
  final ValueChanged<String> onActualChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // Local copy: `verdict` is a public field so the compiler cannot
    // promote it after a null check — a local can.
    final preview = verdict;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(Insets.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(color: context.semantic.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.adjustAllHint,
                style: context.text.labelLarge,
              ),
              const SizedBox(height: Insets.sm),
              for (final component in recipe.components)
                Text(
                  '${component.rawMaterialName}: '
                  '${Fmt.quantity(measured[component.rawMaterialItemId] ?? 0)} '
                  '${component.rawMaterialUnit}',
                  style: context.text.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              const SizedBox(height: Insets.xs),
              Text(
                'Target: ${Fmt.quantity(target)} × ${recipe.sellableItemName ?? recipe.name}',
                style: context.text.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Insets.lg),
        LabeledFormField(
          label: AppStrings.achievedQuantity,
          helper: AppStrings.achievedHint,
          isRequired: true,
          child: TextFormField(
            key: ProductionDialogKeys.actualQty,
            controller: actualCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
            ],
            decoration: InputDecoration(hintText: AppStrings.sameAsSuggested),
            onChanged: onActualChanged,
          ),
        ),
        if (preview != null) ...[
          const SizedBox(height: Insets.md),
          Container(
            padding: const EdgeInsets.all(Insets.md),
            decoration: BoxDecoration(
              color: preview.good
                  ? context.semantic.success.withValues(alpha: 0.12)
                  : preview.bad
                      ? context.semantic.warning.withValues(alpha: 0.14)
                      : colors.surfaceContainerHigh.withValues(alpha: 0.55),
              borderRadius: Radii.card,
              border: Border.all(color: context.semantic.hairline),
            ),
            child: Row(
              children: [
                Icon(
                  preview.good
                      ? Icons.check_circle_outline_rounded
                      : preview.bad
                          ? Icons.warning_amber_rounded
                          : Icons.trending_up_rounded,
                  color: preview.good
                      ? context.semantic.success
                      : preview.bad
                          ? context.semantic.warning
                          : colors.primary,
                ),
                const SizedBox(width: Insets.sm),
                Expanded(
                  child: Text(
                    preview.label,
                    style: context.text.titleSmall,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Server-computed result: above / within / below threshold.
class _VerdictPanel extends StatelessWidget {
  const _VerdictPanel({required this.event});

  final ProductionEventDto event;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final good = event.yieldStatus == YieldStatusDto.withinThreshold;
    final bad = event.yieldStatus == YieldStatusDto.below;
    final label = switch (event.yieldStatus) {
      YieldStatusDto.above => AppStrings.yieldAbove,
      YieldStatusDto.withinThreshold => AppStrings.yieldWithin,
      YieldStatusDto.below => AppStrings.yieldBelow,
    };
    final goal = double.parse(event.yieldGoalQuantity.toString());
    final actual = double.parse(event.actualOutputQuantity.toString());
    final pct = event.yieldVariancePercent == null
        ? '—'
        : '${double.parse(event.yieldVariancePercent.toString()).toStringAsFixed(1)}%';
    return Container(
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: good
            ? context.semantic.success.withValues(alpha: 0.12)
            : bad
                ? context.semantic.warning.withValues(alpha: 0.14)
                : colors.surfaceContainerHigh.withValues(alpha: 0.55),
        borderRadius: Radii.card,
        border: Border.all(color: context.semantic.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                good
                    ? Icons.check_circle_outline_rounded
                    : bad
                        ? Icons.warning_amber_rounded
                        : Icons.trending_up_rounded,
                color: good
                    ? context.semantic.success
                    : bad
                        ? context.semantic.warning
                        : colors.primary,
              ),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: Text(label, style: context.text.titleSmall),
              ),
            ],
          ),
          const SizedBox(height: Insets.sm),
          Text(
            'Target ${Fmt.quantity(goal)} × ${event.sellableItemName} · '
            'achieved ${Fmt.quantity(actual)} · '
            '${AppStrings.yieldVarianceLine(Fmt.quantity(actual - goal), pct)}',
            style: context.text.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// The recipe being produced: name, output, and per-unit ingredient list.
class _RecipeContext extends StatelessWidget {
  const _RecipeContext({required this.recipe});

  final RecipeDto recipe;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh.withValues(alpha: 0.55),
        borderRadius: Radii.card,
        border: Border.all(color: context.semantic.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.soup_kitchen_outlined,
                size: 20,
                color: colors.primary,
              ),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: Text(
                  recipe.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.titleSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.xs),
          Text(
            AppStrings.makesBatchRecipe(
              Fmt.quantity(_reqOfTarget(recipe)),
              recipe.targetYieldUnit,
              recipe.components
                  .map(
                    (c) =>
                        '${Fmt.quantity(_reqOf(c))} ${c.rawMaterialUnit} ${c.rawMaterialName}',
                  )
                  .join(' + '),
            ),
            style: context.text.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  static double _reqOf(RecipeIngredientDto component) =>
      double.parse(component.quantityRequired.toString());

  static double _reqOfTarget(RecipeDto recipe) =>
      double.parse(recipe.targetYieldQuantity.toString());
}

/// A display-plain number for prefilling an editable field: `10`, not
/// `10.0` and never grouped (`1,000` would not parse back).
String _plain(double value) =>
    value == value.roundToDouble() ? value.round().toString() : '$value';
