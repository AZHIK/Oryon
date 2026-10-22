"""Store-scope enforcement: store-staff tokens are pinned to their store.

Tokens WITHOUT ``active_store_id`` (business staff, owners) pass through
untouched — every test here uses a pinned token unless stated otherwise.
"""

from __future__ import annotations

from datetime import UTC, datetime, timedelta
from decimal import Decimal
from uuid import UUID

import jwt
from httpx import AsyncClient
from sqlmodel import select
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.config import get_settings
from app.models.inventory import Item, ItemType, StockLevel
from app.models.suppliers import Supplier
from app.models.units import Unit
from tests.api.test_items import TEST_PRIVATE_KEY

BUSINESS_ID = UUID("00000000-0000-0000-0000-000000000001")
STORE_ID = UUID("00000000-0000-0000-0000-000000000010")
STORE_ID_2 = UUID("00000000-0000-0000-0000-000000000020")
BIZ = f"/api/v1/businesses/{BUSINESS_ID}"

ALL_PERMS = [
    "inventory.view",
    "inventory.items.create",
    "inventory.items.update",
    "inventory.items.deactivate",
    "inventory.adjust",
    "inventory.waste.record",
    "inventory.transfer",
    "reorders.view",
    "reorders.create",
    "reorders.receive",
    "reorders.cancel",
    "reports.view",
    "production.create",
    "production.view",
]


def _store_token(store_id: UUID, permissions: list[str] | None = None) -> str:
    settings = get_settings()
    now = datetime.now(UTC)
    payload = {
        "sub": "user-store-1",
        "type": "access",
        "user_category": "business_store_staff",
        "iat": now,
        "exp": now + timedelta(minutes=15),
        "permissions": permissions or ALL_PERMS,
        "active_business_id": str(BUSINESS_ID),
        "active_store_id": str(store_id),
    }
    return jwt.encode(payload, TEST_PRIVATE_KEY, algorithm=settings.jwt_algorithm)


def _store_header(store_id: UUID) -> dict[str, str]:
    return {"Authorization": f"Bearer {_store_token(store_id)}"}


def _biz_token() -> dict[str, str]:
    settings = get_settings()
    now = datetime.now(UTC)
    payload = {
        "sub": "user-biz-1",
        "type": "access",
        "user_category": "business_staff",
        "iat": now,
        "exp": now + timedelta(minutes=15),
        "permissions": ALL_PERMS,
        "active_business_id": str(BUSINESS_ID),
    }
    return {
        "Authorization": (
            "Bearer "
            f"{jwt.encode(payload, TEST_PRIVATE_KEY, algorithm=settings.jwt_algorithm)}"
        )
    }


async def _kg_unit_id(session: AsyncSession) -> UUID:
    result = await session.exec(select(Unit).where(Unit.code == "kg"))
    return result.one().id


