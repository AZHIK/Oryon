"""Other-expenses API endpoints — sync, read, list, summary, update, delete."""

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
from app.models.finance import OtherExpense
from app.models.pos import PaymentMethod
from app.schemas.finance import (
    ExpenseCategorySummary,
    OtherExpenseListItem,
    OtherExpenseListResponse,
    OtherExpenseRead,
    OtherExpenseSummaryResponse,
    OtherExpenseSyncBatchRequest,
    OtherExpenseSyncBatchResponse,
    OtherExpenseUpdate,
)
from app.services.finance_service import (
    FinanceNotFoundError,
    FinanceStateError,
    soft_delete_expense,
    sync_expense_batch,
    update_expense,
)

logger = structlog.get_logger(__name__)
router = APIRouter(tags=["finance"])


@router.post(
    "/businesses/{business_id}/other-expenses/sync",
    response_model=OtherExpenseSyncBatchResponse,
    status_code=status.HTTP_200_OK,
)
async def sync_other_expenses(
    business_id: UUID,
    batch: OtherExpenseSyncBatchRequest,
    session: AsyncSession = Depends(get_db),
    claims: dict = Depends(get_current_claims),
    _active_business: str = Depends(
        require_business_permission(PermissionCode.FINANCE_EXPENSES_CREATE)
    ),
) -> OtherExpenseSyncBatchResponse:
    """Process a batch of offline-synced expense entries.

    Returns per-entry results (created / duplicate / failed) with HTTP 200.
    Partial success is first-class — one entry's failure does NOT cause an
    HTTP error.
    """
    for expense_input in batch.expenses:
        ensure_store_access(claims, expense_input.store_id)

    try:
        actor_id = UUID(claims["sub"])
    except (ValueError, KeyError, TypeError):
        actor_id = None
    response = await sync_expense_batch(session, business_id, actor_id, batch)

    created = sum(1 for r in response.results if r.status == "created")
    duplicate = sum(1 for r in response.results if r.status == "duplicate")
    failed = sum(1 for r in response.results if r.status == "failed")

    logger.info(
        "finance_expense_sync_batch_processed",
        business_id=str(business_id),
        batch_size=len(batch.expenses),
        created=created,
        duplicate=duplicate,
        failed=failed,
    )

    return response


@router.get(
    "/businesses/{business_id}/other-expenses/summary",
    response_model=OtherExpenseSummaryResponse,
)
async def get_other_expenses_summary(
    business_id: UUID,
    session: Annotated[AsyncSession, Depends(get_db)],
    _active_business: str = Depends(require_business_permission(PermissionCode.FINANCE_VIEW)),
    from_date: datetime | None = Query(default=None),
    to_date: datetime | None = Query(default=None),
    category: str | None = Query(default=None),
    payment_method: str | None = Query(default=None),
    store_id: UUID | None = Depends(store_scope_filter),
) -> OtherExpenseSummaryResponse:
    """Lightweight aggregate: total count, total amount, and category breakdown.

    Soft-deleted entries are always excluded.

    NOTE: this route MUST be declared before ``GET /{expense_id}`` — FastAPI
    matches routes in declaration order, and "summary" would otherwise be
    parsed as a UUID path param and 422.
    """
    base_where = [
        OtherExpense.business_id == business_id,
        OtherExpense.is_deleted.is_(False),  # type: ignore[attr-defined]
    ]

    if from_date is not None:
        base_where.append(OtherExpense.occurred_at >= from_date)
    if to_date is not None:
        base_where.append(OtherExpense.occurred_at <= to_date)
    if category is not None:
        base_where.append(OtherExpense.category == category)
    if payment_method is not None:
        base_where.append(OtherExpense.payment_method == PaymentMethod(payment_method))
    if store_id is not None:
        base_where.append(OtherExpense.store_id == store_id)

    agg_stmt = select(
        sa_func.count(OtherExpense.id).label("total_count"),
        sa_func.coalesce(sa_func.sum(OtherExpense.amount), 0).label("total_amount"),
    ).where(*base_where)
    agg_row = (await session.exec(agg_stmt)).one()

    breakdown_stmt = (
        select(
            OtherExpense.category,
            sa_func.count(OtherExpense.id).label("count"),
            sa_func.sum(OtherExpense.amount).label("total"),
        )
        .where(*base_where)
        .group_by(OtherExpense.category)
    )
    breakdown_rows = (await session.exec(breakdown_stmt)).all()

    return OtherExpenseSummaryResponse(
        total_count=agg_row.total_count,
        total_amount=agg_row.total_amount,
        category_breakdown=[
            ExpenseCategorySummary(category=row.category, count=row.count, total=row.total)
            for row in breakdown_rows
        ],
    )


