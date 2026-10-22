from __future__ import annotations

from collections.abc import Awaitable, Callable
from datetime import UTC, datetime, timedelta
from decimal import Decimal
from uuid import UUID

from sqlalchemy.exc import IntegrityError
from sqlmodel import select
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.config import get_settings
from app.core.events import publish_event
from app.core.exceptions import DomainError
from app.models.customers import Customer
from app.models.pos import (
    DeliveryStatus,
    OrderType,
    PaymentMethod,
    Sale,
    SaleLineItem,
    SaleStatus,
)
from app.schemas.sales import (
    SaleSyncBatchRequest,
    SaleSyncBatchResponse,
    SaleSyncInput,
    SyncResult,
)
from app.schemas.void_refund import VoidRefundRequest
from app.services.courier_service import (
    CourierValidationError,
    validate_courier_for_sale,
)


class SaleServiceError(DomainError):
    """Base for all sale service errors."""


class SaleValidationError(SaleServiceError):
    """A sale's input data fails business-rule validation."""


class InvalidSaleStateError(SaleServiceError):
    """Raised when attempting to void/refund a sale that is not in 'completed' status."""


def detect_time_drift(
    occurred_at: datetime,
    synced_at: datetime | None = None,
) -> bool:
    """Return True if *occurred_at* is suspicious relative to *synced_at*.

    Compares the device-reported timestamp against the server timestamp.
    A timestamp is considered suspicious (potentially clock-drifted) when:

    * It is more than ``time_drift_suspect_threshold_hours`` in the past, or
    * It is more than ``time_drift_future_tolerance_minutes`` in the future.
    """
    settings = get_settings()
    now = synced_at or datetime.now(UTC)

    return occurred_at < now - timedelta(
        hours=settings.time_drift_suspect_threshold_hours
    ) or occurred_at > now + timedelta(minutes=settings.time_drift_future_tolerance_minutes)


async def _validate_customer_belongs_to_business(
    session: AsyncSession,
    business_id: UUID,
    customer_id: UUID,
) -> None:
    """A sale's ``customer_id`` must exist, belong to this business, and not
    be soft-deleted.

    Defined here rather than imported from ``app/services/customer_service.py``
    to avoid a circular import — that module already imports
    ``detect_time_drift`` from this one.
    """
    customer = (
        await session.exec(select(Customer).where(Customer.id == customer_id))
    ).first()
    if customer is None or customer.business_id != business_id:
        raise SaleValidationError("customer_id does not exist for this business")
    if customer.is_deleted:
        raise SaleValidationError("customer_id refers to a deleted customer")


async def sync_sale_batch(
    session: AsyncSession,
    business_id: UUID,
    actor_id: UUID | None,
    batch: SaleSyncBatchRequest,
    publish: Callable[..., Awaitable[None]] = publish_event,
    authorization: str | None = None,
) -> SaleSyncBatchResponse:
    """Process a batch of offline-synced sales.

    Each sale in the batch is processed independently within its own
    database savepoint.  One sale's failure does **not** abort the rest
    of the batch (partial success is a first-class design property).

    Idempotency is enforced by ``client_sale_id`` — sales whose idempotency
    key already exists in the database are reported as ``duplicate``.

    ``authorization`` is the caller's own JWT, forwarded to Identity
    Service to read each store's tax switch (never stored or logged).
    """
    results: list[SyncResult] = []

    async with session.begin():
        for sale_input in batch.sales:
            try:
                existing = await session.exec(
                    select(Sale).where(Sale.client_sale_id == sale_input.client_sale_id)
                )
                if existing.first() is not None:
                    results.append(
                        SyncResult(
                            client_sale_id=sale_input.client_sale_id,
                            status="duplicate",
                        )
                    )
                    continue

                async with session.begin_nested():
                    sale = await _create_sale_internal(
                        session, business_id, actor_id, sale_input,
                        authorization=authorization,
                    )

                await _publish_sale_events(sale, sale_input, publish)

                results.append(
                    SyncResult(
                        client_sale_id=sale_input.client_sale_id,
                        status="created",
                    )
                )
            except SaleValidationError as exc:
                results.append(
                    SyncResult(
                        client_sale_id=sale_input.client_sale_id,
                        status="failed",
                        reason=str(exc),
                    )
                )
            except CourierValidationError as exc:
                results.append(
                    SyncResult(
                        client_sale_id=sale_input.client_sale_id,
                        status="failed",
                        reason=str(exc),
                    )
                )
            except IntegrityError:
                results.append(
                    SyncResult(
                        client_sale_id=sale_input.client_sale_id,
                        status="duplicate",
                    )
                )

    return SaleSyncBatchResponse(results=results)


