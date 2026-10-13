"""API tests for sales endpoints — sync, read, permission enforcement."""

from __future__ import annotations

from datetime import UTC, datetime
from decimal import Decimal
from uuid import UUID, uuid4

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession
from sqlmodel import select

from app.models.pos import Sale, SaleLineItem
from tests.test_token_verification import _build_token


# ═══════════════════════════════════════════════════════════════════════
# Helpers
# ═══════════════════════════════════════════════════════════════════════


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


SYNC_URL = "/api/v1/businesses/{business_id}/sales/sync"
SALE_URL = "/api/v1/businesses/{business_id}/sales/{sale_id}"
BY_CLIENT_URL = "/api/v1/businesses/{business_id}/sales/by-client-id/{client_sale_id}"


async def _create_sale(
    client: AsyncClient,
    business_id: UUID,
    db_session: AsyncSession,
    **overrides: object,
) -> dict:
    """Helper: post a single sale via the sync endpoint and return parsed JSON."""
    sale_input = {
        "client_sale_id": overrides.get("client_sale_id", str(uuid4())),
        "status": overrides.get("status", "completed"),
        "store_id": str(overrides.get("store_id", uuid4())),
        "line_items": overrides.get(
            "line_items",
            [{"item_id": str(uuid4()), "quantity": "1", "unit_price": "10.00"}],
        ),
        "discount_amount": str(overrides.get("discount_amount", Decimal("0"))),
        "payment_method": overrides.get("payment_method", "cash"),
        "occurred_at": (overrides.get("occurred_at", datetime.now(UTC))).isoformat(),
    }
    if "void_or_refund_reason" in overrides:
        sale_input["void_or_refund_reason"] = overrides["void_or_refund_reason"]

    headers = _auth_header(business_id=business_id)
    resp = await client.post(
        SYNC_URL.format(business_id=business_id),
        json={"sales": [sale_input]},
        headers=headers,
    )
    return resp.json()


# ═══════════════════════════════════════════════════════════════════════
# Tests
# ═══════════════════════════════════════════════════════════════════════


