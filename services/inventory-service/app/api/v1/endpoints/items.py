"""Item management endpoints — full CRUD, soft-delete only.

┌──────────────────────────────────────────────────────────────────────────┐
│ PERMISSION MODEL                                                         │
│                                                                          │
│   POST   /businesses/{business_id}/items  → INVENTORY_ITEMS_CREATE       │
│   GET    /businesses/{business_id}/items  → INVENTORY_VIEW               │
│   GET    /businesses/{business_id}/items/{item_id} → INVENTORY_VIEW       │
│   PATCH  /businesses/{business_id}/items/{item_id} → INVENTORY_ITEMS_UPDATE │
│   DELETE /businesses/{business_id}/items/{item_id} → INVENTORY_ITEMS_DEACTIVATE │
│                                                                          │
│ Per Stage 8.5 Gap 3, the old coarse INVENTORY_ADJUST has been split     │
│ into INVENTORY_ITEMS_CREATE / UPDATE / DEACTIVATE, INVENTORY_WASTE_RECORD│
│ and INVENTORY_TRANSFER for finer-grained control over each operation.    │
└──────────────────────────────────────────────────────────────────────────┘

Business-context binding is enforced at the shared dependency level
(``require_business_permission``), not per-endpoint.
"""

from __future__ import annotations

from decimal import Decimal
from typing import Annotated, Any
from uuid import UUID

import structlog
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlmodel import select
from sqlmodel.ext.asyncio.session import AsyncSession
from sqlmodel.sql.expression import SelectOfScalar

from app.core.database import get_db
from app.deps.auth import (
    ensure_store_access,
    get_current_claims,
    require_business_permission,
    resolve_store_filter,
)
from app.models.inventory import ActorType, Item, MovementType, StockLevel
from app.models.suppliers import Supplier
from app.schemas.items import ItemCreate, ItemListFilters, ItemRead, ItemUpdate
from app.services.stock_movement_service import record_movement

logger = structlog.get_logger(__name__)
router = APIRouter(prefix="/businesses/{business_id}/items", tags=["items"])


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


async def _validate_supplier_or_404(
    business_id: UUID,
    supplier_id: UUID,
    session: AsyncSession,
) -> None:
    stmt = select(Supplier).where(
        Supplier.id == supplier_id,
        Supplier.business_id == business_id,
        Supplier.is_deleted == False,  # noqa: E712
    )
    result = await session.exec(stmt)
    if result.one_or_none() is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Supplier not found")


async def _build_list_query(
    business_id: UUID,
    filters: ItemListFilters,
    store_id: UUID | None = None,
) -> SelectOfScalar[Item]:
    stmt = select(Item).where(Item.business_id == business_id)

    if filters.category_id is not None:
        stmt = stmt.where(Item.category_id == filters.category_id)
    if filters.supplier_id is not None:
        stmt = stmt.where(Item.supplier_id == filters.supplier_id)
    if filters.is_active is not None:
        stmt = stmt.where(Item.is_active == filters.is_active)
    if store_id is not None:
        stmt = stmt.where(Item.store_id == store_id)
    if filters.below_threshold:
        stmt = (
            select(Item)
            .join(StockLevel, StockLevel.item_id == Item.id, isouter=True)
            .where(
                Item.business_id == business_id,
                StockLevel.current_quantity <= Item.reorder_threshold,
            )
        )
        if filters.category_id is not None:
            stmt = stmt.where(Item.category_id == filters.category_id)
        if filters.supplier_id is not None:
            stmt = stmt.where(Item.supplier_id == filters.supplier_id)
        if filters.is_active is not None:
            stmt = stmt.where(Item.is_active == filters.is_active)
        if store_id is not None:
            stmt = stmt.where(StockLevel.store_id == store_id)

    stmt = stmt.order_by(Item.created_at.desc())
    return stmt


@router.post("", response_model=ItemRead, status_code=status.HTTP_201_CREATED)
async def create_item(
    business_id: UUID,
    body: ItemCreate,
    session: Annotated[AsyncSession, Depends(get_db)],
    _jwt_biz_id: Annotated[str, Depends(require_business_permission("inventory.items.create"))],
    claims: Annotated[dict[str, Any], Depends(get_current_claims)],
) -> Item:
    """Create a new item for the business.

    ═══════════════════════════════════════════════════════════════════
    CROSS-SERVICE VALIDATION GAP (deferred)
    ═══════════════════════════════════════════════════════════════════

    ``store_id`` is accepted as-given without verifying that
    the store actually belongs to ``business_id``.  Ideally this
    endpoint would call Identity Service's ``GET /businesses/{business_id}/stores/{store_id}``
    (or equivalent) to confirm the store is valid for this business,
    but that cross-service call is out of scope for this stage.

    For now we trust the caller (who is already authenticated and
    authorized via JWT).  A follow-up should add a gRPC or HTTP call to
    Identity Service to validate the store before persisting.
    """
    if body.supplier_id is not None:
        await _validate_supplier_or_404(business_id, body.supplier_id, session)
    ensure_store_access(claims, body.store_id)
    item = Item(
        business_id=business_id,
        store_id=body.store_id,
        name=body.name,
        unit_id=body.unit_id,
        category_id=body.category_id,
        supplier_id=body.supplier_id,
        reorder_threshold=body.reorder_threshold,
        reorder_quantity=body.reorder_quantity,
        selling_price=body.selling_price,
        unit_cost=body.unit_cost,
        allow_negative_stock=body.allow_negative_stock,
        item_type=body.item_type,
    )
    session.add(item)
    # Flush (no commit) so item.id exists for the opening-stock movement
    # below — the movement's commit then persists both rows atomically.
    await session.flush()

    initial_qty = body.initial_quantity or Decimal("0")
    if initial_qty > 0:
        raw_sub = claims.get("sub")
        try:
            actor_id = UUID(raw_sub) if raw_sub else None
        except ValueError:
            actor_id = None
        await record_movement(
            db=session,
            item_id=item.id,
            business_id=business_id,
            store_id=body.store_id,
            quantity_delta=initial_qty,
            movement_type=MovementType.MANUAL_ADJUSTMENT,
            actor_type=ActorType.USER.value,
            actor_id=actor_id,
            reason="Opening stock",
        )
        # record_movement(commit=True) already committed + refreshed.
        await session.refresh(item)
    else:
        await session.commit()
        await session.refresh(item)

    logger.info(
        "item.created",
        item_id=str(item.id),
        business_id=str(business_id),
        store_id=str(body.store_id),
        name=item.name,
        item_type=str(item.item_type),
        initial_quantity=str(initial_qty),
    )
    return item


