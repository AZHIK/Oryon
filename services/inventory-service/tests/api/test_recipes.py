"""Integration tests for recipe endpoints (Stage 1: Recipe CRUD).

Every test uses a real Postgres-backed session (built by the real Alembic
migration chain, including the recipe-header migration) and a signed JWT so
that the full auth + permission stack is exercised.
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
from app.core.permission_codes import PermissionCode
from app.models.inventory import Item, ItemType, Recipe, RecipeComponent
from app.models.units import Unit

# ── Test RSA keypair (byte-identical to tests/api/test_items.py) ──────────
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

ALL_RECIPE_PERMS = [
    "recipes.view",
    "recipes.create",
    "recipes.update",
    "recipes.delete",
]

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
        # NB: `is not None`, not `or` — an explicit empty list means "no
        # permissions" (the RBAC negative case), not "use the default set".
        "permissions": permissions
        if permissions is not None
        else (ALL_RECIPE_PERMS + ALL_INVENTORY_PERMS),
        "active_business_id": active_business_id,
    }
    return jwt.encode(payload, TEST_PRIVATE_KEY, algorithm=settings.jwt_algorithm)


BUSINESS_ID = UUID("00000000-0000-0000-0000-000000000001")
OTHER_BUSINESS_ID = UUID("00000000-0000-0000-0000-000000000099")
STORE_ID = UUID("00000000-0000-0000-0000-000000000010")
AUTH_HEADER = {"Authorization": f"Bearer {_build_token()}"}
API_PREFIX = f"/api/v1/businesses/{BUSINESS_ID}/recipes"


def _auth_header(*codes: str) -> dict[str, str]:
    """Token carrying exactly *codes* (for RBAC negative tests)."""
    return {"Authorization": f"Bearer {_build_token(permissions=list(codes))}"}


async def _kg_unit_id(session: AsyncSession) -> UUID:
    result = await session.exec(select(Unit).where(Unit.code == "kg"))
    return result.one().id


async def _create_test_item(
    session: AsyncSession,
    name: str = "Test Item",
    item_type: ItemType = ItemType.BOTH,
    business_id: UUID = BUSINESS_ID,
) -> Item:
    item = Item(
        business_id=business_id,
        store_id=STORE_ID,
        name=name,
        unit_id=await _kg_unit_id(session),
        reorder_threshold=Decimal("10.000"),
        reorder_quantity=Decimal("20.000"),
        item_type=item_type,
    )
    session.add(item)
    await session.commit()
    await session.refresh(item)
    return item


async def _create_pilau_setup(session: AsyncSession) -> tuple[Item, Item, Item]:
    """A sellable Pilau plus raw Rice and Onions — the happy-path fixture."""
    pilau = await _create_test_item(session, name="Pilau", item_type=ItemType.SELLABLE)
    rice = await _create_test_item(session, name="Rice", item_type=ItemType.RAW_MATERIAL)
    onions = await _create_test_item(
        session, name="Onions", item_type=ItemType.RAW_MATERIAL
    )
    return pilau, rice, onions


def _component(item_id: UUID, qty: str) -> dict[str, str]:
    return {"raw_material_item_id": str(item_id), "quantity_required": qty}


# ── Tests ────────────────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_create_recipe_resolves_ingredients(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    """Valid create → 201; read resolves names/units, not just raw ids."""
    pilau, rice, onions = await _create_pilau_setup(db_session)

    resp = await client.post(
        API_PREFIX,
        json={
            "sellable_item_id": str(pilau.id),
            "name": "Pilau",
            "components": [
                _component(rice.id, "0.200"),
                _component(onions.id, "0.030"),
            ],
        },
        headers=AUTH_HEADER,
    )
    assert resp.status_code == 201, resp.text
    data = resp.json()
    assert data["business_id"] == str(BUSINESS_ID)
    assert data["sellable_item_id"] == str(pilau.id)
    assert data["sellable_item_name"] == "Pilau"
    assert data["name"] == "Pilau"
    assert len(data["components"]) == 2

    by_name = {c["raw_material_name"]: c for c in data["components"]}
    assert by_name["Rice"]["quantity_required"] == "0.200"
    assert by_name["Rice"]["raw_material_unit"] == "kg"
    assert by_name["Onions"]["quantity_required"] == "0.030"

    # GET detail resolves identically.
    resp = await client.get(f"{API_PREFIX}/{data['id']}", headers=AUTH_HEADER)
    assert resp.status_code == 200
    assert resp.json()["components"] == data["components"]

    # List includes it.
    resp = await client.get(API_PREFIX, headers=AUTH_HEADER)
    assert resp.status_code == 200
    assert [r["id"] for r in resp.json()] == [data["id"]]


@pytest.mark.asyncio
async def test_create_recipe_defaults_name_to_sellable(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    """Omitting name snapshots the sellable item's own name."""
    pilau, rice, _ = await _create_pilau_setup(db_session)
    resp = await client.post(
        API_PREFIX,
        json={
            "sellable_item_id": str(pilau.id),
            "components": [_component(rice.id, "0.200")],
        },
        headers=AUTH_HEADER,
    )
    assert resp.status_code == 201, resp.text
    assert resp.json()["name"] == "Pilau"


