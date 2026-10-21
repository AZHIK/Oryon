import uuid as _uuid
from datetime import UTC, datetime
from enum import StrEnum
from uuid import UUID

from sqlalchemy import DateTime, String, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlmodel import Field, SQLModel

from app.models.base import SoftDeleteMixin, TimestampMixin, UUIDMixin


class VerificationCodeType(StrEnum):
    SMS = "sms"
    EMAIL = "email"


class VerificationCodePurpose(StrEnum):
    PHONE_VERIFICATION = "phone_verification"
    EMAIL_VERIFICATION = "email_verification"
    PASSWORD_RESET = "password_reset"
    LOGIN = "login"
    # Changing the sign-in identifier is a separate, higher-risk purpose so a
    # code issued for login can never be replayed to rewrite the account.
    EMAIL_CHANGE = "email_change"
    PHONE_CHANGE = "phone_change"


class AuthEventType(StrEnum):
    LOGIN_SUCCESS = "login_success"
    LOGIN_FAILURE = "login_failure"
    OTP_FAILURE = "otp_failure"
    PASSWORD_RESET_REQUEST = "password_reset_request"
    DEVICE_TRUSTED = "device_trusted"
    ACCOUNT_LOCKED = "account_locked"


class AuthRiskLevel(StrEnum):
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    CRITICAL = "critical"


class VerificationCode(UUIDMixin, TimestampMixin, SoftDeleteMixin, SQLModel, table=True):
    __tablename__ = "verification_codes"

    user_id: UUID = Field(foreign_key="users.id")
    code_hash: str = Field(max_length=255)
    type: VerificationCodeType = Field(sa_type=String)
    purpose: VerificationCodePurpose = Field(sa_type=String)
    expires_at: datetime = Field(  # type: ignore[call-overload]
        sa_type=DateTime(timezone=True),
    )
    used_at: datetime | None = Field(  # type: ignore[call-overload]
        default=None, sa_type=DateTime(timezone=True), nullable=True
    )
    attempts: int = Field(default=0)


class RefreshToken(UUIDMixin, TimestampMixin, SoftDeleteMixin, SQLModel, table=True):
    __tablename__ = "refresh_tokens"

    user_id: UUID = Field(foreign_key="users.id")
    token_hash: str = Field(unique=True, max_length=255)
    device_info: str | None = Field(default=None, max_length=500)
    ip_address: str | None = Field(default=None, max_length=45)
    expires_at: datetime = Field(  # type: ignore[call-overload]
        sa_type=DateTime(timezone=True),
    )
    revoked_at: datetime | None = Field(  # type: ignore[call-overload]
        default=None, sa_type=DateTime(timezone=True), nullable=True
    )
    family_id: UUID = Field(
        default_factory=_uuid.uuid4,
        nullable=False,
        sa_type=PG_UUID,
        index=True,
    )
    previous_token_id: UUID | None = Field(
        default=None, foreign_key="refresh_tokens.id", nullable=True, sa_type=PG_UUID
    )
    replaced_by_token_id: UUID | None = Field(
        default=None, foreign_key="refresh_tokens.id", nullable=True, sa_type=PG_UUID
    )


class UserSession(UUIDMixin, TimestampMixin, SoftDeleteMixin, SQLModel, table=True):
    __tablename__ = "user_sessions"

    user_id: UUID = Field(foreign_key="users.id")
    refresh_token_id: UUID | None = Field(
        default=None, foreign_key="refresh_tokens.id", nullable=True
    )
    device_info: str | None = Field(default=None, max_length=500)
    ip_address: str | None = Field(default=None, max_length=45)
    last_activity_at: datetime = Field(  # type: ignore[call-overload]
        default_factory=lambda: datetime.now(UTC),
        sa_type=DateTime(timezone=True),
    )
    expires_at: datetime = Field(  # type: ignore[call-overload]
        sa_type=DateTime(timezone=True),
    )
    is_active: bool = Field(default=True)


class TrustedDevice(UUIDMixin, TimestampMixin, SoftDeleteMixin, SQLModel, table=True):
    __tablename__ = "trusted_devices"

    user_id: UUID = Field(foreign_key="users.id")
    device_fingerprint_hash: str = Field(max_length=255)
    device_name: str | None = Field(default=None, max_length=255)
    platform: str | None = Field(default=None, max_length=100)
    last_ip_address: str | None = Field(default=None, max_length=45)
    last_seen_at: datetime = Field(  # type: ignore[call-overload]
        default_factory=lambda: datetime.now(UTC),
        sa_type=DateTime(timezone=True),
    )
    revoked_at: datetime | None = Field(  # type: ignore[call-overload]
        default=None, sa_type=DateTime(timezone=True), nullable=True
    )

    __table_args__ = (UniqueConstraint("user_id", "device_fingerprint_hash"),)


class LoginAttempt(UUIDMixin, TimestampMixin, SQLModel, table=True):
    __tablename__ = "login_attempts"

    user_id: UUID | None = Field(default=None, foreign_key="users.id", nullable=True)
    identifier: str = Field(max_length=255)
    success: bool = Field(default=False)
    failure_reason: str | None = Field(default=None, max_length=255)
    ip_address: str | None = Field(default=None, max_length=45)
    device_fingerprint_hash: str | None = Field(default=None, max_length=255)
    user_agent: str | None = Field(default=None, max_length=500)


class AuthRiskEvent(UUIDMixin, TimestampMixin, SQLModel, table=True):
    __tablename__ = "auth_risk_events"

    user_id: UUID | None = Field(default=None, foreign_key="users.id", nullable=True)
    session_id: UUID | None = Field(default=None, foreign_key="user_sessions.id", nullable=True)
    event_type: AuthEventType = Field(sa_type=String)
    risk_level: AuthRiskLevel = Field(sa_type=String)
    reason: str | None = Field(default=None, max_length=500)
    ip_address: str | None = Field(default=None, max_length=45)
    device_fingerprint_hash: str | None = Field(default=None, max_length=255)
