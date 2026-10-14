"""Atomic multi-ingredient production transactions (Stage 2).

A production is the third kind of stock transaction: raw materials go DOWN
and a sellable item goes UP in one atomic action, driven by a Stage 1
recipe. The owner measures ONE leading ingredient; every other consumption
and the suggested output follow from the recipe ratio.

ATOMICITY CONTRACT: either every leg commits or none does. The function
writes nothing before the every-ingredient sufficiency check passes, so a
shortfall on any single ingredient rolls back the entire event by
construction — there is no partial-production state to clean up.

LOCKING CONTRACT (extends Stage 5's single-item ``SELECT ... FOR UPDATE``
rigor to N items): all affected ``Item`` rows are locked in ONE query
ordered by ``item_id``, then all affected ``StockLevel`` rows in the same
order. Two concurrent productions touching overlapping ingredients therefore
acquire locks in the same sequence and cannot deadlock — one waits, one
proceeds. The per-leg ``record_movement(commit=False)`` calls re-lock rows
this transaction already holds, which is a same-transaction no-op, not a
second acquisition.
"""

from __future__ import annotations

from decimal import Decimal
from typing import Any
from uuid import UUID

import structlog
from sqlmodel import select
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.events import publish_event
from app.models.inventory import (
    Item,
    ProductionEvent,
    ProductionEventComponent,
    Recipe,
    RecipeComponent,
    StockLevel,
)
from app.services.stock_movement_service import (
    InsufficientStockError,
    MovementType,
    record_movement,
)

logger = structlog.get_logger(__name__)


class RecipeNotFoundError(ValueError):
    """Raised when the recipe (or its sellable item) is not in this business."""


class InvalidProductionInputError(ValueError):
    """Raised when the production request itself is malformed.

    Leading ingredient not on the recipe, or a non-positive quantity — the
    caller sent something no ratio can be computed from.
    """


def per_unit_requirement(quantity_required: Decimal, target_yield: Decimal) -> Decimal:
    """One sellable unit's share of a batch-formula ingredient line.

    Components are totals for the recipe's target yield — divide through so
    ratio math, plans, and consumption all work per unit. A target of 1
    reproduces the original per-unit recipe exactly.
    """
    if target_yield <= Decimal("0"):
        raise InvalidProductionInputError(
            f"recipe target yield must be positive, got {target_yield}"
        )
    return quantity_required / target_yield


async def plan_production_quantities(
    db: AsyncSession,
    business_id: UUID,
    recipe_id: UUID,
    target_output_quantity: Decimal,
) -> tuple[Recipe, Item, list[tuple[RecipeComponent, Item]]]:
    """Recommend every grocery amount for a target output (no stock change).

    Each ingredient's planned quantity is ``quantity_required * target`` —
    the answer to "I need N products, how much should I measure?". The
    caller may adjust any line before committing via ``components`` on
    ``record_production_event``.
    """
    if target_output_quantity <= Decimal("0"):
        raise InvalidProductionInputError(
            f"target_output_quantity must be positive, got {target_output_quantity}"
        )
    result = await db.exec(
        select(Recipe).where(
            Recipe.id == recipe_id, Recipe.business_id == business_id
        )
    )
    recipe = result.one_or_none()
    if recipe is None:
        raise RecipeNotFoundError(
            f"Recipe '{recipe_id}' not found in this business"
        )
    comp_result = await db.exec(
        select(RecipeComponent).where(RecipeComponent.recipe_id == recipe.id)
    )
    components = list(comp_result.all())
    if not components:
        raise InvalidProductionInputError(
            f"Recipe '{recipe.name}' has no ingredients — cannot plan"
        )
    if recipe.sellable_item_id is None:
        raise InvalidProductionInputError(
            f"Recipe '{recipe.name}' is not linked to a menu item yet — "
            "link it before planning production"
        )
    sellable_result = await db.exec(
        select(Item).where(
            Item.id == recipe.sellable_item_id, Item.business_id == business_id
        )
    )
    sellable = sellable_result.one_or_none()
    if sellable is None:
        raise RecipeNotFoundError(
            f"Sellable item for recipe '{recipe.name}' no longer exists"
        )
    item_result = await db.exec(
        select(Item).where(
            Item.id.in_([c.raw_material_item_id for c in components]),
            Item.business_id == business_id,
        )
    )
    items = {item.id: item for item in item_result.all()}
    missing = [c for c in components if c.raw_material_item_id not in items]
    if missing:
        raise RecipeNotFoundError(
            f"Ingredient item for recipe '{recipe.name}' no longer exists"
        )
    return recipe, sellable, [(c, items[c.raw_material_item_id]) for c in components]