async def _create_sale_internal(
    session: AsyncSession,
    business_id: UUID,
    actor_id: UUID | None,
    sale_input: SaleSyncInput,
    authorization: str | None = None,
) -> Sale:
    if sale_input.status in ("voided", "refunded") and not sale_input.void_or_refund_reason:
        raise SaleValidationError(
            f"void_or_refund_reason is required when status is {sale_input.status}"
        )

    if sale_input.customer_id is not None:
        await _validate_customer_belongs_to_business(
            session, business_id, sale_input.customer_id,
        )

    # ── Delivery validation (service-level mirror of the Pydantic
    # validators — batch tests may mutate inputs past Pydantic, so the
    # rules are enforced here too, where per-sale failure is first-class).
    order_type = OrderType(sale_input.order_type)
    delivery_fee = sale_input.delivery_fee.quantize(Decimal("0.01"))
    if order_type == OrderType.DELIVERY:
        if not sale_input.delivery_address_line1:
            raise SaleValidationError(
                "delivery_address_line1 is required when order_type is delivery"
            )
        if sale_input.courier_id is not None:
            try:
                await validate_courier_for_sale(
                    session, business_id, sale_input.courier_id,
                )
            except CourierValidationError as exc:
                raise SaleValidationError(str(exc)) from exc
    else:
        if sale_input.courier_id is not None:
            raise SaleValidationError(
                "courier_id is only allowed when order_type is delivery"
            )
        if sale_input.delivery_address_line1 is not None:
            raise SaleValidationError(
                "delivery_address_line1 is only allowed when order_type is delivery"
            )
        if sale_input.delivery_recipient_phone is not None:
            raise SaleValidationError(
                "delivery_recipient_phone is only allowed when order_type is delivery"
            )
        if sale_input.delivery_note is not None:
            raise SaleValidationError(
                "delivery_note is only allowed when order_type is delivery"
            )
        if delivery_fee != Decimal("0.00"):
            raise SaleValidationError(
                "delivery_fee is only allowed when order_type is delivery"
            )

    subtotal = sum(
        li.quantity * li.unit_price for li in sale_input.line_items
    )
    # Per-store tax switch (default off): on = subtotal * rate, off = 0.
    # Never blocks the sale — lookup failures degrade to no tax.
    from app.services.tax_policy import get_store_tax

    _, tax_rate = await get_store_tax(
        business_id, sale_input.store_id, authorization
    )
    tax_amount = subtotal * tax_rate
    total = subtotal - sale_input.discount_amount + tax_amount + delivery_fee

    subtotal = subtotal.quantize(Decimal("0.01"))
    tax_amount = tax_amount.quantize(Decimal("0.01"))
    total = total.quantize(Decimal("0.01"))

    now = datetime.now(UTC)
    is_time_suspect = detect_time_drift(sale_input.occurred_at, now)
    status = SaleStatus(sale_input.status)

    sale = Sale(
        business_id=business_id,
        store_id=sale_input.store_id,
        client_sale_id=sale_input.client_sale_id,
        status=status,
        subtotal=subtotal,
        discount_amount=sale_input.discount_amount.quantize(Decimal("0.01")),
        tax_amount=tax_amount,
        delivery_fee=delivery_fee,
        total=total,
        payment_method=PaymentMethod(sale_input.payment_method),
        actor_id=actor_id,
        customer_id=sale_input.customer_id,
        occurred_at=sale_input.occurred_at,
        device_sequence=sale_input.device_sequence,
        is_time_suspect=is_time_suspect,
        order_type=order_type,
        courier_id=sale_input.courier_id,
        delivery_address_line1=sale_input.delivery_address_line1,
        delivery_recipient_phone=sale_input.delivery_recipient_phone,
        delivery_note=sale_input.delivery_note,
        delivery_status=(
            DeliveryStatus.PENDING if order_type == OrderType.DELIVERY else None
        ),
    )

    if status == SaleStatus.VOIDED:
        sale.voided_at = sale_input.occurred_at
        sale.void_or_refund_reason = sale_input.void_or_refund_reason
    elif status == SaleStatus.REFUNDED:
        sale.refunded_at = sale_input.occurred_at
        sale.void_or_refund_reason = sale_input.void_or_refund_reason

    session.add(sale)
    await session.flush()

    for li_input in sale_input.line_items:
        line_total = li_input.quantity * li_input.unit_price - li_input.discount_amount
        line_total = line_total.quantize(Decimal("0.01"))
        line_item = SaleLineItem(
            sale_id=sale.id,
            item_id=li_input.item_id,
            quantity=li_input.quantity,
            unit_price=li_input.unit_price.quantize(Decimal("0.01")),
            discount_amount=li_input.discount_amount.quantize(Decimal("0.01")),
            line_total=line_total,
            unit_cost=(
                li_input.unit_cost.quantize(Decimal("0.0001"))
                if li_input.unit_cost is not None
                else None
            ),
        )
        session.add(line_item)

    await session.flush()
    return sale


