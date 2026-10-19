"""Integration tests for scheduled production runs (Production Module).

Real Postgres (real Alembic chain, including the runs migration), real row
locks, signed JWTs — the full lifecycle: pending → in_progress →
completed → published, plus recipe batch formulas and cost math.
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
from app.models.inventory import (
    Item,
    ItemType,
    ProductionEvent,
    StockLevel,
)
from app.models.units import Unit

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
    "recipes.view",
    "recipes.create",
    "production.create",
    "production.view",
    "inventory.view",
    "inventory.items.create",
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
        "permissions": permissions if permissions is not None else list(ALL_PERMS),
        "active_business_id": active_business_id,
    }
    return jwt.encode(payload, TEST_PRIVATE_KEY, algorithm=settings.jwt_algorithm)


BUSINESS_ID = UUID("00000000-0000-0000-0000-000000000001")
STORE_ID = UUID("00000000-0000-0000-0000-000000000010")
AUTH_HEADER = {"Authorization": f"Bearer {_build_token()}"}
RECIPES_PREFIX = f"/api/v1/businesses/{BUSINESS_ID}/recipes"
RUNS_PREFIX = f"/api/v1/businesses/{BUSINESS_ID}/runs"
HISTORY_PREFIX = f"/api/v1/businesses/{BUSINESS_ID}/production-events"


def _auth_header(*codes: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {_build_token(permissions=list(codes))}"}


async def _kg_unit_id(session: AsyncSession) -> UUID:
    result = await session.exec(select(Unit).where(Unit.code == "kg"))
    return result.one().id


async def _create_test_item(
    session: AsyncSession,
    name: str,
    item_type: ItemType,
    unit_cost: str | None = None,
) -> Item:
    item = Item(
        business_id=BUSINESS_ID,
        store_id=STORE_ID,
        name=name,
        unit_id=await _kg_unit_id(session),
        reorder_threshold=Decimal("10.000"),
        reorder_quantity=Decimal("20.000"),
        unit_cost=Decimal(unit_cost) if unit_cost else None,
        item_type=item_type,
    )
    session.add(item)
    await session.commit()
    await session.refresh(item)
    return item


async def _set_stock(session: AsyncSession, item_id: UUID, quantity: str) -> None:
    session.add(StockLevel(item_id=item_id, store_id=STORE_ID,
                           current_quantity=Decimal(quantity)))
    await session.commit()


async def _level(session: AsyncSession, item_id: UUID) -> Decimal:
    result = await session.exec(
        select(StockLevel).where(
            StockLevel.item_id == item_id, StockLevel.store_id == STORE_ID
        )
    )
    row = result.one_or_none()
    return row.current_quantity if row else Decimal("0.000")


async def _make_pilau_kitchen(
    client: AsyncClient, db_session: AsyncSession
) -> tuple[Item, Item, Item, Item, UUID]:
    """Sellable Pilau + Rice/Meat/Oil with costs, stocked, recipe target 1."""
    pilau = await _create_test_item(db_session, "Pilau", ItemType.SELLABLE)
    rice = await _create_test_item(db_session, "Rice", ItemType.RAW_MATERIAL, "3200.0000")
    meat = await _create_test_item(db_session, "Meat", ItemType.RAW_MATERIAL, "14000.0000")
    oil = await _create_test_item(db_session, "Oil", ItemType.RAW_MATERIAL, "7500.0000")
    for item, qty in ((rice, "10.000"), (meat, "10.000"), (oil, "10.000"), (pilau, "0.000")):
        await _set_stock(db_session, item.id, qty)

    resp = await client.post(
        RECIPES_PREFIX,
        json={
            "sellable_item_id": str(pilau.id),
            "name": "Pilau",
            "category": "finished",
            "target_yield_quantity": "1.000",
            "target_yield_unit": "portions",
            "components": [
                {"raw_material_item_id": str(rice.id), "quantity_required": "0.200"},
                {"raw_material_item_id": str(meat.id), "quantity_required": "0.100"},
                {"raw_material_item_id": str(oil.id), "quantity_required": "0.020"},
            ],
        },
        headers=AUTH_HEADER,
    )
    assert resp.status_code == 201, resp.text
    return pilau, rice, meat, oil, UUID(resp.json()["id"])


async def _create_run(client: AsyncClient, recipe_id: UUID, target: str = "10.000") -> dict:
    resp = await client.post(
        RUNS_PREFIX,
        json={"recipe_id": str(recipe_id), "target_output_quantity": target},
        headers=AUTH_HEADER,
    )
    assert resp.status_code == 201, resp.text
    return resp.json()


# ── Tests ────────────────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_create_run_snapshots_plan_without_moving_stock(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    """Pending run freezes the recommendation; stock untouched."""
    _, rice, meat, oil, recipe_id = await _make_pilau_kitchen(client, db_session)

    data = await _create_run(client, recipe_id, "10.000")
    assert data["status"] == "pending"
    assert data["target_output_quantity"] == "10.000"
    assert data["published_at"] is None
    by_id = {c["raw_material_item_id"]: c for c in data["components"]}
    assert by_id[str(rice.id)]["planned_quantity"] == "2.000"
    assert by_id[str(meat.id)]["planned_quantity"] == "1.000"
    assert by_id[str(oil.id)]["planned_quantity"] == "0.200"
    assert by_id[str(rice.id)]["measured_quantity"] is None

    async with db_session as s:
        assert await _level(s, rice.id) == Decimal("10.000")


@pytest.mark.asyncio
async def test_full_lifecycle_plan_met(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    """start deducts, complete records, publish stocks + verdict within."""
    pilau, rice, meat, oil, recipe_id = await _make_pilau_kitchen(client, db_session)
    run = await _create_run(client, recipe_id, "10.000")
    run_id = run["id"]

    # Start with the plan weighed exactly.
    resp = await client.post(
        f"{RUNS_PREFIX}/{run_id}/start",
        json={"leading_item_id": str(rice.id), "leading_quantity_used": "2.000"},
        headers=AUTH_HEADER,
    )
    assert resp.status_code == 200, resp.text
    assert resp.json()["status"] == "in_progress"

    async with db_session as s:
        assert await _level(s, rice.id) == Decimal("8.000")
        assert await _level(s, meat.id) == Decimal("9.000")
        assert await _level(s, oil.id) == Decimal("9.800")
        # Output is NOT stocked yet — publishing does that.
        assert await _level(s, pilau.id) == Decimal("0.000")

    # Complete with plan-met actual + no waste.
    resp = await client.post(
        f"{RUNS_PREFIX}/{run_id}/complete",
        json={"actual_output_quantity": "10.000"},
        headers=AUTH_HEADER,
    )
    assert resp.status_code == 200, resp.text
    data = resp.json()
    assert data["status"] == "completed"
    assert data["yield_status"] == "within_threshold"

    async with db_session as s:
        assert await _level(s, pilau.id) == Decimal("0.000")

    # Publish: output stocked, history event with verdict.
    resp = await client.post(f"{RUNS_PREFIX}/{run_id}/publish", headers=AUTH_HEADER)
    assert resp.status_code == 200, resp.text
    event = resp.json()
    assert event["run_id"] == run_id
    assert event["actual_output_quantity"] == "10.000"
    assert event["yield_status"] == "within_threshold"

    async with db_session as s:
        assert await _level(s, pilau.id) == Decimal("10.000")


@pytest.mark.asyncio
async def test_shortfall_and_waste_reason_flow(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    """Adjusted start + 8/10 actual + spillage reason → below, reason kept."""
    pilau, rice, meat, oil, recipe_id = await _make_pilau_kitchen(client, db_session)
    run_id = (await _create_run(client, recipe_id, "10.000"))["id"]

    resp = await client.post(
        f"{RUNS_PREFIX}/{run_id}/start",
        json={
            "leading_item_id": str(rice.id),
            "leading_quantity_used": "2.200",
            "components": [
                {"raw_material_item_id": str(rice.id), "quantity_used": "2.200"},
                {"raw_material_item_id": str(meat.id), "quantity_used": "1.100"},
                {"raw_material_item_id": str(oil.id), "quantity_used": "0.220"},
            ],
        },
        headers=AUTH_HEADER,
    )
    assert resp.status_code == 200, resp.text

    resp = await client.post(
        f"{RUNS_PREFIX}/{run_id}/complete",
        json={"actual_output_quantity": "8.000", "waste_reason": "spillage while plating"},
        headers=AUTH_HEADER,
    )
    assert resp.status_code == 200, resp.text
    assert resp.json()["yield_status"] == "below"
    assert resp.json()["waste_reason"] == "spillage while plating"

    resp = await client.post(f"{RUNS_PREFIX}/{run_id}/publish", headers=AUTH_HEADER)
    assert resp.status_code == 200, resp.text
    assert resp.json()["waste_reason"] == "spillage while plating"
    assert resp.json()["yield_status"] == "below"

    async with db_session as s:
        assert await _level(s, pilau.id) == Decimal("8.000")
        events = (await s.exec(
            select(ProductionEvent).where(ProductionEvent.business_id == BUSINESS_ID)
        )).all()
        assert len(events) == 1
        assert str(events[0].run_id) == run_id


@pytest.mark.asyncio
async def test_start_rejected_on_shortfall_nothing_moves(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    """Meat covers 0.5 plates of a 10-plate plan → 409, run stays pending."""
    _, rice, meat, _, recipe_id = await _make_pilau_kitchen(client, db_session)
    async with db_session as s:
        row = (await s.exec(
            select(StockLevel).where(
                StockLevel.item_id == meat.id, StockLevel.store_id == STORE_ID)
        )).one()
        row.current_quantity = Decimal("0.050")
        s.add(row)
        await s.commit()

    run_id = (await _create_run(client, recipe_id, "10.000"))["id"]
    resp = await client.post(
        f"{RUNS_PREFIX}/{run_id}/start",
        json={"leading_item_id": str(rice.id), "leading_quantity_used": "2.000"},
        headers=AUTH_HEADER,
    )
    assert resp.status_code == 409, resp.text

    resp = await client.get(f"{RUNS_PREFIX}/{run_id}", headers=AUTH_HEADER)
    assert resp.json()["status"] == "pending"
    async with db_session as s:
        assert await _level(s, rice.id) == Decimal("10.000")


@pytest.mark.asyncio
async def test_illegal_transitions_rejected(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    """Complete-before-start, double-start, delete-started → 422.

    Publishing twice is the one deliberate exception: it is idempotent
    ("safe retry: tapping Publish twice returns the same record" — see
    ``app.services.run_service.publish_run``) and returns the existing
    event with 200.
    """
    _, rice, _, _, recipe_id = await _make_pilau_kitchen(client, db_session)
    run_id = (await _create_run(client, recipe_id, "10.000"))["id"]
    start_body = {"leading_item_id": str(rice.id), "leading_quantity_used": "2.000"}

    resp = await client.post(
        f"{RUNS_PREFIX}/{run_id}/complete",
        json={"actual_output_quantity": "10.000"}, headers=AUTH_HEADER)
    assert resp.status_code == 422, resp.text

    resp = await client.post(f"{RUNS_PREFIX}/{run_id}/publish", headers=AUTH_HEADER)
    assert resp.status_code == 422, resp.text

    resp = await client.post(
        f"{RUNS_PREFIX}/{run_id}/start", json=start_body, headers=AUTH_HEADER)
    assert resp.status_code == 200, resp.text

    resp = await client.post(
        f"{RUNS_PREFIX}/{run_id}/start", json=start_body, headers=AUTH_HEADER)
    assert resp.status_code == 422, resp.text

    resp = await client.delete(f"{RUNS_PREFIX}/{run_id}", headers=AUTH_HEADER)
    assert resp.status_code == 422, resp.text

    resp = await client.post(
        f"{RUNS_PREFIX}/{run_id}/complete",
        json={"actual_output_quantity": "10.000"}, headers=AUTH_HEADER)
    assert resp.status_code == 200, resp.text

    resp = await client.post(f"{RUNS_PREFIX}/{run_id}/publish", headers=AUTH_HEADER)
    assert resp.status_code == 200, resp.text
    first_event_id = resp.json()["id"]

    # Idempotent retry: the second publish returns the same event, not 422.
    resp = await client.post(f"{RUNS_PREFIX}/{run_id}/publish", headers=AUTH_HEADER)
    assert resp.status_code == 200, resp.text
    assert resp.json()["id"] == first_event_id


@pytest.mark.asyncio
async def test_delete_pending_run(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    """Pending plans are disposable; the recipe survives."""
    _, _, _, _, recipe_id = await _make_pilau_kitchen(client, db_session)
    run_id = (await _create_run(client, recipe_id, "10.000"))["id"]

    resp = await client.delete(f"{RUNS_PREFIX}/{run_id}", headers=AUTH_HEADER)
    assert resp.status_code == 204, resp.text

    resp = await client.get(f"{RUNS_PREFIX}/{run_id}", headers=AUTH_HEADER)
    assert resp.status_code == 404

    resp = await client.get(f"{RECIPES_PREFIX}/{recipe_id}", headers=AUTH_HEADER)
    assert resp.status_code == 200


@pytest.mark.asyncio
async def test_list_runs_filters_by_status(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    """Tab 2's Pending / In Progress / Completed lists."""
    _, rice, _, _, recipe_id = await _make_pilau_kitchen(client, db_session)
    pending_id = (await _create_run(client, recipe_id, "5.000"))["id"]
    active_id = (await _create_run(client, recipe_id, "10.000"))["id"]
    resp = await client.post(
        f"{RUNS_PREFIX}/{active_id}/start",
        json={"leading_item_id": str(rice.id), "leading_quantity_used": "2.000"},
        headers=AUTH_HEADER)
    assert resp.status_code == 200, resp.text

    for want, expected in (("pending", [pending_id]), ("in_progress", [active_id]),
                           ("completed", [])):
        resp = await client.get(
            RUNS_PREFIX, params={"status": want}, headers=AUTH_HEADER)
        assert resp.status_code == 200, resp.text
        assert [r["id"] for r in resp.json()] == expected

    resp = await client.get(RUNS_PREFIX, params={"status": "flying"}, headers=AUTH_HEADER)
    assert resp.status_code == 422, resp.text


