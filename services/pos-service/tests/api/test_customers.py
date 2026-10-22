"""API tests for customers endpoints — sync, list, mutations, aggregates, permissions."""

from __future__ import annotations

from datetime import UTC, datetime
from decimal import Decimal
from uuid import UUID, uuid4

from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession
from sqlmodel import select

from app.models.customers import Customer
from tests.test_token_verification import _build_token

SYNC_URL = "/api/v1/businesses/{business_id}/customers/sync"
LIST_URL = "/api/v1/businesses/{business_id}/customers"
DETAIL_URL = "/api/v1/businesses/{business_id}/customers/{customer_id}"
SALE_SYNC_URL = "/api/v1/businesses/{business_id}/sales/sync"
VOID_REFUND_URL = "/api/v1/businesses/{business_id}/sales/{sale_id}/void-or-refund"

ALL_CUSTOMER_PERMS = [
    "customers.view",
    "customers.create",
    "customers.update",
    "customers.delete",
]
ALL_PERMS = ALL_CUSTOMER_PERMS + ["pos.write", "pos.view", "pos.refund"]


def _auth_header(
    *, business_id: UUID | None = None, permissions: list[str] | None = None
) -> dict[str, str]:
    biz_id = business_id or uuid4()
    token = _build_token(
        extra_claims={
            "permissions": permissions or ALL_PERMS,
            "active_business_id": str(biz_id),
        },
    )
    return {"Authorization": f"Bearer {token}"}


def _customer_input(**overrides: object) -> dict:
    return {
        "id": str(overrides.get("id", uuid4())),
        "name": overrides.get("name", "Jane Doe"),
        "phone": overrides.get("phone", "+1-555-0100"),
        "email": overrides.get("email", "jane@example.com"),
        "joined_at": overrides.get("joined_at", datetime.now(UTC)).isoformat()
        if isinstance(overrides.get("joined_at", datetime.now(UTC)), datetime)
        else overrides["joined_at"],
    }


def _sale_input(**overrides: object) -> dict:
    sale = {
        "client_sale_id": overrides.get("client_sale_id", str(uuid4())),
        "status": overrides.get("status", "completed"),
        "store_id": str(overrides.get("store_id", uuid4())),
        "line_items": overrides.get(
            "line_items",
            [{"item_id": str(uuid4()), "quantity": "1", "unit_price": "10.00"}],
        ),
        "discount_amount": str(overrides.get("discount_amount", Decimal("0"))),
        "payment_method": overrides.get("payment_method", "cash"),
        "occurred_at": overrides.get("occurred_at", datetime.now(UTC)).isoformat()
        if isinstance(overrides.get("occurred_at", datetime.now(UTC)), datetime)
        else overrides["occurred_at"],
    }
    if "customer_id" in overrides:
        sale["customer_id"] = overrides["customer_id"]
    if "void_or_refund_reason" in overrides:
        sale["void_or_refund_reason"] = overrides["void_or_refund_reason"]
    return sale


