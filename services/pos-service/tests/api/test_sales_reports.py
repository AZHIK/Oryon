"""API tests for sales reporting endpoints — list and summary.

Tests:
  - GET /sales date filters use occurred_at (not synced_at)
  - GET /sales filtered by status / payment_method / location
  - GET /sales includes is_time_suspect per result
  - pagination respects limit
  - GET /sales/summary excludes voided/refunded from revenue, counts separately
  - payment_method breakdown sums correctly
  - permission rejection (403) for both endpoints
  - cross-business protection for both endpoints
"""

from __future__ import annotations

from datetime import UTC, datetime, timedelta
from decimal import Decimal
from uuid import UUID, uuid4

from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.pos import Sale, SaleLineItem
from tests.test_token_verification import _build_token

LIST_URL = "/api/v1/businesses/{business_id}/sales"
SUMMARY_URL = "/api/v1/businesses/{business_id}/sales/summary"


def _auth_header(
    *,
    business_id: UUID | None = None,
    permissions: list[str] | None = None,
) -> dict[str, str]:
    biz_id = business_id or uuid4()
    token = _build_token(
        extra_claims={
            "permissions": permissions or ["pos.write", "pos.view"],
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
    is_time_suspect: bool = False,
    voided_at: datetime | None = None,
    refunded_at: datetime | None = None,
    void_or_refund_reason: str | None = None,
) -> Sale:
    """Insert a Sale row directly into the database."""
    from app.models.pos import PaymentMethod, SaleStatus

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
        actor_id=None,
        occurred_at=occurred_at or datetime.now(UTC),
        is_time_suspect=is_time_suspect,
        voided_at=voided_at,
        refunded_at=refunded_at,
        void_or_refund_reason=void_or_refund_reason,
    )
    db_session.add(sale)
    await db_session.flush()

    line_item = SaleLineItem(
        sale_id=sale.id,
        item_id=uuid4(),
        quantity=Decimal("1"),
        unit_price=Decimal(total),
        line_total=Decimal(total),
    )
    db_session.add(line_item)
    await db_session.commit()
    return sale


