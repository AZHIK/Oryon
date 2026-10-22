"""POS domain models — sales, line items, and related enums.

═══════════════════════════════════════════════════════════════════════════
CROSS-SERVICE REFERENCE CONVENTION
═══════════════════════════════════════════════════════════════════════════

Columns named ``business_id``, ``store_id``, ``actor_id``, and
``item_id`` store UUIDs that reference rows in other services' databases.
These are stored as **plain indexed UUID columns with no foreign key
constraint** because the referenced tables live in separate databases.

This is the correct pattern in a microservices architecture — foreign keys
cannot span database boundaries.  Referential integrity is enforced at the
application layer (every request is scoped by an authenticated JWT that
already ties the caller to a specific business context).

Do NOT add FK constraints to these columns.

``customer_id`` on ``Sale`` is the one exception: ``customers`` (see
``app/models/customers.py``) lives in this SAME database, so it IS a real
foreign key, the same way ``SaleLineItem.sale_id`` is.

═══════════════════════════════════════════════════════════════════════════
PROCESSED_SYNC_EVENTS — NOT CREATED (explanation)
═══════════════════════════════════════════════════════════════════════════

Inventory Service has a ``processed_events`` table for idempotency because
it processes multiple line-item-level events per ``sale.completed`` event.
POS Service's ``sales.client_sale_id`` carries its own UNIQUE constraint,
which already provides idempotency for the sale aggregate root — a second
insert with the same ``client_sale_id`` is rejected at the database level.
A separate ``processed_sync_events`` table would be redundant.

═══════════════════════════════════════════════════════════════════════════
SALE STATE MACHINE
═══════════════════════════════════════════════════════════════════════════

A sale arrives from the client in one of three terminal or near-terminal
states: ``completed``, ``voided``, or ``refunded``.  There is no
server-side "open/in-progress" state — the sale is always presented in its
final server-persisted form per the offline-first design decision.
"""

from __future__ import annotations

from datetime import UTC, datetime
from decimal import Decimal
from enum import Enum as PyEnum
from uuid import UUID, uuid4

from sqlalchemy import DateTime, Numeric, func
from sqlalchemy import Enum as SAEnum
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlmodel import Column, Field, ForeignKey, SQLModel

# ═══════════════════════════════════════════════════════════════════════
# Enums
# ═══════════════════════════════════════════════════════════════════════


class SaleStatus(str, PyEnum):
    """Lifecycle state of a sale — terminal states only, no in-progress.

    ``completed`` — a normal, fully-processed sale.
    ``voided`` — cancelled before fulfilment (e.g. cashier error).
    ``refunded`` — reversed after fulfilment (e.g. customer return).
    """

    COMPLETED = "completed"
    VOIDED = "voided"
    REFUNDED = "refunded"


class PaymentMethod(str, PyEnum):
    """Accepted payment method categories for MVP.

    The ``other`` catch-all avoids schema changes per new payment
    integration during early-stage iteration.
    """

    CASH = "cash"
    MOBILE_MONEY = "mobile_money"
    CARD = "card"
    OTHER = "other"


class OrderType(str, PyEnum):
    """How the order leaves the counter.

    ``dine_in`` — seated service. ``takeaway`` — counter pickup.
    ``delivery`` — courier fulfilment; requires a delivery address and
    participates in the minimal ``DeliveryStatus`` lifecycle.
    """

    DINE_IN = "dine_in"
    TAKEAWAY = "takeaway"
    DELIVERY = "delivery"


class DeliveryStatus(str, PyEnum):
    """Minimal delivery lifecycle for a delivery sale.

    ``NULL`` on the row means "not a delivery" (non-delivery sales never
    carry a status). Delivery sales start at ``pending`` and advance via
    ``PATCH .../delivery-status``: pending → assigned → out_for_delivery
    → delivered (or failed from any non-terminal step).
    """

    PENDING = "pending"
    ASSIGNED = "assigned"
    OUT_FOR_DELIVERY = "out_for_delivery"
    DELIVERED = "delivered"
    FAILED = "failed"


# ═══════════════════════════════════════════════════════════════════════
# Tables
# ═══════════════════════════════════════════════════════════════════════


