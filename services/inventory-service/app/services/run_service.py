"""Scheduled production runs: plan → start → complete → publish.

A run separates the stock effects a direct ``record_production_event``
commits atomically:

* create (pending) — snapshot the plan, move nothing;
* start (in_progress) — deduct the measured (adjustable) inputs;
* complete (completed) — record actual yield + waste/variance reason;
* publish — stock the output ("Publish to POS & Inventory"), write the
  immutable ``ProductionEvent`` history row linked via ``run_id``, and
  stamp ``published_at``. POS availability follows inventory stock, so
  the published output is immediately sellable.

LOCKING CONTRACT (same as ``production_service``): all affected ``Item``
rows are locked in ONE query ordered by ``item_id``, then all affected
``StockLevel`` rows in the same order — concurrent starts touching
overlapping ingredients serialize instead of deadlocking.
"""

from __future__ import annotations

from datetime import UTC, datetime
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
    ProductionRun,
    ProductionRunComponent,
    Recipe,
    RecipeComponent,
    RunStatus,
    StockLevel,
)
from app.services.production_service import (
    InvalidProductionInputError,
    RecipeNotFoundError,
    per_unit_requirement,
)
from app.services.stock_movement_service import (
    InsufficientStockError,
    MovementType,
    record_movement,
)

logger = structlog.get_logger(__name__)


class RunNotFoundError(ValueError):
    """Raised when the run is not in this business."""


class InvalidRunStateError(ValueError):
    """Raised when the transition is illegal for the run's status.

    Starting a started run, completing a pending one, publishing twice —
    the run's status is the state machine and this is its guard.
    """


