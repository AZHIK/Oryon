"""Tests for the WhatsApp Business connection + webhooks.

Connection CRUD (store + live-verify, masked reads, disconnect), webhook
verification, status callbacks (sent → delivered → read / failed), and
inbound reply storage with confirmation detection. Network calls to Meta
are faked with monkeypatched service functions — no live Graph calls.
Staff send order messages via the wa.me deep link; there is no Cloud API
per-PO send.
"""

from __future__ import annotations

from datetime import UTC, datetime, timedelta
from decimal import Decimal
from uuid import UUID, uuid4

import jwt
import pytest
from httpx import AsyncClient
from sqlmodel import select
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.config import get_settings
from app.models.inventory import Item, ItemType
from app.models.requisition import MessageStatus, SupplierMessage
from app.models.suppliers import Supplier
from app.models.units import Unit
from app.models.whatsapp import WhatsAppConnection
from app.services import whatsapp_service
from app.services.whatsapp_service import CloudApiError, confirmation_detected

TEST_PRIVATE_KEY = """-----BEGIN RSA PRIVATE KEY-----
MIIEowIBAAKCAQEAoeArXtZ+XrZt5klLXLayTcGOFZCOUZ9tbexpmrdMcXzwxAzx
h+ByKOHyJEJ1xXB6hdZZMWV/66rHMG+dx3l8w8o3woM1Ae/QEz7Yf8Zx1Eu3eqCR
E05QzX0c1SfSxrzNQ91czCIRW3vyq2CQ/dnD3xqFP7asLrfihqYzw2SzSNyoOJo3
EAYwv2IdkJJeQepco+WX5OjZBrYOB9YFXySmo32cT7uT6eIIo1CJFYqCvfK6OeAw
oQy92wOJxod1VcPYRBbFU86bTnge2+ymbjpnnMDUUyF5pl+05raXwrg3pz8ibXjs
V+9aGx1Qs1pAd0IMB6b9JegMcRy3SCdUgvcz/wIDAQABAoIBADEbusyYsdm16n1U
ewJzgoBIWfx80FA+14njkN4ZAZ3kU36GlresBbYVZcpOR0BQsTrtHj34Fui99JPj
KLCdUJZtQKFIAMrHoA5WoIOTBnFrTwxqrdh3h9fvPtIDtNQJ7xPJkh9zrmRco/AN
6a65Y8zJVOdRWccKjjRfM5Dxedp+axsPkLTXJvh/tioGDTzsFTSshMIdOSElH8e4
VZQPx+nB50yRRu/ek3AjrdELppQ8OziNBvl455g9pg8XOuclEG3JuZoZU/s22sYi
oORswvTGrceuzWSdosh6hwMWW8D07BOkLaIMAWpiL0TpCqWW3ABamj6MmZJRHDKL
Rxr8vkECgYEAzosvjW5A5JGTh9XmxMbi2GifN95cm7Lb8IZAdvI/370eVGIxzIHi
eduiHw0pXNcEnTS5uT0fbt/2AvfN8bvoOrfdAnjLSlbgzLFbx544Mtekert6hyGA
ISiB79J6dgdHxa1hWRiQ+Tn+71t+9Afry5TWA/JmqIcFTBLhIJ/WgzECgYEAyKLm
tnN/DHkfYsuWKF2T8LBfXJ5AsXAznfjDP9NKpuVr9ouy/QhjOgVriXdtvt67B00Z
FNtkS2LrjlFLz5cTvABW0TOdB09EA3s6iWE6bjp+Jg7gSHXzIW29YS1VOzVlYxP9
FfYigxlDVrgjnZ9lefZz0iwT+ACDPErjCVdzfi8CgYB6xAxNulzj/wt7z85M5BJt
ozIQGSFegl9shb/Hc5I3wMdITN1gu0sMN1oTrtUJE9zwPCiwS/5k/sXRWc2Vg6Uz
UZoSIA5lb2JLCJiO/CJXRgnD0a+wpl7sVpF1JNwZT5Z/juCv/oQdPzWiu/WnwxWK
ejsDOY9/WFHzt70MkTUF4QKBgQCK5lQo/b54KSZ0ZBNZcKdp2wC6Awkwjkf91ml9
t06YSn462i4ZBQSE95miOp8so9ABVvvFN7mwgxQmm9uLJMFRxz5TaJMOq26fpmE5
GKm2BCKvQF8/awDeJLYWH6dA7U96jy0IVjVAY23+DE8D4YUEMX2vhDpy2BAC3qld
H0DimwKBgG3GWjH5G4uYQ5x/LKX5mSO5vGANRM0n3CVfXtyEDURuo8hQQFbSUyH/
ac/0/f9oHqk1dBBfGYF9eNr6iSo3qgGYmlnavwSeOoemgHwfF9oCULVUPPwldMVD
Miohh2E1Z9T1bGnvke8mHGpvQ4WurtmexOjz+KzVooCAkKzxIYKf
-----END RSA PRIVATE KEY-----
"""

