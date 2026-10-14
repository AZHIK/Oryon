/// Production state: recipe catalog, history ledger, and recording.
///
/// Recipes and production events both live in Inventory Service but arrive
/// through different endpoints with different shapes, so they get their own
/// notifiers rather than hanging off `InventoryNotifier` — the stock list
/// owns on-hand counts, this file owns everything about making things.
library;

import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/inventory_api_service.dart';
import 'inventory_api_provider.dart';
import 'inventory_provider.dart';
import 'permissions_provider.dart';

// ---------------------------------------------------------------------------
// Recipe catalog
// ---------------------------------------------------------------------------

/// The recipes the kitchen can produce, as the backend resolved them —
/// ingredient names and units included, so no screen has to join anything
/// itself before showing a recipe card or computing a suggestion.
class RecipesCatalogNotifier extends AsyncNotifier<List<RecipeDto>> {
  @override
  Future<List<RecipeDto>> build() async {
    final businessId = ref.watch(currentBusinessIdProvider);
    if (businessId == null) return const [];
    return ref.watch(inventoryApiServiceProvider).fetchRecipes(
          businessId: businessId,
        );
  }

  Future<void> refresh() async {
    final businessId = ref.read(currentBusinessIdProvider);
    if (businessId == null) return;
    state = const AsyncLoading<List<RecipeDto>>().copyWithPrevious(state);
    state = AsyncData(
      await ref.read(inventoryApiServiceProvider).fetchRecipes(
            businessId: businessId,
          ),
    );
  }

  /// The recipe that produces the backend item with [catalogItemId], if one
  /// is defined — the link the "Record production" action follows from a
  /// menu-item detail screen.
  RecipeDto? recipeForSellable(String catalogItemId) {
    for (final recipe in state.valueOrNull ?? const <RecipeDto>[]) {
      if (recipe.sellableItemId == catalogItemId) return recipe;
    }
    return null;
  }

  /// Creates a recipe — standalone or for a sellable item — then re-reads
  /// the catalog so pickers and detail screens see it. Returns what the
  /// server stored. Component quantities are totals for
  /// [targetYieldQuantity] (the batch the formula makes).
  Future<RecipeDto> createRecipe({
    String? sellableItemId,
    String? name,
    String? category,
    Decimal? targetYieldQuantity,
    String? targetYieldUnit,
    required List<RecipeComponentInput> components,
  }) async {
    final businessId = ref.read(currentBusinessIdProvider);
    if (businessId == null) throw StateError('No active business context');
    final saved = await ref.read(inventoryApiServiceProvider).createRecipe(
          businessId: businessId,
          sellableItemId: sellableItemId,
          name: name,
          category: category,
          targetYieldQuantity: targetYieldQuantity,
          targetYieldUnit: targetYieldUnit,
          components: components,
        );
    await refresh();
    return saved;
  }

  /// Links a standalone recipe to its sellable item (set-once, never
  /// moved), then re-reads the catalog. The menu-item form calls this
  /// right after saving a produced-in-house item with a recipe picked.
  Future<RecipeDto> linkRecipe({
    required String recipeId,
    required String sellableItemId,
  }) async {
    final businessId = ref.read(currentBusinessIdProvider);
    if (businessId == null) throw StateError('No active business context');
    final saved = await ref.read(inventoryApiServiceProvider).linkRecipe(
          businessId: businessId,
          recipeId: recipeId,
          sellableItemId: sellableItemId,
        );
    await refresh();
    return saved;
  }

  /// Replaces a recipe's component list as a full set (plus optional
  /// rename), then re-reads the catalog. Lines absent from [components]
  /// are deleted server-side.
  Future<RecipeDto> updateRecipe({
    required String recipeId,
    String? name,
    String? category,
    Decimal? targetYieldQuantity,
    String? targetYieldUnit,
    required List<RecipeComponentInput> components,
  }) async {
    final businessId = ref.read(currentBusinessIdProvider);
    if (businessId == null) throw StateError('No active business context');
    final saved = await ref.read(inventoryApiServiceProvider).updateRecipe(
          businessId: businessId,
          recipeId: recipeId,
          name: name,
          category: category,
          targetYieldQuantity: targetYieldQuantity,
          targetYieldUnit: targetYieldUnit,
          components: components,
        );
    await refresh();
    return saved;
  }

  /// Deletes a recipe and re-reads the catalog. Refused server-side with a
  /// 409 when production runs were recorded against it.
  Future<void> deleteRecipe(String recipeId) async {
    final businessId = ref.read(currentBusinessIdProvider);
    if (businessId == null) throw StateError('No active business context');
    await ref.read(inventoryApiServiceProvider).deleteRecipe(
          businessId: businessId,
          recipeId: recipeId,
        );
    await refresh();
  }
}