class TestSyncEndpoint:
    """POST /businesses/{business_id}/sales/sync"""

    async def test_sync_new_sale_returns_created(
        self, client: AsyncClient, db_session: AsyncSession,
    ) -> None:
        business_id = uuid4()
        body = await _create_sale(client, business_id, db_session)

        assert body["results"][0]["status"] == "created"

        sale = (
            await db_session.exec(
                select(Sale).where(Sale.client_sale_id == body["results"][0]["client_sale_id"])
            )
        ).one()
        assert sale.subtotal == Decimal("10.00")

    async def test_sync_twice_returns_duplicate(
        self, client: AsyncClient, db_session: AsyncSession,
    ) -> None:
        business_id = uuid4()
        sale_input = {
            "client_sale_id": "dup-test",
            "status": "completed",
            "store_id": str(uuid4()),
            "line_items": [{"item_id": str(uuid4()), "quantity": "1", "unit_price": "10.00"}],
            "discount_amount": "0",
            "payment_method": "cash",
            "occurred_at": datetime.now(UTC).isoformat(),
        }
        headers = _auth_header(business_id=business_id)

        resp1 = await client.post(
            SYNC_URL.format(business_id=business_id),
            json={"sales": [sale_input]},
            headers=headers,
        )
        assert resp1.json()["results"][0]["status"] == "created"

        resp2 = await client.post(
            SYNC_URL.format(business_id=business_id),
            json={"sales": [sale_input]},
            headers=headers,
        )
        assert resp2.json()["results"][0]["status"] == "duplicate"

        sales = (
            await db_session.exec(
                select(Sale).where(Sale.client_sale_id == "dup-test")
            )
        ).all()
        assert len(sales) == 1

    async def test_mixed_batch_returns_200_with_per_sale_results(
        self, client: AsyncClient, db_session: AsyncSession,
    ) -> None:
        business_id = uuid4()
        headers = _auth_header(business_id=business_id)

        first_id = "mixed-ok"
        second_id = "mixed-dup"
        payload = {
            "sales": [
                {
                    "client_sale_id": first_id,
                    "status": "completed",
                    "store_id": str(uuid4()),
                    "line_items": [
                        {"item_id": str(uuid4()), "quantity": "2", "unit_price": "5.00"},
                    ],
                    "discount_amount": "0",
                    "payment_method": "cash",
                    "occurred_at": datetime.now(UTC).isoformat(),
                },
                {
                    "client_sale_id": second_id,
                    "status": "completed",
                    "store_id": str(uuid4()),
                    "line_items": [
                        {"item_id": str(uuid4()), "quantity": "1", "unit_price": "3.00"},
                    ],
                    "discount_amount": "0",
                    "payment_method": "card",
                    "occurred_at": datetime.now(UTC).isoformat(),
                },
            ],
        }

        resp = await client.post(
            SYNC_URL.format(business_id=business_id),
            json=payload,
            headers=headers,
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["results"][0]["status"] == "created"
        assert data["results"][1]["status"] == "created"

        # Second call: same batch → second set of IDs are duplicates
        resp2 = await client.post(
            SYNC_URL.format(business_id=business_id),
            json=payload,
            headers=headers,
        )
        assert resp2.status_code == 200
        data2 = resp2.json()
        assert data2["results"][0]["status"] == "duplicate"
        assert data2["results"][1]["status"] == "duplicate"

        sales = (
            await db_session.exec(
                select(Sale).where(
                    Sale.client_sale_id.in_([first_id, second_id])
                )
            )
        ).all()
        assert len(sales) == 2

    async def test_sync_without_pos_write_returns_403(
        self, client: AsyncClient,
    ) -> None:
        business_id = uuid4()
        headers = _auth_header(
            business_id=business_id,
            permissions=["pos.view"],
        )
        payload = {
            "sales": [
                {
                    "client_sale_id": "no-perm",
                    "status": "completed",
                    "store_id": str(uuid4()),
                    "line_items": [
                        {"item_id": str(uuid4()), "quantity": "1", "unit_price": "5.00"},
                    ],
                    "discount_amount": "0",
                    "payment_method": "cash",
                    "occurred_at": datetime.now(UTC).isoformat(),
                },
            ],
        }
        resp = await client.post(
            SYNC_URL.format(business_id=business_id),
            json=payload,
            headers=headers,
        )
        assert resp.status_code == 403

    async def test_sync_cross_business_rejected(
        self, client: AsyncClient,
    ) -> None:
        business_id = uuid4()
        other_business_id = uuid4()
        headers = _auth_header(business_id=business_id, permissions=["pos.write"])
        payload = {
            "sales": [
                {
                    "client_sale_id": "cross-biz",
                    "status": "completed",
                    "store_id": str(uuid4()),
                    "line_items": [
                        {"item_id": str(uuid4()), "quantity": "1", "unit_price": "5.00"},
                    ],
                    "discount_amount": "0",
                    "payment_method": "cash",
                    "occurred_at": datetime.now(UTC).isoformat(),
                },
            ],
        }
        resp = await client.post(
            SYNC_URL.format(business_id=other_business_id),
            json=payload,
            headers=headers,
        )
        assert resp.status_code == 403

    async def test_customer_id_round_trips_through_sync_and_read(
        self, client: AsyncClient,
    ) -> None:
        """A sale synced with a customer_id carries it through GET reads too
        — see tests/api/test_customers.py for the full customer-linkage and
        aggregate-correctness coverage; this just guards the sales-side
        schemas (SaleSyncInput/SaleRead) don't regress independently."""
        business_id = uuid4()
        headers = _auth_header(
            business_id=business_id, permissions=["pos.write", "pos.view", "customers.create"],
        )
        customer_id = uuid4()
        await client.post(
            f"/api/v1/businesses/{business_id}/customers/sync",
            json={"customers": [{
                "id": str(customer_id),
                "name": "Jane Doe",
                "phone": "+1-555-0100",
                "joined_at": datetime.now(UTC).isoformat(),
            }]},
            headers=headers,
        )

        client_sale_id = str(uuid4())
        payload = {
            "sales": [
                {
                    "client_sale_id": client_sale_id,
                    "status": "completed",
                    "store_id": str(uuid4()),
                    "line_items": [
                        {"item_id": str(uuid4()), "quantity": "1", "unit_price": "5.00"},
                    ],
                    "discount_amount": "0",
                    "payment_method": "cash",
                    "customer_id": str(customer_id),
                    "occurred_at": datetime.now(UTC).isoformat(),
                },
            ],
        }
        sync_resp = await client.post(
            SYNC_URL.format(business_id=business_id), json=payload, headers=headers,
        )
        assert sync_resp.json()["results"][0]["status"] == "created"

        read_resp = await client.get(
            BY_CLIENT_URL.format(business_id=business_id, client_sale_id=client_sale_id),
            headers=headers,
        )
        assert read_resp.json()["customer_id"] == str(customer_id)

    async def test_sale_with_no_customer_id_reads_back_null(
        self, client: AsyncClient,
    ) -> None:
        business_id = uuid4()
        headers = _auth_header(business_id=business_id, permissions=["pos.write", "pos.view"])
        client_sale_id = str(uuid4())
        payload = {
            "sales": [
                {
                    "client_sale_id": client_sale_id,
                    "status": "completed",
                    "store_id": str(uuid4()),
                    "line_items": [
                        {"item_id": str(uuid4()), "quantity": "1", "unit_price": "5.00"},
                    ],
                    "discount_amount": "0",
                    "payment_method": "cash",
                    "occurred_at": datetime.now(UTC).isoformat(),
                },
            ],
        }
        await client.post(SYNC_URL.format(business_id=business_id), json=payload, headers=headers)

        read_resp = await client.get(
            BY_CLIENT_URL.format(business_id=business_id, client_sale_id=client_sale_id),
            headers=headers,
        )
        assert read_resp.json()["customer_id"] is None


class TestGetSaleEndpoint:
    """GET /businesses/{business_id}/sales/{sale_id}"""

    async def test_get_sale_by_id_returns_sale(
        self, client: AsyncClient, db_session: AsyncSession,
    ) -> None:
        business_id = uuid4()
        body = await _create_sale(client, business_id, db_session)
        sale_id = body["results"][0]["client_sale_id"]

        sale = (
            await db_session.exec(
                select(Sale).where(Sale.client_sale_id == sale_id)
            )
        ).one()

        headers = _auth_header(business_id=business_id)
        resp = await client.get(
            SALE_URL.format(business_id=business_id, sale_id=sale.id),
            headers=headers,
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["id"] == str(sale.id)
        assert data["client_sale_id"] == sale_id

    async def test_get_nonexistent_sale_returns_404(
        self, client: AsyncClient,
    ) -> None:
        business_id = uuid4()
        headers = _auth_header(business_id=business_id)
        resp = await client.get(
            SALE_URL.format(business_id=business_id, sale_id=uuid4()),
            headers=headers,
        )
        assert resp.status_code == 404

    async def test_get_sale_without_pos_view_returns_403(
        self, client: AsyncClient, db_session: AsyncSession,
    ) -> None:
        business_id = uuid4()
        body = await _create_sale(client, business_id, db_session)
        sale = (
            await db_session.exec(
                select(Sale).where(
                    Sale.client_sale_id == body["results"][0]["client_sale_id"]
                )
            )
        ).one()

        headers = _auth_header(
            business_id=business_id,
            permissions=["pos.write"],
        )
        resp = await client.get(
            SALE_URL.format(business_id=business_id, sale_id=sale.id),
            headers=headers,
        )
        assert resp.status_code == 403

    async def test_get_sale_cross_business_returns_404(
        self, client: AsyncClient, db_session: AsyncSession,
    ) -> None:
        business_id = uuid4()
        body = await _create_sale(client, business_id, db_session)
        sale = (
            await db_session.exec(
                select(Sale).where(
                    Sale.client_sale_id == body["results"][0]["client_sale_id"]
                )
            )
        ).one()

        other = uuid4()
        headers = _auth_header(business_id=other)
        resp = await client.get(
            SALE_URL.format(business_id=other, sale_id=sale.id),
            headers=headers,
        )
        # The token is scoped to *other* and the path is for *other*, so
        # business-context binding passes.  The 404 comes from the DB
        # query — no sale exists for *other* with this sale_id.
        assert resp.status_code == 404


class TestGetSaleByClientIdEndpoint:
    """GET /businesses/{business_id}/sales/by-client-id/{client_sale_id}"""

    async def test_get_sale_by_client_id_returns_sale(
        self, client: AsyncClient, db_session: AsyncSession,
    ) -> None:
        business_id = uuid4()
        client_sale_id = f"by-client-{uuid4()}"
        body = await _create_sale(client, business_id, db_session, client_sale_id=client_sale_id)

        assert body["results"][0]["status"] == "created"

        headers = _auth_header(business_id=business_id)
        resp = await client.get(
            BY_CLIENT_URL.format(
                business_id=business_id, client_sale_id=client_sale_id,
            ),
            headers=headers,
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["client_sale_id"] == client_sale_id

    async def test_get_by_client_id_equals_get_by_sale_id(
        self, client: AsyncClient, db_session: AsyncSession,
    ) -> None:
        business_id = uuid4()
        client_sale_id = f"equiv-{uuid4()}"
        body = await _create_sale(client, business_id, db_session, client_sale_id=client_sale_id)
        assert body["results"][0]["status"] == "created"

        sale = (
            await db_session.exec(
                select(Sale).where(Sale.client_sale_id == client_sale_id)
            )
        ).one()

        headers = _auth_header(business_id=business_id)

        by_id_resp = await client.get(
            SALE_URL.format(business_id=business_id, sale_id=sale.id),
            headers=headers,
        )
        by_client_resp = await client.get(
            BY_CLIENT_URL.format(
                business_id=business_id, client_sale_id=client_sale_id,
            ),
            headers=headers,
        )

        assert by_id_resp.status_code == 200
        assert by_client_resp.status_code == 200
        assert by_id_resp.json() == by_client_resp.json()

    async def test_get_nonexistent_client_id_returns_404(
        self, client: AsyncClient,
    ) -> None:
        business_id = uuid4()
        headers = _auth_header(business_id=business_id)
        resp = await client.get(
            BY_CLIENT_URL.format(
                business_id=business_id, client_sale_id="no-such-sale",
            ),
            headers=headers,
        )
        assert resp.status_code == 404

    async def test_get_by_client_id_without_pos_view_returns_403(
        self, client: AsyncClient,
    ) -> None:
        business_id = uuid4()
        headers = _auth_header(
            business_id=business_id,
            permissions=["pos.write"],
        )
        resp = await client.get(
            BY_CLIENT_URL.format(
                business_id=business_id, client_sale_id="no-view-perm",
            ),
            headers=headers,
        )
        assert resp.status_code == 403


class TestLineItemUnitCost:
    """unit_cost snapshot on sale line items — frozen history for profit."""

    async def test_sync_with_unit_cost_stores_and_returns_it(
        self, client: AsyncClient, db_session: AsyncSession,
    ) -> None:
        business_id = uuid4()
        item_id = uuid4()
        body = await _create_sale(
            client,
            business_id,
            db_session,
            line_items=[
                {
                    "item_id": str(item_id),
                    "quantity": "2",
                    "unit_price": "10.00",
                    "unit_cost": "3.50",
                },
            ],
        )
        assert body["results"][0]["status"] == "created"

        line = (
            await db_session.exec(
                select(SaleLineItem).where(SaleLineItem.item_id == item_id)
            )
        ).one()
        assert line.unit_cost == Decimal("3.5000")

        headers = _auth_header(business_id=business_id)
        resp = await client.get(
            BY_CLIENT_URL.format(
                business_id=business_id,
                client_sale_id=body["results"][0]["client_sale_id"],
            ),
            headers=headers,
        )
        assert resp.status_code == 200
        assert resp.json()["line_items"][0]["unit_cost"] == "3.5000"

    async def test_sync_without_unit_cost_stays_null(
        self, client: AsyncClient, db_session: AsyncSession,
    ) -> None:
        """Older clients omit the snapshot — reports fall back to live costs."""
        business_id = uuid4()
        item_id = uuid4()
        body = await _create_sale(
            client,
            business_id,
            db_session,
            line_items=[
                {"item_id": str(item_id), "quantity": "1", "unit_price": "10.00"},
            ],
        )
        assert body["results"][0]["status"] == "created"

        line = (
            await db_session.exec(
                select(SaleLineItem).where(SaleLineItem.item_id == item_id)
            )
        ).one()
        assert line.unit_cost is None

    async def test_sync_negative_unit_cost_rejected(
        self, client: AsyncClient, db_session: AsyncSession,
    ) -> None:
        """Schema-level violation — the whole batch 422s like any other
        malformed line item (per-sale "failed" is for service-level errors
        such as unknown customers, not Pydantic violations)."""
        business_id = uuid4()
        headers = _auth_header(business_id=business_id)
        resp = await client.post(
            SYNC_URL.format(business_id=business_id),
            json={
                "sales": [
                    {
                        "client_sale_id": str(uuid4()),
                        "status": "completed",
                        "store_id": str(uuid4()),
                        "line_items": [
                            {
                                "item_id": str(uuid4()),
                                "quantity": "1",
                                "unit_price": "10.00",
                                "unit_cost": "-1.00",
                            },
                        ],
                        "discount_amount": "0",
                        "payment_method": "cash",
                        "occurred_at": datetime.now(UTC).isoformat(),
                    },
                ],
            },
            headers=headers,
        )
        assert resp.status_code == 422
