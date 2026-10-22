"""Integration tests for item management endpoints (Stage 4).

Every test uses a real Postgres-backed session and a signed JWT so that
the full auth + permission stack is exercised.
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
from app.models.inventory import Item, ItemType, StockLevel
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
API_PREFIX = f"/api/v1/businesses/{BUSINESS_ID}/items"


# ── Helpers ─────────────────────────────────────────────────────────────────


def _auth_header(permissions: list[str] | None = None) -> dict[str, str]:
    return {"Authorization": f"Bearer {_build_token(permissions=permissions)}"}


def _other_biz_header() -> dict[str, str]:
    """Token scoped to OTHER_BUSINESS_ID with all inventory permissions."""
    token = _build_token(active_business_id=str(OTHER_BUSINESS_ID))
    return {"Authorization": f"Bearer {token}"}


async def _kg_unit_id(session: AsyncSession) -> UUID:
    result = await session.exec(select(Unit).where(Unit.code == "kg"))
    return result.one().id


async def _create_test_item(
    session: AsyncSession,
    name: str = "Test Item",
    store_id: UUID = STORE_ID,
    reorder_threshold: Decimal = Decimal("10.000"),
    reorder_quantity: Decimal = Decimal("20.000"),
    item_type: ItemType = ItemType.BOTH,
) -> Item:
    item = Item(
        business_id=BUSINESS_ID,
        store_id=store_id,
        name=name,
        unit_id=await _kg_unit_id(session),
        reorder_threshold=reorder_threshold,
        reorder_quantity=reorder_quantity,
        item_type=item_type,
    )
    session.add(item)
    await session.commit()
    await session.refresh(item)
    return item


async def _create_stock_level(
    session: AsyncSession,
    item_id: UUID,
    store_id: UUID = STORE_ID,
    quantity: Decimal = Decimal("5.000"),
) -> StockLevel:
    sl = StockLevel(
        item_id=item_id,
        store_id=store_id,
        current_quantity=quantity,
    )
    session.add(sl)
    await session.commit()
    await session.refresh(sl)
    return sl


# ── Tests ────────────────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_full_crud_cycle(
    client: AsyncClient, db_session: AsyncSession, produce_category_id: str, kg_unit_id: str
) -> None:
    """Create → read → update → soft-delete → confirm row still exists."""
    # Create
    create_payload = {
        "name": "Fresh Tomatoes",
        "unit_id": kg_unit_id,
        "category_id": produce_category_id,
        "reorder_threshold": 10.0,
        "reorder_quantity": 50.0,
        "allow_negative_stock": False,
        "item_type": "raw_material",
        "store_id": str(STORE_ID),
    }
    resp = await client.post(API_PREFIX, json=create_payload, headers=AUTH_HEADER)
    assert resp.status_code == 201, resp.text
    data = resp.json()
    item_id = data["id"]
    assert data["name"] == "Fresh Tomatoes"
    assert data["business_id"] == str(BUSINESS_ID)
    assert data["item_type"] == "raw_material"
    assert data["is_active"] is True

    # Read single
    resp = await client.get(f"{API_PREFIX}/{item_id}", headers=AUTH_HEADER)
    assert resp.status_code == 200
    assert resp.json()["name"] == "Fresh Tomatoes"

    # Update
    update_payload = {"name": "Roma Tomatoes"}
    resp = await client.patch(f"{API_PREFIX}/{item_id}", json=update_payload, headers=AUTH_HEADER)
    assert resp.status_code == 200, resp.text
    assert resp.json()["name"] == "Roma Tomatoes"

    # Soft-delete
    resp = await client.delete(f"{API_PREFIX}/{item_id}", headers=AUTH_HEADER)
    assert resp.status_code == 204, resp.text

    # Confirm row still exists with is_active=false
    async with db_session as s:
        result = await s.exec(select(Item).where(Item.id == UUID(item_id)))
        db_item = result.one()
        assert db_item.is_active is False
        assert db_item.name == "Roma Tomatoes"


# ── Selling price (add-selling-price task) ──────────────────────────────────


@pytest.mark.asyncio
async def test_create_item_with_selling_price(client: AsyncClient, each_unit_id: str) -> None:
    """Creating an item with selling_price stores and returns it."""
    payload = {
        "name": "Jollof Rice",
        "unit_id": each_unit_id,
        "item_type": "sellable",
        "reorder_threshold": 10.0,
        "reorder_quantity": 50.0,
        "selling_price": 25.5,
        "store_id": str(STORE_ID),
    }
    resp = await client.post(API_PREFIX, json=payload, headers=AUTH_HEADER)
    assert resp.status_code == 201, resp.text
    data = resp.json()
    assert Decimal(data["selling_price"]) == Decimal("25.50")
    assert data["name"] == "Jollof Rice"


@pytest.mark.asyncio
async def test_create_item_without_selling_price_succeeds(
    client: AsyncClient, kg_unit_id: str
) -> None:
    """Omitting selling_price is genuinely optional — not silently required."""
    payload = {
        "name": "Raw Flour",
        "unit_id": kg_unit_id,
        "item_type": "raw_material",
        "reorder_threshold": 10.0,
        "reorder_quantity": 50.0,
        "store_id": str(STORE_ID),
    }
    resp = await client.post(API_PREFIX, json=payload, headers=AUTH_HEADER)
    assert resp.status_code == 201, resp.text
    assert resp.json()["selling_price"] is None


@pytest.mark.asyncio
async def test_update_selling_price_via_patch(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    """PATCH selling_price updates the stored value."""
    item = await _create_test_item(db_session)
    resp = await client.patch(
        f"{API_PREFIX}/{item.id}",
        json={"selling_price": 30.0},
        headers=AUTH_HEADER,
    )
    assert resp.status_code == 200, resp.text
    assert Decimal(resp.json()["selling_price"]) == Decimal("30.00")


@pytest.mark.asyncio
async def test_selling_price_round_trips_without_drift(
    client: AsyncClient, each_unit_id: str
) -> None:
    """selling_price survives create + read + patch without floating-point drift.

    The price is sent as a JSON string (exact Decimal) — a float in JSON
    would already be imprecise before Pydantic sees it.  The response
    serializes Decimal back as a string, so assertions compare Decimal
    values to prove exact round-tripping.
    """
    payload = {
        "name": "Precision Item",
        "unit_id": each_unit_id,
        "item_type": "both",
        "reorder_threshold": 10.0,
        "reorder_quantity": 50.0,
        "selling_price": "0.30",
        "store_id": str(STORE_ID),
    }
    resp = await client.post(API_PREFIX, json=payload, headers=AUTH_HEADER)
    assert resp.status_code == 201, resp.text
    data = resp.json()
    assert Decimal(data["selling_price"]) == Decimal("0.30")

    item_id = data["id"]
    resp = await client.get(f"{API_PREFIX}/{item_id}", headers=AUTH_HEADER)
    assert resp.status_code == 200
    assert Decimal(resp.json()["selling_price"]) == Decimal("0.30")

    resp = await client.patch(
        f"{API_PREFIX}/{item_id}",
        json={"selling_price": "0.10"},
        headers=AUTH_HEADER,
    )
    assert resp.status_code == 200, resp.text
    assert Decimal(resp.json()["selling_price"]) == Decimal("0.10")


# ── Unit cost (add-unit_cost task) ──────────────────────────────────────────


@pytest.mark.asyncio
async def test_create_item_with_unit_cost(client: AsyncClient, kg_unit_id: str) -> None:
    """Creating an item with unit_cost stores and returns it, independent of
    selling_price."""
    payload = {
        "name": "Raw Flour",
        "unit_id": kg_unit_id,
        "item_type": "raw_material",
        "reorder_threshold": 10.0,
        "reorder_quantity": 50.0,
        "unit_cost": "2.4500",
        "store_id": str(STORE_ID),
    }
    resp = await client.post(API_PREFIX, json=payload, headers=AUTH_HEADER)
    assert resp.status_code == 201, resp.text
    data = resp.json()
    assert Decimal(data["unit_cost"]) == Decimal("2.4500")
    assert data["selling_price"] is None


@pytest.mark.asyncio
async def test_update_unit_cost_via_patch(client: AsyncClient, db_session: AsyncSession) -> None:
    """PATCH unit_cost updates the stored value."""
    item = await _create_test_item(db_session)
    resp = await client.patch(
        f"{API_PREFIX}/{item.id}",
        json={"unit_cost": "3.1000"},
        headers=AUTH_HEADER,
    )
    assert resp.status_code == 200, resp.text
    assert Decimal(resp.json()["unit_cost"]) == Decimal("3.1000")


@pytest.mark.asyncio
async def test_item_type_omitted_is_rejected(client: AsyncClient, each_unit_id: str) -> None:
    """Confirm the Stage 2 follow-up is enforced all the way through the API."""
    payload = {
        "name": "No Type Item",
        "unit_id": each_unit_id,
        "reorder_threshold": 5.0,
        "reorder_quantity": 10.0,
        "store_id": str(STORE_ID),
    }
    resp = await client.post(API_PREFIX, json=payload, headers=AUTH_HEADER)
    assert resp.status_code == 422, resp.text


@pytest.mark.asyncio
async def test_soft_deleted_item_still_viewable(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    """GET single item returns a soft-deleted item (does not 404)."""
    item = await _create_test_item(db_session)
    # Soft-delete via API
    resp = await client.delete(f"{API_PREFIX}/{item.id}", headers=AUTH_HEADER)
    assert resp.status_code == 204

    # Still viewable
    resp = await client.get(f"{API_PREFIX}/{item.id}", headers=AUTH_HEADER)
    assert resp.status_code == 200
    assert resp.json()["is_active"] is False


@pytest.mark.asyncio
async def test_list_below_threshold(
    client: AsyncClient,
    db_session: AsyncSession,
) -> None:
    """below_threshold=true returns only items at or below reorder_threshold."""
    # Item A: threshold 10, stock 5 → below
    # Item B: threshold 10, stock 15 → not below
    # Item C: threshold 10, no stock level → not below (no join match)
    item_a = await _create_test_item(
        db_session, name="Low Stock Item", reorder_threshold=Decimal("10.000")
    )
    item_b = await _create_test_item(
        db_session, name="Well Stocked Item", reorder_threshold=Decimal("10.000")
    )
    _item_c = await _create_test_item(
        db_session, name="No Stock Item", reorder_threshold=Decimal("10.000")
    )

    await _create_stock_level(db_session, item_id=item_a.id, quantity=Decimal("5.000"))
    await _create_stock_level(db_session, item_id=item_b.id, quantity=Decimal("15.000"))

    resp = await client.get(f"{API_PREFIX}?below_threshold=true", headers=AUTH_HEADER)
    assert resp.status_code == 200
    names = [i["name"] for i in resp.json()]
    assert "Low Stock Item" in names
    assert "Well Stocked Item" not in names
    assert "No Stock Item" not in names


@pytest.mark.asyncio
async def test_list_no_auth_returns_403(client: AsyncClient) -> None:
    """Requests without the required permission are rejected."""
    restricted = _auth_header(permissions=["pos.write"])
    resp = await client.get(API_PREFIX, headers=restricted)
    assert resp.status_code == 403


@pytest.mark.asyncio
async def test_create_no_adjust_perm_returns_403(client: AsyncClient, kg_unit_id: str) -> None:
    payload = {
        "name": "Any",
        "unit_id": kg_unit_id,
        "reorder_threshold": 1.0,
        "reorder_quantity": 2.0,
        "item_type": "both",
        "store_id": str(STORE_ID),
    }
    restricted = _auth_header(permissions=["inventory.view"])
    resp = await client.post(API_PREFIX, json=payload, headers=restricted)
    assert resp.status_code == 403


@pytest.mark.asyncio
async def test_update_no_adjust_perm_returns_403(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    item = await _create_test_item(db_session)
    restricted = _auth_header(permissions=["inventory.view"])
    resp = await client.patch(
        f"{API_PREFIX}/{item.id}", json={"name": "Hacked"}, headers=restricted
    )
    assert resp.status_code == 403


@pytest.mark.asyncio
async def test_delete_no_adjust_perm_returns_403(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    item = await _create_test_item(db_session)
    restricted = _auth_header(permissions=["inventory.view"])
    resp = await client.delete(f"{API_PREFIX}/{item.id}", headers=restricted)
    assert resp.status_code == 403


@pytest.mark.asyncio
async def test_get_returns_404_for_nonexistent_item(client: AsyncClient) -> None:
    fake_id = UUID("ffffffff-ffff-ffff-ffff-ffffffffffff")
    resp = await client.get(f"{API_PREFIX}/{fake_id}", headers=AUTH_HEADER)
    assert resp.status_code == 404


@pytest.mark.asyncio
async def test_update_empty_body_returns_400(client: AsyncClient, db_session: AsyncSession) -> None:
    item = await _create_test_item(db_session)
    resp = await client.patch(f"{API_PREFIX}/{item.id}", json={}, headers=AUTH_HEADER)
    assert resp.status_code == 400


@pytest.mark.asyncio
async def test_delete_already_inactive_returns_409(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    item = await _create_test_item(db_session)
    await client.delete(f"{API_PREFIX}/{item.id}", headers=AUTH_HEADER)
    resp = await client.delete(f"{API_PREFIX}/{item.id}", headers=AUTH_HEADER)
    assert resp.status_code == 409


@pytest.mark.asyncio
async def test_pagination_behaves_correctly(client: AsyncClient, db_session: AsyncSession) -> None:
    """Limit/offset returns correct items."""
    for i in range(5):
        await _create_test_item(db_session, name=f"Item {i}")

    resp = await client.get(f"{API_PREFIX}?limit=2&offset=0", headers=AUTH_HEADER)
    assert resp.status_code == 200
    page1 = resp.json()
    assert len(page1) == 2  # noqa: PLR2004

    resp = await client.get(f"{API_PREFIX}?limit=2&offset=2", headers=AUTH_HEADER)
    assert resp.status_code == 200
    page2 = resp.json()
    assert len(page2) == 2  # noqa: PLR2004
    assert page2[0]["id"] != page1[0]["id"]


@pytest.mark.asyncio
async def test_list_filters_by_category(
    client: AsyncClient, db_session: AsyncSession, produce_category_id: str
) -> None:
    await _create_test_item(
        db_session,
        name="Apple",
    )
    item2 = await _create_test_item(db_session, name="Banana")
    item2.category_id = UUID(produce_category_id)
    db_session.add(item2)
    await db_session.commit()

    resp = await client.get(f"{API_PREFIX}?category_id={produce_category_id}", headers=AUTH_HEADER)
    assert resp.status_code == 200
    names = [i["name"] for i in resp.json()]
    assert "Banana" in names
    assert "Apple" not in names


# ── Stage 8.5 — Gap 1: Business-context binding ────────────────────────────


@pytest.mark.asyncio
async def test_wrong_business_rejected_for_list(
    client: AsyncClient,
    db_session: AsyncSession,
) -> None:
    """Token for business X is rejected when calling endpoint for business Y."""
    await _create_test_item(db_session, name="Visible Item")
    wrong_url = f"/api/v1/businesses/{OTHER_BUSINESS_ID}/items"
    resp = await client.get(wrong_url, headers=AUTH_HEADER)
    assert resp.status_code == 403


@pytest.mark.asyncio
async def test_wrong_business_rejected_for_create(
    client: AsyncClient,
    db_session: AsyncSession,
    kg_unit_id: str,
) -> None:
    wrong_url = f"/api/v1/businesses/{OTHER_BUSINESS_ID}/items"
    payload = {
        "name": "Should Not Create",
        "unit_id": kg_unit_id,
        "reorder_threshold": 1.0,
        "reorder_quantity": 2.0,
        "item_type": "both",
        "store_id": str(STORE_ID),
    }
    resp = await client.post(wrong_url, json=payload, headers=AUTH_HEADER)
    assert resp.status_code == 403


# ── Stage 8.5 — Gap 3: Fine-grained permission remap ───────────────────────


@pytest.mark.asyncio
async def test_create_requires_items_create_perm(client: AsyncClient, kg_unit_id: str) -> None:
    """Token with old INVENTORY_ADJUST (but not items.create) is rejected."""
    payload = {
        "name": "Needs Create",
        "unit_id": kg_unit_id,
        "reorder_threshold": 1.0,
        "reorder_quantity": 2.0,
        "item_type": "both",
        "store_id": str(STORE_ID),
    }
    old_token = _auth_header(permissions=["inventory.view", "inventory.adjust"])
    resp = await client.post(API_PREFIX, json=payload, headers=old_token)
    assert resp.status_code == 403, (
        "Old INVENTORY_ADJUST should no longer grant create — inventory.items.create is required"
    )


@pytest.mark.asyncio
async def test_update_requires_items_update_perm(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    item = await _create_test_item(db_session)
    old_token = _auth_header(permissions=["inventory.view", "inventory.adjust"])
    resp = await client.patch(
        f"{API_PREFIX}/{item.id}", json={"name": "Should Fail"}, headers=old_token
    )
    assert resp.status_code == 403


@pytest.mark.asyncio
async def test_deactivate_requires_items_deactivate_perm(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    item = await _create_test_item(db_session)
    old_token = _auth_header(permissions=["inventory.view", "inventory.adjust"])
    resp = await client.delete(f"{API_PREFIX}/{item.id}", headers=old_token)
    assert resp.status_code == 403