ALL_PERMS = [
    "procurement.create",
    "procurement.approve",
    "procurement.view",
    "procurement.receive",
    "suppliers.create",
    "suppliers.view",
    "suppliers.update",
]

BUSINESS_ID = UUID("00000000-0000-0000-0000-000000000001")
STORE_ID = UUID("00000000-0000-0000-0000-000000000010")
WA_PREFIX = f"/api/v1/businesses/{BUSINESS_ID}/whatsapp"
PO_PREFIX = f"/api/v1/businesses/{BUSINESS_ID}/purchases"
REQ_PREFIX = f"/api/v1/businesses/{BUSINESS_ID}/requisitions"


def _build_token(
    permissions: list[str] | None = None, business_id: UUID = BUSINESS_ID
) -> str:
    settings = get_settings()
    now = datetime.now(UTC)
    payload = {
        "sub": "user-test-123",
        "type": "access",
        "user_category": "business_staff",
        "iat": now,
        "exp": now + timedelta(minutes=15),
        "permissions": permissions if permissions is not None else ALL_PERMS,
        "active_business_id": str(business_id),
    }
    return jwt.encode(payload, TEST_PRIVATE_KEY, algorithm=settings.jwt_algorithm)


AUTH_HEADER = {"Authorization": f"Bearer {_build_token()}"}


async def _unit_id(session: AsyncSession, code: str = "kg") -> UUID:
    return (await session.exec(select(Unit).where(Unit.code == code))).one().id


async def _item(
    session: AsyncSession, name: str = "Flour", cost: Decimal | None = Decimal("2.0000")
) -> Item:
    item = Item(
        business_id=BUSINESS_ID,
        store_id=STORE_ID,
        name=name,
        unit_id=await _unit_id(session),
        reorder_threshold=Decimal("10.000"),
        reorder_quantity=Decimal("50.000"),
        item_type=ItemType.RAW_MATERIAL,
        unit_cost=cost,
    )
    session.add(item)
    await session.commit()
    await session.refresh(item)
    return item


async def _supplier(
    session: AsyncSession, name: str = "Acme", whatsapp: str | None = "+255700000001"
) -> Supplier:
    supplier = Supplier(business_id=BUSINESS_ID, name=name, whatsapp_number=whatsapp)
    session.add(supplier)
    await session.commit()
    await session.refresh(supplier)
    return supplier


async def _connect(
    client: AsyncClient, monkeypatch: pytest.MonkeyPatch, phone_number_id: str = "12345"
) -> dict:
    async def _fake_fetch(**_kwargs):  # noqa: ANN003, ANN202
        return {"display_phone_number": "+255700000099", "verified_name": "FoodLink"}

    monkeypatch.setattr(whatsapp_service, "fetch_phone_number", _fake_fetch)
    response = await client.put(
        f"{WA_PREFIX}/connection",
        json={
            "phone_number_id": phone_number_id,
            "display_phone_number": "+255700000099",
            "access_token": "test-token-abcdef",
        },
        headers=AUTH_HEADER,
    )
    assert response.status_code == 200, response.text
    return response.json()


async def _submit_order(client: AsyncClient, supplier: Supplier, item: Item) -> dict:
    response = await client.post(
        REQ_PREFIX,
        json={
            "store_id": str(STORE_ID),
            "idempotency_key": f"wa-{uuid4()}",
            "lines": [
                {
                    "item_id": str(item.id),
                    "qty": "5.000",
                    "supplier_id": str(supplier.id),
                }
            ],
        },
        headers=AUTH_HEADER,
    )
    assert response.status_code == 201, response.text
    return response.json()


# ── Connection CRUD ───────────────────────────────────────────────────────


async def test_connect_stores_and_verifies(
    client: AsyncClient, monkeypatch: pytest.MonkeyPatch
) -> None:
    body = await _connect(client, monkeypatch)
    assert body["status"] == "connected"
    assert body["phone_number_id"] == "12345"
    assert body["token_preview"] == "…cdef"
    assert body["verify_token"]
    assert body["webhook_path"] == "/api/v1/whatsapp/webhook"


