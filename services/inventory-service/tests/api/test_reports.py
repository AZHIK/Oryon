"""Integration tests for reporting endpoints (Stage 8).

Tests the HTTP layer — stock levels and movement history — through the
full auth + permission stack with a real Postgres-backed session.
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
from app.models.categories import Category
from app.models.inventory import (
    ActorType,
    Item,
    ItemType,
    MovementType,
    StockMovement,
)
from app.models.units import Unit
from app.services.stock_movement_service import record_movement

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
-----END RSA PRIVATE KEY-----"""


ALL_INVENTORY_PERMS = [
    "inventory.view",
    "inventory.items.create",
    "inventory.items.update",
    "inventory.items.deactivate",
    "inventory.adjust",
    "inventory.waste.record",
    "inventory.transfer",
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
        "permissions": permissions or ALL_INVENTORY_PERMS,
        "active_business_id": active_business_id,
    }
    return jwt.encode(payload, TEST_PRIVATE_KEY, algorithm=settings.jwt_algorithm)


BUSINESS_ID = UUID("00000000-0000-0000-0000-000000000001")
OTHER_BUSINESS_ID = UUID("00000000-0000-0000-0000-000000000099")
STORE_ID = UUID("00000000-0000-0000-0000-000000000010")
STORE_ID_2 = UUID("00000000-0000-0000-0000-000000000020")
AUTH_HEADER = {"Authorization": f"Bearer {_build_token()}"}
STOCK_URL = f"/api/v1/businesses/{BUSINESS_ID}/stock"


def _auth_header(permissions: list[str] | None = None) -> dict[str, str]:
    return {"Authorization": f"Bearer {_build_token(permissions=permissions)}"}


def _other_biz_header() -> dict[str, str]:
    token = _build_token(active_business_id=str(OTHER_BUSINESS_ID))
    return {"Authorization": f"Bearer {token}"}


async def _category_id(session: AsyncSession, code: str) -> UUID:
    """Look up a seeded category's id by its stable code (see
    ``f1a2b3c4d5e6_create_category_and_migrate_item_category.py``)."""
    result = await session.exec(select(Category).where(Category.code == code))
    return result.one().id


async def _unit_id(session: AsyncSession, code: str = "kg") -> UUID:
    """Look up a seeded unit's id by its stable code (see
    ``a7b8c9d0e1f2_create_unit_and_migrate_item_unit.py``)."""
    result = await session.exec(select(Unit).where(Unit.code == code))
    return result.one().id


async def _create_item(
    session: AsyncSession,
    name: str = "Test Item",
    store_id: UUID = STORE_ID,
    item_type: ItemType = ItemType.BOTH,
    category_code: str | None = "produce",
    reorder_threshold: Decimal = Decimal("10.000"),
) -> Item:
    item = Item(
        business_id=BUSINESS_ID,
        store_id=store_id,
        name=name,
        unit_id=await _unit_id(session),
        category_id=await _category_id(session, category_code) if category_code else None,
        reorder_threshold=reorder_threshold,
        reorder_quantity=Decimal("20.000"),
        allow_negative_stock=True,
        item_type=item_type,
    )
    session.add(item)
    await session.commit()
    await session.refresh(item)
    return item


# ═══════════════════════════════════════════════════════════════════════
# GET /stock  —  stock levels
# ═══════════════════════════════════════════════════════════════════════


@pytest.mark.asyncio
async def test_stock_levels_after_movements(
    client: AsyncClient,
    db_session: AsyncSession,
) -> None:
    """GET /stock returns correct current_quantity values after a mix of movements.

    Uses ``record_movement`` (the same function the system actually uses)
    for setup so this test verifies the reporting layer, not the movement
    math (which is already covered in Stage 5).
    """
    item_a = await _create_item(db_session, name="Item A")
    item_b = await _create_item(db_session, name="Item B")

    await record_movement(
        db=db_session,
        item_id=item_a.id,
        business_id=BUSINESS_ID,
        store_id=STORE_ID,
        quantity_delta=Decimal("10.000"),
        movement_type=MovementType.MANUAL_ADJUSTMENT,
        actor_type=ActorType.USER.value,
        reason="Test setup",
    )
    await record_movement(
        db=db_session,
        item_id=item_b.id,
        business_id=BUSINESS_ID,
        store_id=STORE_ID,
        quantity_delta=Decimal("5.000"),
        movement_type=MovementType.MANUAL_ADJUSTMENT,
        actor_type=ActorType.USER.value,
        reason="Test setup",
    )
    await record_movement(
        db=db_session,
        item_id=item_a.id,
        business_id=BUSINESS_ID,
        store_id=STORE_ID,
        quantity_delta=Decimal("-3.000"),
        movement_type=MovementType.MANUAL_ADJUSTMENT,
        actor_type=ActorType.USER.value,
        reason="Test setup",
    )

    resp = await client.get(STOCK_URL, headers=AUTH_HEADER)
    assert resp.status_code == 200, resp.text
    data = resp.json()

    by_name = {r["item_name"]: r["current_quantity"] for r in data}
    assert by_name["Item A"] == "7.000"
    assert by_name["Item B"] == "5.000"


