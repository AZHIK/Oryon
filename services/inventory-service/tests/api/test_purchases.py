"""Integration tests for the purchases module endpoints.

Two-step flow only: create an (unfulfilled, qty-only) PO → receive GRNs
with per-line actual costs (asserts the stock engine ran + weighted-average
costing) → fulfilled once quantities are met, else still unfulfilled.
Cancel is allowed only before anything is received. The old submit/approve,
returns, invoices/payments, and statement routes are gone (404).
"""

from __future__ import annotations

from datetime import UTC, datetime, timedelta
from decimal import Decimal
from uuid import UUID

import jwt
import pytest
from httpx import AsyncClient
from sqlmodel import select
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.config import get_settings
from app.models.inventory import Item, ItemType, StockLevel, StockMovement
from app.models.suppliers import Supplier
from app.models.units import Unit

# ── Test RSA keypair (copied from test_reorders.py) ──────────────────────
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

ALL_PURCHASE_PERMS = [
    "procurement.create",
    "procurement.view",
    "procurement.receive",
]


def _build_token(
    *,
    permissions: list[str] | None = None,
    active_business_id: str = "00000000-0000-0000-0000-000000000001",
) -> str:
    settings = get_settings()
    now = datetime.now(UTC)
    payload = {
        "sub": "user-test-123",
        "type": "access",
        "user_category": "business_staff",
        "iat": now,
        "exp": now + timedelta(minutes=15),
        "permissions": permissions if permissions is not None else ALL_PURCHASE_PERMS,
        "active_business_id": active_business_id,
    }
    return jwt.encode(payload, TEST_PRIVATE_KEY, algorithm=settings.jwt_algorithm)


BUSINESS_ID = UUID("00000000-0000-0000-0000-000000000001")
STORE_ID = UUID("00000000-0000-0000-0000-000000000010")
AUTH_HEADER = {"Authorization": f"Bearer {_build_token()}"}
API_PREFIX = f"/api/v1/businesses/{BUSINESS_ID}/purchases"


def _auth_header(permissions: list[str] | None = None) -> dict[str, str]:
    return {"Authorization": f"Bearer {_build_token(permissions=permissions)}"}


async def _unit_id(session: AsyncSession, code: str = "kg") -> UUID:
    result = await session.exec(select(Unit).where(Unit.code == code))
    return result.one().id


async def _create_item(
    session: AsyncSession,
    name: str = "Flour",
    item_type: ItemType = ItemType.RAW_MATERIAL,
    unit_cost: Decimal | None = None,
) -> Item:
    item = Item(
        business_id=BUSINESS_ID,
        store_id=STORE_ID,
        name=name,
        unit_id=await _unit_id(session),
        reorder_threshold=Decimal("10.000"),
        reorder_quantity=Decimal("50.000"),
        item_type=item_type,
        unit_cost=unit_cost,
    )
    session.add(item)
    await session.commit()
    await session.refresh(item)
    return item


async def _create_supplier(session: AsyncSession, name: str = "Acme Produce") -> Supplier:
    supplier = Supplier(business_id=BUSINESS_ID, name=name)
    session.add(supplier)
    await session.commit()
    await session.refresh(supplier)
    return supplier


def _order_payload(
    item: Item, supplier: Supplier, second_item: Item | None = None, **overrides
) -> dict:
    lines = [
        {
            "item_id": str(item.id),
            "quantity_ordered": "20.000",
        }
    ]
    if second_item is not None:
        lines.append(
            {
                "item_id": str(second_item.id),
                "quantity_ordered": "10.000",
            }
        )
    payload = {
        "store_id": str(STORE_ID),
        "supplier_id": str(supplier.id),
        "lines": lines,
    }
    payload.update(overrides)
    return payload


def _receive_payload(line_id: str, qty: str, unit_cost: str = "2.5000") -> dict:
    """One-line GRN body — cost rides on the receipt, never the PO."""
    return {
        "lines": [
            {
                "purchase_order_line_id": line_id,
                "quantity_received": qty,
                "unit_cost": unit_cost,
            }
        ]
    }


async def _create_order(client: AsyncClient, item: Item, supplier: Supplier) -> dict:
    """Create a PO via the API (no handshake — created unfulfilled)."""
    resp = await client.post(
        f"{API_PREFIX}/orders",
        json=_order_payload(item, supplier),
        headers=AUTH_HEADER,
    )
    assert resp.status_code == 201, resp.text
    return resp.json()


