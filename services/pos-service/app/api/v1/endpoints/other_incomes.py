"""Other-incomes API endpoints — sync, read, list, summary, update, delete.

Mirror of ``other_expenses.py`` with ``source`` instead of ``payee`` and the
income category list. See that file for the shared design notes (partial-
success batch sync, route-ordering constraint on ``/summary``, soft-delete
semantics).
"""

from __future__ import annotations

from datetime import datetime
from typing import Annotated
from uuid import UUID

import structlog
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func as sa_func
from sqlmodel import select
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.permission_codes import PermissionCode
from app.db.session import get_db
from app.deps.auth import (
    ensure_store_access,
    get_current_claims,
    require_business_permission,
    store_scope_filter,
)
from app.models.finance import OtherIncome
from app.models.pos import PaymentMethod
from app.schemas.finance import (
    IncomeCategorySummary,
    OtherIncomeListItem,
    OtherIncomeListResponse,
    OtherIncomeRead,
    OtherIncomeSummaryResponse,
    OtherIncomeSyncBatchRequest,
    OtherIncomeSyncBatchResponse,
    OtherIncomeUpdate,
)
from app.services.finance_service import (
    FinanceNotFoundError,
    FinanceStateError,
    soft_delete_income,
    sync_income_batch,
    update_income,
)

logger = structlog.get_logger(__name__)
router = APIRouter(tags=["finance"])


@router.post(
    "/businesses/{business_id}/other-incomes/sync",
    response_model=OtherIncomeSyncBatchResponse,
    status_code=status.HTTP_200_OK,
)
async def sync_other_incomes(
    business_id: UUID,
    batch: OtherIncomeSyncBatchRequest,
    session: AsyncSession = Depends(get_db),
    claims: dict = Depends(get_current_claims),
    _active_business: str = Depends(
        require_business_permission(PermissionCode.FINANCE_INCOMES_CREATE)
    ),
) -> OtherIncomeSyncBatchResponse:
    for income_input in batch.incomes:
        ensure_store_access(claims, income_input.store_id)

    try:
        actor_id = UUID(claims["sub"])
    except (ValueError, KeyError, TypeError):
        actor_id = None
    response = await sync_income_batch(session, business_id, actor_id, batch)

    created = sum(1 for r in response.results if r.status == "created")
    duplicate = sum(1 for r in response.results if r.status == "duplicate")
    failed = sum(1 for r in response.results if r.status == "failed")

    logger.info(
        "finance_income_sync_batch_processed",
        business_id=str(business_id),
        batch_size=len(batch.incomes),
        created=created,
        duplicate=duplicate,
        failed=failed,
    )

    return response


@router.get(
    "/businesses/{business_id}/other-incomes/summary",
    response_model=OtherIncomeSummaryResponse,
)
async def get_other_incomes_summary(
    business_id: UUID,
    session: Annotated[AsyncSession, Depends(get_db)],
    _active_business: str = Depends(require_business_permission(PermissionCode.FINANCE_VIEW)),
    from_date: datetime | None = Query(default=None),
    to_date: datetime | None = Query(default=None),
    category: str | None = Query(default=None),
    payment_method: str | None = Query(default=None),
    store_id: UUID | None = Depends(store_scope_filter),
) -> OtherIncomeSummaryResponse:
    """NOTE: declared before ``/{income_id}`` — see other_expenses.py's summary route for why."""
    base_where = [
        OtherIncome.business_id == business_id,
        OtherIncome.is_deleted.is_(False),  # type: ignore[attr-defined]
    ]

    if from_date is not None:
        base_where.append(OtherIncome.occurred_at >= from_date)
    if to_date is not None:
        base_where.append(OtherIncome.occurred_at <= to_date)
    if category is not None:
        base_where.append(OtherIncome.category == category)
    if payment_method is not None:
        base_where.append(OtherIncome.payment_method == PaymentMethod(payment_method))
    if store_id is not None:
        base_where.append(OtherIncome.store_id == store_id)

    agg_stmt = select(
        sa_func.count(OtherIncome.id).label("total_count"),
        sa_func.coalesce(sa_func.sum(OtherIncome.amount), 0).label("total_amount"),
    ).where(*base_where)
    agg_row = (await session.exec(agg_stmt)).one()

    breakdown_stmt = (
        select(
            OtherIncome.category,
            sa_func.count(OtherIncome.id).label("count"),
            sa_func.sum(OtherIncome.amount).label("total"),
        )
        .where(*base_where)
        .group_by(OtherIncome.category)
    )
    breakdown_rows = (await session.exec(breakdown_stmt)).all()

    return OtherIncomeSummaryResponse(
        total_count=agg_row.total_count,
        total_amount=agg_row.total_amount,
        category_breakdown=[
            IncomeCategorySummary(category=row.category, count=row.count, total=row.total)
            for row in breakdown_rows
        ],
    )