@pytest.mark.asyncio
async def test_stock_below_threshold(
    client: AsyncClient,
    db_session: AsyncSession,
) -> None:
    """below_threshold=true returns only items at or below reorder_threshold.

    Uses the SAME predicate as Stage 4's item-list below_threshold filter:
    ``StockLevel.current_quantity <= Item.reorder_threshold``.
    """
    # Item A: threshold 10, stock 5 -> below
    # Item B: threshold 10, stock 15 -> not below
    # Item C: no stock level -> not in stock report (inner join)
    item_a = await _create_item(
        db_session, name="Low Stock", reorder_threshold=Decimal("10.000")
    )
    item_b = await _create_item(
        db_session, name="Well Stocked", reorder_threshold=Decimal("10.000")
    )
    await _create_item(db_session, name="No Stock Item", reorder_threshold=Decimal("10.000"))

    await record_movement(
        db=db_session,
        item_id=item_a.id,
        business_id=BUSINESS_ID,
        store_id=STORE_ID,
        quantity_delta=Decimal("5.000"),
        movement_type=MovementType.MANUAL_ADJUSTMENT,
        actor_type=ActorType.USER.value,
    )
    await record_movement(
        db=db_session,
        item_id=item_b.id,
        business_id=BUSINESS_ID,
        store_id=STORE_ID,
        quantity_delta=Decimal("15.000"),
        movement_type=MovementType.MANUAL_ADJUSTMENT,
        actor_type=ActorType.USER.value,
    )

    resp = await client.get(f"{STOCK_URL}?below_threshold=true", headers=AUTH_HEADER)
    assert resp.status_code == 200, resp.text
    names = [r["item_name"] for r in resp.json()]
    assert "Low Stock" in names
    assert "Well Stocked" not in names
    assert "No Stock Item" not in names


@pytest.mark.asyncio
async def test_stock_includes_item_details(
    client: AsyncClient,
    db_session: AsyncSession,
) -> None:
    """GET /stock returns denormalized item fields without a separate query per item."""
    item = await _create_item(
        db_session,
        name="Detail Check",
        category_code="dry",
        reorder_threshold=Decimal("5.000"),
        item_type=ItemType.SELLABLE,
    )
    await record_movement(
        db=db_session,
        item_id=item.id,
        business_id=BUSINESS_ID,
        store_id=STORE_ID,
        quantity_delta=Decimal("10.000"),
        movement_type=MovementType.MANUAL_ADJUSTMENT,
        actor_type=ActorType.USER.value,
    )

    resp = await client.get(STOCK_URL, headers=AUTH_HEADER)
    assert resp.status_code == 200, resp.text
    data = resp.json()
    assert len(data) == 1
    row = data[0]

    assert row["item_name"] == "Detail Check"
    assert row["item_unit_of_measure"] == "kg"
    assert row["item_category"] == "Dry goods"
    assert row["item_reorder_threshold"] == "5.000"
    assert row["item_type"] == "sellable"
    assert row["current_quantity"] is not None
    assert row["item_id"] == str(item.id)
    assert row["store_id"] == str(STORE_ID)


@pytest.mark.asyncio
async def test_stock_filters_by_category(
    client: AsyncClient,
    db_session: AsyncSession,
) -> None:
    item_a = await _create_item(db_session, name="Produce Item", category_code="produce")
    item_b = await _create_item(db_session, name="Dairy Item", category_code="dairy")
    for i in (item_a, item_b):
        await record_movement(
            db=db_session,
            item_id=i.id,
            business_id=BUSINESS_ID,
            store_id=STORE_ID,
            quantity_delta=Decimal("10.000"),
            movement_type=MovementType.MANUAL_ADJUSTMENT,
            actor_type=ActorType.USER.value,
        )

    resp = await client.get(f"{STOCK_URL}?category_id={item_b.category_id}", headers=AUTH_HEADER)
    assert resp.status_code == 200, resp.text
    names = [r["item_name"] for r in resp.json()]
    assert "Dairy Item" in names
    assert "Produce Item" not in names


