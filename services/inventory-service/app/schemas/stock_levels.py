"""Schemas for StockLevel — read-only.

StockLevelRead includes denormalized item fields populated by a JOIN in
the endpoint layer (Stage 8 / reports.py) so that callers can display
"12 kg of Rice" without a second lookup per row.

No Create / Update / Delete schemas exist — stock_levels is never written
directly via a generic API.  The only way to modify a stock level is
through ``record_movement`` (Stage 5).
"""

from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from uuid import UUID

from pydantic import BaseModel, ConfigDict

from app.models.inventory import ItemType


class StockLevelRead(BaseModel):
    """Current stock level for an item at a specific store, with denormalized item info."""

    model_config = ConfigDict(from_attributes=True)

    item_id: UUID
    store_id: UUID
    current_quantity: Decimal
    updated_at: datetime
    item_name: str
    item_unit_of_measure: str
    item_category: str | None = None
    item_reorder_threshold: Decimal
    item_type: ItemType