final recipesCatalogProvider =
    AsyncNotifierProvider<RecipesCatalogNotifier, List<RecipeDto>>(
      RecipesCatalogNotifier.new,
    );

/// The catalog, unwrapped for pickers that just need the current list.
final recipesCatalogListProvider = Provider<List<RecipeDto>>(
  (ref) => ref.watch(recipesCatalogProvider).valueOrNull ?? const [],
);

/// Standalone recipes: formulas defined before their menu item exists
/// ([RecipeDto.sellableItemId] null). The menu-item form offers these when
/// adding a produced-in-house item; linking happens on save.
final standaloneRecipesProvider = Provider<List<RecipeDto>>(
  (ref) => [
    for (final recipe in ref.watch(recipesCatalogListProvider))
      if (recipe.sellableItemId == null) recipe,
  ],
);

/// Linked recipes only: the only ones production runs and records can use
/// (the output needs a sellable item to stock — the backend 422s the rest).
final linkedRecipesProvider = Provider<List<RecipeDto>>(
  (ref) => [
    for (final recipe in ref.watch(recipesCatalogListProvider))
      if (recipe.sellableItemId != null) recipe,
  ],
);

// ---------------------------------------------------------------------------
// Suggestion math (pure, client-side preview of the server's ratio)
// ---------------------------------------------------------------------------

/// What a production run will consume and suggest, computed locally so the
/// dialog previews live while typing — the server recomputes authoritatively
/// on submit, so this is a preview, never the committed record.
///
/// Null when no preview is possible yet: unknown leading ingredient, an
/// empty quantity, or a zero requirement (which would divide by zero).
@immutable
class ProductionPreview {
  const ProductionPreview({
    required this.ratio,
    required this.consumedByItemId,
    required this.suggestedOutput,
  });

  /// `leadingQty ÷ leadingRequirement` — doubles as the suggested output
  /// count, since one recipe makes one unit of the sellable item.
  final double ratio;

  /// Every ingredient's consumption at this ratio, keyed by backend item id.
  /// The leading entry is the typed value exactly, never ratio-rounded.
  final Map<String, double> consumedByItemId;

  final double suggestedOutput;

  static ProductionPreview? of({
    required RecipeDto recipe,
    required String leadingItemId,
    required double leadingQty,
  }) {
    if (leadingQty <= 0) return null;
    RecipeIngredientDto? leading;
    for (final component in recipe.components) {
      if (component.rawMaterialItemId == leadingItemId) leading = component;
    }
    if (leading == null) return null;
    final batch = double.parse(recipe.targetYieldQuantity.toString());
    final divisor = batch <= 0 ? 1.0 : batch;
    final requirement =
        double.parse(leading.quantityRequired.toString()) / divisor;
    if (requirement <= 0) return null;

    final ratio = leadingQty / requirement;
    return ProductionPreview(
      ratio: ratio,
      suggestedOutput: ratio,
      consumedByItemId: {
        for (final component in recipe.components)
          component.rawMaterialItemId:
              component.rawMaterialItemId == leadingItemId
                  ? leadingQty
                  : double.parse(component.quantityRequired.toString()) /
                      divisor *
                      ratio,
      },
    );
  }

  /// Recommendation for a target output: per-unit share × target per
  /// ingredient. Mirrors the backend plan endpoint so the dialog can seed
  /// its adjustable fields instantly (the server remains authoritative on
  /// submit). Batch-aware: divides batch totals by the recipe yield.
  static Map<String, double> plannedForTarget({
    required RecipeDto recipe,
    required double target,
  }) {
    final batch = double.parse(recipe.targetYieldQuantity.toString());
    final divisor = batch <= 0 ? 1.0 : batch;
    return {
      for (final component in recipe.components)
        component.rawMaterialItemId:
            double.parse(component.quantityRequired.toString()) /
                divisor *
                target,
    };
  }
}

// ---------------------------------------------------------------------------
// History ledger
// ---------------------------------------------------------------------------

/// Date-range filter over production history. Null ends are open — "from
/// last Monday" needs no end date, and clearing is one call.
@immutable
class ProductionDateFilter {
  const ProductionDateFilter({this.from, this.to});

  final DateTime? from;
  final DateTime? to;

  ProductionDateFilter copyWith({DateTime? from, DateTime? to}) =>
      ProductionDateFilter(from: from ?? this.from, to: to ?? this.to);
}

class ProductionDateFilterNotifier extends Notifier<ProductionDateFilter> {
  @override
  ProductionDateFilter build() => const ProductionDateFilter();

  void setRange(DateTime? from, DateTime? to) =>
      state = ProductionDateFilter(from: from, to: to);

