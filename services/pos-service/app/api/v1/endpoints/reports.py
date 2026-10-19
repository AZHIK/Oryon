"""Aggregated reporting endpoints — daily takings, item mix, staff
performance, and finance summary.

┌──────────────────────────────────────────────────────────────────────────┐
│ PERMISSION MODEL                                                         │
│                                                                          │
│   All four endpoints → REPORTS_VIEW (the code the app's Reports nav      │
│   gates on). The older `GET /sales/summary` keeps its POS_VIEW gate —    │
│   it predates this surface and stays untouched.                          │
│                                                                          │
│ Business-context binding is enforced at the shared dependency level      │
│ (``require_business_permission``), not per-endpoint.                     │
│                                                                          │
│ Every query is a single SQL aggregation (no Python-side rollups),        │
│ business-scoped first, so one business can never see another's           │
│ numbers. Read-only: no endpoint here writes.                             │
└──────────────────────────────────────────────────────────────────────────┘
"""

from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from typing import Annotated
from uuid import UUID

import structlog
from fastapi import APIRouter, Depends, Query
from sqlalchemy import case as sa_case
from sqlalchemy import func as sa_func
from sqlmodel import select
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.permission_codes import PermissionCode
from app.db.session import get_db
from app.deps.auth import require_business_permission, store_scope_filter
from app.models.customers import Customer
from app.models.finance import OtherExpense, OtherIncome
from app.models.pos import Sale, SaleLineItem, SaleStatus
from app.schemas.reports import (
    CustomerGroupsResponse,
    CustomerGroupLine,
    CustomerSpendLine,
    CustomerSpendResponse,
    DailyTakingsDay,
    DailyTakingsResponse,
    ExpenseReportLine,
    ExpenseReportResponse,
    FinanceCategoryTotal,
    FinanceSummaryResponse,
    ItemMixLine,
    ItemMixResponse,
    ProfitLossResponse,
    RegisterDay,
    RegisterDayMethod,
    RegisterReportResponse,
    SellPaymentLine,
    SellPaymentsResponse,
    StaffPerformanceLine,
    StaffPerformanceResponse,
    TaxDay,
    TaxReportResponse,
)

logger = structlog.get_logger(__name__)
router = APIRouter(tags=["reports"])


def _sale_filters(
    business_id: UUID,
    from_date: datetime | None,
    to_date: datetime | None,
    store_id: UUID | None,
) -> list:
    """Shared WHERE clauses: business scope plus the optional window."""
    filters = [Sale.business_id == business_id]
    if from_date is not None:
        filters.append(Sale.occurred_at >= from_date)
    if to_date is not None:
        filters.append(Sale.occurred_at <= to_date)
    if store_id is not None:
        filters.append(Sale.store_id == store_id)
    return filters


@router.get("/businesses/{business_id}/reports/daily-takings")
async def daily_takings(
    business_id: UUID,
    session: Annotated[AsyncSession, Depends(get_db)],
    _active_business: str = Depends(require_business_permission(PermissionCode.REPORTS_VIEW)),
    from_date: datetime | None = Query(default=None, description="Start (inclusive) for occurred_at"),
    to_date: datetime | None = Query(default=None, description="End (inclusive) for occurred_at"),
    store_id: UUID | None = Depends(store_scope_filter),
) -> DailyTakingsResponse:
    """Per-day revenue, ticket count, average ticket, and void/refund counts.

    Days bucket by UTC date of ``occurred_at``. Days with no sales simply
    do not appear — the client, not this endpoint, decides whether to render
    zero-filled gaps.
    """
    day = sa_func.date(Sale.occurred_at).label("day")
    stmt = (
        select(
            day,
            sa_func.sum(
                sa_case((Sale.status == SaleStatus.COMPLETED, Sale.total), else_=Decimal("0"))
            ).label("revenue"),
            sa_func.count(Sale.id).label("sales_count"),
            sa_func.sum(sa_case((Sale.status == SaleStatus.VOIDED, 1), else_=0)).label("voided_count"),
            sa_func.sum(sa_case((Sale.status == SaleStatus.REFUNDED, 1), else_=0)).label("refunded_count"),
        )
        .where(*_sale_filters(business_id, from_date, to_date, store_id))
        .group_by(day)
        .order_by(day)
    )
    rows = (await session.exec(stmt)).all()

    days = [
        DailyTakingsDay(
            date=row.day,
            revenue=row.revenue or Decimal("0"),
            sales_count=row.sales_count,
            avg_ticket=(row.revenue / row.sales_count)
            if row.sales_count and row.revenue
            else Decimal("0"),
            voided_count=row.voided_count or 0,
            refunded_count=row.refunded_count or 0,
        )
        for row in rows
    ]
    logger.info("reports.daily_takings", business_id=str(business_id), days=len(days))
    return DailyTakingsResponse(days=days)


