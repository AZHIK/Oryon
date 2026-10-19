"""Requisition endpoints — unified cart → per-supplier PO split + payloads.

┌──────────────────────────────────────────────────────────────────────────┐
│ PERMISSION MODEL (mirrors purchases.py)                                  │
│                                                                          │
│   POST /requisitions               → PROCUREMENT_CREATE (submit/split)    │
│   GET  /requisitions/{id}          → PROCUREMENT_VIEW                    │
│   POST /requisitions/{id}/bulk-assign → PROCUREMENT_CREATE               │
│   POST /requisitions/{id}/regenerate-payloads → PROCUREMENT_CREATE       │
│   POST /supplier-items             → PROCUREMENT_CREATE (catalogue)       │
└──────────────────────────────────────────────────────────────────────────┘

All writes are single-transaction API calls (online-only, same as
purchases.py): the submit path flushes the requisition + POs + messages and
commits ONCE — all-or-nothing across all resulting POs.
"""

from __future__ import annotations

from typing import Annotated, Any
from uuid import UUID

import structlog
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.exc import IntegrityError
from sqlmodel import select
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.database import get_db
from app.deps.auth import (
    ensure_store_access,
    get_current_claims,
    require_business_permission,
)
from app.models.inventory import Item
from app.models.purchases import PurchaseOrder
from app.models.requisition import (
    Requisition,
    RequisitionLine,
    SupplierItem,
    SupplierMessage,
)
from app.schemas.requisitions import (
    BulkAssignRequest,
    PurchaseOrderSplitRead,
    RequisitionLineRead,
    RequisitionRead,
    RequisitionSubmit,
    RequisitionSubmitResponse,
    SupplierItemRead,
    SupplierItemUpsert,
    SupplierMessageRead,
)
from app.services.requisition_service import (
    bulk_assign_supplier,
    regenerate_payload,
    rollup_requisition_status,
    submit_requisition,
)

logger = structlog.get_logger(__name__)
router = APIRouter(prefix="/businesses/{business_id}/requisitions", tags=["requisitions"])
catalogue_router = APIRouter(
    prefix="/businesses/{business_id}/supplier-items", tags=["supplier-items"]
)


def _extract_actor_id(claims: dict[str, Any]) -> UUID | None:
    raw = claims.get("sub")
    if not raw:
        return None
    try:
        return UUID(raw)
    except ValueError:
        return None


def _restaurant_name(claims: dict[str, Any], business_id: UUID) -> str:
    return claims.get("business_name") or claims.get("restaurant_name") or f"Business {business_id}"


