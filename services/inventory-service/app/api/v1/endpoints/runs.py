"""Production run endpoints — scheduled batches (Production Module).

┌──────────────────────────────────────────────────────────────────────────┐
│ PERMISSION MODEL (reuses the production codes — runs ARE production)     │
│                                                                          │
│   POST   /businesses/{id}/runs              → PRODUCTION_CREATE (plan)   │
│   GET    /businesses/{id}/runs              → PRODUCTION_VIEW   (tabs)   │
│   GET    /businesses/{id}/runs/{rid}        → PRODUCTION_VIEW            │
│   POST   /businesses/{id}/runs/{rid}/start    → PRODUCTION_CREATE       │
│   POST   /businesses/{id}/runs/{rid}/complete → PRODUCTION_CREATE       │
│   POST   /businesses/{id}/runs/{rid}/publish  → PRODUCTION_CREATE       │
│   DELETE /businesses/{id}/runs/{rid}          → PRODUCTION_CREATE       │
│          (pending runs only — started runs moved stock and stay auditable)│
│                                                                          │
│ Lifecycle: pending → in_progress → completed → published. Starting       │
│ deducts the measured inputs (409 when any ingredient is short — the      │
│ whole start is rejected); completing records actual + waste reason;      │
│ publishing stocks the output (the "Publish to POS & Inventory" button)  │
│ and returns the immutable history event with its yield verdict.          │
└──────────────────────────────────────────────────────────────────────────┘
"""

from __future__ import annotations

from typing import Annotated, Any
from uuid import UUID

import structlog
from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel
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
    ProductionRun,
    ProductionRunComponent,
    Recipe,
    RunStatus,
)
from app.models.units import Unit
from app.schemas.production import ProductionEventRead, evaluate_yield
from app.schemas.runs import (
    RunCompleteRequest,
    RunComponentRead,
    RunCreate,
    RunRead,
    RunStartRequest,
)
from app.services.production_service import (
    InsufficientStockError,
    InvalidProductionInputError,
    RecipeNotFoundError,
)
from app.services.run_service import (
    InvalidRunStateError,
    RunNotFoundError,
    cancel_run,
    complete_run,
    create_run,
    delete_run,
    publish_run,
    start_run,
)

logger = structlog.get_logger(__name__)

router = APIRouter(prefix="/businesses/{business_id}/runs", tags=["production-runs"])

_VALID_STATUSES = ("pending", "in_progress", "completed", "cancelled")


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


async def _ensure_run_store_access(
    business_id: UUID,
    run_id: UUID,
    claims: dict[str, Any],
    session: AsyncSession,
) -> None:
    """Reject cross-store actions before the service mutates a run."""
    run = (
        await session.exec(
            select(ProductionRun).where(
                ProductionRun.id == run_id,
                ProductionRun.business_id == business_id,
            )
        )
    ).one_or_none()
    if run is not None:
        ensure_store_access(claims, run.store_id)