@router.get("/businesses/{business_id}/reports/item-mix")
async def item_mix(
    business_id: UUID,
    session: Annotated[AsyncSession, Depends(get_db)],
    _active_business: str = Depends(require_business_permission(PermissionCode.REPORTS_VIEW)),
    from_date: datetime | None = Query(default=None, description="Start (inclusive) for occurred_at"),
    to_date: datetime | None = Query(default=None, description="End (inclusive) for occurred_at"),
    store_id: UUID | None = Depends(store_scope_filter),
    limit: int = Query(default=50, ge=1, le=200, description="Max items, top revenue first"),
    order_by: str = Query(
        default="revenue",
        description="Ranking — revenue (Product Sell Report) or quantity (Trending Products)",
    ),
) -> ItemMixResponse:
    """What sold, by menu item: quantity, revenue, and line count.

    Completed sales only. Item names are deliberately NOT resolved here —
    ``item_id`` is Inventory Service's key and the app joins its catalog.
    ``order_by=revenue`` backs the **Product Sell Report**; ``order_by=
    quantity`` backs **Trending Products**.
    """
    if order_by not in ("revenue", "quantity"):
        order_by = "revenue"
    filters = _sale_filters(business_id, from_date, to_date, store_id)
    filters.append(Sale.status == SaleStatus.COMPLETED)
    order_expr = (
        sa_func.sum(SaleLineItem.line_total).desc()
        if order_by == "revenue"
        else sa_func.sum(SaleLineItem.quantity).desc()
    )
    stmt = (
        select(
            SaleLineItem.item_id,
            sa_func.sum(SaleLineItem.quantity).label("quantity"),
            sa_func.sum(SaleLineItem.line_total).label("revenue"),
            sa_func.count(SaleLineItem.id).label("lines"),
        )
        .join(Sale, SaleLineItem.sale_id == Sale.id)
        .where(*filters)
        .group_by(SaleLineItem.item_id)
        .order_by(order_expr)
        .limit(limit)
    )
    rows = (await session.exec(stmt)).all()

    lines = [
        ItemMixLine(
            item_id=row.item_id,
            quantity=row.quantity or Decimal("0"),
            revenue=row.revenue or Decimal("0"),
            lines=row.lines,
        )
        for row in rows
    ]
    logger.info("reports.item_mix", business_id=str(business_id), lines=len(lines))
    return ItemMixResponse(lines=lines)


@router.get("/businesses/{business_id}/reports/staff-performance")
async def staff_performance(
    business_id: UUID,
    session: Annotated[AsyncSession, Depends(get_db)],
    _active_business: str = Depends(require_business_permission(PermissionCode.REPORTS_VIEW)),
    from_date: datetime | None = Query(default=None, description="Start (inclusive) for occurred_at"),
    to_date: datetime | None = Query(default=None, description="End (inclusive) for occurred_at"),
    store_id: UUID | None = Depends(store_scope_filter),
) -> StaffPerformanceResponse:
    """Per-actor sales: count, revenue, and void/refund counts.

    SQL groups NULL ``actor_id``s into one row, which surfaces as the
    explicit unknown bucket rather than vanishing from the report.
    """
    stmt = (
        select(
            Sale.actor_id,
            sa_func.count(Sale.id).label("sales_count"),
            sa_func.sum(
                sa_case((Sale.status == SaleStatus.COMPLETED, Sale.total), else_=Decimal("0"))
            ).label("revenue"),
            sa_func.sum(sa_case((Sale.status == SaleStatus.VOIDED, 1), else_=0)).label("voided_count"),
            sa_func.sum(sa_case((Sale.status == SaleStatus.REFUNDED, 1), else_=0)).label("refunded_count"),
        )
        .where(*_sale_filters(business_id, from_date, to_date, store_id))
        .group_by(Sale.actor_id)
        .order_by(sa_func.sum(
            sa_case((Sale.status == SaleStatus.COMPLETED, Sale.total), else_=Decimal("0"))
        ).desc())
    )
    rows = (await session.exec(stmt)).all()

    lines = [
        StaffPerformanceLine(
            actor_id=row.actor_id,
            sales_count=row.sales_count,
            revenue=row.revenue or Decimal("0"),
            voided_count=row.voided_count or 0,
            refunded_count=row.refunded_count or 0,
        )
        for row in rows
    ]
    logger.info("reports.staff_performance", business_id=str(business_id), lines=len(lines))
    return StaffPerformanceResponse(lines=lines)


