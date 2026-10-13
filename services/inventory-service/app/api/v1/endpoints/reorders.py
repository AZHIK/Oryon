"""Reorder (purchase order) endpoints — create, list, receive, cancel.

┌──────────────────────────────────────────────────────────────────────────┐
│ PERMISSION MODEL                                                         │
│                                                                          │
│   POST /businesses/{business_id}/reorders                → REORDERS_CREATE │
│   GET  /businesses/{business_id}/reorders                → REORDERS_VIEW   │
│   GET  /businesses/{business_id}/reorders/{reorder_id}    → REORDERS_VIEW   │
│   POST /businesses/{business_id}/reorders/{reorder_id}/receive → REORDERS_RECEIVE │
│   POST /businesses/{business_id}/reorders/{reorder_id}/cancel  → REORDERS_CANCEL  │
└──────────────────────────────────────────────────────────────────────────┘

``receive_reorder`` is the one non-trivial piece: it calls
``record_movement()`` (the same core engine ``operations.py`` uses for
manual adjust/waste/transfer) with ``movement_type=PURCHASE_RECEIVED`` and
``reference_type="reorder"``, then updates this ``Reorder`` row's status in
the SAME transaction (``commit=False`` on the movement call, one
``session.commit()`` at the end) — mirrors ``operations.py``'s
``transfer_stock`` two-write-one-transaction pattern exactly.

A reorder against a ``sellable``-type item is rejected at creation — the
frontend already hides the "Create reorder" action for such items (see
`apps/restaurant_app`'s reorder dialog entry points), this is
defense-in-depth: ``PURCHASE_RECEIVED`` is rejected for ``sellable`` items
by ``stock_movement_service._COMPATIBILITY_RULES`` regardless, so letting a
reorder be *created* against one just defers the same failure to receive
time — better to refuse it up front with a clear message.
"""

from __future__ import annotations

from datetime import UTC, datetime
from decimal import Decimal
from typing import Annotated, Any
from uuid import UUID

import structlog
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlmodel import select
from sqlmodel.ext.asyncio.session import AsyncSession
from sqlmodel.sql.expression import SelectOfScalar

from app.core.database import get_db
from app.deps.auth import get_current_claims, require_business_permission
from app.models.inventory import ActorType, Item, ItemType, MovementType, StockLevel
from app.models.reorders import Reorder, ReorderStatus
from app.models.suppliers import Supplier
from app.models.units import Unit
from app.schemas.reorders import (
    ReorderCreate,
    ReorderListFilters,
    ReorderListResponse,
    ReorderRead,
    ReorderReceive,
)
from app.services.stock_movement_service import (
    InsufficientStockError,
    ItemTypeMismatchError,
    record_movement,
)

logger = structlog.get_logger(__name__)
router = APIRouter(prefix="/businesses/{business_id}/reorders", tags=["reorders"])


def _extract_actor_id(claims: dict[str, Any]) -> UUID | None:
    raw = claims.get("sub")
    if not raw:
        return None
    try:
        return UUID(raw)
    except ValueError:
        return None


async def _get_reorder_or_404(
    business_id: UUID,
    reorder_id: UUID,
    session: AsyncSession,
) -> Reorder:
    stmt = select(Reorder).where(Reorder.id == reorder_id, Reorder.business_id == business_id)
    result = await session.exec(stmt)
    reorder = result.one_or_none()
    if reorder is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Reorder not found")
    return reorder


def _build_list_query(business_id: UUID, filters: ReorderListFilters) -> SelectOfScalar[Reorder]:
    stmt = select(Reorder).where(Reorder.business_id == business_id)
    if filters.status is not None:
        stmt = stmt.where(Reorder.status == filters.status)
    if filters.item_id is not None:
        stmt = stmt.where(Reorder.item_id == filters.item_id)
    if filters.store_id is not None:
        stmt = stmt.where(Reorder.store_id == filters.store_id)
    return stmt.order_by(Reorder.ordered_at.desc())


