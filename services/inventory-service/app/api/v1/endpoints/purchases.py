"""Purchases endpoints — two-step purchase orders (create → receive).

┌──────────────────────────────────────────────────────────────────────────┐
│ PERMISSION MODEL                                                         │
│                                                                          │
│   POST /orders                                  → PROCUREMENT_CREATE     │
│   GET  /orders  /orders/{id}                   → PROCUREMENT_VIEW       │
│   POST /orders/{id}/receive                    → PROCUREMENT_RECEIVE    │
│   POST /orders/{id}/cancel                     → PROCUREMENT_CREATE     │
└──────────────────────────────────────────────────────────────────────────┘

``receive_order`` is the non-trivial piece: it creates one ``GoodsReceipt``
+ ``GoodsReceiptLine`` rows (each receipt line carries the actual
``unit_cost`` for that delivery) and loops ``record_movement()`` (the same
core engine ``operations.py``/``reorders.py`` use) with
``movement_type=PURCHASE_RECEIVED`` and ``reference_type="goods_receipt"``,
updates each line's ``quantity_received`` counter and the item's weighted-
average ``unit_cost`` from the receipt cost, then re-derives the PO status
(``fulfilled`` once every line is fully received, else still
``unfulfilled``) — ALL in one transaction (``commit=False`` on every
movement call, one ``session.commit()`` at the end), mirroring
``operations.py``'s ``transfer_stock`` pattern.

ONLINE-ONLY: every write is a direct single-transaction API call — there is
no offline outbox for purchases. The Flutter client gates these endpoints
on connectivity (see ``ConnectivityService``), mirroring the existing
supplier/reorder no-outbox convention.
"""

from __future__ import annotations

from datetime import UTC, datetime
from decimal import Decimal
from typing import Annotated, Any
from uuid import UUID

import structlog
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func
from sqlalchemy.exc import IntegrityError
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
from app.models.inventory import ActorType, Item, ItemType, MovementType, StockLevel
from app.models.purchases import (
    GoodsReceipt,
    GoodsReceiptLine,
    PurchaseOrder,
    PurchaseOrderLine,
    PurchaseOrderStatus,
)
from app.models.suppliers import Supplier
from app.models.units import Unit
from app.schemas.purchases import (
    GoodsReceiptCreate,
    GoodsReceiptDetailRead,
    GoodsReceiptLineRead,
    GoodsReceiptRead,
    PurchaseOrderCreate,
    PurchaseOrderDetailRead,
    PurchaseOrderLineRead,
    PurchaseOrderListFilters,
    PurchaseOrderListResponse,
    PurchaseOrderRead,
)
from app.services.stock_movement_service import (
    InsufficientStockError,
    ItemTypeMismatchError,
    record_movement,
)

logger = structlog.get_logger(__name__)
router = APIRouter(prefix="/businesses/{business_id}/purchases", tags=["purchases"])


def _extract_actor_id(claims: dict[str, Any]) -> UUID | None:
    raw = claims.get("sub")
    if not raw:
        return None
    try:
        return UUID(raw)
    except ValueError:
        return None


async def _get_po_or_404(
    business_id: UUID,
    order_id: UUID,
    session: AsyncSession,
) -> PurchaseOrder:
    stmt = select(PurchaseOrder).where(
        PurchaseOrder.id == order_id, PurchaseOrder.business_id == business_id
    )
    po = (await session.exec(stmt)).one_or_none()
    if po is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Purchase order not found"
        )
    return po


async def _get_supplier_or_404(
    business_id: UUID,
    supplier_id: UUID,
    session: AsyncSession,
    *,
    allow_deleted: bool = False,
) -> Supplier:
    stmt = select(Supplier).where(
        Supplier.id == supplier_id, Supplier.business_id == business_id
    )
    if not allow_deleted:
        stmt = stmt.where(Supplier.is_deleted == False)  # noqa: E712
    supplier = (await session.exec(stmt)).one_or_none()
    if supplier is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Supplier not found"
        )
    return supplier


async def _next_number(
    session: AsyncSession,
    model: type[PurchaseOrder] | type[GoodsReceipt],
    business_id: UUID,
    prefix: str,
) -> str:
    """Next ``PREFIX-0001``-style number scoped to the business."""
    count = (
        await session.exec(
            select(func.count())
            .select_from(model)
            .where(model.business_id == business_id)
        )
    ).one()
    return f"{prefix}-{int(count) + 1:04d}"


