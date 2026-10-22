"""Production endpoints — record runs and read history (Stage 2).

┌──────────────────────────────────────────────────────────────────────────┐
│ PERMISSION MODEL                                                         │
│                                                                          │
│   POST /businesses/{id}/recipes/{rid}/produce       → PRODUCTION_CREATE  │
│   POST /businesses/{id}/recipes/{rid}/plan          → PRODUCTION_CREATE  │
│   GET  /businesses/{id}/production-events           → PRODUCTION_VIEW    │
│   GET  /businesses/{id}/production-events/{eid}     → PRODUCTION_VIEW    │
│                                                                          │
│ Business-context binding is enforced at the shared dependency level      │
│ (``require_business_permission``), not per-endpoint.                     │
│                                                                          │
│ Error mapping for the service's domain errors: not-found → 404,          │
│ malformed input → 422, any-ingredient shortfall → 409 with the whole     │
│ event rejected (``record_production_event`` writes nothing before its    │
│ sufficiency check, so a 409 always means zero side effects).             │
└──────────────────────────────────────────────────────────────────────────┘
"""

from __future__ import annotations

from datetime import UTC, date, datetime
from decimal import Decimal
from typing import Annotated, Any
from uuid import UUID

import structlog
from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, Field
from sqlmodel import select
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.database import get_db
from app.deps.auth import (
    ensure_store_access,
    get_current_claims,
    require_business_permission,
    resolve_store_filter,
)
from app.models.inventory import (
    Item,
    ProductionEvent,
    ProductionEventComponent,
    Recipe,
)
from app.models.units import Unit
from app.schemas.production import (
    DEFAULT_YIELD_TOLERANCE_PERCENT,
    PlannedComponentRead,
    ProduceRequest,
    ProductionComponentRead,
    ProductionEventRead,
    ProductionPlanRead,
    ProductionPlanRequest,
    evaluate_yield,
)
from app.services.production_service import (
    InsufficientStockError,
    InvalidProductionInputError,
    RecipeNotFoundError,
    per_unit_requirement,
    plan_production_quantities,
    record_production_event,
)

logger = structlog.get_logger(__name__)

produce_router = APIRouter(
    prefix="/businesses/{business_id}/recipes/{recipe_id}", tags=["production"]
)
history_router = APIRouter(
    prefix="/businesses/{business_id}/production-events", tags=["production"]
)


async def _ensure_recipe_store_access(
    business_id: UUID,
    recipe_id: UUID,
    claims: dict[str, Any],
    session: AsyncSession,
) -> None:
    """Bind a recipe action to the token's store via its sellable item."""
    recipe = (
        await session.exec(
            select(Recipe).where(
                Recipe.id == recipe_id, Recipe.business_id == business_id
            )
        )
    ).one_or_none()
    if recipe is None:
        return  # the service layer owns the 404
    sellable = (
        await session.exec(select(Item).where(Item.id == recipe.sellable_item_id))
    ).one_or_none()
    if sellable is not None:
        ensure_store_access(claims, sellable.store_id)