@pytest.mark.asyncio
async def test_runs_rbac(client: AsyncClient, db_session: AsyncSession) -> None:
    """Run reads need production.view; mutations need production.create."""
    _, rice, _, _, recipe_id = await _make_pilau_kitchen(client, db_session)
    run_id = (await _create_run(client, recipe_id, "10.000"))["id"]

    resp = await client.get(RUNS_PREFIX, headers=_auth_header())
    assert resp.status_code == 403, resp.text
    resp = await client.get(RUNS_PREFIX, headers=_auth_header("production.view"))
    assert resp.status_code == 200, resp.text

    start_body = {"leading_item_id": str(rice.id), "leading_quantity_used": "2.000"}
    resp = await client.post(
        f"{RUNS_PREFIX}/{run_id}/start", json=start_body, headers=_auth_header())
    assert resp.status_code == 403, resp.text
    resp = await client.post(
        f"{RUNS_PREFIX}/{run_id}/start", json=start_body,
        headers=_auth_header("production.create"))
    assert resp.status_code == 200, resp.text


@pytest.mark.asyncio
async def test_batch_recipe_cost_and_scaling(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    """50-portion batch formula: totals stored, per-unit derived, cost shown."""
    pilau = await _create_test_item(db_session, "Biryani", ItemType.SELLABLE)
    rice = await _create_test_item(db_session, "Rice", ItemType.RAW_MATERIAL, "3200.0000")
    meat = await _create_test_item(db_session, "Meat", ItemType.RAW_MATERIAL, "14000.0000")
    oil = await _create_test_item(db_session, "Oil", ItemType.RAW_MATERIAL, "7500.0000")
    for item, qty in ((rice, "100.000"), (meat, "100.000"), (oil, "100.000"), (pilau, "0.000")):
        await _set_stock(db_session, item.id, qty)

    resp = await client.post(
        RECIPES_PREFIX,
        json={
            "sellable_item_id": str(pilau.id),
            "name": "Biryani x50",
            "category": "finished",
            "target_yield_quantity": "50.000",
            "target_yield_unit": "portions",
            "components": [
                {"raw_material_item_id": str(rice.id), "quantity_required": "10.000"},
                {"raw_material_item_id": str(meat.id), "quantity_required": "5.000"},
                {"raw_material_item_id": str(oil.id), "quantity_required": "1.000"},
            ],
        },
        headers=AUTH_HEADER,
    )
    assert resp.status_code == 201, resp.text
    data = resp.json()
    # Batch cost: 10×3200 + 5×14000 + 1×7500 = 109500; per plate 2190.
    assert data["total_cost"] == "109500.00"
    assert data["cost_per_unit"] == "2190.00"
    assert data["cost_complete"] is True
    assert data["category"] == "finished"
    by_id = {c["raw_material_item_id"]: c for c in data["components"]}
    assert by_id[str(rice.id)]["quantity_per_unit"] == "0.200"
    recipe_id = UUID(data["id"])

    # Planning 100 plates doubles the batch; producing consumes by ratio.
    resp = await client.post(
        f"{RECIPES_PREFIX}/{recipe_id}/plan",
        json={"target_output_quantity": "100.000"},
        headers=AUTH_HEADER,
    )
    assert resp.status_code == 200, resp.text
    by_id = {c["raw_material_item_id"]: c for c in resp.json()["components"]}
    assert by_id[str(rice.id)]["planned_quantity"] == "20.000"
    assert by_id[str(meat.id)]["planned_quantity"] == "10.000"

    resp = await client.post(
        f"{RECIPES_PREFIX}/{recipe_id}/produce",
        json={"leading_item_id": str(rice.id), "leading_quantity_used": "20.000",
              "actual_output_quantity": "100.000"},
        headers=AUTH_HEADER,
    )
    assert resp.status_code == 201, resp.text
    assert resp.json()["suggested_output_quantity"] == "100.000"
    async with db_session as s:
        assert await _level(s, pilau.id) == Decimal("100.000")
        assert await _level(s, rice.id) == Decimal("80.000")


@pytest.mark.asyncio
async def test_recipe_cost_incomplete_without_unit_costs(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    """A priceless ingredient flags the totals as estimates."""
    pilau = await _create_test_item(db_session, "Pilau", ItemType.SELLABLE)
    rice = await _create_test_item(db_session, "Rice", ItemType.RAW_MATERIAL, "3200.0000")
    spice = await _create_test_item(db_session, "Masala", ItemType.RAW_MATERIAL)

    resp = await client.post(
        RECIPES_PREFIX,
        json={
            "sellable_item_id": str(pilau.id),
            "name": "Pilau",
            "components": [
                {"raw_material_item_id": str(rice.id), "quantity_required": "0.200"},
                {"raw_material_item_id": str(spice.id), "quantity_required": "0.005"},
            ],
        },
        headers=AUTH_HEADER,
    )
    assert resp.status_code == 201, resp.text
    data = resp.json()
    assert data["cost_complete"] is False
    assert data["total_cost"] == "640.00"
    by_id = {c["raw_material_item_id"]: c for c in data["components"]}
    assert by_id[str(spice.id)]["line_cost"] is None