async def _publish_sale_events(
    sale: Sale,
    sale_input: SaleSyncInput,
    publish: Callable[..., Awaitable[None]],
) -> None:
    if sale.status == SaleStatus.COMPLETED:
        await publish(
            "sale.completed",
            {
                "event_id": str(sale.id),
                "business_id": str(sale.business_id),
                "store_id": str(sale.store_id),
                "sale_id": str(sale.id),
                "order_type": sale.order_type.value,
                "courier_id": str(sale.courier_id) if sale.courier_id else None,
                "delivery_status": (
                    sale.delivery_status.value if sale.delivery_status else None
                ),
                "delivery_fee": str(sale.delivery_fee),
                "line_items": [
                    {"item_id": str(li.item_id), "quantity": str(li.quantity)}
                    for li in sale_input.line_items
                ],
            },
        )


# ── Delivery-status transitions ──────────────────────────────────────

_DELIVERY_TRANSITIONS: dict[DeliveryStatus | None, set[DeliveryStatus]] = {
    None: set(),
    DeliveryStatus.PENDING: {DeliveryStatus.ASSIGNED, DeliveryStatus.FAILED},
    DeliveryStatus.ASSIGNED: {
        DeliveryStatus.OUT_FOR_DELIVERY,
        DeliveryStatus.FAILED,
    },
    DeliveryStatus.OUT_FOR_DELIVERY: {
        DeliveryStatus.DELIVERED,
        DeliveryStatus.FAILED,
    },
    DeliveryStatus.DELIVERED: set(),
    DeliveryStatus.FAILED: set(),
}


async def update_delivery_status(
    session: AsyncSession,
    business_id: UUID,
    sale_id: UUID,
    actor_id: UUID | None,
    new_status: DeliveryStatus,
    courier_id: UUID | None = None,
    publish: Callable[..., Awaitable[None]] = publish_event,
) -> Sale:
    """Advance a delivery sale's fulfilment state.

    Guards: sale must exist for the business, be a delivery sale
    (``order_type == delivery``), and follow the linear transition map —
    terminal states (delivered/failed) reject further moves. An optional
    ``courier_id`` reassigns the courier (validated active + same
    business); moving to ``assigned`` without any courier (existing or
    supplied) is rejected.
    """
    sale = (
        await session.exec(
            select(Sale).where(Sale.id == sale_id, Sale.business_id == business_id)
        )
    ).first()
    if sale is None:
        raise SaleValidationError(
            f"Sale {sale_id} not found for business {business_id}"
        )
    if sale.order_type != OrderType.DELIVERY:
        raise SaleValidationError(
            f"Sale {sale_id} is not a delivery sale "
            f"(order_type is '{sale.order_type.value}')"
        )

    allowed = _DELIVERY_TRANSITIONS.get(sale.delivery_status, set())
    if new_status not in allowed:
        current = sale.delivery_status.value if sale.delivery_status else "none"
        raise SaleValidationError(
            f"Cannot move delivery status from '{current}' to '{new_status.value}'"
        )

    if courier_id is not None:
        try:
            await validate_courier_for_sale(session, business_id, courier_id)
        except CourierValidationError as exc:
            raise SaleValidationError(str(exc)) from exc
        sale.courier_id = courier_id

    if new_status == DeliveryStatus.ASSIGNED and sale.courier_id is None:
        raise SaleValidationError(
            "A courier must be assigned before moving to 'assigned'"
        )

    sale.delivery_status = new_status
    session.add(sale)
    await session.flush()

    await publish(
        "delivery.status_changed",
        {
            "event_id": f"delivery:{sale.id}:{new_status.value}",
            "business_id": str(sale.business_id),
            "store_id": str(sale.store_id),
            "sale_id": str(sale.id),
            "courier_id": str(sale.courier_id) if sale.courier_id else None,
            "delivery_status": new_status.value,
            "actor_id": str(actor_id) if actor_id else None,
        },
    )

    await session.commit()
    return sale