async def _read_runs(
    runs: list[ProductionRun],
    session: AsyncSession,
) -> list[RunRead]:
    """Build full read payloads with resolved names/units in bulk.

    Constant query count regardless of run count (components → recipes →
    items → units), and the yield verdict computed server-side once the
    actual is known (completed runs) against the run target.
    """
    if not runs:
        return []

    run_ids = [r.id for r in runs]
    comp_result = await session.exec(
        select(ProductionRunComponent).where(
            ProductionRunComponent.production_run_id.in_(run_ids)
        )
    )
    components = list(comp_result.all())

    recipe_ids = list({r.recipe_id for r in runs})
    recipe_result = await session.exec(
        select(Recipe).where(Recipe.id.in_(recipe_ids))
    )
    recipes = {r.id: r for r in recipe_result.all()}

    item_ids = {r.leading_component_item_id for r in runs if r.leading_component_item_id} | {
        c.raw_material_item_id for c in components
    } | {r.sellable_item_id for r in recipes.values()}
    item_result = await session.exec(select(Item).where(Item.id.in_(list(item_ids))))
    items = {item.id: item for item in item_result.all()}

    unit_ids = {item.unit_id for item in items.values() if item.unit_id is not None}
    units: dict[UUID, str] = {}
    if unit_ids:
        unit_result = await session.exec(select(Unit).where(Unit.id.in_(list(unit_ids))))
        units = {unit.id: unit.code for unit in unit_result.all()}

    comps_by_run: dict[UUID, list[RunComponentRead]] = {r.id: [] for r in runs}
    for comp in components:
        raw = items[comp.raw_material_item_id]
        comps_by_run[comp.production_run_id].append(
            RunComponentRead(
                id=comp.id,
                production_run_id=comp.production_run_id,
                raw_material_item_id=comp.raw_material_item_id,
                raw_material_name=raw.name,
                raw_material_unit=units.get(raw.unit_id) if raw.unit_id else "",
                planned_quantity=comp.planned_quantity,
                measured_quantity=comp.measured_quantity,
            )
        )

    reads = []
    for r in runs:
        recipe = recipes[r.recipe_id]
        sellable = items[recipe.sellable_item_id]
        variance = variance_percent = verdict = None
        if r.actual_output_quantity is not None:
            verdict, variance, variance_percent = evaluate_yield(
                actual=r.actual_output_quantity,
                goal=r.target_output_quantity,
                tolerance_percent=r.yield_tolerance_percent,
            )
        reads.append(
            RunRead(
                id=r.id,
                business_id=r.business_id,
                store_id=r.store_id,
                recipe_id=r.recipe_id,
                recipe_name=recipe.name,
                sellable_item_id=recipe.sellable_item_id,
                sellable_item_name=sellable.name,
                target_output_quantity=r.target_output_quantity,
                status=r.status.value,
                leading_component_item_id=r.leading_component_item_id,
                yield_tolerance_percent=r.yield_tolerance_percent,
                actual_output_quantity=r.actual_output_quantity,
                waste_reason=r.waste_reason,
                yield_goal_quantity=r.target_output_quantity,
                yield_variance=variance,
                yield_variance_percent=variance_percent,
                yield_status=verdict,
                published_at=r.published_at,
                cancel_reason=r.cancel_reason,
                cancelled_at=r.cancelled_at,
                created_by=r.created_by,
                started_at=r.started_at,
                completed_at=r.completed_at,
                created_at=r.created_at,
                updated_at=r.updated_at,
                components=comps_by_run[r.id],
            )
        )
    return reads


def _actor_id_from(claims: dict[str, Any]) -> UUID | None:
    raw_sub = claims.get("sub")
    try:
        return UUID(raw_sub) if raw_sub else None
    except ValueError:
        return None


def _map_errors(exc: Exception) -> HTTPException:
    if isinstance(exc, RunNotFoundError | RecipeNotFoundError):
        return HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc))
    if isinstance(exc, InvalidRunStateError | InvalidProductionInputError):
        return HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT, detail=str(exc)
        )
    if isinstance(exc, InsufficientStockError):
        return HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(exc))
    raise exc


@router.post("", response_model=RunRead, status_code=status.HTTP_201_CREATED)
async def create_production_run(
    business_id: UUID,
    body: RunCreate,
    session: Annotated[AsyncSession, Depends(get_db)],
    _jwt_biz_id: Annotated[str, Depends(require_business_permission("production.create"))],
    claims: Annotated[dict[str, Any], Depends(get_current_claims)],
) -> RunRead:
    """Schedule a batch (pending): snapshot the plan, move no stock."""
    await _ensure_recipe_store_access(business_id, body.recipe_id, claims, session)
    try:
        run = await create_run(
            db=session,
            business_id=business_id,
            recipe_id=body.recipe_id,
            target_output_quantity=body.target_output_quantity,
            yield_tolerance_percent=body.yield_tolerance_percent,
            actor_id=_actor_id_from(claims),
            idempotency_key=body.idempotency_key,
        )
    except Exception as exc:
        raise _map_errors(exc) from exc
    ensure_store_access(claims, run.store_id)
    logger.info("runs.endpoint_created", run_id=str(run.id), business_id=str(business_id))
    return (await _read_runs([run], session))[0]


