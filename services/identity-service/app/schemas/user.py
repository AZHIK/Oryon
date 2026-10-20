"""Schemas for the User model — CRUD plus dedicated schemas for sensitive operations."""

from __future__ import annotations

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict

from app.models.user import UserCategory, UserStatus
from app.schemas.validators import NormalizedEmailStr, PhoneStr


class UserBase(BaseModel):
    """Shared fields present in every user schema.

    ``phone`` is optional because email-only invited staff exist before they
    add a number; self-registration still requires it (``UserCreate``).
    """

    phone: str | None = None
    email: str | None = None
    full_name: str
    user_category: UserCategory


class UserCreate(UserBase):
    """Fields required to create a user (admin-initiated, not self-registration).

    Does NOT include a password — registration flows have their own schemas in auth.py.
    """

    phone: PhoneStr
    email: NormalizedEmailStr | None = None


class UserUpdate(BaseModel):
    """Fields that may be updated on a user profile (partial update).

    Phone changes and status changes have dedicated schemas below.
    """

    full_name: str | None = None
    email: NormalizedEmailStr | None = None


class UserRead(UserBase):
    """Full user representation returned by the API.

    password_hash is never exposed.
    """

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    is_active: bool
    is_phone_verified: bool
    is_email_verified: bool
    status: UserStatus
    created_at: datetime
    updated_at: datetime


class UserPhoneChangeRequest(BaseModel):
    """Dedicated schema for changing a user's phone number (sensitive operation)."""

    phone: PhoneStr


class UserStatusUpdate(BaseModel):
    """Dedicated schema for updating a user's status (sensitive operation)."""

    status: UserStatus


class UserAdminUpdate(BaseModel):
    """Admin-only schema for updating a user's account-level fields.

    Unlike UserUpdate (self-service, limited to full_name/email), this
    schema allows platform staff to change status, is_active, and
    user_category — fields that should never be self-service.
    """

    status: UserStatus | None = None
    is_active: bool | None = None
    user_category: UserCategory | None = None


class UserListFilters(BaseModel):
    """Query-parameter schema for listing users with optional filters.

    Used as query parameters on GET /admin/users, not a request body.
    """

    user_category: UserCategory | None = None
    status: UserStatus | None = None
    is_active: bool | None = None
    search: str | None = None