def _finance_filters(model, business_id: UUID, from_date, to_date, store_id) -> list:
    """Shared clauses for finance tables: scope, window, live rows only."""
    filters = [
        model.business_id == business_id,
        model.is_deleted == False,  # noqa: E712
    ]
    if from_date is not None:
        filters.append(model.occurred_at >= from_date)
    if to_date is not None:
        filters.append(model.occurred_at <= to_date)
    if store_id is not None:
        filters.append(model.store_id == store_id)
    return filters


@router.get("/businesses/{business_id}/reports/finance-summary")
async def finance_summary(
    business_id: UUID,
    session: Annotated[AsyncSession, Depends(get_db)],
    _active_business: str = Depends(require_business_permission(PermissionCode.REPORTS_VIEW)),
    from_date: datetime | None = Query(default=None, description="Start (inclusive) for occurred_at"),
    to_date: datetime | None = Query(default=None, description="End (inclusive) for occurred_at"),
    store_id: UUID | None = Depends(store_scope_filter),
) -> FinanceSummaryResponse:
    """Money in vs money out: completed sales revenue, ad-hoc incomes and
    expenses by category, and the net. Deleted finance entries are excluded.
    """
    revenue_row = (
        await session.exec(
            select(
                sa_func.sum(
                    sa_case((Sale.status == SaleStatus.COMPLETED, Sale.total), else_=Decimal("0"))
                )
            ).where(*_sale_filters(business_id, from_date, to_date, store_id))
        )
    ).one()
    sales_revenue = revenue_row or Decimal("0")

    async def _category_totals(model) -> list[FinanceCategoryTotal]:
        rows = (
            await session.exec(
                select(model.category, sa_func.sum(model.amount))
                .where(*_finance_filters(model, business_id, from_date, to_date, store_id))
                .group_by(model.category)
                .order_by(sa_func.sum(model.amount).desc())
            )
        ).all()
        return [
            FinanceCategoryTotal(category=row[0], total=row[1] or Decimal("0"))
            for row in rows
        ]

    expenses = await _category_totals(OtherExpense)
    incomes = await _category_totals(OtherIncome)
    expense_total = sum((line.total for line in expenses), Decimal("0"))
    income_total = sum((line.total for line in incomes), Decimal("0"))

    response = FinanceSummaryResponse(
        sales_revenue=sales_revenue,
        income_total=income_total,
        expense_total=expense_total,
        net=sales_revenue + income_total - expense_total,
        expenses_by_category=expenses,
        incomes_by_category=incomes,
    )
    logger.info(
        "reports.finance_summary",
        business_id=str(business_id),
        net=str(response.net),
    )
    return response


@router.get("/businesses/{business_id}/reports/sell-payments")
async def sell_payments(
    business_id: UUID,
    session: Annotated[AsyncSession, Depends(get_db)],
    _active_business: str = Depends(require_business_permission(PermissionCode.REPORTS_VIEW)),
    from_date: datetime | None = Query(default=None, description="Start (inclusive) for occurred_at"),
    to_date: datetime | None = Query(default=None, description="End (inclusive) for occurred_at"),
    store_id: UUID | None = Depends(store_scope_filter),
) -> SellPaymentsResponse:
    """Sell Payment Report: completed-sales revenue grouped by payment method."""
    filters = _sale_filters(business_id, from_date, to_date, store_id)
    filters.append(Sale.status == SaleStatus.COMPLETED)
    rows = (
        await session.exec(
            select(
                Sale.payment_method,
                sa_func.count(Sale.id).label("sales_count"),
                sa_func.sum(Sale.total).label("revenue"),
            )
            .where(*filters)
            .group_by(Sale.payment_method)
            .order_by(sa_func.sum(Sale.total).desc())
        )
    ).all()
    lines = [
        SellPaymentLine(
            payment_method=str(row[0].value if hasattr(row[0], "value") else row[0]),
            sales_count=row[1],
            revenue=row[2] or Decimal("0"),
        )
        for row in rows
    ]
    total = sum((line.revenue for line in lines), Decimal("0"))
    logger.info("reports.sell_payments", business_id=str(business_id), lines=len(lines))
    return SellPaymentsResponse(lines=lines, total_revenue=total)