async def _make_item(
    session: AsyncSession,
    store_id: UUID,
    name: str = "Scope Item",
    item_type: ItemType = ItemType.BOTH,
) -> Item:
    item = Item(
        business_id=BUSINESS_ID,
        store_id=store_id,
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


async def _make_stock(
    session: AsyncSession, item_id: UUID, store_id: UUID, qty: str = "10.000"
) -> None:
    session.add(StockLevel(item_id=item_id, store_id=store_id, current_quantity=Decimal(qty)))
    await session.commit()


class TestItemScope:
    async def test_list_unfiltered_pinned_to_own_store(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        await _make_item(db_session, STORE_ID, name="Own Flour")
        await _make_item(db_session, STORE_ID_2, name="Other Flour")

        resp = await client.get(f"{BIZ}/items", headers=_store_header(STORE_ID))
        assert resp.status_code == 200
        names = [i["name"] for i in resp.json()]
        assert names == ["Own Flour"]

    async def test_list_foreign_store_rejected(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        resp = await client.get(
            f"{BIZ}/items?store_id={STORE_ID_2}",
            headers=_store_header(STORE_ID),
        )
        assert resp.status_code == 403

    async def test_create_foreign_store_rejected(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        unit_id = await _kg_unit_id(db_session)
        resp = await client.post(
            f"{BIZ}/items",
            json={
                "store_id": str(STORE_ID_2),
                "name": "Foreign Item",
                "unit_id": str(unit_id),
                "reorder_threshold": "10",
                "reorder_quantity": "20",
                "item_type": "both",
            },
            headers=_store_header(STORE_ID),
        )
        assert resp.status_code == 403

    async def test_get_update_deactivate_foreign_item_rejected(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        item = await _make_item(db_session, STORE_ID_2, name="Foreign Item")
        headers = _store_header(STORE_ID)

        resp = await client.get(f"{BIZ}/items/{item.id}", headers=headers)
        assert resp.status_code == 403

        resp = await client.patch(
            f"{BIZ}/items/{item.id}", json={"name": "Renamed"}, headers=headers
        )
        assert resp.status_code == 403

        resp = await client.delete(f"{BIZ}/items/{item.id}", headers=headers)
        assert resp.status_code == 403

    async def test_unpinned_caller_unaffected(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        await _make_item(db_session, STORE_ID, name="Own Flour")
        await _make_item(db_session, STORE_ID_2, name="Other Flour")

        resp = await client.get(f"{BIZ}/items", headers=_biz_token())
        assert resp.status_code == 200
        assert len(resp.json()) == 2


class TestOperationScope:
    async def test_adjust_foreign_item_rejected(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        item = await _make_item(db_session, STORE_ID_2, name="Foreign Item")

        resp = await client.post(
            f"{BIZ}/items/{item.id}/adjust",
            json={"quantity_delta": 1.0, "reason": "scope probe"},
            headers=_store_header(STORE_ID),
        )
        assert resp.status_code == 403

    async def test_transfer_foreign_leg_rejected(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        item = await _make_item(db_session, STORE_ID, name="Transfer Item")
        await _make_stock(db_session, item.id, STORE_ID)
        headers = _store_header(STORE_ID)

        # Foreign source.
        resp = await client.post(
            f"{BIZ}/transfer",
            json={
                "item_id": str(item.id),
                "source_store_id": str(STORE_ID_2),
                "destination_store_id": str(STORE_ID),
                "quantity": 1.0,
            },
            headers=headers,
        )
        assert resp.status_code == 403

        # Foreign destination.
        resp = await client.post(
            f"{BIZ}/transfer",
            json={
                "item_id": str(item.id),
                "source_store_id": str(STORE_ID),
                "destination_store_id": str(STORE_ID_2),
                "quantity": 1.0,
            },
            headers=headers,
        )
        assert resp.status_code == 403


class TestReorderScope:
    async def _seed_reorder(
        self, client: AsyncClient, db_session: AsyncSession, store_id: UUID
    ) -> str:
        headers = _biz_token()
        supplier = Supplier(business_id=BUSINESS_ID, name="Scope Supplier")
        db_session.add(supplier)
        await db_session.commit()
        item = await _make_item(
            db_session,
            store_id,
            name="Reorder Item",
            item_type=ItemType.RAW_MATERIAL,
        )
        resp = await client.post(
            f"{BIZ}/reorders",
            json={
                "store_id": str(store_id),
                "item_id": str(item.id),
                "supplier_id": str(supplier.id),
                "quantity": "5.000",
            },
            headers=headers,
        )
        assert resp.status_code == 201, resp.text
        return resp.json()["id"]

    async def test_list_unfiltered_pinned_to_own_store(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        await self._seed_reorder(client, db_session, STORE_ID)
        await self._seed_reorder(client, db_session, STORE_ID_2)

        resp = await client.get(f"{BIZ}/reorders", headers=_store_header(STORE_ID))
        assert resp.status_code == 200
        data = resp.json()
        assert data["total"] == 1
        assert data["items"][0]["store_id"] == str(STORE_ID)

    async def test_receive_foreign_reorder_rejected(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        reorder_id = await self._seed_reorder(client, db_session, STORE_ID_2)

        resp = await client.post(
            f"{BIZ}/reorders/{reorder_id}/receive",
            headers=_store_header(STORE_ID),
        )
        assert resp.status_code == 403


class TestReportsScope:
    async def test_stock_unfiltered_pinned_to_own_store(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        item = await _make_item(db_session, STORE_ID, name="Own Flour")
        await _make_stock(db_session, item.id, STORE_ID)
        other = await _make_item(db_session, STORE_ID_2, name="Other Flour")
        await _make_stock(db_session, other.id, STORE_ID_2)

        resp = await client.get(f"{BIZ}/stock", headers=_store_header(STORE_ID))
        assert resp.status_code == 200
        stores = {row["store_id"] for row in resp.json()}
        assert stores == {str(STORE_ID)}
