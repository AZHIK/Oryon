"""Tests for inbound event handlers.

Covers sale.completed, sale.voided, sale.refunded, order.confirmed,
and purchase.received handlers with focus on idempotency
(per-line-item derived keys), negative-stock bypass, item_type
enforcement, and stock-reversal correctness.
"""

from __future__ import annotations

from decimal import Decimal
from uuid import UUID

import pytest
from sqlmodel import select
from sqlmodel.ext.asyncio.session import AsyncSession

from app.models.inventory import (
    Item,
    ItemType,
    ProcessedEvent,
    StockLevel,
    StockMovement,
)
from app.services.event_handlers import (
    handle_order_confirmed,
    handle_purchase_received,
    handle_sale_completed,
    handle_sale_refunded,
    handle_sale_voided,
)
from app.services.stock_movement_service import ItemTypeMismatchError

BUSINESS_ID = UUID("00000000-0000-0000-0000-000000000001")
STORE_ID = UUID("00000000-0000-0000-0000-000000000010")


async def _create_item(
    db: AsyncSession,
    *,
    item_type: ItemType = ItemType.BOTH,
    allow_negative_stock: bool = False,
    name: str = "Test Item",
) -> Item:
    item = Item(
        business_id=BUSINESS_ID,
        store_id=STORE_ID,
        name=name,
        category="test",
        reorder_threshold=Decimal("10.000"),
        reorder_quantity=Decimal("20.000"),
        allow_negative_stock=allow_negative_stock,
        item_type=item_type,
    )
    db.add(item)
    await db.commit()
    await db.refresh(item)
    return item


async def _create_stock_level(
    db: AsyncSession,
    item_id: UUID,
    quantity: Decimal = Decimal("10.000"),
) -> StockLevel:
    sl = StockLevel(
        item_id=item_id,
        store_id=STORE_ID,
        current_quantity=quantity,
    )
    db.add(sl)
    await db.commit()
    await db.refresh(sl)
    return sl


# ── Sale completed ───────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_sale_completed_multi_item(db_session: AsyncSession) -> None:
    item_a = await _create_item(db_session, name="Item A")
    item_b = await _create_item(db_session, name="Item B")
    await _create_stock_level(db_session, item_a.id, quantity=Decimal("20.000"))
    await _create_stock_level(db_session, item_b.id, quantity=Decimal("30.000"))

    payload = {
        "event_id": "sale-evt-001",
        "business_id": str(BUSINESS_ID),
        "store_id": str(STORE_ID),
        "sale_id": "00000000-0000-0000-0000-000000000100",
        "line_items": [
            {"item_id": str(item_a.id), "quantity": Decimal("3.000")},
            {"item_id": str(item_b.id), "quantity": Decimal("5.000")},
        ],
    }

    movements = await handle_sale_completed(db_session, payload)
    assert len(movements) == 2

    result = await db_session.exec(
        select(StockLevel).where(StockLevel.item_id == item_a.id)
    )
    assert result.one().current_quantity == Decimal("17.000")

    result = await db_session.exec(
        select(StockLevel).where(StockLevel.item_id == item_b.id)
    )
    assert result.one().current_quantity == Decimal("25.000")

    total_movements = await db_session.exec(select(StockMovement))
    assert len(total_movements.all()) == 2


@pytest.mark.asyncio
async def test_sale_completed_bypasses_negative_stock(db_session: AsyncSession) -> None:
    """A sale that would drive stock negative still succeeds because the
    physical sale has already happened."""
    item = await _create_item(db_session, allow_negative_stock=False, name="Can Go Negative")
    await _create_stock_level(db_session, item.id, quantity=Decimal("2.000"))

    payload = {
        "event_id": "sale-evt-negative",
        "business_id": str(BUSINESS_ID),
        "store_id": str(STORE_ID),
        "sale_id": "00000000-0000-0000-0000-000000000200",
        "line_items": [
            {"item_id": str(item.id), "quantity": Decimal("5.000")},
        ],
    }

    movements = await handle_sale_completed(db_session, payload)
    assert len(movements) == 1
    assert movements[0].quantity_delta == Decimal("-5.000")

    result = await db_session.exec(
        select(StockLevel).where(StockLevel.item_id == item.id)
    )
    assert result.one().current_quantity == Decimal("-3.000")


