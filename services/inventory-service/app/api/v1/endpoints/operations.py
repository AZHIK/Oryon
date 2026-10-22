"""Manual operation endpoints — adjust, waste, and transfer stock.

Every endpoint calls ``record_movement()`` (Stage 5) and returns the
resulting ``StockMovementRead``.

┌──────────────────────────────────────────────────────────────────────────┐
│ PERMISSION MODEL  (Stage 8.5 Gap 3 — fine-grained codes)                 │
│                                                                          │
│   POST  /businesses/{business_id}/items/{item_id}/adjust   → ADJUST     │
│   POST  /businesses/{business_id}/items/{item_id}/waste    →             │
│                                              INVENTORY_WASTE_RECORD      │
│   POST  /businesses/{business_id}/transfer                 →             │
│                                              INVENTORY_TRANSFER          │
│                                                                          │
│ Business-context binding is enforced at the shared dependency level      │
│ (``require_business_permission``), not per-endpoint.                    │
│                                                                          │
│ Store-scoped enforcement: when the token carries ``active_store_id``    │
│ (store-staff), adjust/waste are limited to items in that store and      │
│ transfer must have that store on both legs.  Owner/business tokens      │
│ without ``active_store_id`` keep business-wide access.                  │
└──────────────────────────────────────────────────────────────────────────┘
"""

from __future__ import annotations

from decimal import Decimal
from typing import Annotated, Any
from uuid import UUID

import structlog
from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import select
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.database import get_db
from app.deps.auth import (
    ensure_store_access,
    get_current_claims,
    require_business_permission,
)
from app.models.inventory import ActorType, Item, MovementType
from app.schemas.movements import StockMovementRead
from app.schemas.operations import AdjustStockRequest, RecordWasteRequest, TransferStockRequest
from app.services.stock_movement_service import (
    InsufficientStockError,
    ItemTypeMismatchError,
    record_movement,
)

logger = structlog.get_logger(__name__)

# Two routers so adjust/waste (item-scoped) and transfer (business-scoped)
# can have different URL prefixes.
items_router = APIRouter(prefix="/businesses/{business_id}/items/{item_id}", tags=["operations"])
business_router = APIRouter(prefix="/businesses/{business_id}", tags=["operations"])


def _extract_actor_id(claims: dict[str, Any]) -> UUID | None:
    raw = claims.get("sub")
    if not raw:
        return None
    try:
        return UUID(raw)
    except ValueError:
        return None


async def _get_item_or_404(
    business_id: UUID,
    item_id: UUID,
    session: AsyncSession,
) -> Item:
    stmt = select(Item).where(Item.id == item_id, Item.business_id == business_id)
    result = await session.exec(stmt)
    item = result.one_or_none()
    if item is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Item not found")
    return item


async def _call_movement(
    db: AsyncSession,
    business_id: UUID,
    store_id: UUID,
    item_id: UUID,
    quantity_delta: Decimal,
    movement_type: MovementType,
    claims: dict[str, Any],
    reason: str | None = None,
    commit: bool = True,
) -> Any:
    """Thin wrapper: calls ``record_movement`` and maps domain exceptions to HTTP."""
    actor_id = _extract_actor_id(claims)

    try:
        return await record_movement(
            db=db,
            item_id=item_id,
            business_id=business_id,
            store_id=store_id,
            quantity_delta=quantity_delta,
            movement_type=movement_type,
            actor_type=ActorType.USER.value,
            actor_id=actor_id,
            reason=reason,
            commit=commit,
        )
    except ItemTypeMismatchError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail=str(exc),
        ) from exc
    except InsufficientStockError as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=str(exc),
        ) from exc