@router.get("", response_model=list[RunRead])
async def list_production_runs(
    business_id: UUID,
    session: Annotated[AsyncSession, Depends(get_db)],
    _jwt_biz_id: Annotated[str, Depends(require_business_permission("production.view"))],
    claims: Annotated[dict[str, Any], Depends(get_current_claims)],
    run_status: str | None = Query(
        default=None, alias="status",
        description="Filter: pending | in_progress | completed",
    ),
    limit: int = Query(default=20, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
) -> list[RunRead]:
    """Shift plan: batches newest first, optionally filtered by status."""
    if run_status is not None and run_status not in _VALID_STATUSES:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail=f"status must be one of {', '.join(_VALID_STATUSES)}",
        )
    store_id = resolve_store_filter(claims, None)
    stmt = select(ProductionRun).where(ProductionRun.business_id == business_id)
    if store_id is not None:
        stmt = stmt.where(ProductionRun.store_id == store_id)
    if run_status is not None:
        stmt = stmt.where(ProductionRun.status == RunStatus(run_status))
    stmt = stmt.order_by(ProductionRun.created_at.desc()).offset(offset).limit(limit)
    runs = list((await session.exec(stmt)).all())
    logger.info("runs.listed", business_id=str(business_id), count=len(runs))
    return await _read_runs(runs, session)


@router.get("/{run_id}", response_model=RunRead)
async def get_production_run(
    business_id: UUID,
    run_id: UUID,
    session: Annotated[AsyncSession, Depends(get_db)],
    _jwt_biz_id: Annotated[str, Depends(require_business_permission("production.view"))],
    claims: Annotated[dict[str, Any], Depends(get_current_claims)],
) -> RunRead:
    """Full detail for one run, plan lines included."""
    result = await session.exec(
        select(ProductionRun).where(
            ProductionRun.id == run_id, ProductionRun.business_id == business_id
        )
    )
    run = result.one_or_none()
    if run is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Production run not found"
        )
    ensure_store_access(claims, run.store_id)
    return (await _read_runs([run], session))[0]


@router.post("/{run_id}/start", response_model=RunRead)
async def start_production_run(
    business_id: UUID,
    run_id: UUID,
    body: RunStartRequest,
    session: Annotated[AsyncSession, Depends(get_db)],
    _jwt_biz_id: Annotated[str, Depends(require_business_permission("production.create"))],
    claims: Annotated[dict[str, Any], Depends(get_current_claims)],
) -> RunRead:
    """Start a pending run: deduct the weighed ingredients, instantly.

    Omit ``components`` to weigh the snapshotted plan exactly; supply the
    full adjusted list to record what the scale actually said. A shortfall
    on any ingredient rejects the whole start (409) with zero side effects.
    """
    await _ensure_run_store_access(business_id, run_id, claims, session)
    try:
        run = await start_run(
            db=session,
            business_id=business_id,
            run_id=run_id,
            leading_item_id=body.leading_item_id,
            leading_quantity_used=body.leading_quantity_used,
            components_override=(
                {c.raw_material_item_id: c.quantity_used for c in body.components}
                if body.components is not None
                else None
            ),
            actor_id=_actor_id_from(claims),
        )
    except Exception as exc:
        raise _map_errors(exc) from exc
    logger.info("runs.endpoint_started", run_id=str(run.id), business_id=str(business_id))
    return (await _read_runs([run], session))[0]