@router.get(
    "/businesses/{business_id}/other-expenses",
    response_model=OtherExpenseListResponse,
)
async def list_other_expenses(
    business_id: UUID,
    session: Annotated[AsyncSession, Depends(get_db)],
    _active_business: str = Depends(require_business_permission(PermissionCode.FINANCE_VIEW)),
    limit: int = Query(default=20, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    from_date: datetime | None = Query(default=None, description="Start date (inclusive)"),
    to_date: datetime | None = Query(default=None, description="End date (inclusive)"),
    category: str | None = Query(default=None, description="Filter by expense category"),
    payment_method: str | None = Query(default=None, description="Filter by payment method"),
    store_id: UUID | None = Depends(store_scope_filter),
    include_deleted: bool = Query(default=False, description="Include soft-deleted entries"),
) -> OtherExpenseListResponse:
    """Paginated expense list, filterable by date range, category, payment method, and location.

    Default sort: occurred_at descending (most recent first).

    ``include_deleted`` defaults to False for the app's normal list view,
    but the sync pull path calls this with ``include_deleted=true`` so a
    delete made on one device propagates to the local cache on others.
    """
    stmt = select(OtherExpense).where(OtherExpense.business_id == business_id)

    if not include_deleted:
        stmt = stmt.where(OtherExpense.is_deleted.is_(False))  # type: ignore[attr-defined]
    if from_date is not None:
        stmt = stmt.where(OtherExpense.occurred_at >= from_date)
    if to_date is not None:
        stmt = stmt.where(OtherExpense.occurred_at <= to_date)
    if category is not None:
        stmt = stmt.where(OtherExpense.category == category)
    if payment_method is not None:
        stmt = stmt.where(OtherExpense.payment_method == PaymentMethod(payment_method))
    if store_id is not None:
        stmt = stmt.where(OtherExpense.store_id == store_id)

    count_stmt = select(sa_func.count()).select_from(stmt.subquery())
    total = (await session.exec(count_stmt)).one()

    stmt = stmt.order_by(OtherExpense.occurred_at.desc()).offset(offset).limit(limit)
    expenses = (await session.exec(stmt)).all()

    return OtherExpenseListResponse(
        items=[OtherExpenseListItem.model_validate(e, from_attributes=True) for e in expenses],
        total=total,
        limit=limit,
        offset=offset,
    )


@router.get(
    "/businesses/{business_id}/other-expenses/{expense_id}",
    response_model=OtherExpenseRead,
)
async def get_other_expense(
    business_id: UUID,
    expense_id: UUID,
    session: AsyncSession = Depends(get_db),
    _active_business: str = Depends(require_business_permission(PermissionCode.FINANCE_VIEW)),
) -> OtherExpenseRead:
    expense = (
        await session.exec(
            select(OtherExpense).where(
                OtherExpense.id == expense_id, OtherExpense.business_id == business_id
            )
        )
    ).first()
    if expense is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Expense not found")
    return OtherExpenseRead.model_validate(expense, from_attributes=True)


@router.patch(
    "/businesses/{business_id}/other-expenses/{expense_id}",
    response_model=OtherExpenseRead,
)
async def patch_other_expense(
    business_id: UUID,
    expense_id: UUID,
    patch: OtherExpenseUpdate,
    session: AsyncSession = Depends(get_db),
    claims: dict = Depends(get_current_claims),
    _active_business: str = Depends(
        require_business_permission(PermissionCode.FINANCE_EXPENSES_UPDATE)
    ),
) -> OtherExpenseRead:
    try:
        actor_id = UUID(claims["sub"])
    except (ValueError, KeyError, TypeError):
        actor_id = None
    try:
        expense = await update_expense(session, business_id, expense_id, actor_id, patch)
    except FinanceNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except FinanceStateError as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(exc)) from exc
    return OtherExpenseRead.model_validate(expense, from_attributes=True)


@router.delete(
    "/businesses/{business_id}/other-expenses/{expense_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
async def delete_other_expense(
    business_id: UUID,
    expense_id: UUID,
    session: AsyncSession = Depends(get_db),
    claims: dict = Depends(get_current_claims),
    _active_business: str = Depends(
        require_business_permission(PermissionCode.FINANCE_EXPENSES_DELETE)
    ),
) -> None:
    try:
        actor_id = UUID(claims["sub"])
    except (ValueError, KeyError, TypeError):
        actor_id = None
    try:
        await soft_delete_expense(session, business_id, expense_id, actor_id)
    except FinanceNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
