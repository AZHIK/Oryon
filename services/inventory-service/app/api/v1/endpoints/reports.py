"""Read-only reporting endpoints — stock levels and movement history.

Every endpoint requires ``INVENTORY_VIEW`` permission and returns
paginated results via the standard limit/offset convention.

═══════════════════════════════════════════════════════════════════════════
STAGE 3 OPEN QUESTION — denormalized item fields in StockLevelRead
═══════════════════════════════════════════════════════════════════════════

The original schema had only ``item_name`` and ``item_unit_of_measure``.
This stage adds ``item_category``, ``item_reorder_threshold``, and
``item_type`` so that the Business App can render a complete stock-level
card without a second round-trip per item.

The join is implemented here (the endpoint layer) rather than in a service
function because the endpoint is read-only — it doesn't need transactional
wrapping, and keeping the join visible at the API boundary makes it easy
to optimise later (e.g. add ``store_name`` when cross-service
lookups land).

``item_category`` is now sourced from a further ``Category`` join on
``Item.category_id`` (see ``app/models/categories.py``) rather than a raw
string column — the denormalization rationale above still holds, only the
source changed. ``item_unit_of_measure`` went through the same change:
it's now ``Unit.code`` from a further ``Unit`` join on ``Item.unit_id``
(see ``app/models/units.py``) rather than a Postgres enum column — an
unresolved (``NULL`` FK) unit reads as ``""`` rather than ``None`` since
the field's type predates this change and is still a plain ``str``.

═══════════════════════════════════════════════════════════════════════════
BELOW_THRESHOLD FILTER — shared logic, same predicate
═══════════════════════════════════════════════════════════════════════════

Stage 4's item-list endpoint uses ``StockLevel.current_quantity <=
Item.reorder_threshold`` inside a LEFT JOIN.  This endpoint uses the
**exact same predicate** — the difference is the base entity (StockLevel
here, Item in Stage 4).  Both code paths produce the same result for the
same data.  No duplication — the predicate is a one-line WHERE clause that
cannot meaningfully be extracted into a shared helper.
"""

from __future__ import annotations

from datetime import UTC, date, datetime
from decimal import Decimal
from typing import Annotated, Any
from uuid import UUID

import structlog
from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel
from sqlalchemy import func as sa_func
from sqlmodel import select
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.database import get_db
from app.deps.auth import (
    ensure_store_access,
    get_current_claims,
    require_business_permission,
    resolve_store_filter,
)
from app.models.categories import Category
from app.models.inventory import (
    Item,
    MovementType,
    ProductionEvent,
    ProductionEventComponent,
    StockLevel,
    StockMovement,
)
from app.models.purchases import (
    GoodsReceipt,
    GoodsReceiptLine,
    PurchaseOrder,
    PurchaseOrderLine,
    PurchaseOrderStatus,
)
from app.models.suppliers import Supplier
from app.models.units import Unit
from app.schemas.analytics import (
    ActivityLogLine,
    ActivityLogResponse,
    CostHistoryLine,
    CostHistoryResponse,
    ExpiryLine,
    ExpiryReportResponse,
    IngredientConsumption,
    LotLine,
    LotReportResponse,
    ProductionSummaryResponse,
    ProductPurchaseLine,
    ProductPurchaseResponse,
    StockAdjustmentLine,
    StockAdjustmentResponse,
    StockValuationLine,
    StockValuationResponse,
    SupplierPurchaseLine,
    SupplierPurchaseResponse,
    WasteLine,
    WasteSummaryResponse,
)
from app.schemas.movements import StockMovementRead
from app.schemas.stock_levels import StockLevelRead

logger = structlog.get_logger(__name__)
router = APIRouter(prefix="/businesses/{business_id}", tags=["reports"])


# ═══════════════════════════════════════════════════════════════════════
# Stock-level filters
# ═══════════════════════════════════════════════════════════════════════


class StockLevelFilters(BaseModel):
    store_id: UUID | None = None
    category_id: UUID | None = None
    below_threshold: bool | None = None


# ═══════════════════════════════════════════════════════════════════════
# GET /businesses/{business_id}/stock
# ═══════════════════════════════════════════════════════════════════════