@pytest.mark.asyncio
async def test_sale_completed_full_event_idempotency(db_session: AsyncSession) -> None:
    """Calling handle_sale_completed twice with the same event_id and
    payload only applies each line item's decrement ONCE."""
    item_a = await _create_item(db_session, name="Idem A")
    item_b = await _create_item(db_session, name="Idem B")
    await _create_stock_level(db_session, item_a.id, quantity=Decimal("50.000"))
    await _create_stock_level(db_session, item_b.id, quantity=Decimal("50.000"))

    payload = {
        "event_id": "sale-evt-idem",
        "business_id": str(BUSINESS_ID),
        "store_id": str(STORE_ID),
        "sale_id": "00000000-0000-0000-0000-000000000300",
        "line_items": [
            {"item_id": str(item_a.id), "quantity": Decimal("10.000")},
            {"item_id": str(item_b.id), "quantity": Decimal("20.000")},
        ],
    }

    # First call
    await handle_sale_completed(db_session, payload)

    # Second call — same event_id
    await handle_sale_completed(db_session, payload)

    # Stock should reflect only the first call's decrements
    result = await db_session.exec(
        select(StockLevel).where(StockLevel.item_id == item_a.id)
    )
    assert result.one().current_quantity == Decimal("40.000")

    result = await db_session.exec(
        select(StockLevel).where(StockLevel.item_id == item_b.id)
    )
    assert result.one().current_quantity == Decimal("30.000")

    # Only two movement rows (one per item), not four
    result = await db_session.exec(select(StockMovement))
    assert len(result.all()) == 2

    # Both ProcessedEvent rows exist for the derived keys
    key_a = f"sale-evt-idem:{item_a.id}"
    key_b = f"sale-evt-idem:{item_b.id}"
    assert await db_session.get(ProcessedEvent, key_a) is not None
    assert await db_session.get(ProcessedEvent, key_b) is not None


@pytest.mark.asyncio
async def test_sale_completed_partial_retry_idempotency(db_session: AsyncSession) -> None:
    """Simulate a partial failure: first call succeeds for item A, then
    the handler crashes before processing item B.  A retry with the same
    event_id must skip item A (derived key already exists) and only
    process item B."""
    # We'll test this by calling record_movement directly for item A
    # (simulating success before crash), then calling the full handler.
    from app.models.inventory import ActorType, MovementType
    from app.services.stock_movement_service import record_movement

    item_a = await _create_item(db_session, name="Partial A")
    item_b = await _create_item(db_session, name="Partial B")
    await _create_stock_level(db_session, item_a.id, quantity=Decimal("100.000"))
    await _create_stock_level(db_session, item_b.id, quantity=Decimal("100.000"))

    event_id = "sale-evt-partial"
    derived_a = f"{event_id}:{item_a.id}"
    sale_id = UUID("00000000-0000-0000-0000-000000000400")

    # Simulate the first item being processed before the crash
    await record_movement(
        db=db_session,
        item_id=item_a.id,
        business_id=BUSINESS_ID,
        store_id=STORE_ID,
        quantity_delta=Decimal("-10.000"),
        movement_type=MovementType.SALE,
        reference_type="sale",
        reference_id=sale_id,
        actor_type=ActorType.SERVICE.value,
        reason="sale 00000000-0000-0000-0000-000000000400",
        event_id=derived_a,
        skip_negative_check=True,
    )

    # Now the full handler runs as a retry
    payload = {
        "event_id": event_id,
        "business_id": str(BUSINESS_ID),
        "store_id": str(STORE_ID),
        "sale_id": str(sale_id),
        "line_items": [
            {"item_id": str(item_a.id), "quantity": Decimal("10.000")},
            {"item_id": str(item_b.id), "quantity": Decimal("20.000")},
        ],
    }

    movements = await handle_sale_completed(db_session, payload)
    # Both items "processed" but item A was idempotently skipped
    assert len(movements) == 2

    # Item A's stock decremented only once (by -10, not -20)
    result = await db_session.exec(
        select(StockLevel).where(StockLevel.item_id == item_a.id)
    )
    assert result.one().current_quantity == Decimal("90.000")

    # Item B was processed normally
    result = await db_session.exec(
        select(StockLevel).where(StockLevel.item_id == item_b.id)
    )
    assert result.one().current_quantity == Decimal("80.000")