async def test_get_connection_masks_token(
    client: AsyncClient, monkeypatch: pytest.MonkeyPatch, db_session: AsyncSession
) -> None:
    await _connect(client, monkeypatch)
    response = await client.get(f"{WA_PREFIX}/connection", headers=AUTH_HEADER)
    assert response.status_code == 200
    assert response.json()["token_preview"] == "…cdef"
    row = (
        await db_session.exec(
            select(WhatsAppConnection).where(WhatsAppConnection.business_id == BUSINESS_ID)
        )
    ).one()
    assert row.access_token == "test-token-abcdef"


async def test_get_connection_missing_is_404(client: AsyncClient) -> None:
    response = await client.get(f"{WA_PREFIX}/connection", headers=AUTH_HEADER)
    assert response.status_code == 404


async def test_connect_blank_token_rejected(
    client: AsyncClient, monkeypatch: pytest.MonkeyPatch
) -> None:
    async def _fake_fetch(**_kwargs):  # noqa: ANN003, ANN202
        return {}

    monkeypatch.setattr(whatsapp_service, "fetch_phone_number", _fake_fetch)
    response = await client.put(
        f"{WA_PREFIX}/connection",
        json={"phone_number_id": "12345", "access_token": "   "},
        headers=AUTH_HEADER,
    )
    assert response.status_code == 422


async def test_connect_provider_error_recorded(
    client: AsyncClient, monkeypatch: pytest.MonkeyPatch
) -> None:
    async def _bad_fetch(**_kwargs):  # noqa: ANN003, ANN202
        raise CloudApiError("Invalid OAuth access token", status_code=401)

    monkeypatch.setattr(whatsapp_service, "fetch_phone_number", _bad_fetch)
    response = await client.put(
        f"{WA_PREFIX}/connection",
        json={"phone_number_id": "nope", "access_token": "bad-token"},
        headers=AUTH_HEADER,
    )
    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "error"
    assert "Invalid OAuth" in body["last_error"]


async def test_disconnect_clears_token(
    client: AsyncClient, monkeypatch: pytest.MonkeyPatch
) -> None:
    await _connect(client, monkeypatch)
    response = await client.delete(f"{WA_PREFIX}/connection", headers=AUTH_HEADER)
    assert response.status_code == 200
    assert response.json()["status"] == "disconnected"
    assert response.json()["token_preview"] is None
    assert (await client.get(f"{WA_PREFIX}/connection", headers=AUTH_HEADER)).status_code == 404


async def test_connection_requires_auth(client: AsyncClient) -> None:
    assert (await client.get(f"{WA_PREFIX}/connection")).status_code == 401


async def test_connection_rejects_other_business(
    client: AsyncClient, monkeypatch: pytest.MonkeyPatch
) -> None:
    await _connect(client, monkeypatch)
    other = UUID("00000000-0000-0000-0000-000000000099")
    headers = {"Authorization": f"Bearer {_build_token(business_id=other)}"}
    response = await client.get(
        f"/api/v1/businesses/{other}/whatsapp/connection", headers=headers
    )
    assert response.status_code == 404


# ── Per-PO Cloud API send is gone ──────────────────────────────────────────