@router.post("", response_model=RequisitionSubmitResponse, status_code=status.HTTP_201_CREATED)
async def submit(
    business_id: UUID,
    body: RequisitionSubmit,
    session: Annotated[AsyncSession, Depends(get_db)],
    claims: Annotated[dict[str, Any], Depends(get_current_claims)],
    _jwt_biz_id: Annotated[str, Depends(require_business_permission("procurement.create"))],
) -> RequisitionSubmitResponse:
    ensure_store_access(claims, body.store_id)
    line_item_ids = {line.item_id for line in body.lines}
    if line_item_ids:
        line_items = (
            await session.exec(
                select(Item).where(
                    Item.id.in_(line_item_ids),
                    Item.business_id == business_id,
                )
            )
        ).all()
        for line_item in line_items:
            ensure_store_access(claims, line_item.store_id)
    # Duplicate-submit guard: fast-path check before the transactional write.
    if body.idempotency_key:
        dup = (
            await session.exec(
                select(Requisition).where(
                    Requisition.business_id == business_id,
                    Requisition.idempotency_key == body.idempotency_key,
                )
            )
        ).one_or_none()
        if dup is not None:
            pos = (
                await session.exec(
                    select(PurchaseOrder).where(PurchaseOrder.requisition_id == dup.id)
                )
            ).all()
            msgs: list[SupplierMessage] = []
            for po in pos:
                msgs.extend(
                    (
                        await session.exec(
                            select(SupplierMessage).where(SupplierMessage.po_id == po.id)
                        )
                    ).all()
                )
            return RequisitionSubmitResponse(
                requisition=RequisitionRead.model_validate(dup),
                purchase_orders=[PurchaseOrderSplitRead.model_validate(po) for po in pos],
                messages=[SupplierMessageRead.model_validate(m) for m in msgs],
                price_unconfirmed_items=[],
                rollup_status=rollup_requisition_status([po.status.value for po in pos]),
            )
    try:
        requisition, pos, msgs, flagged = await submit_requisition(
            session,
            business_id=business_id,
            store_id=body.store_id,
            created_by=_extract_actor_id(claims),
            notes=body.notes,
            expected_at=body.expected_at,
            lines=[ln.model_dump() for ln in body.lines],
            idempotency_key=body.idempotency_key,
            restaurant_name=_restaurant_name(claims, business_id),
        )
        await session.commit()
    except ValueError as exc:
        await session.rollback()
        message = str(exc)
        code = status.HTTP_422_UNPROCESSABLE_CONTENT
        if "need a supplier" in message:
            code = status.HTTP_422_UNPROCESSABLE_CONTENT
        raise HTTPException(status_code=code, detail=message) from exc
    except LookupError as exc:
        await session.rollback()
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except IntegrityError as exc:
        await session.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Duplicate requisition — retry with a fresh idempotency key",
        ) from exc
    except Exception:
        await session.rollback()
        raise

    for po in pos:
        await session.refresh(po)
    await session.refresh(requisition)
    for m in msgs:
        await session.refresh(m)
    logger.info("requisition.submitted", requisition_id=str(requisition.id), pos=len(pos))
    return RequisitionSubmitResponse(
        requisition=RequisitionRead.model_validate(requisition),
        purchase_orders=[PurchaseOrderSplitRead.model_validate(po) for po in pos],
        messages=[SupplierMessageRead.model_validate(m) for m in msgs],
        price_unconfirmed_items=flagged,
        rollup_status=rollup_requisition_status([po.status.value for po in pos]),
    )


@router.get("/{requisition_id}", response_model=RequisitionSubmitResponse)
async def get_requisition(
    business_id: UUID,
    requisition_id: UUID,
    session: Annotated[AsyncSession, Depends(get_db)],
    _jwt_biz_id: Annotated[str, Depends(require_business_permission("procurement.view"))],
    claims: Annotated[dict[str, Any], Depends(get_current_claims)],
) -> RequisitionSubmitResponse:
    requisition = (
        await session.exec(
            select(Requisition).where(
                Requisition.id == requisition_id, Requisition.business_id == business_id
            )
        )
    ).one_or_none()
    if requisition is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Requisition not found")
    ensure_store_access(claims, requisition.store_id)
    pos = (
        await session.exec(
            select(PurchaseOrder).where(PurchaseOrder.requisition_id == requisition.id)
        )
    ).all()
    msgs: list[SupplierMessage] = []
    for po in pos:
        msgs.extend(
            (
                await session.exec(select(SupplierMessage).where(SupplierMessage.po_id == po.id))
            ).all()
        )
    flagged = sorted(
        {
            str(rl.item_id)
            for rl in (
                await session.exec(
                    select(RequisitionLine).where(
                        RequisitionLine.requisition_id == requisition.id,
                        RequisitionLine.price_unconfirmed == True,  # noqa: E712
                    )
                )
            ).all()
        }
    )
    return RequisitionSubmitResponse(
        requisition=RequisitionRead.model_validate(requisition),
        purchase_orders=[PurchaseOrderSplitRead.model_validate(po) for po in pos],
        messages=[SupplierMessageRead.model_validate(m) for m in msgs],
        price_unconfirmed_items=flagged,
        rollup_status=rollup_requisition_status([po.status.value for po in pos]),
    )


