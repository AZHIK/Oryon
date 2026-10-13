"""Sales API endpoints — sync, read, lookup, list, and summary."""

from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from typing import Annotated
from uuid import UUID

import structlog
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import case as sa_case, func as sa_func
from sqlmodel import select
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.permission_codes import PermissionCode
from app.db.session import get_db
from app.deps.auth import get_current_claims, require_business_permission
from app.models.pos import (
    DeliveryStatus,
    OrderType,
    PaymentMethod,
    Sale,
    SaleLineItem,
    SaleStatus,
)
from app.schemas.line_items import SaleLineItemRead
from app.schemas.sales import (
    PaymentMethodSummary,
    SaleListItem,
    SaleListResponse,
    SaleRead,
    SaleSummaryResponse,
    SaleSyncBatchRequest,
    SaleSyncBatchResponse,
)
from app.services.sale_service import sync_sale_batch

logger = structlog.get_logger(__name__)
router = APIRouter(tags=["sales"])


@router.post(
    "/businesses/{business_id}/sales/sync",
    response_model=SaleSyncBatchResponse,
    status_code=status.HTTP_200_OK,
)
async def sync_sales(
    business_id: UUID,
    batch: SaleSyncBatchRequest,
    session: AsyncSession = Depends(get_db),
    claims: dict = Depends(get_current_claims),
    _active_business: str = Depends(require_business_permission(PermissionCode.POS_WRITE)),
) -> SaleSyncBatchResponse:
    """Process a batch of offline-synced sales.

    Returns per-sale results (created / duplicate / failed) with HTTP 200.
    Partial success is first-class — one sale failure does NOT cause an
    HTTP error.
    """
    try:
        actor_id = UUID(claims["sub"])
    except (ValueError, KeyError, TypeError):
        actor_id = None
    response = await sync_sale_batch(session, business_id, actor_id, batch)

    created = sum(1 for r in response.results if r.status == "created")
    duplicate = sum(1 for r in response.results if r.status == "duplicate")
    failed = sum(1 for r in response.results if r.status == "failed")

    logger.info(
        "sales_sync_batch_processed",
        business_id=str(business_id),
        batch_size=len(batch.sales),
        created=created,
        duplicate=duplicate,
        failed=failed,
    )

    return response


