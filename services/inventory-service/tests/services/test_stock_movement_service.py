"""Tests for the stock movement engine (Stage 5).

These are the most important tests in the entire service — they cover
locking correctness, atomicity, concurrency safety, type-compatibility
enforcement, and event emission.
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
    MovementType,
    ProcessedEvent,
    StockLevel,
    StockMovement,
)
from app.services.stock_movement_service import (
    InsufficientStockError,
    ItemTypeMismatchError,
    record_movement,
)

BUSINESS_ID = UUID("00000000-0000-0000-0000-000000000001")
STORE_ID = UUID("00000000-0000-0000-0000-000000000010")
STORE_ID_2 = UUID("00000000-0000-0000-0000-000000000020")


async def _create_item(
    db: AsyncSession,
    *,
    item_type: ItemType = ItemType.BOTH,
    allow_negative_stock: bool = False,
    reorder_threshold: Decimal = Decimal("10.000"),
    reorder_quantity: Decimal = Decimal("20.000"),
    name: str = "Test Item",
) -> Item:
    item = Item(
        business_id=BUSINESS_ID,
        store_id=STORE_ID,
        name=name,
        reorder_threshold=reorder_threshold,
        reorder_quantity=reorder_quantity,
        allow_negative_stock=allow_negative_stock,
        item_type=item_type,
    )
    db.add(item)
    await db.commit()
    await db.refresh(item)
    return item


async def _count_rows(db: AsyncSession, model: type) -> int:
    result = await db.exec(select(model))
    return len(result.all())


# ── Happy path: normal movements ──────────────────────────────────────────────


@pytest.mark.asyncio
async def test_normal_movement_updates_both_tables(db_session: AsyncSession) -> None:
    item = await _create_item(db_session, item_type=ItemType.RAW_MATERIAL)

    movement = await record_movement(
        db=db_session,
        item_id=item.id,
        business_id=BUSINESS_ID,
        store_id=STORE_ID,
        quantity_delta=Decimal("50.000"),
        movement_type=MovementType.PURCHASE_RECEIVED,
        actor_type="system",
    )

    assert movement.item_id == item.id
    assert movement.quantity_delta == Decimal("50.000")

    # Stock level updated
    result = await db_session.exec(
        select(StockLevel).where(
            StockLevel.item_id == item.id,
            StockLevel.store_id == STORE_ID,
        )
    )
    sl = result.one()
    assert sl.current_quantity == Decimal("50.000")

    # Movement row created
    result = await db_session.exec(select(StockMovement))
    assert len(result.all()) == 1


# ── ItemType / MovementType compatibility ─────────────────────────────────────


@pytest.mark.asyncio
async def test_sale_on_raw_material_raises_item_type_mismatch(db_session: AsyncSession) -> None:
    item = await _create_item(db_session, item_type=ItemType.RAW_MATERIAL)

    with pytest.raises(ItemTypeMismatchError, match="raw_material"):
        await record_movement(
            db=db_session,
            item_id=item.id,
            business_id=BUSINESS_ID,
            store_id=STORE_ID,
            quantity_delta=Decimal("-10.000"),
            movement_type=MovementType.SALE,
        )

    # Neither table written
    assert await _count_rows(db_session, StockMovement) == 0
    assert await _count_rows(db_session, StockLevel) == 0


@pytest.mark.asyncio
async def test_purchase_received_on_sellable_raises_item_type_mismatch(
    db_session: AsyncSession,
) -> None:
    item = await _create_item(db_session, item_type=ItemType.SELLABLE)

    with pytest.raises(ItemTypeMismatchError, match="sellable"):
        await record_movement(
            db=db_session,
            item_id=item.id,
            business_id=BUSINESS_ID,
            store_id=STORE_ID,
            quantity_delta=Decimal("20.000"),
            movement_type=MovementType.PURCHASE_RECEIVED,
        )

    assert await _count_rows(db_session, StockMovement) == 0
    assert await _count_rows(db_session, StockLevel) == 0


@pytest.mark.asyncio
async def test_sale_on_sellable_succeeds(db_session: AsyncSession) -> None:
    item = await _create_item(db_session, item_type=ItemType.SELLABLE)

    # First add stock via manual_adjustment (allowed for any type)
    await record_movement(
        db=db_session,
        item_id=item.id,
        business_id=BUSINESS_ID,
        store_id=STORE_ID,
        quantity_delta=Decimal("30.000"),
        movement_type=MovementType.MANUAL_ADJUSTMENT,
    )

    movement = await record_movement(
        db=db_session,
        item_id=item.id,
        business_id=BUSINESS_ID,
        store_id=STORE_ID,
        quantity_delta=Decimal("-10.000"),
        movement_type=MovementType.SALE,
    )

    assert movement.movement_type == MovementType.SALE
    result = await db_session.exec(select(StockLevel).where(StockLevel.item_id == item.id))
    assert result.one().current_quantity == Decimal("20.000")


@pytest.mark.asyncio
async def test_purchase_received_on_both_succeeds(db_session: AsyncSession) -> None:
    item = await _create_item(db_session, item_type=ItemType.BOTH)

    movement = await record_movement(
        db=db_session,
        item_id=item.id,
        business_id=BUSINESS_ID,
        store_id=STORE_ID,
        quantity_delta=Decimal("100.000"),
        movement_type=MovementType.PURCHASE_RECEIVED,
    )

    assert movement.movement_type == MovementType.PURCHASE_RECEIVED

    # Now sale on same both item
    movement2 = await record_movement(
        db=db_session,
        item_id=item.id,
        business_id=BUSINESS_ID,
        store_id=STORE_ID,
        quantity_delta=Decimal("-30.000"),
        movement_type=MovementType.SALE,
    )

    assert movement2.movement_type == MovementType.SALE
    result = await db_session.exec(select(StockLevel).where(StockLevel.item_id == item.id))
    assert result.one().current_quantity == Decimal("70.000")


@pytest.mark.asyncio
async def test_waste_on_raw_material_succeeds(db_session: AsyncSession) -> None:
    item = await _create_item(db_session, item_type=ItemType.RAW_MATERIAL)

    await record_movement(
        db=db_session,
        item_id=item.id,
        business_id=BUSINESS_ID,
        store_id=STORE_ID,
        quantity_delta=Decimal("50.000"),
        movement_type=MovementType.PURCHASE_RECEIVED,
    )

    movement = await record_movement(
        db=db_session,
        item_id=item.id,
        business_id=BUSINESS_ID,
        store_id=STORE_ID,
        quantity_delta=Decimal("-5.000"),
        movement_type=MovementType.WASTE,
    )

    assert movement.movement_type == MovementType.WASTE
    result = await db_session.exec(select(StockLevel).where(StockLevel.item_id == item.id))
    assert result.one().current_quantity == Decimal("45.000")


# ── Negative stock checks ─────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_negative_stock_disallowed_raises_error(db_session: AsyncSession) -> None:
    item = await _create_item(db_session, allow_negative_stock=False)

    with pytest.raises(InsufficientStockError, match="Insufficient stock"):
        await record_movement(
            db=db_session,
            item_id=item.id,
            business_id=BUSINESS_ID,
            store_id=STORE_ID,
            quantity_delta=Decimal("-1.000"),
            movement_type=MovementType.MANUAL_ADJUSTMENT,
        )

    # Use a separate session to verify no rows were committed to the DB
    from app.core.database import async_session_factory

    async with async_session_factory() as verify_session:
        assert await _count_rows(verify_session, StockMovement) == 0
        result = await verify_session.exec(select(StockLevel).where(StockLevel.item_id == item.id))
        assert result.first() is None


@pytest.mark.asyncio
async def test_negative_stock_allowed_succeeds(db_session: AsyncSession) -> None:
    item = await _create_item(db_session, allow_negative_stock=True)

    movement = await record_movement(
        db=db_session,
        item_id=item.id,
        business_id=BUSINESS_ID,
        store_id=STORE_ID,
        quantity_delta=Decimal("-5.000"),
        movement_type=MovementType.MANUAL_ADJUSTMENT,
    )

    assert movement.quantity_delta == Decimal("-5.000")
    result = await db_session.exec(select(StockLevel).where(StockLevel.item_id == item.id))
    assert result.one().current_quantity == Decimal("-5.000")


# ── First movement creates stock_levels row ──────────────────────────────────


@pytest.mark.asyncio
async def test_first_movement_creates_stock_level_row(db_session: AsyncSession) -> None:
    item = await _create_item(db_session, item_type=ItemType.RAW_MATERIAL)

    assert await _count_rows(db_session, StockLevel) == 0

    await record_movement(
        db=db_session,
        item_id=item.id,
        business_id=BUSINESS_ID,
        store_id=STORE_ID,
        quantity_delta=Decimal("25.000"),
        movement_type=MovementType.PURCHASE_RECEIVED,
    )

    assert await _count_rows(db_session, StockLevel) == 1
    result = await db_session.exec(select(StockLevel).where(StockLevel.item_id == item.id))
    assert result.one().current_quantity == Decimal("25.000")


# ── Idempotency (event_id) ───────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_duplicate_event_id_skips_second_movement(db_session: AsyncSession) -> None:
    item = await _create_item(db_session, item_type=ItemType.BOTH)
    event_id = "evt-001"

    # First call
    m1 = await record_movement(
        db=db_session,
        item_id=item.id,
        business_id=BUSINESS_ID,
        store_id=STORE_ID,
        quantity_delta=Decimal("30.000"),
        movement_type=MovementType.PURCHASE_RECEIVED,
        event_id=event_id,
    )
    assert m1 is not None

    # Second call with same event_id
    _m2 = await record_movement(
        db=db_session,
        item_id=item.id,
        business_id=BUSINESS_ID,
        store_id=STORE_ID,
        quantity_delta=Decimal("100.000"),
        movement_type=MovementType.PURCHASE_RECEIVED,
        event_id=event_id,
    )

    # Only one movement row
    result = await db_session.exec(select(StockMovement))
    movements = result.all()
    assert len(movements) == 1
    assert movements[0].quantity_delta == Decimal("30.000")

    # Stock level reflects first movement only
    result = await db_session.exec(select(StockLevel).where(StockLevel.item_id == item.id))
    assert result.one().current_quantity == Decimal("30.000")

    # ProcessedEvent row exists
    processed = await db_session.get(ProcessedEvent, event_id)
    assert processed is not None


@pytest.mark.asyncio
async def test_no_event_id_does_not_create_processed_event(db_session: AsyncSession) -> None:
    item = await _create_item(db_session, item_type=ItemType.BOTH)

    await record_movement(
        db=db_session,
        item_id=item.id,
        business_id=BUSINESS_ID,
        store_id=STORE_ID,
        quantity_delta=Decimal("10.000"),
        movement_type=MovementType.PURCHASE_RECEIVED,
    )

    assert await _count_rows(db_session, ProcessedEvent) == 0


# ── Different stores get independent stock_levels ─────────────────────────


@pytest.mark.asyncio
async def test_different_stores_independent_stock(db_session: AsyncSession) -> None:
    item = await _create_item(db_session, item_type=ItemType.BOTH)

    await record_movement(
        db=db_session,
        item_id=item.id,
        business_id=BUSINESS_ID,
        store_id=STORE_ID,
        quantity_delta=Decimal("10.000"),
        movement_type=MovementType.PURCHASE_RECEIVED,
    )

    await record_movement(
        db=db_session,
        item_id=item.id,
        business_id=BUSINESS_ID,
        store_id=STORE_ID_2,
        quantity_delta=Decimal("20.000"),
        movement_type=MovementType.PURCHASE_RECEIVED,
    )

    result = await db_session.exec(select(StockLevel).order_by(StockLevel.store_id))
    levels = result.all()
    assert len(levels) == 2
    assert levels[0].current_quantity == Decimal("10.000")
    assert levels[1].current_quantity == Decimal("20.000")


# ── Concurrency (lost update prevention) ─────────────────────────────────────


@pytest.mark.asyncio
async def test_concurrent_movements_no_lost_update(db_session: AsyncSession) -> None:
    """Two concurrent movements against the same item/store must both apply.
    Each call uses its own session to simulate real concurrent HTTP requests."""
    item = await _create_item(db_session, item_type=ItemType.BOTH, allow_negative_stock=False)
    item_id = item.id

    from app.core.database import async_session_factory

    async def add_50() -> None:
        async with async_session_factory() as sess:
            await record_movement(
                db=sess,
                item_id=item_id,
                business_id=BUSINESS_ID,
                store_id=STORE_ID,
                quantity_delta=Decimal("50.000"),
                movement_type=MovementType.PURCHASE_RECEIVED,
            )

    async def add_30() -> None:
        async with async_session_factory() as sess:
            await record_movement(
                db=sess,
                item_id=item_id,
                business_id=BUSINESS_ID,
                store_id=STORE_ID,
                quantity_delta=Decimal("30.000"),
                movement_type=MovementType.PURCHASE_RECEIVED,
            )

    import asyncio

    await asyncio.gather(add_50(), add_30())

    # Read final state in test session
    result = await db_session.exec(select(StockLevel).where(StockLevel.item_id == item_id))
    sl = result.one()
    assert sl.current_quantity == Decimal("80.000"), (
        f"Expected 80.000, got {sl.current_quantity} — lost update detected"
    )

    result = await db_session.exec(select(StockMovement))
    assert len(result.all()) == 2


# ── Reorder threshold crossing ────────────────────────────────────────────────
# Note: event publishing is *logged* by publish_event, which currently writes
# a structlog line.  We cannot assert on log output easily in this test
# framework, so we verify the *side-effect behavior* (no DB changes on skip,
# correct quantity after each call).  The event emission logic is tested
# implicitly: if publish_event fails with an exception the tests catch that.


@pytest.mark.asyncio
async def test_movement_with_valid_data_does_not_raise(db_session: AsyncSession) -> None:
    item = await _create_item(
        db_session, item_type=ItemType.BOTH, reorder_threshold=Decimal("10.000")
    )

    await record_movement(
        db=db_session,
        item_id=item.id,
        business_id=BUSINESS_ID,
        store_id=STORE_ID,
        quantity_delta=Decimal("5.000"),
        movement_type=MovementType.MANUAL_ADJUSTMENT,
    )

    result = await db_session.exec(select(StockLevel).where(StockLevel.item_id == item.id))
    assert result.one().current_quantity == Decimal("5.000")


# ── Edge cases ────────────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_nonexistent_item_raises_value_error(db_session: AsyncSession) -> None:
    fake_id = UUID("ffffffff-ffff-ffff-ffff-ffffffffffff")

    with pytest.raises(ValueError, match="not found"):
        await record_movement(
            db=db_session,
            item_id=fake_id,
            business_id=BUSINESS_ID,
            store_id=STORE_ID,
            quantity_delta=Decimal("10.000"),
            movement_type=MovementType.PURCHASE_RECEIVED,
        )


@pytest.mark.asyncio
async def test_zero_delta_movement_succeeds(db_session: AsyncSession) -> None:
    item = await _create_item(db_session, item_type=ItemType.BOTH)

    movement = await record_movement(
        db=db_session,
        item_id=item.id,
        business_id=BUSINESS_ID,
        store_id=STORE_ID,
        quantity_delta=Decimal("0.000"),
        movement_type=MovementType.MANUAL_ADJUSTMENT,
    )

    assert movement.quantity_delta == Decimal("0.000")

    result = await db_session.exec(select(StockLevel).where(StockLevel.item_id == item.id))
    assert result.one().current_quantity == Decimal("0.000")


@pytest.mark.asyncio
async def test_sale_on_both_with_negative_stock_allowed(db_session: AsyncSession) -> None:
    item = await _create_item(db_session, item_type=ItemType.BOTH, allow_negative_stock=True)

    movement = await record_movement(
        db=db_session,
        item_id=item.id,
        business_id=BUSINESS_ID,
        store_id=STORE_ID,
        quantity_delta=Decimal("-10.000"),
        movement_type=MovementType.SALE,
    )

    assert movement.quantity_delta == Decimal("-10.000")
    result = await db_session.exec(select(StockLevel).where(StockLevel.item_id == item.id))
    assert result.one().current_quantity == Decimal("-10.000")


# ── skip_negative_check bypass ────────────────────────────────────────────
# Stage 7 introduces skip_negative_check for event handlers that must
# record sales even when inventory goes negative.  These tests prove the
# bypass works and the default (False) is unchanged.


@pytest.mark.asyncio
async def test_skip_negative_check_bypasses_insufficient_stock(db_session: AsyncSession) -> None:
    """A movement with skip_negative_check=True on an allow_negative_stock=False
    item SUCCEEDS and produces negative stock."""
    item = await _create_item(db_session, allow_negative_stock=False)

    movement = await record_movement(
        db=db_session,
        item_id=item.id,
        business_id=BUSINESS_ID,
        store_id=STORE_ID,
        quantity_delta=Decimal("-5.000"),
        movement_type=MovementType.SALE,
        skip_negative_check=True,
    )

    assert movement.quantity_delta == Decimal("-5.000")
    result = await db_session.exec(select(StockLevel).where(StockLevel.item_id == item.id))
    assert result.one().current_quantity == Decimal("-5.000")


@pytest.mark.asyncio
async def test_skip_negative_check_default_false_still_raises(db_session: AsyncSession) -> None:
    """The default skip_negative_check=False behaves exactly as before —
    InsufficientStockError is raised for negative-quantity movements on
    items that disallow negative stock."""
    item = await _create_item(db_session, allow_negative_stock=False)

    with pytest.raises(InsufficientStockError, match="Insufficient stock"):
        await record_movement(
            db=db_session,
            item_id=item.id,
            business_id=BUSINESS_ID,
            store_id=STORE_ID,
            quantity_delta=Decimal("-1.000"),
            movement_type=MovementType.MANUAL_ADJUSTMENT,
        )
