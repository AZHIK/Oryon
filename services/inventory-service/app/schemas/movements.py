"""Schemas for StockMovement — read-only.

Stock movements form an immutable audit trail.  There is no
Create/Update/Delete API — records are inserted exclusively through the
internal ``record_movement`` service function (Stage 5), never via a raw
"create movement" endpoint.
"""

from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from uuid import UUID

from pydantic import BaseModel, ConfigDict

from app.models.inventory import ActorType, MovementType


class StockMovementRead(BaseModel):
    """A single stock movement record from the immutable audit trail."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    item_id: UUID
    business_id: UUID
    store_id: UUID
    quantity_delta: Decimal
    movement_type: MovementType
    reference_type: str | None = None
    reference_id: UUID | None = None
    actor_type: ActorType
    actor_id: UUID | None = None
    reason: str | None = None
    # Frozen per-unit cost basis at event time. Null for legacy rows written
    # before the snapshot existed — readers fall back to Item.unit_cost.
    unit_cost: Decimal | None = None
    created_at: datetime