class TestSyncEndpoint:
    async def test_sync_new_customer_returns_created_with_client_id_as_pk(
        self,
        client: AsyncClient,
        db_session: AsyncSession,
    ) -> None:
        business_id = uuid4()
        headers = _auth_header(business_id=business_id)
        customer_id = uuid4()
        customer_input = _customer_input(id=customer_id, name="Jane Doe")

        resp = await client.post(
            SYNC_URL.format(business_id=business_id),
            json={"customers": [customer_input]},
            headers=headers,
        )
        assert resp.status_code == 200
        body = resp.json()
        assert body["results"][0]["status"] == "created"
        assert body["results"][0]["client_customer_id"] == str(customer_id)

        customer = (await db_session.exec(select(Customer).where(Customer.id == customer_id))).one()
        assert customer.name == "Jane Doe"
        assert customer.business_id == business_id

    async def test_sync_twice_same_business_returns_duplicate(
        self,
        client: AsyncClient,
        db_session: AsyncSession,
    ) -> None:
        business_id = uuid4()
        headers = _auth_header(business_id=business_id)
        customer_id = uuid4()
        customer_input = _customer_input(id=customer_id)

        resp1 = await client.post(
            SYNC_URL.format(business_id=business_id),
            json={"customers": [customer_input]},
            headers=headers,
        )
        assert resp1.json()["results"][0]["status"] == "created"

        resp2 = await client.post(
            SYNC_URL.format(business_id=business_id),
            json={"customers": [customer_input]},
            headers=headers,
        )
        assert resp2.json()["results"][0]["status"] == "duplicate"

        rows = (await db_session.exec(select(Customer).where(Customer.id == customer_id))).all()
        assert len(rows) == 1

    async def test_id_owned_by_another_business_fails_not_duplicate(
        self,
        client: AsyncClient,
    ) -> None:
        business_a = uuid4()
        business_b = uuid4()
        customer_id = uuid4()

        await client.post(
            SYNC_URL.format(business_id=business_a),
            json={"customers": [_customer_input(id=customer_id)]},
            headers=_auth_header(business_id=business_a),
        )

        resp = await client.post(
            SYNC_URL.format(business_id=business_b),
            json={"customers": [_customer_input(id=customer_id)]},
            headers=_auth_header(business_id=business_b),
        )
        result = resp.json()["results"][0]
        assert result["status"] == "failed"
        assert "already in use" in result["reason"]

    async def test_mixed_batch_returns_200_with_per_entry_results(
        self,
        client: AsyncClient,
    ) -> None:
        business_id = uuid4()
        headers = _auth_header(business_id=business_id)
        shared_id = uuid4()

        # Pre-create one customer under a different business so the second
        # batch item collides.
        other_business = uuid4()
        await client.post(
            SYNC_URL.format(business_id=other_business),
            json={"customers": [_customer_input(id=shared_id)]},
            headers=_auth_header(business_id=other_business),
        )

        good = _customer_input(id=uuid4(), name="Good Customer")
        bad = _customer_input(id=shared_id, name="Colliding Customer")

        resp = await client.post(
            SYNC_URL.format(business_id=business_id),
            json={"customers": [good, bad]},
            headers=headers,
        )
        assert resp.status_code == 200
        results = {r["client_customer_id"]: r["status"] for r in resp.json()["results"]}
        assert results[good["id"]] == "created"
        assert results[bad["id"]] == "failed"

    async def test_sync_without_permission_returns_403(self, client: AsyncClient) -> None:
        business_id = uuid4()
        headers = _auth_header(business_id=business_id, permissions=["customers.view"])
        resp = await client.post(
            SYNC_URL.format(business_id=business_id),
            json={"customers": [_customer_input()]},
            headers=headers,
        )
        assert resp.status_code == 403

    async def test_naive_joined_at_is_normalized_not_500(self, client: AsyncClient) -> None:
        business_id = uuid4()
        headers = _auth_header(business_id=business_id)
        customer_input = _customer_input(joined_at="2026-01-01T00:00:00")
        resp = await client.post(
            SYNC_URL.format(business_id=business_id),
            json={"customers": [customer_input]},
            headers=headers,
        )
        assert resp.status_code == 200
        assert resp.json()["results"][0]["status"] == "created"


