"""Transactional stock movement engine — the core of the Inventory Service.

This is the only function in the entire service that writes to
``stock_movements`` or ``stock_levels``.  Every mutation endpoint (Stage 6),
event consumer (Stage 7), and future batch operation must go through this
function to guarantee consistency, locking correctness, and event emission.

═══════════════════════════════════════════════════════════════════════════
CONCURRENCY GUARANTEES
═══════════════════════════════════════════════════════════════════════════

All writes happen in a single database transaction.  Row-level locks
(``SELECT ... FOR UPDATE``) are acquired on the **item** row first, then
on the **stock_levels** row, preventing lost updates when two cashiers
ring up the same item simultaneously.

═══════════════════════════════════════════════════════════════════════════
EXCEPTIONS (raised, never caught silently)
═══════════════════════════════════════════════════════════════════════════

* ``ItemTypeMismatchError`` — movement type is incompatible with item's
  ``item_type`` (e.g. ``sale`` on ``raw_material``).
* ``InsufficientStockError`` — movement would make quantity negative and
  ``allow_negative_stock`` is ``False``.

These are two **distinct checks** with separate exception types — they
must never be conflated into a single validation gate.
"""

from __future__ import annotations

from decimal import Decimal
from typing import Any
from uuid import UUID

import structlog
from sqlmodel import select
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.events import publish_event
from app.models.inventory import (
    ActorType,
    Item,
    ItemType,
    MovementType,
    ProcessedEvent,
    StockLevel,
    StockMovement,
)

logger = structlog.get_logger(__name__)

# ═══════════════════════════════════════════════════════════════════════
# Domain exceptions
# ═══════════════════════════════════════════════════════════════════════


class ItemTypeMismatchError(ValueError):
    """Raised when a movement type is incompatible with the item's item_type.

    For example, a ``sale`` movement on a ``raw_material`` item, or a
    ``purchase_received`` movement on a ``sellable`` item.
    """


class InsufficientStockError(ValueError):
    """Raised when a movement would drive quantity negative on an item
    that does not allow negative stock."""


# ═══════════════════════════════════════════════════════════════════════
# Helpers
# ═══════════════════════════════════════════════════════════════════════


_MOVEMENTS_ALLOWED_FOR_ANY: frozenset[MovementType] = frozenset(
    {
        MovementType.WASTE,
        MovementType.MANUAL_ADJUSTMENT,
        MovementType.TRANSFER_IN,
        MovementType.TRANSFER_OUT,
        MovementType.SALE_REVERSAL,
        MovementType.REFUND_REVERSAL,
        # Production legs are transformations/corrections, not sales or
        # purchases — a production_input on a `both` ingredient or a
        # production_output on a `both` sellable must not trip the
        # sale/purchase item_type rules (Stage 2).
        MovementType.PRODUCTION_INPUT,
        MovementType.PRODUCTION_OUTPUT,
        MovementType.PRODUCTION_REVERSAL,
    }
)

_COMPATIBILITY_RULES: dict[ItemType, frozenset[MovementType]] = {
    ItemType.SELLABLE: frozenset(
        {
            MovementType.SALE,
            MovementType.WASTE,
            MovementType.MANUAL_ADJUSTMENT,
            MovementType.TRANSFER_IN,
            MovementType.TRANSFER_OUT,
            MovementType.SALE_REVERSAL,
            MovementType.REFUND_REVERSAL,
            MovementType.PRODUCTION_INPUT,
            MovementType.PRODUCTION_OUTPUT,
            MovementType.PRODUCTION_REVERSAL,
        }
    ),
    ItemType.RAW_MATERIAL: frozenset(
        {
            MovementType.PURCHASE_RECEIVED,
            MovementType.WASTE,
            MovementType.MANUAL_ADJUSTMENT,
            MovementType.TRANSFER_IN,
            MovementType.TRANSFER_OUT,
            MovementType.SALE_REVERSAL,
            MovementType.REFUND_REVERSAL,
            MovementType.PRODUCTION_INPUT,
            MovementType.PRODUCTION_OUTPUT,
            MovementType.PRODUCTION_REVERSAL,
        }
    ),
    ItemType.BOTH: frozenset(
        {
            MovementType.SALE,
            MovementType.PURCHASE_RECEIVED,
            MovementType.WASTE,
            MovementType.MANUAL_ADJUSTMENT,
            MovementType.TRANSFER_IN,
            MovementType.TRANSFER_OUT,
            MovementType.SALE_REVERSAL,
            MovementType.REFUND_REVERSAL,
            MovementType.PRODUCTION_INPUT,
            MovementType.PRODUCTION_OUTPUT,
            MovementType.PRODUCTION_REVERSAL,
        }
    ),
}