async def void_or_refund_sale(
    session: AsyncSession,
    business_id: UUID,
    sale_id: UUID,
    actor_id: UUID | None,
    request: VoidRefundRequest,
    publish: Callable[..., Awaitable[None]] = publish_event,
) -> Sale:
    """Void or refund an already-synced completed sale.

    Publishes ``sale.voided`` / ``sale.refunded`` (for Inventory Service
    stock reversal — **not yet consumed**, see KNOWN_GAP) and
    ``audit.recorded`` (financially significant correction).

    Idempotent via ``client_action_id`` — repeated calls with the same
    action ID load and return the existing sale without side effects.
    """
    # -- Idempotency: client_action_id already processed? ---------------
    existing = (
        await session.exec(
            select(Sale).where(
                (Sale.void_client_action_id == request.client_action_id)
                | (Sale.refund_client_action_id == request.client_action_id)
            )
        )
    ).first()
    if existing is not None:
        return existing

    # -- Load & guard ---------------------------------------------------
    sale = (
        await session.exec(
            select(Sale).where(Sale.id == sale_id, Sale.business_id == business_id)
        )
    ).first()
    if sale is None:
        raise SaleValidationError(
            f"Sale {sale_id} not found for business {business_id}"
        )
    if sale.status != SaleStatus.COMPLETED:
        raise InvalidSaleStateError(
            f"Cannot {request.new_status} sale {sale_id}: "
            f"current status is '{sale.status.value}', expected 'completed'"
        )

    line_items = (
        await session.exec(
            select(SaleLineItem).where(SaleLineItem.sale_id == sale_id)
        )
    ).all()

    # -- Apply transition -----------------------------------------------
    now = datetime.now(UTC)
    new_status = SaleStatus(request.new_status)

    if new_status == SaleStatus.VOIDED:
        sale.status = SaleStatus.VOIDED
        sale.voided_at = now
        sale.void_client_action_id = request.client_action_id
    else:
        sale.status = SaleStatus.REFUNDED
        sale.refunded_at = now
        sale.refund_client_action_id = request.client_action_id

    sale.void_or_refund_reason = request.reason
    session.add(sale)
    await session.flush()

    # -- Publish reversal event -----------------------------------------
    event_name = f"sale.{request.new_status}"
    event_payload = {
        "event_id": request.client_action_id,
        "business_id": str(sale.business_id),
        "store_id": str(sale.store_id),
        "sale_id": str(sale.id),
            "line_items": [
                {
                    "item_id": str(li.item_id),
                    "quantity": str(li.quantity.normalize()),
                }
                for li in line_items
            ],
    }
    await publish(event_name, event_payload)

    # -- Publish audit event --------------------------------------------
    await publish(
        "audit.recorded",
        {
            "event_id": f"audit:{request.client_action_id}",
            "business_id": str(sale.business_id),
            "action": event_name,
            "sale_id": str(sale.id),
            "actor_id": str(actor_id) if actor_id else None,
            "reason": request.reason,
        },
    )

    await session.commit()
    return sale
