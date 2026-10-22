"""API tests for aggregated reporting endpoints.

Tests:
  - daily-takings buckets by day with revenue/count/avg, voided+refunded counted
  - item-mix aggregates completed sales only, top revenue first, honors limit
  - staff-performance buckets by actor including the null-actor row
  - finance-summary nets sales + incomes - expenses, skips soft-deleted rows
  - 403 without reports.view; cross-business isolation
"""

from __future__ import annotations

from datetime import UTC, datetime, timedelta
from decimal import Decimal
from uuid import UUID, uuid4

from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.finance import OtherExpense, OtherIncome
from app.models.pos import PaymentMethod, Sale, SaleLineItem, SaleStatus
from tests.test_token_verification import _build_token

BASE = "/api/v1/businesses/{business_id}/reports"


def _auth_header(
    *,
    business_id: UUID | None = None,
    permissions: list[str] | None = None,
) -> dict[str, str]:
    biz_id = business_id or uuid4()
    token = _build_token(
        extra_claims={
            "permissions": permissions or ["reports.view"],
            "active_business_id": str(biz_id),
        },
    )
    return {"Authorization": f"Bearer {token}"}


async def _seed_sale(
    db_session: AsyncSession,
    business_id: UUID,
    client_sale_id: str,
    status: str = "completed",
    payment_method: str = "cash",
    occurred_at: datetime | None = None,
    total: str = "100.00",
    store_id: UUID | None = None,
    actor_id: UUID | None = None,
    lines: list[tuple[UUID, str, str]] | None = None,
) -> Sale:
    """Insert a Sale with explicit line items.

    ``lines`` is a list of (item_id, quantity, line_total); defaults to a
    single line for the whole total (mirrors test_sales_reports).
    """
    sale = Sale(
        business_id=business_id,
        store_id=store_id or uuid4(),
        client_sale_id=client_sale_id,
        status=SaleStatus(status),
        subtotal=Decimal(total),
        discount_amount=Decimal("0"),
        tax_amount=Decimal("0"),
        total=Decimal(total),
        payment_method=PaymentMethod(payment_method),
        actor_id=actor_id,
        occurred_at=occurred_at or datetime.now(UTC),
    )
    db_session.add(sale)
    await db_session.flush()

    for item_id, qty, line_total in lines or [(uuid4(), "1", total)]:
        db_session.add(
            SaleLineItem(
                sale_id=sale.id,
                item_id=item_id,
                quantity=Decimal(qty),
                unit_price=Decimal(line_total),
                line_total=Decimal(line_total),
            )
        )
    await db_session.commit()
    return sale


async def _seed_expense(
    db_session: AsyncSession,
    business_id: UUID,
    client_id: str,
    category: str = "rent",
    amount: str = "50.00",
    store_id: UUID | None = None,
    occurred_at: datetime | None = None,
    is_deleted: bool = False,
) -> None:
    db_session.add(
        OtherExpense(
            business_id=business_id,
            store_id=store_id or uuid4(),
            client_expense_id=client_id,
            category=category,
            amount=Decimal(amount),
            description="test expense",
            payment_method=PaymentMethod.CASH,
            occurred_at=occurred_at or datetime.now(UTC),
            is_deleted=is_deleted,
        )
    )
    await db_session.commit()


async def _seed_income(
    db_session: AsyncSession,
    business_id: UUID,
    client_id: str,
    category: str = "catering",
    amount: str = "30.00",
    store_id: UUID | None = None,
    occurred_at: datetime | None = None,
) -> None:
    db_session.add(
        OtherIncome(
            business_id=business_id,
            store_id=store_id or uuid4(),
            client_income_id=client_id,
            category=category,
            amount=Decimal(amount),
            description="test income",
            payment_method=PaymentMethod.CASH,
            occurred_at=occurred_at or datetime.now(UTC),
        )
    )
    await db_session.commit()