@pytest.mark.asyncio
async def test_create_recipe_for_raw_material_only_rejected(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    """A raw_material-only item cannot have a recipe (422, not 201)."""
    flour = await _create_test_item(
        session=db_session, name="Flour", item_type=ItemType.RAW_MATERIAL
    )
    rice = await _create_test_item(
        session=db_session, name="Rice", item_type=ItemType.RAW_MATERIAL
    )
    resp = await client.post(
        API_PREFIX,
        json={
            "sellable_item_id": str(flour.id),
            "components": [_component(rice.id, "1.000")],
        },
        headers=AUTH_HEADER,
    )
    assert resp.status_code == 422, resp.text


@pytest.mark.asyncio
async def test_create_recipe_with_sellable_only_ingredient_rejected(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    """A sellable-only item cannot be an ingredient (422)."""
    pilau = await _create_test_item(
        session=db_session, name="Pilau", item_type=ItemType.SELLABLE
    )
    cake = await _create_test_item(
        session=db_session, name="Cake", item_type=ItemType.SELLABLE
    )
    resp = await client.post(
        API_PREFIX,
        json={
            "sellable_item_id": str(pilau.id),
            "components": [_component(cake.id, "1.000")],
        },
        headers=AUTH_HEADER,
    )
    assert resp.status_code == 422, resp.text


@pytest.mark.asyncio
async def test_create_second_recipe_conflicts(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    """A second recipe for the same sellable → clear 409, not a raw DB error."""
    pilau, rice, onions = await _create_pilau_setup(db_session)
    payload = {
        "sellable_item_id": str(pilau.id),
        "components": [_component(rice.id, "0.200")],
    }
    resp = await client.post(API_PREFIX, json=payload, headers=AUTH_HEADER)
    assert resp.status_code == 201, resp.text

    resp = await client.post(
        API_PREFIX,
        json={
            "sellable_item_id": str(pilau.id),
            "components": [_component(onions.id, "0.030")],
        },
        headers=AUTH_HEADER,
    )
    assert resp.status_code == 409, resp.text
    assert "already has a recipe" in resp.json()["detail"]


@pytest.mark.asyncio
async def test_create_recipe_with_zero_components_rejected(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    """An empty component list is rejected by schema validation (422)."""
    pilau, _, _ = await _create_pilau_setup(db_session)
    resp = await client.post(
        API_PREFIX,
        json={"sellable_item_id": str(pilau.id), "components": []},
        headers=AUTH_HEADER,
    )
    assert resp.status_code == 422, resp.text


@pytest.mark.asyncio
async def test_create_recipe_with_cross_business_ingredient_rejected(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    """An ingredient owned by another business is rejected (422)."""
    pilau, rice, _ = await _create_pilau_setup(db_session)
    foreign_rice = await _create_test_item(
        session=db_session,
        name="Foreign Rice",
        item_type=ItemType.RAW_MATERIAL,
        business_id=OTHER_BUSINESS_ID,
    )
    resp = await client.post(
        API_PREFIX,
        json={
            "sellable_item_id": str(pilau.id),
            "components": [
                _component(rice.id, "0.200"),
                _component(foreign_rice.id, "0.100"),
            ],
        },
        headers=AUTH_HEADER,
    )
    assert resp.status_code == 422, resp.text
    assert "does not exist in this business" in resp.json()["detail"]


@pytest.mark.asyncio
async def test_update_recipe_replaces_component_set(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    """PATCH replaces the set: dropped lines are gone (confirmed by query)."""
    pilau, rice, onions = await _create_pilau_setup(db_session)
    resp = await client.post(
        API_PREFIX,
        json={
            "sellable_item_id": str(pilau.id),
            "components": [
                _component(rice.id, "0.200"),
                _component(onions.id, "0.030"),
            ],
        },
        headers=AUTH_HEADER,
    )
    assert resp.status_code == 201, resp.text
    recipe_id = resp.json()["id"]

    meat = await _create_test_item(
        session=db_session, name="Meat", item_type=ItemType.RAW_MATERIAL
    )
    resp = await client.patch(
        f"{API_PREFIX}/{recipe_id}",
        json={
            "components": [
                _component(rice.id, "0.250"),
                _component(meat.id, "0.100"),
            ]
        },
        headers=AUTH_HEADER,
    )
    assert resp.status_code == 200, resp.text
    data = resp.json()
    by_name = {c["raw_material_name"]: c for c in data["components"]}
    assert set(by_name) == {"Rice", "Meat"}
    assert by_name["Rice"]["quantity_required"] == "0.250"

    # Direct query: the dropped Onions line is really gone.
    async with db_session as s:
        result = await s.exec(
            select(RecipeComponent).where(
                RecipeComponent.recipe_id == UUID(recipe_id)
            )
        )
        rows = list(result.all())
        assert len(rows) == 2
        assert {r.raw_material_item_id for r in rows} == {rice.id, meat.id}


@pytest.mark.asyncio
async def test_delete_recipe_hard_deletes(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    """DELETE removes the header AND its components (hard delete, verified)."""
    pilau, rice, _ = await _create_pilau_setup(db_session)
    resp = await client.post(
        API_PREFIX,
        json={
            "sellable_item_id": str(pilau.id),
            "components": [_component(rice.id, "0.200")],
        },
        headers=AUTH_HEADER,
    )
    assert resp.status_code == 201, resp.text
    recipe_id = resp.json()["id"]

    resp = await client.delete(f"{API_PREFIX}/{recipe_id}", headers=AUTH_HEADER)
    assert resp.status_code == 204, resp.text

    resp = await client.get(f"{API_PREFIX}/{recipe_id}", headers=AUTH_HEADER)
    assert resp.status_code == 404

    async with db_session as s:
        assert (
            await s.exec(select(Recipe).where(Recipe.id == UUID(recipe_id)))
        ).one_or_none() is None
        assert (
            await s.exec(
                select(RecipeComponent).where(
                    RecipeComponent.recipe_id == UUID(recipe_id)
                )
            )
        ).all() == []


@pytest.mark.asyncio
async def test_recipe_rbac(client: AsyncClient, db_session: AsyncSession) -> None:
    """Each endpoint rejects a token missing its code and honours one with it."""
    pilau, rice, _ = await _create_pilau_setup(db_session)
    payload = {
        "sellable_item_id": str(pilau.id),
        "components": [_component(rice.id, "0.200")],
    }

    resp = await client.post(API_PREFIX, json=payload, headers=_auth_header())
    assert resp.status_code == 403, resp.text
    resp = await client.post(
        API_PREFIX, json=payload, headers=_auth_header("recipes.create")
    )
    assert resp.status_code == 201, resp.text
    recipe_id = resp.json()["id"]

    resp = await client.get(API_PREFIX, headers=_auth_header())
    assert resp.status_code == 403, resp.text
    resp = await client.get(API_PREFIX, headers=_auth_header("recipes.view"))
    assert resp.status_code == 200, resp.text

    resp = await client.get(
        f"{API_PREFIX}/{recipe_id}", headers=_auth_header("inventory.view")
    )
    assert resp.status_code == 403, resp.text

    update = {"components": [_component(rice.id, "0.300")]}
    resp = await client.patch(
        f"{API_PREFIX}/{recipe_id}", json=update, headers=_auth_header()
    )
    assert resp.status_code == 403, resp.text
    resp = await client.patch(
        f"{API_PREFIX}/{recipe_id}",
        json=update,
        headers=_auth_header("recipes.update"),
    )
    assert resp.status_code == 200, resp.text

    resp = await client.delete(
        f"{API_PREFIX}/{recipe_id}", headers=_auth_header("recipes.view")
    )
    assert resp.status_code == 403, resp.text
    resp = await client.delete(
        f"{API_PREFIX}/{recipe_id}", headers=_auth_header("recipes.delete")
    )
    assert resp.status_code == 204, resp.text


def test_recipe_permission_codes_registered() -> None:
    """The four recipe codes exist in this service's PermissionCode copy."""
    assert PermissionCode.RECIPES_VIEW.value == "recipes.view"
    assert PermissionCode.RECIPES_CREATE.value == "recipes.create"
    assert PermissionCode.RECIPES_UPDATE.value == "recipes.update"
    assert PermissionCode.RECIPES_DELETE.value == "recipes.delete"


# ── Standalone recipes (no menu item yet) ────────────────────────────────


@pytest.mark.asyncio
async def test_create_standalone_recipe_without_sellable(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    """Omitting sellable_item_id creates a standalone formula (201)."""
    _, rice, onions = await _create_pilau_setup(db_session)
    resp = await client.post(
        API_PREFIX,
        json={
            "name": "House Pilau Mix",
            "components": [
                _component(rice.id, "0.200"),
                _component(onions.id, "0.030"),
            ],
        },
        headers=AUTH_HEADER,
    )
    assert resp.status_code == 201, resp.text
    data = resp.json()
    assert data["sellable_item_id"] is None
    assert data["sellable_item_name"] is None
    assert data["name"] == "House Pilau Mix"
    assert len(data["components"]) == 2


@pytest.mark.asyncio
async def test_create_standalone_recipe_requires_name(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    """No sellable and no name → 422 (nothing to default from)."""
    _, rice, _ = await _create_pilau_setup(db_session)
    resp = await client.post(
        API_PREFIX,
        json={"components": [_component(rice.id, "0.200")]},
        headers=AUTH_HEADER,
    )
    assert resp.status_code == 422, resp.text


@pytest.mark.asyncio
async def test_link_standalone_recipe_to_sellable(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    """POST /recipes/{id}/link attaches a standalone recipe (200)."""
    pilau, rice, _ = await _create_pilau_setup(db_session)
    resp = await client.post(
        API_PREFIX,
        json={
            "name": "House Pilau Mix",
            "components": [_component(rice.id, "0.200")],
        },
        headers=AUTH_HEADER,
    )
    assert resp.status_code == 201, resp.text
    recipe_id = resp.json()["id"]

    resp = await client.post(
        f"{API_PREFIX}/{recipe_id}/link",
        json={"sellable_item_id": str(pilau.id)},
        headers=AUTH_HEADER,
    )
    assert resp.status_code == 200, resp.text
    data = resp.json()
    assert data["sellable_item_id"] == str(pilau.id)
    assert data["sellable_item_name"] == "Pilau"
    # The recipe's own name is kept, not overwritten by the sellable's.
    assert data["name"] == "House Pilau Mix"


@pytest.mark.asyncio
async def test_link_already_linked_recipe_rejected(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    """Links are set-once: re-linking a linked recipe → 422."""
    pilau, rice, _ = await _create_pilau_setup(db_session)
    other = await _create_test_item(
        session=db_session, name="Biriani", item_type=ItemType.SELLABLE
    )
    resp = await client.post(
        API_PREFIX,
        json={
            "sellable_item_id": str(pilau.id),
            "components": [_component(rice.id, "0.200")],
        },
        headers=AUTH_HEADER,
    )
    assert resp.status_code == 201, resp.text
    recipe_id = resp.json()["id"]

    resp = await client.post(
        f"{API_PREFIX}/{recipe_id}/link",
        json={"sellable_item_id": str(other.id)},
        headers=AUTH_HEADER,
    )
    assert resp.status_code == 422, resp.text


@pytest.mark.asyncio
async def test_link_to_sellable_with_recipe_conflicts(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    """Linking onto a menu item that already has a recipe → 409."""
    pilau, rice, onions = await _create_pilau_setup(db_session)
    resp = await client.post(
        API_PREFIX,
        json={
            "sellable_item_id": str(pilau.id),
            "components": [_component(rice.id, "0.200")],
        },
        headers=AUTH_HEADER,
    )
    assert resp.status_code == 201, resp.text

    resp = await client.post(
        API_PREFIX,
        json={
            "name": "Second Mix",
            "components": [_component(onions.id, "0.030")],
        },
        headers=AUTH_HEADER,
    )
    assert resp.status_code == 201, resp.text
    standalone_id = resp.json()["id"]

    resp = await client.post(
        f"{API_PREFIX}/{standalone_id}/link",
        json={"sellable_item_id": str(pilau.id)},
        headers=AUTH_HEADER,
    )
    assert resp.status_code == 409, resp.text


@pytest.mark.asyncio
async def test_run_for_standalone_recipe_rejected(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    """Planning a run for an unlinked recipe → 422 (output needs a home)."""
    _, rice, _ = await _create_pilau_setup(db_session)
    resp = await client.post(
        API_PREFIX,
        json={
            "name": "House Pilau Mix",
            "components": [_component(rice.id, "0.200")],
        },
        headers=AUTH_HEADER,
    )
    assert resp.status_code == 201, resp.text
    recipe_id = resp.json()["id"]

    resp = await client.post(
        f"/api/v1/businesses/{BUSINESS_ID}/runs",
        json={"recipe_id": recipe_id, "target_output_quantity": "10.000"},
        headers=_auth_header("production.create"),
    )
    assert resp.status_code == 422, resp.text
    assert "not linked" in resp.json()["detail"]