@pytest.mark.asyncio
async def test_sale_completed_on_raw_material_raises_item_type_mismatch(
    db_session: AsyncSession,
) -> None:
    """The item_type compatibility check is NOT bypassed for sale handlers."""
    item = await _create_item(db_session, item_type=ItemType.RAW_MATERIAL, name="RawOnly")
    await _create_stock_level(db_session, item.id, quantity=Decimal("10.000"))

    payload = {
        "event_id": "sale-evt-typeerr",
        "business_id": str(BUSINESS_ID),
        "store_id": str(STORE_ID),
        "sale_id": "00000000-0000-0000-0000-000000000500",
        "line_items": [
            {"item_id": str(item.id), "quantity": Decimal("1.000")},
        ],
    }

    with pytest.raises(ItemTypeMismatchError, match="raw_material"):
        await handle_sale_completed(db_session, payload)


# ── Order confirmed ──────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_order_confirmed_behaves_like_sale(db_session: AsyncSession) -> None:
    """handle_order_confirmed is identical to sale except reference_type."""
    item = await _create_item(db_session, name="Order Item")
    await _create_stock_level(db_session, item.id, quantity=Decimal("50.000"))

    payload = {
        "event_id": "order-evt-001",
        "business_id": str(BUSINESS_ID),
        "store_id": str(STORE_ID),
        "order_id": "00000000-0000-0000-0000-000000000600",
        "line_items": [
            {"item_id": str(item.id), "quantity": Decimal("7.000")},
        ],
    }

    movements = await handle_order_confirmed(db_session, payload)
    assert len(movements) == 1
    assert movements[0].reference_type == "order"
    assert str(movements[0].reference_id) == "00000000-0000-0000-0000-000000000600"
    assert movements[0].quantity_delta == Decimal("-7.000")

    result = await db_session.exec(
        select(StockLevel).where(StockLevel.item_id == item.id)
    )
    assert result.one().current_quantity == Decimal("43.000")


@pytest.mark.asyncio
async def test_order_confirmed_bypasses_negative_stock(db_session: AsyncSession) -> None:
    """Same negative-stock bypass as sale."""
    item = await _create_item(db_session, allow_negative_stock=False, name="Order Negative")
    await _create_stock_level(db_session, item.id, quantity=Decimal("1.000"))

    payload = {
        "event_id": "order-evt-negative",
        "business_id": str(BUSINESS_ID),
        "store_id": str(STORE_ID),
        "order_id": "00000000-0000-0000-0000-000000000700",
        "line_items": [
            {"item_id": str(item.id), "quantity": Decimal("3.000")},
        ],
    }

    movements = await handle_order_confirmed(db_session, payload)
    assert movements[0].quantity_delta == Decimal("-3.000")

    result = await db_session.exec(
        select(StockLevel).where(StockLevel.item_id == item.id)
    )
    assert result.one().current_quantity == Decimal("-2.000")