_ITEM_TYPE_ERROR_MESSAGES: dict[MovementType, dict[ItemType, str]] = {
    MovementType.SALE: {
        ItemType.RAW_MATERIAL: (
            "raw_material items cannot be decremented via a sale movement "
            "— did you mean manual_adjustment or waste?"
        ),
    },
    MovementType.PURCHASE_RECEIVED: {
        ItemType.SELLABLE: (
            "sellable items cannot be incremented via a purchase_received movement "
            "— did you mean manual_adjustment?"
        ),
    },
}


def _validate_item_type(item_type: ItemType, movement_type: MovementType) -> None:
    allowed = _COMPATIBILITY_RULES.get(item_type)
    if allowed is None:
        return
    if movement_type in allowed:
        return
    msg_map = _ITEM_TYPE_ERROR_MESSAGES.get(movement_type, {})
    message = msg_map.get(
        item_type,
        f"Movement type '{movement_type.value}' is not allowed for "
        f"item_type '{item_type.value}'",
    )
    raise ItemTypeMismatchError(message)


def _should_publish_low_stock(
    old_quantity: Decimal,
    new_quantity: Decimal,
    reorder_threshold: Decimal,
) -> bool:
    """Return True only if the quantity just crossed from >=threshold to <threshold."""
    return old_quantity >= reorder_threshold and new_quantity < reorder_threshold


# ═══════════════════════════════════════════════════════════════════════
# Core function
# ═══════════════════════════════════════════════════════════════════════