@pytest.mark.asyncio
async def test_stock_filters_by_store(
    client: AsyncClient,
    db_session: AsyncSession,
) -> None:
    item = await _create_item(db_session, name="Located Item", store_id=STORE_ID_2)
    await record_movement(
        db=db_session,
        item_id=item.id,
        business_id=BUSINESS_ID,
        store_id=STORE_ID_2,
        quantity_delta=Decimal("10.000"),
        movement_type=MovementType.MANUAL_ADJUSTMENT,
        actor_type=ActorType.USER.value,
    )

    resp = await client.get(
        f"{STOCK_URL}?store_id={STORE_ID_2}", headers=AUTH_HEADER
    )
    assert resp.status_code == 200, resp.text
    data = resp.json()
    assert len(data) == 1
    assert data[0]["store_id"] == str(STORE_ID_2)


# ═══════════════════════════════════════════════════════════════════════
# GET /businesses/{business_id}/items/{item_id}/movements
# ═══════════════════════════════════════════════════════════════════════


@pytest.mark.asyncio
async def test_movements_filtered_by_date_range(
    client: AsyncClient,
    db_session: AsyncSession,
) -> None:
    item = await _create_item(db_session, name="Date Test Item")

    for delta, mtype in [
        (Decimal("10.000"), MovementType.MANUAL_ADJUSTMENT),
        (Decimal("-2.000"), MovementType.WASTE),
        (Decimal("5.000"), MovementType.MANUAL_ADJUSTMENT),
    ]:
        await record_movement(
            db=db_session,
            item_id=item.id,
            business_id=BUSINESS_ID,
            store_id=STORE_ID,
            quantity_delta=delta,
            movement_type=mtype,
            actor_type=ActorType.USER.value,
        )

    movements_db = await db_session.exec(
        select(StockMovement)
        .where(StockMovement.item_id == item.id)
        .order_by(StockMovement.created_at.asc())
    )
    all_movements = list(movements_db.all())
    assert len(all_movements) >= 3, "Need at least 3 movements for date tests"

    mid = all_movements[1]
    mid_time = mid.created_at

    from_date = mid_time.date()
    to_date = mid_time.date()

    url = (
        f"/api/v1/businesses/{BUSINESS_ID}/items/{item.id}/movements"
        f"?from={from_date.isoformat()}&to={to_date.isoformat()}"
    )
    resp = await client.get(url, headers=AUTH_HEADER)
    assert resp.status_code == 200, resp.text
    data = resp.json()
    assert len(data) >= 1
    for row in data:
        row_dt = datetime.fromisoformat(row["created_at"]).date()
        assert from_date <= row_dt <= to_date


@pytest.mark.asyncio
async def test_movements_filtered_by_movement_type(
    client: AsyncClient,
    db_session: AsyncSession,
) -> None:
    item = await _create_item(db_session, name="Type Filter Item")

    for delta, mtype in [
        (Decimal("10.000"), MovementType.MANUAL_ADJUSTMENT),
        (Decimal("5.000"), MovementType.PURCHASE_RECEIVED),
        (Decimal("-3.000"), MovementType.MANUAL_ADJUSTMENT),
    ]:
        await record_movement(
            db=db_session,
            item_id=item.id,
            business_id=BUSINESS_ID,
            store_id=STORE_ID,
            quantity_delta=delta,
            movement_type=mtype,
            actor_type=ActorType.USER.value,
        )

    url = f"/api/v1/businesses/{BUSINESS_ID}/items/{item.id}/movements"
    resp = await client.get(f"{url}?movement_type=purchase_received", headers=AUTH_HEADER)
    assert resp.status_code == 200, resp.text
    data = resp.json()
    assert len(data) == 1
    assert data[0]["movement_type"] == "purchase_received"


@pytest.mark.asyncio
async def test_movements_sorted_most_recent_first(
    client: AsyncClient,
    db_session: AsyncSession,
) -> None:
    item = await _create_item(db_session, name="Sort Test Item")

    for delta in [Decimal("10.000"), Decimal("-2.000"), Decimal("3.000")]:
        await record_movement(
            db=db_session,
            item_id=item.id,
            business_id=BUSINESS_ID,
            store_id=STORE_ID,
            quantity_delta=delta,
            movement_type=MovementType.MANUAL_ADJUSTMENT,
            actor_type=ActorType.USER.value,
        )

    url = f"/api/v1/businesses/{BUSINESS_ID}/items/{item.id}/movements"
    resp = await client.get(url, headers=AUTH_HEADER)
    assert resp.status_code == 200, resp.text
    data = resp.json()
    assert len(data) >= 3

    timestamps = [datetime.fromisoformat(r["created_at"]) for r in data]
    assert timestamps == sorted(timestamps, reverse=True), "Not sorted most-recent-first"


@pytest.mark.asyncio
async def test_movements_404_for_nonexistent_item(
    client: AsyncClient,
) -> None:
    fake_id = UUID("ffffffff-ffff-ffff-ffff-ffffffffffff")
    url = f"/api/v1/businesses/{BUSINESS_ID}/items/{fake_id}/movements"
    resp = await client.get(url, headers=AUTH_HEADER)
    assert resp.status_code == 404


