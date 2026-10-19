"""Schemas for the Store model.

location_type is validated by the LocationType enum at the schema level.
Cross-validation against business_type is business logic — out of scope here.

``token`` is a plain unique identifier generated server-side at creation; it
carries no authentication semantics and is never accepted on create/update.
"""

from __future__ import annotations

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict

from app.models.business import BusinessStatus, LocationType


class StoreBase(BaseModel):
    """Shared fields for store schemas.

    ``business_id`` is deliberately not declared here: create requests take it
    from the path (and may omit it in the body), while read responses always
    include it. Declaring it optional in the base and required in
    ``StoreRead`` keeps both shapes type-checkable.
    """

    name: str
    location_type: LocationType
    status: BusinessStatus = BusinessStatus.ACTIVE
    country_code: str = "TZ"
    city: str | None = None
    address: str | None = None
    timezone: str = "Africa/Dar_es_Salaam"
    is_primary: bool = False


class StoreCreate(StoreBase):
    """Fields required to create a store.

    location_type must be one of: head_office, restaurant_branch, kitchen,
    warehouse, farm, depot. Other values are rejected at the schema level.

    ``business_id`` is optional here: the endpoint takes it from the path
    (``POST /businesses/{business_id}/stores``) and ignores any body value,
    so clients must not be forced to send it — requiring it 422s legitimate
    calls that only carry the store fields.
    """

    business_id: UUID | None = None


class StoreUpdate(BaseModel):
    """Fields that may be updated on a store (partial update)."""

    name: str | None = None
    location_type: LocationType | None = None
    status: BusinessStatus | None = None
    country_code: str | None = None
    city: str | None = None
    address: str | None = None
    timezone: str | None = None
    is_primary: bool | None = None


class StoreRead(StoreBase):
    """Full store representation returned by the API."""

    model_config = ConfigDict(from_attributes=True)

    business_id: UUID
    id: UUID
    token: str
    created_at: datetime
    updated_at: datetime