@router.get(
    "/businesses/{business_id}/sales",
    response_model=SaleListResponse,
)
async def list_sales(
    business_id: UUID,
    session: Annotated[AsyncSession, Depends(get_db)],
    _active_business: str = Depends(require_business_permission(PermissionCode.POS_VIEW)),
    limit: int = Query(default=20, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    from_date: datetime | None = Query(default=None, description="Start date (inclusive) for occurred_at"),
    to_date: datetime | None = Query(default=None, description="End date (inclusive) for occurred_at"),
    status: str | None = Query(default=None, description="Filter by status: completed, voided, refunded"),
    payment_method: str | None = Query(default=None, description="Filter by payment method: cash, mobile_money, card, other"),
    store_id: UUID | None = Query(default=None, description="Filter by store"),
    order_type: str | None = Query(default=None, description="Filter by order type: dine_in, takeaway, delivery"),
    courier_id: UUID | None = Query(default=None, description="Filter by assigned courier"),
    delivery_status: str | None = Query(default=None, description="Filter by delivery status: pending, assigned, out_for_delivery, delivered, failed"),
) -> SaleListResponse:
    """Paginated sale list, filterable by date range (occurred_at), status, payment method, and location.

    Default sort: occurred_at descending (most recent first).
    """
    stmt = select(Sale).where(Sale.business_id == business_id)

    if from_date is not None:
        stmt = stmt.where(Sale.occurred_at >= from_date)
    if to_date is not None:
        stmt = stmt.where(Sale.occurred_at <= to_date)
    if status is not None:
        stmt = stmt.where(Sale.status == SaleStatus(status))
    if payment_method is not None:
        stmt = stmt.where(Sale.payment_method == PaymentMethod(payment_method))
    if store_id is not None:
        stmt = stmt.where(Sale.store_id == store_id)
    if order_type is not None:
        stmt = stmt.where(Sale.order_type == OrderType(order_type))
    if courier_id is not None:
        stmt = stmt.where(Sale.courier_id == courier_id)
    if delivery_status is not None:
        stmt = stmt.where(Sale.delivery_status == DeliveryStatus(delivery_status))

    count_stmt = select(sa_func.count()).select_from(stmt.subquery())
    total = (await session.exec(count_stmt)).one()

    stmt = stmt.order_by(Sale.occurred_at.desc()).offset(offset).limit(limit)
    sales = (await session.exec(stmt)).all()

    return SaleListResponse(
        items=[_sale_to_list_item(s) for s in sales],
        total=total,
        limit=limit,
        offset=offset,
    )


@router.get(
    "/businesses/{business_id}/sales/summary",
    response_model=SaleSummaryResponse,
)
async def get_sales_summary(
    business_id: UUID,
    session: Annotated[AsyncSession, Depends(get_db)],
    _active_business: str = Depends(require_business_permission(PermissionCode.POS_VIEW)),
    from_date: datetime | None = Query(default=None, description="Start date (inclusive) for occurred_at"),
    to_date: datetime | None = Query(default=None, description="End date (inclusive) for occurred_at"),
    payment_method: str | None = Query(default=None, description="Filter by payment method: cash, mobile_money, card, other"),
    store_id: UUID | None = Query(default=None, description="Filter by store"),
) -> SaleSummaryResponse:
    """Lightweight aggregate: total count, revenue (completed only), and payment-method breakdown.

    Voided/refunded sales are excluded from revenue but counted separately
    as voided_count / refunded_count so dashboard views can show both figures.
    """
    base_where = [Sale.business_id == business_id]

    if from_date is not None:
        base_where.append(Sale.occurred_at >= from_date)
    if to_date is not None:
        base_where.append(Sale.occurred_at <= to_date)
    if payment_method is not None:
        base_where.append(Sale.payment_method == PaymentMethod(payment_method))
    if store_id is not None:
        base_where.append(Sale.store_id == store_id)

    agg_stmt = select(
        sa_func.count(Sale.id).label("total_count"),
        sa_func.sum(
            sa_case((Sale.status == SaleStatus.COMPLETED, Sale.total), else_=Decimal("0"))
        ).label("total_revenue"),
        sa_func.sum(
            sa_case((Sale.status == SaleStatus.VOIDED, 1), else_=0)
        ).label("voided_count"),
        sa_func.sum(
            sa_case((Sale.status == SaleStatus.REFUNDED, 1), else_=0)
        ).label("refunded_count"),
    ).where(*base_where)

    agg_row = (await session.exec(agg_stmt)).one()

    breakdown_stmt = select(
        Sale.payment_method,
        sa_func.count(Sale.id).label("count"),
        sa_func.sum(
            sa_case((Sale.status == SaleStatus.COMPLETED, Sale.total), else_=Decimal("0"))
        ).label("revenue"),
    ).where(*base_where).group_by(Sale.payment_method)

    breakdown_rows = (await session.exec(breakdown_stmt)).all()

    return SaleSummaryResponse(
        total_count=agg_row.total_count,
        total_revenue=agg_row.total_revenue or Decimal("0"),
        voided_count=agg_row.voided_count or 0,
        refunded_count=agg_row.refunded_count or 0,
        payment_method_breakdown=[
            PaymentMethodSummary(
                payment_method=row.payment_method.value,
                count=row.count,
                revenue=row.revenue or Decimal("0"),
            )
            for row in breakdown_rows
        ],
    )


@router.get(
    "/businesses/{business_id}/sales/{sale_id}",
    response_model=SaleRead,
)
async def get_sale(
    business_id: UUID,
    sale_id: UUID,
    session: AsyncSession = Depends(get_db),
    _active_business: str = Depends(require_business_permission(PermissionCode.POS_VIEW)),
) -> SaleRead:
    """Retrieve a single sale by server-assigned ID."""
    sale = (
        await session.exec(
            select(Sale).where(Sale.id == sale_id, Sale.business_id == business_id)
        )
    ).first()
    if sale is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Sale not found",
        )

    line_items = (
        await session.exec(
            select(SaleLineItem).where(SaleLineItem.sale_id == sale_id)
        )
    ).all()

    return _sale_to_read(sale, list(line_items))