class TestListEndpoint:
    async def test_pagination_and_search(self, client: AsyncClient) -> None:
        business_id = uuid4()
        headers = _auth_header(business_id=business_id)
        for name, phone in [("Alice Smith", "+1-555-0001"), ("Bob Jones", "+1-555-0002")]:
            await client.post(
                SYNC_URL.format(business_id=business_id),
                json={"customers": [_customer_input(name=name, phone=phone)]},
                headers=headers,
            )

        list_resp = await client.get(LIST_URL.format(business_id=business_id), headers=headers)
        assert list_resp.status_code == 200
        assert list_resp.json()["total"] == 2

        search_resp = await client.get(
            LIST_URL.format(business_id=business_id),
            params={"search": "alice"},
            headers=headers,
        )
        assert search_resp.json()["total"] == 1
        assert search_resp.json()["items"][0]["name"] == "Alice Smith"

        phone_search = await client.get(
            LIST_URL.format(business_id=business_id),
            params={"search": "0002"},
            headers=headers,
        )
        assert phone_search.json()["total"] == 1
        assert phone_search.json()["items"][0]["name"] == "Bob Jones"

    async def test_soft_deleted_excluded_by_default(self, client: AsyncClient) -> None:
        business_id = uuid4()
        headers = _auth_header(business_id=business_id)
        customer_id = uuid4()
        await client.post(
            SYNC_URL.format(business_id=business_id),
            json={"customers": [_customer_input(id=customer_id)]},
            headers=headers,
        )
        await client.delete(
            DETAIL_URL.format(business_id=business_id, customer_id=customer_id),
            headers=headers,
        )

        default_list = await client.get(LIST_URL.format(business_id=business_id), headers=headers)
        assert default_list.json()["total"] == 0

        incl_list = await client.get(
            LIST_URL.format(business_id=business_id),
            params={"include_deleted": "true"},
            headers=headers,
        )
        assert incl_list.json()["total"] == 1

    async def test_another_businesss_customers_never_appear(self, client: AsyncClient) -> None:
        business_a = uuid4()
        business_b = uuid4()
        await client.post(
            SYNC_URL.format(business_id=business_a),
            json={"customers": [_customer_input()]},
            headers=_auth_header(business_id=business_a),
        )
        list_resp = await client.get(
            LIST_URL.format(business_id=business_b),
            headers=_auth_header(business_id=business_b),
        )
        assert list_resp.json()["total"] == 0