class TestListSalesEndpoint:
    """GET /businesses/{business_id}/sales"""

    async def test_list_all_sales_for_business(
        self,
        client: AsyncClient,
        db_session: AsyncSession,
    ) -> None:
        business_id = uuid4()
        _s1 = await _seed_sale(db_session, business_id, "list-1", occurred_at=datetime.now(UTC))
        _s2 = await _seed_sale(db_session, business_id, "list-2", occurred_at=datetime.now(UTC))

        headers = _auth_header(business_id=business_id)
        resp = await client.get(LIST_URL.format(business_id=business_id), headers=headers)

        assert resp.status_code == 200
        data = resp.json()
        assert data["total"] == 2
        assert len(data["items"]) == 2

    async def test_date_filter_uses_occurred_at_not_synced_at(
        self,
        client: AsyncClient,
        db_session: AsyncSession,
    ) -> None:
        business_id = uuid4()
        now = datetime.now(UTC)

        old_occurred = now - timedelta(days=10)
        recent_occurred = now - timedelta(hours=1)

        old_sale = await _seed_sale(
            db_session,
            business_id,
            "occurred-old",
            occurred_at=old_occurred,
            total="50.00",
        )
        recent_sale = await _seed_sale(
            db_session,
            business_id,
            "occurred-recent",
            occurred_at=recent_occurred,
            total="75.00",
        )

        # Manually set synced_at to the OPPOSITE — old sale has recent synced_at,
        # recent sale has old synced_at — to prove the filter uses occurred_at.
        old_sale.synced_at = recent_occurred
        recent_sale.synced_at = old_occurred
        await db_session.commit()

        headers = _auth_header(business_id=business_id)

        window_start = now - timedelta(days=2)
        resp = await client.get(
            LIST_URL.format(business_id=business_id),
            headers=headers,
            params={
                "from_date": window_start.isoformat(),
            },
        )
        assert resp.status_code == 200
        data = resp.json()
        client_ids = {item["client_sale_id"] for item in data["items"]}
        # only recent_occurred falls within the window; old_occurred is day -10
        assert "occurred-recent" in client_ids
        assert "occurred-old" not in client_ids, (
            "date filter matched synced_at instead of occurred_at"
        )

    async def test_filter_by_status(
        self,
        client: AsyncClient,
        db_session: AsyncSession,
    ) -> None:
        business_id = uuid4()
        await _seed_sale(db_session, business_id, "status-completed", status="completed")
        await _seed_sale(
            db_session,
            business_id,
            "status-voided",
            status="voided",
            voided_at=datetime.now(UTC),
            void_or_refund_reason="mistake",
        )
        await _seed_sale(
            db_session,
            business_id,
            "status-refunded",
            status="refunded",
            refunded_at=datetime.now(UTC),
            void_or_refund_reason="return",
        )

        headers = _auth_header(business_id=business_id)

        resp = await client.get(
            LIST_URL.format(business_id=business_id),
            headers=headers,
            params={"status": "completed"},
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["total"] == 1
        assert data["items"][0]["status"] == "completed"

        resp = await client.get(
            LIST_URL.format(business_id=business_id),
            headers=headers,
            params={"status": "voided"},
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["total"] == 1
        assert data["items"][0]["status"] == "voided"

    async def test_filter_by_payment_method(
        self,
        client: AsyncClient,
        db_session: AsyncSession,
    ) -> None:
        business_id = uuid4()
        await _seed_sale(db_session, business_id, "pm-cash", payment_method="cash")
        await _seed_sale(db_session, business_id, "pm-card", payment_method="card")

        headers = _auth_header(business_id=business_id)
        resp = await client.get(
            LIST_URL.format(business_id=business_id),
            headers=headers,
            params={"payment_method": "card"},
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["total"] == 1
        assert data["items"][0]["payment_method"] == "card"

    async def test_filter_by_store(
        self,
        client: AsyncClient,
        db_session: AsyncSession,
    ) -> None:
        business_id = uuid4()
        loc_a = uuid4()
        loc_b = uuid4()
        await _seed_sale(db_session, business_id, "loc-a", store_id=loc_a)
        await _seed_sale(db_session, business_id, "loc-b", store_id=loc_b)

        headers = _auth_header(business_id=business_id)
        resp = await client.get(
            LIST_URL.format(business_id=business_id),
            headers=headers,
            params={"store_id": str(loc_a)},
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["total"] == 1
        assert data["items"][0]["store_id"] == str(loc_a)

    async def test_response_includes_is_time_suspect(
        self,
        client: AsyncClient,
        db_session: AsyncSession,
    ) -> None:
        business_id = uuid4()
        _normal = await _seed_sale(
            db_session,
            business_id,
            "suspect-normal",
            is_time_suspect=False,
            occurred_at=datetime.now(UTC),
        )
        _suspect = await _seed_sale(
            db_session,
            business_id,
            "suspect-flagged",
            is_time_suspect=True,
            occurred_at=datetime.now(UTC) - timedelta(days=90),
        )

        headers = _auth_header(business_id=business_id)
        resp = await client.get(LIST_URL.format(business_id=business_id), headers=headers)
        assert resp.status_code == 200
        data = resp.json()

        items_by_id = {item["client_sale_id"]: item for item in data["items"]}
        assert items_by_id["suspect-normal"]["is_time_suspect"] is False
        assert items_by_id["suspect-flagged"]["is_time_suspect"] is True

    async def test_pagination_limits_results(
        self,
        client: AsyncClient,
        db_session: AsyncSession,
    ) -> None:
        business_id = uuid4()
        for i in range(5):
            await _seed_sale(
                db_session,
                business_id,
                f"page-{i}",
                occurred_at=datetime.now(UTC) - timedelta(minutes=i),
            )

        headers = _auth_header(business_id=business_id)

        resp = await client.get(
            LIST_URL.format(business_id=business_id),
            headers=headers,
            params={"limit": 2, "offset": 0},
        )
        assert resp.status_code == 200
        data = resp.json()
        assert len(data["items"]) == 2
        assert data["total"] == 5

    async def test_default_sort_is_occurred_at_desc(
        self,
        client: AsyncClient,
        db_session: AsyncSession,
    ) -> None:
        business_id = uuid4()
        now = datetime.now(UTC)
        _s_old = await _seed_sale(
            db_session,
            business_id,
            "sort-old",
            occurred_at=now - timedelta(days=5),
        )
        _s_new = await _seed_sale(
            db_session,
            business_id,
            "sort-new",
            occurred_at=now,
        )

        headers = _auth_header(business_id=business_id)
        resp = await client.get(LIST_URL.format(business_id=business_id), headers=headers)
        assert resp.status_code == 200
        items = resp.json()["items"]
        assert items[0]["client_sale_id"] == "sort-new"
        assert items[1]["client_sale_id"] == "sort-old"

    async def test_without_pos_view_returns_403(
        self,
        client: AsyncClient,
    ) -> None:
        business_id = uuid4()
        headers = _auth_header(
            business_id=business_id,
            permissions=["pos.write"],
        )
        resp = await client.get(
            LIST_URL.format(business_id=business_id),
            headers=headers,
        )
        assert resp.status_code == 403

    async def test_cross_business_rejected(
        self,
        client: AsyncClient,
        db_session: AsyncSession,
    ) -> None:
        business_id = uuid4()
        other = uuid4()
        await _seed_sale(db_session, business_id, "cross-list")

        headers = _auth_header(business_id=other, permissions=["pos.view"])
        resp = await client.get(
            LIST_URL.format(business_id=other),
            headers=headers,
        )
        # Token is scoped to *other*, path is for *other* — context binding
        # passes, but no sales exist for *other* so total=0
        assert resp.status_code == 200
        assert resp.json()["total"] == 0


class TestSalesSummaryEndpoint:
    """GET /businesses/{business_id}/sales/summary"""

    async def test_summary_all_completed(
        self,
        client: AsyncClient,
        db_session: AsyncSession,
    ) -> None:
        business_id = uuid4()
        await _seed_sale(db_session, business_id, "sum-c1", total="100.00")
        await _seed_sale(db_session, business_id, "sum-c2", total="200.00")

        headers = _auth_header(business_id=business_id)
        resp = await client.get(SUMMARY_URL.format(business_id=business_id), headers=headers)
        assert resp.status_code == 200
        data = resp.json()
        assert data["total_count"] == 2
        assert data["total_revenue"] == "300.00"
        assert data["voided_count"] == 0
        assert data["refunded_count"] == 0

    async def test_summary_excludes_voided_refunded_from_revenue(
        self,
        client: AsyncClient,
        db_session: AsyncSession,
    ) -> None:
        business_id = uuid4()
        await _seed_sale(db_session, business_id, "sum-rev-completed", total="150.00")
        await _seed_sale(
            db_session,
            business_id,
            "sum-rev-voided",
            total="50.00",
            status="voided",
            voided_at=datetime.now(UTC),
            void_or_refund_reason="error",
        )
        await _seed_sale(
            db_session,
            business_id,
            "sum-rev-refunded",
            total="75.00",
            status="refunded",
            refunded_at=datetime.now(UTC),
            void_or_refund_reason="return",
        )

        headers = _auth_header(business_id=business_id)
        resp = await client.get(SUMMARY_URL.format(business_id=business_id), headers=headers)
        assert resp.status_code == 200
        data = resp.json()
        assert data["total_count"] == 3
        assert data["total_revenue"] == "150.00"
        assert data["voided_count"] == 1
        assert data["refunded_count"] == 1

    async def test_summary_payment_method_breakdown(
        self,
        client: AsyncClient,
        db_session: AsyncSession,
    ) -> None:
        business_id = uuid4()
        await _seed_sale(db_session, business_id, "bd-cash-1", payment_method="cash", total="50.00")
        await _seed_sale(db_session, business_id, "bd-cash-2", payment_method="cash", total="25.00")
        await _seed_sale(
            db_session, business_id, "bd-card-1", payment_method="card", total="100.00"
        )
        await _seed_sale(
            db_session, business_id, "bd-mmoney-1", payment_method="mobile_money", total="200.00"
        )

        headers = _auth_header(business_id=business_id)
        resp = await client.get(SUMMARY_URL.format(business_id=business_id), headers=headers)
        assert resp.status_code == 200
        data = resp.json()

        breakdown = {b["payment_method"]: b for b in data["payment_method_breakdown"]}
        assert len(breakdown) == 3
        assert breakdown["cash"]["count"] == 2
        assert breakdown["cash"]["revenue"] == "75.00"
        assert breakdown["card"]["count"] == 1
        assert breakdown["card"]["revenue"] == "100.00"
        assert breakdown["mobile_money"]["count"] == 1
        assert breakdown["mobile_money"]["revenue"] == "200.00"

    async def test_summary_breakdown_excludes_voided_revenue(
        self,
        client: AsyncClient,
        db_session: AsyncSession,
    ) -> None:
        business_id = uuid4()
        await _seed_sale(
            db_session, business_id, "bdv-cash-completed", payment_method="cash", total="80.00"
        )
        await _seed_sale(
            db_session,
            business_id,
            "bdv-cash-voided",
            payment_method="cash",
            total="20.00",
            status="voided",
            voided_at=datetime.now(UTC),
            void_or_refund_reason="oops",
        )

        headers = _auth_header(business_id=business_id)
        resp = await client.get(SUMMARY_URL.format(business_id=business_id), headers=headers)
        assert resp.status_code == 200
        data = resp.json()

        assert data["total_revenue"] == "80.00"
        cash = next(b for b in data["payment_method_breakdown"] if b["payment_method"] == "cash")
        assert cash["count"] == 2
        assert cash["revenue"] == "80.00"

    async def test_summary_date_filter(
        self,
        client: AsyncClient,
        db_session: AsyncSession,
    ) -> None:
        business_id = uuid4()
        now = datetime.now(UTC)
        await _seed_sale(
            db_session,
            business_id,
            "sum-dt-old",
            total="10.00",
            occurred_at=now - timedelta(days=10),
        )
        await _seed_sale(
            db_session,
            business_id,
            "sum-dt-recent",
            total="20.00",
            occurred_at=now - timedelta(hours=1),
        )

        headers = _auth_header(business_id=business_id)
        resp = await client.get(
            SUMMARY_URL.format(business_id=business_id),
            headers=headers,
            params={"from_date": (now - timedelta(days=2)).isoformat()},
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["total_count"] == 1
        assert data["total_revenue"] == "20.00"

    async def test_summary_without_pos_view_returns_403(
        self,
        client: AsyncClient,
    ) -> None:
        business_id = uuid4()
        headers = _auth_header(
            business_id=business_id,
            permissions=["pos.write"],
        )
        resp = await client.get(
            SUMMARY_URL.format(business_id=business_id),
            headers=headers,
        )
        assert resp.status_code == 403

    async def test_summary_cross_business_isolation(
        self,
        client: AsyncClient,
        db_session: AsyncSession,
    ) -> None:
        business_id = uuid4()
        other = uuid4()
        await _seed_sale(db_session, business_id, "cross-sum", total="999.00")

        headers = _auth_header(business_id=other, permissions=["pos.view"])
        resp = await client.get(
            SUMMARY_URL.format(business_id=other),
            headers=headers,
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["total_count"] == 0
        assert data["total_revenue"] == "0"
        assert data["payment_method_breakdown"] == []