async def _build_detail(
    po: PurchaseOrder, session: AsyncSession
) -> PurchaseOrderDetailRead:
    lines = (
        await session.exec(
            select(PurchaseOrderLine).where(
                PurchaseOrderLine.purchase_order_id == po.id
            )
        )
    ).all()
    receipts = (
        await session.exec(
            select(GoodsReceipt)
            .where(GoodsReceipt.purchase_order_id == po.id)
            .order_by(GoodsReceipt.received_at)
        )
    ).all()
    header = PurchaseOrderRead.model_validate(po)
    return PurchaseOrderDetailRead(
        **header.model_dump(),
        lines=[PurchaseOrderLineRead.model_validate(line) for line in lines],
        receipts=[GoodsReceiptRead.model_validate(grn) for grn in receipts],
    )


def _build_list_query(
    business_id: UUID,
    filters: PurchaseOrderListFilters,
    store_id: UUID | None = None,
) -> SelectOfScalar[PurchaseOrder]:
    stmt = select(PurchaseOrder).where(PurchaseOrder.business_id == business_id)
    if filters.status is not None:
        stmt = stmt.where(PurchaseOrder.status == filters.status)
    if filters.supplier_id is not None:
        stmt = stmt.where(PurchaseOrder.supplier_id == filters.supplier_id)
    if store_id is not None:
        stmt = stmt.where(PurchaseOrder.store_id == store_id)
    return stmt.order_by(PurchaseOrder.ordered_at.desc())


# ═══════════════════════════════════════════════════════════════════════
# Purchase orders — step 1: create
# ═══════════════════════════════════════════════════════════════════════


@router.post("/orders", response_model=PurchaseOrderRead, status_code=status.HTTP_201_CREATED)
async def create_order(
    business_id: UUID,
    body: PurchaseOrderCreate,
    session: Annotated[AsyncSession, Depends(get_db)],
    claims: Annotated[dict[str, Any], Depends(get_current_claims)],
    _jwt_biz_id: Annotated[str, Depends(require_business_permission("procurement.create"))],
) -> PurchaseOrder:
    await _get_supplier_or_404(business_id, body.supplier_id, session)
    ensure_store_access(claims, body.store_id)

    resolved: list[tuple[Item, str]] = []
    for line in body.lines:
        item = (
            await session.exec(
                select(Item).where(
                    Item.id == line.item_id, Item.business_id == business_id
                )
            )
        ).one_or_none()
        if item is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Item '{line.item_id}' not found",
            )
        if item.item_type == ItemType.SELLABLE:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                detail=(
                    f"Cannot purchase sellable-only item '{item.name}' — it can "
                    "never be purchase-received. Order its raw-material "
                    "components instead."
                ),
            )
        if item.unit_id is None:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                detail=f"Item '{item.name}' has no unit assigned.",
            )
        ensure_store_access(claims, item.store_id)
        unit = (
            await session.exec(select(Unit).where(Unit.id == item.unit_id))
        ).one_or_none()
        if unit is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Item '{item.name}' references a missing unit.",
            )
        resolved.append((item, unit.code))

    if body.po_number is not None:
        existing = (
            await session.exec(
                select(PurchaseOrder).where(
                    PurchaseOrder.business_id == business_id,
                    PurchaseOrder.po_number == body.po_number,
                )
            )
        ).one_or_none()
        if existing is not None:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"PO number '{body.po_number}' already exists",
            )
        po_number = body.po_number
    else:
        po_number = await _next_number(session, PurchaseOrder, business_id, "PO")

    po = PurchaseOrder(
        business_id=business_id,
        store_id=body.store_id,
        supplier_id=body.supplier_id,
        po_number=po_number,
        status=PurchaseOrderStatus.UNFULFILLED,
        notes=body.notes,
        ordered_at=datetime.now(UTC),
        ordered_by=_extract_actor_id(claims),
        expected_at=body.expected_at,
    )
    session.add(po)
    # Flush so the header row exists before its lines reference it.
    await session.flush()
    for line, (_item, unit_code) in zip(body.lines, resolved, strict=True):
        session.add(
            PurchaseOrderLine(
                purchase_order_id=po.id,
                item_id=line.item_id,
                quantity_ordered=line.quantity_ordered,
                quantity_received=Decimal("0.000"),
                unit=unit_code,
                notes=line.notes,
            )
        )
    try:
        await session.commit()
    except IntegrityError as exc:
        await session.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="PO number already exists — retry without an explicit po_number",
        ) from exc
    await session.refresh(po)

    logger.info(
        "purchase.created",
        order_id=str(po.id),
        business_id=str(business_id),
        po_number=po_number,
    )
    return po


