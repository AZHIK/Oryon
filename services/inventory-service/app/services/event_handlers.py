"""Event handlers for inbound messages from POS, Food Delivery, and Procurement Service.

Handlers in this module:
* ``handle_sale_completed``      — POS Service ``sale.completed``      (decrement stock)
* ``handle_sale_voided``         — POS Service ``sale.voided``         (reverse decrement)
* ``handle_sale_refunded``       — POS Service ``sale.refunded``       (reverse decrement)
* ``handle_order_confirmed``     — Food Delivery ``order.confirmed``   (decrement stock)
* ``handle_purchase_received``   — Procurement ``purchase.received``   (increment stock)

The void/refund handlers use distinct ``MovementType`` values
(``sale_reversal`` / ``refund_reversal``) so stock-movement reports
can distinguish voided-sale reversals from refunded-sale reversals.

Each handler is a directly-callable async function that processes one
event payload and returns ``list[StockMovement]``.  They are designed to
be wired to a real RabbitMQ consumer later — the handler itself contains
no broker-specific logic.

═══════════════════════════════════════════════════════════════════════════
IDEMPOTENCY KEY SCHEME (multi-line-item events)
═══════════════════════════════════════════════════════════════════════════

Each event carries a single ``event_id`` used for deduplication at the
**event level**.  Since a single event may contain multiple line items
(e.g. a sale with 3 items), each line item gets its own derived key:

    key = f"{event_id}:{item_id}"

This derived key is passed as ``event_id`` to ``record_movement``, which
persists a ``ProcessedEvent`` row per line item.  This means:

* If a partial failure occurs (item A succeeds, item B fails), a retry
  with the same top-level ``event_id`` will skip item A (its
  ``ProcessedEvent`` row already exists) and only apply item B.
* If every line item was fully processed on the first attempt, all
  derived keys exist and the retry is a no-op for every item.
* The ``ProcessedEvent`` table acts as a simple existence-check
  (PRIMARY KEY lookup) with no locks needed in the idempotent path.

Callers (future message consumers) should use this scheme when deciding
whether to acknowledge or re-queue an event after a partial failure.
"""

from __future__ import annotations

from decimal import Decimal
from typing import Any
from uuid import UUID

from sqlmodel.ext.asyncio.session import AsyncSession

from app.models.inventory import ActorType, MovementType
from app.services.stock_movement_service import record_movement

# ═══════════════════════════════════════════════════════════════════════
# Handler for POS Service: sale.completed
# ═══════════════════════════════════════════════════════════════════════


async def handle_sale_completed(
    db: AsyncSession,
    event_payload: dict[str, Any],
) -> list[Any]:
    """Process a ``sale.completed`` event from POS Service.

    Expected payload shape::

        {
            "event_id": str,           # unique event identifier
            "business_id": str|UUID,
            "store_id": str|UUID,
            "sale_id": str|UUID,
            "line_items": [
                {"item_id": str|UUID, "quantity": Decimal|float},
                ...
            ],
        }

    For each line item, calls ``record_movement`` with
    ``skip_negative_check=True`` — the sale has already happened in the
    real world and must be recorded even if it drives inventory negative.
    The ``item_type`` compatibility check (sale on raw_material) is still
    enforced and will raise ``ItemTypeMismatchError``.

    Returns a list of ``StockMovement`` instances (one per line item).
    """
    return await _process_line_items(
        db=db,
        event_payload=event_payload,
        reference_type="sale",
        reference_id_key="sale_id",
        movement_type=MovementType.SALE,
        sign=-1,
        skip_negative_check=True,
    )


# ═══════════════════════════════════════════════════════════════════════
# Handler for Food Delivery Service: order.confirmed
# ═══════════════════════════════════════════════════════════════════════


async def handle_order_confirmed(
    db: AsyncSession,
    event_payload: dict[str, Any],
) -> list[Any]:
    """Process an ``order.confirmed`` event from Food Delivery Service.

    Expected payload shape::

        {
            "event_id": str,
            "business_id": str|UUID,
            "store_id": str|UUID,
            "order_id": str|UUID,
            "line_items": [
                {"item_id": str|UUID, "quantity": Decimal|float},
                ...
            ],
        }

    Identical in logic to ``handle_sale_completed``, except
    ``reference_type`` is ``"order"`` and the reference ID comes from
    ``order_id``.  Same ``skip_negative_check=True`` reasoning applies.
    """
    return await _process_line_items(
        db=db,
        event_payload=event_payload,
        reference_type="order",
        reference_id_key="order_id",
        movement_type=MovementType.SALE,
        sign=-1,
        skip_negative_check=True,
    )


# ═══════════════════════════════════════════════════════════════════════
# Handler for Procurement Service: purchase.received
# ═══════════════════════════════════════════════════════════════════════


# ═══════════════════════════════════════════════════════════════════════
# Handler for POS Service: sale.voided
# ═══════════════════════════════════════════════════════════════════════