@router.get("/stock", response_model=list[StockLevelRead])
async def get_stock_levels(
    business_id: UUID,
    filters: Annotated[StockLevelFilters, Depends()],
    session: Annotated[AsyncSession, Depends(get_db)],
    _jwt_biz_id: Annotated[str, Depends(require_business_permission("inventory.view"))],
    claims: Annotated[dict[str, Any], Depends(get_current_claims)],
    limit: int = Query(default=20, ge=1, le=100, description="Max items per page"),
    offset: int = Query(default=0, ge=0, description="Number of items to skip"),
    sort_by: str = Query(
        default="name",
        description="Sort field — name, current_quantity, or category",
    ),
) -> list[StockLevelRead]:
    """Current stock levels for the business, one row per item/store.

    Item details (name, unit_of_measure, category, reorder_threshold,
    item_type) are joined in so callers don't need a second round-trip
    per item.
    """
    if sort_by not in ("name", "current_quantity", "category"):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail=f"Invalid sort_by '{sort_by}' — must be name, current_quantity, or category",
        )

    store_id = resolve_store_filter(claims, filters.store_id)

    # Join StockLevel → Item so we can filter/sort on item columns and
    # return denormalized item details — this is the single query that
    # resolves the Stage 3 open question. Category and Unit are further
    # outer joins (item.category_id / item.unit_id are both nullable) so
    # item_category / item_unit_of_measure can be resolved to human-readable
    # strings without a second round-trip per row.
    stmt = (
        select(StockLevel, Item, Category, Unit)
        .join(Item, StockLevel.item_id == Item.id)
        .join(Category, Item.category_id == Category.id, isouter=True)
        .join(Unit, Item.unit_id == Unit.id, isouter=True)
        .where(Item.business_id == business_id)
    )

    if store_id is not None:
        stmt = stmt.where(StockLevel.store_id == store_id)
    if filters.category_id is not None:
        stmt = stmt.where(Item.category_id == filters.category_id)
    if filters.below_threshold:
        stmt = stmt.where(StockLevel.current_quantity <= Item.reorder_threshold)

    sort_map = {
        "name": Item.name,
        "current_quantity": StockLevel.current_quantity,
        "category": Category.name,
    }
    stmt = stmt.order_by(sort_map[sort_by].asc().nullslast())
    stmt = stmt.offset(offset).limit(limit)

    result = await session.exec(stmt)
    rows = result.all()

    levels: list[StockLevelRead] = [
        StockLevelRead(
            item_id=sl.item_id,
            store_id=sl.store_id,
            current_quantity=sl.current_quantity,
            updated_at=sl.updated_at,
            item_name=item.name,
            item_unit_of_measure=unit.code if unit else "",
            item_category=category.name if category else None,
            item_reorder_threshold=item.reorder_threshold,
            item_type=item.item_type,
        )
        for sl, item, category, unit in rows
    ]

    logger.info(
        "reports.stock_levels",
        business_id=str(business_id),
        count=len(levels),
        filters=filters.model_dump(exclude_none=True),
    )
    return levels


# ═══════════════════════════════════════════════════════════════════════
# GET /businesses/{business_id}/items/{item_id}/movements
# ═══════════════════════════════════════════════════════════════════════


@router.get("/items/{item_id}/movements", response_model=list[StockMovementRead])
async def get_item_movements(
    business_id: UUID,
    item_id: UUID,
    session: Annotated[AsyncSession, Depends(get_db)],
    _jwt_biz_id: Annotated[str, Depends(require_business_permission("inventory.view"))],
    claims: Annotated[dict[str, Any], Depends(get_current_claims)],
    limit: int = Query(default=20, ge=1, le=100, description="Max items per page"),
    offset: int = Query(default=0, ge=0, description="Number of items to skip"),
    from_date: date | None = Query(
        default=None, alias="from", description="Start date (inclusive)"
    ),
    to_date: date | None = Query(default=None, alias="to", description="End date (inclusive)"),
    movement_type: MovementType | None = Query(default=None, description="Filter by movement type"),
    store_id: UUID | None = Query(default=None, description="Filter by store"),
) -> list[StockMovementRead]:
    """Paginated movement history for one item, most recent first."""
    store_id = resolve_store_filter(claims, store_id)
    result = await session.exec(
        select(Item).where(Item.id == item_id, Item.business_id == business_id)
    )
    item = result.one_or_none()
    if item is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Item not found")
    ensure_store_access(claims, item.store_id)

    stmt = select(StockMovement).where(
        StockMovement.business_id == business_id,
        StockMovement.item_id == item_id,
    )

    if from_date is not None:
        dt = datetime.combine(from_date, datetime.min.time(), tzinfo=UTC)
        stmt = stmt.where(StockMovement.created_at >= dt)
    if to_date is not None:
        dt = datetime.combine(to_date, datetime.max.time(), tzinfo=UTC)
        stmt = stmt.where(StockMovement.created_at <= dt)
    if movement_type is not None:
        stmt = stmt.where(StockMovement.movement_type == movement_type)
    if store_id is not None:
        stmt = stmt.where(StockMovement.store_id == store_id)

    stmt = stmt.order_by(StockMovement.created_at.desc())
    stmt = stmt.offset(offset).limit(limit)

    result = await session.exec(stmt)
    movements = list(result.all())

    logger.info(
        "reports.item_movements",
        business_id=str(business_id),
        item_id=str(item_id),
        count=len(movements),
    )
    return movements


# ═══════════════════════════════════════════════════════════════════════
# Analytics (waste / production / valuation) — REPORTS_VIEW
#
# These three are newer than the stock/movement reads above, so they gate
# on the dedicated REPORTS_VIEW code (the one the app's Reports nav
# checks) rather than the older INVENTORY_VIEW the reads above predate.
# ═══════════════════════════════════════════════════════════════════════


def _day_bounds(
    from_date: date | None, to_date: date | None
) -> tuple[datetime | None, datetime | None]:
    """Inclusive UTC day bounds, mirroring the movement-history filters."""
    start = (
        datetime.combine(from_date, datetime.min.time(), tzinfo=UTC)
        if from_date is not None
        else None
    )
    end = (
        datetime.combine(to_date, datetime.max.time(), tzinfo=UTC) if to_date is not None else None
    )
    return start, end


