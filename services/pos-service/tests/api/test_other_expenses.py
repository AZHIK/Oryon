"""API tests for other-expenses endpoints — sync, read, update, delete, permissions."""

from __future__ import annotations

from datetime import UTC, datetime
from decimal import Decimal
from uuid import UUID, uuid4

from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession
from sqlmodel import select

from app.models.finance import OtherExpense
from tests.test_token_verification import _build_token

SYNC_URL = "/api/v1/businesses/{business_id}/other-expenses/sync"
LIST_URL = "/api/v1/businesses/{business_id}/other-expenses"
SUMMARY_URL = "/api/v1/businesses/{business_id}/other-expenses/summary"
DETAIL_URL = "/api/v1/businesses/{business_id}/other-expenses/{expense_id}"

ALL_FINANCE_PERMS = [
    "finance.view",
    "finance.expenses.create",
    "finance.expenses.update",
    "finance.expenses.delete",
]


def _auth_header(
    *, business_id: UUID | None = None, permissions: list[str] | None = None
) -> dict[str, str]:
    biz_id = business_id or uuid4()
    token = _build_token(
        extra_claims={
            "permissions": permissions or ALL_FINANCE_PERMS,
            "active_business_id": str(biz_id),
        },
    )
    return {"Authorization": f"Bearer {token}"}


def _expense_input(**overrides: object) -> dict:
    return {
        "client_expense_id": overrides.get("client_expense_id", str(uuid4())),
        "store_id": str(overrides.get("store_id", uuid4())),
        "category": overrides.get("category", "rent"),
        "amount": str(overrides.get("amount", Decimal("100.00"))),
        "description": overrides.get("description", "Monthly rent"),
        "payment_method": overrides.get("payment_method", "cash"),
        "payee": overrides.get("payee", "Landlord Co."),
        "occurred_at": overrides.get("occurred_at", datetime.now(UTC)).isoformat()
        if isinstance(overrides.get("occurred_at", datetime.now(UTC)), datetime)
        else overrides["occurred_at"],
    }


class TestSyncEndpoint:
    async def test_sync_new_expense_returns_created(
        self,
        client: AsyncClient,
        db_session: AsyncSession,
    ) -> None:
        business_id = uuid4()
        headers = _auth_header(business_id=business_id)
        expense_input = _expense_input()

        resp = await client.post(
            SYNC_URL.format(business_id=business_id),
            json={"expenses": [expense_input]},
            headers=headers,
        )
        assert resp.status_code == 200
        body = resp.json()
        assert body["results"][0]["status"] == "created"

        expense = (
            await db_session.exec(
                select(OtherExpense).where(
                    OtherExpense.client_expense_id == expense_input["client_expense_id"]
                )
            )
        ).one()
        assert expense.amount == Decimal("100.00")
        assert expense.category == "rent"

    async def test_sync_twice_returns_duplicate(
        self,
        client: AsyncClient,
        db_session: AsyncSession,
    ) -> None:
        business_id = uuid4()
        headers = _auth_header(business_id=business_id)
        expense_input = _expense_input(client_expense_id="dup-test")

        resp1 = await client.post(
            SYNC_URL.format(business_id=business_id),
            json={"expenses": [expense_input]},
            headers=headers,
        )
        assert resp1.json()["results"][0]["status"] == "created"

        resp2 = await client.post(
            SYNC_URL.format(business_id=business_id),
            json={"expenses": [expense_input]},
            headers=headers,
        )
        assert resp2.json()["results"][0]["status"] == "duplicate"

        rows = (
            await db_session.exec(
                select(OtherExpense).where(OtherExpense.client_expense_id == "dup-test")
            )
        ).all()
        assert len(rows) == 1

    async def test_mixed_batch_returns_200_with_per_entry_results(
        self,
        client: AsyncClient,
    ) -> None:
        business_id = uuid4()
        headers = _auth_header(business_id=business_id)

        good = _expense_input(client_expense_id="ok-1")
        # Fails a service-layer rule (unknown attachment) rather than schema
        # validation, so it exercises the same request as `good` and proves
        # a batch's failures don't block its successes.
        bad = _expense_input(client_expense_id="bad-1")
        bad["receipt_attachment_id"] = str(uuid4())

        resp = await client.post(
            SYNC_URL.format(business_id=business_id),
            json={"expenses": [good, bad]},
            headers=headers,
        )
        assert resp.status_code == 200
        results = {r["client_entry_id"]: r["status"] for r in resp.json()["results"]}
        assert results["ok-1"] == "created"
        assert results["bad-1"] == "failed"

    async def test_unknown_receipt_attachment_fails_not_errors(
        self,
        client: AsyncClient,
    ) -> None:
        business_id = uuid4()
        headers = _auth_header(business_id=business_id)
        expense_input = _expense_input(client_expense_id="bad-attachment")
        expense_input["receipt_attachment_id"] = str(uuid4())

        resp = await client.post(
            SYNC_URL.format(business_id=business_id),
            json={"expenses": [expense_input]},
            headers=headers,
        )
        assert resp.status_code == 200
        result = resp.json()["results"][0]
        assert result["status"] == "failed"
        assert "receipt_attachment_id" in result["reason"]

    async def test_sync_without_permission_returns_403(self, client: AsyncClient) -> None:
        business_id = uuid4()
        headers = _auth_header(business_id=business_id, permissions=["finance.view"])
        resp = await client.post(
            SYNC_URL.format(business_id=business_id),
            json={"expenses": [_expense_input()]},
            headers=headers,
        )
        assert resp.status_code == 403

    async def test_naive_occurred_at_is_normalized_not_500(self, client: AsyncClient) -> None:
        business_id = uuid4()
        headers = _auth_header(business_id=business_id)
        expense_input = _expense_input(occurred_at="2026-01-01T00:00:00")  # no tz marker
        resp = await client.post(
            SYNC_URL.format(business_id=business_id),
            json={"expenses": [expense_input]},
            headers=headers,
        )
        assert resp.status_code == 200
        assert resp.json()["results"][0]["status"] == "created"