@router.post("", response_model=ReorderRead, status_code=status.HTTP_201_CREATED)
async def create_reorder(
    business_id: UUID,
    body: ReorderCreate,
    session: Annotated[AsyncSession, Depends(get_db)],
    claims: Annotated[dict[str, Any], Depends(get_current_claims)],
    _jwt_biz_id: Annotated[str, Depends(require_business_permission("reorders.create"))],
) -> Reorder:
    item = (
        await session.exec(
            select(Item).where(Item.id == body.item_id, Item.business_id == business_id)
        )
    ).one_or_none()
    if item is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Item not found")
    if item.item_type == ItemType.SELLABLE:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=(
                "Cannot reorder a sellable-only item — it can never be "
                "purchase-received. Reorder its raw-material components instead."
            ),
        )
    if item.unit_id is None:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Item has no unit assigned — set a unit before reordering it.",
        )
    unit = (await session.exec(select(Unit).where(Unit.id == item.unit_id))).one_or_none()
    if unit is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Item's unit not found")

    supplier = (
        await session.exec(
            select(Supplier).where(
                Supplier.id == body.supplier_id,
                Supplier.business_id == business_id,
                Supplier.is_deleted == False,  # noqa: E712
            )
        )
    ).one_or_none()
    if supplier is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Supplier not found")

    reorder = Reorder(
        business_id=business_id,
        store_id=body.store_id,
        item_id=body.item_id,
        supplier_id=body.supplier_id,
        quantity=body.quantity,
        unit=unit.code,
        notes=body.notes,
        ordered_at=datetime.now(UTC),
        ordered_by=_extract_actor_id(claims),
        expected_at=body.expected_at,
    )
    session.add(reorder)
    await session.commit()
    await session.refresh(reorder)

    logger.info(
        "reorder.created",
        reorder_id=str(reorder.id),
        business_id=str(business_id),
        item_id=str(body.item_id),
        supplier_id=str(body.supplier_id),
    )
    return reorder


