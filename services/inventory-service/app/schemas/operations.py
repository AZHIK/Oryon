"""Schemas for manual inventory operations — adjustments, waste recording, and transfers.

These are the structured request bodies for the operations endpoints
(Stage 5).  Validation rules are enforced at the schema level so that
invalid requests are rejected before reaching the service layer.
"""

from __future__ import annotations

from decimal import Decimal
from uuid import UUID

from pydantic import BaseModel, ValidationInfo, field_validator


class AdjustStockRequest(BaseModel):
    """Request to manually adjust stock by a delta (positive or negative).

    Used for count corrections where the actual count differs from the
    system record — the delta can go either direction.
    """

    quantity_delta: Decimal
    reason: str

    @field_validator("reason")
    @classmethod
    def reason_min_length(cls, v: str) -> str:
        if len(v.strip()) < 3:
            raise ValueError("Reason must be at least 3 characters long")
        return v.strip()


class RecordWasteRequest(BaseModel):
    """Request to record wasted/spoiled stock.

    quantity is a positive number — waste is always a reduction.
    The service layer negates it internally when calling record_movement.
    """

    quantity: Decimal
    reason: str

    @field_validator("quantity")
    @classmethod
    def quantity_must_be_positive(cls, v: Decimal) -> Decimal:
        if v <= 0:
            raise ValueError("Quantity must be a positive number")
        return v

    @field_validator("reason")
    @classmethod
    def reason_min_length(cls, v: str) -> str:
        if len(v.strip()) < 3:
            raise ValueError("Reason must be at least 3 characters long")
        return v.strip()


class TransferStockRequest(BaseModel):
    """Request to transfer stock between two stores.

    source_store_id and destination_store_id must differ — a
    self-transfer is rejected at the schema level.
    """

    item_id: UUID
    source_store_id: UUID
    destination_store_id: UUID
    quantity: Decimal

    @field_validator("quantity")
    @classmethod
    def quantity_must_be_positive(cls, v: Decimal) -> Decimal:
        if v <= 0:
            raise ValueError("Quantity must be a positive number")
        return v

    @field_validator("destination_store_id")
    @classmethod
    def destination_must_differ_from_source(cls, v: UUID, info: ValidationInfo) -> UUID:
        if "source_store_id" in info.data and v == info.data["source_store_id"]:
            raise ValueError("Source and destination stores must be different")
        return v
