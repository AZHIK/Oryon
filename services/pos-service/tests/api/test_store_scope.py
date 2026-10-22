"""Store-scope enforcement: store-staff tokens are pinned to their store.

Tokens WITHOUT ``active_store_id`` (business staff, owners) pass through
untouched — every test here uses a pinned token unless stated otherwise.
"""

from __future__ import annotations

from datetime import UTC, datetime
from uuid import UUID, uuid4

from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from tests.test_token_verification import _build_token


def _store_header(
    *,
    business_id: UUID,
    store_id: UUID,
    permissions: list[str] | None = None,
) -> dict[str, str]:
    token = _build_token(
        extra_claims={
            "permissions": permissions
            or ["pos.write", "pos.view", "pos.refund", "finance.view"],
            "active_business_id": str(business_id),
            "active_store_id": str(store_id),
            "user_category": "business_store_staff",
        },
    )
    return {"Authorization": f"Bearer {token}"}


def _sale_payload(store_id: UUID, **overrides: object) -> dict:
    return {
        "client_sale_id": str(overrides.get("client_sale_id", uuid4())),
        "status": "completed",
        "store_id": str(store_id),
        "line_items": [
            {"item_id": str(uuid4()), "quantity": "1", "unit_price": "10.00"}
        ],
        "discount_amount": "0",
        "payment_method": "cash",
        "occurred_at": datetime.now(UTC).isoformat(),
    }