@items_router.post("/adjust", response_model=StockMovementRead, status_code=status.HTTP_201_CREATED)
async def adjust_stock(
    business_id: UUID,
    item_id: UUID,
    body: AdjustStockRequest,
    session: Annotated[AsyncSession, Depends(get_db)],
    _jwt_biz_id: Annotated[str, Depends(require_business_permission("inventory.adjust"))],
    claims: Annotated[dict[str, Any], Depends(get_current_claims)],
) -> Any:
    """Manually adjust stock for an item by a positive or negative delta."""
    item = await _get_item_or_404(business_id, item_id, session)
    ensure_store_access(claims, item.store_id)

    movement = await _call_movement(
        db=session,
        business_id=business_id,
        store_id=item.store_id,
        item_id=item_id,
        quantity_delta=body.quantity_delta,
        movement_type=MovementType.MANUAL_ADJUSTMENT,
        claims=claims,
        reason=body.reason,
    )

    logger.info(
        "operation.adjust",
        item_id=str(item_id),
        business_id=str(business_id),
        delta=str(body.quantity_delta),
        reason=body.reason,
    )
    return movement


@items_router.post("/waste", response_model=StockMovementRead, status_code=status.HTTP_201_CREATED)
async def record_waste(
    business_id: UUID,
    item_id: UUID,
    body: RecordWasteRequest,
    session: Annotated[AsyncSession, Depends(get_db)],
    _jwt_biz_id: Annotated[str, Depends(require_business_permission("inventory.waste.record"))],
    claims: Annotated[dict[str, Any], Depends(get_current_claims)],
) -> Any:
    """Record wasted/spoiled stock (quantity is a positive number, negated internally)."""
    item = await _get_item_or_404(business_id, item_id, session)
    ensure_store_access(claims, item.store_id)

    movement = await _call_movement(
        db=session,
        business_id=business_id,
        store_id=item.store_id,
        item_id=item_id,
        quantity_delta=-body.quantity,
        movement_type=MovementType.WASTE,
        claims=claims,
        reason=body.reason,
    )

    logger.info(
        "operation.waste",
        item_id=str(item_id),
        business_id=str(business_id),
        quantity=str(body.quantity),
        reason=body.reason,
    )
    return movement


@business_router.post(
    "/transfer", response_model=list[StockMovementRead], status_code=status.HTTP_201_CREATED
)
async def transfer_stock(
    business_id: UUID,
    body: TransferStockRequest,
    session: Annotated[AsyncSession, Depends(get_db)],
    _jwt_biz_id: Annotated[str, Depends(require_business_permission("inventory.transfer"))],
    claims: Annotated[dict[str, Any], Depends(get_current_claims)],
) -> Any:
    """Transfer stock from one store to another within the same business.

    Both movements (TRANSFER_OUT at source, TRANSFER_IN at destination)
    happen in a single transaction so that a failure in either leg rolls
    back both.
    """
    ensure_store_access(claims, body.source_store_id)
    ensure_store_access(claims, body.destination_store_id)
    await _get_item_or_404(business_id, body.item_id, session)

    actor_id = _extract_actor_id(claims)

    try:
        movement_out = await record_movement(
            db=session,
            item_id=body.item_id,
            business_id=business_id,
            store_id=body.source_store_id,
            quantity_delta=-body.quantity,
            movement_type=MovementType.TRANSFER_OUT,
            actor_type=ActorType.USER.value,
            actor_id=actor_id,
            reason=f"Transfer to store {body.destination_store_id}",
            commit=False,
        )
        movement_in = await record_movement(
            db=session,
            item_id=body.item_id,
            business_id=business_id,
            store_id=body.destination_store_id,
            quantity_delta=body.quantity,
            movement_type=MovementType.TRANSFER_IN,
            actor_type=ActorType.USER.value,
            actor_id=actor_id,
            reason=f"Transfer from store {body.source_store_id}",
            commit=False,
        )
        await session.commit()
        await session.refresh(movement_out)
        await session.refresh(movement_in)
    except ItemTypeMismatchError as exc:
        await session.rollback()
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
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
        "operation.transfer",
        item_id=str(body.item_id),
        business_id=str(business_id),
        quantity=str(body.quantity),
        source=str(body.source_store_id),
        destination=str(body.destination_store_id),
    )

    return [movement_out, movement_in]
