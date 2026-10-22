"""Sale schemas — sync input, batch envelope, read models, and filters.

=============================================================================
PRE-VOIDED / PRE-REFUNDED SALE ON FIRST SYNC  (design decision, MVP)
=============================================================================
ALLOWED.  A cashier can ring up a sale and void it immediately, all before
ever syncing.  POS Service never sees an intermediate "open" state — the
sale arrives in its final form.  The schema enforces that
``void_or_refund_reason`` is provided when ``status`` is ``voided`` or
``refunded``, but does not reject a sale that was born already-voided.

=============================================================================
PARTIAL-SUCCESS BATCH DESIGN  (design decision, MVP)
=============================================================================
The batch sync endpoint returns one result per submitted ``client_sale_id``
(``created``, ``duplicate``, or ``failed``).  A batch is NOT all-or-nothing
at the HTTP level — individual sales within a batch succeed or fail
independently.  This is a first-class design choice so that the client can
stop retrying successes without losing visibility into failures.
"""

from __future__ import annotations

from datetime import UTC, datetime
from decimal import Decimal
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, Field, field_validator, model_validator

from app.schemas.line_items import SaleLineItemInput, SaleLineItemRead

# ── Sync input ──────────────────────────────────────────────────────────


class SaleSyncInput(BaseModel):
    """One sale within a sync batch, submitted by the offline device.

    The sale arrives in its final server-side state — POS Service has no
    "open/in-progress" concept.

    ``void_or_refund_reason`` is required when ``status`` is ``voided`` or
    ``refunded`` (validated below).  ``device_sequence`` is optional since
    the device may not always provide one.
    """

    client_sale_id: str
    status: Literal["completed", "voided", "refunded"]
    store_id: UUID
    line_items: list[SaleLineItemInput] = Field(min_length=1)
    discount_amount: Decimal = Field(default=Decimal("0"), ge=Decimal("0"))
    payment_method: Literal["cash", "mobile_money", "card", "other"]
    customer_id: UUID | None = None
    occurred_at: datetime
    device_sequence: int | None = None
    void_or_refund_reason: str | None = None
    order_type: Literal["dine_in", "takeaway", "delivery"] = "dine_in"
    courier_id: UUID | None = None
    delivery_address_line1: str | None = Field(default=None, max_length=500)
    delivery_recipient_phone: str | None = Field(default=None, max_length=50)
    delivery_note: str | None = Field(default=None, max_length=500)
    delivery_fee: Decimal = Field(default=Decimal("0"), ge=Decimal("0"))

    @field_validator("occurred_at")
    @classmethod
    def _assume_naive_is_utc(cls, value: datetime) -> datetime:
        """Treat a timezone-naive timestamp as UTC rather than crashing later.

        `occurred_at` is documented as UTC device time, but nothing here
        enforced that a client actually attaches a timezone marker — a plain
        `datetime.now().toIso8601String()` on the Dart side has none.
        `detect_time_drift` compares this against `datetime.now(UTC)`
        (timezone-aware), and Python raises `TypeError` comparing naive to
        aware rather than any usable error — normalize at the input
        boundary instead of letting a malformed request 500 deep in
        business logic.
        """
        return value if value.tzinfo is not None else value.replace(tzinfo=UTC)

    @model_validator(mode="after")
    def _validate_void_reason(self) -> SaleSyncInput:
        if self.status in ("voided", "refunded") and not self.void_or_refund_reason:
            raise ValueError(
                "void_or_refund_reason is required when status is voided or refunded"
            )
        return self

    @model_validator(mode="after")
    def _validate_delivery_fields(self) -> SaleSyncInput:
        if self.order_type == "delivery":
            if not self.delivery_address_line1:
                raise ValueError(
                    "delivery_address_line1 is required when order_type is delivery"
                )
        else:
            if self.courier_id is not None:
                raise ValueError(
                    "courier_id is only allowed when order_type is delivery"
                )
            if self.delivery_address_line1 is not None:
                raise ValueError(
                    "delivery_address_line1 is only allowed when order_type is delivery"
                )
            if self.delivery_recipient_phone is not None:
                raise ValueError(
                    "delivery_recipient_phone is only allowed when order_type is delivery"
                )
            if self.delivery_note is not None:
                raise ValueError(
                    "delivery_note is only allowed when order_type is delivery"
                )
            if self.delivery_fee != Decimal("0"):
                raise ValueError(
                    "delivery_fee is only allowed when order_type is delivery"
                )
        return self