  void clear() => state = const ProductionDateFilter();
}

final productionDateFilterProvider =
    NotifierProvider<ProductionDateFilterNotifier, ProductionDateFilter>(
      ProductionDateFilterNotifier.new,
    );

/// Recorded production runs, newest first — the kitchen's ledger.
///
/// With no business context this is empty — recording genuinely needs the
/// backend's atomic transaction.
class ProductionHistoryNotifier extends AsyncNotifier<List<ProductionEventDto>> {
  InventoryApiService get _api => ref.read(inventoryApiServiceProvider);

  String? get _businessId => ref.read(currentBusinessIdProvider);

  @override
  Future<List<ProductionEventDto>> build() async {
    final businessId = ref.watch(currentBusinessIdProvider);
    final filter = ref.watch(productionDateFilterProvider);
    if (businessId == null) return const [];
    return ref.watch(inventoryApiServiceProvider).fetchProductionEvents(
          businessId: businessId,
          from: filter.from,
          to: filter.to,
        );
  }

  Future<void> refresh() async {
    final businessId = ref.read(currentBusinessIdProvider);
    if (businessId == null) return;
    final filter = ref.read(productionDateFilterProvider);
    state = const AsyncLoading<List<ProductionEventDto>>().copyWithPrevious(state);
    state = AsyncData(
      await _api.fetchProductionEvents(
        businessId: businessId,
        from: filter.from,
        to: filter.to,
      ),
    );
  }

  /// Recommends every grocery amount for [targetOutput] ("I need N").
  ///
  /// Pure calculation server-side — no stock moves. Each line stays
  /// adjustable; the dialog seeds its editable fields from the plan.
  Future<ProductionPlanDto> planProduction({
    required String recipeId,
    required double targetOutput,
  }) async {
    final businessId = _businessId;
    if (businessId == null) throw StateError('No active business context');
    return _api.planProduction(
      businessId: businessId,
      recipeId: recipeId,
      targetOutputQuantity: Decimal.parse(targetOutput.toString()),
    );
  }

  /// Records a production run, then re-reads history and stock counts.
  ///
  /// Both refreshes matter: the ledger must show the new run, and every
  /// touched stock count moved server-side. Returns the recorded event so
  /// the dialog can confirm with real numbers including the server-computed
  /// yield verdict (above / within / below threshold).
  Future<ProductionEventDto> recordProduction({
    required String recipeId,
    required String leadingItemId,
    required double leadingQuantity,
    double? targetOutput,
    Map<String, double>? measuredByItemId,
    double? actualOutput,
    double? yieldTolerancePercent,
  }) async {
    final businessId = _businessId;
    if (businessId == null) throw StateError('No active business context');
    final event = await _api.recordProduction(
      businessId: businessId,
      recipeId: recipeId,
      leadingItemId: leadingItemId,
      leadingQuantityUsed: Decimal.parse(leadingQuantity.toString()),
      targetOutputQuantity: targetOutput == null
          ? null
          : Decimal.parse(targetOutput.toString()),
      components: measuredByItemId == null
          ? null
          : [
              for (final entry in measuredByItemId.entries)
                MeasuredComponentInput(
                  rawMaterialItemId: entry.key,
                  quantityUsed: Decimal.parse(entry.value.toString()),
                ),
            ],
      actualOutputQuantity: actualOutput == null
          ? null
          : Decimal.parse(actualOutput.toString()),
      yieldTolerancePercent: yieldTolerancePercent == null
          ? null
          : Decimal.parse(yieldTolerancePercent.toString()),
    );
    await refresh();
    // Stock moved on every leg — the grocery counts are stale until this
    // re-syncs, the same read-after-write discipline as item creation.
    await ref.read(inventoryItemsProvider.notifier).refresh();
    return event;
  }
}

final productionHistoryProvider =
    AsyncNotifierProvider<ProductionHistoryNotifier, List<ProductionEventDto>>(
      ProductionHistoryNotifier.new,
    );

/// The ledger, unwrapped for the history screen.
final productionHistoryListProvider = Provider<List<ProductionEventDto>>(
  (ref) => ref.watch(productionHistoryProvider).valueOrNull ?? const [],
);

// ---------------------------------------------------------------------------
// Scheduled runs (Production Module, Tabs 2 + 3)
// ---------------------------------------------------------------------------

/// Status filter over the runs list. Null means all — the tab chips set
/// one status or clear back to everything.
class ProductionRunStatusFilterNotifier extends Notifier<RunStatusDto?> {
  @override
  RunStatusDto? build() => null;

  void set(RunStatusDto? status) => state = status;

  void clear() => state = null;
}

