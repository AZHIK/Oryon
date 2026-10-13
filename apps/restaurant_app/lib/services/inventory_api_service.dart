/// Write-side API client for Inventory Service — item CRUD and stock
/// operations (adjust/waste/transfer).
///
/// Unlike `sync/inventory_catalog_api.dart` (a pluggable Fake/Http pair for
/// the read-side catalog pull), this is a plain Dio-wrapping class, matching
/// `StoreApiService`/`BusinessApiService` — there is no offline/demo mode for
/// writes; every call here requires connectivity.
library;

import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';

import '../constants/api_paths.dart';
import '../constants/app_limits.dart';
import '../sync/inventory_catalog_api.dart' show CatalogItemDto;

/// A single stock movement, as returned by the adjust/waste/transfer
/// endpoints. This is an audit-trail record, not a stock level — callers
/// that need the item's new on-hand quantity must re-sync stock levels
/// after a successful write (see `CatalogSyncService.syncStockLevels`).
class StockMovementDto {
  final String id;
  final String itemId;
  final String businessId;
  final String storeId;
  final Decimal quantityDelta;
  final String movementType;
  final String? reason;
  final DateTime createdAt;
  final Decimal? unitCost;

  StockMovementDto({
    required this.id,
    required this.itemId,
    required this.businessId,
    required this.storeId,
    required this.quantityDelta,
    required this.movementType,
    this.reason,
    required this.createdAt,
    this.unitCost,
  });

  factory StockMovementDto.fromJson(Map<String, dynamic> json) => StockMovementDto(
        id: json['id'] as String,
        itemId: json['item_id'] as String,
        businessId: json['business_id'] as String,
        storeId: json['store_id'] as String,
        quantityDelta: Decimal.parse(json['quantity_delta'].toString()),
        movementType: json['movement_type'] as String,
        reason: json['reason'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        unitCost: json['unit_cost'] == null
            ? null
            : Decimal.parse(json['unit_cost'].toString()),
      );
}

/// Thrown when the backend rejects a write with a domain-specific error
/// (insufficient stock, item-type mismatch, validation) — callers can show
/// [message] directly rather than a generic "something went wrong".
class InventoryApiException implements Exception {
  final String message;
  final int? statusCode;

  InventoryApiException(this.message, [this.statusCode]);

  @override
  String toString() =>
      'InventoryApiException: $message${statusCode != null ? ' (HTTP $statusCode)' : ''}';
}

/// One ingredient line of a recipe, with resolved item details.
///
/// Batch semantics: [quantityRequired] is the TOTAL for the recipe's
/// target yield; [quantityPerUnit] is one sellable unit's share.
/// [lineCost] is the line's batch cost at current prices (null when the
/// raw item has no unit cost — unknown, not zero).
class RecipeIngredientDto {
  final String rawMaterialItemId;
  final String rawMaterialName;
  final String rawMaterialUnit;
  final Decimal quantityRequired;
  final Decimal quantityPerUnit;
  final Decimal? lineCost;

  RecipeIngredientDto({
    required this.rawMaterialItemId,
    required this.rawMaterialName,
    required this.rawMaterialUnit,
    required this.quantityRequired,
    Decimal? quantityPerUnit,
    this.lineCost,
  }) : quantityPerUnit = quantityPerUnit ?? quantityRequired;

  factory RecipeIngredientDto.fromJson(Map<String, dynamic> json) {
    final required = Decimal.parse(json['quantity_required'].toString());
    final perUnit = json['quantity_per_unit'];
    final cost = json['line_cost'];
    return RecipeIngredientDto(
      rawMaterialItemId: json['raw_material_item_id'] as String,
      rawMaterialName: json['raw_material_name'] as String,
      rawMaterialUnit: json['raw_material_unit'] as String? ?? '',
      quantityRequired: required,
      quantityPerUnit:
          perUnit == null ? required : Decimal.parse(perUnit.toString()),
      lineCost: cost == null ? null : Decimal.parse(cost.toString()),
    );
  }
}

/// One ingredient line on a recipe create/update payload: just the raw
/// item id and the quantity in that item's own unit.
class RecipeComponentInput {
  RecipeComponentInput({
    required this.rawMaterialItemId,
    required this.quantityRequired,
  });

  final String rawMaterialItemId;
  final Decimal quantityRequired;

  Map<String, dynamic> toJson() => {
        'raw_material_item_id': rawMaterialItemId,
        'quantity_required': quantityRequired.toString(),
      };
}

/// Kitchen blueprint categories offered by the recipe form.
abstract final class RecipeCategories {
  static const prep = 'prep';
  static const sauce = 'sauce';
  static const finished = 'finished';

  static const all = [prep, sauce, finished];
}

/// A recipe header with its full ingredient set.
///
/// [targetYieldQuantity]/[targetYieldUnit] size the batch the component
/// totals are written for ("makes 50 portions"). [totalCost] is the batch
/// cost at current raw prices, [costPerUnit] one unit's share;
/// [costComplete] is false when some ingredient lacks a unit cost (the
/// totals then understate the truth).
class RecipeDto {
  final String id;
  final String businessId;
  final String sellableItemId;
  final String sellableItemName;
  final String name;
  final String? category;
  final Decimal targetYieldQuantity;
  final String targetYieldUnit;
  final Decimal totalCost;
  final Decimal costPerUnit;
  final bool costComplete;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<RecipeIngredientDto> components;

  RecipeDto({
    required this.id,
    required this.businessId,
    required this.sellableItemId,
    required this.sellableItemName,
    required this.name,
    this.category,
    Decimal? targetYieldQuantity,
    this.targetYieldUnit = 'portions',
    Decimal? totalCost,
    Decimal? costPerUnit,
    this.costComplete = true,
    required this.createdAt,
    required this.updatedAt,
    required this.components,
  })  : targetYieldQuantity = targetYieldQuantity ?? Decimal.fromInt(1),
        totalCost = totalCost ?? Decimal.zero,
        costPerUnit = costPerUnit ?? Decimal.zero;