@router.get("", response_model=ReorderListResponse)
async def list_reorders(
    business_id: UUID,
    filters: Annotated[ReorderListFilters, Depends()],
    session: Annotated[AsyncSession, Depends(get_db)],
    _jwt_biz_id: Annotated[str, Depends(require_business_permission("reorders.view"))],
    limit: int = Query(default=20, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
) -> ReorderListResponse:
    base_stmt = _build_list_query(business_id, filters)

    count_result = await session.exec(base_stmt)
    total = len(count_result.all())

    stmt = base_stmt.offset(offset).limit(limit)
    result = await session.exec(stmt)
    items = list(result.all())

    return ReorderListResponse(items=items, total=total, limit=limit, offset=offset)


@router.post("/{reorder_id}/receive", response_model=ReorderRead)
async def receive_reorder(
    business_id: UUID,
    reorder_id: UUID,
    session: Annotated[AsyncSession, Depends(get_db)],
    claims: Annotated[dict[str, Any], Depends(get_current_claims)],
    _jwt_biz_id: Annotated[str, Depends(require_business_permission("reorders.receive"))],
    body: ReorderReceive | None = None,
) -> Reorder:
    reorder = await _get_reorder_or_404(business_id, reorder_id, session)
    if reorder.status != ReorderStatus.PENDING:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Reorder is already {reorder.status.value}, cannot receive it",
        )

    actor_id = _extract_actor_id(claims)
    unit_cost = body.unit_cost if body is not None else None

    # Snapshot the pre-receipt cost basis BEFORE record_movement mutates the
    # level row in-session (same read-before-write order as purchases.py).
    costing: tuple[Item, Decimal, Decimal | None] | None = None
    if unit_cost is not None:
        snapshot_item = (
            await session.exec(
                select(Item).where(
                    Item.id == reorder.item_id, Item.business_id == business_id
                )
            )
        ).one_or_none()
        if snapshot_item is not None:
            snapshot_level = (
                await session.exec(
                    select(StockLevel).where(
                        StockLevel.item_id == snapshot_item.id,
                        StockLevel.store_id == reorder.store_id,
                    )
                )
            ).one_or_none()
            costing = (
                snapshot_item,
                snapshot_level.current_quantity
                if snapshot_level
                else Decimal("0.000"),
                snapshot_item.unit_cost,
            )

    try:
        await record_movement(
            db=session,
            item_id=reorder.item_id,
            business_id=business_id,
            store_id=reorder.store_id,
            quantity_delta=reorder.quantity,
            movement_type=MovementType.PURCHASE_RECEIVED,
            reference_type="reorder",
            reference_id=reorder.id,
            actor_type=ActorType.USER.value,
            actor_id=actor_id,
            reason=f"Reorder {reorder.id} received",
            commit=False,
            unit_cost=unit_cost,
        )

        # Cost enters here when supplied — same weighted-average rule the
        # GRN path uses. Omitted cost leaves Item.unit_cost untouched.
        if costing is not None:
            item, old_qty, old_cost = costing
            basis = old_cost if old_cost is not None else unit_cost
            assert unit_cost is not None
            denom = old_qty + reorder.quantity
            if denom > 0:
                item.unit_cost = (
                    (old_qty * basis + reorder.quantity * unit_cost) / denom
                ).quantize(Decimal("0.0001"))
            else:
                item.unit_cost = unit_cost
            session.add(item)

        reorder.status = ReorderStatus.RECEIVED
        reorder.received_at = datetime.now(UTC)
        reorder.received_by = actor_id
        session.add(reorder)

        await session.commit()
        await session.refresh(reorder)
    except ItemTypeMismatchError as exc:
        await session.rollback()
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=str(exc),
        ) from exc
    except InsufficientStockError as exc:
        await session.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=str(exc),
        ) from exc
    except Exception:
        await session.rollback()
        raise

    logger.info(
        "reorder.received",
        reorder_id=str(reorder.id),
        business_id=str(business_id),
        item_id=str(reorder.item_id),
        quantity=str(reorder.quantity),
    )
    return reorder


@router.post("/{reorder_id}/cancel", response_model=ReorderRead)
async def cancel_reorder(
    business_id: UUID,
    reorder_id: UUID,
    session: Annotated[AsyncSession, Depends(get_db)],
    claims: Annotated[dict[str, Any], Depends(get_current_claims)],
    _jwt_biz_id: Annotated[str, Depends(require_business_permission("reorders.cancel"))],
) -> Reorder:
    reorder = await _get_reorder_or_404(business_id, reorder_id, session)
    if reorder.status != ReorderStatus.PENDING:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Reorder is already {reorder.status.value}, cannot cancel it",
        )

    reorder.status = ReorderStatus.CANCELLED
    reorder.cancelled_at = datetime.now(UTC)
    reorder.cancelled_by = _extract_actor_id(claims)
    session.add(reorder)
    await session.commit()
    await session.refresh(reorder)

    logger.info("reorder.cancelled", reorder_id=str(reorder.id), business_id=str(business_id))
    return reorder


@router.get("/{reorder_id}", response_model=ReorderRead)
async def get_reorder(
    business_id: UUID,
    reorder_id: UUID,
    session: Annotated[AsyncSession, Depends(get_db)],
    _jwt_biz_id: Annotated[str, Depends(require_business_permission("reorders.view"))],
) -> Reorder:
    """Declared last — ``/receive``/``/cancel`` are literal sub-paths that
    must never be swallowed by this ``{reorder_id}`` matcher (same ordering
    discipline as ``customers.py`` in pos-service, here for a route that
    actually does have literal sub-paths)."""
    return await _get_reorder_or_404(business_id, reorder_id, session)