@router.get("/orders", response_model=PurchaseOrderListResponse)
async def list_orders(
    business_id: UUID,
    filters: Annotated[PurchaseOrderListFilters, Depends()],
    session: Annotated[AsyncSession, Depends(get_db)],
    _jwt_biz_id: Annotated[str, Depends(require_business_permission("procurement.view"))],
    claims: Annotated[dict[str, Any], Depends(get_current_claims)],
    limit: int = Query(default=20, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
) -> PurchaseOrderListResponse:
    store_id = resolve_store_filter(claims, filters.store_id)
    base_stmt = _build_list_query(business_id, filters, store_id)
    total = len((await session.exec(base_stmt)).all())
    items = list((await session.exec(base_stmt.offset(offset).limit(limit))).all())
    return PurchaseOrderListResponse(
        items=items, total=total, limit=limit, offset=offset
    )


@router.post("/orders/{order_id}/cancel", response_model=PurchaseOrderRead)
async def cancel_order(
    business_id: UUID,
    order_id: UUID,
    session: Annotated[AsyncSession, Depends(get_db)],
    claims: Annotated[dict[str, Any], Depends(get_current_claims)],
    _jwt_biz_id: Annotated[str, Depends(require_business_permission("procurement.create"))],
) -> PurchaseOrder:
    po = await _get_po_or_404(business_id, order_id, session)
    ensure_store_access(claims, po.store_id)
    if po.status == PurchaseOrderStatus.CANCELLED:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Order is already cancelled",
        )
    if po.status == PurchaseOrderStatus.FULFILLED:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Order is fulfilled, cannot cancel it",
        )
    received = (
        await session.exec(
            select(PurchaseOrderLine).where(
                PurchaseOrderLine.purchase_order_id == po.id,
                PurchaseOrderLine.quantity_received > 0,
            )
        )
    ).all()
    if received:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Order has receipts, cannot cancel it — receive the rest instead",
        )
    po.status = PurchaseOrderStatus.CANCELLED
    po.cancelled_at = datetime.now(UTC)
    po.cancelled_by = _extract_actor_id(claims)
    session.add(po)
    await session.commit()
    await session.refresh(po)
    logger.info("purchase.cancelled", order_id=str(po.id), business_id=str(business_id))
    return po


# ═══════════════════════════════════════════════════════════════════════
# Purchase orders — step 2: receive
# ═══════════════════════════════════════════════════════════════════════