@router.get("/waste-summary", response_model=WasteSummaryResponse)
async def waste_summary(
    business_id: UUID,
    session: Annotated[AsyncSession, Depends(get_db)],
    _jwt_biz_id: Annotated[str, Depends(require_business_permission("reports.view"))],
    claims: Annotated[dict[str, Any], Depends(get_current_claims)],
    from_date: date | None = Query(
        default=None, alias="from", description="Start date (inclusive)"
    ),
    to_date: date | None = Query(default=None, alias="to", description="End date (inclusive)"),
    store_id: UUID | None = Query(default=None, description="Filter by store"),
) -> WasteSummaryResponse:
    """Waste recorded in the window, per item, with cost.

    Waste movements store negative deltas, so quantities are negated back
    to positive "wasted" amounts. Cost uses each movement's frozen
    ``unit_cost`` (the basis at event time) — legacy rows without a snapshot
    fall back to the item's current ``unit_cost`` and are flagged estimated.
    An item with no basis anywhere contributes quantity but zero cost.
    """
    store_id = resolve_store_filter(claims, store_id)
    start, end = _day_bounds(from_date, to_date)

    stmt = (
        select(
            StockMovement.item_id,
            Item.name,
            Unit.code,
            Item.unit_cost,
            sa_func.sum(-StockMovement.quantity_delta).label("quantity"),
            # Frozen cost: sum of qty × movement basis per item. Movements
            # without a snapshot (legacy) use the item's current cost.
            sa_func.sum(
                -StockMovement.quantity_delta
                * sa_func.coalesce(StockMovement.unit_cost, Item.unit_cost, Decimal("0"))
            ).label("cost"),
            sa_func.bool_or(StockMovement.unit_cost.is_(None)).label("has_legacy"),
        )
        .join(Item, StockMovement.item_id == Item.id)
        .join(Unit, Item.unit_id == Unit.id, isouter=True)
        .where(
            StockMovement.business_id == business_id,
            StockMovement.movement_type == MovementType.WASTE,
        )
    )
    if start is not None:
        stmt = stmt.where(StockMovement.created_at >= start)
    if end is not None:
        stmt = stmt.where(StockMovement.created_at <= end)
    if store_id is not None:
        stmt = stmt.where(StockMovement.store_id == store_id)
    stmt = stmt.group_by(StockMovement.item_id, Item.name, Unit.code, Item.unit_cost).order_by(
        sa_func.sum(-StockMovement.quantity_delta).desc()
    )

    rows = (await session.exec(stmt)).all()

    lines = [
        WasteLine(
            item_id=row.item_id,
            item_name=row.name,
            item_unit=row.code or "",
            quantity_wasted=row.quantity or Decimal("0"),
            cost_wasted=row.cost or Decimal("0"),
            cost_estimated=bool(row.has_legacy)
            or (
                row.unit_cost is None
                and (row.cost or Decimal("0")) == Decimal("0")
                and (row.quantity or Decimal("0")) != Decimal("0")
            ),
        )
        for row in rows
    ]
    total = sum((line.cost_wasted for line in lines), Decimal("0"))
    estimated = any(line.cost_estimated for line in lines)

    logger.info("reports.waste_summary", business_id=str(business_id), lines=len(lines))
    return WasteSummaryResponse(lines=lines, total_cost_wasted=total, estimated=estimated)


@router.get("/production-summary", response_model=ProductionSummaryResponse)
async def production_summary(
    business_id: UUID,
    session: Annotated[AsyncSession, Depends(get_db)],
    _jwt_biz_id: Annotated[str, Depends(require_business_permission("reports.view"))],
    claims: Annotated[dict[str, Any], Depends(get_current_claims)],
    from_date: date | None = Query(
        default=None, alias="from", description="Start date (inclusive)"
    ),
    to_date: date | None = Query(default=None, alias="to", description="End date (inclusive)"),
    store_id: UUID | None = Query(default=None, description="Filter by store"),
) -> ProductionSummaryResponse:
    """Production runs in the window: counts, suggested-vs-actual totals,
    and per-ingredient consumption.

    ``over_portioned_by`` is actual minus suggested — positive means the
    kitchen stocked more than recipes called for. Same gap the per-event
    payloads carry, summed for the window.
    """
    store_id = resolve_store_filter(claims, store_id)
    start, end = _day_bounds(from_date, to_date)

    base = [ProductionEvent.business_id == business_id]
    if start is not None:
        base.append(ProductionEvent.occurred_at >= start)
    if end is not None:
        base.append(ProductionEvent.occurred_at <= end)
    if store_id is not None:
        base.append(ProductionEvent.store_id == store_id)

    agg = (
        await session.exec(
            select(
                sa_func.count(ProductionEvent.id),
                sa_func.sum(ProductionEvent.suggested_output_quantity),
                sa_func.sum(ProductionEvent.actual_output_quantity),
            ).where(*base)
        )
    ).one()
    runs = agg[0] or 0
    suggested = agg[1] or Decimal("0")
    actual = agg[2] or Decimal("0")

    comp_stmt = (
        select(
            ProductionEventComponent.raw_material_item_id,
            Item.name,
            Unit.code,
            sa_func.sum(ProductionEventComponent.quantity_consumed).label("quantity"),
        )
        .join(
            ProductionEvent,
            ProductionEventComponent.production_event_id == ProductionEvent.id,
        )
        .join(Item, ProductionEventComponent.raw_material_item_id == Item.id)
        .join(Unit, Item.unit_id == Unit.id, isouter=True)
        .where(*base)
        .group_by(ProductionEventComponent.raw_material_item_id, Item.name, Unit.code)
        .order_by(sa_func.sum(ProductionEventComponent.quantity_consumed).desc())
    )
    comp_rows = (await session.exec(comp_stmt)).all()

    logger.info("reports.production_summary", business_id=str(business_id), runs=runs)
    return ProductionSummaryResponse(
        runs=runs,
        suggested_total=suggested,
        actual_total=actual,
        over_portioned_by=actual - suggested,
        ingredients_consumed=[
            IngredientConsumption(
                raw_material_item_id=row.raw_material_item_id,
                raw_material_name=row.name,
                raw_material_unit=row.code or "",
                quantity_consumed=row.quantity or Decimal("0"),
            )
            for row in comp_rows
        ],
    )