final productionRunStatusFilterProvider =
    NotifierProvider<ProductionRunStatusFilterNotifier, RunStatusDto?>(
      ProductionRunStatusFilterNotifier.new,
    );

/// Scheduled cooking batches, newest first — the shift plan (Tab 2) and
/// the verification queue (Tab 3) read the same list through different
/// status filters.
class ProductionRunsNotifier extends AsyncNotifier<List<RunDto>> {
  InventoryApiService get _api => ref.read(inventoryApiServiceProvider);

  String? get _businessId => ref.read(currentBusinessIdProvider);

  @override
  Future<List<RunDto>> build() async {
    final businessId = ref.watch(currentBusinessIdProvider);
    final filter = ref.watch(productionRunStatusFilterProvider);
    if (businessId == null) return const [];
    return _api.fetchRuns(businessId: businessId, status: filter);
  }

  Future<void> refresh() async {
    final businessId = _businessId;
    if (businessId == null) return;
    final filter = ref.read(productionRunStatusFilterProvider);
    state = const AsyncLoading<List<RunDto>>().copyWithPrevious(state);
    state = AsyncData(
      await _api.fetchRuns(businessId: businessId, status: filter),
    );
  }

  /// Schedules a batch (pending): snapshots the plan, moves no stock.
  Future<RunDto> createRun({
    required String recipeId,
    required double targetOutput,
    double? yieldTolerancePercent,
  }) async {
    final businessId = _businessId;
    if (businessId == null) throw StateError('No active business context');
    final run = await _api.createRun(
      businessId: businessId,
      recipeId: recipeId,
      targetOutputQuantity: Decimal.parse(targetOutput.toString()),
      yieldTolerancePercent: yieldTolerancePercent == null
          ? null
          : Decimal.parse(yieldTolerancePercent.toString()),
    );
    await refresh();
    return run;
  }

  /// Starts a pending run: deducts the weighed ingredients, instantly.
  /// Pass [measuredByItemId] (full recipe coverage) to record adjustments;
  /// omit it to weigh the plan exactly. Refreshes stock counts too — every
  /// input leg moved server-side.
  Future<RunDto> startRun({
    required String runId,
    required String leadingItemId,
    required double leadingQuantity,
    Map<String, double>? measuredByItemId,
  }) async {
    final businessId = _businessId;
    if (businessId == null) throw StateError('No active business context');
    final run = await _api.startRun(
      businessId: businessId,
      runId: runId,
      leadingItemId: leadingItemId,
      leadingQuantityUsed: Decimal.parse(leadingQuantity.toString()),
      components: measuredByItemId == null
          ? null
          : [
              for (final entry in measuredByItemId.entries)
                MeasuredComponentInput(
                  rawMaterialItemId: entry.key,
                  quantityUsed: Decimal.parse(entry.value.toString()),
                ),
            ],
    );
    await refresh();
    await ref.read(inventoryItemsProvider.notifier).refresh();
    return run;
  }

  /// Completes an in-progress run: records actual yield + waste reason.
  /// Moves no stock — publishing does that, so verification stays safe.
  Future<RunDto> completeRun({
    required String runId,
    required double actualOutput,
    String? wasteReason,
  }) async {
    final businessId = _businessId;
    if (businessId == null) throw StateError('No active business context');
    final run = await _api.completeRun(
      businessId: businessId,
      runId: runId,
      actualOutputQuantity: Decimal.parse(actualOutput.toString()),
      wasteReason: wasteReason,
    );
    await refresh();
    return run;
  }

  /// Publishes a completed run: stocks the output ("Publish to POS &
  /// Inventory"), writes history + verdict. Refreshes history, runs, and
  /// stock — all three moved server-side.
  Future<ProductionEventDto> publishRun({required String runId}) async {
    final businessId = _businessId;
    if (businessId == null) throw StateError('No active business context');
    final event = await _api.publishRun(businessId: businessId, runId: runId);
    await refresh();
    await ref.read(productionHistoryProvider.notifier).refresh();
    await ref.read(inventoryItemsProvider.notifier).refresh();
    return event;
  }

  /// Deletes a pending run. Started runs moved stock — complete them.
  Future<void> deleteRun(String runId) async {
    final businessId = _businessId;
    if (businessId == null) throw StateError('No active business context');
    await _api.deleteRun(businessId: businessId, runId: runId);
    await refresh();
  }
}

final productionRunsProvider =
    AsyncNotifierProvider<ProductionRunsNotifier, List<RunDto>>(
      ProductionRunsNotifier.new,
    );

/// The runs, unwrapped for the Runs and Output tabs.
final productionRunsListProvider = Provider<List<RunDto>>(
  (ref) => ref.watch(productionRunsProvider).valueOrNull ?? const [],
);
