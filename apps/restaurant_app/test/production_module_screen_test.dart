import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:restaurant_pos/models/permission.dart';
import 'package:restaurant_pos/providers/permissions_provider.dart';
import 'package:restaurant_pos/providers/production_provider.dart';
import 'package:restaurant_pos/screens/inventory/cook_wizard_dialog.dart';
import 'package:restaurant_pos/screens/inventory/production_module_screen.dart';
import 'package:restaurant_pos/services/inventory_api_service.dart';
import 'package:restaurant_pos/theme/app_theme.dart';

import 'production_preview_test.dart' show pilauRecipe;
import 'test_helpers/test_container.dart';

RunDto _run({
  required String id,
  required RunStatusDto status,
  String? actual,
  String? waste,
  bool published = false,
  String target = '10',
}) =>
    RunDto(
      id: id,
      businessId: 'biz-1',
      storeId: 'store-1',
      recipeId: 'recipe-1',
      recipeName: 'Pilau',
      sellableItemId: 'sellable-1',
      sellableItemName: 'Pilau',
      targetOutputQuantity: Decimal.parse(target),
      status: status,
      leadingComponentItemId:
          status == RunStatusDto.pending ? null : 'rice',
      yieldTolerancePercent: Decimal.parse('5'),
      actualOutputQuantity:
          actual == null ? null : Decimal.parse(actual),
      wasteReason: waste,
      yieldGoalQuantity: Decimal.parse('10'),
      yieldVariance:
          actual == null ? null : Decimal.parse(actual) - Decimal.parse('10'),
      yieldVariancePercent: null,
      yieldStatus:
          actual == null ? null : YieldStatusDto.withinThreshold,
      published: published,
      publishedAt: published ? DateTime.utc(2026, 9, 14, 8) : null,
      startedAt: status == RunStatusDto.pending
          ? null
          : DateTime.utc(2026, 9, 14, 7),
      completedAt: status == RunStatusDto.completed
          ? DateTime.utc(2026, 9, 14, 7, 30)
          : null,
      createdAt: DateTime.utc(2026, 9, 14, 7),
      updatedAt: DateTime.utc(2026, 9, 14, 7),
      components: [
        RunComponentDto(
          id: 'c1',
          rawMaterialItemId: 'rice',
          rawMaterialName: 'Rice',
          rawMaterialUnit: 'kg',
          plannedQuantity: Decimal.parse('2'),
          measuredQuantity:
              status == RunStatusDto.pending ? null : Decimal.parse('2'),
        ),
      ],
    );

/// Runs notifier double: answers creates/starts instantly with canned runs
/// so the guided pages (plan saved, cooking started) render without a
/// backend. Refresh is a no-op — lists are seeded via [seeded].
class FakeRunsNotifier extends ProductionRunsNotifier {
  FakeRunsNotifier({this._seeded = const []});

  final List<RunDto> _seeded;

  @override
  Future<List<RunDto>> build() async => _seeded;

  @override
  Future<RunDto> createRun({
    required String recipeId,
    required double targetOutput,
    double? yieldTolerancePercent,
  }) async {
    final run = _run(
      id: 'new-run',
      status: RunStatusDto.pending,
      target: '$targetOutput',
    );
    state = AsyncData([run, ...state.valueOrNull ?? const []]);
    return run;
  }

  @override
  Future<RunDto> startRun({
    required String runId,
    required String leadingItemId,
    required double leadingQuantity,
    Map<String, double>? measuredByItemId,
  }) async {
    final run = _run(id: runId, status: RunStatusDto.inProgress);
    state = AsyncData([run]);
    return run;
  }

  @override
  Future<RunDto> completeRun({
    required String runId,
    required double actualOutput,
    String? wasteReason,
  }) async {
    final run = _run(
      id: runId,
      status: RunStatusDto.completed,
      actual: '$actualOutput',
      waste: wasteReason,
    );
    state = AsyncData([run]);
    return run;
  }