class TestListAndSummary:
    async def test_summary_route_resolves_not_as_uuid(self, client: AsyncClient) -> None:
        """Regression test: /summary must not be swallowed by GET /{expense_id}."""
        business_id = uuid4()
        headers = _auth_header(business_id=business_id)
        resp = await client.get(SUMMARY_URL.format(business_id=business_id), headers=headers)
        assert resp.status_code == 200
        body = resp.json()
        assert body["total_count"] == 0
        assert body["category_breakdown"] == []

    async def test_list_and_summary_reflect_created_entries(self, client: AsyncClient) -> None:
        business_id = uuid4()
        headers = _auth_header(business_id=business_id)
        for cat, amount in [("rent", "100.00"), ("rent", "50.00"), ("utilities", "20.00")]:
            await client.post(
                SYNC_URL.format(business_id=business_id),
                json={"expenses": [_expense_input(category=cat, amount=amount)]},
                headers=headers,
            )

        list_resp = await client.get(LIST_URL.format(business_id=business_id), headers=headers)
        assert list_resp.status_code == 200
        assert list_resp.json()["total"] == 3

        summary_resp = await client.get(
            SUMMARY_URL.format(business_id=business_id), headers=headers
        )
        summary = summary_resp.json()
        assert summary["total_count"] == 3
        assert Decimal(summary["total_amount"]) == Decimal("170.00")
        rent_row = next(r for r in summary["category_breakdown"] if r["category"] == "rent")
        assert Decimal(rent_row["total"]) == Decimal("150.00")

    async def test_soft_deleted_excluded_from_list_and_summary(self, client: AsyncClient) -> None:
        business_id = uuid4()
        headers = _auth_header(business_id=business_id)
        await client.post(
            SYNC_URL.format(business_id=business_id),
            json={"expenses": [_expense_input(client_expense_id="to-delete")]},
            headers=headers,
        )
        list_resp = await client.get(LIST_URL.format(business_id=business_id), headers=headers)
        expense_id = list_resp.json()["items"][0]["id"]

        del_resp = await client.delete(
            DETAIL_URL.format(business_id=business_id, expense_id=expense_id),
            headers=headers,
        )
        assert del_resp.status_code == 204

        list_resp2 = await client.get(LIST_URL.format(business_id=business_id), headers=headers)
        assert list_resp2.json()["total"] == 0

        summary_resp = await client.get(
            SUMMARY_URL.format(business_id=business_id), headers=headers
        )
        assert summary_resp.json()["total_count"] == 0

        list_incl = await client.get(
            LIST_URL.format(business_id=business_id),
            params={"include_deleted": "true"},
            headers=headers,
        )
        assert list_incl.json()["total"] == 1
        assert list_incl.json()["items"][0]["is_deleted"] is True