@router.post("/orders/{order_id}/receive", response_model=GoodsReceiptDetailRead)
async def receive_order(
    business_id: UUID,
    order_id: UUID,
    body: GoodsReceiptCreate,
    session: Annotated[AsyncSession, Depends(get_db)],
    claims: Annotated[dict[str, Any], Depends(get_current_claims)],
    _jwt_biz_id: Annotated[str, Depends(require_business_permission("procurement.receive"))],
) -> GoodsReceiptDetailRead:
    po = await _get_po_or_404(business_id, order_id, session)
    ensure_store_access(claims, po.store_id)
    if po.status != PurchaseOrderStatus.UNFULFILLED:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Order is {po.status.value}, only unfulfilled orders can be received",
        )
    actor_id = _extract_actor_id(claims)

    lines = (
        await session.exec(
            select(PurchaseOrderLine).where(PurchaseOrderLine.purchase_order_id == po.id)
        )
    ).all()
    lines_by_id = {line.id: line for line in lines}

    grn = GoodsReceipt(
        business_id=business_id,
        store_id=po.store_id,
        purchase_order_id=po.id,
        grn_number=await _next_number(session, GoodsReceipt, business_id, "GRN"),
        notes=body.notes,
        received_at=datetime.now(UTC),
        received_by=actor_id,
    )
    session.add(grn)

    try:
        for req in body.lines:
            pol = lines_by_id.get(req.purchase_order_line_id)
            if pol is None:
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                    detail=f"PO line '{req.purchase_order_line_id}' is not on this order",
                )
            outstanding = pol.quantity_ordered - pol.quantity_received
            if req.quantity_received > outstanding:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=(
                        f"Over-receive on line '{pol.id}': ordered={pol.quantity_ordered}, "
                        f"already received={pol.quantity_received}, "
                        f"requested={req.quantity_received}"
                    ),
                )

            item_result = await session.exec(
                select(Item).where(
                    Item.id == pol.item_id, Item.business_id == business_id
                )
            )
            item = item_result.one_or_none()
            if item is None:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail=f"Item '{pol.item_id}' not found",
                )

            level = (
                await session.exec(
                    select(StockLevel).where(
                        StockLevel.item_id == item.id,
                        StockLevel.store_id == po.store_id,
                    )
                )
            ).one_or_none()
            old_qty: Decimal = level.current_quantity if level else Decimal("0.000")
            old_cost: Decimal | None = item.unit_cost

            await record_movement(
                db=session,
                item_id=item.id,
                business_id=business_id,
                store_id=po.store_id,
                quantity_delta=req.quantity_received,
                movement_type=MovementType.PURCHASE_RECEIVED,
                reference_type="goods_receipt",
                reference_id=grn.id,
                actor_type=ActorType.USER.value,
                actor_id=actor_id,
                reason=f"GRN {grn.grn_number} for PO {po.po_number}",
                commit=False,
                unit_cost=req.unit_cost,
            )

            # Weighted-average costing in the same transaction, driven by
            # the receipt line's actual cost — the PO itself carries no money.
            basis = old_cost if old_cost is not None else req.unit_cost
            denom = old_qty + req.quantity_received
            if denom > 0:
                new_cost = (
                    (old_qty * basis + req.quantity_received * req.unit_cost) / denom
                ).quantize(Decimal("0.0001"))
            else:
                new_cost = req.unit_cost
            item.unit_cost = new_cost
            session.add(item)

            pol.quantity_received = pol.quantity_received + req.quantity_received
            session.add(pol)
            session.add(
                GoodsReceiptLine(
                    goods_receipt_id=grn.id,
                    purchase_order_line_id=pol.id,
                    item_id=item.id,
                    quantity_received=req.quantity_received,
                    unit_cost=req.unit_cost,
                    lot_no=req.lot_no,
                    expiry_date=req.expiry_date,
                )
            )

        refreshed = (
            await session.exec(
                select(PurchaseOrderLine).where(
                    PurchaseOrderLine.purchase_order_id == po.id
                )
            )
        ).all()
        if all(
            line.quantity_received >= line.quantity_ordered for line in refreshed
        ):
            po.status = PurchaseOrderStatus.FULFILLED
            po.received_at = datetime.now(UTC)
            po.received_by = actor_id
        else:
            po.status = PurchaseOrderStatus.UNFULFILLED
        session.add(po)

        await session.commit()
    except (ItemTypeMismatchError, InsufficientStockError) as exc:
        await session.rollback()
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail=str(exc),
        ) from exc
    except HTTPException:
        await session.rollback()
        raise
    except IntegrityError as exc:
        await session.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="GRN number already exists — retry the receive",
        ) from exc
    except Exception:
        await session.rollback()
        raise

    await session.refresh(grn)
    grn_lines = (
        await session.exec(
            select(GoodsReceiptLine).where(GoodsReceiptLine.goods_receipt_id == grn.id)
        )
    ).all()
    logger.info(
        "purchase.received",
        order_id=str(po.id),
        grn_id=str(grn.id),
        business_id=str(business_id),
    )
    header = GoodsReceiptRead.model_validate(grn)
    return GoodsReceiptDetailRead(
        **header.model_dump(),
        lines=[GoodsReceiptLineRead.model_validate(line) for line in grn_lines],
    )


@router.get("/orders/{order_id}", response_model=PurchaseOrderDetailRead)
async def get_order(
    business_id: UUID,
    order_id: UUID,
    session: Annotated[AsyncSession, Depends(get_db)],
    _jwt_biz_id: Annotated[str, Depends(require_business_permission("procurement.view"))],
    claims: Annotated[dict[str, Any], Depends(get_current_claims)],
) -> PurchaseOrderDetailRead:
    """Declared after the literal ``/orders/{id}/…`` action routes so those
    sub-paths are never swallowed by this ``{order_id}`` matcher (same
    ordering discipline as ``reorders.py``)."""
    po = await _get_po_or_404(business_id, order_id, session)
    ensure_store_access(claims, po.store_id)
    return await _build_detail(po, session)
