"""API tests for void/refund endpoint — POST .../void-or-refund."""

from __future__ import annotations

from datetime import UTC, datetime
from uuid import UUID, uuid4

from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession
from sqlmodel import select

from app.models.pos import Sale, SaleStatus
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
            "permissions": permissions or ["pos.write", "pos.view", "pos.refund"],
            "active_business_id": str(biz_id),
        },
    )
    return {"Authorization": f"Bearer {token}"}


SYNC_URL = "/api/v1/businesses/{business_id}/sales/sync"
VOID_REFUND_URL = "/api/v1/businesses/{business_id}/sales/{sale_id}/void-or-refund"


async def _create_completed_sale(
    client: AsyncClient,
    business_id: UUID,
) -> tuple[dict, str]:
    """POST one completed sale via sync and return the parsed JSON."""
    sale_input = {
        "client_sale_id": str(uuid4()),
        "status": "completed",
        "store_id": str(uuid4()),
        "line_items": [{"item_id": str(uuid4()), "quantity": "2", "unit_price": "5.00"}],
        "discount_amount": "0",
        "payment_method": "cash",
        "occurred_at": datetime.now(UTC).isoformat(),
    }
    headers = _auth_header(business_id=business_id)
    resp = await client.post(
        SYNC_URL.format(business_id=business_id),
        json={"sales": [sale_input]},
        headers=headers,
    )
    body = resp.json()
    return body, sale_input["client_sale_id"]


# ═══════════════════════════════════════════════════════════════════════
# Tests
# ═══════════════════════════════════════════════════════════════════════


class TestVoidRefundEndpoint:
    """POST /businesses/{business_id}/sales/{sale_id}/void-or-refund"""

    async def test_void_completed_sale_returns_200(
        self,
        client: AsyncClient,
        db_session: AsyncSession,
    ) -> None:
        business_id = uuid4()
        body, _client_sale_id = await _create_completed_sale(client, business_id)
        sale_id = body["results"][0]["client_sale_id"]

        sale = (await db_session.exec(select(Sale).where(Sale.client_sale_id == sale_id))).one()
        assert sale.status == SaleStatus.COMPLETED

        headers = _auth_header(business_id=business_id)
        resp = await client.post(
            VOID_REFUND_URL.format(business_id=business_id, sale_id=sale.id),
            json={"client_action_id": "api-void-1", "new_status": "voided", "reason": "API void"},
            headers=headers,
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["status"] == "voided"
        assert data["void_or_refund_reason"] == "API void"

        # Confirm database reflects the change
        await db_session.refresh(sale)
        assert sale.status == SaleStatus.VOIDED

    async def test_refund_completed_sale_returns_200(
        self,
        client: AsyncClient,
        db_session: AsyncSession,
    ) -> None:
        business_id = uuid4()
        body, _ = await _create_completed_sale(client, business_id)
        sale = (
            await db_session.exec(
                select(Sale).where(Sale.client_sale_id == body["results"][0]["client_sale_id"])
            )
        ).one()

        headers = _auth_header(business_id=business_id)
        resp = await client.post(
            VOID_REFUND_URL.format(business_id=business_id, sale_id=sale.id),
            json={
                "client_action_id": "api-ref-1",
                "new_status": "refunded",
                "reason": "API refund",
            },
            headers=headers,
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["status"] == "refunded"
        assert data["refunded_at"] is not None

    async def test_without_pos_refund_returns_403(
        self,
        client: AsyncClient,
        db_session: AsyncSession,
    ) -> None:
        business_id = uuid4()
        body, _ = await _create_completed_sale(client, business_id)
        sale = (
            await db_session.exec(
                select(Sale).where(Sale.client_sale_id == body["results"][0]["client_sale_id"])
            )
        ).one()

        headers = _auth_header(
            business_id=business_id,
            permissions=["pos.write", "pos.view"],
        )
        resp = await client.post(
            VOID_REFUND_URL.format(business_id=business_id, sale_id=sale.id),
            json={
                "client_action_id": "no-perm",
                "new_status": "voided",
                "reason": "Should fail",
            },
            headers=headers,
        )
        assert resp.status_code == 403

    async def test_cross_business_rejected(
        self,
        client: AsyncClient,
        db_session: AsyncSession,
    ) -> None:
        business_id = uuid4()
        body, _ = await _create_completed_sale(client, business_id)
        sale = (
            await db_session.exec(
                select(Sale).where(Sale.client_sale_id == body["results"][0]["client_sale_id"])
            )
        ).one()

        other_business_id = uuid4()
        headers = _auth_header(
            business_id=other_business_id,
            permissions=["pos.refund"],
        )
        resp = await client.post(
            VOID_REFUND_URL.format(business_id=other_business_id, sale_id=sale.id),
            json={
                "client_action_id": "cross-biz",
                "new_status": "voided",
                "reason": "Should fail",
            },
            headers=headers,
        )
        assert resp.status_code == 404

    async def test_void_already_voided_returns_409(
        self,
        client: AsyncClient,
        db_session: AsyncSession,
    ) -> None:
        business_id = uuid4()
        body, _ = await _create_completed_sale(client, business_id)
        sale = (
            await db_session.exec(
                select(Sale).where(Sale.client_sale_id == body["results"][0]["client_sale_id"])
            )
        ).one()

        headers = _auth_header(business_id=business_id)

        # First void succeeds
        resp1 = await client.post(
            VOID_REFUND_URL.format(business_id=business_id, sale_id=sale.id),
            json={
                "client_action_id": "double-void",
                "new_status": "voided",
                "reason": "First void",
            },
            headers=headers,
        )
        assert resp1.status_code == 200

        # Second void is rejected
        resp2 = await client.post(
            VOID_REFUND_URL.format(business_id=business_id, sale_id=sale.id),
            json={
                "client_action_id": "double-void-2",
                "new_status": "voided",
                "reason": "Second void",
            },
            headers=headers,
        )
        assert resp2.status_code == 409
        assert (
            "already" in resp2.json()["detail"].lower()
            or "cannot" in resp2.json()["detail"].lower()
        )

    async def test_idempotency_same_client_action_id_twice(
        self,
        client: AsyncClient,
        db_session: AsyncSession,
    ) -> None:
        business_id = uuid4()
        body, _ = await _create_completed_sale(client, business_id)
        sale = (
            await db_session.exec(
                select(Sale).where(Sale.client_sale_id == body["results"][0]["client_sale_id"])
            )
        ).one()

        headers = _auth_header(business_id=business_id)
        payload = {
            "client_action_id": "idemp-api-test",
            "new_status": "voided",
            "reason": "First call",
        }

        resp1 = await client.post(
            VOID_REFUND_URL.format(business_id=business_id, sale_id=sale.id),
            json=payload,
            headers=headers,
        )
        assert resp1.status_code == 200
        assert resp1.json()["status"] == "voided"

        # Same client_action_id again
        resp2 = await client.post(
            VOID_REFUND_URL.format(business_id=business_id, sale_id=sale.id),
            json=payload,
            headers=headers,
        )
        assert resp2.status_code == 200
        assert resp2.json()["status"] == "voided"

        # Only one sale row
        sales = (await db_session.exec(select(Sale).where(Sale.id == sale.id))).all()
        assert len(sales) == 1