class SaleSyncBatchRequest(BaseModel):
    """Batch of completed/voided/refunded sales from an offline device."""

    sales: list[SaleSyncInput] = Field(min_length=1)


# ── Sync response ───────────────────────────────────────────────────────


class SyncResult(BaseModel):
    """Outcome for a single ``client_sale_id`` within a batch sync.

    ``created`` — first time this ``client_sale_id`` has been seen.
    ``duplicate`` — already processed (idempotency key collision).
    ``failed`` — validation error (``reason`` contains details).
    """

    client_sale_id: str
    status: Literal["created", "duplicate", "failed"]
    reason: str | None = None


class SaleSyncBatchResponse(BaseModel):
    """Per-sale results for a batch sync.

    Not all-or-nothing — individual sales can succeed or fail independently.
    """

    results: list[SyncResult]


# ── Read models ─────────────────────────────────────────────────────────


class SaleRead(BaseModel):
    """Full server-side sale representation returned by GET endpoints."""

    id: UUID
    business_id: UUID
    store_id: UUID
    client_sale_id: str
    status: str
    subtotal: Decimal
    discount_amount: Decimal
    tax_amount: Decimal
    delivery_fee: Decimal = Decimal("0")
    total: Decimal
    payment_method: str
    actor_id: UUID | None = None
    customer_id: UUID | None = None
    order_type: str = "dine_in"
    courier_id: UUID | None = None
    delivery_address_line1: str | None = None
    delivery_recipient_phone: str | None = None
    delivery_note: str | None = None
    delivery_status: str | None = None
    occurred_at: datetime
    synced_at: datetime
    device_sequence: int | None = None
    is_time_suspect: bool = False
    voided_at: datetime | None = None
    refunded_at: datetime | None = None
    void_or_refund_reason: str | None = None
    created_at: datetime
    line_items: list[SaleLineItemRead]


class SaleListItem(BaseModel):
    """Compact sale representation for list endpoints (no line items)."""

    id: UUID
    business_id: UUID
    store_id: UUID
    client_sale_id: str
    status: str
    subtotal: Decimal
    discount_amount: Decimal
    tax_amount: Decimal
    delivery_fee: Decimal = Decimal("0")
    total: Decimal
    payment_method: str
    actor_id: UUID | None = None
    customer_id: UUID | None = None
    order_type: str = "dine_in"
    courier_id: UUID | None = None
    delivery_status: str | None = None
    occurred_at: datetime
    synced_at: datetime
    device_sequence: int | None = None
    is_time_suspect: bool = False
    voided_at: datetime | None = None
    refunded_at: datetime | None = None
    void_or_refund_reason: str | None = None
    created_at: datetime


class SaleListResponse(BaseModel):
    """Paginated list response for sales."""

    items: list[SaleListItem]
    total: int
    limit: int
    offset: int


class PaymentMethodSummary(BaseModel):
    """Aggregate for a single payment method in the summary."""

    payment_method: str
    count: int
    revenue: Decimal


class SaleSummaryResponse(BaseModel):
    """Lightweight aggregate response for the sales dashboard."""

    total_count: int
    total_revenue: Decimal
    voided_count: int
    refunded_count: int
    payment_method_breakdown: list[PaymentMethodSummary]


# ── Query filters ───────────────────────────────────────────────────────


class SaleListFilters(BaseModel):
    """Query-parameter schema for listing sales.

    All filters are optional.  Date-range filtering is applied against
    ``occurred_at`` (the device-reported timestamp) per the SRS.
    """

    from_date: datetime | None = None
    to_date: datetime | None = None
    status: Literal["completed", "voided", "refunded"] | None = None
    payment_method: Literal["cash", "mobile_money", "card", "other"] | None = None
    store_id: UUID | None = None
    order_type: Literal["dine_in", "takeaway", "delivery"] | None = None
    courier_id: UUID | None = None
    delivery_status: (
        Literal["pending", "assigned", "out_for_delivery", "delivered", "failed"] | None
    ) = None


class DeliveryStatusUpdate(BaseModel):
    """PATCH body for advancing a delivery sale's fulfilment state."""

    delivery_status: Literal[
        "pending", "assigned", "out_for_delivery", "delivered", "failed"
    ]
    courier_id: UUID | None = None