async def _line_id(client: AsyncClient, order_id: str) -> str:
    detail = (
        await client.get(f"{API_PREFIX}/orders/{order_id}", headers=AUTH_HEADER)
    ).json()
    return detail["lines"][0]["id"]


async def _stock_level(session: AsyncSession, item: Item) -> Decimal:
    level = (
        await session.exec(
            select(StockLevel).where(
                StockLevel.item_id == item.id, StockLevel.store_id == STORE_ID
            )
        )
    ).one_or_none()
    return level.current_quantity if level else Decimal("0.000")


# ── Create ───────────────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_create_multi_line_order(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    item = await _create_item(db_session)
    second = await _create_item(db_session, name="Sugar")
    supplier = await _create_supplier(db_session)

    resp = await client.post(
        f"{API_PREFIX}/orders",
        json=_order_payload(item, supplier, second),
        headers=AUTH_HEADER,
    )
    assert resp.status_code == 201, resp.text
    data = resp.json()
    assert data["status"] == "unfulfilled"
    assert data["po_number"].startswith("PO-")
    # Qty-only PO — no money on the header.
    assert "total_amount" not in data
    assert "invoice_status" not in data

    detail = (
        await client.get(f"{API_PREFIX}/orders/{data['id']}", headers=AUTH_HEADER)
    ).json()
    assert len(detail["lines"]) == 2
    assert {line["unit"] for line in detail["lines"]} == {"kg"}
    assert all("unit_cost" not in line for line in detail["lines"])
    assert detail["receipts"] == []