class TestAggregates:
    async def test_customer_with_no_sales_reports_zero_totals(self, client: AsyncClient) -> None:
        business_id = uuid4()
        headers = _auth_header(business_id=business_id)
        customer_id = uuid4()
        await client.post(
            SYNC_URL.format(business_id=business_id),
            json={"customers": [_customer_input(id=customer_id)]},
            headers=headers,
        )
        resp = await client.get(
            DETAIL_URL.format(business_id=business_id, customer_id=customer_id),
            headers=headers,
        )
        body = resp.json()
        assert body["total_orders"] == 0
        assert Decimal(body["total_spent"]) == Decimal("0")
        assert body["last_order_at"] is None

    async def test_sync_sale_with_customer_id_links_and_aggregates(
        self,
        client: AsyncClient,
        db_session: AsyncSession,
    ) -> None:
        business_id = uuid4()
        headers = _auth_header(business_id=business_id)
        customer_id = uuid4()
        await client.post(
            SYNC_URL.format(business_id=business_id),
            json={"customers": [_customer_input(id=customer_id)]},
            headers=headers,
        )

        sale_input = _sale_input(customer_id=str(customer_id))
        sale_resp = await client.post(
            SALE_SYNC_URL.format(business_id=business_id),
            json={"sales": [sale_input]},
            headers=headers,
        )
        assert sale_resp.json()["results"][0]["status"] == "created"

        detail_resp = await client.get(
            DETAIL_URL.format(business_id=business_id, customer_id=customer_id),
            headers=headers,
        )
        body = detail_resp.json()
        assert body["total_orders"] == 1
        assert Decimal(body["total_spent"]) == Decimal("10.00")
        assert body["last_order_at"] is not None

    async def test_voided_and_refunded_sales_excluded_from_totals(
        self,
        client: AsyncClient,
    ) -> None:
        business_id = uuid4()
        headers = _auth_header(business_id=business_id)
        customer_id = uuid4()
        await client.post(
            SYNC_URL.format(business_id=business_id),
            json={"customers": [_customer_input(id=customer_id)]},
            headers=headers,
        )

        await client.post(
            SALE_SYNC_URL.format(business_id=business_id),
            json={"sales": [_sale_input(customer_id=str(customer_id), status="completed")]},
            headers=headers,
        )
        await client.post(
            SALE_SYNC_URL.format(business_id=business_id),
            json={
                "sales": [
                    _sale_input(
                        customer_id=str(customer_id),
                        status="voided",
                        void_or_refund_reason="test",
                    )
                ]
            },
            headers=headers,
        )
        await client.post(
            SALE_SYNC_URL.format(business_id=business_id),
            json={
                "sales": [
                    _sale_input(
                        customer_id=str(customer_id),
                        status="refunded",
                        void_or_refund_reason="test",
                    )
                ]
            },
            headers=headers,
        )

        detail_resp = await client.get(
            DETAIL_URL.format(business_id=business_id, customer_id=customer_id),
            headers=headers,
        )
        body = detail_resp.json()
        assert body["total_orders"] == 1
        assert Decimal(body["total_spent"]) == Decimal("10.00")

    async def test_void_after_sync_updates_totals(self, client: AsyncClient) -> None:
        """Proves computed-on-read: voiding a synced sale must self-correct
        the customer's totals on the very next read, with no stored counter."""
        business_id = uuid4()
        headers = _auth_header(business_id=business_id)
        customer_id = uuid4()
        await client.post(
            SYNC_URL.format(business_id=business_id),
            json={"customers": [_customer_input(id=customer_id)]},
            headers=headers,
        )

        client_sale_id = str(uuid4())
        sale_resp = await client.post(
            SALE_SYNC_URL.format(business_id=business_id),
            json={
                "sales": [
                    _sale_input(
                        customer_id=str(customer_id),
                        client_sale_id=client_sale_id,
                    )
                ]
            },
            headers=headers,
        )
        assert sale_resp.json()["results"][0]["status"] == "created"

        before = await client.get(
            DETAIL_URL.format(business_id=business_id, customer_id=customer_id),
            headers=headers,
        )
        assert before.json()["total_orders"] == 1

        list_resp = await client.get(
            f"/api/v1/businesses/{business_id}/sales/by-client-id/{client_sale_id}",
            headers=headers,
        )
        sale_id = list_resp.json()["id"]

        await client.post(
            VOID_REFUND_URL.format(business_id=business_id, sale_id=sale_id),
            json={
                "client_action_id": str(uuid4()),
                "new_status": "voided",
                "reason": "cashier error",
            },
            headers=headers,
        )

        after = await client.get(
            DETAIL_URL.format(business_id=business_id, customer_id=customer_id),
            headers=headers,
        )
        assert after.json()["total_orders"] == 0
        assert Decimal(after.json()["total_spent"]) == Decimal("0")

    async def test_list_and_detail_report_identical_totals(self, client: AsyncClient) -> None:
        business_id = uuid4()
        headers = _auth_header(business_id=business_id)
        customer_id = uuid4()
        await client.post(
            SYNC_URL.format(business_id=business_id),
            json={"customers": [_customer_input(id=customer_id)]},
            headers=headers,
        )
        await client.post(
            SALE_SYNC_URL.format(business_id=business_id),
            json={"sales": [_sale_input(customer_id=str(customer_id))]},
            headers=headers,
        )

        list_resp = await client.get(LIST_URL.format(business_id=business_id), headers=headers)
        detail_resp = await client.get(
            DETAIL_URL.format(business_id=business_id, customer_id=customer_id),
            headers=headers,
        )
        list_item = next(i for i in list_resp.json()["items"] if i["id"] == str(customer_id))
        assert list_item["total_orders"] == detail_resp.json()["total_orders"]
        assert list_item["total_spent"] == detail_resp.json()["total_spent"]


