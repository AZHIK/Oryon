"""Schemas for the Reorder model."""

from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, field_validator

from app.models.reorders import ReorderStatus


class ReorderCreate(BaseModel):
    """Fields required to place a reorder — qty-only.

    ``business_id`` comes from the URL path, same convention as
    ``ItemCreate``. ``store_id`` is required — receiving credits a specific
    store's stock level. ``unit`` is deliberately absent: it is always
    denormalized server-side from the item's own ``unit_id`` (resolved to
    the referenced ``Unit.code``) at creation time (see
    ``app/models/reorders.py``'s module docstring), never client-supplied.
    Cost is captured at receive time (``ReorderReceive.unit_cost``), never
    here.
    """

    store_id: UUID
    item_id: UUID
    supplier_id: UUID
    quantity: Decimal
    notes: str | None = None
    expected_at: datetime | None = None

    @field_validator("quantity")
    @classmethod
    def quantity_must_be_positive(cls, v: Decimal) -> Decimal:
        if v <= 0:
            raise ValueError("Quantity must be a positive number")
        return v


class ReorderReceive(BaseModel):
    """Cost captured when a reorder's goods arrive.

    ``unit_cost`` is optional: when supplied it revalues ``Item.unit_cost``
    via weighted averaging; when omitted stock moves without revaluation.
    """

    unit_cost: Decimal | None = None

    @field_validator("unit_cost")
    @classmethod
    def unit_cost_must_be_non_negative(cls, v: Decimal | None) -> Decimal | None:
        if v is not None and v < 0:
            raise ValueError("Unit cost must not be negative")
        return v


class ReorderRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    business_id: UUID
    store_id: UUID
    item_id: UUID
    supplier_id: UUID
    quantity: Decimal
    unit: str
    status: ReorderStatus
    notes: str | None
    ordered_at: datetime
    ordered_by: UUID | None
    expected_at: datetime | None
    received_at: datetime | None
    received_by: UUID | None
    cancelled_at: datetime | None
    cancelled_by: UUID | None
    created_at: datetime


class ReorderListFilters(BaseModel):
    """Query-parameter schema for the list-reorders endpoint."""

    status: ReorderStatus | None = None
    item_id: UUID | None = None
    store_id: UUID | None = None


class ReorderListResponse(BaseModel):
    items: list[ReorderRead]
    total: int
    limit: int
    offset: int