class TestDailyTakingsEndpoint:
    async def test_buckets_days_with_averages(
        self,
        client: AsyncClient,
        db_session: AsyncSession,
    ) -> None:
        business_id = uuid4()
        now = datetime.now(UTC)
        day_one = now - timedelta(days=2)
        await _seed_sale(db_session, business_id, "dt-a", total="100.00", occurred_at=day_one)
        await _seed_sale(db_session, business_id, "dt-b", total="50.00", occurred_at=day_one)
        await _seed_sale(
            db_session,
            business_id,
            "dt-c",
            total="200.00",
            status="voided",
            occurred_at=now,
        )

        resp = await client.get(
            f"{BASE.format(business_id=business_id)}/daily-takings",
            headers=_auth_header(business_id=business_id),
        )
        assert resp.status_code == 200, resp.text
        days = {d["date"]: d for d in resp.json()["days"]}
        assert len(days) == 2
        assert days[day_one.date().isoformat()]["revenue"] == "150.00"
        assert days[day_one.date().isoformat()]["sales_count"] == 2
        assert days[day_one.date().isoformat()]["avg_ticket"] == "75.00"
        today = days[now.date().isoformat()]
        assert today["revenue"] == "0"
        assert today["sales_count"] == 1
        assert today["voided_count"] == 1

    async def test_date_window_filters(
        self,
        client: AsyncClient,
        db_session: AsyncSession,
    ) -> None:
        business_id = uuid4()
        now = datetime.now(UTC)
        await _seed_sale(
            db_session,
            business_id,
            "dtw-old",
            total="10.00",
            occurred_at=now - timedelta(days=10),
        )
        await _seed_sale(
            db_session,
            business_id,
            "dtw-new",
            total="20.00",
            occurred_at=now - timedelta(hours=1),
        )

        resp = await client.get(
            f"{BASE.format(business_id=business_id)}/daily-takings",
            headers=_auth_header(business_id=business_id),
            params={"from_date": (now - timedelta(days=2)).isoformat()},
        )
        assert resp.status_code == 200, resp.text
        assert len(resp.json()["days"]) == 1
        assert resp.json()["days"][0]["revenue"] == "20.00"


class TestItemMixEndpoint:
    async def test_completed_only_top_revenue_first(
        self,
        client: AsyncClient,
        db_session: AsyncSession,
    ) -> None:
        business_id = uuid4()
        burger, fries, soda = uuid4(), uuid4(), uuid4()
        await _seed_sale(
            db_session,
            business_id,
            "mix-1",
            lines=[(burger, "2", "20.00"), (fries, "1", "5.00")],
        )
        await _seed_sale(
            db_session,
            business_id,
            "mix-2",
            lines=[(burger, "1", "10.00"), (soda, "3", "9.00")],
        )
        await _seed_sale(
            db_session,
            business_id,
            "mix-void",
            status="voided",
            lines=[(soda, "100", "300.00")],
        )

        resp = await client.get(
            f"{BASE.format(business_id=business_id)}/item-mix",
            headers=_auth_header(business_id=business_id),
        )
        assert resp.status_code == 200, resp.text
        lines = resp.json()["lines"]
        assert [line["item_id"] for line in lines] == [
            str(burger),
            str(soda),
            str(fries),
        ]
        assert lines[0]["quantity"] == "3.000"
        assert lines[0]["revenue"] == "30.00"
        # The voided 100 sodas must not leak in.
        assert next(line for line in lines if line["item_id"] == str(soda))["quantity"] == "3.000"

    async def test_limit_is_honored(
        self,
        client: AsyncClient,
        db_session: AsyncSession,
    ) -> None:
        business_id = uuid4()
        await _seed_sale(
            db_session,
            business_id,
            "mixlim-1",
            lines=[(uuid4(), "1", "10.00"), (uuid4(), "1", "20.00")],
        )

        resp = await client.get(
            f"{BASE.format(business_id=business_id)}/item-mix",
            headers=_auth_header(business_id=business_id),
            params={"limit": 1},
        )
        assert resp.status_code == 200, resp.text
        assert len(resp.json()["lines"]) == 1


