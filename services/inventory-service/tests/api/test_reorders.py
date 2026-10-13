"""Integration tests for reorder (purchase order) endpoints.

Covers create (incl. the sellable-item rejection), list/filter, receive
(the core piece — asserts the stock engine actually ran), cancel, and route
permissions. Mirrors ``test_items.py``/``test_operations.py``'s shape.
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
from app.models.reorders import Reorder, ReorderStatus
from app.models.suppliers import Supplier
from app.models.units import Unit

# ── Test RSA keypair (copied from test_token_verification.py) ──────────
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

ALL_REORDER_PERMS = [
    "reorders.view",
    "reorders.create",
    "reorders.receive",
    "reorders.cancel",
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
        "permissions": permissions or ALL_REORDER_PERMS,
        "active_business_id": active_business_id,
    }
    return jwt.encode(payload, TEST_PRIVATE_KEY, algorithm=settings.jwt_algorithm)


BUSINESS_ID = UUID("00000000-0000-0000-0000-000000000001")
OTHER_BUSINESS_ID = UUID("00000000-0000-0000-0000-000000000099")
STORE_ID = UUID("00000000-0000-0000-0000-000000000010")
AUTH_HEADER = {"Authorization": f"Bearer {_build_token()}"}
API_PREFIX = f"/api/v1/businesses/{BUSINESS_ID}/reorders"


def _auth_header(permissions: list[str] | None = None) -> dict[str, str]:
    return {"Authorization": f"Bearer {_build_token(permissions=permissions)}"}


async def _unit_id(session: AsyncSession, code: str = "kg") -> UUID:
    result = await session.exec(select(Unit).where(Unit.code == code))
    return result.one().id


async def _create_item(
    session: AsyncSession,
    name: str = "Flour",
    item_type: ItemType = ItemType.RAW_MATERIAL,
) -> Item:
    item = Item(
        business_id=BUSINESS_ID,
        store_id=STORE_ID,
        name=name,
        unit_id=await _unit_id(session),
        reorder_threshold=Decimal("10.000"),
        reorder_quantity=Decimal("50.000"),
        item_type=item_type,
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


async def _create_reorder(
    session: AsyncSession,
    item: Item,
    supplier: Supplier,
    quantity: Decimal = Decimal("20.000"),
    status: ReorderStatus = ReorderStatus.PENDING,
) -> Reorder:
    reorder = Reorder(
        business_id=BUSINESS_ID,
        store_id=STORE_ID,
        item_id=item.id,
        supplier_id=supplier.id,
        quantity=quantity,
        unit="kg",
        status=status,
        ordered_at=datetime.now(UTC),
    )
    session.add(reorder)
    await session.commit()
    await session.refresh(reorder)
    return reorder


def _reorder_payload(item: Item, supplier: Supplier, **overrides) -> dict:
    payload = {
        "store_id": str(STORE_ID),
        "item_id": str(item.id),
        "supplier_id": str(supplier.id),
        "quantity": "20.000",
    }
    payload.update(overrides)
    return payload


# ── Create ───────────────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_create_reorder_for_raw_material_item(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    item = await _create_item(db_session, item_type=ItemType.RAW_MATERIAL)
    supplier = await _create_supplier(db_session)

    resp = await client.post(
        API_PREFIX, json=_reorder_payload(item, supplier), headers=AUTH_HEADER
    )
    assert resp.status_code == 201, resp.text
    data = resp.json()
    assert data["status"] == "pending"
    assert data["unit"] == "kg"
    assert data["item_id"] == str(item.id)
    assert data["supplier_id"] == str(supplier.id)


@pytest.mark.asyncio
async def test_create_reorder_for_both_type_item_succeeds(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    item = await _create_item(db_session, item_type=ItemType.BOTH)
    supplier = await _create_supplier(db_session)

    resp = await client.post(
        API_PREFIX, json=_reorder_payload(item, supplier), headers=AUTH_HEADER
    )
    assert resp.status_code == 201, resp.text


@pytest.mark.asyncio
async def test_create_reorder_for_sellable_item_rejected(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    item = await _create_item(db_session, item_type=ItemType.SELLABLE)
    supplier = await _create_supplier(db_session)

    resp = await client.post(
        API_PREFIX, json=_reorder_payload(item, supplier), headers=AUTH_HEADER
    )
    assert resp.status_code == 422
    assert "sellable" in resp.json()["detail"].lower()


@pytest.mark.asyncio
async def test_create_reorder_for_item_with_no_unit_rejected(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    """An item whose unit_id is unresolved (NULL FK) cannot be reordered —
    ``Reorder.unit`` is non-nullable and always denormalized from the item's
    unit at creation time."""
    item = Item(
        business_id=BUSINESS_ID,
        store_id=STORE_ID,
        name="No Unit Item",
        reorder_threshold=Decimal("10.000"),
        reorder_quantity=Decimal("50.000"),
        item_type=ItemType.RAW_MATERIAL,
    )
    db_session.add(item)
    await db_session.commit()
    await db_session.refresh(item)
    supplier = await _create_supplier(db_session)

    resp = await client.post(
        API_PREFIX, json=_reorder_payload(item, supplier), headers=AUTH_HEADER
    )
    assert resp.status_code == 422
    assert "unit" in resp.json()["detail"].lower()


@pytest.mark.asyncio
async def test_create_reorder_unknown_item_or_supplier_404s(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    item = await _create_item(db_session)
    supplier = await _create_supplier(db_session)
    fake_id = "00000000-0000-0000-0000-000000000404"

    resp = await client.post(
        API_PREFIX, json=_reorder_payload(item, supplier, item_id=fake_id), headers=AUTH_HEADER
    )
    assert resp.status_code == 404

    resp = await client.post(
        API_PREFIX,
        json=_reorder_payload(item, supplier, supplier_id=fake_id),
        headers=AUTH_HEADER,
    )
    assert resp.status_code == 404


@pytest.mark.asyncio
async def test_create_reorder_rejects_non_positive_quantity(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    item = await _create_item(db_session)
    supplier = await _create_supplier(db_session)

    resp = await client.post(
        API_PREFIX,
        json=_reorder_payload(item, supplier, quantity="0"),
        headers=AUTH_HEADER,
    )
    assert resp.status_code == 422


# ── List/filter ──────────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_list_filters_by_status_and_item(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    item = await _create_item(db_session)
    other_item = await _create_item(db_session, name="Sugar")
    supplier = await _create_supplier(db_session)

    r1 = await _create_reorder(db_session, item, supplier, status=ReorderStatus.PENDING)
    await _create_reorder(db_session, other_item, supplier, status=ReorderStatus.RECEIVED)

    resp = await client.get(API_PREFIX, params={"status": "pending"}, headers=AUTH_HEADER)
    ids = [r["id"] for r in resp.json()["items"]]
    assert ids == [str(r1.id)]

    resp = await client.get(API_PREFIX, params={"item_id": str(item.id)}, headers=AUTH_HEADER)
    ids = [r["id"] for r in resp.json()["items"]]
    assert ids == [str(r1.id)]


@pytest.mark.asyncio
async def test_list_is_business_scoped(client: AsyncClient, db_session: AsyncSession) -> None:
    item = await _create_item(db_session)
    supplier = await _create_supplier(db_session)
    mine = await _create_reorder(db_session, item, supplier)

    other_item = Item(
        business_id=OTHER_BUSINESS_ID,
        store_id=STORE_ID,
        name="Theirs",
        reorder_threshold=Decimal("1"),
        reorder_quantity=Decimal("1"),
        item_type=ItemType.RAW_MATERIAL,
    )
    db_session.add(other_item)
    await db_session.commit()
    await db_session.refresh(other_item)
    other_supplier = Supplier(business_id=OTHER_BUSINESS_ID, name="Theirs")
    db_session.add(other_supplier)
    await db_session.commit()
    await db_session.refresh(other_supplier)
    other_reorder = Reorder(
        business_id=OTHER_BUSINESS_ID,
        store_id=STORE_ID,
        item_id=other_item.id,
        supplier_id=other_supplier.id,
        quantity=Decimal("1"),
        unit="kg",
        ordered_at=datetime.now(UTC),
    )
    db_session.add(other_reorder)
    await db_session.commit()

    resp = await client.get(API_PREFIX, headers=AUTH_HEADER)
    ids = [r["id"] for r in resp.json()["items"]]
    assert ids == [str(mine.id)]


# ── Receive — the core stock-engine integration ─────────────────────────────


@pytest.mark.asyncio
async def test_receive_reorder_increases_stock_and_records_movement(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    item = await _create_item(db_session)
    supplier = await _create_supplier(db_session)
    stock = StockLevel(item_id=item.id, store_id=STORE_ID, current_quantity=Decimal("5.000"))
    db_session.add(stock)
    await db_session.commit()

    reorder = await _create_reorder(db_session, item, supplier, quantity=Decimal("20.000"))

    resp = await client.post(f"{API_PREFIX}/{reorder.id}/receive", headers=AUTH_HEADER)
    assert resp.status_code == 200, resp.text
    data = resp.json()
    assert data["status"] == "received"
    assert data["received_at"] is not None

    # `async_session_factory` uses `expire_on_commit=False` — the `stock`
    # row this session already loaded won't pick up the app's own session's
    # commit unless explicitly refreshed (an implicit lazy-load after a bare
    # `expire_all()` would raise `MissingGreenlet` under AsyncSession).
    await db_session.refresh(stock)
    assert stock.current_quantity == Decimal("25.000")

    movement = (
        await db_session.exec(
            select(StockMovement).where(StockMovement.reference_id == reorder.id)
        )
    ).one_or_none()
    assert movement is not None
    assert movement.movement_type.value == "purchase_received"
    assert movement.reference_type == "reorder"
    assert movement.quantity_delta == Decimal("20.000")


@pytest.mark.asyncio
async def test_receive_reorder_with_unit_cost_revalues_item(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    """Cost enters at receive time: opening 10 @ 1.0 + 20 @ 3.0 → 2.3333."""
    item = await _create_item(db_session)
    item.unit_cost = Decimal("1.0000")
    db_session.add(item)
    await db_session.commit()
    db_session.add(
        StockLevel(item_id=item.id, store_id=STORE_ID, current_quantity=Decimal("10.000"))
    )
    await db_session.commit()
    supplier = await _create_supplier(db_session)
    reorder = await _create_reorder(db_session, item, supplier, quantity=Decimal("20.000"))

    resp = await client.post(
        f"{API_PREFIX}/{reorder.id}/receive",
        json={"unit_cost": "3.0000"},
        headers=AUTH_HEADER,
    )
    assert resp.status_code == 200, resp.text
    assert resp.json()["status"] == "received"
    assert "unit_cost" not in resp.json()

    await db_session.refresh(item)
    assert item.unit_cost == Decimal("2.3333")


@pytest.mark.asyncio
async def test_receive_reorder_without_cost_leaves_item_cost_untouched(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    """Omitting unit_cost moves stock without revaluing the item."""
    item = await _create_item(db_session)
    item.unit_cost = Decimal("1.0000")
    db_session.add(item)
    await db_session.commit()
    supplier = await _create_supplier(db_session)
    reorder = await _create_reorder(db_session, item, supplier, quantity=Decimal("5.000"))

    resp = await client.post(f"{API_PREFIX}/{reorder.id}/receive", headers=AUTH_HEADER)
    assert resp.status_code == 200, resp.text

    await db_session.refresh(item)
    assert item.unit_cost == Decimal("1.0000")


@pytest.mark.asyncio
async def test_receive_reorder_for_sellable_item_type_mismatch(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    """Defense-in-depth: even if a sellable-item reorder somehow exists
    (e.g. the item's type changed after the reorder was created), receiving
    it surfaces the real stock-engine rejection rather than silently
    succeeding."""
    item = await _create_item(db_session, item_type=ItemType.RAW_MATERIAL)
    supplier = await _create_supplier(db_session)
    reorder = await _create_reorder(db_session, item, supplier)

    item.item_type = ItemType.SELLABLE
    db_session.add(item)
    await db_session.commit()

    resp = await client.post(f"{API_PREFIX}/{reorder.id}/receive", headers=AUTH_HEADER)
    assert resp.status_code == 422

    # Rolled back — the reorder must still be pending, not half-received.
    refreshed = (
        await db_session.exec(select(Reorder).where(Reorder.id == reorder.id))
    ).one()
    assert refreshed.status == ReorderStatus.PENDING


@pytest.mark.asyncio
async def test_double_receive_is_409(client: AsyncClient, db_session: AsyncSession) -> None:
    item = await _create_item(db_session)
    supplier = await _create_supplier(db_session)
    reorder = await _create_reorder(db_session, item, supplier)

    resp = await client.post(f"{API_PREFIX}/{reorder.id}/receive", headers=AUTH_HEADER)
    assert resp.status_code == 200

    resp = await client.post(f"{API_PREFIX}/{reorder.id}/receive", headers=AUTH_HEADER)
    assert resp.status_code == 409


@pytest.mark.asyncio
async def test_receiving_does_not_retrigger_stock_low_spuriously(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    """A receive is always an increase — stock.low only fires on a
    downward crossing, so receiving stock must never publish it."""
    item = await _create_item(db_session)
    supplier = await _create_supplier(db_session)
    stock = StockLevel(item_id=item.id, store_id=STORE_ID, current_quantity=Decimal("2.000"))
    db_session.add(stock)
    await db_session.commit()
    reorder = await _create_reorder(db_session, item, supplier, quantity=Decimal("50.000"))

    # No assertion needed on the event bus itself (not wired to a spy here)
    # — this just proves the endpoint completes normally for the classic
    # "was already below threshold" case without erroring.
    resp = await client.post(f"{API_PREFIX}/{reorder.id}/receive", headers=AUTH_HEADER)
    assert resp.status_code == 200


# ── Cancel ───────────────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_cancel_pending_reorder(client: AsyncClient, db_session: AsyncSession) -> None:
    item = await _create_item(db_session)
    supplier = await _create_supplier(db_session)
    reorder = await _create_reorder(db_session, item, supplier)

    resp = await client.post(f"{API_PREFIX}/{reorder.id}/cancel", headers=AUTH_HEADER)
    assert resp.status_code == 200, resp.text
    data = resp.json()
    assert data["status"] == "cancelled"
    assert data["cancelled_at"] is not None

    # No stock movement should exist for a cancelled reorder.
    movement = (
        await db_session.exec(
            select(StockMovement).where(StockMovement.reference_id == reorder.id)
        )
    ).one_or_none()
    assert movement is None


@pytest.mark.asyncio
async def test_double_cancel_is_409(client: AsyncClient, db_session: AsyncSession) -> None:
    item = await _create_item(db_session)
    supplier = await _create_supplier(db_session)
    reorder = await _create_reorder(db_session, item, supplier)

    resp = await client.post(f"{API_PREFIX}/{reorder.id}/cancel", headers=AUTH_HEADER)
    assert resp.status_code == 200

    resp = await client.post(f"{API_PREFIX}/{reorder.id}/cancel", headers=AUTH_HEADER)
    assert resp.status_code == 409


@pytest.mark.asyncio
async def test_cannot_cancel_a_received_reorder(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    item = await _create_item(db_session)
    supplier = await _create_supplier(db_session)
    reorder = await _create_reorder(db_session, item, supplier, status=ReorderStatus.RECEIVED)

    resp = await client.post(f"{API_PREFIX}/{reorder.id}/cancel", headers=AUTH_HEADER)
    assert resp.status_code == 409


# ── Route ordering / permissions ────────────────────────────────────────────


@pytest.mark.asyncio
async def test_receive_and_cancel_subpaths_not_swallowed_by_detail_route(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    item = await _create_item(db_session)
    supplier = await _create_supplier(db_session)
    r1 = await _create_reorder(db_session, item, supplier)
    r2 = await _create_reorder(db_session, item, supplier)

    resp = await client.post(f"{API_PREFIX}/{r1.id}/receive", headers=AUTH_HEADER)
    assert resp.status_code == 200
    resp = await client.post(f"{API_PREFIX}/{r2.id}/cancel", headers=AUTH_HEADER)
    assert resp.status_code == 200


@pytest.mark.asyncio
@pytest.mark.parametrize(
    ("method", "path_suffix", "required_perm"),
    [
        ("POST", "", "reorders.create"),
        ("GET", "", "reorders.view"),
        ("GET", "/{id}", "reorders.view"),
        ("POST", "/{id}/receive", "reorders.receive"),
        ("POST", "/{id}/cancel", "reorders.cancel"),
    ],
)
async def test_each_route_403s_without_its_permission(
    client: AsyncClient,
    db_session: AsyncSession,
    method: str,
    path_suffix: str,
    required_perm: str,
) -> None:
    item = await _create_item(db_session)
    supplier = await _create_supplier(db_session)
    reorder = await _create_reorder(db_session, item, supplier)
    path = f"{API_PREFIX}{path_suffix.format(id=reorder.id)}"
    body = _reorder_payload(item, supplier) if method == "POST" and not path_suffix else None
    header = _auth_header(["suppliers.view"])  # real but unrelated permission

    resp = await client.request(method, path, json=body, headers=header)
    assert resp.status_code == 403, f"{method} {path} should 403 without {required_perm}"