async def _read_events(
    events: list[ProductionEvent],
    session: AsyncSession,
    yield_tolerance_percent=DEFAULT_YIELD_TOLERANCE_PERCENT,
) -> list[ProductionEventRead]:
    """Build full read payloads with resolved names/units in bulk.

    One constant-size query pass (components → recipes/items → units) no
    matter how many events are listed — the same no-N+1 discipline as the
    recipes endpoint's reader. The yield verdict is computed server-side
    here (never trusted from the client) against the stored target when
    the target flow was used, else against the suggestion.
    """
    if not events:
        return []

    event_ids = [e.id for e in events]
    comp_result = await session.exec(
        select(ProductionEventComponent).where(
            ProductionEventComponent.production_event_id.in_(event_ids)
        )
    )
    components = list(comp_result.all())

    recipe_ids = {e.recipe_id for e in events}
    recipe_result = await session.exec(
        select(Recipe).where(Recipe.id.in_(list(recipe_ids)))
    )
    recipes = {r.id: r for r in recipe_result.all()}

    item_ids = {e.leading_component_item_id for e in events} | {
        c.raw_material_item_id for c in components
    } | {r.sellable_item_id for r in recipes.values()}
    item_result = await session.exec(select(Item).where(Item.id.in_(list(item_ids))))
    items = {item.id: item for item in item_result.all()}

    unit_ids = {item.unit_id for item in items.values() if item.unit_id is not None}
    units: dict[UUID, str] = {}
    if unit_ids:
        unit_result = await session.exec(
            select(Unit).where(Unit.id.in_(list(unit_ids)))
        )
        units = {unit.id: unit.code for unit in unit_result.all()}

    comps_by_event: dict[UUID, list[ProductionComponentRead]] = {
        e.id: [] for e in events
    }
    for comp in components:
        raw = items[comp.raw_material_item_id]
        comps_by_event[comp.production_event_id].append(
            ProductionComponentRead(
                id=comp.id,
                production_event_id=comp.production_event_id,
                raw_material_item_id=comp.raw_material_item_id,
                raw_material_name=raw.name,
                raw_material_unit=units.get(raw.unit_id) if raw.unit_id else "",
                quantity_consumed=comp.quantity_consumed,
            )
        )

    reads = []
    for e in events:
        recipe = recipes[e.recipe_id]
        sellable = items[recipe.sellable_item_id]
        goal = (
            e.target_output_quantity
            if e.target_output_quantity is not None
            else e.suggested_output_quantity
        )
        # Use the saved band when the caller does not pick one, so
        # history always reads the same.
        band = e.yield_tolerance_percent or yield_tolerance_percent
        status, variance, variance_percent = evaluate_yield(
            actual=e.actual_output_quantity,
            goal=goal,
            tolerance_percent=band,
        )
        reads.append(
            ProductionEventRead(
                id=e.id,
                business_id=e.business_id,
                store_id=e.store_id,
                recipe_id=e.recipe_id,
                recipe_name=recipe.name,
                sellable_item_id=recipe.sellable_item_id,
                sellable_item_name=sellable.name,
                leading_component_item_id=e.leading_component_item_id,
                leading_quantity_used=e.leading_quantity_used,
                target_output_quantity=e.target_output_quantity,
                suggested_output_quantity=e.suggested_output_quantity,
                actual_output_quantity=e.actual_output_quantity,
                run_id=e.run_id,
                waste_reason=e.waste_reason,
                yield_goal_quantity=goal,
                yield_variance=variance,
                yield_variance_percent=variance_percent,
                yield_status=status,
                yield_tolerance_percent=band,
                voided_at=e.voided_at,
                void_reason=e.void_reason,
                production_cost_total=e.production_cost_total,
                production_cost_per_unit=e.production_cost_per_unit,
                actor_id=e.actor_id,
                occurred_at=e.occurred_at,
                created_at=e.created_at,
                components=comps_by_event[e.id],
            )
        )
    return reads


