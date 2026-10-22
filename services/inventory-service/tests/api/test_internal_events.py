"""Integration tests for the internal stock-events endpoint.

This endpoint is service-to-service only (POS Service -> Inventory
Service) — auth is a shared-secret header, not a JWT, so these tests don't
need the RSA token machinery the other API test files use.
"""

from __future__ import annotations

from decimal import Decimal
from uuid import UUID, uuid4

import pytest
from httpx import AsyncClient
from sqlmodel import select
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.config import get_settings
from app.models.inventory import Item, ItemType, StockLevel

BUSINESS_ID = UUID("00000000-0000-0000-0000-000000000001")
STORE_ID = UUID("00000000-0000-0000-0000-000000000010")
API_PREFIX = f"/api/v1/internal/businesses/{BUSINESS_ID}"


def _internal_header() -> dict[str, str]:
    return {"X-Internal-Service-Token": get_settings().internal_service_token}


async def _create_test_item(
    session: AsyncSession,
    name: str = "Test Item",
    item_type: ItemType = ItemType.SELLABLE,
) -> Item:
    item = Item(
        business_id=BUSINESS_ID,
        store_id=STORE_ID,
        name=name,
        reorder_threshold=Decimal("10.000"),
        reorder_quantity=Decimal("20.000"),
        item_type=item_type,
    )
    session.add(item)
    await session.commit()
    await session.refresh(item)
    return item


async def _create_stock_level(
    session: AsyncSession,
    item_id: UUID,
    quantity: Decimal = Decimal("5.000"),
) -> StockLevel:
    sl = StockLevel(item_id=item_id, store_id=STORE_ID, current_quantity=quantity)
    session.add(sl)
    await session.commit()
    await session.refresh(sl)
    return sl


def _sale_completed_body(event_id: str, item_id: UUID, quantity: str = "2") -> dict:
    return {
        "event_type": "sale.completed",
        "event_id": event_id,
        "store_id": str(STORE_ID),
        "sale_id": str(uuid4()),
        "line_items": [{"item_id": str(item_id), "quantity": quantity}],
    }


@pytest.mark.asyncio
async def test_sale_completed_decrements_stock(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    item = await _create_test_item(db_session)
    await _create_stock_level(db_session, item.id, quantity=Decimal("10.000"))

    resp = await client.post(
        f"{API_PREFIX}/stock-events",
        json=_sale_completed_body(str(uuid4()), item.id, "3"),
        headers=_internal_header(),
    )

    assert resp.status_code == 200, resp.text
    data = resp.json()
    assert data["results"] == [{"item_id": str(item.id), "status": "applied", "reason": None}]

    result = await db_session.exec(
        select(StockLevel).where(StockLevel.item_id == item.id, StockLevel.store_id == STORE_ID)
    )
    stock_level = result.one()
    assert stock_level.current_quantity == Decimal("7.000")


@pytest.mark.asyncio
async def test_duplicate_event_id_is_idempotent(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    item = await _create_test_item(db_session)
    await _create_stock_level(db_session, item.id, quantity=Decimal("10.000"))
    event_id = str(uuid4())
    body = _sale_completed_body(event_id, item.id, "3")

    first = await client.post(f"{API_PREFIX}/stock-events", json=body, headers=_internal_header())
    second = await client.post(f"{API_PREFIX}/stock-events", json=body, headers=_internal_header())

    assert first.status_code == 200
    assert second.status_code == 200
    assert second.json()["results"][0]["status"] == "applied"

    # Applying twice must not double-decrement — the second call is a no-op
    # by ProcessedEvent's idempotency check inside record_movement.
    result = await db_session.exec(
        select(StockLevel).where(StockLevel.item_id == item.id, StockLevel.store_id == STORE_ID)
    )
    stock_level = result.one()
    assert stock_level.current_quantity == Decimal("7.000")


@pytest.mark.asyncio
async def test_unknown_item_id_is_skipped_not_failed(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    resp = await client.post(
        f"{API_PREFIX}/stock-events",
        json=_sale_completed_body(str(uuid4()), uuid4()),
        headers=_internal_header(),
    )

    assert resp.status_code == 200, resp.text
    assert resp.json()["results"][0]["status"] == "skipped"


@pytest.mark.asyncio
async def test_one_bad_line_item_does_not_block_the_others(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    good_item = await _create_test_item(db_session, name="Good Item")
    await _create_stock_level(db_session, good_item.id, quantity=Decimal("10.000"))
    missing_item_id = uuid4()

    body = {
        "event_type": "sale.completed",
        "event_id": str(uuid4()),
        "store_id": str(STORE_ID),
        "sale_id": str(uuid4()),
        "line_items": [
            {"item_id": str(missing_item_id), "quantity": "1"},
            {"item_id": str(good_item.id), "quantity": "2"},
        ],
    }

    resp = await client.post(f"{API_PREFIX}/stock-events", json=body, headers=_internal_header())

    assert resp.status_code == 200, resp.text
    results = {r["item_id"]: r["status"] for r in resp.json()["results"]}
    assert results[str(missing_item_id)] == "skipped"
    assert results[str(good_item.id)] == "applied"


@pytest.mark.asyncio
async def test_missing_internal_token_is_rejected(client: AsyncClient) -> None:
    resp = await client.post(
        f"{API_PREFIX}/stock-events",
        json=_sale_completed_body(str(uuid4()), uuid4()),
    )
    assert resp.status_code == 401


@pytest.mark.asyncio
async def test_wrong_internal_token_is_rejected(client: AsyncClient) -> None:
    resp = await client.post(
        f"{API_PREFIX}/stock-events",
        json=_sale_completed_body(str(uuid4()), uuid4()),
        headers={"X-Internal-Service-Token": "definitely-not-it"},
    )
    assert resp.status_code == 401


@pytest.mark.asyncio
async def test_sale_voided_reverses_stock(client: AsyncClient, db_session: AsyncSession) -> None:
    item = await _create_test_item(db_session)
    await _create_stock_level(db_session, item.id, quantity=Decimal("10.000"))

    sale_id = str(uuid4())
    completed = {
        "event_type": "sale.completed",
        "event_id": str(uuid4()),
        "store_id": str(STORE_ID),
        "sale_id": sale_id,
        "line_items": [{"item_id": str(item.id), "quantity": "4"}],
    }
    await client.post(f"{API_PREFIX}/stock-events", json=completed, headers=_internal_header())

    voided = {
        "event_type": "sale.voided",
        "event_id": str(uuid4()),
        "store_id": str(STORE_ID),
        "sale_id": sale_id,
        "line_items": [{"item_id": str(item.id), "quantity": "4"}],
    }
    resp = await client.post(f"{API_PREFIX}/stock-events", json=voided, headers=_internal_header())

    assert resp.status_code == 200, resp.text
    assert resp.json()["results"][0]["status"] == "applied"

    result = await db_session.exec(
        select(StockLevel).where(StockLevel.item_id == item.id, StockLevel.store_id == STORE_ID)
    )
    stock_level = result.one()
    assert stock_level.current_quantity == Decimal("10.000")