# ── Purchase received ────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_purchase_received_increases_stock(db_session: AsyncSession) -> None:
    item = await _create_item(db_session, item_type=ItemType.RAW_MATERIAL, name="Proc Item")
    await _create_stock_level(db_session, item.id, quantity=Decimal("10.000"))

    payload = {
        "event_id": "purchase-evt-001",
        "business_id": str(BUSINESS_ID),
        "store_id": str(STORE_ID),
        "purchase_order_id": "00000000-0000-0000-0000-000000000800",
        "line_items": [
            {"item_id": str(item.id), "quantity": Decimal("25.000")},
        ],
    }

    movements = await handle_purchase_received(db_session, payload)
    assert len(movements) == 1
    assert movements[0].quantity_delta == Decimal("25.000")
    assert movements[0].reference_type == "purchase_order"

    result = await db_session.exec(
        select(StockLevel).where(StockLevel.item_id == item.id)
    )
    assert result.one().current_quantity == Decimal("35.000")


@pytest.mark.asyncio
async def test_purchase_received_on_sellable_raises_item_type_mismatch(
    db_session: AsyncSession,
) -> None:
    """ItemType check is NOT bypassed for purchase_received — a purchase
    against a sellable-only item is a real configuration error."""
    item = await _create_item(db_session, item_type=ItemType.SELLABLE, name="SellableOnly")

    payload = {
        "event_id": "purchase-evt-typeerr",
        "business_id": str(BUSINESS_ID),
        "store_id": str(STORE_ID),
        "purchase_order_id": "00000000-0000-0000-0000-000000000900",
        "line_items": [
            {"item_id": str(item.id), "quantity": Decimal("10.000")},
        ],
    }

    with pytest.raises(ItemTypeMismatchError, match="sellable"):
        await handle_purchase_received(db_session, payload)

    # No movement or stock level should have been committed
    result = await db_session.exec(select(StockMovement))
    assert len(result.all()) == 0

    result = await db_session.exec(select(StockLevel))
    assert result.first() is None


# ── Sale voided ──────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_sale_voided_increases_stock(db_session: AsyncSession) -> None:
    """A voided sale reverses the stock decrement — each line item's
    quantity_delta is positive and the movement type is sale_reversal."""
    item_a = await _create_item(db_session, name="Void A")
    item_b = await _create_item(db_session, name="Void B")
    await _create_stock_level(db_session, item_a.id, quantity=Decimal("10.000"))
    await _create_stock_level(db_session, item_b.id, quantity=Decimal("20.000"))

    payload = {
        "event_id": "void-evt-001",
        "business_id": str(BUSINESS_ID),
        "store_id": str(STORE_ID),
        "sale_id": "00000000-0000-0000-0000-000000001000",
        "line_items": [
            {"item_id": str(item_a.id), "quantity": Decimal("3.000")},
            {"item_id": str(item_b.id), "quantity": Decimal("5.000")},
        ],
    }

    movements = await handle_sale_voided(db_session, payload)
    assert len(movements) == 2

    result = await db_session.exec(
        select(StockLevel).where(StockLevel.item_id == item_a.id)
    )
    assert result.one().current_quantity == Decimal("13.000")

    result = await db_session.exec(
        select(StockLevel).where(StockLevel.item_id == item_b.id)
    )
    assert result.one().current_quantity == Decimal("25.000")

    # Verify movement_type and sign
    movements_all = (await db_session.exec(select(StockMovement))).all()
    assert len(movements_all) == 2
    assert all(m.movement_type.value == "sale_reversal" for m in movements_all)
    assert all(m.quantity_delta > Decimal("0") for m in movements_all)
    assert all(m.reference_type == "sale" for m in movements_all)


