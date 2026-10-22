"""Integration tests for analytics endpoints (waste, production, valuation).

Auth helpers are imported from ``test_reports`` (same RSA key and business
constants) rather than duplicated — the key block must stay byte-identical
everywhere and there is no reason to copy it a third time.
"""

from __future__ import annotations

from datetime import UTC, datetime, timedelta
from decimal import Decimal
from uuid import UUID

from httpx import AsyncClient
from sqlmodel import select
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.permission_codes import PermissionCode
from app.models.inventory import (
    ActorType,
    Item,
    ItemType,
    MovementType,
    ProductionEvent,
    ProductionEventComponent,
    Recipe,
    StockLevel,
    StockMovement,
)
from app.models.units import Unit
from tests.api.test_reports import BUSINESS_ID, STORE_ID, _build_token

BASE = "/api/v1/businesses/{business_id}"
REPORTS_VIEW = ["reports.view"]
INVENTORY_ONLY = ["inventory.view"]


def _auth(permissions: list[str] = REPORTS_VIEW, business_id: UUID = BUSINESS_ID) -> dict[str, str]:
    return {
        "Authorization": "Bearer "
        + _build_token(permissions=permissions, active_business_id=str(business_id))
    }


async def _kg_unit_id(session: AsyncSession) -> UUID:
    result = await session.exec(select(Unit).where(Unit.code == "kg"))
    return result.one().id


async def _create_item(
    session: AsyncSession,
    name: str,
    item_type: ItemType = ItemType.RAW_MATERIAL,
    unit_cost: Decimal | None = Decimal("2.0000"),
    category_id: UUID | None = None,
) -> Item:
    item = Item(
        business_id=BUSINESS_ID,
        store_id=STORE_ID,
        name=name,
        unit_id=await _kg_unit_id(session),
        category_id=category_id,
        reorder_threshold=Decimal("10.000"),
        reorder_quantity=Decimal("20.000"),
        unit_cost=unit_cost,
        item_type=item_type,
    )
    session.add(item)
    await session.commit()
    await session.refresh(item)
    return item


async def _set_level(session: AsyncSession, item_id: UUID, qty: str) -> None:
    session.add(StockLevel(item_id=item_id, store_id=STORE_ID, current_quantity=Decimal(qty)))
    await session.commit()


async def _waste(
    session: AsyncSession,
    item_id: UUID,
    qty: str,
    when: datetime | None = None,
) -> None:
    session.add(
        StockMovement(
            item_id=item_id,
            business_id=BUSINESS_ID,
            store_id=STORE_ID,
            quantity_delta=-Decimal(qty),
            movement_type=MovementType.WASTE,
            actor_type=ActorType.USER,
            reason="spoiled",
            created_at=when or datetime.now(UTC),
        )
    )
    await session.commit()


async def _production_event(
    session: AsyncSession,
    recipe_id: UUID,
    leading_item_id: UUID,
    suggested: str,
    actual: str,
    when: datetime | None = None,
    consumptions: list[tuple[UUID, str]] | None = None,
) -> UUID:
    moment = when or datetime.now(UTC)
    event = ProductionEvent(
        business_id=BUSINESS_ID,
        store_id=STORE_ID,
        recipe_id=recipe_id,
        leading_component_item_id=leading_item_id,
        leading_quantity_used=Decimal("1.000"),
        suggested_output_quantity=Decimal(suggested),
        actual_output_quantity=Decimal(actual),
        occurred_at=moment,
        created_at=moment,
    )
    session.add(event)
    await session.flush()
    for raw_id, qty in consumptions or []:
        session.add(
            ProductionEventComponent(
                production_event_id=event.id,
                raw_material_item_id=raw_id,
                quantity_consumed=Decimal(qty),
            )
        )
    await session.commit()
    await session.refresh(event)
    return event.id


async def _recipe(session: AsyncSession, sellable_id: UUID, name: str = "Pilau") -> UUID:
    recipe = Recipe(business_id=BUSINESS_ID, sellable_item_id=sellable_id, name=name)
    session.add(recipe)
    await session.commit()
    await session.refresh(recipe)
    return recipe.id