  factory RecipeDto.fromJson(Map<String, dynamic> json) {
    Decimal? _opt(Object? v) => v == null ? null : Decimal.parse(v.toString());
    return RecipeDto(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      sellableItemId: json['sellable_item_id'] as String,
      sellableItemName: json['sellable_item_name'] as String,
      name: json['name'] as String,
      category: json['category'] as String?,
      targetYieldQuantity: _opt(json['target_yield_quantity']) ?? Decimal.fromInt(1),
      targetYieldUnit: json['target_yield_unit'] as String? ?? 'portions',
      totalCost: _opt(json['total_cost']) ?? Decimal.zero,
      costPerUnit: _opt(json['cost_per_unit']) ?? Decimal.zero,
      costComplete: json['cost_complete'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      components: (json['components'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(RecipeIngredientDto.fromJson)
          .toList(),
    );
  }
}

/// One ingredient consumed by a production event, with resolved item details.
class ProductionComponentDto {
  final String id;
  final String rawMaterialItemId;
  final String rawMaterialName;
  final String rawMaterialUnit;
  final Decimal quantityConsumed;

  ProductionComponentDto({
    required this.id,
    required this.rawMaterialItemId,
    required this.rawMaterialName,
    required this.rawMaterialUnit,
    required this.quantityConsumed,
  });

  factory ProductionComponentDto.fromJson(Map<String, dynamic> json) =>
      ProductionComponentDto(
        id: json['id'] as String,
        rawMaterialItemId: json['raw_material_item_id'] as String,
        rawMaterialName: json['raw_material_name'] as String,
        rawMaterialUnit: json['raw_material_unit'] as String? ?? '',
        quantityConsumed: Decimal.parse(json['quantity_consumed'].toString()),
      );
}

/// Yield verdict of a production run vs its goal, computed server-side.
enum YieldStatusDto {
  above,
  withinThreshold,
  below;

  static YieldStatusDto fromJson(String value) => switch (value) {
        'above' => YieldStatusDto.above,
        'within_threshold' => YieldStatusDto.withinThreshold,
        'below' => YieldStatusDto.below,
        _ => YieldStatusDto.withinThreshold,
      };
}

/// One adjustable ingredient line on a target-based produce payload.
class MeasuredComponentInput {
  MeasuredComponentInput({
    required this.rawMaterialItemId,
    required this.quantityUsed,
  });

  final String rawMaterialItemId;
  final Decimal quantityUsed;

  Map<String, dynamic> toJson() => {
        'raw_material_item_id': rawMaterialItemId,
        'quantity_used': quantityUsed.toString(),
      };
}

/// One recommended ingredient line for a target output.
class PlannedComponentDto {
  final String rawMaterialItemId;
  final String rawMaterialName;
  final String rawMaterialUnit;
  final Decimal quantityRequiredPerUnit;
  final Decimal plannedQuantity;

  PlannedComponentDto({
    required this.rawMaterialItemId,
    required this.rawMaterialName,
    required this.rawMaterialUnit,
    required this.quantityRequiredPerUnit,
    required this.plannedQuantity,
  });

  factory PlannedComponentDto.fromJson(Map<String, dynamic> json) =>
      PlannedComponentDto(
        rawMaterialItemId: json['raw_material_item_id'] as String,
        rawMaterialName: json['raw_material_name'] as String,
        rawMaterialUnit: json['raw_material_unit'] as String? ?? '',
        quantityRequiredPerUnit: Decimal.parse(
          json['quantity_required_per_unit'].toString(),
        ),
        plannedQuantity: Decimal.parse(
          json['planned_quantity'].toString(),
        ),
      );
}

/// Recommendation for a target output: one adjustable line per ingredient.
class ProductionPlanDto {
  final String recipeId;
  final String recipeName;
  final String sellableItemId;
  final String sellableItemName;
  final Decimal targetOutputQuantity;
  final Decimal suggestedOutputQuantity;
  final List<PlannedComponentDto> components;

  ProductionPlanDto({
    required this.recipeId,
    required this.recipeName,
    required this.sellableItemId,
    required this.sellableItemName,
    required this.targetOutputQuantity,
    required this.suggestedOutputQuantity,
    required this.components,
  });

  factory ProductionPlanDto.fromJson(Map<String, dynamic> json) =>
      ProductionPlanDto(
        recipeId: json['recipe_id'] as String,
        recipeName: json['recipe_name'] as String,
        sellableItemId: json['sellable_item_id'] as String,
        sellableItemName: json['sellable_item_name'] as String,
        targetOutputQuantity: Decimal.parse(
          json['target_output_quantity'].toString(),
        ),
        suggestedOutputQuantity: Decimal.parse(
          json['suggested_output_quantity'].toString(),
        ),
        components: (json['components'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map(PlannedComponentDto.fromJson)
            .toList(),
      );
}

/// A recorded production run: measured input, goal, suggestion, confirmed
/// output, and the server-computed yield verdict.
class ProductionEventDto {
  final String id;
  final String businessId;
  final String storeId;
  final String recipeId;
  final String recipeName;
  final String sellableItemId;
  final String sellableItemName;
  final String leadingComponentItemId;
  final Decimal leadingQuantityUsed;
  final Decimal? targetOutputQuantity;
  final Decimal suggestedOutputQuantity;
  final Decimal actualOutputQuantity;
  final String? runId;
  final String? wasteReason;
  final Decimal yieldGoalQuantity;
  final Decimal yieldVariance;
  final Decimal? yieldVariancePercent;
  final YieldStatusDto yieldStatus;
  final Decimal yieldTolerancePercent;
  final String? actorId;
  final DateTime occurredAt;
  final DateTime createdAt;
  final List<ProductionComponentDto> components;

  ProductionEventDto({
    required this.id,
    required this.businessId,
    required this.storeId,
    required this.recipeId,
    required this.recipeName,
    required this.sellableItemId,
    required this.sellableItemName,
    required this.leadingComponentItemId,
    required this.leadingQuantityUsed,
    this.targetOutputQuantity,
    required this.suggestedOutputQuantity,
    required this.actualOutputQuantity,
    this.runId,
    this.wasteReason,
    required this.yieldGoalQuantity,
    required this.yieldVariance,
    this.yieldVariancePercent,
    required this.yieldStatus,
    required this.yieldTolerancePercent,
    this.actorId,
    required this.occurredAt,
    required this.createdAt,
    required this.components,
  });

  factory ProductionEventDto.fromJson(Map<String, dynamic> json) {
    Decimal? _optDecimal(Object? v) =>
        v == null ? null : Decimal.parse(v.toString());
    return ProductionEventDto(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      storeId: json['store_id'] as String,
      recipeId: json['recipe_id'] as String,
      recipeName: json['recipe_name'] as String,
      sellableItemId: json['sellable_item_id'] as String,
      sellableItemName: json['sellable_item_name'] as String,
      leadingComponentItemId: json['leading_component_item_id'] as String,
      leadingQuantityUsed: Decimal.parse(
        json['leading_quantity_used'].toString(),
      ),
      targetOutputQuantity: _optDecimal(json['target_output_quantity']),
      suggestedOutputQuantity: Decimal.parse(
        json['suggested_output_quantity'].toString(),
      ),
      actualOutputQuantity: Decimal.parse(
        json['actual_output_quantity'].toString(),
      ),
      runId: json['run_id'] as String?,
      wasteReason: json['waste_reason'] as String?,
      yieldGoalQuantity: Decimal.parse(
        (json['yield_goal_quantity'] ?? json['suggested_output_quantity'])
            .toString(),
      ),
      yieldVariance: Decimal.parse(
        (json['yield_variance'] ?? '0').toString(),
      ),
      yieldVariancePercent: _optDecimal(json['yield_variance_percent']),
      yieldStatus: json['yield_status'] == null
          ? YieldStatusDto.withinThreshold
          : YieldStatusDto.fromJson(json['yield_status'].toString()),
      yieldTolerancePercent: Decimal.parse(
        (json['yield_tolerance_percent'] ?? '5').toString(),
      ),
      actorId: json['actor_id'] as String?,
      occurredAt: DateTime.parse(json['occurred_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      components: (json['components'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(ProductionComponentDto.fromJson)
          .toList(),
    );
  }
}

/// Lifecycle state of a scheduled production run.
enum RunStatusDto {
  pending,
  inProgress,
  completed;

  static RunStatusDto fromJson(String value) => switch (value) {
        'pending' => RunStatusDto.pending,
        'in_progress' => RunStatusDto.inProgress,
        'completed' => RunStatusDto.completed,
        _ => RunStatusDto.pending,
      };

  String get apiValue => switch (this) {
        RunStatusDto.pending => 'pending',
        RunStatusDto.inProgress => 'in_progress',
        RunStatusDto.completed => 'completed',
      };
}

/// One snapshotted plan line of a run with its measured outcome.
class RunComponentDto {
  final String id;
  final String rawMaterialItemId;
  final String rawMaterialName;
  final String rawMaterialUnit;
  final Decimal plannedQuantity;
  final Decimal? measuredQuantity;

  RunComponentDto({
    required this.id,
    required this.rawMaterialItemId,
    required this.rawMaterialName,
    required this.rawMaterialUnit,
    required this.plannedQuantity,
    this.measuredQuantity,
  });

  factory RunComponentDto.fromJson(Map<String, dynamic> json) {
    final measured = json['measured_quantity'];
    return RunComponentDto(
      id: json['id'] as String,
      rawMaterialItemId: json['raw_material_item_id'] as String,
      rawMaterialName: json['raw_material_name'] as String,
      rawMaterialUnit: json['raw_material_unit'] as String? ?? '',
      plannedQuantity: Decimal.parse(json['planned_quantity'].toString()),
      measuredQuantity:
          measured == null ? null : Decimal.parse(measured.toString()),
    );
  }
}

/// A scheduled cooking batch: plan → start → complete → publish.
class RunDto {
  final String id;
  final String businessId;
  final String storeId;
  final String recipeId;
  final String recipeName;
  final String sellableItemId;
  final String sellableItemName;
  final Decimal targetOutputQuantity;
  final RunStatusDto status;
  final String? leadingComponentItemId;
  final Decimal yieldTolerancePercent;
  final Decimal? actualOutputQuantity;
  final String? wasteReason;
  final Decimal yieldGoalQuantity;
  final Decimal? yieldVariance;
  final Decimal? yieldVariancePercent;
  final YieldStatusDto? yieldStatus;
  final bool published;
  final DateTime? publishedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<RunComponentDto> components;

  RunDto({
    required this.id,
    required this.businessId,
    required this.storeId,
    required this.recipeId,
    required this.recipeName,
    required this.sellableItemId,
    required this.sellableItemName,
    required this.targetOutputQuantity,
    required this.status,
    this.leadingComponentItemId,
    required this.yieldTolerancePercent,
    this.actualOutputQuantity,
    this.wasteReason,
    required this.yieldGoalQuantity,
    this.yieldVariance,
    this.yieldVariancePercent,
    this.yieldStatus,
    required this.published,
    this.publishedAt,
    this.startedAt,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
    required this.components,
  });

  factory RunDto.fromJson(Map<String, dynamic> json) {
    Decimal? _opt(Object? v) =>
        v == null ? null : Decimal.parse(v.toString());
    final status = RunStatusDto.fromJson(json['status'].toString());
    final yieldStatus = json['yield_status'];
    return RunDto(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      storeId: json['store_id'] as String,
      recipeId: json['recipe_id'] as String,
      recipeName: json['recipe_name'] as String,
      sellableItemId: json['sellable_item_id'] as String,
      sellableItemName: json['sellable_item_name'] as String,
      targetOutputQuantity: Decimal.parse(
        json['target_output_quantity'].toString(),
      ),
      status: status,
      leadingComponentItemId: json['leading_component_item_id'] as String?,
      yieldTolerancePercent: Decimal.parse(
        (json['yield_tolerance_percent'] ?? '5').toString(),
      ),
      actualOutputQuantity: _opt(json['actual_output_quantity']),
      wasteReason: json['waste_reason'] as String?,
      yieldGoalQuantity: Decimal.parse(
        json['yield_goal_quantity'].toString(),
      ),
      yieldVariance: _opt(json['yield_variance']),
      yieldVariancePercent: _opt(json['yield_variance_percent']),
      yieldStatus: yieldStatus == null
          ? null
          : YieldStatusDto.fromJson(yieldStatus.toString()),
      published: json['published_at'] != null,
      publishedAt: json['published_at'] == null
          ? null
          : DateTime.parse(json['published_at'] as String),
      startedAt: json['started_at'] == null
          ? null
          : DateTime.parse(json['started_at'] as String),
      completedAt: json['completed_at'] == null
          ? null
          : DateTime.parse(json['completed_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      components: (json['components'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(RunComponentDto.fromJson)
          .toList(),
    );
  }
}

/// One item's recorded waste in a window: quantity and cost.
///
/// [costEstimated] is true when the backend fell back to the item's current
/// cost for legacy movements without a frozen snapshot.
class WasteLineDto {
  final String itemId;
  final String itemName;
  final String itemUnit;
  final Decimal quantityWasted;
  final Decimal costWasted;
  final bool costEstimated;

  WasteLineDto({
    required this.itemId,
    required this.itemName,
    required this.itemUnit,
    required this.quantityWasted,
    required this.costWasted,
    this.costEstimated = false,
  });

  factory WasteLineDto.fromJson(Map<String, dynamic> json) => WasteLineDto(
        itemId: json['item_id'] as String,
        itemName: json['item_name'] as String,
        itemUnit: json['item_unit'] as String? ?? '',
        quantityWasted: Decimal.parse(json['quantity_wasted'].toString()),
        costWasted: Decimal.parse(json['cost_wasted'].toString()),
        costEstimated: json['cost_estimated'] as bool? ?? false,
      );
}

/// Waste in a window: per-item lines plus the total cost.
class WasteSummaryDto {
  final List<WasteLineDto> lines;
  final Decimal totalCostWasted;
  final bool estimated;

  WasteSummaryDto({
    required this.lines,
    required this.totalCostWasted,
    this.estimated = false,
  });

  factory WasteSummaryDto.fromJson(Map<String, dynamic> json) =>
      WasteSummaryDto(
        lines: (json['lines'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map(WasteLineDto.fromJson)
            .toList(),
        totalCostWasted: Decimal.parse(
          json['total_cost_wasted'].toString(),
        ),
        estimated: json['estimated'] as bool? ?? false,
      );
}

/// One ingredient's total consumption across production runs in a window.
class IngredientConsumptionDto {
  final String rawMaterialItemId;
  final String rawMaterialName;
  final String rawMaterialUnit;
  final Decimal quantityConsumed;

  IngredientConsumptionDto({
    required this.rawMaterialItemId,
    required this.rawMaterialName,
    required this.rawMaterialUnit,
    required this.quantityConsumed,
  });

  factory IngredientConsumptionDto.fromJson(Map<String, dynamic> json) =>
      IngredientConsumptionDto(
        rawMaterialItemId: json['raw_material_item_id'] as String,
        rawMaterialName: json['raw_material_name'] as String,
        rawMaterialUnit: json['raw_material_unit'] as String? ?? '',
        quantityConsumed: Decimal.parse(
          json['quantity_consumed'].toString(),
        ),
      );
}

/// Production in a window: run counts, suggested-vs-actual totals, and the
/// over-portioning gap (actual minus suggested).
class ProductionSummaryDto {
  final int runs;
  final Decimal suggestedTotal;
  final Decimal actualTotal;
  final Decimal overPortionedBy;
  final List<IngredientConsumptionDto> ingredientsConsumed;

  ProductionSummaryDto({
    required this.runs,
    required this.suggestedTotal,
    required this.actualTotal,
    required this.overPortionedBy,
    required this.ingredientsConsumed,
  });

  factory ProductionSummaryDto.fromJson(Map<String, dynamic> json) =>
      ProductionSummaryDto(
        runs: json['runs'] as int,
        suggestedTotal: Decimal.parse(json['suggested_total'].toString()),
        actualTotal: Decimal.parse(json['actual_total'].toString()),
        overPortionedBy: Decimal.parse(json['over_portioned_by'].toString()),
        ingredientsConsumed:
            (json['ingredients_consumed'] as List<dynamic>)
                .cast<Map<String, dynamic>>()
                .map(IngredientConsumptionDto.fromJson)
                .toList(),
      );
}

/// One category's share of current inventory value.
class StockValuationLineDto {
  final String? category;
  final int itemCount;
  final Decimal totalValue;

  StockValuationLineDto({
    this.category,
    required this.itemCount,
    required this.totalValue,
  });

  factory StockValuationLineDto.fromJson(Map<String, dynamic> json) =>
      StockValuationLineDto(
        category: json['category'] as String?,
        itemCount: json['item_count'] as int,
        totalValue: Decimal.parse(json['total_value'].toString()),
      );
}

/// Current inventory value (on-hand × unit cost): a snapshot, not a window.
class StockValuationDto {
  final Decimal totalValue;
  final List<StockValuationLineDto> lines;

  StockValuationDto({required this.totalValue, required this.lines});

  factory StockValuationDto.fromJson(Map<String, dynamic> json) =>
      StockValuationDto(
        totalValue: Decimal.parse(json['total_value'].toString()),
        lines: (json['lines'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map(StockValuationLineDto.fromJson)
            .toList(),
      );
}

/// One item+supplier bucket of purchasing (Product Purchase Report).
class ProductPurchaseLineDto {
  final String itemId;
  final String itemName;
  final String itemUnit;
  final String? supplierId;
  final String supplierName;
  final Decimal quantityOrdered;
  final Decimal quantityReceived;
  final Decimal totalCost;

  ProductPurchaseLineDto({
    required this.itemId,
    required this.itemName,
    required this.itemUnit,
    this.supplierId,
    required this.supplierName,
    required this.quantityOrdered,
    required this.quantityReceived,
    required this.totalCost,
  });

  factory ProductPurchaseLineDto.fromJson(Map<String, dynamic> json) =>
      ProductPurchaseLineDto(
        itemId: json['item_id'] as String,
        itemName: json['item_name'] as String,
        itemUnit: json['item_unit'] as String? ?? '',
        supplierId: json['supplier_id'] as String?,
        supplierName: json['supplier_name'] as String,
        quantityOrdered: Decimal.parse(json['quantity_ordered'].toString()),
        quantityReceived: Decimal.parse(json['quantity_received'].toString()),
        totalCost: Decimal.parse(json['total_cost'].toString()),
      );
}

/// One manual correction (Stock Adjustment Report / Activity Log).
class StockAdjustmentLineDto {
  final String id;
  final String itemId;
  final String itemName;
  final Decimal quantityDelta;
  final String? reason;
  final String createdAt;

  StockAdjustmentLineDto({
    required this.id,
    required this.itemId,
    required this.itemName,
    required this.quantityDelta,
    this.reason,
    required this.createdAt,
  });

  factory StockAdjustmentLineDto.fromJson(Map<String, dynamic> json) =>
      StockAdjustmentLineDto(
        id: json['id'] as String,
        itemId: json['item_id'] as String,
        itemName: json['item_name'] as String,
        quantityDelta: Decimal.parse(json['quantity_delta'].toString()),
        reason: json['reason'] as String?,
        createdAt: json['created_at'] as String,
      );
}

/// One received batch (Lot Report): frozen receipt cost included.
class LotLineDto {
  final String lotNo;
  final String itemName;
  final Decimal quantityReceived;
  final Decimal unitCost;
  final Decimal totalCost;
  final String? supplierName;
  final String? expiryDate;

  LotLineDto({
    required this.lotNo,
    required this.itemName,
    required this.quantityReceived,
    Decimal? unitCost,
    Decimal? totalCost,
    this.supplierName,
    this.expiryDate,
  })  : unitCost = unitCost ?? Decimal.zero,
        totalCost = totalCost ?? Decimal.zero;

  factory LotLineDto.fromJson(Map<String, dynamic> json) {
    Decimal _opt(Object? v) => v == null ? Decimal.zero : Decimal.parse(v.toString());
    return LotLineDto(
      lotNo: json['lot_no'] as String,
      itemName: json['item_name'] as String,
      quantityReceived:
          Decimal.parse(json['quantity_received'].toString()),
      unitCost: _opt(json['unit_cost']),
      totalCost: _opt(json['total_cost']),
      supplierName: json['supplier_name'] as String?,
      expiryDate: json['expiry_date'] as String?,
    );
  }
}

/// One frozen receipt cost ("what did flour cost in March").
class CostHistoryLineDto {
  final String lotNo;
  final String itemName;
  final Decimal quantityReceived;
  final Decimal unitCost;
  final Decimal totalCost;
  final String? supplierName;
  final String receivedAt;

  CostHistoryLineDto({
    required this.lotNo,
    required this.itemName,
    required this.quantityReceived,
    required this.unitCost,
    required this.totalCost,
    this.supplierName,
    required this.receivedAt,
  });

  factory CostHistoryLineDto.fromJson(Map<String, dynamic> json) =>
      CostHistoryLineDto(
        lotNo: json['lot_no'] as String,
        itemName: json['item_name'] as String,
        quantityReceived:
            Decimal.parse(json['quantity_received'].toString()),
        unitCost: Decimal.parse(json['unit_cost'].toString()),
        totalCost: Decimal.parse(json['total_cost'].toString()),
        supplierName: json['supplier_name'] as String?,
        receivedAt: json['received_at'] as String,
      );
}

/// One supplier's received purchase value (Supplier & Customer Report).
class SupplierPurchaseLineDto {
  final String supplierId;
  final String supplierName;
  final int ordersCount;
  final Decimal totalReceived;

  SupplierPurchaseLineDto({
    required this.supplierId,
    required this.supplierName,
    required this.ordersCount,
    required this.totalReceived,
  });

  factory SupplierPurchaseLineDto.fromJson(Map<String, dynamic> json) =>
      SupplierPurchaseLineDto(
        supplierId: json['supplier_id'] as String,
        supplierName: json['supplier_name'] as String,
        ordersCount: json['orders_count'] as int,
        totalReceived: Decimal.parse(json['total_received'].toString()),
      );
}

/// One auditable event (Activity Log).
class ActivityLogLineDto {
  final String itemName;
  final String movementType;
  final Decimal quantityDelta;
  final String createdAt;

  ActivityLogLineDto({
    required this.itemName,
    required this.movementType,
    required this.quantityDelta,
    required this.createdAt,
  });

  factory ActivityLogLineDto.fromJson(Map<String, dynamic> json) =>
      ActivityLogLineDto(
        itemName: json['item_name'] as String,
        movementType: json['movement_type'] as String,
        quantityDelta: Decimal.parse(json['quantity_delta'].toString()),
        createdAt: json['created_at'] as String,
      );
}

class InventoryApiService {
  const InventoryApiService({required this._dio});

  final Dio _dio;

  CatalogItemDto _itemFromJson(Map<String, dynamic> item) => CatalogItemDto(
        id: item['id'] as String,
        businessId: item['business_id'] as String,
        storeId: item['store_id'] as String,
        name: item['name'] as String,
        unitId: item['unit_id'] as String?,
        category: item['category_id'] as String?,
        supplierId: item['supplier_id'] as String?,
        reorderThreshold: Decimal.parse(item['reorder_threshold'].toString()),
        reorderQuantity: Decimal.parse(item['reorder_quantity'].toString()),
        sellingPrice: item['selling_price'] != null
            ? Decimal.parse(item['selling_price'].toString())
            : null,
        unitCost:
            item['unit_cost'] != null ? Decimal.parse(item['unit_cost'].toString()) : null,
        allowNegativeStock: item['allow_negative_stock'] as bool? ?? false,
        itemType: item['item_type'] as String,
        isActive: item['is_active'] as bool? ?? true,
        createdAt: DateTime.parse(item['created_at'] as String),
        updatedAt: DateTime.parse(item['updated_at'] as String),
        imageUrl: item['image_url'] as String?,
      );

  Never _rethrowAsInventoryError(DioException e) {
    final detail = e.response?.data is Map
        ? (e.response?.data as Map)['detail']
        : null;
    throw InventoryApiException(
      detail?.toString() ?? e.message ?? 'Request failed',
      e.response?.statusCode,
    );
  }

  /// Creates a new item. Requires `inventory.items.create`.
  /// [initialQuantity] is the opening on-hand stock — sent as
  /// `initial_quantity` so the backend can create the stock level +
  /// audit movement atomically with the item.
  Future<CatalogItemDto> createItem({
    required String businessId,
    required String storeId,
    required String name,
    required String unitId,
    required String itemType,
    required Decimal reorderThreshold,
    required Decimal reorderQuantity,
    String? categoryId,
    Decimal? sellingPrice,
    Decimal? unitCost,
    bool allowNegativeStock = false,
    Decimal? initialQuantity,
  }) async {
    try {
      final response = await _dio.post(
        InventoryApiPaths.items(businessId),
        data: {
          'store_id': storeId,
          'name': name,
          'unit_id': unitId,
          'item_type': itemType,
          'reorder_threshold': reorderThreshold.toString(),
          'reorder_quantity': reorderQuantity.toString(),
          if (categoryId != null) 'category_id': categoryId,
          if (sellingPrice != null) 'selling_price': sellingPrice.toString(),
          if (unitCost != null) 'unit_cost': unitCost.toString(),
          'allow_negative_stock': allowNegativeStock,
          if (initialQuantity != null)
            'initial_quantity': initialQuantity.toString(),
        },
      );
      return _itemFromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      _rethrowAsInventoryError(e);
    }
  }

  /// Updates mutable fields on an item (partial update). Requires
  /// `inventory.items.update`. Only non-null parameters are sent.
  Future<CatalogItemDto> updateItem({
    required String businessId,
    required String itemId,
    String? name,
    String? unitId,
    String? categoryId,
    Decimal? reorderThreshold,
    Decimal? reorderQuantity,
    Decimal? sellingPrice,
    Decimal? unitCost,
    bool? allowNegativeStock,
    String? itemType,
  }) async {
    try {
      final response = await _dio.patch(
        InventoryApiPaths.item(businessId, itemId),
        data: {
          if (name != null) 'name': name,
          if (unitId != null) 'unit_id': unitId,
          if (categoryId != null) 'category_id': categoryId,
          if (reorderThreshold != null) 'reorder_threshold': reorderThreshold.toString(),
          if (reorderQuantity != null) 'reorder_quantity': reorderQuantity.toString(),
          if (sellingPrice != null) 'selling_price': sellingPrice.toString(),
          if (unitCost != null) 'unit_cost': unitCost.toString(),
          if (allowNegativeStock != null) 'allow_negative_stock': allowNegativeStock,
          if (itemType != null) 'item_type': itemType,
        },
      );
      return _itemFromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      _rethrowAsInventoryError(e);
    }
  }

  /// Soft-deactivates an item. Requires `inventory.items.deactivate`.
  Future<void> deactivateItem({
    required String businessId,
    required String itemId,
  }) async {
    try {
      await _dio.delete(InventoryApiPaths.item(businessId, itemId));
    } on DioException catch (e) {
      _rethrowAsInventoryError(e);
    }
  }

  /// Uploads (or replaces) an item's product photo. Requires
  /// `inventory.items.update`. JPEG, PNG, or WebP up to `AppLimits.imageMaxBytes` —
  /// matching what the backend accepts and what the picker advertises.
  Future<CatalogItemDto> uploadItemImage({
    required String businessId,
    required String itemId,
    required String filename,
    required List<int> bytes,
  }) async {
    try {
      final form = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: filename),
      });
      final response = await _dio.put(
        InventoryApiPaths.itemImage(businessId, itemId),
        data: form,
      );
      return _itemFromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      _rethrowAsInventoryError(e);
    }
  }

  /// Removes an item's product photo (idempotent). Requires
  /// `inventory.items.update`.
  Future<CatalogItemDto> deleteItemImage({
    required String businessId,
    required String itemId,
  }) async {
    try {
      final response = await _dio.delete(
        InventoryApiPaths.itemImage(businessId, itemId),
      );
      return _itemFromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      _rethrowAsInventoryError(e);
    }
  }

  /// Downloads an item's product photo bytes. Requires `inventory.view`.
  /// Callers cache the bytes themselves (see `itemPhotoProvider`) — this
  /// is a plain fetch, so every display site doesn't re-solve auth.
  Future<List<int>> fetchItemImageBytes({
    required String businessId,
    required String itemId,
  }) async {
    try {
      final response = await _dio.get(
        InventoryApiPaths.itemImage(businessId, itemId),
        options: Options(responseType: ResponseType.bytes),
      );
      return (response.data as List<dynamic>).cast<int>();
    } on DioException catch (e) {
      _rethrowAsInventoryError(e);
    }
  }

  /// Manually adjusts stock by a positive or negative delta. Requires
  /// `inventory.adjust`. [reason] must be at least `AppLimits.adjustReasonMinLength`
  /// characters — the backend rejects anything shorter with a 422.
  Future<StockMovementDto> adjustStock({
    required String businessId,
    required String itemId,
    required Decimal quantityDelta,
    required String reason,
  }) async {
    try {
      final response = await _dio.post(
        InventoryApiPaths.itemAdjust(businessId, itemId),
        data: {'quantity_delta': quantityDelta.toString(), 'reason': reason},
      );
      return StockMovementDto.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      _rethrowAsInventoryError(e);
    }
  }

  /// Records wasted/spoiled stock. Requires `inventory.waste.record`.
  /// [quantity] must be positive — the backend negates it internally.
  Future<StockMovementDto> recordWaste({
    required String businessId,
    required String itemId,
    required Decimal quantity,
    required String reason,
  }) async {
    try {
      final response = await _dio.post(
        InventoryApiPaths.itemWaste(businessId, itemId),
        data: {'quantity': quantity.toString(), 'reason': reason},
      );
      return StockMovementDto.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      _rethrowAsInventoryError(e);
    }
  }

  /// Transfers stock between two stores within the same business. Requires
  /// `inventory.transfer`. [sourceStoreId] and [destinationStoreId] must
  /// differ — the backend rejects a self-transfer with a 422.
  Future<List<StockMovementDto>> transferStock({
    required String businessId,
    required String itemId,
    required String sourceStoreId,
    required String destinationStoreId,
    required Decimal quantity,
  }) async {
    try {
      final response = await _dio.post(
        InventoryApiPaths.transfer(businessId),
        data: {
          'item_id': itemId,
          'source_store_id': sourceStoreId,
          'destination_store_id': destinationStoreId,
          'quantity': quantity.toString(),
        },
      );
      return (response.data as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(StockMovementDto.fromJson)
          .toList();
    } on DioException catch (e) {
      _rethrowAsInventoryError(e);
    }
  }

  /// Recommends every grocery amount for a target output (no stock change).
  /// Requires `production.create`. Each line stays adjustable before commit.
  Future<ProductionPlanDto> planProduction({
    required String businessId,
    required String recipeId,
    required Decimal targetOutputQuantity,
  }) async {
    try {
      final response = await _dio.post(
        InventoryApiPaths.planProduction(businessId, recipeId),
        data: {
          'target_output_quantity': targetOutputQuantity.toString(),
        },
      );
      return ProductionPlanDto.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      _rethrowAsInventoryError(e);
    }
  }

  /// Records a production run against a recipe. Requires `production.create`.
  ///
  /// Two flows: omit [targetOutputQuantity]/[components] for the classic
  /// leading-ingredient ratio; send both for the target flow (goal + the
  /// adjustable measured amounts, one per ingredient). [actualOutputQuantity]
  /// is optional — omit it and the server commits the suggestion.
  /// [yieldTolerancePercent] sets the ±"met plan" band (default 5%).
  Future<ProductionEventDto> recordProduction({
    required String businessId,
    required String recipeId,
    required String leadingItemId,
    required Decimal leadingQuantityUsed,
    Decimal? targetOutputQuantity,
    List<MeasuredComponentInput>? components,
    Decimal? actualOutputQuantity,
    Decimal? yieldTolerancePercent,
  }) async {
    try {
      final response = await _dio.post(
        InventoryApiPaths.produce(businessId, recipeId),
        data: {
          'leading_item_id': leadingItemId,
          'leading_quantity_used': leadingQuantityUsed.toString(),
          if (targetOutputQuantity != null)
            'target_output_quantity': targetOutputQuantity.toString(),
          if (components != null)
            'components': [for (final c in components) c.toJson()],
          if (actualOutputQuantity != null)
            'actual_output_quantity': actualOutputQuantity.toString(),
          if (yieldTolerancePercent != null)
            'yield_tolerance_percent': yieldTolerancePercent.toString(),
        },
      );
      return ProductionEventDto.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      _rethrowAsInventoryError(e);
    }
  }

  /// Lists production history, newest first. Requires `production.view`.
  /// [from]/[to] are calendar dates (inclusive) on the event's occurred time.
  Future<List<ProductionEventDto>> fetchProductionEvents({
    required String businessId,
    DateTime? from,
    DateTime? to,
    int limit = AppLimits.catalogFetchPageSize,
    int offset = 0,
  }) async {
    try {
      final response = await _dio.get(
        InventoryApiPaths.productionEvents(businessId),
        queryParameters: {
          if (from != null) 'from': _isoDate(from),
          if (to != null) 'to': _isoDate(to),
          'limit': limit,
          'offset': offset,
        },
      );
      return (response.data as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(ProductionEventDto.fromJson)
          .toList();
    } on DioException catch (e) {
      _rethrowAsInventoryError(e);
    }
  }

  /// Full detail for one production event. Requires `production.view`.
  Future<ProductionEventDto> fetchProductionEvent({
    required String businessId,
    required String eventId,
  }) async {
    try {
      final response = await _dio.get(
        InventoryApiPaths.productionEvent(businessId, eventId),
      );
      return ProductionEventDto.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      _rethrowAsInventoryError(e);
    }
  }

  static String _isoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  /// Lists this business's recipes with resolved ingredients.
  /// Requires `recipes.view`.
  Future<List<RecipeDto>> fetchRecipes({
    required String businessId,
    int limit = AppLimits.catalogFetchPageSize,
    int offset = 0,
  }) async {
    try {
      final response = await _dio.get(
        InventoryApiPaths.recipes(businessId),
        queryParameters: {'limit': limit, 'offset': offset},
      );
      return (response.data as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(RecipeDto.fromJson)
          .toList();
    } on DioException catch (e) {
      _rethrowAsInventoryError(e);
    }
  }

  /// Waste recorded in a window, per item with cost. Requires
  /// `reports.view`.
  Future<WasteSummaryDto> fetchWasteSummary({
    required String businessId,
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      final response = await _dio.get(
        InventoryApiPaths.wasteSummary(businessId),
        queryParameters: {
          if (from != null) 'from': _isoDate(from),
          if (to != null) 'to': _isoDate(to),
        },
      );
      return WasteSummaryDto.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      _rethrowAsInventoryError(e);
    }
  }

  /// Production runs in a window with suggested-vs-actual totals. Requires
  /// `reports.view`.
  Future<ProductionSummaryDto> fetchProductionSummary({
    required String businessId,
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      final response = await _dio.get(
        InventoryApiPaths.productionSummary(businessId),
        queryParameters: {
          if (from != null) 'from': _isoDate(from),
          if (to != null) 'to': _isoDate(to),
        },
      );
      return ProductionSummaryDto.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      _rethrowAsInventoryError(e);
    }
  }

  /// Current inventory value, total and by category. Requires
  /// `reports.view`. A snapshot — no window applies.
  Future<StockValuationDto> fetchStockValuation({
    required String businessId,
  }) async {
    try {
      final response = await _dio.get(
        InventoryApiPaths.stockValuation(businessId),
      );
      return StockValuationDto.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      _rethrowAsInventoryError(e);
    }
  }

  Map<String, dynamic> _reportWindow(DateTime? from, DateTime? to) => {
        if (from != null) 'from': _isoDate(from),
        if (to != null) 'to': _isoDate(to),
      };

  List<T> _lines<T>(
    Map<String, dynamic> data,
    T Function(Map<String, dynamic>) fromJson,
  ) =>
      (data['lines'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(fromJson)
          .toList();

  /// Product Purchase Report.
  Future<List<ProductPurchaseLineDto>> fetchProductPurchases({
    required String businessId,
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      final response = await _dio.get(
        InventoryApiPaths.productPurchases(businessId),
        queryParameters: _reportWindow(from, to),
      );
      return _lines(
        response.data as Map<String, dynamic>,
        ProductPurchaseLineDto.fromJson,
      );
    } on DioException catch (e) {
      _rethrowAsInventoryError(e);
    }
  }

  /// Stock Adjustment Report (business-wide manual corrections).
  Future<List<StockAdjustmentLineDto>> fetchStockAdjustments({
    required String businessId,
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      final response = await _dio.get(
        InventoryApiPaths.stockAdjustments(businessId),
        queryParameters: _reportWindow(from, to),
      );
      return _lines(
        response.data as Map<String, dynamic>,
        StockAdjustmentLineDto.fromJson,
      );
    } on DioException catch (e) {
      _rethrowAsInventoryError(e);
    }
  }

  /// Lot Report.
  Future<List<LotLineDto>> fetchLotReport({
    required String businessId,
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      final response = await _dio.get(
        InventoryApiPaths.lotReport(businessId),
        queryParameters: _reportWindow(from, to),
      );
      return _lines(
        response.data as Map<String, dynamic>,
        LotLineDto.fromJson,
      );
    } on DioException catch (e) {
      _rethrowAsInventoryError(e);
    }
  }

  /// Stock Expiry Report (lots expiring in the window).
  Future<List<LotLineDto>> fetchExpiryReport({
    required String businessId,
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      final response = await _dio.get(
        InventoryApiPaths.expiryReport(businessId),
        queryParameters: _reportWindow(from, to),
      );
      return _lines(
        response.data as Map<String, dynamic>,
        LotLineDto.fromJson,
      );
    } on DioException catch (e) {
      _rethrowAsInventoryError(e);
    }
  }

  /// Supplier & Customer Report (supplier leg).
  Future<List<SupplierPurchaseLineDto>> fetchSupplierPurchases({
    required String businessId,
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      final response = await _dio.get(
        InventoryApiPaths.supplierPurchases(businessId),
        queryParameters: _reportWindow(from, to),
      );
      return _lines(
        response.data as Map<String, dynamic>,
        SupplierPurchaseLineDto.fromJson,
      );
    } on DioException catch (e) {
      _rethrowAsInventoryError(e);
    }
  }

  /// Activity Log (inventory leg).
  Future<List<ActivityLogLineDto>> fetchActivityLog({
    required String businessId,
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      final response = await _dio.get(
        InventoryApiPaths.activityLog(businessId),
        queryParameters: _reportWindow(from, to),
      );
      return _lines(
        response.data as Map<String, dynamic>,
        ActivityLogLineDto.fromJson,
      );
    } on DioException catch (e) {
      _rethrowAsInventoryError(e);
    }
  }

  /// Cost history: frozen receipt costs over time (read-only price record).
  /// Requires `reports.view`.
  Future<List<CostHistoryLineDto>> fetchCostHistory({
    required String businessId,
    DateTime? from,
    DateTime? to,
    String? itemId,
    String? supplierId,
  }) async {
    try {
      final response = await _dio.get(
        InventoryApiPaths.costHistory(businessId),
        queryParameters: {
          ..._reportWindow(from, to),
          if (itemId != null) 'item_id': itemId,
          if (supplierId != null) 'supplier_id': supplierId,
        },
      );
      return _lines(
        response.data as Map<String, dynamic>,
        CostHistoryLineDto.fromJson,
      );
    } on DioException catch (e) {
      _rethrowAsInventoryError(e);
    }
  }

  /// Creates a recipe for a sellable item. Requires `recipes.create`.
  /// At least one component is required — the backend rejects an empty set.
  /// Component quantities are totals for [targetYieldQuantity] (batch).
  Future<RecipeDto> createRecipe({
    required String businessId,
    required String sellableItemId,
    String? name,
    String? category,
    Decimal? targetYieldQuantity,
    String? targetYieldUnit,
    required List<RecipeComponentInput> components,
  }) async {
    try {
      final response = await _dio.post(
        InventoryApiPaths.recipes(businessId),
        data: {
          'sellable_item_id': sellableItemId,
          if (name != null) 'name': name,
          if (category != null) 'category': category,
          if (targetYieldQuantity != null)
            'target_yield_quantity': targetYieldQuantity.toString(),
          if (targetYieldUnit != null) 'target_yield_unit': targetYieldUnit,
          'components': [for (final c in components) c.toJson()],
        },
      );
      return RecipeDto.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      _rethrowAsInventoryError(e);
    }
  }

  /// Replaces a recipe's component list as a full set (plus optional rename).
  /// Requires `recipes.update`. Lines absent from [components] are deleted.
  Future<RecipeDto> updateRecipe({
    required String businessId,
    required String recipeId,
    String? name,
    String? category,
    Decimal? targetYieldQuantity,
    String? targetYieldUnit,
    required List<RecipeComponentInput> components,
  }) async {
    try {
      final response = await _dio.patch(
        InventoryApiPaths.recipe(businessId, recipeId),
        data: {
          if (name != null) 'name': name,
          if (category != null) 'category': category,
          if (targetYieldQuantity != null)
            'target_yield_quantity': targetYieldQuantity.toString(),
          if (targetYieldUnit != null) 'target_yield_unit': targetYieldUnit,
          'components': [for (final c in components) c.toJson()],
        },
      );
      return RecipeDto.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      _rethrowAsInventoryError(e);
    }
  }

  /// Hard-deletes a recipe. Requires `recipes.delete`. Refused with a 409
  /// when production runs were recorded against it.
  Future<void> deleteRecipe({
    required String businessId,
    required String recipeId,
  }) async {
    try {
      await _dio.delete(InventoryApiPaths.recipe(businessId, recipeId));
    } on DioException catch (e) {
      _rethrowAsInventoryError(e);
    }
  }

  /// Schedules a batch (pending): snapshots the plan, moves no stock.
  /// Requires `production.create`.
  Future<RunDto> createRun({
    required String businessId,
    required String recipeId,
    required Decimal targetOutputQuantity,
    Decimal? yieldTolerancePercent,
  }) async {
    try {
      final response = await _dio.post(
        InventoryApiPaths.runs(businessId),
        data: {
          'recipe_id': recipeId,
          'target_output_quantity': targetOutputQuantity.toString(),
          if (yieldTolerancePercent != null)
            'yield_tolerance_percent': yieldTolerancePercent.toString(),
        },
      );
      return RunDto.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      _rethrowAsInventoryError(e);
    }
  }

  /// Lists scheduled batches, newest first, optionally by status.
  /// Requires `production.view`.
  Future<List<RunDto>> fetchRuns({
    required String businessId,
    RunStatusDto? status,
    int limit = AppLimits.catalogFetchPageSize,
    int offset = 0,
  }) async {
    try {
      final response = await _dio.get(
        InventoryApiPaths.runs(businessId),
        queryParameters: {
          if (status != null) 'status': status.apiValue,
          'limit': limit,
          'offset': offset,
        },
      );
      return (response.data as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(RunDto.fromJson)
          .toList();
    } on DioException catch (e) {
      _rethrowAsInventoryError(e);
    }
  }

  /// Full detail for one run. Requires `production.view`.
  Future<RunDto> fetchRun({
    required String businessId,
    required String runId,
  }) async {
    try {
      final response = await _dio.get(
        InventoryApiPaths.run(businessId, runId),
      );
      return RunDto.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      _rethrowAsInventoryError(e);
    }
  }

  /// Starts a pending run: deducts the weighed ingredients, instantly.
  /// Requires `production.create`. Omit [components] to weigh the plan
  /// exactly; pass the full adjusted list otherwise.
  Future<RunDto> startRun({
    required String businessId,
    required String runId,
    required String leadingItemId,
    required Decimal leadingQuantityUsed,
    List<MeasuredComponentInput>? components,
  }) async {
    try {
      final response = await _dio.post(
        InventoryApiPaths.runAction(businessId, runId, 'start'),
        data: {
          'leading_item_id': leadingItemId,
          'leading_quantity_used': leadingQuantityUsed.toString(),
          if (components != null)
            'components': [
              for (final c in components)
                {
                  'raw_material_item_id': c.rawMaterialItemId,
                  'quantity_used': c.quantityUsed.toString(),
                },
            ],
        },
      );
      return RunDto.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      _rethrowAsInventoryError(e);
    }
  }

  /// Completes an in-progress run: records actual yield + waste reason.
  /// Requires `production.create`. Moves no stock — publishing does that.
  Future<RunDto> completeRun({
    required String businessId,
    required String runId,
    required Decimal actualOutputQuantity,
    String? wasteReason,
  }) async {
    try {
      final response = await _dio.post(
        InventoryApiPaths.runAction(businessId, runId, 'complete'),
        data: {
          'actual_output_quantity': actualOutputQuantity.toString(),
          if (wasteReason != null && wasteReason.trim().isNotEmpty)
            'waste_reason': wasteReason.trim(),
        },
      );
      return RunDto.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      _rethrowAsInventoryError(e);
    }
  }

  /// Publishes a completed run: stocks the output, writes history + verdict.
  /// Requires `production.create`.
  Future<ProductionEventDto> publishRun({
    required String businessId,
    required String runId,
  }) async {
    try {
      final response = await _dio.post(
        InventoryApiPaths.runAction(businessId, runId, 'publish'),
      );
      return ProductionEventDto.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      _rethrowAsInventoryError(e);
    }
  }

  /// Deletes a pending run. Requires `production.create`.
  Future<void> deleteRun({
    required String businessId,
    required String runId,
  }) async {
    try {
      await _dio.delete(InventoryApiPaths.run(businessId, runId));
    } on DioException catch (e) {
      _rethrowAsInventoryError(e);
    }
  }
}