@pytest.mark.asyncio
async def test_sale_voided_on_raw_material_succeeds(db_session: AsyncSession) -> None:
    """sale_reversal is exempt from the sale/raw_material restriction —
    a voided sale may affect raw_material-only items without being a
    configuration error."""
    item = await _create_item(db_session, item_type=ItemType.RAW_MATERIAL, name="Raw Reversal")
    await _create_stock_level(db_session, item.id, quantity=Decimal("10.000"))

    payload = {
        "event_id": "void-evt-raw",
        "business_id": str(BUSINESS_ID),
        "store_id": str(STORE_ID),
        "sale_id": "00000000-0000-0000-0000-000000001010",
        "line_items": [
            {"item_id": str(item.id), "quantity": Decimal("4.000")},
        ],
    }

    movements = await handle_sale_voided(db_session, payload)
    assert len(movements) == 1
    assert movements[0].quantity_delta == Decimal("4.000")

    result = await db_session.exec(
        select(StockLevel).where(StockLevel.item_id == item.id)
    )
    assert result.one().current_quantity == Decimal("14.000")


@pytest.mark.asyncio
async def test_sale_voided_on_sellable_succeeds(db_session: AsyncSession) -> None:
    """sale_reversal is exempt from any item_type restriction."""
    item = await _create_item(db_session, item_type=ItemType.SELLABLE, name="Sellable Reversal")
    await _create_stock_level(db_session, item.id, quantity=Decimal("10.000"))

    payload = {
        "event_id": "void-evt-sell",
        "business_id": str(BUSINESS_ID),
        "store_id": str(STORE_ID),
        "sale_id": "00000000-0000-0000-0000-000000001020",
        "line_items": [
            {"item_id": str(item.id), "quantity": Decimal("2.000")},
        ],
    }

    movements = await handle_sale_voided(db_session, payload)
    assert len(movements) == 1
    result = await db_session.exec(
        select(StockLevel).where(StockLevel.item_id == item.id)
    )
    assert result.one().current_quantity == Decimal("12.000")


@pytest.mark.asyncio
async def test_sale_voided_idempotency(db_session: AsyncSession) -> None:
    """Calling handle_sale_voided twice with the same event_id only
    reverses stock once."""
    item = await _create_item(db_session, name="Void Idem")
    await _create_stock_level(db_session, item.id, quantity=Decimal("50.000"))

    payload = {
        "event_id": "void-evt-idem",
        "business_id": str(BUSINESS_ID),
        "store_id": str(STORE_ID),
        "sale_id": "00000000-0000-0000-0000-000000001030",
        "line_items": [
            {"item_id": str(item.id), "quantity": Decimal("15.000")},
        ],
    }

    await handle_sale_voided(db_session, payload)
    await handle_sale_voided(db_session, payload)

    result = await db_session.exec(
        select(StockLevel).where(StockLevel.item_id == item.id)
    )
    assert result.one().current_quantity == Decimal("65.000")

    movements = await db_session.exec(select(StockMovement))
    assert len(movements.all()) == 1

    key = f"void-evt-idem:{item.id}"
    assert await db_session.get(ProcessedEvent, key) is not None


# ── Sale refunded ────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_sale_refunded_increases_stock(db_session: AsyncSession) -> None:
    """A refunded sale reverses stock with movement_type=refund_reversal."""
    item = await _create_item(db_session, name="Refund A")
    await _create_stock_level(db_session, item.id, quantity=Decimal("10.000"))

    payload = {
        "event_id": "refund-evt-001",
        "business_id": str(BUSINESS_ID),
        "store_id": str(STORE_ID),
        "sale_id": "00000000-0000-0000-0000-000000001100",
        "line_items": [
            {"item_id": str(item.id), "quantity": Decimal("7.000")},
        ],
    }

    movements = await handle_sale_refunded(db_session, payload)
    assert len(movements) == 1
    assert movements[0].movement_type.value == "refund_reversal"
    assert movements[0].quantity_delta == Decimal("7.000")

    result = await db_session.exec(
        select(StockLevel).where(StockLevel.item_id == item.id)
    )
    assert result.one().current_quantity == Decimal("17.000")


