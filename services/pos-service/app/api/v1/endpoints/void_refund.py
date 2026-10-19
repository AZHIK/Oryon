"""Void/refund endpoints — POST /businesses/{bid}/sales/{sid}/void-or-refund."""

from __future__ import annotations

from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import select
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.permission_codes import PermissionCode
from app.db.session import get_db
from app.deps.auth import (
    get_current_claims,
    get_pinned_store_id,
    require_business_permission,
)
from app.models.pos import Sale, SaleLineItem
from app.schemas.line_items import SaleLineItemRead
from app.schemas.sales import SaleRead
from app.schemas.void_refund import VoidRefundRequest
from app.services.sale_service import (
    InvalidSaleStateError,
    SaleValidationError,
    void_or_refund_sale,
)

router = APIRouter(tags=["sales"])


@router.post(
    "/businesses/{business_id}/sales/{sale_id}/void-or-refund",
    response_model=SaleRead,
    status_code=status.HTTP_200_OK,
)
async def void_or_refund(
    business_id: UUID,
    sale_id: UUID,
    request: VoidRefundRequest,
    session: AsyncSession = Depends(get_db),
    claims: dict = Depends(get_current_claims),
    _active_business: str = Depends(
        require_business_permission(PermissionCode.POS_REFUND)
    ),
) -> SaleRead:
    """Void or refund an already-synced completed sale.

    Returns the updated sale representation.  Idempotent — submitting the
    same ``client_action_id`` twice returns the same result without
    side effects.
    """
    pinned_store_id = get_pinned_store_id(claims)
    if pinned_store_id is not None:
        target_store_id = (
            await session.exec(
                select(Sale.store_id).where(
                    Sale.id == sale_id,
                    Sale.business_id == business_id,
                )
            )
        ).first()
        if target_store_id is not None and target_store_id != pinned_store_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Store ID does not match authenticated store context",
            )

    try:
        actor_id = UUID(claims["sub"])
    except (ValueError, KeyError, TypeError):
        actor_id = None

    try:
        sale = await void_or_refund_sale(
            session, business_id, sale_id, actor_id, request,
        )
    except SaleValidationError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(exc),
        )
    except InvalidSaleStateError as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=str(exc),
        )

    line_items = (
        await session.exec(
            select(SaleLineItem).where(SaleLineItem.sale_id == sale.id)
        )
    ).all()

    return SaleRead(
        id=sale.id,
        business_id=sale.business_id,
        store_id=sale.store_id,
        client_sale_id=sale.client_sale_id,
        status=sale.status.value,
        subtotal=sale.subtotal,
        discount_amount=sale.discount_amount,
        tax_amount=sale.tax_amount,
        total=sale.total,
        payment_method=sale.payment_method.value,
        actor_id=sale.actor_id,
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
