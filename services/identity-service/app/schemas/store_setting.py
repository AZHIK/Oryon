"""Schemas for the StoreSetting model (one-to-one with Store).

A StoreSetting row is created automatically alongside its Store (see the
business-creation flow), so there is no standalone POST endpoint — the
StoreSettingCreate schema exists for completeness/consistency but is not
exposed as a create route.
"""

from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from app.schemas.validators import NormalizedEmailStr, PhoneStr


class StoreSettingBase(BaseModel):
    """Shared fields for store setting schemas."""

    store_id: UUID
    active: bool = True
    address: str | None = None
    latitude: Decimal | None = None
    longitude: Decimal | None = None
    email: NormalizedEmailStr | None = None
    phone: PhoneStr | None = None
    preferred_currency: str = "TZS"
    amount: Decimal | None = None
    max_payment_time_minutes: int | None = None
    logo: str | None = None
    offer_retail: bool = True
    offer_wholesale: bool = False
    display_prices_inclusive_of_tax: bool = False
    # Tax switch (off by default). tax_rate is a fraction (0.18 = 18%).
    tax_enabled: bool = False
    tax_rate: Decimal | None = Field(default=Decimal("0"), ge=Decimal("0"), le=Decimal("1"))


class StoreSettingCreate(StoreSettingBase):
    """Fields for a store setting row.

    Not exposed as a standalone POST endpoint — the row is created
    automatically with its store.
    """


class StoreSettingUpdate(BaseModel):
    """Fields that may be updated on a store setting (partial update)."""

    active: bool | None = None
    address: str | None = None
    latitude: Decimal | None = None
    longitude: Decimal | None = None
    email: NormalizedEmailStr | None = None
    phone: PhoneStr | None = None
    preferred_currency: str | None = None
    amount: Decimal | None = None
    max_payment_time_minutes: int | None = None
    logo: str | None = None
    offer_retail: bool | None = None
    offer_wholesale: bool | None = None
    display_prices_inclusive_of_tax: bool | None = None
    tax_enabled: bool | None = None
    tax_rate: Decimal | None = Field(default=None, ge=Decimal("0"), le=Decimal("1"))


class StoreSettingRead(StoreSettingBase):
    """Full store setting representation returned by the API."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    created_at: datetime
    updated_at: datetime