@router.get("/stock-valuation", response_model=StockValuationResponse)
async def stock_valuation(
    business_id: UUID,
    session: Annotated[AsyncSession, Depends(get_db)],
    _jwt_biz_id: Annotated[str, Depends(require_business_permission("reports.view"))],
    claims: Annotated[dict[str, Any], Depends(get_current_claims)],
    store_id: UUID | None = Query(default=None, description="Filter by store"),
) -> StockValuationResponse:
    """Current inventory value (on-hand × unit cost), total and by category.

    A point-in-time snapshot, not a windowed report — stock levels only know
    the present. Items without a cost basis contribute quantity but zero
    value rather than vanishing from the total.
    """
    store_id = resolve_store_filter(claims, store_id)
    stmt = (
        select(
            Category.name,
            sa_func.count(StockLevel.item_id).label("items"),
            sa_func.sum(
                StockLevel.current_quantity * sa_func.coalesce(Item.unit_cost, Decimal("0"))
            ).label("value"),
        )
        .join(Item, StockLevel.item_id == Item.id)
        .join(Category, Item.category_id == Category.id, isouter=True)
        .where(Item.business_id == business_id)
    )
    if store_id is not None:
        stmt = stmt.where(StockLevel.store_id == store_id)
    stmt = stmt.group_by(Category.name).order_by(
        sa_func.sum(
            StockLevel.current_quantity * sa_func.coalesce(Item.unit_cost, Decimal("0"))
        ).desc()
    )

    rows = (await session.exec(stmt)).all()
    lines = [
        StockValuationLine(
            category=row[0],
            item_count=row[1],
            total_value=row[2] or Decimal("0"),
        )
        for row in rows
    ]
    total = sum((line.total_value for line in lines), Decimal("0"))

    logger.info("reports.stock_valuation", business_id=str(business_id), total=str(total))
    return StockValuationResponse(total_value=total, lines=lines)