async def record_production_event(
    db: AsyncSession,
    business_id: UUID,
    recipe_id: UUID,
    leading_item_id: UUID,
    leading_quantity_used: Decimal,
    actual_output_quantity: Decimal | None = None,
    target_output_quantity: Decimal | None = None,
    components_override: dict[UUID, Decimal] | None = None,
    actor_type: str = "user",
    actor_id: UUID | None = None,
) -> ProductionEvent:
    """Record one production run atomically: consume ingredients, add output.

    Two flows share this commit path:

    * LEADING flow (``target_output_quantity=None``,
      ``components_override=None``): consumption follows the recipe ratio
      from the measured leading ingredient; the suggestion is that ratio.
    * TARGET flow (``target_output_quantity`` set): the cook entered a
      goal first and the app recommended ``quantity_required * target``
      per ingredient. The goal anchors the suggestion and the
      above/within/below-threshold verdict. Consumption comes from
      ``components_override`` when supplied (every line adjustable),
      else falls back to the leading ratio.

    Parameters
    ----------
    target_output_quantity : Decimal | None
        Goal entered before measuring ("I need N products"). Stored on
        the event and used as the yield goal; ``None`` preserves the
        original leading-only behaviour.
    components_override : dict[UUID, Decimal] | None
        Owner-adjusted measured amounts keyed by raw material id. Must
        cover the whole recipe exactly once (including the leading
        ingredient, whose entry must equal ``leading_quantity_used``);
        every value strictly positive.

    Raises
    ------
    RecipeNotFoundError
        Recipe (or its sellable item) is not part of this business.
    InvalidProductionInputError
        Leading ingredient is not on the recipe, a quantity is not
        strictly positive, or the override set does not match the recipe.
    InsufficientStockError
        Any ingredient would go negative without ``allow_negative_stock``.
        Nothing has been written when this raises — the event fails whole.
    """
    if leading_quantity_used <= Decimal("0"):
        raise InvalidProductionInputError(
            f"leading_quantity_used must be positive, got {leading_quantity_used}"
        )
    if target_output_quantity is not None and target_output_quantity <= Decimal("0"):
        raise InvalidProductionInputError(
            f"target_output_quantity must be positive, got {target_output_quantity}"
        )

    # ── Step 1: load recipe + components, all business-scoped ──────────
    result = await db.exec(
        select(Recipe).where(
            Recipe.id == recipe_id, Recipe.business_id == business_id
        )
    )
    recipe = result.one_or_none()
    if recipe is None:
        raise RecipeNotFoundError(
            f"Recipe '{recipe_id}' not found in this business"
        )
    if recipe.sellable_item_id is None:
        raise InvalidProductionInputError(
            f"Recipe '{recipe.name}' is not linked to a menu item yet — "
            "link it before recording production"
        )

    comp_result = await db.exec(
        select(RecipeComponent).where(RecipeComponent.recipe_id == recipe.id)
    )
    components = list(comp_result.all())

    leading_batch_requirement: Decimal | None = None
    for comp in components:
        if comp.raw_material_item_id == leading_item_id:
            leading_batch_requirement = comp.quantity_required
    if leading_batch_requirement is None:
        raise InvalidProductionInputError(
            f"Item '{leading_item_id}' is not an ingredient of recipe '{recipe.name}' — "
            "the measured ingredient must be one of the recipe's components"
        )
    # Batch semantics: components are totals for the target yield — the
    # ratio works on per-unit shares (a target of 1 is the old behaviour).
    leading_requirement = per_unit_requirement(
        leading_batch_requirement, recipe.target_yield_quantity
    )

    # ── Step 2: ratio math (Decimal throughout — never float) ──────────
    # One recipe makes ONE unit of output, so the ratio doubles as the
    # suggested output count: 2000g used ÷ 200g per plate = 10 plates.
    # In the TARGET flow the entered goal anchors the suggestion instead;
    # consumption still comes from the adjustable override when supplied,
    # else from the leading ratio (plan endpoint tells the client what to
    # send as the override).
    ratio = leading_quantity_used / leading_requirement
    suggested_output = (
        target_output_quantity if target_output_quantity is not None else ratio
    )
    actual_output = (
        suggested_output if actual_output_quantity is None else actual_output_quantity
    )
    if actual_output <= Decimal("0"):
        raise InvalidProductionInputError(
            f"actual_output_quantity must be positive, got {actual_output}"
        )

    if components_override is not None:
        recipe_ids = {c.raw_material_item_id for c in components}
        override_ids = set(components_override.keys())
        if override_ids != recipe_ids:
            raise InvalidProductionInputError(
                "components must cover the whole recipe exactly once — "
                f"recipe has {len(recipe_ids)} ingredients, "
                f"got {len(override_ids)}"
            )
        for raw_id, qty in components_override.items():
            if qty <= Decimal("0"):
                raise InvalidProductionInputError(
                    f"components quantity for '{raw_id}' must be positive, got {qty}"
                )
        if components_override[leading_item_id] != leading_quantity_used:
            raise InvalidProductionInputError(
                "components entry for the leading ingredient must equal "
                "leading_quantity_used — adjust both together"
            )
        consumption: dict[UUID, Decimal] = dict(components_override)
    else:
        # Every other ingredient scales by the same ratio; the leading row
        # is the measured value exactly, so weighing error never compounds.
        consumption = {}
        for comp in components:
            if comp.raw_material_item_id == leading_item_id:
                consumption[comp.raw_material_item_id] = leading_quantity_used
            else:
                consumption[comp.raw_material_item_id] = (
                    per_unit_requirement(
                        comp.quantity_required, recipe.target_yield_quantity
                    )
                    * ratio
                )

    # ── Step 3: production site = the sellable item's store ────────────
    # The output level lives at the sellable's store, so inputs are drawn
    # there too. A component stocked only elsewhere reads as 0 here (and
    # 409s unless it allows negative stock) — the correct physical answer,
    # not a cross-store transfer, which is a separate operation.
    sellable_result = await db.exec(
        select(Item).where(
            Item.id == recipe.sellable_item_id, Item.business_id == business_id
        )
    )
    sellable = sellable_result.one_or_none()
    if sellable is None:
        raise RecipeNotFoundError(
            f"Sellable item for recipe '{recipe.name}' no longer exists"
        )
    store_id = sellable.store_id

    # ── Step 4: lock everything, in item_id order (deadlock-safe) ──────
    locked_ids = sorted(
        [sellable.id, *consumption.keys()], key=str
    )
    item_result = await db.exec(
        select(Item).where(Item.id.in_(locked_ids)).order_by(Item.id).with_for_update()
    )
    items = {item.id: item for item in item_result.all()}

    level_result = await db.exec(
        select(StockLevel)
        .where(
            StockLevel.item_id.in_(locked_ids),
            StockLevel.store_id == store_id,
        )
        .order_by(StockLevel.item_id)
        .with_for_update()
    )
    levels = {level.item_id: level for level in level_result.all()}

    # ── Step 5: every-ingredient sufficiency BEFORE any write ──────────
    for raw_id, needed in consumption.items():
        current = (
            levels[raw_id].current_quantity
            if raw_id in levels
            else Decimal("0.000")
        )
        if (
            current - needed < Decimal("0.000")
            and not items[raw_id].allow_negative_stock
        ):
            raise InsufficientStockError(
                f"Insufficient stock for item '{items[raw_id].name}' at store "
                f"'{store_id}': current={current}, "
                f"production needs {needed} — entire event rejected, "
                "nothing was written"
            )

    # ── Step 6: write event + component rows + movement legs, one txn ──
    event = ProductionEvent(
        business_id=business_id,
        store_id=store_id,
        recipe_id=recipe.id,
        leading_component_item_id=leading_item_id,
        leading_quantity_used=leading_quantity_used,
        target_output_quantity=target_output_quantity,
        suggested_output_quantity=suggested_output,
        actual_output_quantity=actual_output,
        actor_id=actor_id,
    )
    db.add(event)
    await db.flush()  # event.id needed for component + movement references

    for raw_id, needed in consumption.items():
        db.add(
            ProductionEventComponent(
                production_event_id=event.id,
                raw_material_item_id=raw_id,
                quantity_consumed=needed,
            )
        )

    # Legs reuse record_movement (not duplicated): per-leg locks are
    # already held by this transaction, its negative-stock check is a
    # backstop to Step 5, and commit=False keeps everything in OUR
    # transaction (it also publishes nothing — production emits its own
    # events in Step 7, not per-leg stock.adjusted noise).
    try:
        for raw_id, needed in consumption.items():
            await record_movement(
                db=db,
                item_id=raw_id,
                business_id=business_id,
                store_id=store_id,
                quantity_delta=-needed,
                movement_type=MovementType.PRODUCTION_INPUT,
                reference_type="production_event",
                reference_id=event.id,
                actor_type=actor_type,
                actor_id=actor_id,
                reason=f"Production {event.id} ({recipe.name})",
                commit=False,
            )
        # The sellable leg uses the OWNER-CONFIRMED quantity — that is the
        # real stock effect; the suggestion is recorded, not stocked.
        await record_movement(
            db=db,
            item_id=sellable.id,
            business_id=business_id,
            store_id=store_id,
            quantity_delta=actual_output,
            movement_type=MovementType.PRODUCTION_OUTPUT,
            reference_type="production_event",
            reference_id=event.id,
            actor_type=actor_type,
            actor_id=actor_id,
            reason=f"Production {event.id} ({recipe.name})",
            commit=False,
        )
        await db.commit()
        await db.refresh(event)
    except Exception:
        await db.rollback()
        raise

    # Read back what the database actually stored (NUMERIC scale
    # normalization: 2.000/0.200 divides to Decimal('10') in memory but
    # persists as 10.000) so the published payloads — the future AI
    # insights feed — carry stored values, not float-shaped locals.

    # ── Step 7: post-commit events (recorded, not stocked, quantities) ──
    production_payload: dict[str, Any] = {
        "event_id": str(event.id),
        "recipe_id": str(recipe.id),
        "business_id": str(business_id),
        "store_id": str(store_id),
        "leading_item_id": str(leading_item_id),
        "leading_quantity_used": str(event.leading_quantity_used),
        "target_output_quantity": (
            str(event.target_output_quantity)
            if event.target_output_quantity is not None
            else None
        ),
        "suggested_output_quantity": str(event.suggested_output_quantity),
        "actual_output_quantity": str(event.actual_output_quantity),
    }
    await publish_event("production.recorded", production_payload)

    audit_payload: dict[str, Any] = {
        "actor_id": str(actor_id) if actor_id else None,
        "business_id": str(business_id),
        "action": "production.recorded",
        "resource_type": "production_event",
        "resource_id": str(event.id),
        "details": {
            "recipe_id": str(recipe.id),
            "target_output_quantity": (
                str(event.target_output_quantity)
                if event.target_output_quantity is not None
                else None
            ),
            "suggested_output_quantity": str(event.suggested_output_quantity),
            "actual_output_quantity": str(event.actual_output_quantity),
        },
    }
    await publish_event("audit.recorded", audit_payload)

    logger.info(
        "production.recorded",
        event_id=str(event.id),
        business_id=str(business_id),
        recipe_id=str(recipe.id),
        suggested=str(suggested_output),
        actual=str(actual_output),
    )
    return event