async def test_send_whatsapp_route_is_gone(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    """Staff send via the wa.me deep link — no Cloud API per-PO send."""
    supplier = await _supplier(db_session)
    item = await _item(db_session)
    submitted = await _submit_order(client, supplier, item)
    po_id = submitted["purchase_orders"][0]["id"]
    response = await client.post(
        f"{PO_PREFIX}/orders/{po_id}/send-whatsapp", headers=AUTH_HEADER
    )
    assert response.status_code == 404


# ── Webhook verification ──────────────────────────────────────────────────


async def test_webhook_verify_roundtrip(
    client: AsyncClient, monkeypatch: pytest.MonkeyPatch
) -> None:
    body = await _connect(client, monkeypatch)
    token = body["verify_token"]
    good = await client.get(
        "/api/v1/whatsapp/webhook",
        params={
            "hub.mode": "subscribe",
            "hub.verify_token": token,
            "hub.challenge": "challenge-123",
            "business_id": str(BUSINESS_ID),
            "t": token,
        },
    )
    assert good.status_code == 200
    assert good.text == "challenge-123"

    bad = await client.get(
        "/api/v1/whatsapp/webhook",
        params={
            "hub.mode": "subscribe",
            "hub.verify_token": "wrong",
            "hub.challenge": "challenge-123",
            "business_id": str(BUSINESS_ID),
        },
    )
    assert bad.status_code == 403


# ── Status callbacks + inbound replies ────────────────────────────────────


def _status_payload(wamid: str, state: str) -> dict:
    return {
        "object": "whatsapp_business_account",
        "entry": [
            {
                "changes": [
                    {
                        "value": {
                            "metadata": {"phone_number_id": "12345"},
                            "statuses": [{"id": wamid, "status": state}],
                        }
                    }
                ]
            }
        ],
    }


async def test_webhook_status_flow(
    client: AsyncClient, monkeypatch: pytest.MonkeyPatch, db_session: AsyncSession
) -> None:
    await _connect(client, monkeypatch)
    supplier = await _supplier(db_session)
    item = await _item(db_session)
    submitted = await _submit_order(client, supplier, item)
    po_id = submitted["purchase_orders"][0]["id"]

    # No Cloud API send — join the status callback to the prepared message
    # by stamping the provider id directly.
    msg = (
        await db_session.exec(
            select(SupplierMessage).where(SupplierMessage.po_id == UUID(po_id))
        )
    ).one()
    msg.provider_message_id = "wamid.flow1"
    db_session.add(msg)
    await db_session.commit()

    for state in ("delivered", "read"):
        response = await client.post(
            "/api/v1/whatsapp/webhook", json=_status_payload("wamid.flow1", state)
        )
        assert response.status_code == 200
    row = (
        await db_session.exec(
            select(SupplierMessage).where(
                SupplierMessage.provider_message_id == "wamid.flow1"
            )
        )
    ).one()
    # This session already holds the row (stamped above) — refresh past the
    # identity map to see the webhook session's update.
    await db_session.refresh(row)
    assert row.status == MessageStatus.READ
    row = (
        await db_session.exec(
            select(SupplierMessage).where(
                SupplierMessage.provider_message_id == "wamid.flow1"
            )
        )
    ).one()
    assert row.status == MessageStatus.READ


async def test_webhook_unknown_wamid_ignored(client: AsyncClient) -> None:
    response = await client.post(
        "/api/v1/whatsapp/webhook", json=_status_payload("wamid.unknown", "delivered")
    )
    assert response.status_code == 200
    assert response.json()["statuses_applied"] == []


def _inbound_payload(sender: str, text: str | None) -> dict:
    message: dict = {"from": sender, "id": "wamid.in1", "type": "text"}
    if text is not None:
        message["text"] = {"body": text}
    return {
        "object": "whatsapp_business_account",
        "entry": [
            {
                "changes": [
                    {
                        "value": {
                            "metadata": {"phone_number_id": "12345"},
                            "messages": [message],
                        }
                    }
                ]
            }
        ],
    }


async def test_webhook_inbound_reply_matched_with_confirmation(
    client: AsyncClient, monkeypatch: pytest.MonkeyPatch, db_session: AsyncSession
) -> None:
    await _connect(client, monkeypatch)
    supplier = await _supplier(db_session)
    item = await _item(db_session)
    submitted = await _submit_order(client, supplier, item)
    po_id = submitted["purchase_orders"][0]["id"]

    response = await client.post(
        "/api/v1/whatsapp/webhook",
        json=_inbound_payload("255700000001", "Sawa, confirmed"),
    )
    assert response.status_code == 200
    replies = response.json()["replies"]
    assert len(replies) == 1
    assert replies[0]["confirmation_detected"] is True
    assert replies[0]["po_id"] == po_id
    assert replies[0]["matched_supplier_id"] == str(supplier.id)


async def test_webhook_inbound_unmatched_sender_has_no_po(
    client: AsyncClient, monkeypatch: pytest.MonkeyPatch, db_session: AsyncSession
) -> None:
    await _connect(client, monkeypatch)
    await _supplier(db_session)
    await _item(db_session)
    response = await client.post(
        "/api/v1/whatsapp/webhook",
        json=_inbound_payload("255799988877", "Hello?"),
    )
    assert response.status_code == 200
    replies = response.json()["replies"]
    assert replies[0]["po_id"] is None
    assert replies[0]["confirmation_detected"] is False


def test_confirmation_keywords() -> None:
    assert confirmation_detected("Sawa")
    assert confirmation_detected("confirmed. thanks")
    assert confirmation_detected("OK")
    assert not confirmation_detected("Bei ni kubwa sana")
    assert not confirmation_detected("")
    assert not confirmation_detected(None)