@produce_router.post(
    "/produce", response_model=ProductionEventRead, status_code=status.HTTP_201_CREATED
)
async def produce(
    business_id: UUID,
    recipe_id: UUID,
    body: ProduceRequest,
    session: Annotated[AsyncSession, Depends(get_db)],
    _jwt_biz_id: Annotated[str, Depends(require_business_permission("production.create"))],
    claims: Annotated[dict[str, Any], Depends(get_current_claims)],
) -> ProductionEventRead:
    """Record a production run: consume ingredients, stock confirmed output.

    Two flows:

    * Omit ``target_output_quantity`` + ``components`` — classic ratio
      from the measured leading ingredient.
    * Send ``target_output_quantity`` (the goal) with ``components`` (the
      adjustable measured amounts, one per ingredient) — the target flow.
      The server validates full-recipe coverage, consumes exactly those
      amounts, and anchors the suggestion + yield verdict on the target.

    ``actual_output_quantity`` may be omitted — the server then commits
    the suggestion (plan-met portions, the common case). The response
    always carries the server-computed ``yield_status`` (above /
    within_threshold / below) — the client never decides the verdict.
    """
    await _ensure_recipe_store_access(business_id, recipe_id, claims, session)
    raw_sub = claims.get("sub")
    try:
        actor_id = UUID(raw_sub) if raw_sub else None
    except ValueError:
        actor_id = None

    try:
        event = await record_production_event(
            db=session,
            business_id=business_id,
            recipe_id=recipe_id,
            leading_item_id=body.leading_item_id,
            leading_quantity_used=body.leading_quantity_used,
            actual_output_quantity=body.actual_output_quantity,
            target_output_quantity=body.target_output_quantity,
            components_override=(
                {c.raw_material_item_id: c.quantity_used for c in body.components}
                if body.components is not None
                else None
            ),
            actor_id=actor_id,
            yield_tolerance_percent=body.yield_tolerance_percent,
            idempotency_key=body.idempotency_key,
        )
    except RecipeNotFoundError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)
        ) from exc
    except InvalidProductionInputError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT, detail=str(exc)
        ) from exc
    except InsufficientStockError as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT, detail=str(exc)
        ) from exc

    logger.info(
        "production.endpoint_recorded",
        event_id=str(event.id),
        business_id=str(business_id),
        recipe_id=str(recipe_id),
    )
    return (
        await _read_events(
            [event], session, yield_tolerance_percent=body.yield_tolerance_percent
        )
    )[0]


@produce_router.post("/plan", response_model=ProductionPlanRead)
async def plan_production(
    business_id: UUID,
    recipe_id: UUID,
    body: ProductionPlanRequest,
    session: Annotated[AsyncSession, Depends(get_db)],
    _jwt_biz_id: Annotated[str, Depends(require_business_permission("production.create"))],
    claims: Annotated[dict[str, Any], Depends(get_current_claims)],
) -> ProductionPlanRead:
    """Recommend every grocery amount for a target output (no stock change).

    "I need N products" → batch total × N ÷ recipe target yield per
    ingredient. Each line is adjustable: the cook measures, tweaks any
    amount, then commits through ``POST .../produce`` with
    ``target_output_quantity=N`` and the final ``components`` list.
    """
    await _ensure_recipe_store_access(business_id, recipe_id, claims, session)
    try:
        recipe, sellable, lines = await plan_production_quantities(
            db=session,
            business_id=business_id,
            recipe_id=recipe_id,
            target_output_quantity=body.target_output_quantity,
        )
    except RecipeNotFoundError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)
        ) from exc
    except InvalidProductionInputError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT, detail=str(exc)
        ) from exc

    unit_ids = {item.unit_id for _, item in lines if item.unit_id is not None}
    units: dict[UUID, str] = {}
    if unit_ids:
        unit_result = await session.exec(
            select(Unit).where(Unit.id.in_(list(unit_ids)))
        )
        units = {unit.id: unit.code for unit in unit_result.all()}

    logger.info(
        "production.planned",
        business_id=str(business_id),
        recipe_id=str(recipe_id),
        target=str(body.target_output_quantity),
    )
    batch_yield = recipe.target_yield_quantity
    per_unit = {
        comp.raw_material_item_id: per_unit_requirement(
            comp.quantity_required, batch_yield
        ).quantize(Decimal("0.001"))
        for comp, _ in lines
    }
    return ProductionPlanRead(
        recipe_id=recipe.id,
        recipe_name=recipe.name,
        sellable_item_id=sellable.id,
        sellable_item_name=sellable.name,
        target_output_quantity=body.target_output_quantity,
        suggested_output_quantity=body.target_output_quantity,
        components=[
            PlannedComponentRead(
                raw_material_item_id=comp.raw_material_item_id,
                raw_material_name=item.name,
                raw_material_unit=(
                    units.get(item.unit_id) if item.unit_id else ""
                ),
                quantity_required_per_unit=per_unit[comp.raw_material_item_id],
                planned_quantity=(
                    per_unit[comp.raw_material_item_id]
                    * body.target_output_quantity
                ).quantize(Decimal("0.001")),
            )
            for comp, item in lines
        ],
    )