async def _load_recipe(
    db: AsyncSession, business_id: UUID, recipe_id: UUID
) -> tuple[Recipe, list[RecipeComponent], Item]:
    """Fetch recipe + components + sellable, all business-scoped."""
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
            f"Recipe '{recipe.name}' has no ingredients — cannot plan a run"
        )
    if recipe.sellable_item_id is None:
        raise InvalidProductionInputError(
            f"Recipe '{recipe.name}' is not linked to a menu item yet — "
            "link it before planning a production run"
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
    return recipe, components, sellable


async def create_run(
    db: AsyncSession,
    business_id: UUID,
    recipe_id: UUID,
    target_output_quantity: Decimal,
    yield_tolerance_percent: Decimal = Decimal("5"),
    actor_id: UUID | None = None,
    idempotency_key: str | None = None,
) -> ProductionRun:
    """Schedule a batch (pending): snapshot the plan, move no stock.

    Each planned line is the per-unit requirement × target — the same
    recommendation the plan endpoint computes, frozen onto the run so
    recipe edits never rewrite a cook's shift plan.
    """
    if target_output_quantity <= Decimal("0"):
        raise InvalidProductionInputError(
            f"target_output_quantity must be positive, got {target_output_quantity}"
        )
    if idempotency_key:
        existing = await db.exec(
            select(ProductionRun).where(
                ProductionRun.business_id == business_id,
                ProductionRun.idempotency_key == idempotency_key,
            )
        )
        found = existing.one_or_none()
        if found is not None:
            return found
    recipe, components, sellable = await _load_recipe(db, business_id, recipe_id)

    run = ProductionRun(
        business_id=business_id,
        store_id=sellable.store_id,
        recipe_id=recipe.id,
        target_output_quantity=target_output_quantity,
        status=RunStatus.PENDING,
        yield_tolerance_percent=yield_tolerance_percent,
        created_by=actor_id,
        idempotency_key=idempotency_key,
    )
    db.add(run)
    await db.flush()
    for comp in components:
        planned = (
            per_unit_requirement(comp.quantity_required, recipe.target_yield_quantity)
            * target_output_quantity
        ).quantize(Decimal("0.001"))
        db.add(
            ProductionRunComponent(
                production_run_id=run.id,
                raw_material_item_id=comp.raw_material_item_id,
                planned_quantity=planned,
            )
        )
    await db.commit()
    await db.refresh(run)

    await publish_event(
        "production.run_created",
        {
            "run_id": str(run.id),
            "recipe_id": str(recipe.id),
            "business_id": str(business_id),
            "store_id": str(run.store_id),
            "target_output_quantity": str(target_output_quantity),
        },
    )
    logger.info(
        "production.run_created",
        run_id=str(run.id),
        business_id=str(business_id),
        recipe_id=str(recipe.id),
        target=str(target_output_quantity),
    )
    return run


async def _get_run_or_404(
    db: AsyncSession, business_id: UUID, run_id: UUID
) -> ProductionRun:
    result = await db.exec(
        select(ProductionRun).where(
            ProductionRun.id == run_id, ProductionRun.business_id == business_id
        )
    )
    run = result.one_or_none()
    if run is None:
        raise RunNotFoundError(
            f"Production run '{run_id}' not found in this business"
        )
    return run


async def start_run(
    db: AsyncSession,
    business_id: UUID,
    run_id: UUID,
    leading_item_id: UUID,
    leading_quantity_used: Decimal,
    components_override: dict[UUID, Decimal] | None = None,
    actor_id: UUID | None = None,
) -> ProductionRun:
    """Start a pending run: deduct the weighed ingredients.

    ``components_override`` carries the cook's adjustments (full recipe
    coverage, leading line equal to ``leading_quantity_used``); omit it
    and the snapshotted plan is weighed exactly. Either every leg commits
    or none does — a shortfall on any ingredient rejects the whole start.
    Output is NOT stocked here; publishing does that.
    """
    if leading_quantity_used <= Decimal("0"):
        raise InvalidProductionInputError(
            f"leading_quantity_used must be positive, got {leading_quantity_used}"
        )
    run = await _get_run_or_404(db, business_id, run_id)
    if run.status != RunStatus.PENDING:
        raise InvalidRunStateError(
            f"Run '{run_id}' is {run.status.value} — only pending runs can start"
        )

    recipe, components, _ = await _load_recipe(db, business_id, run.recipe_id)
    recipe_ids = {c.raw_material_item_id for c in components}
    if leading_item_id not in recipe_ids:
        raise InvalidProductionInputError(
            f"Item '{leading_item_id}' is not an ingredient of recipe '{recipe.name}'"
        )

    comp_result = await db.exec(
        select(ProductionRunComponent).where(
            ProductionRunComponent.production_run_id == run.id
        )
    )
    snap = {c.raw_material_item_id: c for c in comp_result.all()}

    if components_override is not None:
        if set(components_override.keys()) != recipe_ids:
            raise InvalidProductionInputError(
                "components must cover the whole recipe exactly once — "
                f"recipe has {len(recipe_ids)} ingredients, "
                f"got {len(components_override)}"
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
        measured: dict[UUID, Decimal] = dict(components_override)
    else:
        measured = {raw_id: c.planned_quantity for raw_id, c in snap.items()}
        # The snapshot was planned from the same ratio the leading anchor
        # implies; keep the measured leading value exactly so weighing
        # error never compounds through a recompute.
        measured[leading_item_id] = leading_quantity_used

    store_id = run.store_id
    locked_ids = sorted(measured.keys(), key=str)
    item_result = await db.exec(
        select(Item).where(Item.id.in_(locked_ids)).order_by(Item.id).with_for_update()
    )
    items = {item.id: item for item in item_result.all()}
    level_result = await db.exec(
        select(StockLevel)
        .where(StockLevel.item_id.in_(locked_ids), StockLevel.store_id == store_id)
        .order_by(StockLevel.item_id)
        .with_for_update()
    )
    levels = {level.item_id: level for level in level_result.all()}

    for raw_id, needed in measured.items():
        current = levels[raw_id].current_quantity if raw_id in levels else Decimal("0.000")
        if current - needed < Decimal("0.000") and not items[raw_id].allow_negative_stock:
            raise InsufficientStockError(
                f"Insufficient stock for item '{items[raw_id].name}' at store "
                f"'{store_id}': current={current}, run needs {needed} — "
                "entire start rejected, nothing was written"
            )

    try:
        for raw_id, needed in measured.items():
            await record_movement(
                db=db,
                item_id=raw_id,
                business_id=business_id,
                store_id=store_id,
                quantity_delta=-needed,
                movement_type=MovementType.PRODUCTION_INPUT,
                reference_type="production_run",
                reference_id=run.id,
                actor_id=actor_id,
                reason=f"Production run {run.id} started ({recipe.name})",
                commit=False,
            )
        for raw_id, row in snap.items():
            row.measured_quantity = measured[raw_id]
            db.add(row)
        run.leading_component_item_id = leading_item_id
        run.status = RunStatus.IN_PROGRESS
        run.started_at = datetime.now(UTC)
        db.add(run)
        await db.commit()
        await db.refresh(run)
    except Exception:
        await db.rollback()
        raise

    await publish_event(
        "production.run_started",
        {
            "run_id": str(run.id),
            "recipe_id": str(run.recipe_id),
            "business_id": str(business_id),
            "store_id": str(store_id),
            "leading_item_id": str(leading_item_id),
            "leading_quantity_used": str(leading_quantity_used),
        },
    )
    logger.info("production.run_started", run_id=str(run.id), business_id=str(business_id))
    return run


async def complete_run(
    db: AsyncSession,
    business_id: UUID,
    run_id: UUID,
    actual_output_quantity: Decimal,
    waste_reason: str | None = None,
) -> ProductionRun:
    """Finish an in-progress run: record actual yield + waste reason.

    No stock moves — the output lands in inventory at publish. The actual
    may differ from the target (portions came out bigger/smaller); the
    verdict is computed from it at publish time.
    """
    if actual_output_quantity <= Decimal("0"):
        raise InvalidProductionInputError(
            f"actual_output_quantity must be positive, got {actual_output_quantity}"
        )
    run = await _get_run_or_404(db, business_id, run_id)
    if run.status != RunStatus.IN_PROGRESS:
        raise InvalidRunStateError(
            f"Run '{run_id}' is {run.status.value} — only in-progress runs can complete"
        )
    if waste_reason is not None and not waste_reason.strip():
        waste_reason = None

    run.actual_output_quantity = actual_output_quantity
    run.waste_reason = waste_reason
    run.status = RunStatus.COMPLETED
    run.completed_at = datetime.now(UTC)
    db.add(run)
    await db.commit()
    await db.refresh(run)

    await publish_event(
        "production.run_completed",
        {
            "run_id": str(run.id),
            "recipe_id": str(run.recipe_id),
            "business_id": str(business_id),
            "actual_output_quantity": str(actual_output_quantity),
            "waste_reason": waste_reason,
        },
    )
    logger.info(
        "production.run_completed",
        run_id=str(run.id),
        business_id=str(business_id),
        actual=str(actual_output_quantity),
    )
    return run


async def publish_run(
    db: AsyncSession,
    business_id: UUID,
    run_id: UUID,
    actor_id: UUID | None = None,
) -> ProductionEvent:
    """Publish a completed run: stock the output + write history.

    The "one-click conversion": the confirmed output is added to the
    sellable's stock (immediately sellable on the POS, which reads
    inventory), and an immutable ``ProductionEvent`` linked via
    ``run_id`` records inputs, target, actual, verdict inputs, and the
    waste reason. Inputs are NOT deducted again — starting did that.
    """
    run = await _get_run_or_404(db, business_id, run_id)
    if run.status != RunStatus.COMPLETED:
        # Safe retry: tapping Publish twice returns the same record.
        if run.published_at is not None:
            existing = await db.exec(
                select(ProductionEvent).where(ProductionEvent.run_id == run.id)
            )
            found = existing.one_or_none()
            if found is not None:
                return found
        raise InvalidRunStateError(
            f"Run '{run_id}' is {run.status.value} — only completed runs can publish"
        )
    if run.published_at is not None:
        existing = await db.exec(
            select(ProductionEvent).where(ProductionEvent.run_id == run.id)
        )
        found = existing.one_or_none()
        if found is not None:
            return found
        raise InvalidRunStateError(f"Run '{run_id}' is already published")
    assert run.actual_output_quantity is not None  # completed implies actual
    assert run.leading_component_item_id is not None  # started implies leading

    comp_result = await db.exec(
        select(ProductionRunComponent).where(
            ProductionRunComponent.production_run_id == run.id
        )
    )
    snap = list(comp_result.all())
    measured = {c.raw_material_item_id: c.measured_quantity for c in snap}
    if any(q is None for q in measured.values()):
        raise InvalidRunStateError(
            f"Run '{run_id}' has no measured quantities — it was never started"
        )

    recipe_result = await db.exec(
        select(Recipe).where(
            Recipe.id == run.recipe_id, Recipe.business_id == business_id
        )
    )
    recipe = recipe_result.one_or_none()
    if recipe is None:
        raise RecipeNotFoundError("This run's recipe no longer exists")
    sellable_result = await db.exec(
        select(Item).where(
            Item.id == recipe.sellable_item_id, Item.business_id == business_id
        )
    )
    sellable = sellable_result.one_or_none()
    if sellable is None:
        raise RecipeNotFoundError("Sellable item for this run's recipe no longer exists")

    leading_qty = measured[run.leading_component_item_id]
    assert leading_qty is not None
    # Simple cost from weighed items (same rule as quick cooking).
    ingredient_ids = list(measured.keys())
    item_result = await db.exec(
        select(Item).where(Item.id.in_(ingredient_ids))
    )
    cost_by_item = {i.id: i.unit_cost for i in item_result.all()}
    cost_total: Decimal | None = None
    for raw_id, qty in measured.items():
        assert qty is not None
        basis = cost_by_item.get(raw_id)
        if basis is not None:
            line = (qty * basis).quantize(Decimal("0.0001"))
            cost_total = line if cost_total is None else cost_total + line
    cost_per_unit: Decimal | None = None
    if cost_total is not None and run.actual_output_quantity and run.actual_output_quantity > Decimal("0"):
        cost_per_unit = (cost_total / run.actual_output_quantity).quantize(Decimal("0.0001"))
    event = ProductionEvent(
        business_id=business_id,
        store_id=run.store_id,
        recipe_id=run.recipe_id,
        leading_component_item_id=run.leading_component_item_id,
        leading_quantity_used=leading_qty,
        target_output_quantity=run.target_output_quantity,
        suggested_output_quantity=run.target_output_quantity,
        actual_output_quantity=run.actual_output_quantity,
        run_id=run.id,
        waste_reason=run.waste_reason,
        yield_tolerance_percent=run.yield_tolerance_percent,
        production_cost_total=cost_total,
        production_cost_per_unit=cost_per_unit,
        actor_id=actor_id,
    )
    try:
        db.add(event)
        await db.flush()
        for raw_id, qty in measured.items():
            assert qty is not None
            db.add(
                ProductionEventComponent(
                    production_event_id=event.id,
                    raw_material_item_id=raw_id,
                    quantity_consumed=qty,
                )
            )
        await record_movement(
            db=db,
            item_id=sellable.id,
            business_id=business_id,
            store_id=run.store_id,
            quantity_delta=run.actual_output_quantity,
            movement_type=MovementType.PRODUCTION_OUTPUT,
            reference_type="production_event",
            reference_id=event.id,
            actor_id=actor_id,
            reason=f"Production run {run.id} published",
            commit=False,
            unit_cost=cost_per_unit,
        )
        if cost_per_unit is not None:
            sellable.unit_cost = cost_per_unit
            db.add(sellable)
        run.published_at = datetime.now(UTC)
        db.add(run)
        await db.commit()
        await db.refresh(event)
        await db.refresh(run)
    except Exception:
        await db.rollback()
        raise

    production_payload: dict[str, Any] = {
        "event_id": str(event.id),
        "run_id": str(run.id),
        "recipe_id": str(run.recipe_id),
        "business_id": str(business_id),
        "store_id": str(run.store_id),
        "target_output_quantity": str(run.target_output_quantity),
        "suggested_output_quantity": str(event.suggested_output_quantity),
        "actual_output_quantity": str(event.actual_output_quantity),
        "waste_reason": run.waste_reason,
    }
    await publish_event("production.recorded", production_payload)
    await publish_event(
        "audit.recorded",
        {
            "actor_id": str(actor_id) if actor_id else None,
            "business_id": str(business_id),
            "action": "production.run_published",
            "resource_type": "production_event",
            "resource_id": str(event.id),
            "details": {
                "run_id": str(run.id),
                "recipe_id": str(run.recipe_id),
                "actual_output_quantity": str(event.actual_output_quantity),
                "waste_reason": run.waste_reason,
            },
        },
    )
    logger.info(
        "production.run_published",
        run_id=str(run.id),
        event_id=str(event.id),
        business_id=str(business_id),
    )
    return event


async def delete_run(db: AsyncSession, business_id: UUID, run_id: UUID) -> None:
    """Delete a pending run (plan components cascade).

    Only pending runs can be deleted — a started run already moved stock
    and its history must stay auditable; complete or publish it instead.
    """
    run = await _get_run_or_404(db, business_id, run_id)
    if run.status != RunStatus.PENDING:
        raise InvalidRunStateError(
            f"Run '{run_id}' is {run.status.value} — only pending runs can be deleted"
        )
    await db.delete(run)
    await db.commit()
    logger.info("production.run_deleted", run_id=str(run.id), business_id=str(business_id))


async def cancel_run(
    db: AsyncSession,
    business_id: UUID,
    run_id: UUID,
    reason: str | None = None,
    actor_id: UUID | None = None,
) -> ProductionRun:
    """Stop a batch: put weighed items back, mark it stopped.

    Simple words: "Stop" puts the items back on the shelf.
    Works for planned (pending) and cooking (in_progress) batches.
    A finished batch cannot be stopped here — undo its record instead.
    Safe to tap twice.
    """
    from datetime import UTC, datetime

    run = await _get_run_or_404(db, business_id, run_id)
    if run.status == RunStatus.CANCELLED:
        return run
    if run.status == RunStatus.COMPLETED:
        raise InvalidRunStateError(
            f"Run '{run_id}' is completed — undo its cooking record instead"
        )
    if run.published_at is not None:
        raise InvalidRunStateError(
            f"Run '{run_id}' is already published — undo its cooking record instead"
        )
    clean_reason = (reason or "").strip() or "Stopped by staff"

    if run.status == RunStatus.PENDING:
        run.status = RunStatus.CANCELLED
        run.cancel_reason = clean_reason[:500]
        run.cancelled_at = datetime.now(UTC)
        db.add(run)
        await db.commit()
        await db.refresh(run)
    else:
        # in_progress: put measured items back.
        comp_result = await db.exec(
            select(ProductionRunComponent).where(
                ProductionRunComponent.production_run_id == run.id
            )
        )
        snap = list(comp_result.all())
        measured = {
            c.raw_material_item_id: c.measured_quantity for c in snap
        }
        if any(q is None for q in measured.values()):
            raise InvalidRunStateError(
                f"Run '{run_id}' has no measured quantities to put back"
            )
        try:
            for raw_id, qty in measured.items():
                assert qty is not None
                await record_movement(
                    db=db,
                    item_id=raw_id,
                    business_id=business_id,
                    store_id=run.store_id,
                    quantity_delta=qty,
                    movement_type=MovementType.PRODUCTION_REVERSAL,
                    reference_type="production_run",
                    reference_id=run.id,
                    actor_id=actor_id,
                    reason=f"Stop batch {run.id}: put back",
                    commit=False,
                    skip_negative_check=True,
                )
            run.status = RunStatus.CANCELLED
            run.cancel_reason = clean_reason[:500]
            run.cancelled_at = datetime.now(UTC)
            db.add(run)
            await db.commit()
            await db.refresh(run)
        except Exception:
            await db.rollback()
            raise

    await publish_event(
        "production.run_cancelled",
        {
            "run_id": str(run.id),
            "business_id": str(business_id),
            "reason": clean_reason,
        },
    )
    logger.info("production.run_cancelled", run_id=str(run.id), business_id=str(business_id))
    return run