@router.post("/{run_id}/complete", response_model=RunRead)
async def complete_production_run(
    business_id: UUID,
    run_id: UUID,
    body: RunCompleteRequest,
    session: Annotated[AsyncSession, Depends(get_db)],
    _jwt_biz_id: Annotated[str, Depends(require_business_permission("production.create"))],
    claims: Annotated[dict[str, Any], Depends(get_current_claims)],
) -> RunRead:
    """Finish an in-progress run: record actual yield + waste reason.

    No stock moves — the output lands in inventory at publish, so the
    kitchen can verify before anything becomes sellable.
    """
    await _ensure_run_store_access(business_id, run_id, claims, session)
    try:
        run = await complete_run(
            db=session,
            business_id=business_id,
            run_id=run_id,
            actual_output_quantity=body.actual_output_quantity,
            waste_reason=body.waste_reason,
        )
    except Exception as exc:
        raise _map_errors(exc) from exc
    logger.info("runs.endpoint_completed", run_id=str(run.id), business_id=str(business_id))
    return (await _read_runs([run], session))[0]


@router.post("/{run_id}/publish", response_model=ProductionEventRead)
async def publish_production_run(
    business_id: UUID,
    run_id: UUID,
    session: Annotated[AsyncSession, Depends(get_db)],
    _jwt_biz_id: Annotated[str, Depends(require_business_permission("production.create"))],
    claims: Annotated[dict[str, Any], Depends(get_current_claims)],
) -> ProductionEventRead:
    """Publish a completed run: stock the output, write history + verdict.

    The one-click conversion — the confirmed quantity is injected into the
    sellable's stock (immediately sellable on the POS) and the immutable
    history event carries target, actual, variance, and waste reason.
    """
    from app.api.v1.endpoints.production import _read_events

    await _ensure_run_store_access(business_id, run_id, claims, session)
    try:
        event = await publish_run(
            db=session,
            business_id=business_id,
            run_id=run_id,
            actor_id=_actor_id_from(claims),
        )
    except Exception as exc:
        raise _map_errors(exc) from exc
    logger.info(
        "runs.endpoint_published",
        run_id=str(run_id),
        event_id=str(event.id),
        business_id=str(business_id),
    )
    run_result = await session.exec(
        select(ProductionRun).where(ProductionRun.id == run_id)
    )
    run = run_result.one()
    return (await _read_events([event], session, run.yield_tolerance_percent))[0]


@router.delete("/{run_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_production_run(
    business_id: UUID,
    run_id: UUID,
    session: Annotated[AsyncSession, Depends(get_db)],
    _jwt_biz_id: Annotated[str, Depends(require_business_permission("production.create"))],
    claims: Annotated[dict[str, Any], Depends(get_current_claims)],
) -> None:
    """Delete a pending run. Started runs moved stock — complete them."""
    await _ensure_run_store_access(business_id, run_id, claims, session)
    try:
        await delete_run(db=session, business_id=business_id, run_id=run_id)
    except Exception as exc:
        raise _map_errors(exc) from exc
    logger.info("runs.endpoint_deleted", run_id=str(run_id), business_id=str(business_id))


class CancelRunRequest(BaseModel):
    """Stop a batch, in simple words."""

    reason: str | None = None


@router.post("/{run_id}/cancel", response_model=RunRead)
async def cancel_production_run(
    business_id: UUID,
    run_id: UUID,
    body: CancelRunRequest,
    session: Annotated[AsyncSession, Depends(get_db)],
    _jwt_biz_id: Annotated[str, Depends(require_business_permission("production.create"))],
    claims: Annotated[dict[str, Any], Depends(get_current_claims)],
) -> RunRead:
    """Stop: put weighed items back. Works for planned and cooking batches."""
    await _ensure_run_store_access(business_id, run_id, claims, session)
    try:
        run = await cancel_run(
            db=session,
            business_id=business_id,
            run_id=run_id,
            reason=body.reason,
            actor_id=_actor_id_from(claims),
        )
    except Exception as exc:
        raise _map_errors(exc) from exc
    logger.info("runs.endpoint_cancelled", run_id=str(run_id), business_id=str(business_id))
    return (await _read_runs([run], session))[0]