class TestSaleCustomerValidation:
    async def test_unknown_customer_id_fails_not_500(self, client: AsyncClient) -> None:
        business_id = uuid4()
        headers = _auth_header(business_id=business_id)
        resp = await client.post(
            SALE_SYNC_URL.format(business_id=business_id),
            json={"sales": [_sale_input(customer_id=str(uuid4()))]},
            headers=headers,
        )
        assert resp.status_code == 200
        result = resp.json()["results"][0]
        assert result["status"] == "failed"
        assert "customer_id" in result["reason"]

    async def test_another_businesss_customer_id_fails(self, client: AsyncClient) -> None:
        other_business = uuid4()
        customer_id = uuid4()
        await client.post(
            SYNC_URL.format(business_id=other_business),
            json={"customers": [_customer_input(id=customer_id)]},
            headers=_auth_header(business_id=other_business),
        )

        business_id = uuid4()
        resp = await client.post(
            SALE_SYNC_URL.format(business_id=business_id),
            json={"sales": [_sale_input(customer_id=str(customer_id))]},
            headers=_auth_header(business_id=business_id),
        )
        assert resp.json()["results"][0]["status"] == "failed"

    async def test_deleted_customer_id_fails(self, client: AsyncClient) -> None:
        business_id = uuid4()
        headers = _auth_header(business_id=business_id)
        customer_id = uuid4()
        await client.post(
            SYNC_URL.format(business_id=business_id),
            json={"customers": [_customer_input(id=customer_id)]},
            headers=headers,
        )
        await client.delete(
            DETAIL_URL.format(business_id=business_id, customer_id=customer_id),
            headers=headers,
        )

        resp = await client.post(
            SALE_SYNC_URL.format(business_id=business_id),
            json={"sales": [_sale_input(customer_id=str(customer_id))]},
            headers=headers,
        )
        assert resp.json()["results"][0]["status"] == "failed"

    async def test_null_customer_id_still_creates(self, client: AsyncClient) -> None:
        business_id = uuid4()
        headers = _auth_header(business_id=business_id)
        resp = await client.post(
            SALE_SYNC_URL.format(business_id=business_id),
            json={"sales": [_sale_input()]},
            headers=headers,
        )
        assert resp.json()["results"][0]["status"] == "created"

    async def test_sale_synced_before_its_customer_then_retried_succeeds(
        self,
        client: AsyncClient,
    ) -> None:
        """A sale referencing a not-yet-synced customer fails, then the
        exact same batch succeeds once the customer exists — proving the
        client's retry-after-customer-syncs recovery path works."""
        business_id = uuid4()
        headers = _auth_header(business_id=business_id)
        customer_id = uuid4()
        sale_input = _sale_input(customer_id=str(customer_id))

        first = await client.post(
            SALE_SYNC_URL.format(business_id=business_id),
            json={"sales": [sale_input]},
            headers=headers,
        )
        assert first.json()["results"][0]["status"] == "failed"

        await client.post(
            SYNC_URL.format(business_id=business_id),
            json={"customers": [_customer_input(id=customer_id)]},
            headers=headers,
        )

        retry = await client.post(
            SALE_SYNC_URL.format(business_id=business_id),
            json={"sales": [sale_input]},
            headers=headers,
        )
        assert retry.json()["results"][0]["status"] == "created"


class TestMutations:
    async def _create(self, client: AsyncClient, business_id: UUID, headers: dict) -> str:
        customer_id = uuid4()
        await client.post(
            SYNC_URL.format(business_id=business_id),
            json={"customers": [_customer_input(id=customer_id)]},
            headers=headers,
        )
        return str(customer_id)

    async def test_patch_updates_fields(self, client: AsyncClient) -> None:
        business_id = uuid4()
        headers = _auth_header(business_id=business_id)
        customer_id = await self._create(client, business_id, headers)

        resp = await client.patch(
            DETAIL_URL.format(business_id=business_id, customer_id=customer_id),
            json={"name": "Updated Name", "phone": "+1-555-9999"},
            headers=headers,
        )
        assert resp.status_code == 200
        body = resp.json()
        assert body["name"] == "Updated Name"
        assert body["phone"] == "+1-555-9999"

    async def test_patch_empty_body_rejected(self, client: AsyncClient) -> None:
        business_id = uuid4()
        headers = _auth_header(business_id=business_id)
        customer_id = await self._create(client, business_id, headers)

        resp = await client.patch(
            DETAIL_URL.format(business_id=business_id, customer_id=customer_id),
            json={},
            headers=headers,
        )
        assert resp.status_code == 422

    async def test_patch_deleted_customer_returns_409(self, client: AsyncClient) -> None:
        business_id = uuid4()
        headers = _auth_header(business_id=business_id)
        customer_id = await self._create(client, business_id, headers)

        await client.delete(
            DETAIL_URL.format(business_id=business_id, customer_id=customer_id),
            headers=headers,
        )
        resp = await client.patch(
            DETAIL_URL.format(business_id=business_id, customer_id=customer_id),
            json={"name": "New Name"},
            headers=headers,
        )
        assert resp.status_code == 409

    async def test_patch_unknown_returns_404(self, client: AsyncClient) -> None:
        business_id = uuid4()
        headers = _auth_header(business_id=business_id)
        resp = await client.patch(
            DETAIL_URL.format(business_id=business_id, customer_id=uuid4()),
            json={"name": "New Name"},
            headers=headers,
        )
        assert resp.status_code == 404

    async def test_delete_is_idempotent(self, client: AsyncClient) -> None:
        business_id = uuid4()
        headers = _auth_header(business_id=business_id)
        customer_id = await self._create(client, business_id, headers)

        first = await client.delete(
            DETAIL_URL.format(business_id=business_id, customer_id=customer_id),
            headers=headers,
        )
        second = await client.delete(
            DETAIL_URL.format(business_id=business_id, customer_id=customer_id),
            headers=headers,
        )
        assert first.status_code == 204
        assert second.status_code == 204

    async def test_delete_preserves_sale_attribution(self, client: AsyncClient) -> None:
        business_id = uuid4()
        headers = _auth_header(business_id=business_id)
        customer_id = await self._create(client, business_id, headers)

        client_sale_id = str(uuid4())
        await client.post(
            SALE_SYNC_URL.format(business_id=business_id),
            json={"sales": [_sale_input(customer_id=customer_id, client_sale_id=client_sale_id)]},
            headers=headers,
        )

        await client.delete(
            DETAIL_URL.format(business_id=business_id, customer_id=customer_id),
            headers=headers,
        )

        sale_resp = await client.get(
            f"/api/v1/businesses/{business_id}/sales/by-client-id/{client_sale_id}",
            headers=headers,
        )
        assert sale_resp.json()["customer_id"] == customer_id