@router.get(
    "/businesses/{business_id}/other-incomes",
    response_model=OtherIncomeListResponse,
)
async def list_other_incomes(
    business_id: UUID,
    session: Annotated[AsyncSession, Depends(get_db)],
    _active_business: str = Depends(require_business_permission(PermissionCode.FINANCE_VIEW)),
    limit: int = Query(default=20, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    from_date: datetime | None = Query(default=None),
    to_date: datetime | None = Query(default=None),
    category: str | None = Query(default=None),
    payment_method: str | None = Query(default=None),
    store_id: UUID | None = Depends(store_scope_filter),
    include_deleted: bool = Query(default=False),
) -> OtherIncomeListResponse:
    stmt = select(OtherIncome).where(OtherIncome.business_id == business_id)

    if not include_deleted:
        stmt = stmt.where(OtherIncome.is_deleted.is_(False))  # type: ignore[attr-defined]
    if from_date is not None:
        stmt = stmt.where(OtherIncome.occurred_at >= from_date)
    if to_date is not None:
        stmt = stmt.where(OtherIncome.occurred_at <= to_date)
    if category is not None:
        stmt = stmt.where(OtherIncome.category == category)
    if payment_method is not None:
        stmt = stmt.where(OtherIncome.payment_method == PaymentMethod(payment_method))
    if store_id is not None:
        stmt = stmt.where(OtherIncome.store_id == store_id)

    count_stmt = select(sa_func.count()).select_from(stmt.subquery())
    total = (await session.exec(count_stmt)).one()

    stmt = stmt.order_by(OtherIncome.occurred_at.desc()).offset(offset).limit(limit)
    incomes = (await session.exec(stmt)).all()

    return OtherIncomeListResponse(
        items=[OtherIncomeListItem.model_validate(i, from_attributes=True) for i in incomes],
        total=total,
        limit=limit,
        offset=offset,
    )


@router.get(
    "/businesses/{business_id}/other-incomes/{income_id}",
    response_model=OtherIncomeRead,
)
async def get_other_income(
    business_id: UUID,
    income_id: UUID,
    session: AsyncSession = Depends(get_db),
    _active_business: str = Depends(require_business_permission(PermissionCode.FINANCE_VIEW)),
) -> OtherIncomeRead:
    income = (
        await session.exec(
            select(OtherIncome).where(
                OtherIncome.id == income_id, OtherIncome.business_id == business_id
            )
        )
    ).first()
    if income is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Income not found")
    return OtherIncomeRead.model_validate(income, from_attributes=True)


@router.patch(
    "/businesses/{business_id}/other-incomes/{income_id}",
    response_model=OtherIncomeRead,
)
async def patch_other_income(
    business_id: UUID,
    income_id: UUID,
    patch: OtherIncomeUpdate,
    session: AsyncSession = Depends(get_db),
    claims: dict = Depends(get_current_claims),
    _active_business: str = Depends(
        require_business_permission(PermissionCode.FINANCE_INCOMES_UPDATE)
    ),
) -> OtherIncomeRead:
    try:
        actor_id = UUID(claims["sub"])
    except (ValueError, KeyError, TypeError):
        actor_id = None
    try:
        income = await update_income(session, business_id, income_id, actor_id, patch)
    except FinanceNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except FinanceStateError as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(exc)) from exc
    return OtherIncomeRead.model_validate(income, from_attributes=True)


@router.delete(
    "/businesses/{business_id}/other-incomes/{income_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
async def delete_other_income(
    business_id: UUID,
    income_id: UUID,
    session: AsyncSession = Depends(get_db),
    claims: dict = Depends(get_current_claims),
    _active_business: str = Depends(
        require_business_permission(PermissionCode.FINANCE_INCOMES_DELETE)
    ),
) -> None:
    try:
        actor_id = UUID(claims["sub"])
    except (ValueError, KeyError, TypeError):
        actor_id = None
    try:
        await soft_delete_income(session, business_id, income_id, actor_id)
    except FinanceNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