  @override
  Future<ProductionEventDto> publishRun({required String runId}) async {
    return ProductionEventDto(
      id: 'event-1',
      businessId: 'biz-1',
      storeId: 'store-1',
      recipeId: 'recipe-1',
      recipeName: 'Pilau',
      sellableItemId: 'sellable-1',
      sellableItemName: 'Pilau',
      leadingComponentItemId: 'rice',
      leadingQuantityUsed: Decimal.parse('2'),
      targetOutputQuantity: Decimal.parse('10'),
      suggestedOutputQuantity: Decimal.parse('10'),
      actualOutputQuantity: Decimal.parse('10'),
      runId: runId,
      yieldGoalQuantity: Decimal.parse('10'),
      yieldVariance: Decimal.parse('0'),
      yieldVariancePercent: Decimal.parse('0'),
      yieldStatus: YieldStatusDto.withinThreshold,
      yieldTolerancePercent: Decimal.parse('5'),
      occurredAt: DateTime.utc(2026, 9, 14, 8),
      createdAt: DateTime.utc(2026, 9, 14, 8),
      components: const [],
    );
  }
}

Future<void> pumpModule(
  WidgetTester tester, {
  List<RunDto> runs = const [],
  ProductionRunsNotifier? runsNotifier,
  Set<String> permissions = const {
    AppPermissions.productionView,
    AppPermissions.productionCreate,
    AppPermissions.recipesCreate,
    AppPermissions.recipesUpdate,
  },
}) async {
  final container = newTestContainer(
    extraOverrides: [
      if (runsNotifier != null)
        productionRunsProvider.overrideWith(() => runsNotifier)
      else
        productionRunsListProvider.overrideWithValue(runs),
      recipesCatalogListProvider.overrideWithValue([pilauRecipe()]),
      hasPermissionProvider.overrideWith(
        (ref, code) => permissions.contains(code),
      ),
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const ProductionModuleScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> goToTab(WidgetTester tester, Key tabKey) async {
  await tester.tap(find.byKey(tabKey));
  await tester.pumpAndSettle();
}

void main() {
  group('ProductionModuleScreen', () {
    testWidgets('opens in the Production Zone with the flow numbered', (
      tester,
    ) async {
      await pumpModule(tester);

      expect(find.byKey(ProductionModuleKeys.recipesTab), findsOneWidget);
      expect(find.byKey(ProductionModuleKeys.runsTab), findsOneWidget);
      expect(find.byKey(ProductionModuleKeys.outputTab), findsOneWidget);

      // Tabs read as a numbered flow, not separate sections.
      expect(find.text('Recipes'), findsOneWidget);
      expect(find.text('Production Zone'), findsOneWidget);
      expect(find.text('Output'), findsOneWidget);

      // Default landing is the zone (hit-testable), not the recipes list.
      expect(
        find.text('No runs in this state yet').hitTestable(),
        findsOneWidget,
      );
      expect(find.text('Pilau').hitTestable(), findsNothing);
    });

    testWidgets('pending run offers Start, in-progress offers Complete',
        (tester) async {
      await pumpModule(
        tester,
        runs: [
          _run(id: 'r1', status: RunStatusDto.pending),
          _run(id: 'r2', status: RunStatusDto.inProgress),
        ],
      );
      await goToTab(tester, ProductionModuleKeys.runsTab);

      expect(
          find.byKey(ProductionModuleKeys.runStart('r1')), findsOneWidget);
      expect(
          find.byKey(ProductionModuleKeys.runComplete('r2')), findsOneWidget);
      expect(
          find.byKey(ProductionModuleKeys.runComplete('r1')), findsNothing);
    });

    testWidgets('starting opens the adjustable measure dialog',
        (tester) async {
      await pumpModule(
        tester,
        runs: [_run(id: 'r1', status: RunStatusDto.pending)],
      );
      await goToTab(tester, ProductionModuleKeys.runsTab);

      await tester.tap(find.byKey(ProductionModuleKeys.runStart('r1')));
      await tester.pumpAndSettle();

      expect(find.text('Rice'), findsOneWidget);
      expect(find.byKey(ProductionModuleKeys.startSubmit), findsOneWidget);
    });

    testWidgets('output tab shows completed runs with Publish', (
      tester,
    ) async {
      await pumpModule(
        tester,
        runs: [
          _run(
            id: 'r3',
            status: RunStatusDto.completed,
            actual: '8',
            waste: 'spillage',
          ),
        ],
      );
      await goToTab(tester, ProductionModuleKeys.outputTab);

      expect(
          find.byKey(ProductionModuleKeys.runPublish('r3')), findsOneWidget);
      expect(find.text('spillage'), findsOneWidget);
    });

    testWidgets('publishing without a backend shows the error', (
      tester,
    ) async {
      await pumpModule(
        tester,
        runs: [
          _run(id: 'r3', status: RunStatusDto.completed, actual: '10'),
        ],
      );
      await goToTab(tester, ProductionModuleKeys.outputTab);

      await tester.tap(find.byKey(ProductionModuleKeys.runPublish('r3')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Could not update run'), findsOneWidget);
    });

    testWidgets('wizard plans, then weighs in one place', (tester) async {
      await pumpModule(tester, runsNotifier: FakeRunsNotifier());
      await goToTab(tester, ProductionModuleKeys.runsTab);

      await tester.tap(find.byKey(ProductionModuleKeys.newRun));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pilau').first);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(CookWizardKeys.targetField),
        '10',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(CookWizardKeys.planContinue));
      await tester.pumpAndSettle();

      // Still inside the one wizard: step 3 of 6, lines to weigh.
      expect(find.text('Step 3 of 6'), findsOneWidget);
      expect(find.text('Rice'), findsOneWidget);
      expect(find.byKey(ProductionModuleKeys.runActual), findsNothing);
    });

    testWidgets('weighing through to a cooking-started landing page', (
      tester,
    ) async {
      await pumpModule(tester, runsNotifier: FakeRunsNotifier());
      await goToTab(tester, ProductionModuleKeys.runsTab);

      await tester.tap(find.byKey(ProductionModuleKeys.newRun));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pilau').first);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(CookWizardKeys.targetField),
        '10',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(CookWizardKeys.planContinue));
      await tester.pumpAndSettle();

      expect(find.text('Rice'), findsOneWidget);
      await tester.tap(find.byKey(CookWizardKeys.startCooking));
      await tester.pumpAndSettle();

      // Cooking takes hours — the wizard says so and offers both exits.
      expect(find.text('Step 4 of 6'), findsOneWidget);
      expect(find.byKey(CookWizardKeys.recordNow), findsOneWidget);
      expect(find.byKey(CookWizardKeys.recordLater), findsOneWidget);
    });

    testWidgets('recording and publishing finish inside the wizard', (
      tester,
    ) async {
      await pumpModule(tester, runsNotifier: FakeRunsNotifier());
      await goToTab(tester, ProductionModuleKeys.runsTab);

      await tester.tap(find.byKey(ProductionModuleKeys.newRun));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pilau').first);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(CookWizardKeys.targetField),
        '10',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(CookWizardKeys.planContinue));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(CookWizardKeys.startCooking));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(CookWizardKeys.recordNow));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(CookWizardKeys.actualField),
        '10',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(CookWizardKeys.completeBatch));
      await tester.pumpAndSettle();

      // Review step: numbers to verify, then publish in the same dialog.
      expect(find.text('Step 6 of 6'), findsOneWidget);
      expect(find.text('Review & publish'), findsOneWidget);
      await tester.tap(find.byKey(CookWizardKeys.publish));
      await tester.pumpAndSettle();

      expect(find.text('Published!'), findsOneWidget);
    });

    testWidgets('completing welcomes back instead of demanding', (
      tester,
    ) async {
      await pumpModule(
        tester,
        runs: [_run(id: 'r2', status: RunStatusDto.inProgress)],
      );
      await goToTab(tester, ProductionModuleKeys.runsTab);

      await tester.tap(find.byKey(ProductionModuleKeys.runComplete('r2')));
      await tester.pumpAndSettle();

      expect(find.text('Welcome back!'), findsOneWidget);
      expect(
        find.byKey(ProductionModuleKeys.runActual),
        findsOneWidget,
      );
    });
  });
}