@router.get("/businesses/{business_id}/reports/tax-report")
async def tax_report(
    business_id: UUID,
    session: Annotated[AsyncSession, Depends(get_db)],
    _active_business: str = Depends(require_business_permission(PermissionCode.REPORTS_VIEW)),
    from_date: datetime | None = Query(default=None, description="Start (inclusive) for occurred_at"),
    to_date: datetime | None = Query(default=None, description="End (inclusive) for occurred_at"),
    store_id: UUID | None = Depends(store_scope_filter),
) -> TaxReportResponse:
    """Tax Report: tax collected per day from completed sales."""
    day = sa_func.date(Sale.occurred_at).label("day")
    rows = (
        await session.exec(
            select(
                day,
                sa_func.sum(
                    sa_case((Sale.status == SaleStatus.COMPLETED, Sale.total), else_=Decimal("0"))
                ).label("revenue"),
                sa_func.sum(
                    sa_case((Sale.status == SaleStatus.COMPLETED, Sale.tax_amount), else_=Decimal("0"))
                ).label("tax"),
                sa_func.sum(
                    sa_case((Sale.status == SaleStatus.COMPLETED, 1), else_=0)
                ).label("sales_count"),
            )
            .where(*_sale_filters(business_id, from_date, to_date, store_id))
            .group_by(day)
            .order_by(day)
        )
    ).all()
    days = [
        TaxDay(
            date=row.day,
            taxable_revenue=row.revenue or Decimal("0"),
            tax_collected=row.tax or Decimal("0"),
            sales_count=row.sales_count or 0,
        )
        for row in rows
    ]
    total_tax = sum((d.tax_collected for d in days), Decimal("0"))
    total_rev = sum((d.taxable_revenue for d in days), Decimal("0"))
    logger.info("reports.tax_report", business_id=str(business_id), days=len(days))
    return TaxReportResponse(days=days, total_tax=total_tax, total_taxable_revenue=total_rev)


@router.get("/businesses/{business_id}/reports/register-summary")
async def register_summary(
    business_id: UUID,
    session: Annotated[AsyncSession, Depends(get_db)],
    _active_business: str = Depends(require_business_permission(PermissionCode.REPORTS_VIEW)),
    from_date: datetime | None = Query(default=None, description="Start (inclusive) for occurred_at"),
    to_date: datetime | None = Query(default=None, description="End (inclusive) for occurred_at"),
    store_id: UUID | None = Depends(store_scope_filter),
) -> RegisterReportResponse:
    """Register Report: per-day takings with per-method drawer split."""
    day = sa_func.date(Sale.occurred_at).label("day")
    day_rows = (
        await session.exec(
            select(
                day,
                sa_func.sum(
                    sa_case((Sale.status == SaleStatus.COMPLETED, Sale.total), else_=Decimal("0"))
                ).label("revenue"),
                sa_func.sum(sa_case((Sale.status == SaleStatus.COMPLETED, 1), else_=0)).label("sales_count"),
                sa_func.sum(sa_case((Sale.status == SaleStatus.VOIDED, 1), else_=0)).label("voided_count"),
                sa_func.sum(sa_case((Sale.status == SaleStatus.REFUNDED, 1), else_=0)).label("refunded_count"),
            )
            .where(*_sale_filters(business_id, from_date, to_date, store_id))
            .group_by(day)
            .order_by(day)
        )
    ).all()
    method_rows = (
        await session.exec(
            select(
                sa_func.date(Sale.occurred_at).label("day"),
                Sale.payment_method,
                sa_func.count(Sale.id).label("sales_count"),
                sa_func.sum(Sale.total).label("revenue"),
            )
            .where(
                *_sale_filters(business_id, from_date, to_date, store_id),
                Sale.status == SaleStatus.COMPLETED,
            )
            .group_by(sa_func.date(Sale.occurred_at), Sale.payment_method)
        )
    ).all()
    by_day: dict = {}
    for row in method_rows:
        key = str(row[0])
        by_day.setdefault(key, []).append(
            RegisterDayMethod(
                payment_method=str(row[1].value if hasattr(row[1], "value") else row[1]),
                sales_count=row[2],
                revenue=row[3] or Decimal("0"),
            )
        )
    days = [
        RegisterDay(
            date=row.day,
            revenue=row.revenue or Decimal("0"),
            sales_count=row.sales_count or 0,
            voided_count=row.voided_count or 0,
            refunded_count=row.refunded_count or 0,
            by_method=by_day.get(str(row.day), []),
        )
        for row in day_rows
    ]
    logger.info("reports.register_summary", business_id=str(business_id), days=len(days))
    return RegisterReportResponse(days=days)


