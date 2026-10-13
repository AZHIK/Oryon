"""Schemas for the requisition (unified multi-supplier order) flow."""

from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, field_validator


class RequisitionLineInput(BaseModel):
    item_id: UUID
    qty: Decimal
    supplier_id: UUID | None = None

    @field_validator("qty")
    @classmethod
    def qty_must_be_positive(cls, v: Decimal) -> Decimal:
        if v <= 0:
            raise ValueError("Quantity must be a positive number")
        return v


class RequisitionSubmit(BaseModel):
    """Finalized cart: lines already carry supplier_ids (per-item and/or bulk).

    ``expected_at`` is the single per-requisition delivery request date.
    ``idempotency_key`` guards duplicate submit / double-tap.
    """

    store_id: UUID
    notes: str | None = None
    expected_at: datetime | None = None
    idempotency_key: str | None = None
    lines: list[RequisitionLineInput]

    @field_validator("lines")
    @classmethod
    def lines_must_not_be_empty(cls, v: list[RequisitionLineInput]) -> list[RequisitionLineInput]:
        if not v:
            raise ValueError("A requisition must contain at least one line")
        return v


class BulkAssignRequest(BaseModel):
    supplier_id: UUID
    scope: str = "unassigned_items_only"
    # Explicit "override all" toggle (confirmed): only when True does
    # scope="all_items" replace existing per-item choices.
    overwrite: bool = False

    @field_validator("scope")
    @classmethod
    def scope_must_be_known(cls, v: str) -> str:
        if v not in ("all_items", "unassigned_items_only"):
            raise ValueError("scope must be 'all_items' or 'unassigned_items_only'")
        return v


class RequisitionLineRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    requisition_id: UUID
    item_id: UUID
    qty: Decimal
    supplier_id: UUID | None
    unit_price_snapshot: Decimal | None
    price_unconfirmed: bool
    supplier_assignment_source: str | None = None


class SupplierMessageRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    po_id: UUID
    direction: str
    channel: str
    payload: dict
    status: str
    created_at: datetime
    sent_at: datetime | None = None


class PurchaseOrderSplitRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    supplier_id: UUID
    po_number: str
    status: str
    requisition_id: UUID | None = None


class RequisitionRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    business_id: UUID
    store_id: UUID
    notes: str | None = None
    expected_at: datetime | None = None
    idempotency_key: str | None = None
    created_at: datetime


class RequisitionSubmitResponse(BaseModel):
    requisition: RequisitionRead
    purchase_orders: list[PurchaseOrderSplitRead]
    messages: list[SupplierMessageRead]
    # Item names whose price could not be confirmed — UI display flags.
    price_unconfirmed_items: list[str] = []
    rollup_status: str


class SupplierItemUpsert(BaseModel):
    supplier_id: UUID
    item_id: UUID
    price: Decimal | None = None
    moq: Decimal | None = None
    lead_time_days: int | None = None
    is_preferred: bool = False


class SupplierItemRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    supplier_id: UUID
    item_id: UUID
    price: Decimal | None
    moq: Decimal | None
    lead_time_days: int | None
    is_preferred: bool