@pytest.mark.asyncio
async def test_movements_filters_by_store(
    client: AsyncClient,
    db_session: AsyncSession,
) -> None:
    item = await _create_item(db_session, name="Store Filter Item")

    for lid in (STORE_ID, STORE_ID_2):
        await record_movement(
            db=db_session,
            item_id=item.id,
            business_id=BUSINESS_ID,
            store_id=lid,
            quantity_delta=Decimal("10.000"),
            movement_type=MovementType.MANUAL_ADJUSTMENT,
            actor_type=ActorType.USER.value,
        )

    url = f"/api/v1/businesses/{BUSINESS_ID}/items/{item.id}/movements"
    resp = await client.get(f"{url}?store_id={STORE_ID}", headers=AUTH_HEADER)
    assert resp.status_code == 200, resp.text
    data = resp.json()
    assert len(data) == 1
    assert data[0]["store_id"] == str(STORE_ID)


# ═══════════════════════════════════════════════════════════════════════
# Pagination
# ═══════════════════════════════════════════════════════════════════════


@pytest.mark.asyncio
async def test_stock_pagination(
    client: AsyncClient,
    db_session: AsyncSession,
) -> None:
    for i in range(5):
        item = await _create_item(db_session, name=f"Stock Page {i}")
        await record_movement(
            db=db_session,
            item_id=item.id,
            business_id=BUSINESS_ID,
            store_id=STORE_ID,
            quantity_delta=Decimal("10.000"),
            movement_type=MovementType.MANUAL_ADJUSTMENT,
            actor_type=ActorType.USER.value,
        )

    resp = await client.get(f"{STOCK_URL}?limit=2&offset=0", headers=AUTH_HEADER)
    assert resp.status_code == 200
    page1 = resp.json()
    assert len(page1) == 2

    resp = await client.get(f"{STOCK_URL}?limit=2&offset=2", headers=AUTH_HEADER)
    assert resp.status_code == 200
    page2 = resp.json()
    assert len(page2) == 2
    assert page2[0]["item_id"] != page1[0]["item_id"]


@pytest.mark.asyncio
async def test_movements_pagination(
    client: AsyncClient,
    db_session: AsyncSession,
) -> None:
    item = await _create_item(db_session, name="Movement Page Test")

    for i in range(5):
        await record_movement(
            db=db_session,
            item_id=item.id,
            business_id=BUSINESS_ID,
            store_id=STORE_ID,
            quantity_delta=Decimal(f"{i+1}.000"),
            movement_type=MovementType.MANUAL_ADJUSTMENT,
            actor_type=ActorType.USER.value,
        )

    url = f"/api/v1/businesses/{BUSINESS_ID}/items/{item.id}/movements"
    resp = await client.get(f"{url}?limit=2&offset=0", headers=AUTH_HEADER)
    assert resp.status_code == 200
    page1 = resp.json()
    assert len(page1) == 2

    resp = await client.get(f"{url}?limit=2&offset=2", headers=AUTH_HEADER)
    assert resp.status_code == 200
    page2 = resp.json()
    assert len(page2) == 2
    assert page2[0]["id"] != page1[0]["id"]


# ═══════════════════════════════════════════════════════════════════════
# Permission enforcement
# ═══════════════════════════════════════════════════════════════════════


@pytest.mark.asyncio
async def test_stock_no_view_perm_returns_403(
    client: AsyncClient,
) -> None:
    restricted = _auth_header(permissions=["pos.write"])
    resp = await client.get(STOCK_URL, headers=restricted)
    assert resp.status_code == 403


@pytest.mark.asyncio
async def test_movements_no_view_perm_returns_403(
    client: AsyncClient,
) -> None:
    fake_id = UUID("00000000-0000-0000-0000-000000000001")
    url = f"/api/v1/businesses/{BUSINESS_ID}/items/{fake_id}/movements"
    restricted = _auth_header(permissions=["pos.write"])
    resp = await client.get(url, headers=restricted)
    assert resp.status_code == 403


# ═══════════════════════════════════════════════════════════════════════
# Stage 8.5 — Gap 1: Business-context binding
# ═══════════════════════════════════════════════════════════════════════


@pytest.mark.asyncio
async def test_stock_wrong_business_rejected(
    client: AsyncClient,
    db_session: AsyncSession,
) -> None:
    """Token for business X is rejected when calling /stock for business Y."""
    wrong_url = f"/api/v1/businesses/{OTHER_BUSINESS_ID}/stock"
    resp = await client.get(wrong_url, headers=AUTH_HEADER)
    assert resp.status_code == 403