class TestWasteSummary:
    async def test_quantities_and_costs(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        rice = await _create_item(db_session, "Rice", unit_cost=Decimal("1.5000"))
        await _waste(db_session, rice.id, "2.000")
        await _waste(db_session, rice.id, "1.000")

        resp = await client.get(
            f"{BASE.format(business_id=BUSINESS_ID)}/waste-summary", headers=_auth()
        )
        assert resp.status_code == 200, resp.text
        data = resp.json()
        assert len(data["lines"]) == 1
        assert Decimal(data["lines"][0]["quantity_wasted"]) == Decimal("3")
        assert Decimal(data["lines"][0]["cost_wasted"]) == Decimal("4.5")
        assert Decimal(data["total_cost_wasted"]) == Decimal("4.5")

    async def test_costless_item_reports_quantity_only(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        mystery = await _create_item(db_session, "Mystery", unit_cost=None)
        await _waste(db_session, mystery.id, "5.000")

        resp = await client.get(
            f"{BASE.format(business_id=BUSINESS_ID)}/waste-summary", headers=_auth()
        )
        assert resp.status_code == 200, resp.text
        line = resp.json()["lines"][0]
        assert Decimal(line["quantity_wasted"]) == Decimal("5")
        assert Decimal(line["cost_wasted"]) == Decimal("0")

    async def test_date_filter(self, client: AsyncClient, db_session: AsyncSession) -> None:
        rice = await _create_item(db_session, "Rice")
        await _waste(db_session, rice.id, "9.000", when=datetime.now(UTC) - timedelta(days=10))
        await _waste(db_session, rice.id, "1.000")

        resp = await client.get(
            f"{BASE.format(business_id=BUSINESS_ID)}/waste-summary",
            headers=_auth(),
            params={"from": (datetime.now(UTC) - timedelta(days=2)).date().isoformat()},
        )
        assert resp.status_code == 200, resp.text
        assert Decimal(resp.json()["lines"][0]["quantity_wasted"]) == Decimal("1")


class TestProductionSummary:
    async def _setup(self, db_session: AsyncSession) -> tuple[UUID, UUID]:
        pilau = await _create_item(db_session, "Pilau", ItemType.SELLABLE)
        rice = await _create_item(db_session, "Rice")
        recipe_id = await _recipe(db_session, pilau.id)
        await _production_event(
            db_session,
            recipe_id,
            rice.id,
            "10.000",
            "8.000",
            consumptions=[(rice.id, "2.000")],
        )
        await _production_event(
            db_session,
            recipe_id,
            rice.id,
            "5.000",
            "5.000",
            when=datetime.now(UTC) - timedelta(days=10),
            consumptions=[(rice.id, "1.000")],
        )
        return recipe_id, rice.id

    async def test_totals_and_gap(self, client: AsyncClient, db_session: AsyncSession) -> None:
        _, rice_id = await self._setup(db_session)

        resp = await client.get(
            f"{BASE.format(business_id=BUSINESS_ID)}/production-summary",
            headers=_auth(),
        )
        assert resp.status_code == 200, resp.text
        data = resp.json()
        assert data["runs"] == 2
        assert Decimal(data["suggested_total"]) == Decimal("15")
        assert Decimal(data["actual_total"]) == Decimal("13")
        assert Decimal(data["over_portioned_by"]) == Decimal("-2")
        consumed = {c["raw_material_item_id"]: c for c in data["ingredients_consumed"]}
        assert Decimal(consumed[str(rice_id)]["quantity_consumed"]) == Decimal("3")

    async def test_date_filter(self, client: AsyncClient, db_session: AsyncSession) -> None:
        await self._setup(db_session)

        resp = await client.get(
            f"{BASE.format(business_id=BUSINESS_ID)}/production-summary",
            headers=_auth(),
            params={"from": (datetime.now(UTC) - timedelta(days=2)).date().isoformat()},
        )
        assert resp.status_code == 200, resp.text
        assert resp.json()["runs"] == 1


class TestStockValuation:
    async def test_total_and_category_split(
        self, client: AsyncClient, db_session: AsyncSession, produce_category_id: str
    ) -> None:
        rice = await _create_item(
            db_session,
            "Rice",
            unit_cost=Decimal("1.5000"),
            category_id=UUID(produce_category_id),
        )
        await _set_level(db_session, rice.id, "10.000")
        beans = await _create_item(db_session, "Beans", unit_cost=Decimal("2.0000"))
        await _set_level(db_session, beans.id, "5.000")
        mystery = await _create_item(db_session, "Mystery", unit_cost=None)
        await _set_level(db_session, mystery.id, "7.000")

        resp = await client.get(
            f"{BASE.format(business_id=BUSINESS_ID)}/stock-valuation",
            headers=_auth(),
        )
        assert resp.status_code == 200, resp.text
        data = resp.json()
        # 10×1.5 + 5×2 + 7×0 = 25.
        assert Decimal(data["total_value"]) == Decimal("25")
        by_cat = {line["category"]: line for line in data["lines"]}
        assert Decimal(by_cat["Produce"]["total_value"]) == Decimal("15")
        assert by_cat["Produce"]["item_count"] == 1
        assert Decimal(by_cat[None]["total_value"]) == Decimal("10")


class TestAnalyticsRbac:
    async def test_endpoints_reject_without_reports_view(
        self,
        client: AsyncClient,
    ) -> None:
        for suffix in ("waste-summary", "production-summary", "stock-valuation"):
            resp = await client.get(
                f"{BASE.format(business_id=BUSINESS_ID)}/{suffix}",
                headers=_auth(INVENTORY_ONLY),
            )
            assert resp.status_code == 403, suffix

    async def test_cross_business_isolation(
        self,
        client: AsyncClient,
        db_session: AsyncSession,
    ) -> None:
        rice = await _create_item(db_session, "Rice")
        await _waste(db_session, rice.id, "9.000")

        other = UUID("00000000-0000-0000-0000-000000000099")
        headers = _auth(REPORTS_VIEW, business_id=other)
        for suffix, key in (
            ("waste-summary", "lines"),
            ("production-summary", "ingredients_consumed"),
            ("stock-valuation", "lines"),
        ):
            resp = await client.get(f"/api/v1/businesses/{other}/{suffix}", headers=headers)
            assert resp.status_code == 200, suffix
            assert resp.json()[key] == [], suffix


def test_analytics_permission_codes_registered() -> None:
    """REPORTS_VIEW/EXPORT exist with exact values in this service's copy."""
    assert PermissionCode.REPORTS_VIEW.value == "reports.view"
    assert PermissionCode.REPORTS_EXPORT.value == "reports.export"