@router.get("/product-purchases", response_model=ProductPurchaseResponse)
async def product_purchases(
    business_id: UUID,
    session: Annotated[AsyncSession, Depends(get_db)],
    _jwt_biz_id: Annotated[str, Depends(require_business_permission("reports.view"))],
    claims: Annotated[dict[str, Any], Depends(get_current_claims)],
    from_date: date | None = Query(
        default=None, alias="from", description="Start date (inclusive)"
    ),
    to_date: date | None = Query(default=None, alias="to", description="End date (inclusive)"),
    store_id: UUID | None = Query(default=None, description="Filter by store"),
    supplier_id: UUID | None = Query(default=None, description="Filter by supplier"),
) -> ProductPurchaseResponse:
    """Product Purchase Report: quantities and cost per item+supplier.

    Quantities ordered come from ``PurchaseOrderLine`` (qty-only); received
    quantities and cost come from ``GoodsReceiptLine`` actuals
    (qty × receipt unit_cost). Cancelled orders are excluded — a cancelled
    PO is intent, not spend.
    """
    store_id = resolve_store_filter(claims, store_id)
    start, end = _day_bounds(from_date, to_date)
    ordered_stmt = (
        select(
            PurchaseOrderLine.item_id.label("item_id"),
            PurchaseOrder.supplier_id.label("supplier_id"),
            sa_func.sum(PurchaseOrderLine.quantity_ordered).label("qty_ordered"),
        )
        .join(PurchaseOrder, PurchaseOrderLine.purchase_order_id == PurchaseOrder.id)
        .where(
            PurchaseOrder.business_id == business_id,
            PurchaseOrder.status != PurchaseOrderStatus.CANCELLED,
        )
    )
    if start is not None:
        ordered_stmt = ordered_stmt.where(PurchaseOrder.ordered_at >= start)
    if end is not None:
        ordered_stmt = ordered_stmt.where(PurchaseOrder.ordered_at <= end)
    if store_id is not None:
        ordered_stmt = ordered_stmt.where(PurchaseOrder.store_id == store_id)
    if supplier_id is not None:
        ordered_stmt = ordered_stmt.where(PurchaseOrder.supplier_id == supplier_id)
    ordered_stmt = ordered_stmt.group_by(PurchaseOrderLine.item_id, PurchaseOrder.supplier_id)
    ordered_rows = (await session.exec(ordered_stmt)).all()
    ordered = {(r.item_id, r.supplier_id): r.qty_ordered or Decimal("0") for r in ordered_rows}

    received_stmt = (
        select(
            GoodsReceiptLine.item_id.label("item_id"),
            PurchaseOrder.supplier_id.label("supplier_id"),
            sa_func.sum(GoodsReceiptLine.quantity_received).label("qty_received"),
            sa_func.sum(GoodsReceiptLine.quantity_received * GoodsReceiptLine.unit_cost).label(
                "cost"
            ),
        )
        .join(GoodsReceipt, GoodsReceiptLine.goods_receipt_id == GoodsReceipt.id)
        .join(PurchaseOrder, GoodsReceipt.purchase_order_id == PurchaseOrder.id)
        .where(
            GoodsReceipt.business_id == business_id,
            PurchaseOrder.status != PurchaseOrderStatus.CANCELLED,
        )
    )
    if start is not None:
        received_stmt = received_stmt.where(PurchaseOrder.ordered_at >= start)
    if end is not None:
        received_stmt = received_stmt.where(PurchaseOrder.ordered_at <= end)
    if store_id is not None:
        received_stmt = received_stmt.where(GoodsReceipt.store_id == store_id)
    if supplier_id is not None:
        received_stmt = received_stmt.where(PurchaseOrder.supplier_id == supplier_id)
    received_stmt = received_stmt.group_by(GoodsReceiptLine.item_id, PurchaseOrder.supplier_id)
    received_rows = (await session.exec(received_stmt)).all()
    received = {
        (r.item_id, r.supplier_id): (
            r.qty_received or Decimal("0"),
            r.cost or Decimal("0"),
        )
        for r in received_rows
    }

    keys = set(ordered) | set(received)
    names: dict = {}
    sup_names: dict = {}
    units: dict = {}
    if keys:
        item_rows = (
            await session.exec(
                select(Item.id, Item.name, Unit.code)
                .join(Unit, Item.unit_id == Unit.id, isouter=True)
                .where(Item.id.in_([k[0] for k in keys]))
            )
        ).all()
        for iid, name, code in item_rows:
            names[iid] = name
            units[iid] = code or ""
        sup_rows = (
            await session.exec(
                select(Supplier.id, Supplier.name).where(Supplier.id.in_([k[1] for k in keys]))
            )
        ).all()
        sup_names = {row[0]: row[1] for row in sup_rows}

    lines = [
        ProductPurchaseLine(
            item_id=item_id,
            item_name=names.get(item_id, "Unknown"),
            item_unit=units.get(item_id, ""),
            supplier_id=sup_id,
            supplier_name=sup_names.get(sup_id, "Unknown"),
            quantity_ordered=ordered.get((item_id, sup_id), Decimal("0")),
            quantity_received=received.get((item_id, sup_id), (Decimal("0"), Decimal("0")))[0],
            total_cost=received.get((item_id, sup_id), (Decimal("0"), Decimal("0")))[1],
        )
        for item_id, sup_id in keys
    ]
    lines.sort(key=lambda line: line.total_cost, reverse=True)
    total = sum((line.total_cost for line in lines), Decimal("0"))
    logger.info("reports.product_purchases", business_id=str(business_id), lines=len(lines))
    return ProductPurchaseResponse(lines=lines, total_cost=total)