async def record_movement(
    db: AsyncSession,
    item_id: UUID,
    business_id: UUID,
    store_id: UUID,
    quantity_delta: Decimal,
    movement_type: MovementType,
    reference_type: str | None = None,
    reference_id: UUID | None = None,
    actor_type: str = "user",
    actor_id: UUID | None = None,
    reason: str | None = None,
    event_id: str | None = None,
    commit: bool = True,
    skip_negative_check: bool = False,
    unit_cost: Decimal | None = None,
) -> StockMovement:
    """Record a stock movement atomically.

    This is the single write-path for all stock changes in the service.
    Every parameter is explicit — no inferred values.

    Parameters
    ----------
    db : AsyncSession
        The database session.  Caller manages the transaction lifecycle.
    item_id : UUID
    business_id : UUID
        Explicitly required — callers always have this from the URL path or
        event payload.  Not inferred from the item row to avoid an extra query.
    store_id : UUID
    quantity_delta : Decimal
        Positive for increases, negative for decreases.
    movement_type : MovementType
    reference_type : str | None
        Domain name of the external reference (e.g. ``"order"``, ``"procurement"``).
    reference_id : UUID | None
        ID of the external reference row.
    actor_type : str
        One of ``"user"``, ``"system"``, ``"service"``.  Defaults to ``"user"``.
    actor_id : UUID | None
        ID of the specific actor (user ID, system process ID, etc.).
    reason : str | None
        Human-readable justification for the movement.
    event_id : str | None
        If provided, enables idempotent processing.  The function checks for
        an existing ``ProcessedEvent`` row first and short-circuits without
        acquiring any locks if the event was already processed.
    commit : bool
        When ``True`` (default), commits the transaction, refreshes the
        movement, and publishes post-commit events.  Set to ``False`` when
        batching multiple moves in a single transaction (e.g. a transfer
        that needs both a TRANSFER_OUT and TRANSFER_IN committed together).
        When ``False`` the caller must call ``db.commit()``, refresh, and
        publish events manually.
    skip_negative_check : bool
        When ``True``, bypasses the ``InsufficientStockError`` check entirely.
        Used by event handlers for sale/order events where the physical sale
        has already happened and must be recorded even if it drives inventory
        negative.  Defaults to ``False`` so all other callers (Stage 6
        endpoints) are completely unaffected.
    unit_cost : Decimal | None
        Explicit per-unit cost to freeze on the movement row (purchase legs
        pass the receipt's actual ``unit_cost``). When ``None`` the item's
        current ``unit_cost`` is snapshotted at write time; stays ``None``
        only when the item has no basis on file.

    Returns
    -------
    StockMovement
        The newly created movement row.

    Raises
    ------
    ItemTypeMismatchError
        If the movement type is incompatible with the item's ``item_type``.
    InsufficientStockError
        If ``skip_negative_check`` is ``False`` and the movement would make
        quantity negative while the item does not allow negative stock.
    """
    # ── Step 0: Idempotency check (before any locks) ────────────────
    if event_id is not None:
        existing_event = await db.get(ProcessedEvent, event_id)
        if existing_event is not None:
            logger.info(
                "movement.idempotent_skip",
                event_id=event_id,
                item_id=str(item_id),
                movement_type=movement_type.value,
            )
            # Return the most recent movement for this item/store as a
            # convenience so callers don't have to handle a None return
            result = await db.exec(
                select(StockMovement)
                .where(
                    StockMovement.item_id == item_id,
                    StockMovement.store_id == store_id,
                )
                .order_by(StockMovement.created_at.desc())
                .limit(1)
            )
            return result.first()

    # ── Step 1: Lock the item row ───────────────────────────────────
    result = await db.exec(
        select(Item).where(Item.id == item_id).with_for_update()
    )
    item = result.one_or_none()
    if item is None:
        raise ValueError(f"Item with id '{item_id}' not found")

    # ── Step 2: Item type / movement type compatibility check ────────
    _validate_item_type(item.item_type, movement_type)

    # ── Step 3: Lock the stock_levels row ────────────────────────────
    result = await db.exec(
        select(StockLevel)
        .where(
            StockLevel.item_id == item_id,
            StockLevel.store_id == store_id,
        )
        .with_for_update()
    )
    stock_level = result.one_or_none()

    if stock_level is None:
        stock_level = StockLevel(
            item_id=item_id,
            store_id=store_id,
            current_quantity=Decimal("0.000"),
        )
        db.add(stock_level)

    old_quantity = stock_level.current_quantity
    new_quantity = old_quantity + quantity_delta

    # ── Step 4: Negative stock check ────────────────────────────────
    if not skip_negative_check and new_quantity < Decimal("0.000") and not item.allow_negative_stock:
        raise InsufficientStockError(
            f"Insufficient stock for item '{item_id}' at store "
            f"'{store_id}': current={old_quantity}, "
            f"requested_delta={quantity_delta}, new_quantity={new_quantity} would be negative "
            f"and item does not allow negative stock"
        )

    # ── Step 5: Update stock_levels (within the locked row) ──────────
    stock_level.current_quantity = new_quantity
    db.add(stock_level)

    # ── Step 6: Insert stock_movements row ──────────────────────────
    actor_enum = ActorType(actor_type)
    # Freeze the per-unit cost basis at event time so later deliveries that
    # revalue Item.unit_cost cannot rewrite this row's history. An explicit
    # receipt cost (purchase legs) wins; otherwise snapshot the item's
    # current basis (waste/adjust/transfer/production legs). Stays null only
    # when the item itself has no basis on file.
    frozen_cost = unit_cost if unit_cost is not None else item.unit_cost
    movement = StockMovement(
        item_id=item_id,
        business_id=business_id,
        store_id=store_id,
        quantity_delta=quantity_delta,
        movement_type=movement_type,
        reference_type=reference_type,
        reference_id=reference_id,
        actor_type=actor_enum,
        actor_id=actor_id,
        reason=reason,
        unit_cost=frozen_cost,
    )
    db.add(movement)

    # ── Step 7: Record processed event (same transaction) ────────────
    if event_id is not None:
        processed = ProcessedEvent(event_id=event_id)
        db.add(processed)

    # ── Commit (or defer to caller) ─────────────────────────────────
    if commit:
        await db.commit()
        await db.refresh(movement)

        # ── Step 8: Publish post-commit events ─────────────────────────
        payload: dict[str, Any] = {
            "item_id": str(item_id),
            "business_id": str(business_id),
            "store_id": str(store_id),
            "movement_type": movement_type.value,
            "quantity_delta": str(quantity_delta),
            "new_quantity": str(new_quantity),
        }

        # Always publish stock.adjusted
        await publish_event("stock.adjusted", payload)

        # stock.low — only on first crossing below threshold
        if _should_publish_low_stock(old_quantity, new_quantity, item.reorder_threshold):
            low_payload = {
                "item_id": str(item_id),
                "business_id": str(business_id),
                "store_id": str(store_id),
                "current_quantity": str(new_quantity),
                "reorder_threshold": str(item.reorder_threshold),
            }
            await publish_event("stock.low", low_payload)

        # audit.recorded — only for manual_adjustment and waste
        if movement_type in (MovementType.MANUAL_ADJUSTMENT, MovementType.WASTE):
            audit_payload = {
                "actor_id": str(actor_id) if actor_id else None,
                "business_id": str(business_id),
                "action": f"stock.{movement_type.value}",
                "resource_type": "item",
                "resource_id": str(item_id),
                "details": {
                    "reason": reason,
                    "quantity_delta": str(quantity_delta),
                },
            }
            await publish_event("audit.recorded", audit_payload)

        logger.info(
            "movement.recorded",
            movement_id=str(movement.id),
            item_id=str(item_id),
            business_id=str(business_id),
            movement_type=movement_type.value,
            quantity_delta=str(quantity_delta),
            new_quantity=str(new_quantity),
        )

    return movement