@router.get("", response_model=list[ItemRead])
async def list_items(
    business_id: UUID,
    filters: Annotated[ItemListFilters, Depends()],
    session: Annotated[AsyncSession, Depends(get_db)],
    _jwt_biz_id: Annotated[str, Depends(require_business_permission("inventory.view"))],
    claims: Annotated[dict[str, Any], Depends(get_current_claims)],
    limit: int = Query(default=20, ge=1, le=100, description="Max items per page"),
    offset: int = Query(default=0, ge=0, description="Number of items to skip"),
) -> list[Item]:
    """List items for the business with filtering and pagination.

    Pagination is simple limit/offset, consistent with Identity Service's
    admin CRUD convention.  ``below_threshold=true`` joins against
    ``stock_levels`` and returns only items whose ``current_quantity``
    is at or below their ``reorder_threshold``.

    Store-pinned tokens are always constrained to their own store; an
    explicit foreign ``store_id`` filter is rejected with 403.
    """
    store_id = resolve_store_filter(claims, filters.store_id)
    stmt = await _build_list_query(business_id, filters, store_id)
    stmt = stmt.offset(offset).limit(limit)
    result = await session.exec(stmt)
    return list(result.all())


@router.get("/{item_id}", response_model=ItemRead)
async def get_item(
    business_id: UUID,
    item_id: UUID,
    session: Annotated[AsyncSession, Depends(get_db)],
    _jwt_biz_id: Annotated[str, Depends(require_business_permission("inventory.view"))],
    claims: Annotated[dict[str, Any], Depends(get_current_claims)],
) -> Item:
    """Get a single item by ID.

    Returns the item even if ``is_active`` is False.  Deactivation is a
    status field, not an existence flag — downstream operations (e.g.
    historical movement lookups) need to reference deactivated items.
    """
    item = await _get_item_or_404(business_id, item_id, session)
    ensure_store_access(claims, item.store_id)
    return item


@router.patch("/{item_id}", response_model=ItemRead)
async def update_item(
    business_id: UUID,
    item_id: UUID,
    body: ItemUpdate,
    session: Annotated[AsyncSession, Depends(get_db)],
    _jwt_biz_id: Annotated[str, Depends(require_business_permission("inventory.items.update"))],
    claims: Annotated[dict[str, Any], Depends(get_current_claims)],
) -> Item:
    """Update an item's mutable fields.

    ``business_id`` and ``store_id`` cannot be changed via
    this endpoint (``ItemUpdate`` excludes them by design).  Relocating
    an item is a transfer operation handled in a later stage.
    """
    item = await _get_item_or_404(business_id, item_id, session)
    ensure_store_access(claims, item.store_id)
    update_data = body.model_dump(exclude_unset=True)

    if not update_data:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No fields provided for update",
        )

    if update_data.get("supplier_id") is not None:
        await _validate_supplier_or_404(business_id, update_data["supplier_id"], session)

    for field, value in update_data.items():
        setattr(item, field, value)

    session.add(item)
    await session.commit()
    await session.refresh(item)

    logger.info(
        "item.updated",
        item_id=str(item.id),
        business_id=str(business_id),
        updated_fields=list(update_data.keys()),
    )
    return item


@router.delete("/{item_id}", status_code=status.HTTP_204_NO_CONTENT)
async def deactivate_item(
    business_id: UUID,
    item_id: UUID,
    session: Annotated[AsyncSession, Depends(get_db)],
    _jwt_biz_id: Annotated[str, Depends(require_business_permission("inventory.items.deactivate"))],
    claims: Annotated[dict[str, Any], Depends(get_current_claims)],
) -> None:
    """Soft-deactivate an item (sets ``is_active=False``).

    ┌─────────────────────────────────────────────────────────────────────┐
    │ SOFT DELETE POLICY                                                   │
    │                                                                      │
    │ • This is a soft deactivation only — the row is NOT removed.         │
    │ • Deactivating an item with nonzero stock levels IS allowed.         │
    │   "Deactivation" means "stop transacting this item," not             │
    │   "this item must have zero stock."  Those are separate concerns.   │
    │ • Historical stock_movements referencing this item are preserved.    │
    │                                                                      │
    │ This matches Identity Service's admin user deactivation pattern.     │
    └─────────────────────────────────────────────────────────────────────┘
    """
    item = await _get_item_or_404(business_id, item_id, session)
    ensure_store_access(claims, item.store_id)
    if not item.is_active:
        logger.warning(
            "item.deactivate_skipped",
            item_id=str(item.id),
            business_id=str(business_id),
            reason="already inactive",
        )
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Item is already inactive",
        )

    item.is_active = False
    session.add(item)
    await session.commit()

    logger.info(
        "item.deactivated",
        item_id=str(item.id),
        business_id=str(business_id),
    )
