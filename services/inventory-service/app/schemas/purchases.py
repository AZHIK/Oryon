"""Schemas for the purchases module — two-step POs (create → receive)."""

from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.models.purchases import PurchaseOrderStatus


class PurchaseOrderLineCreate(BaseModel):
    """One item line of a new purchase order — qty-only.

    ``unit`` is deliberately absent: it is always denormalized server-side
    from the item's own ``unit_id`` (resolved to the referenced
    ``Unit.code``) at creation time (see ``app/models/purchases.py``), never
    client-supplied — same convention as ``ReorderCreate``. Cost is
    deliberately absent too: the actual price is captured on each
    ``GoodsReceiptLine`` when goods arrive.
    """

    item_id: UUID
    quantity_ordered: Decimal
    notes: str | None = None

    @field_validator("quantity_ordered")
    @classmethod
    def quantity_must_be_positive(cls, v: Decimal) -> Decimal:
        if v <= 0:
            raise ValueError("Quantity must be a positive number")
        return v


class PurchaseOrderCreate(BaseModel):
    """Fields required to create a purchase order.

    ``business_id`` comes from the URL path, same convention as
    ``ReorderCreate``. ``po_number`` is optional — when omitted the server
    assigns the next ``PO-0001``-style number scoped to the business.
    Orders are created ``unfulfilled`` and received directly.
    """

    store_id: UUID
    supplier_id: UUID
    po_number: str | None = None
    notes: str | None = None
    expected_at: datetime | None = None
    lines: list[PurchaseOrderLineCreate]

    @field_validator("lines")
    @classmethod
    def lines_must_not_be_empty(
        cls, v: list[PurchaseOrderLineCreate]
    ) -> list[PurchaseOrderLineCreate]:
        if not v:
            raise ValueError("A purchase order must contain at least one line")
        item_ids = [line.item_id for line in v]
        if len(set(item_ids)) != len(item_ids):
            raise ValueError("Duplicate item in purchase order lines")
        return v


class PurchaseOrderLineRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    purchase_order_id: UUID
    item_id: UUID
    quantity_ordered: Decimal
    quantity_received: Decimal
    unit: str
    notes: str | None


class PurchaseOrderRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    business_id: UUID
    store_id: UUID
    supplier_id: UUID
    po_number: str
    status: PurchaseOrderStatus
    notes: str | None
    ordered_at: datetime
    ordered_by: UUID | None
    expected_at: datetime | None
    received_at: datetime | None
    received_by: UUID | None
    cancelled_at: datetime | None
    cancelled_by: UUID | None
    created_at: datetime
    updated_at: datetime


class PurchaseOrderListFilters(BaseModel):
    """Query-parameter schema for the list-purchase-orders endpoint."""

    status: PurchaseOrderStatus | None = None
    supplier_id: UUID | None = None
    store_id: UUID | None = None


class PurchaseOrderListResponse(BaseModel):
    items: list[PurchaseOrderRead]
    total: int
    limit: int
    offset: int


# ── Goods receipts (partial GRNs) ──────────────────────────────────────


class GoodsReceiptLineCreate(BaseModel):
    purchase_order_line_id: UUID
    quantity_received: Decimal
    # Actual price for this delivery — drives weighted-average costing.
    unit_cost: Decimal
    lot_no: str | None = Field(default=None, max_length=64)
    expiry_date: datetime | None = None

    @field_validator("quantity_received")
    @classmethod
    def quantity_must_be_positive(cls, v: Decimal) -> Decimal:
        if v <= 0:
            raise ValueError("Quantity must be a positive number")
        return v

    @field_validator("unit_cost")
    @classmethod
    def unit_cost_must_be_non_negative(cls, v: Decimal) -> Decimal:
        if v < 0:
            raise ValueError("Unit cost must not be negative")
        return v


class GoodsReceiptCreate(BaseModel):
    """Receive one delivery against a purchase order.

    The PO id comes from the URL path. Each entry references a PO line and
    carries the actual unit cost for that delivery; the server guards
    ``sum(received) <= ordered`` per line and re-derives the header status
    (``fulfilled`` once every line is fully received, else still
    ``unfulfilled``).
    """

    lines: list[GoodsReceiptLineCreate]
    notes: str | None = None

    @field_validator("lines")
    @classmethod
    def lines_must_not_be_empty(
        cls, v: list[GoodsReceiptLineCreate]
    ) -> list[GoodsReceiptLineCreate]:
        if not v:
            raise ValueError("A goods receipt must contain at least one line")
        line_ids = [line.purchase_order_line_id for line in v]
        if len(set(line_ids)) != len(line_ids):
            raise ValueError("Duplicate purchase order line in goods receipt")
        return v


class GoodsReceiptLineRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    goods_receipt_id: UUID
    purchase_order_line_id: UUID
    item_id: UUID
    quantity_received: Decimal
    unit_cost: Decimal
    lot_no: str | None = None
    expiry_date: datetime | None = None


class GoodsReceiptRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    business_id: UUID
    store_id: UUID
    purchase_order_id: UUID
    grn_number: str
    notes: str | None
    received_at: datetime
    received_by: UUID | None
    created_at: datetime


class GoodsReceiptDetailRead(GoodsReceiptRead):
    lines: list[GoodsReceiptLineRead] = []


class PurchaseOrderDetailRead(PurchaseOrderRead):
    """Header plus lines and receipts for the detail view."""

    lines: list[PurchaseOrderLineRead] = []
    receipts: list[GoodsReceiptRead] = []
