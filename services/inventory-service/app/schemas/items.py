"""Schemas for the Item model.

═══════════════════════════════════════════════════════════════════════════
ItemCreate includes business_id and store_id — why?
═══════════════════════════════════════════════════════════════════════════

Unlike Identity Service's BusinessCreateRequest (where owner_user_id is
derivable from the JWT's ``sub`` claim and is intentionally omitted from
the request body), an item's *business context* is NOT always derivable
from the JWT alone:

- A business user may hold access to multiple businesses through their
  ``other_businesses`` claim, and the ``active_business_id`` in the JWT
  reflects their *current switch*, not necessarily the business they want
  to create an item for.
- During automated / system-to-system creation (e.g. bulk import from a
  supplier catalog), no user JWT is involved at all.

Therefore the schema accepts these IDs explicitly.  The endpoint layer
MAY override them (e.g. force them to match the authenticated user's
context) but the schema itself is honest about what data it needs.
"""

from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, computed_field

from app.models.inventory import ItemType


class ItemBase(BaseModel):
    """Shared fields for item schemas."""

    name: str
    unit_id: UUID
    category_id: UUID | None = None
    supplier_id: UUID | None = None
    reorder_threshold: Decimal
    reorder_quantity: Decimal
    selling_price: Decimal | None = None
    unit_cost: Decimal | None = None
    allow_negative_stock: bool = False
    item_type: ItemType


class ItemCreate(ItemBase):
    """Fields required to create an item.

    ``business_id`` is intentionally absent — it is taken from the URL path
    (``/businesses/{business_id}/items``) and cross-validated against the
    JWT's ``active_business_id`` by the endpoint layer.

    ``store_id`` is required here because the caller knows which
    store within the business this item belongs to.  The endpoint layer
    does NOT override it.
    """

    store_id: UUID

    # Opening on-hand quantity at the item's store. Optional, defaults to 0.
    # Must be >= 0 — opening stock is never negative. When > 0 the create
    # endpoint records it as a MANUAL_ADJUSTMENT movement ("Opening stock")
    # so stock_levels and the audit trail stay consistent.
    initial_quantity: Decimal = Field(default=Decimal("0"), ge=Decimal("0"))


class ItemUpdate(BaseModel):
    """Fields that may be updated on an item (partial update).

    Excludes business_id and store_id — an item's store
    should not change via a generic PATCH.  Transferring an item between
    stores is a separate operation handled by a dedicated endpoint in a
    later stage.
    """

    name: str | None = None
    unit_id: UUID | None = None
    category_id: UUID | None = None
    supplier_id: UUID | None = None
    reorder_threshold: Decimal | None = None
    reorder_quantity: Decimal | None = None
    selling_price: Decimal | None = None
    unit_cost: Decimal | None = None
    allow_negative_stock: bool | None = None
    item_type: ItemType | None = None
    is_active: bool | None = None


class ItemRead(ItemBase):
    """Full item representation returned by the API."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    business_id: UUID
    store_id: UUID
    # Relaxed from ItemBase's required UUID: legacy rows predating the
    # mandatory-unit rule may carry NULL, and one such row must never 500
    # the whole list (ResponseValidationError). Creation still requires a
    # unit — see ItemBase — and reordering a unit-less item is refused
    # with 422 at receive/create time.
    unit_id: UUID | None = None
    is_active: bool
    created_at: datetime
    updated_at: datetime

    # Raw storage key — excluded from the wire. Exists only so the
    # ``image_url`` computed field below can tell "has a photo" from
    # "no photo" without a second query.
    image_path: str | None = Field(default=None, exclude=True)

    @computed_field
    @property
    def image_url(self) -> str | None:
        """Service-relative URL of the item's product photo, or null.

        Resolved by the app against Inventory Service's base URL (which
        already ends in ``/api/v1``) — the same convention every other
        endpoint path in this service follows. Null means no photo; the
        app falls back to its placeholder.
        """
        if not self.image_path:
            return None
        return f"/businesses/{self.business_id}/items/{self.id}/image"


class ItemListFilters(BaseModel):
    """Query-parameter schema for the list-items endpoint (Stage 4)."""

    category_id: UUID | None = None
    supplier_id: UUID | None = None
    is_active: bool | None = None
    below_threshold: bool | None = None
    store_id: UUID | None = None
