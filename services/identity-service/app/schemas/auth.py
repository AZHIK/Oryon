"""Authentication flow schemas for business-staff, store-staff, and platform-staff tracks.

Covers registration, OTP, login, password reset, token claims, and
business-context switching.
"""

from __future__ import annotations

from typing import Any
from uuid import UUID

from pydantic import BaseModel, Field

from app.models.user import UserCategory
from app.schemas.validators import (
    BusinessPassword,
    NormalizedEmailStr,
    OTPCodeStr,
    PhoneStr,
    StrongPassword,
)

# ══════════════════════════════════════════════════════════════════════════
# Business-user / driver / consumer track (phone-first)
# ══════════════════════════════════════════════════════════════════════════


class BusinessUserRegisterRequest(BaseModel):
    """Self-registration payload for business-user / driver / consumer accounts.

    Password is optional — OTP-only accounts pass None.
    """

    phone: PhoneStr
    full_name: str
    email: NormalizedEmailStr | None = None
    password: BusinessPassword | None = None


class UpdateProfileRequest(BaseModel):
    """Self-service update of the caller's own name/email/phone (PATCH /users/me).

    Every field is optional except the name; only the fields present in the
    request are written, so saving a name never clears the identifier the
    account signs in with.
    """

    full_name: str
    email: NormalizedEmailStr | None = None
    phone: PhoneStr | None = None


class RequestOTPRequest(BaseModel):
    """Request an OTP code sent to the user's phone."""

    phone: PhoneStr


class VerifyOTPRequest(BaseModel):
    """Verify an OTP code submitted by the user."""

    phone: PhoneStr
    code: OTPCodeStr


class RequestEmailOTPRequest(BaseModel):
    """Request an OTP code sent to the user's email address."""

    email: NormalizedEmailStr


class VerifyEmailOTPRequest(BaseModel):
    """Verify an OTP code delivered to the user's email address."""

    email: NormalizedEmailStr
    code: OTPCodeStr


class PasswordLoginRequest(BaseModel):
    """Login with phone number and password (no strength validation on login)."""

    phone: PhoneStr
    password: str


class PasswordResetRequest(BaseModel):
    """Request a password reset; an OTP is sent to the user's phone."""

    phone: PhoneStr


class PasswordResetConfirm(BaseModel):
    """Confirm a password reset with the OTP and a new password."""

    phone: PhoneStr
    code: OTPCodeStr
    new_password: BusinessPassword


# ══════════════════════════════════════════════════════════════════════════
# Platform-staff track (email-first, stronger requirements)
# ══════════════════════════════════════════════════════════════════════════


class PlatformStaffRegisterRequest(BaseModel):
    """Create a platform-staff account (admin-initiated, not self-serve signup)."""

    email: NormalizedEmailStr
    full_name: str
    password: StrongPassword
    group_id: UUID


class PlatformStaffLoginRequest(BaseModel):
    """Login with email and password (no strength validation on login)."""

    email: NormalizedEmailStr
    password: str


class PlatformStaffVerifyMFARequest(BaseModel):
    """Placeholder schema for MFA/OTP second-factor verification for platform staff.

    The actual MFA flow is not yet implemented; this schema exists so the
    shape is defined ahead of the feature.
    """

    email: NormalizedEmailStr
    code: OTPCodeStr


# ══════════════════════════════════════════════════════════════════════════
# Shared response / token schemas
# ══════════════════════════════════════════════════════════════════════════


class TokenResponse(BaseModel):
    """Standard token response returned on successful authentication."""

    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class BusinessStaffTokenClaims(BaseModel):
    """Claims shape for a business-staff JWT (for documentation / response typing, not encoding)."""

    sub: str
    user_category: UserCategory = UserCategory.BUSINESS_STAFF
    active_business_id: UUID | None = None
    roles: list[str] = Field(default_factory=list)
    permissions: list[str] = Field(default_factory=list)
    other_businesses: list[dict[str, Any]] = Field(
        default_factory=list,
        description="List of {id: UUID, name: str} for business-switcher UI",
    )


class StoreStaffTokenClaims(BaseModel):
    """Claims shape for a business-store-staff JWT (doc / response typing, not encoding)."""

    sub: str
    user_category: UserCategory = UserCategory.BUSINESS_STORE_STAFF
    active_business_id: UUID | None = None
    active_store_id: UUID | None = None
    roles: list[str] = Field(default_factory=list)
    permissions: list[str] = Field(default_factory=list)


class PlatformStaffTokenClaims(BaseModel):
    """Claims shape for a platform-staff JWT (for documentation / response typing, not encoding)."""

    sub: str
    user_category: UserCategory = UserCategory.PLATFORM_STAFF
    group: str
    roles: list[str] = Field(default_factory=list)
    permissions: list[str] = Field(default_factory=list)


class DriverConsumerTokenClaims(BaseModel):
    """Claims shape for a driver/consumer JWT (doc / response typing, not encoding)."""

    sub: str
    user_category: UserCategory  # DRIVER or CONSUMER
    platform_role: str
    permissions: list[str] = Field(default_factory=list)


class SwitchBusinessContextRequest(BaseModel):
    """Request to switch the active business context for a multi-business user."""

    business_id: UUID


class SwitchStoreContextRequest(BaseModel):
    """Request to switch the terminal's operating store within the active business."""

    store_id: UUID


class RefreshRequest(BaseModel):
    """Request to rotate a refresh token."""

    refresh_token: str


class LogoutRequest(BaseModel):
    """Request to revoke a session via its refresh token."""

    refresh_token: str