class TestPermissions:
    async def test_each_route_403s_without_its_code(self, client: AsyncClient) -> None:
        business_id = uuid4()
        # `permissions or ALL_PERMS` in `_auth_header` treats `[]` as "no
        # override" (falsy), so an unrelated code is used instead of an
        # empty list to actually exercise the missing-permission path.
        no_perms_headers = _auth_header(
            business_id=business_id,
            permissions=["reports.view"],
        )

        sync_resp = await client.post(
            SYNC_URL.format(business_id=business_id),
            json={"customers": [_customer_input()]},
            headers=no_perms_headers,
        )
        assert sync_resp.status_code == 403

        list_resp = await client.get(
            LIST_URL.format(business_id=business_id), headers=no_perms_headers
        )
        assert list_resp.status_code == 403

        detail_resp = await client.get(
            DETAIL_URL.format(business_id=business_id, customer_id=uuid4()),
            headers=no_perms_headers,
        )
        assert detail_resp.status_code == 403

        patch_resp = await client.patch(
            DETAIL_URL.format(business_id=business_id, customer_id=uuid4()),
            json={"name": "x"},
            headers=no_perms_headers,
        )
        assert patch_resp.status_code == 403

        delete_resp = await client.delete(
            DETAIL_URL.format(business_id=business_id, customer_id=uuid4()),
            headers=no_perms_headers,
        )
        assert delete_resp.status_code == 403

    async def test_business_id_mismatch_returns_403(self, client: AsyncClient) -> None:
        token_business = uuid4()
        path_business = uuid4()
        headers = _auth_header(business_id=token_business)
        resp = await client.get(LIST_URL.format(business_id=path_business), headers=headers)
        assert resp.status_code == 403


class TestRouteOrdering:
    async def test_list_route_resolves_not_as_uuid(self, client: AsyncClient) -> None:
        business_id = uuid4()
        headers = _auth_header(business_id=business_id)
        resp = await client.get(LIST_URL.format(business_id=business_id), headers=headers)
        assert resp.status_code == 200

    async def test_unknown_uuid_detail_returns_404_not_422(self, client: AsyncClient) -> None:
        business_id = uuid4()
        headers = _auth_header(business_id=business_id)
        resp = await client.get(
            DETAIL_URL.format(business_id=business_id, customer_id=uuid4()),
            headers=headers,
        )
        assert resp.status_code == 404