@router.get("/businesses/{business_id}/reports/expense-report")
async def expense_report(
    business_id: UUID,
    session: Annotated[AsyncSession, Depends(get_db)],
    _active_business: str = Depends(require_business_permission(PermissionCode.REPORTS_VIEW)),
    from_date: datetime | None = Query(default=None, description="Start (inclusive) for occurred_at"),
    to_date: datetime | None = Query(default=None, description="End (inclusive) for occurred_at"),
    store_id: UUID | None = Depends(store_scope_filter),
    category: str | None = Query(default=None, description="Filter by expense category"),
    limit: int = Query(default=100, ge=1, le=500),
    offset: int = Query(default=0, ge=0),
) -> ExpenseReportResponse:
    """Expense Report: ad-hoc spend lines plus category totals."""
    filters = _finance_filters(OtherExpense, business_id, from_date, to_date, store_id)
    if category is not None:
        filters.append(OtherExpense.category == category)
    rows = (
        await session.exec(
            select(OtherExpense)
            .where(*filters)
            .order_by(OtherExpense.occurred_at.desc())
            .offset(offset)
            .limit(limit)
        )
    ).all()
    cat_rows = (
        await session.exec(
            select(OtherExpense.category, sa_func.sum(OtherExpense.amount))
            .where(*_finance_filters(OtherExpense, business_id, from_date, to_date, store_id))
            .group_by(OtherExpense.category)
            .order_by(sa_func.sum(OtherExpense.amount).desc())
        )
    ).all()
    by_category = [
        FinanceCategoryTotal(category=row[0], total=row[1] or Decimal("0")) for row in cat_rows
    ]
    total = sum((c.total for c in by_category), Decimal("0"))
    lines = [
        ExpenseReportLine(
            id=r.id,
            category=r.category,
            amount=r.amount,
            description=r.description,
            payment_method=str(r.payment_method.value if hasattr(r.payment_method, "value") else r.payment_method),
            store_id=r.store_id,
            occurred_at=r.occurred_at,
            actor_id=r.actor_id,
        )
        for r in rows
    ]
    logger.info("reports.expense_report", business_id=str(business_id), lines=len(lines))
    return ExpenseReportResponse(lines=lines, total=total, by_category=by_category)


@router.get("/businesses/{business_id}/reports/profit-loss")
async def profit_loss(
    business_id: UUID,
    session: Annotated[AsyncSession, Depends(get_db)],
    _active_business: str = Depends(require_business_permission(PermissionCode.REPORTS_VIEW)),
    from_date: datetime | None = Query(default=None, description="Start (inclusive) for occurred_at"),
    to_date: datetime | None = Query(default=None, description="End (inclusive) for occurred_at"),
    store_id: UUID | None = Depends(store_scope_filter),
) -> ProfitLossResponse:
    """Profit / Loss Report (POS-side leg): sales + incomes − expenses."""
    revenue_row = (
        await session.exec(
            select(
                sa_func.sum(
                    sa_case((Sale.status == SaleStatus.COMPLETED, Sale.total), else_=Decimal("0"))
                )
            ).where(*_sale_filters(business_id, from_date, to_date, store_id))
        )
    ).one()
    sales_revenue = revenue_row or Decimal("0")

    async def _category_totals(model) -> list[FinanceCategoryTotal]:
        rows = (
            await session.exec(
                select(model.category, sa_func.sum(model.amount))
                .where(*_finance_filters(model, business_id, from_date, to_date, store_id))
                .group_by(model.category)
                .order_by(sa_func.sum(model.amount).desc())
            )
        ).all()
        return [FinanceCategoryTotal(category=row[0], total=row[1] or Decimal("0")) for row in rows]

    expenses = await _category_totals(OtherExpense)
    incomes = await _category_totals(OtherIncome)
    expense_total = sum((line.total for line in expenses), Decimal("0"))
    income_total = sum((line.total for line in incomes), Decimal("0"))
    gross = sales_revenue + income_total
    response = ProfitLossResponse(
        sales_revenue=sales_revenue,
        income_total=income_total,
        expense_total=expense_total,
        gross_profit=gross,
        net=gross - expense_total,
        expenses_by_category=expenses,
        incomes_by_category=incomes,
    )
    logger.info("reports.profit_loss", business_id=str(business_id), net=str(response.net))
    return response