@pytest.mark.asyncio
async def test_sale_refunded_on_raw_material_succeeds(db_session: AsyncSession) -> None:
    """refund_reversal is exempt from the item_type restriction, same as
    sale_reversal."""
    item = await _create_item(db_session, item_type=ItemType.RAW_MATERIAL, name="Raw Refund")
    await _create_stock_level(db_session, item.id, quantity=Decimal("10.000"))

    payload = {
        "event_id": "refund-evt-raw",
        "business_id": str(BUSINESS_ID),
        "store_id": str(STORE_ID),
        "sale_id": "00000000-0000-0000-0000-000000001110",
        "line_items": [
            {"item_id": str(item.id), "quantity": Decimal("3.000")},
        ],
    }

    movements = await handle_sale_refunded(db_session, payload)
    assert len(movements) == 1
    assert movements[0].quantity_delta == Decimal("3.000")

    result = await db_session.exec(
        select(StockLevel).where(StockLevel.item_id == item.id)
    )
    assert result.one().current_quantity == Decimal("13.000")


@pytest.mark.asyncio
async def test_sale_refunded_idempotency(db_session: AsyncSession) -> None:
    """Calling handle_sale_refunded twice with the same event_id only
    reverses stock once."""
    item = await _create_item(db_session, name="Refund Idem")
    await _create_stock_level(db_session, item.id, quantity=Decimal("30.000"))

    payload = {
        "event_id": "refund-evt-idem",
        "business_id": str(BUSINESS_ID),
        "store_id": str(STORE_ID),
        "sale_id": "00000000-0000-0000-0000-000000001120",
        "line_items": [
            {"item_id": str(item.id), "quantity": Decimal("10.000")},
        ],
    }

    await handle_sale_refunded(db_session, payload)
    await handle_sale_refunded(db_session, payload)

    result = await db_session.exec(
        select(StockLevel).where(StockLevel.item_id == item.id)
    )
    assert result.one().current_quantity == Decimal("40.000")

    movements = await db_session.exec(select(StockMovement))
    assert len(movements.all()) == 1


# ── Post-gap-closure integration check ───────────────────────────────────


@pytest.mark.asyncio
async def test_sale_completed_then_voided_fully_reverses(db_session: AsyncSession) -> None:
    """Integration-style: complete a sale (stock drops), then void it
    (stock rises back).  The net effect on stock should be zero.

    This test verifies the full POS → Inventory lifecycle that was the
    subject of the POS Service's KNOWN_GAP test (now closed).
    """
    item = await _create_item(db_session, name="Full Lifecycle")
    await _create_stock_level(db_session, item.id, quantity=Decimal("100.000"))

    sale_id = "00000000-0000-0000-0000-000000009999"

    # Step 1: sale.completed — stock goes down
    complete_payload = {
        "event_id": "lifecycle-sale-001",
        "business_id": str(BUSINESS_ID),
        "store_id": str(STORE_ID),
        "sale_id": sale_id,
        "line_items": [
            {"item_id": str(item.id), "quantity": Decimal("20.000")},
        ],
    }
    await handle_sale_completed(db_session, complete_payload)

    result = await db_session.exec(
        select(StockLevel).where(StockLevel.item_id == item.id)
    )
    assert result.one().current_quantity == Decimal("80.000")

    # Step 2: sale.voided — stock goes back up
    void_payload = {
        "event_id": "lifecycle-void-001",
        "business_id": str(BUSINESS_ID),
        "store_id": str(STORE_ID),
        "sale_id": sale_id,
        "line_items": [
            {"item_id": str(item.id), "quantity": Decimal("20.000")},
        ],
    }
    await handle_sale_voided(db_session, void_payload)

    result = await db_session.exec(
        select(StockLevel).where(StockLevel.item_id == item.id)
    )
    assert result.one().current_quantity == Decimal("100.000")

    # Two distinct movement types recorded
    movements = (await db_session.exec(select(StockMovement))).all()
    assert len(movements) == 2
    assert {m.movement_type.value for m in movements} == {"sale", "sale_reversal"}