@history_router.get("", response_model=list[ProductionEventRead])
async def list_production_events(
    business_id: UUID,
    session: Annotated[AsyncSession, Depends(get_db)],
    _jwt_biz_id: Annotated[str, Depends(require_business_permission("production.view"))],
    claims: Annotated[dict[str, Any], Depends(get_current_claims)],
    from_date: date | None = Query(
        default=None, alias="from", description="Start date (inclusive)"
    ),
    to_date: date | None = Query(
        default=None, alias="to", description="End date (inclusive)"
    ),
    limit: int = Query(default=20, ge=1, le=100, description="Max events per page"),
    offset: int = Query(default=0, ge=0, description="Number of events to skip"),
) -> list[ProductionEventRead]:
    """Production history for the business, newest first, filterable by date."""
    store_id = resolve_store_filter(claims, None)
    stmt = select(ProductionEvent).where(
        ProductionEvent.business_id == business_id
    )
    if store_id is not None:
        stmt = stmt.where(ProductionEvent.store_id == store_id)
    if from_date is not None:
        dt = datetime.combine(from_date, datetime.min.time(), tzinfo=UTC)
        stmt = stmt.where(ProductionEvent.occurred_at >= dt)
    if to_date is not None:
        dt = datetime.combine(to_date, datetime.max.time(), tzinfo=UTC)
        stmt = stmt.where(ProductionEvent.occurred_at <= dt)

    stmt = stmt.order_by(ProductionEvent.occurred_at.desc()).offset(offset).limit(limit)
    result = await session.exec(stmt)
    events = list(result.all())

    logger.info(
        "production.listed", business_id=str(business_id), count=len(events)
    )
    return await _read_events(events, session)


@history_router.get("/{event_id}", response_model=ProductionEventRead)
async def get_production_event(
    business_id: UUID,
    event_id: UUID,
    session: Annotated[AsyncSession, Depends(get_db)],
    _jwt_biz_id: Annotated[str, Depends(require_business_permission("production.view"))],
    claims: Annotated[dict[str, Any], Depends(get_current_claims)],
) -> ProductionEventRead:
    """Full detail for one production event."""
    result = await session.exec(
        select(ProductionEvent).where(
            ProductionEvent.id == event_id,
            ProductionEvent.business_id == business_id,
        )
    )
    event = result.one_or_none()
    if event is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Production event not found",
        )
    ensure_store_access(claims, event.store_id)
    return (await _read_events([event], session))[0]


class VoidProductionRequest(BaseModel):
    """Undo a cooking record, in simple words."""

    reason: str | None = Field(default=None, max_length=500)


@history_router.post("/{event_id}/void", response_model=ProductionEventRead)
async def void_production(
    business_id: UUID,
    event_id: UUID,
    body: VoidProductionRequest,
    session: Annotated[AsyncSession, Depends(get_db)],
    _jwt_biz_id: Annotated[str, Depends(require_business_permission("production.create"))],
    claims: Annotated[dict[str, Any], Depends(get_current_claims)],
) -> ProductionEventRead:
    """Undo: put used items back, take made items back. History is kept."""
    event_row = (
        await session.exec(
            select(ProductionEvent).where(
                ProductionEvent.id == event_id,
                ProductionEvent.business_id == business_id,
            )
        )
    ).one_or_none()
    if event_row is not None:
        ensure_store_access(claims, event_row.store_id)
    from app.services.production_service import void_production_event

    raw_sub = claims.get("sub")
    try:
        actor_id = UUID(raw_sub) if raw_sub else None
    except ValueError:
        actor_id = None
    try:
        event = await void_production_event(
            db=session,
            business_id=business_id,
            event_id=event_id,
            reason=body.reason,
            actor_id=actor_id,
        )
    except RecipeNotFoundError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)
        ) from exc
    return (await _read_events([event], session))[0]