class Sale(SQLModel, table=True):
    """Root aggregate for a POS transaction.

    A sale is submitted by an offline-first device in its final state
    (completed, voided, or refunded).  ``client_sale_id`` is the
    idempotency key — the UNIQUE constraint prevents duplicate ingestion.

    ``occurred_at`` is device-reported and may be inaccurate (handled via
    ``is_time_suspect`` and drift-detection logic in a later stage).
    ``synced_at`` is server-set on insert and always trustworthy.

    Monetary fields (subtotal, discount_amount, tax_amount, total) use
    ``Numeric(12, 2)`` — never float, matching Inventory Service's
    precision standard.
    """

    __tablename__ = "sales"

    id: UUID = Field(
        default_factory=uuid4,
        primary_key=True,
        nullable=False,
        sa_type=PG_UUID,
    )
    business_id: UUID = Field(
        nullable=False,
        index=True,
        sa_type=PG_UUID,
    )
    store_id: UUID = Field(
        nullable=False,
        index=True,
        sa_type=PG_UUID,
    )
    client_sale_id: str = Field(
        nullable=False,
        max_length=255,
        unique=True,
    )
    status: SaleStatus = Field(
        sa_column=Column(
            SAEnum(
                SaleStatus,
                name="salestatus",
                values_callable=lambda x: [e.value for e in x],
            ),
            nullable=False,
        ),
    )
    subtotal: Decimal = Field(
        nullable=False,
        sa_type=Numeric(precision=12, scale=2),
    )
    discount_amount: Decimal = Field(
        default=Decimal("0"),
        nullable=False,
        sa_type=Numeric(precision=12, scale=2),
        sa_column_kwargs={"server_default": "0"},
    )
    tax_amount: Decimal = Field(
        default=Decimal("0"),
        nullable=False,
        sa_type=Numeric(precision=12, scale=2),
        sa_column_kwargs={"server_default": "0"},
    )
    total: Decimal = Field(
        nullable=False,
        sa_type=Numeric(precision=12, scale=2),
    )
    payment_method: PaymentMethod = Field(
        sa_column=Column(
            SAEnum(
                PaymentMethod,
                name="paymentmethod",
                values_callable=lambda x: [e.value for e in x],
            ),
            nullable=False,
        ),
    )
    actor_id: UUID | None = Field(
        default=None,
        index=True,
        sa_type=PG_UUID,
    )
    customer_id: UUID | None = Field(
        default=None,
        sa_column=Column(
            PG_UUID,
            ForeignKey("customers.id", ondelete="SET NULL"),
            nullable=True,
            index=True,
        ),
    )
    order_type: OrderType = Field(
        default=OrderType.DINE_IN,
        sa_column=Column(
            SAEnum(
                OrderType,
                name="ordertype",
                values_callable=lambda x: [e.value for e in x],
            ),
            nullable=False,
            server_default="dine_in",
            index=True,
        ),
    )
    courier_id: UUID | None = Field(
        default=None,
        sa_column=Column(
            PG_UUID,
            ForeignKey("couriers.id", ondelete="SET NULL"),
            nullable=True,
            index=True,
        ),
    )
    delivery_address_line1: str | None = Field(default=None, max_length=500)
    delivery_recipient_phone: str | None = Field(default=None, max_length=50)
    delivery_note: str | None = Field(default=None, max_length=500)
    delivery_fee: Decimal = Field(
        default=Decimal("0"),
        nullable=False,
        sa_type=Numeric(precision=12, scale=2),
        sa_column_kwargs={"server_default": "0"},
    )
    delivery_status: DeliveryStatus | None = Field(
        default=None,
        sa_column=Column(
            SAEnum(
                DeliveryStatus,
                name="deliverystatus",
                values_callable=lambda x: [e.value for e in x],
            ),
            nullable=True,
            index=True,
        ),
    )
    occurred_at: datetime = Field(
        nullable=False,
        index=True,
        sa_type=DateTime(timezone=True),
    )
    synced_at: datetime = Field(
        default_factory=lambda: datetime.now(UTC),
        sa_type=DateTime(timezone=True),
        sa_column_kwargs={"server_default": func.now()},
        nullable=False,
    )
    device_sequence: int | None = Field(default=None)
    is_time_suspect: bool = Field(
        default=False,
        nullable=False,
        sa_column_kwargs={"server_default": "false"},
    )
    void_client_action_id: str | None = Field(
        default=None, max_length=255, unique=True,
    )
    refund_client_action_id: str | None = Field(
        default=None, max_length=255, unique=True,
    )
    voided_at: datetime | None = Field(
        default=None,
        sa_type=DateTime(timezone=True),
    )
    refunded_at: datetime | None = Field(
        default=None,
        sa_type=DateTime(timezone=True),
    )
    void_or_refund_reason: str | None = Field(default=None, max_length=500)
    created_at: datetime = Field(
        default_factory=lambda: datetime.now(UTC),
        sa_type=DateTime(timezone=True),
        sa_column_kwargs={"server_default": func.now()},
        nullable=False,
    )


class SaleLineItem(SQLModel, table=True):
    """Individual line within a sale.

    ``item_id`` is a cross-service reference to Inventory Service's
    ``items`` table — no FK constraint, same discipline as
    ``business_id`` / ``store_id``.

    ``unit_price`` is captured at the time of sale and never dynamically
    looked up, ensuring historical accuracy regardless of future price
    changes in Inventory Service.

    ``sale_id`` IS a real FK — it references the parent ``sale`` row in
    the same database.
    """

    __tablename__ = "sale_line_items"

    id: UUID = Field(
        default_factory=uuid4,
        primary_key=True,
        nullable=False,
        sa_type=PG_UUID,
    )
    sale_id: UUID = Field(
        sa_column=Column(
            PG_UUID,
            ForeignKey("sales.id", ondelete="CASCADE"),
            nullable=False,
            index=True,
        ),
    )
    item_id: UUID = Field(
        nullable=False,
        index=True,
        sa_type=PG_UUID,
    )
    quantity: Decimal = Field(
        nullable=False,
        sa_type=Numeric(precision=12, scale=3),
    )
    unit_price: Decimal = Field(
        nullable=False,
        sa_type=Numeric(precision=12, scale=2),
    )
    discount_amount: Decimal = Field(
        default=Decimal("0"),
        nullable=False,
        sa_type=Numeric(precision=12, scale=2),
        sa_column_kwargs={"server_default": "0"},
    )
    line_total: Decimal = Field(
        nullable=False,
        sa_type=Numeric(precision=12, scale=2),
    )
    # Production-cost snapshot captured at sale time (per-unit cost of the
    # item when it was sold). Nullable: sales synced by older clients carry
    # no snapshot, and reports fall back to live recipe costs for those.
    # Frozen on write like ``unit_price`` — grocery price changes must
    # never rewrite history, so profit stays accurate per sale.
    unit_cost: Decimal | None = Field(
        default=None,
        sa_type=Numeric(precision=12, scale=4),
    )
    created_at: datetime = Field(
        default_factory=lambda: datetime.now(UTC),
        sa_type=DateTime(timezone=True),
        sa_column_kwargs={"server_default": func.now()},
        nullable=False,
    )