@pytest.mark.asyncio
async def test_create_order_sellable_item_rejected(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    item = await _create_item(db_session, item_type=ItemType.SELLABLE)
    supplier = await _create_supplier(db_session)

    resp = await client.post(
        f"{API_PREFIX}/orders",
        json=_order_payload(item, supplier),
        headers=AUTH_HEADER,
    )
    assert resp.status_code == 422
    assert "sellable" in resp.json()["detail"].lower()


@pytest.mark.asyncio
async def test_create_order_duplicate_and_empty_lines_rejected(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    item = await _create_item(db_session)
    supplier = await _create_supplier(db_session)

    dup = _order_payload(item, supplier)
    dup["lines"] = [dup["lines"][0], dup["lines"][0]]
    resp = await client.post(
        f"{API_PREFIX}/orders", json=dup, headers=AUTH_HEADER
    )
    assert resp.status_code == 422

    empty = _order_payload(item, supplier, lines=[])
    resp = await client.post(
        f"{API_PREFIX}/orders", json=empty, headers=AUTH_HEADER
    )
    assert resp.status_code == 422


@pytest.mark.asyncio
async def test_create_order_unknown_supplier_404s(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    item = await _create_item(db_session)
    supplier = await _create_supplier(db_session)
    payload = _order_payload(
        item, supplier, supplier_id="00000000-0000-0000-0000-000000000404"
    )
    resp = await client.post(
        f"{API_PREFIX}/orders", json=payload, headers=AUTH_HEADER
    )
    assert resp.status_code == 404


# ── Receiving (core: stock + costing + fulfilled/unfulfilled) ───────────────


@pytest.mark.asyncio
async def test_partial_receive_stays_unfulfilled_full_receive_fulfills(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    item = await _create_item(db_session, unit_cost=Decimal("2.0000"))
    supplier = await _create_supplier(db_session)
    order = await _create_order(client, item, supplier)
    line_id = await _line_id(client, order["id"])

    # Partial: 8 of 20 @ 2.5000 over opening 0 @ 2.0000 → avg 2.5000.
    resp = await client.post(
        f"{API_PREFIX}/orders/{order['id']}/receive",
        json=_receive_payload(line_id, "8.000"),
        headers=AUTH_HEADER,
    )
    assert resp.status_code == 200, resp.text
    assert resp.json()["grn_number"].startswith("GRN-")
    assert Decimal(resp.json()["lines"][0]["unit_cost"]) == Decimal("2.5000")

    detail = (
        await client.get(f"{API_PREFIX}/orders/{order['id']}", headers=AUTH_HEADER)
    ).json()
    assert detail["status"] == "unfulfilled"
    assert Decimal(detail["lines"][0]["quantity_received"]) == Decimal("8.000")
    assert await _stock_level(db_session, item) == Decimal("8.000")

    # Remainder: 12 @ 2.5000 over 8 @ 2.5000 → avg stays 2.5000, fulfilled.
    resp = await client.post(
        f"{API_PREFIX}/orders/{order['id']}/receive",
        json=_receive_payload(line_id, "12.000"),
        headers=AUTH_HEADER,
    )
    assert resp.status_code == 200, resp.text

    detail = (
        await client.get(f"{API_PREFIX}/orders/{order['id']}", headers=AUTH_HEADER)
    ).json()
    assert detail["status"] == "fulfilled"
    assert detail["received_at"] is not None
    assert len(detail["receipts"]) == 2
    assert await _stock_level(db_session, item) == Decimal("20.000")

    await db_session.refresh(item)
    assert item.unit_cost == Decimal("2.5000")

    movements = (
        await db_session.exec(
            select(StockMovement).where(StockMovement.item_id == item.id)
        )
    ).all()
    assert len(movements) == 2
    assert all(m.reference_type == "goods_receipt" for m in movements)


@pytest.mark.asyncio
async def test_fulfilled_order_cannot_be_received_again(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    item = await _create_item(db_session)
    supplier = await _create_supplier(db_session)
    order = await _create_order(client, item, supplier)
    line_id = await _line_id(client, order["id"])

    resp = await client.post(
        f"{API_PREFIX}/orders/{order['id']}/receive",
        json=_receive_payload(line_id, "20.000"),
        headers=AUTH_HEADER,
    )
    assert resp.status_code == 200, resp.text

    resp = await client.post(
        f"{API_PREFIX}/orders/{order['id']}/receive",
        json=_receive_payload(line_id, "1.000"),
        headers=AUTH_HEADER,
    )
    assert resp.status_code == 409


@pytest.mark.asyncio
async def test_weighted_average_cost_blends_with_existing_stock(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    # Opening 10 @ 1.0000, receive 10 @ 2.5000 → (10 + 25)/20 = 1.7500.
    item = await _create_item(db_session, unit_cost=Decimal("1.0000"))
    db_session.add(
        StockLevel(item_id=item.id, store_id=STORE_ID, current_quantity=Decimal("10.000"))
    )
    await db_session.commit()
    supplier = await _create_supplier(db_session)
    order = await _create_order(client, item, supplier)
    line_id = await _line_id(client, order["id"])

    resp = await client.post(
        f"{API_PREFIX}/orders/{order['id']}/receive",
        json=_receive_payload(line_id, "10.000"),
        headers=AUTH_HEADER,
    )
    assert resp.status_code == 200, resp.text
    await db_session.refresh(item)
    assert item.unit_cost == Decimal("1.7500")


@pytest.mark.asyncio
async def test_over_receive_rejected(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    item = await _create_item(db_session)
    supplier = await _create_supplier(db_session)
    order = await _create_order(client, item, supplier)
    line_id = await _line_id(client, order["id"])

    resp = await client.post(
        f"{API_PREFIX}/orders/{order['id']}/receive",
        json=_receive_payload(line_id, "21.000"),
        headers=AUTH_HEADER,
    )
    assert resp.status_code == 409
    assert await _stock_level(db_session, item) == Decimal("0.000")


@pytest.mark.asyncio
async def test_receive_requires_unit_cost(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    """Cost rides on the receipt: a GRN line without unit_cost is rejected."""
    item = await _create_item(db_session)
    supplier = await _create_supplier(db_session)
    order = await _create_order(client, item, supplier)
    line_id = await _line_id(client, order["id"])

    resp = await client.post(
        f"{API_PREFIX}/orders/{order['id']}/receive",
        json={"lines": [{"purchase_order_line_id": line_id, "quantity_received": "5.000"}]},
        headers=AUTH_HEADER,
    )
    assert resp.status_code == 422

    resp = await client.post(
        f"{API_PREFIX}/orders/{order['id']}/receive",
        json=_receive_payload(line_id, "5.000", unit_cost="-1.0000"),
        headers=AUTH_HEADER,
    )
    assert resp.status_code == 422


# ── Cancel ───────────────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_cancel_unreceived_order(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    item = await _create_item(db_session)
    supplier = await _create_supplier(db_session)
    order = await _create_order(client, item, supplier)

    resp = await client.post(
        f"{API_PREFIX}/orders/{order['id']}/cancel", headers=AUTH_HEADER
    )
    assert resp.status_code == 200, resp.text
    assert resp.json()["status"] == "cancelled"

    # Cancelled orders cannot be received.
    line_id = await _line_id(client, order["id"])
    resp = await client.post(
        f"{API_PREFIX}/orders/{order['id']}/receive",
        json=_receive_payload(line_id, "5.000"),
        headers=AUTH_HEADER,
    )
    assert resp.status_code == 409

    # Double cancel is rejected.
    resp = await client.post(
        f"{API_PREFIX}/orders/{order['id']}/cancel", headers=AUTH_HEADER
    )
    assert resp.status_code == 409


@pytest.mark.asyncio
async def test_cancel_after_receive_or_fulfill_rejected(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    item = await _create_item(db_session)
    supplier = await _create_supplier(db_session)
    order = await _create_order(client, item, supplier)
    line_id = await _line_id(client, order["id"])

    # Partial receipt → cancel rejected.
    resp = await client.post(
        f"{API_PREFIX}/orders/{order['id']}/receive",
        json=_receive_payload(line_id, "5.000"),
        headers=AUTH_HEADER,
    )
    assert resp.status_code == 200, resp.text
    resp = await client.post(
        f"{API_PREFIX}/orders/{order['id']}/cancel", headers=AUTH_HEADER
    )
    assert resp.status_code == 409

    # Full receipt (fulfilled) → cancel rejected.
    resp = await client.post(
        f"{API_PREFIX}/orders/{order['id']}/receive",
        json=_receive_payload(line_id, "15.000"),
        headers=AUTH_HEADER,
    )
    assert resp.status_code == 200, resp.text
    resp = await client.post(
        f"{API_PREFIX}/orders/{order['id']}/cancel", headers=AUTH_HEADER
    )
    assert resp.status_code == 409


# ── Removed routes ─────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_removed_routes_are_gone(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    """submit/approve, returns, invoices, payments, and statements are gone."""
    item = await _create_item(db_session)
    supplier = await _create_supplier(db_session)
    order = await _create_order(client, item, supplier)

    for method, path, body in [
        ("POST", f"{API_PREFIX}/orders/{order['id']}/submit", None),
        ("POST", f"{API_PREFIX}/orders/{order['id']}/approve", None),
        ("POST", f"{API_PREFIX}/returns", {"item_id": str(item.id), "quantity": "1.000"}),
        (
            "POST",
            f"{API_PREFIX}/invoices",
            {"purchase_order_id": order["id"], "invoice_number": "SUP-001"},
        ),
        (
            "GET",
            f"{API_PREFIX}/suppliers/{supplier.id}/statement",
            None,
        ),
    ]:
        resp = await client.request(method, path, json=body, headers=AUTH_HEADER)
        assert resp.status_code == 404, f"{method} {path} should be gone"


# ── List & permissions ─────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_list_filters_by_status(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    item = await _create_item(db_session)
    supplier = await _create_supplier(db_session)
    await _create_order(client, item, supplier)

    resp = await client.get(
        f"{API_PREFIX}/orders?status=unfulfilled", headers=AUTH_HEADER
    )
    assert resp.status_code == 200, resp.text
    assert resp.json()["total"] == 1

    resp = await client.get(
        f"{API_PREFIX}/orders?status=fulfilled", headers=AUTH_HEADER
    )
    assert resp.json()["total"] == 0


@pytest.mark.asyncio
async def test_missing_token_401_and_missing_permission_403(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    item = await _create_item(db_session)
    supplier = await _create_supplier(db_session)

    resp = await client.post(
        f"{API_PREFIX}/orders", json=_order_payload(item, supplier)
    )
    assert resp.status_code == 401

    resp = await client.post(
        f"{API_PREFIX}/orders",
        json=_order_payload(item, supplier),
        headers=_auth_header(permissions=["procurement.view"]),
    )
    assert resp.status_code == 403

    resp = await client.get(
        f"{API_PREFIX}/orders", headers=_auth_header(permissions=[])
    )
    assert resp.status_code == 403


@pytest.mark.asyncio
async def test_cross_business_token_rejected(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    """A token bound to another business cannot touch this business's POs."""
    item = await _create_item(db_session)
    supplier = await _create_supplier(db_session)
    other_id = "00000000-0000-0000-0000-000000000099"
    other_header = {"Authorization": f"Bearer {_build_token(active_business_id=other_id)}"}
    resp = await client.post(
        f"{API_PREFIX}/orders",
        json=_order_payload(item, supplier),
        headers=other_header,
    )
    assert resp.status_code == 403