async def handle_sale_voided(
    db: AsyncSession,
    event_payload: dict[str, Any],
) -> list[Any]:
    """Process a ``sale.voided`` event from POS Service.

    Expected payload shape (identical to ``sale.completed``)::

        {
            "event_id": str,
            "business_id": str|UUID,
            "store_id": str|UUID,
            "sale_id": str|UUID,
            "line_items": [
                {"item_id": str|UUID, "quantity": Decimal|float},
                ...
            ],
        }

    For each line item, calls ``record_movement`` with
    ``movement_type=MovementType.SALE_REVERSAL`` and a **positive**
    ``quantity_delta`` (reversing the original decrement).  ``skip_negative_check``
    is not needed here — a reversal always increases stock.

    ``sale_reversal`` is exempt from the ``item_type`` compatibility check
    (same as ``waste`` / ``manual_adjustment`` / ``transfer_in`` /
    ``transfer_out``), because a voided sale may affect raw_material-only or
    sellable-only items without being a configuration error — it is a
    correction, not a new sale transaction.

    Returns a list of ``StockMovement`` instances (one per line item).
    """
    return await _process_line_items(
        db=db,
        event_payload=event_payload,
        reference_type="sale",
        reference_id_key="sale_id",
        movement_type=MovementType.SALE_REVERSAL,
        sign=1,
        skip_negative_check=False,
    )


# ═══════════════════════════════════════════════════════════════════════
# Handler for POS Service: sale.refunded
# ═══════════════════════════════════════════════════════════════════════


async def handle_sale_refunded(
    db: AsyncSession,
    event_payload: dict[str, Any],
) -> list[Any]:
    """Process a ``sale.refunded`` event from POS Service.

    Identical to ``handle_sale_voided`` except ``movement_type`` is
    ``MovementType.REFUND_REVERSAL``, keeping voided vs refunded stock
    movements distinguishable in audit reports even though their effect
    on stock is identical (both increment quantity).

    Returns a list of ``StockMovement`` instances (one per line item).
    """
    return await _process_line_items(
        db=db,
        event_payload=event_payload,
        reference_type="sale",
        reference_id_key="sale_id",
        movement_type=MovementType.REFUND_REVERSAL,
        sign=1,
        skip_negative_check=False,
    )


async def handle_purchase_received(
    db: AsyncSession,
    event_payload: dict[str, Any],
) -> list[Any]:
    """Process a ``purchase.received`` event from Procurement Service.

    Expected payload shape::

        {
            "event_id": str,
            "business_id": str|UUID,
            "store_id": str|UUID,
            "purchase_order_id": str|UUID,
            "line_items": [
                {"item_id": str|UUID, "quantity": Decimal|float},
                ...
            ],
        }

    For each line item, calls ``record_movement`` with
    ``skip_negative_check=False`` (increasing stock never goes negative,
    but the parameter is explicit for clarity).  The ``item_type`` check
    (purchase_received on sellable-only) IS enforced — this is a real
    configuration error that must not be silently suppressed.
    """
    return await _process_line_items(
        db=db,
        event_payload=event_payload,
        reference_type="purchase_order",
        reference_id_key="purchase_order_id",
        movement_type=MovementType.PURCHASE_RECEIVED,
        sign=1,
        skip_negative_check=False,
    )


# ═══════════════════════════════════════════════════════════════════════
# Shared logic
# ═══════════════════════════════════════════════════════════════════════


async def _process_line_items(
    db: AsyncSession,
    event_payload: dict[str, Any],
    reference_type: str,
    reference_id_key: str,
    movement_type: MovementType,
    sign: int,
    skip_negative_check: bool,
) -> list[Any]:
    """Iterate over ``event_payload["line_items"]`` and call
    ``record_movement`` for each, using a per-line-item idempotency key
    ``f"{event_id}:{item_id}"``.
    """
    event_id: str = event_payload["event_id"]
    business_id = UUID(str(event_payload["business_id"]))
    store_id = UUID(str(event_payload["store_id"]))
    reference_id = UUID(str(event_payload[reference_id_key]))
    line_items: list[dict[str, Any]] = event_payload["line_items"]

    movements: list[Any] = []

    for item in line_items:
        item_id = UUID(str(item["item_id"]))
        quantity = Decimal(str(item["quantity"]))
        line_event_id = f"{event_id}:{item_id}"

        movement = await record_movement(
            db=db,
            item_id=item_id,
            business_id=business_id,
            store_id=store_id,
            quantity_delta=Decimal(sign) * quantity,
            movement_type=movement_type,
            reference_type=reference_type,
            reference_id=reference_id,
            actor_type=ActorType.SERVICE.value,
            reason=f"{reference_type} {reference_id}",
            event_id=line_event_id,
            skip_negative_check=skip_negative_check,
        )
        movements.append(movement)

    return movements