class TestSalesScope:
    async def test_sync_foreign_store_rejected(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        biz, own, other = uuid4(), uuid4(), uuid4()
        headers = _store_header(business_id=biz, store_id=own)

        resp = await client.post(
            f"/api/v1/businesses/{biz}/sales/sync",
            json={"sales": [_sale_payload(other)]},
            headers=headers,
        )
        assert resp.status_code == 403

    async def test_sync_own_store_accepted(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        biz, own = uuid4(), uuid4()
        headers = _store_header(business_id=biz, store_id=own)

        resp = await client.post(
            f"/api/v1/businesses/{biz}/sales/sync",
            json={"sales": [_sale_payload(own)]},
            headers=headers,
        )
        assert resp.status_code == 200
        assert resp.json()["results"][0]["status"] == "created"

    async def test_list_unfiltered_pinned_to_own_store(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        biz, own, other = uuid4(), uuid4(), uuid4()
        owner_headers = _store_header(
            business_id=biz,
            store_id=own,
            permissions=["pos.write", "pos.view"],
        )
        # Seed one sale per store via an unpinned (business) token.
        biz_token = _build_token(
            extra_claims={
                "permissions": ["pos.write", "pos.view"],
                "active_business_id": str(biz),
            },
        )
        biz_headers = {"Authorization": f"Bearer {biz_token}"}
        for store in (own, other):
            resp = await client.post(
                f"/api/v1/businesses/{biz}/sales/sync",
                json={"sales": [_sale_payload(store)]},
                headers=biz_headers,
            )
            assert resp.status_code == 200

        resp = await client.get(
            f"/api/v1/businesses/{biz}/sales",
            headers=owner_headers,
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["total"] == 1
        assert data["items"][0]["store_id"] == str(own)

    async def test_list_foreign_store_rejected(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        biz, own, other = uuid4(), uuid4(), uuid4()
        headers = _store_header(business_id=biz, store_id=own)

        resp = await client.get(
            f"/api/v1/businesses/{biz}/sales?store_id={other}",
            headers=headers,
        )
        assert resp.status_code == 403

    async def test_void_foreign_sale_rejected(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        from app.models.pos import Sale

        biz, own, other = uuid4(), uuid4(), uuid4()
        biz_token = _build_token(
            extra_claims={
                "permissions": ["pos.write", "pos.view", "pos.refund"],
                "active_business_id": str(biz),
            },
        )
        biz_headers = {"Authorization": f"Bearer {biz_token}"}
        sync = await client.post(
            f"/api/v1/businesses/{biz}/sales/sync",
            json={"sales": [_sale_payload(other)]},
            headers=biz_headers,
        )
        assert sync.status_code == 200

        from sqlmodel import select

        sale = (
            await db_session.exec(select(Sale).where(Sale.business_id == biz))
        ).one()

        headers = _store_header(business_id=biz, store_id=own)
        resp = await client.post(
            f"/api/v1/businesses/{biz}/sales/{sale.id}/void-or-refund",
            json={
                "client_action_id": str(uuid4()),
                "new_status": "voided",
                "reason": "test",
            },
            headers=headers,
        )
        assert resp.status_code == 403

    async def test_unpinned_caller_unaffected(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        biz, own, other = uuid4(), uuid4(), uuid4()
        biz_token = _build_token(
            extra_claims={
                "permissions": ["pos.write", "pos.view"],
                "active_business_id": str(biz),
            },
        )
        headers = {"Authorization": f"Bearer {biz_token}"}
        for store in (own, other):
            resp = await client.post(
                f"/api/v1/businesses/{biz}/sales/sync",
                json={"sales": [_sale_payload(store)]},
                headers=headers,
            )
            assert resp.status_code == 200

        resp = await client.get(
            f"/api/v1/businesses/{biz}/sales",
            headers=headers,
        )
        assert resp.status_code == 200
        assert resp.json()["total"] == 2


class TestFinanceScope:
    async def test_expense_summary_foreign_store_rejected(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        biz, own, other = uuid4(), uuid4(), uuid4()
        headers = _store_header(business_id=biz, store_id=own)

        resp = await client.get(
            f"/api/v1/businesses/{biz}/other-expenses/summary?store_id={other}",
            headers=headers,
        )
        assert resp.status_code == 403

    async def test_expense_sync_foreign_store_rejected(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        biz, own, other = uuid4(), uuid4(), uuid4()
        headers = _store_header(
            business_id=biz,
            store_id=own,
            permissions=["finance.expenses.create"],
        )

        resp = await client.post(
            f"/api/v1/businesses/{biz}/other-expenses/sync",
            json={
                "expenses": [
                    {
                        "client_expense_id": str(uuid4()),
                        "store_id": str(other),
                        "category": "rent",
                        "amount": "100.00",
                        "description": "scope probe",
                        "payment_method": "cash",
                        "occurred_at": datetime.now(UTC).isoformat(),
                    }
                ]
            },
            headers=headers,
        )
        assert resp.status_code == 403


class TestReportsScope:
    async def test_daily_takings_foreign_store_rejected(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        biz, own, other = uuid4(), uuid4(), uuid4()
        headers = _store_header(
            business_id=biz, store_id=own, permissions=["reports.view"]
        )

        resp = await client.get(
            f"/api/v1/businesses/{biz}/reports/daily-takings?store_id={other}",
            headers=headers,
        )
        assert resp.status_code == 403

    async def test_daily_takings_unfiltered_pinned_to_own_store(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        biz, own, other = uuid4(), uuid4(), uuid4()
        biz_token = _build_token(
            extra_claims={
                "permissions": ["pos.write", "pos.view", "reports.view"],
                "active_business_id": str(biz),
            },
        )
        biz_headers = {"Authorization": f"Bearer {biz_token}"}
        for store in (own, other):
            resp = await client.post(
                f"/api/v1/businesses/{biz}/sales/sync",
                json={"sales": [_sale_payload(store)]},
                headers=biz_headers,
            )
            assert resp.status_code == 200

        headers = _store_header(
            business_id=biz, store_id=own, permissions=["reports.view"]
        )
        resp = await client.get(
            f"/api/v1/businesses/{biz}/reports/daily-takings",
            headers=headers,
        )
        assert resp.status_code == 200
        days = resp.json()["days"]
        assert sum(d["sales_count"] for d in days) == 1