class TestMutations:
    async def _create(self, client: AsyncClient, business_id: UUID, headers: dict) -> str:
        await client.post(
            SYNC_URL.format(business_id=business_id),
            json={"expenses": [_expense_input()]},
            headers=headers,
        )
        list_resp = await client.get(LIST_URL.format(business_id=business_id), headers=headers)
        return list_resp.json()["items"][0]["id"]

    async def test_patch_updates_fields(self, client: AsyncClient) -> None:
        business_id = uuid4()
        headers = _auth_header(business_id=business_id)
        expense_id = await self._create(client, business_id, headers)

        resp = await client.patch(
            DETAIL_URL.format(business_id=business_id, expense_id=expense_id),
            json={"amount": "250.00", "description": "Updated rent"},
            headers=headers,
        )
        assert resp.status_code == 200
        body = resp.json()
        assert Decimal(body["amount"]) == Decimal("250.00")
        assert body["description"] == "Updated rent"

    async def test_patch_empty_body_rejected(self, client: AsyncClient) -> None:
        business_id = uuid4()
        headers = _auth_header(business_id=business_id)
        expense_id = await self._create(client, business_id, headers)

        resp = await client.patch(
            DETAIL_URL.format(business_id=business_id, expense_id=expense_id),
            json={},
            headers=headers,
        )
        assert resp.status_code == 422

    async def test_patch_deleted_entry_returns_409(self, client: AsyncClient) -> None:
        business_id = uuid4()
        headers = _auth_header(business_id=business_id)
        expense_id = await self._create(client, business_id, headers)

        await client.delete(
            DETAIL_URL.format(business_id=business_id, expense_id=expense_id),
            headers=headers,
        )
        resp = await client.patch(
            DETAIL_URL.format(business_id=business_id, expense_id=expense_id),
            json={"amount": "1.00"},
            headers=headers,
        )
        assert resp.status_code == 409

    async def test_delete_is_idempotent(self, client: AsyncClient) -> None:
        business_id = uuid4()
        headers = _auth_header(business_id=business_id)
        expense_id = await self._create(client, business_id, headers)

        first = await client.delete(
            DETAIL_URL.format(business_id=business_id, expense_id=expense_id),
            headers=headers,
        )
        second = await client.delete(
            DETAIL_URL.format(business_id=business_id, expense_id=expense_id),
            headers=headers,
        )
        assert first.status_code == 204
        assert second.status_code == 204

    async def test_get_cross_business_returns_404(self, client: AsyncClient) -> None:
        business_id = uuid4()
        other_business_id = uuid4()
        headers = _auth_header(business_id=business_id)
        expense_id = await self._create(client, business_id, headers)

        other_headers = _auth_header(business_id=other_business_id)
        resp = await client.get(
            DETAIL_URL.format(business_id=other_business_id, expense_id=expense_id),
            headers=other_headers,
        )
        assert resp.status_code == 404

    async def test_delete_without_permission_returns_403(self, client: AsyncClient) -> None:
        business_id = uuid4()
        headers = _auth_header(business_id=business_id)
        expense_id = await self._create(client, business_id, headers)

        limited_headers = _auth_header(
            business_id=business_id,
            permissions=["finance.view", "finance.expenses.create"],
        )
        resp = await client.delete(
            DETAIL_URL.format(business_id=business_id, expense_id=expense_id),
            headers=limited_headers,
        )
        assert resp.status_code == 403