@router.post("/{requisition_id}/bulk-assign", response_model=list[RequisitionLineRead])
async def bulk_assign(
    business_id: UUID,
    requisition_id: UUID,
    body: BulkAssignRequest,
    session: Annotated[AsyncSession, Depends(get_db)],
    claims: Annotated[dict[str, Any], Depends(get_current_claims)],
    _jwt_biz_id: Annotated[str, Depends(require_business_permission("procurement.create"))],
) -> list[RequisitionLine]:
    requisition = (
        await session.exec(
            select(Requisition).where(
                Requisition.id == requisition_id,
                Requisition.business_id == business_id,
            )
        )
    ).one_or_none()
    if requisition is not None:
        ensure_store_access(claims, requisition.store_id)
    try:
        touched = await bulk_assign_supplier(
            session,
            requisition_id=requisition_id,
            business_id=business_id,
            supplier_id=body.supplier_id,
            scope=body.scope,
            overwrite=body.overwrite,
        )
        await session.commit()
    except ValueError as exc:
        await session.rollback()
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT, detail=str(exc)
        ) from exc
    except LookupError as exc:
        await session.rollback()
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except Exception:
        await session.rollback()
        raise
    for line in touched:
        await session.refresh(line)
    return touched


@router.post("/{requisition_id}/regenerate-payloads", response_model=list[SupplierMessageRead])
async def regenerate_all_payloads(
    business_id: UUID,
    requisition_id: UUID,
    session: Annotated[AsyncSession, Depends(get_db)],
    claims: Annotated[dict[str, Any], Depends(get_current_claims)],
    _jwt_biz_id: Annotated[str, Depends(require_business_permission("procurement.create"))],
) -> list[SupplierMessage]:
    pos = (
        await session.exec(
            select(PurchaseOrder).where(
                PurchaseOrder.requisition_id == requisition_id,
                PurchaseOrder.business_id == business_id,
            )
        )
    ).all()
    if not pos:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Requisition not found")
    for po in pos:
        ensure_store_access(claims, po.store_id)
    out: list[SupplierMessage] = []
    for po in pos:
        msg = await regenerate_payload(
            session,
            po_id=po.id,
            business_id=business_id,
            restaurant_name=_restaurant_name(claims, business_id),
        )
        if msg is not None:
            out.append(msg)
    await session.commit()
    for m in out:
        await session.refresh(m)
    return out


@catalogue_router.post("", response_model=SupplierItemRead, status_code=status.HTTP_201_CREATED)
async def upsert_supplier_item(
    business_id: UUID,
    body: SupplierItemUpsert,
    session: Annotated[AsyncSession, Depends(get_db)],
    _jwt_biz_id: Annotated[str, Depends(require_business_permission("procurement.create"))],
) -> SupplierItem:
    """Upsert a supplier↔item catalogue row, scoped to the URL business."""
    from app.models.inventory import Item
    from app.models.suppliers import Supplier

    supplier = (
        await session.exec(
            select(Supplier).where(
                Supplier.id == body.supplier_id, Supplier.business_id == business_id
            )
        )
    ).one_or_none()
    if supplier is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Supplier not found")
    item = (
        await session.exec(
            select(Item).where(Item.id == body.item_id, Item.business_id == business_id)
        )
    ).one_or_none()
    if item is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Item not found")
    existing = (
        await session.exec(
            select(SupplierItem).where(
                SupplierItem.supplier_id == body.supplier_id, SupplierItem.item_id == body.item_id
            )
        )
    ).one_or_none()
    if existing is None:
        row = SupplierItem(**body.model_dump())
        session.add(row)
        await session.commit()
        await session.refresh(row)
        return row
    for field, value in body.model_dump(exclude={"supplier_id", "item_id"}).items():
        setattr(existing, field, value)
    session.add(existing)
    await session.commit()
    await session.refresh(existing)
    return existing
