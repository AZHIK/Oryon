"""Tests for the requisition (unified multi-supplier order) flow.

Unit: bulk-assign scopes/overwrite/price snapshots, PO split grouping,
payload generation (qty-only formatting, URL-encoding, missing number),
status rollup.
Integration: cart → bulk-assign → per-item override → submit → POs → payloads,
duplicate-submit idempotency, transaction rollback on validation failure.
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
from app.models.purchases import PurchaseOrder
from app.models.requisition import (
    Requisition,
    RequisitionLine,
    SupplierItem,
)
from app.models.suppliers import Supplier
from app.models.units import Unit
from app.services.requisition_service import (
    build_whatsapp_payload,
    rollup_requisition_status,
)

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


def _build_token(permissions: list[str] | None = None) -> str:
    settings = get_settings()
    now = datetime.now(UTC)
    payload = {
        "sub": "user-test-123",
        "type": "access",
        "user_category": "business_staff",
        "iat": now,
        "exp": now + timedelta(minutes=15),
        "permissions": permissions if permissions is not None else ALL_PERMS,
        "active_business_id": str(BUSINESS_ID),
    }
    return jwt.encode(payload, TEST_PRIVATE_KEY, algorithm=settings.jwt_algorithm)


BUSINESS_ID = UUID("00000000-0000-0000-0000-000000000001")
STORE_ID = UUID("00000000-0000-0000-0000-000000000010")
AUTH_HEADER = {"Authorization": f"Bearer {_build_token()}"}
REQ_PREFIX = f"/api/v1/businesses/{BUSINESS_ID}/requisitions"
CAT_PREFIX = f"/api/v1/businesses/{BUSINESS_ID}/supplier-items"
PO_PREFIX = f"/api/v1/businesses/{BUSINESS_ID}/purchases"


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


async def _price(
    session: AsyncSession, supplier: Supplier, item: Item, price: Decimal | None
) -> SupplierItem:
    row = SupplierItem(supplier_id=supplier.id, item_id=item.id, price=price)
    session.add(row)
    await session.commit()
    await session.refresh(row)
    return row


async def _draft_requisition(session: AsyncSession, item_ids: list[UUID]) -> Requisition:
    req = Requisition(business_id=BUSINESS_ID, store_id=STORE_ID, created_by=uuid4())
    session.add(req)
    await session.flush()
    for iid in item_ids:
        session.add(RequisitionLine(requisition_id=req.id, item_id=iid, qty=Decimal("5.000")))
    await session.commit()
    await session.refresh(req)
    return req


def _submit_payload(lines: list[dict], key: str | None = None) -> dict:
    return {
        "store_id": str(STORE_ID),
        "notes": "weekly restock",
        "expected_at": "2026-10-05T08:00:00Z",
        "idempotency_key": key or f"key-{uuid4()}",
        "lines": lines,
    }


# ── bulk-assign ────────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_bulk_assign_unassigned_only_preserves_manual_pick(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    flour, sugar = await _item(db_session, "Flour"), await _item(db_session, "Sugar")
    bulk_sup, manual_sup = (
        await _supplier(db_session, "Bulk"),
        await _supplier(db_session, "Manual"),
    )
    req = await _draft_requisition(db_session, [flour.id, sugar.id])
    # Pre-assign sugar manually.
    sugar_line = (
        await db_session.exec(
            select(RequisitionLine).where(
                RequisitionLine.requisition_id == req.id, RequisitionLine.item_id == sugar.id
            )
        )
    ).one()
    sugar_line.supplier_id = manual_sup.id
    db_session.add(sugar_line)
    await db_session.commit()

    resp = await client.post(
        f"{REQ_PREFIX}/{req.id}/bulk-assign",
        json={"supplier_id": str(bulk_sup.id), "scope": "unassigned_items_only"},
        headers=AUTH_HEADER,
    )
    assert resp.status_code == 200, resp.text
    touched = resp.json()
    assert len(touched) == 1  # only flour
    assert touched[0]["supplier_id"] == str(bulk_sup.id)
    assert touched[0]["price_unconfirmed"] is True  # no catalogue row
    assert touched[0]["supplier_assignment_source"] == "bulk_all"


@pytest.mark.asyncio
async def test_bulk_assign_all_without_overwrite_keeps_manual(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    flour, sugar = await _item(db_session, "Flour"), await _item(db_session, "Sugar")
    bulk_sup, manual_sup = (
        await _supplier(db_session, "Bulk"),
        await _supplier(db_session, "Manual"),
    )
    req = await _draft_requisition(db_session, [flour.id, sugar.id])
    sugar_line = (
        await db_session.exec(
            select(RequisitionLine).where(
                RequisitionLine.requisition_id == req.id, RequisitionLine.item_id == sugar.id
            )
        )
    ).one()
    sugar_line.supplier_id = manual_sup.id
    db_session.add(sugar_line)
    await db_session.commit()

    resp = await client.post(
        f"{REQ_PREFIX}/{req.id}/bulk-assign",
        json={"supplier_id": str(bulk_sup.id), "scope": "all_items", "overwrite": False},
        headers=AUTH_HEADER,
    )
    assert resp.status_code == 200, resp.text
    assert len(resp.json()) == 1  # flour only, sugar preserved


@pytest.mark.asyncio
async def test_bulk_assign_all_with_overwrite_reassigns_and_resolves_price(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    flour, sugar = await _item(db_session, "Flour"), await _item(db_session, "Sugar")
    bulk_sup, manual_sup = (
        await _supplier(db_session, "Bulk"),
        await _supplier(db_session, "Manual"),
    )
    await _price(db_session, bulk_sup, flour, Decimal("3.2500"))
    await _price(db_session, bulk_sup, sugar, Decimal("1.5000"))
    req = await _draft_requisition(db_session, [flour.id, sugar.id])
    sugar_line = (
        await db_session.exec(
            select(RequisitionLine).where(
                RequisitionLine.requisition_id == req.id, RequisitionLine.item_id == sugar.id
            )
        )
    ).one()
    sugar_line.supplier_id = manual_sup.id
    db_session.add(sugar_line)
    await db_session.commit()

    resp = await client.post(
        f"{REQ_PREFIX}/{req.id}/bulk-assign",
        json={"supplier_id": str(bulk_sup.id), "scope": "all_items", "overwrite": True},
        headers=AUTH_HEADER,
    )
    assert resp.status_code == 200, resp.text
    touched = {t["item_id"]: t for t in resp.json()}
    assert len(touched) == 2
    assert touched[str(sugar.id)]["supplier_id"] == str(bulk_sup.id)
    assert touched[str(flour.id)]["unit_price_snapshot"] == "3.2500"
    assert all(t["price_unconfirmed"] is False for t in touched.values())


@pytest.mark.asyncio
async def test_bulk_assign_idempotent_rerun_no_duplicates(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    flour = await _item(db_session, "Flour")
    sup = await _supplier(db_session, "Bulk")
    req = await _draft_requisition(db_session, [flour.id])
    for _ in range(2):
        resp = await client.post(
            f"{REQ_PREFIX}/{req.id}/bulk-assign",
            json={"supplier_id": str(sup.id), "scope": "all_items", "overwrite": True},
            headers=AUTH_HEADER,
        )
        assert resp.status_code == 200, resp.text
    count = len(
        (
            await db_session.exec(
                select(RequisitionLine).where(RequisitionLine.requisition_id == req.id)
            )
        ).all()
    )
    assert count == 1


# ── submit / split ─────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_submit_splits_one_po_per_supplier(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    flour, sugar, rice = (
        await _item(db_session, "Flour"),
        await _item(db_session, "Sugar"),
        await _item(db_session, "Rice"),
    )
    sup_a, sup_b = await _supplier(db_session, "A"), await _supplier(db_session, "B")
    await _price(db_session, sup_a, flour, Decimal("2.5000"))
    await _price(db_session, sup_a, sugar, Decimal("5.0000"))
    await _price(db_session, sup_b, rice, Decimal("4.0000"))

    resp = await client.post(
        REQ_PREFIX,
        json=_submit_payload(
            [
                {"item_id": str(flour.id), "qty": "20.000", "supplier_id": str(sup_a.id)},
                {"item_id": str(sugar.id), "qty": "10.000", "supplier_id": str(sup_a.id)},
                {"item_id": str(rice.id), "qty": "5.000", "supplier_id": str(sup_b.id)},
            ]
        ),
        headers=AUTH_HEADER,
    )
    assert resp.status_code == 201, resp.text
    body = resp.json()
    assert len(body["purchase_orders"]) == 2
    po_numbers = [po["po_number"] for po in body["purchase_orders"]]
    assert len(set(po_numbers)) == 2 and all(n.startswith("PO-") for n in po_numbers)
    # Qty-only POs — no money on the split headers.
    assert all("total_amount" not in po for po in body["purchase_orders"])
    assert all(po["status"] == "unfulfilled" for po in body["purchase_orders"])
    assert body["price_unconfirmed_items"] == []
    assert len(body["messages"]) == 2
    assert all(m["status"] == "ready" for m in body["messages"])
    assert body["rollup_status"] == "Unfulfilled"


@pytest.mark.asyncio
async def test_submit_rejects_missing_supplier_naming_items(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    flour, sugar = await _item(db_session, "Flour"), await _item(db_session, "Sugar")
    sup = await _supplier(db_session, "A")
    resp = await client.post(
        REQ_PREFIX,
        json=_submit_payload(
            [
                {"item_id": str(flour.id), "qty": "2.000", "supplier_id": str(sup.id)},
                {"item_id": str(sugar.id), "qty": "2.000", "supplier_id": None},
            ]
        ),
        headers=AUTH_HEADER,
    )
    assert resp.status_code == 422, resp.text
    assert "Sugar" in resp.json()["detail"]
    # Nothing persisted — all-or-nothing.
    assert len((await db_session.exec(select(Requisition))).all()) == 0
    assert len((await db_session.exec(select(PurchaseOrder))).all()) == 0


@pytest.mark.asyncio
async def test_submit_allows_unconfirmed_and_flags(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    flour = await _item(db_session, "Flour", cost=None)
    sup = await _supplier(db_session, "A")
    resp = await client.post(
        REQ_PREFIX,
        json=_submit_payload(
            [{"item_id": str(flour.id), "qty": "3.000", "supplier_id": str(sup.id)}]
        ),
        headers=AUTH_HEADER,
    )
    assert resp.status_code == 201, resp.text
    body = resp.json()
    assert body["price_unconfirmed_items"] == ["Flour"]
    payload = body["messages"][0]["payload"]
    # Qty-only payload — no prices, no totals.
    assert payload["structured_data"]["items"][0] == {
        "name": "Flour",
        "qty": "3.000",
        "unit": "kg",
    }
    assert "total" not in payload["structured_data"]
    assert "TBC" not in payload["text_preview"]
    assert "- Flour: 3.000 kg" in payload["text_preview"]


@pytest.mark.asyncio
async def test_same_item_two_suppliers_yields_two_pos(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    flour = await _item(db_session, "Flour")
    sup_a, sup_b = await _supplier(db_session, "A"), await _supplier(db_session, "B")
    await _price(db_session, sup_a, flour, Decimal("2.0000"))
    await _price(db_session, sup_b, flour, Decimal("3.0000"))
    resp = await client.post(
        REQ_PREFIX,
        json=_submit_payload(
            [
                {"item_id": str(flour.id), "qty": "2.000", "supplier_id": str(sup_a.id)},
                {"item_id": str(flour.id), "qty": "3.000", "supplier_id": str(sup_b.id)},
            ]
        ),
        headers=AUTH_HEADER,
    )
    assert resp.status_code == 201, resp.text
    assert len(resp.json()["purchase_orders"]) == 2


@pytest.mark.asyncio
async def test_duplicate_submit_idempotent(client: AsyncClient, db_session: AsyncSession) -> None:
    flour = await _item(db_session, "Flour")
    sup = await _supplier(db_session, "A")
    await _price(db_session, sup, flour, Decimal("2.0000"))
    payload = _submit_payload(
        [{"item_id": str(flour.id), "qty": "2.000", "supplier_id": str(sup.id)}], key="dup-key-1"
    )
    first = await client.post(REQ_PREFIX, json=payload, headers=AUTH_HEADER)
    assert first.status_code == 201, first.text
    second = await client.post(REQ_PREFIX, json=payload, headers=AUTH_HEADER)
    assert second.status_code == 201, second.text
    assert first.json()["requisition"]["id"] == second.json()["requisition"]["id"]
    assert len((await db_session.exec(select(PurchaseOrder))).all()) == 1


@pytest.mark.asyncio
async def test_transaction_rollback_on_bad_item(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    flour = await _item(db_session, "Flour")
    sup = await _supplier(db_session, "A")
    resp = await client.post(
        REQ_PREFIX,
        json=_submit_payload(
            [
                {"item_id": str(flour.id), "qty": "2.000", "supplier_id": str(sup.id)},
                {"item_id": str(uuid4()), "qty": "1.000", "supplier_id": str(sup.id)},
            ]
        ),
        headers=AUTH_HEADER,
    )
    assert resp.status_code == 404, resp.text
    assert len((await db_session.exec(select(PurchaseOrder))).all()) == 0


# ── payload unit tests ─────────────────────────────────────────────────────


def _po(supplier_id: UUID) -> PurchaseOrder:
    return PurchaseOrder(
        business_id=BUSINESS_ID,
        store_id=STORE_ID,
        supplier_id=supplier_id,
        po_number="PO-0042",
    )


@pytest.mark.asyncio
async def test_payload_qty_only_and_url_encoding(db_session: AsyncSession) -> None:
    sup = await _supplier(db_session, "Acme & Sons", "+255 700 000 001")
    payload = build_whatsapp_payload(
        po=_po(sup.id),
        supplier=sup,
        lines=[
            {"name": "Flour", "qty": Decimal("2.5"), "unit": "kg"},
            {"name": "Sugar & Spice", "qty": Decimal("1"), "unit": "kg"},
        ],
        restaurant_name="Mama's Kitchen",
        order_date="2026-09-28",
        delivery_requested_date="2026-10-05",
        notes="Call on arrival",
    )
    assert payload is not None
    # Qty-only — no money anywhere in the payload.
    assert payload["structured_data"]["items"] == [
        {"name": "Flour", "qty": "2.5", "unit": "kg"},
        {"name": "Sugar & Spice", "qty": "1", "unit": "kg"},
    ]
    assert "total" not in payload["structured_data"]
    assert "- Flour: 2.5 kg" in payload["text_preview"]
    assert "- Sugar & Spice: 1 kg" in payload["text_preview"]
    assert payload["deep_link"].startswith("https://wa.me/255700000001?text=")
    assert "%26" in payload["deep_link"]  # '&' encoded
    assert " " not in payload["deep_link"].split("?text=")[1][:20]


@pytest.mark.asyncio
async def test_payload_missing_number_returns_none(db_session: AsyncSession) -> None:
    sup = await _supplier(db_session, "NoPhone", None)
    sup.phone = None
    payload = build_whatsapp_payload(
        po=_po(sup.id),
        supplier=sup,
        lines=[],
        restaurant_name="R",
        order_date="2026-09-28",
        delivery_requested_date=None,
        notes=None,
    )
    assert payload is None


@pytest.mark.asyncio
async def test_payload_phone_fallback(db_session: AsyncSession) -> None:
    sup = await _supplier(db_session, "Legacy", None)
    sup.phone = "0700 111 222"
    payload = build_whatsapp_payload(
        po=_po(sup.id),
        supplier=sup,
        lines=[{"name": "Flour", "qty": Decimal("1"), "unit": "kg"}],
        restaurant_name="R",
        order_date="2026-09-28",
        delivery_requested_date=None,
        notes=None,
    )
    assert payload is not None
    assert payload["supplier"]["whatsapp_number"] == "0700111222"


# ── rollup ─────────────────────────────────────────────────────────────────


def test_rollup_statuses() -> None:
    assert rollup_requisition_status([]) == "Unfulfilled"
    assert rollup_requisition_status(["unfulfilled"]) == "Unfulfilled"
    assert rollup_requisition_status(["fulfilled", "unfulfilled"]) == "Unfulfilled"
    assert rollup_requisition_status(["fulfilled", "fulfilled"]) == "Fulfilled"
    assert rollup_requisition_status(["cancelled", "cancelled"]) == "Cancelled"


# ── integration: full journey ──────────────────────────────────────────────


@pytest.mark.asyncio
async def test_full_journey_submit_then_receive_fulfills(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    """Requisition POs are receivable immediately — submit, then receive
    each PO's lines with actual costs until fulfilled."""
    flour, sugar, rice = (
        await _item(db_session, "Flour"),
        await _item(db_session, "Sugar"),
        await _item(db_session, "Rice"),
    )
    sup_a, sup_b = (
        await _supplier(db_session, "Supplier A"),
        await _supplier(db_session, "Supplier B"),
    )
    await _price(db_session, sup_a, flour, Decimal("2.0000"))
    await _price(db_session, sup_a, sugar, Decimal("5.0000"))
    await _price(db_session, sup_b, rice, Decimal("4.0000"))
    resp = await client.post(
        REQ_PREFIX,
        json=_submit_payload(
            [
                {"item_id": str(flour.id), "qty": "2.000", "supplier_id": str(sup_a.id)},
                {"item_id": str(sugar.id), "qty": "1.000", "supplier_id": str(sup_b.id)},
                {"item_id": str(rice.id), "qty": "3.000", "supplier_id": str(sup_b.id)},
            ]
        ),
        headers=AUTH_HEADER,
    )
    assert resp.status_code == 201, resp.text
    body = resp.json()
    assert len(body["purchase_orders"]) == 2
    assert all(po["status"] == "unfulfilled" for po in body["purchase_orders"])
    assert len(body["messages"]) == 2
    for msg in body["messages"]:
        assert "wa.me" in msg["payload"]["deep_link"]

    # The manual mark-sent/mark-confirmed transitions are gone.
    first_po = body["purchase_orders"][0]
    for action in ("mark-sent", "mark-confirmed"):
        resp = await client.post(
            f"{PO_PREFIX}/orders/{first_po['id']}/{action}", headers=AUTH_HEADER
        )
        assert resp.status_code == 404, action

    # Receive every line of every PO → all fulfilled → rollup Fulfilled.
    for po in body["purchase_orders"]:
        detail = (
            await client.get(f"{PO_PREFIX}/orders/{po['id']}", headers=AUTH_HEADER)
        ).json()
        lines = [
            {
                "purchase_order_line_id": line["id"],
                "quantity_received": line["quantity_ordered"],
                "unit_cost": "2.0000",
            }
            for line in detail["lines"]
        ]
        resp = await client.post(
            f"{PO_PREFIX}/orders/{po['id']}/receive",
            json={"lines": lines},
            headers=AUTH_HEADER,
        )
        assert resp.status_code == 200, resp.text

    fetched = (
        await client.get(
            f"{REQ_PREFIX}/{body['requisition']['id']}", headers=AUTH_HEADER
        )
    ).json()
    assert fetched["rollup_status"] == "Fulfilled"


@pytest.mark.asyncio
async def test_supplier_without_whatsapp_still_creates_po(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    flour = await _item(db_session, "Flour")
    sup = await _supplier(db_session, "NoWhatsApp", None)
    sup.phone = None
    db_session.add(sup)
    await db_session.commit()
    resp = await client.post(
        REQ_PREFIX,
        json=_submit_payload(
            [{"item_id": str(flour.id), "qty": "2.000", "supplier_id": str(sup.id)}]
        ),
        headers=AUTH_HEADER,
    )
    assert resp.status_code == 201, resp.text
    body = resp.json()
    assert len(body["purchase_orders"]) == 1
    assert body["messages"] == []  # payload skipped, PO created