class TestStaffPerformanceEndpoint:
    async def test_buckets_by_actor_with_unknown_row(
        self,
        client: AsyncClient,
        db_session: AsyncSession,
    ) -> None:
        business_id = uuid4()
        ava, marco = uuid4(), uuid4()
        await _seed_sale(db_session, business_id, "sp-ava-1", total="100.00", actor_id=ava)
        await _seed_sale(db_session, business_id, "sp-ava-2", total="50.00", actor_id=ava)
        await _seed_sale(
            db_session,
            business_id,
            "sp-marco-void",
            total="30.00",
            status="voided",
            actor_id=marco,
        )
        await _seed_sale(db_session, business_id, "sp-anon", total="20.00")

        resp = await client.get(
            f"{BASE.format(business_id=business_id)}/staff-performance",
            headers=_auth_header(business_id=business_id),
        )
        assert resp.status_code == 200, resp.text
        by_actor = {line["actor_id"]: line for line in resp.json()["lines"]}
        assert by_actor[str(ava)]["revenue"] == "150.00"
        assert by_actor[str(ava)]["sales_count"] == 2
        assert by_actor[str(marco)]["revenue"] == "0"
        assert by_actor[str(marco)]["voided_count"] == 1
        assert by_actor[None]["revenue"] == "20.00"


class TestFinanceSummaryEndpoint:
    async def test_nets_sales_plus_incomes_minus_expenses(
        self,
        client: AsyncClient,
        db_session: AsyncSession,
    ) -> None:
        business_id = uuid4()
        await _seed_sale(db_session, business_id, "fin-sale", total="200.00")
        await _seed_sale(
            db_session,
            business_id,
            "fin-void",
            total="999.00",
            status="voided",
        )
        await _seed_expense(
            db_session, business_id, "fin-exp-rent", category="rent", amount="50.00"
        )
        await _seed_expense(
            db_session, business_id, "fin-exp-util", category="utilities", amount="20.00"
        )
        await _seed_expense(
            db_session,
            business_id,
            "fin-exp-dead",
            category="rent",
            amount="1000.00",
            is_deleted=True,
        )
        await _seed_income(db_session, business_id, "fin-inc", category="catering", amount="30.00")

        resp = await client.get(
            f"{BASE.format(business_id=business_id)}/finance-summary",
            headers=_auth_header(business_id=business_id),
        )
        assert resp.status_code == 200, resp.text
        data = resp.json()
        # Voided sale and soft-deleted expense stay out of the math.
        assert data["sales_revenue"] == "200.00"
        assert data["income_total"] == "30.00"
        assert data["expense_total"] == "70.00"
        assert data["net"] == "160.00"
        assert {c["category"]: c["total"] for c in data["expenses_by_category"]} == {
            "rent": "50.00",
            "utilities": "20.00",
        }


class TestReportsRbac:
    async def test_reports_reject_without_reports_view(
        self,
        client: AsyncClient,
    ) -> None:
        business_id = uuid4()
        for suffix in ("daily-takings", "item-mix", "staff-performance", "finance-summary"):
            resp = await client.get(
                f"{BASE.format(business_id=business_id)}/{suffix}",
                headers=_auth_header(
                    business_id=business_id,
                    permissions=["pos.view"],
                ),
            )
            assert resp.status_code == 403, suffix

    async def test_reports_cross_business_isolation(
        self,
        client: AsyncClient,
        db_session: AsyncSession,
    ) -> None:
        business_id = uuid4()
        other = uuid4()
        await _seed_sale(db_session, business_id, "cross-rep", total="999.00")

        headers = _auth_header(business_id=other, permissions=["reports.view"])
        resp = await client.get(
            f"{BASE.format(business_id=other)}/daily-takings",
            headers=headers,
        )
        assert resp.status_code == 200
        assert resp.json()["days"] == []