@router.get(
    "/businesses/{business_id}/sales/by-client-id/{client_sale_id}",
    response_model=SaleRead,
)
async def get_sale_by_client_id(
    business_id: UUID,
    client_sale_id: str,
    session: AsyncSession = Depends(get_db),
    _active_business: str = Depends(require_business_permission(PermissionCode.POS_VIEW)),
) -> SaleRead:
    """Retrieve a single sale by client-generated idempotency key."""
    sale = (
        await session.exec(
            select(Sale).where(
                Sale.client_sale_id == client_sale_id,
                Sale.business_id == business_id,
            )
        )
    ).first()
    if sale is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Sale not found",
        )

    line_items = (
        await session.exec(
            select(SaleLineItem).where(SaleLineItem.sale_id == sale.id)
        )
    ).all()

    return _sale_to_read(sale, list(line_items))


def _sale_to_list_item(sale: Sale) -> SaleListItem:
    return SaleListItem(
        id=sale.id,
        business_id=sale.business_id,
        store_id=sale.store_id,
        client_sale_id=sale.client_sale_id,
        status=sale.status.value,
        subtotal=sale.subtotal,
        discount_amount=sale.discount_amount,
        tax_amount=sale.tax_amount,
        delivery_fee=sale.delivery_fee,
        total=sale.total,
        payment_method=sale.payment_method.value,
        actor_id=sale.actor_id,
        customer_id=sale.customer_id,
        order_type=sale.order_type.value,
        courier_id=sale.courier_id,
        delivery_status=sale.delivery_status.value if sale.delivery_status else None,
        occurred_at=sale.occurred_at,
        synced_at=sale.synced_at,
        device_sequence=sale.device_sequence,
        is_time_suspect=sale.is_time_suspect,
        voided_at=sale.voided_at,
        refunded_at=sale.refunded_at,
        void_or_refund_reason=sale.void_or_refund_reason,
        created_at=sale.created_at,
    )


def _sale_to_read(sale: Sale, line_items: list[SaleLineItem]) -> SaleRead:
    return SaleRead(
        id=sale.id,
        business_id=sale.business_id,
        store_id=sale.store_id,
        client_sale_id=sale.client_sale_id,
        status=sale.status.value,
        subtotal=sale.subtotal,
        discount_amount=sale.discount_amount,
        tax_amount=sale.tax_amount,
        delivery_fee=sale.delivery_fee,
        total=sale.total,
        payment_method=sale.payment_method.value,
        actor_id=sale.actor_id,
        customer_id=sale.customer_id,
        order_type=sale.order_type.value,
        courier_id=sale.courier_id,
        delivery_address_line1=sale.delivery_address_line1,
        delivery_recipient_phone=sale.delivery_recipient_phone,
        delivery_note=sale.delivery_note,
        delivery_status=sale.delivery_status.value if sale.delivery_status else None,
        occurred_at=sale.occurred_at,
        synced_at=sale.synced_at,
        device_sequence=sale.device_sequence,
        is_time_suspect=sale.is_time_suspect,
        voided_at=sale.voided_at,
        refunded_at=sale.refunded_at,
        void_or_refund_reason=sale.void_or_refund_reason,
        created_at=sale.created_at,
        line_items=[
            SaleLineItemRead(
                id=li.id,
                sale_id=li.sale_id,
                item_id=li.item_id,
                quantity=li.quantity,
                unit_price=li.unit_price,
                discount_amount=li.discount_amount,
                line_total=li.line_total,
                unit_cost=li.unit_cost,
            )
            for li in line_items
        ],
    )