@router.get("/stock-adjustments", response_model=StockAdjustmentResponse)
async def stock_adjustments(
    business_id: UUID,
    session: Annotated[AsyncSession, Depends(get_db)],
    _jwt_biz_id: Annotated[str, Depends(require_business_permission("reports.view"))],
    claims: Annotated[dict[str, Any], Depends(get_current_claims)],
    from_date: date | None = Query(
        default=None, alias="from", description="Start date (inclusive)"
    ),
    to_date: date | None = Query(default=None, alias="to", description="End date (inclusive)"),
    store_id: UUID | None = Query(default=None, description="Filter by store"),
    limit: int = Query(default=50, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
) -> StockAdjustmentResponse:
    """Stock Adjustment Report: business-wide manual corrections, newest first."""
    store_id = resolve_store_filter(claims, store_id)
    start, end = _day_bounds(from_date, to_date)
    stmt = (
        select(StockMovement, Item.name)
        .join(Item, StockMovement.item_id == Item.id)
        .where(
            StockMovement.business_id == business_id,
            StockMovement.movement_type == MovementType.MANUAL_ADJUSTMENT,
        )
    )
    if start is not None:
        stmt = stmt.where(StockMovement.created_at >= start)
    if end is not None:
        stmt = stmt.where(StockMovement.created_at <= end)
    if store_id is not None:
        stmt = stmt.where(StockMovement.store_id == store_id)
    stmt = stmt.order_by(StockMovement.created_at.desc()).offset(offset).limit(limit)
    rows = (await session.exec(stmt)).all()
    count_stmt = select(sa_func.count(StockMovement.id)).where(
        StockMovement.business_id == business_id,
        StockMovement.movement_type == MovementType.MANUAL_ADJUSTMENT,
    )
    if start is not None:
        count_stmt = count_stmt.where(StockMovement.created_at >= start)
    if end is not None:
        count_stmt = count_stmt.where(StockMovement.created_at <= end)
    if store_id is not None:
        count_stmt = count_stmt.where(StockMovement.store_id == store_id)
    total = (await session.exec(count_stmt)).one() or 0
    lines = [
        StockAdjustmentLine(
            id=m.id,
            item_id=m.item_id,
            item_name=name,
            store_id=m.store_id,
            quantity_delta=m.quantity_delta,
            reason=m.reason,
            actor_id=m.actor_id,
            created_at=m.created_at.isoformat(),
        )
        for m, name in rows
    ]
    logger.info("reports.stock_adjustments", business_id=str(business_id), lines=len(lines))
    return StockAdjustmentResponse(lines=lines, total=total)


@router.get("/lot-report", response_model=LotReportResponse)
async def lot_report(
    business_id: UUID,
    session: Annotated[AsyncSession, Depends(get_db)],
    _jwt_biz_id: Annotated[str, Depends(require_business_permission("reports.view"))],
    claims: Annotated[dict[str, Any], Depends(get_current_claims)],
    from_date: date | None = Query(
        default=None, alias="from", description="Start date (inclusive)"
    ),
    to_date: date | None = Query(default=None, alias="to", description="End date (inclusive)"),
    store_id: UUID | None = Query(default=None, description="Filter by store"),
    item_id: UUID | None = Query(default=None, description="Filter by item"),
    limit: int = Query(default=100, ge=1, le=500),
    offset: int = Query(default=0, ge=0),
) -> LotReportResponse:
    """Lot Report: every received batch as a traceable lot."""
    store_id = resolve_store_filter(claims, store_id)
    start, end = _day_bounds(from_date, to_date)
    stmt = (
        select(GoodsReceiptLine, GoodsReceipt, Item.name, Supplier.name)
        .join(GoodsReceipt, GoodsReceiptLine.goods_receipt_id == GoodsReceipt.id)
        .join(Item, GoodsReceiptLine.item_id == Item.id)
        .join(PurchaseOrder, GoodsReceipt.purchase_order_id == PurchaseOrder.id, isouter=True)
        .join(Supplier, PurchaseOrder.supplier_id == Supplier.id, isouter=True)
        .where(GoodsReceipt.business_id == business_id)
    )
    if start is not None:
        stmt = stmt.where(GoodsReceipt.received_at >= start)
    if end is not None:
        stmt = stmt.where(GoodsReceipt.received_at <= end)
    if store_id is not None:
        stmt = stmt.where(GoodsReceipt.store_id == store_id)
    if item_id is not None:
        stmt = stmt.where(GoodsReceiptLine.item_id == item_id)
    stmt = stmt.order_by(GoodsReceipt.received_at.desc()).offset(offset).limit(limit)
    rows = (await session.exec(stmt)).all()
    lines = [
        LotLine(
            goods_receipt_id=gr.id,
            lot_no=line.lot_no or gr.grn_number,
            item_id=line.item_id,
            item_name=item_name,
            quantity_received=line.quantity_received,
            unit_cost=line.unit_cost,
            total_cost=line.quantity_received * line.unit_cost,
            supplier_name=supplier_name,
            expiry_date=line.expiry_date.isoformat() if line.expiry_date else None,
            received_at=gr.received_at.isoformat(),
        )
        for line, gr, item_name, supplier_name in rows
    ]
    logger.info("reports.lot_report", business_id=str(business_id), lines=len(lines))
    return LotReportResponse(lines=lines)


@router.get("/expiry-report", response_model=ExpiryReportResponse)
async def expiry_report(
    business_id: UUID,
    session: Annotated[AsyncSession, Depends(get_db)],
    _jwt_biz_id: Annotated[str, Depends(require_business_permission("reports.view"))],
    claims: Annotated[dict[str, Any], Depends(get_current_claims)],
    from_date: date | None = Query(
        default=None, alias="from", description="Expiring from (inclusive)"
    ),
    to_date: date | None = Query(
        default=None, alias="to", description="Expiring until (inclusive)"
    ),
    store_id: UUID | None = Query(default=None, description="Filter by store"),
    limit: int = Query(default=100, ge=1, le=500),
) -> ExpiryReportResponse:
    """Stock Expiry Report: receipt lots whose expiry falls in the window."""
    store_id = resolve_store_filter(claims, store_id)
    start, end = _day_bounds(from_date, to_date)
    stmt = (
        select(GoodsReceiptLine, GoodsReceipt, Item.name)
        .join(GoodsReceipt, GoodsReceiptLine.goods_receipt_id == GoodsReceipt.id)
        .join(Item, GoodsReceiptLine.item_id == Item.id)
        .where(
            GoodsReceipt.business_id == business_id,
            GoodsReceiptLine.expiry_date.is_not(None),
        )
    )
    if start is not None:
        stmt = stmt.where(GoodsReceiptLine.expiry_date >= start)
    if end is not None:
        stmt = stmt.where(GoodsReceiptLine.expiry_date <= end)
    if store_id is not None:
        stmt = stmt.where(GoodsReceipt.store_id == store_id)
    stmt = stmt.order_by(GoodsReceiptLine.expiry_date.asc()).limit(limit)
    rows = (await session.exec(stmt)).all()
    lines = [
        ExpiryLine(
            goods_receipt_id=gr.id,
            lot_no=line.lot_no or gr.grn_number,
            item_id=line.item_id,
            item_name=item_name,
            quantity_received=line.quantity_received,
            unit_cost=line.unit_cost,
            total_cost=line.quantity_received * line.unit_cost,
            expiry_date=line.expiry_date.isoformat(),  # type: ignore[union-attr]
            received_at=gr.received_at.isoformat(),
        )
        for line, gr, item_name in rows
    ]
    logger.info("reports.expiry_report", business_id=str(business_id), lines=len(lines))
    return ExpiryReportResponse(lines=lines)


@router.get("/supplier-purchases", response_model=SupplierPurchaseResponse)
async def supplier_purchases(
    business_id: UUID,
    session: Annotated[AsyncSession, Depends(get_db)],
    _jwt_biz_id: Annotated[str, Depends(require_business_permission("reports.view"))],
    claims: Annotated[dict[str, Any], Depends(get_current_claims)],
    from_date: date | None = Query(
        default=None, alias="from", description="Start date (inclusive)"
    ),
    to_date: date | None = Query(default=None, alias="to", description="End date (inclusive)"),
    store_id: UUID | None = Query(default=None, description="Filter by store"),
) -> SupplierPurchaseResponse:
    """Supplier leg of the Supplier & Customer Report: received value.

    POs are qty-only so there is no ordered money value and no payables
    ledger — ``total_received`` reports the received value (Σ receipt qty
    × receipt unit_cost) per supplier. Cancelled orders are excluded.
    """
    store_id = resolve_store_filter(claims, store_id)
    start, end = _day_bounds(from_date, to_date)
    po_filters = [
        PurchaseOrder.business_id == business_id,
        PurchaseOrder.status != PurchaseOrderStatus.CANCELLED,
    ]
    if start is not None:
        po_filters.append(PurchaseOrder.ordered_at >= start)
    if end is not None:
        po_filters.append(PurchaseOrder.ordered_at <= end)
    if store_id is not None:
        po_filters.append(PurchaseOrder.store_id == store_id)
    po_rows = (
        await session.exec(
            select(
                PurchaseOrder.supplier_id,
                sa_func.count(PurchaseOrder.id).label("orders"),
            )
            .where(*po_filters)
            .group_by(PurchaseOrder.supplier_id)
        )
    ).all()
    counts = {row[0]: row[1] for row in po_rows}
    recv_filters = [
        GoodsReceipt.business_id == business_id,
        PurchaseOrder.status != PurchaseOrderStatus.CANCELLED,
    ]
    if start is not None:
        recv_filters.append(PurchaseOrder.ordered_at >= start)
    if end is not None:
        recv_filters.append(PurchaseOrder.ordered_at <= end)
    if store_id is not None:
        recv_filters.append(GoodsReceipt.store_id == store_id)
    recv_rows = (
        await session.exec(
            select(
                PurchaseOrder.supplier_id,
                sa_func.sum(GoodsReceiptLine.quantity_received * GoodsReceiptLine.unit_cost).label(
                    "received"
                ),
            )
            .join(GoodsReceipt, GoodsReceiptLine.goods_receipt_id == GoodsReceipt.id)
            .join(PurchaseOrder, GoodsReceipt.purchase_order_id == PurchaseOrder.id)
            .where(*recv_filters)
            .group_by(PurchaseOrder.supplier_id)
        )
    ).all()
    ordered = {row[0]: (counts.get(row[0], 0), row[1] or Decimal("0")) for row in recv_rows}
    for sid, count in counts.items():
        if sid not in ordered:
            ordered[sid] = (count, Decimal("0"))
    supplier_ids = set(ordered)
    names: dict = {}
    if supplier_ids:
        sup_rows = (
            await session.exec(
                select(Supplier.id, Supplier.name).where(Supplier.id.in_(supplier_ids))
            )
        ).all()
        names = {row[0]: row[1] for row in sup_rows}
    lines = [
        SupplierPurchaseLine(
            supplier_id=sid,
            supplier_name=names.get(sid, "Unknown"),
            orders_count=ordered.get(sid, (0, Decimal("0")))[0],
            total_received=ordered.get(sid, (0, Decimal("0")))[1],
        )
        for sid in supplier_ids
    ]
    lines.sort(key=lambda line: line.total_received, reverse=True)
    logger.info("reports.supplier_purchases", business_id=str(business_id), lines=len(lines))
    return SupplierPurchaseResponse(lines=lines)


@router.get("/cost-history", response_model=CostHistoryResponse)
async def cost_history(
    business_id: UUID,
    session: Annotated[AsyncSession, Depends(get_db)],
    _jwt_biz_id: Annotated[str, Depends(require_business_permission("reports.view"))],
    claims: Annotated[dict[str, Any], Depends(get_current_claims)],
    from_date: date | None = Query(
        default=None, alias="from", description="Start date (inclusive)"
    ),
    to_date: date | None = Query(default=None, alias="to", description="End date (inclusive)"),
    store_id: UUID | None = Query(default=None, description="Filter by store"),
    item_id: UUID | None = Query(default=None, description="Filter by item"),
    supplier_id: UUID | None = Query(default=None, description="Filter by supplier"),
    limit: int = Query(default=100, ge=1, le=500),
    offset: int = Query(default=0, ge=0),
) -> CostHistoryResponse:
    """Cost history: frozen receipt costs over time ("what did flour cost in March").

    Receipt lines are append-only — unlike ``Item.unit_cost`` (rewritten on
    every delivery) and ``SupplierItem.price`` (overwritten on every upsert)
    — so this is the reconstructable price record for historical P&L.
    """
    store_id = resolve_store_filter(claims, store_id)
    start, end = _day_bounds(from_date, to_date)
    stmt = (
        select(GoodsReceiptLine, GoodsReceipt, Item.name, Supplier.name)
        .join(GoodsReceipt, GoodsReceiptLine.goods_receipt_id == GoodsReceipt.id)
        .join(Item, GoodsReceiptLine.item_id == Item.id)
        .join(PurchaseOrder, GoodsReceipt.purchase_order_id == PurchaseOrder.id, isouter=True)
        .join(Supplier, PurchaseOrder.supplier_id == Supplier.id, isouter=True)
        .where(GoodsReceipt.business_id == business_id)
    )
    if start is not None:
        stmt = stmt.where(GoodsReceipt.received_at >= start)
    if end is not None:
        stmt = stmt.where(GoodsReceipt.received_at <= end)
    if store_id is not None:
        stmt = stmt.where(GoodsReceipt.store_id == store_id)
    if item_id is not None:
        stmt = stmt.where(GoodsReceiptLine.item_id == item_id)
    if supplier_id is not None:
        stmt = stmt.where(PurchaseOrder.supplier_id == supplier_id)
    stmt = stmt.order_by(GoodsReceipt.received_at.desc()).offset(offset).limit(limit)
    rows = (await session.exec(stmt)).all()
    lines = [
        CostHistoryLine(
            goods_receipt_id=gr.id,
            grn_number=gr.grn_number,
            lot_no=line.lot_no or gr.grn_number,
            item_id=line.item_id,
            item_name=item_name,
            supplier_name=supplier_name,
            quantity_received=line.quantity_received,
            unit_cost=line.unit_cost,
            total_cost=line.quantity_received * line.unit_cost,
            received_at=gr.received_at.isoformat(),
        )
        for line, gr, item_name, supplier_name in rows
    ]
    logger.info("reports.cost_history", business_id=str(business_id), lines=len(lines))
    return CostHistoryResponse(lines=lines)


@router.get("/activity-log", response_model=ActivityLogResponse)
async def activity_log(
    business_id: UUID,
    session: Annotated[AsyncSession, Depends(get_db)],
    _jwt_biz_id: Annotated[str, Depends(require_business_permission("reports.view"))],
    claims: Annotated[dict[str, Any], Depends(get_current_claims)],
    from_date: date | None = Query(
        default=None, alias="from", description="Start date (inclusive)"
    ),
    to_date: date | None = Query(default=None, alias="to", description="End date (inclusive)"),
    store_id: UUID | None = Query(default=None, description="Filter by store"),
    movement_type: MovementType | None = Query(default=None, description="Filter by movement type"),
    limit: int = Query(default=100, ge=1, le=500),
    offset: int = Query(default=0, ge=0),
) -> ActivityLogResponse:
    """Activity Log (inventory leg): every stock movement, newest first."""
    store_id = resolve_store_filter(claims, store_id)
    start, end = _day_bounds(from_date, to_date)
    stmt = (
        select(StockMovement, Item.name)
        .join(Item, StockMovement.item_id == Item.id)
        .where(StockMovement.business_id == business_id)
    )
    if start is not None:
        stmt = stmt.where(StockMovement.created_at >= start)
    if end is not None:
        stmt = stmt.where(StockMovement.created_at <= end)
    if store_id is not None:
        stmt = stmt.where(StockMovement.store_id == store_id)
    if movement_type is not None:
        stmt = stmt.where(StockMovement.movement_type == movement_type)
    stmt = stmt.order_by(StockMovement.created_at.desc()).offset(offset).limit(limit)
    rows = (await session.exec(stmt)).all()
    count_stmt = select(sa_func.count(StockMovement.id)).where(
        StockMovement.business_id == business_id
    )
    if start is not None:
        count_stmt = count_stmt.where(StockMovement.created_at >= start)
    if end is not None:
        count_stmt = count_stmt.where(StockMovement.created_at <= end)
    if store_id is not None:
        count_stmt = count_stmt.where(StockMovement.store_id == store_id)
    if movement_type is not None:
        count_stmt = count_stmt.where(StockMovement.movement_type == movement_type)
    total = (await session.exec(count_stmt)).one() or 0
    lines = [
        ActivityLogLine(
            id=m.id,
            item_id=m.item_id,
            item_name=name,
            movement_type=str(
                m.movement_type.value if hasattr(m.movement_type, "value") else m.movement_type
            ),
            quantity_delta=m.quantity_delta,
            store_id=m.store_id,
            actor_id=m.actor_id,
            reason=m.reason,
            created_at=m.created_at.isoformat(),
        )
        for m, name in rows
    ]
    logger.info("reports.activity_log", business_id=str(business_id), lines=len(lines))
    return ActivityLogResponse(lines=lines, total=total)