@router.get("/businesses/{business_id}/reports/customer-groups")
async def customer_groups(
    business_id: UUID,
    session: Annotated[AsyncSession, Depends(get_db)],
    _active_business: str = Depends(require_business_permission(PermissionCode.REPORTS_VIEW)),
    from_date: datetime | None = Query(default=None, description="Start (inclusive) for occurred_at"),
    to_date: datetime | None = Query(default=None, description="End (inclusive) for occurred_at"),
) -> CustomerGroupsResponse:
    """Customer Groups Report: customers and their spend bucketed by group."""
    group_col = sa_func.coalesce(Customer.customer_group, "ungrouped").label("grp")
    cust_rows = (
        await session.exec(
            select(group_col, sa_func.count(Customer.id))
            .where(Customer.business_id == business_id, Customer.is_deleted == False)  # noqa: E712
            .group_by(group_col)
        )
    ).all()
    customer_count = {row[0]: row[1] for row in cust_rows}
    sale_filters = _sale_filters(business_id, from_date, to_date, None)
    sale_filters.append(Sale.status == SaleStatus.COMPLETED)
    # NOTE: GROUP BY must reuse the *same* labeled expression object —
    # a second, textually-identical coalesce() renders a distinct bind
    # param that Postgres refuses to match to the SELECT list (GroupingError).
    spend_grp = sa_func.coalesce(Customer.customer_group, "ungrouped").label("grp")
    spend_rows = (
        await session.exec(
            select(
                spend_grp,
                sa_func.count(Sale.id).label("sales_count"),
                sa_func.sum(Sale.total).label("revenue"),
            )
            .join(Customer, Sale.customer_id == Customer.id, isouter=True)
            .where(*sale_filters)
            .group_by(spend_grp)
        )
    ).all()
    spend = {row[0]: (row[1], row[2] or Decimal("0")) for row in spend_rows}
    # Walk-in sales (null customer) surface under "ungrouped" via the outer join.
    groups = set(customer_count) | set(spend)
    lines = [
        CustomerGroupLine(
            group=g,
            customer_count=customer_count.get(g, 0),
            sales_count=spend.get(g, (0, Decimal("0")))[0],
            revenue=spend.get(g, (0, Decimal("0")))[1],
        )
        for g in sorted(groups)
    ]
    logger.info("reports.customer_groups", business_id=str(business_id), lines=len(lines))
    return CustomerGroupsResponse(lines=lines)


@router.get("/businesses/{business_id}/reports/customer-spend")
async def customer_spend(
    business_id: UUID,
    session: Annotated[AsyncSession, Depends(get_db)],
    _active_business: str = Depends(require_business_permission(PermissionCode.REPORTS_VIEW)),
    from_date: datetime | None = Query(default=None, description="Start (inclusive) for occurred_at"),
    to_date: datetime | None = Query(default=None, description="End (inclusive) for occurred_at"),
    limit: int = Query(default=100, ge=1, le=500),
) -> CustomerSpendResponse:
    """Customer-spend leg of the Supplier & Customer Report."""
    sale_filters = _sale_filters(business_id, from_date, to_date, None)
    sale_filters.append(Sale.status == SaleStatus.COMPLETED)
    rows = (
        await session.exec(
            select(
                Sale.customer_id,
                sa_func.count(Sale.id).label("sales_count"),
                sa_func.sum(Sale.total).label("revenue"),
            )
            .where(*sale_filters)
            .group_by(Sale.customer_id)
            .order_by(sa_func.sum(Sale.total).desc())
            .limit(limit)
        )
    ).all()
    customer_ids = [row[0] for row in rows if row[0] is not None]
    names: dict = {}
    if customer_ids:
        cust_rows = (
            await session.exec(
                select(Customer.id, Customer.name).where(Customer.id.in_(customer_ids))
            )
        ).all()
        names = {row[0]: row[1] for row in cust_rows}
    lines = [
        CustomerSpendLine(
            customer_id=row[0],
            customer_name=names.get(row[0], "Walk-in") if row[0] is not None else "Walk-in",
            sales_count=row[1],
            total_spent=row[2] or Decimal("0"),
        )
        for row in rows
    ]
    logger.info("reports.customer_spend", business_id=str(business_id), lines=len(lines))
    return CustomerSpendResponse(lines=lines)
