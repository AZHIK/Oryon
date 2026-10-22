"""API tests for other-incomes endpoints.

Condensed mirror of ``test_other_expenses.py`` — the sync/list/summary/
mutation machinery is identical (shared via ``finance_service.py``), so this
focuses on what's actually different: the ``source`` field, income
categories, and the separate ``finance.incomes.*`` permission codes.
"""

from __future__ import annotations

from datetime import UTC, datetime
from decimal import Decimal
from uuid import UUID, uuid4

from httpx import AsyncClient

from tests.test_token_verification import _build_token

SYNC_URL = "/api/v1/businesses/{business_id}/other-incomes/sync"
LIST_URL = "/api/v1/businesses/{business_id}/other-incomes"
SUMMARY_URL = "/api/v1/businesses/{business_id}/other-incomes/summary"
DETAIL_URL = "/api/v1/businesses/{business_id}/other-incomes/{income_id}"

ALL_INCOME_PERMS = [
    "finance.view",
    "finance.incomes.create",
    "finance.incomes.update",
    "finance.incomes.delete",
]


def _auth_header(
    *, business_id: UUID | None = None, permissions: list[str] | None = None
) -> dict[str, str]:
    biz_id = business_id or uuid4()
    token = _build_token(
        extra_claims={
            "permissions": permissions or ALL_INCOME_PERMS,
            "active_business_id": str(biz_id),
        },
    )
    return {"Authorization": f"Bearer {token}"}


def _income_input(**overrides: object) -> dict:
    return {
        "client_income_id": overrides.get("client_income_id", str(uuid4())),
        "store_id": str(overrides.get("store_id", uuid4())),
        "category": overrides.get("category", "catering"),
        "amount": str(overrides.get("amount", Decimal("300.00"))),
        "description": overrides.get("description", "Wedding catering deposit"),
        "payment_method": overrides.get("payment_method", "mobile_money"),
        "source": overrides.get("source", "Jane Doe"),
        "occurred_at": datetime.now(UTC).isoformat(),
    }


class TestSyncAndMutations:
    async def test_sync_new_income_returns_created_with_source(self, client: AsyncClient) -> None:
        business_id = uuid4()
        headers = _auth_header(business_id=business_id)
        resp = await client.post(
            SYNC_URL.format(business_id=business_id),
            json={"incomes": [_income_input()]},
            headers=headers,
        )
        assert resp.status_code == 200
        assert resp.json()["results"][0]["status"] == "created"

        list_resp = await client.get(LIST_URL.format(business_id=business_id), headers=headers)
        item = list_resp.json()["items"][0]
        assert item["source"] == "Jane Doe"
        assert item["category"] == "catering"

    async def test_summary_route_resolves_not_as_uuid(self, client: AsyncClient) -> None:
        business_id = uuid4()
        headers = _auth_header(business_id=business_id)
        resp = await client.get(SUMMARY_URL.format(business_id=business_id), headers=headers)
        assert resp.status_code == 200
        assert resp.json()["total_count"] == 0

    async def test_incomes_permission_is_separate_from_expenses(self, client: AsyncClient) -> None:
        """A token with only finance.expenses.* must NOT be able to sync incomes."""
        business_id = uuid4()
        headers = _auth_header(
            business_id=business_id,
            permissions=["finance.view", "finance.expenses.create"],
        )
        resp = await client.post(
            SYNC_URL.format(business_id=business_id),
            json={"incomes": [_income_input()]},
            headers=headers,
        )
        assert resp.status_code == 403

    async def test_update_and_delete(self, client: AsyncClient) -> None:
        business_id = uuid4()
        headers = _auth_header(business_id=business_id)
        await client.post(
            SYNC_URL.format(business_id=business_id),
            json={"incomes": [_income_input()]},
            headers=headers,
        )
        list_resp = await client.get(LIST_URL.format(business_id=business_id), headers=headers)
        income_id = list_resp.json()["items"][0]["id"]

        patch_resp = await client.patch(
            DETAIL_URL.format(business_id=business_id, income_id=income_id),
            json={"source": "Updated Source"},
            headers=headers,
        )
        assert patch_resp.status_code == 200
        assert patch_resp.json()["source"] == "Updated Source"

        del_resp = await client.delete(
            DETAIL_URL.format(business_id=business_id, income_id=income_id),
            headers=headers,
        )
        assert del_resp.status_code == 204

        list_resp2 = await client.get(LIST_URL.format(business_id=business_id), headers=headers)
        assert list_resp2.json()["total"] == 0
