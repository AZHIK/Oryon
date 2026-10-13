"""Schemas for the WhatsApp Business connection."""

from __future__ import annotations

from pydantic import BaseModel, field_validator


class WhatsAppConnectionUpsert(BaseModel):
    """Operator-pasted credentials from the Meta dashboard."""

    phone_number_id: str
    display_phone_number: str | None = None
    access_token: str

    @field_validator("phone_number_id", "access_token")
    @classmethod
    def must_not_be_blank(cls, v: str) -> str:
        if not v.strip():
            raise ValueError("Must not be blank")
        return v.strip()


class WhatsAppConnectionRead(BaseModel):
    business_id: str
    phone_number_id: str
    display_phone_number: str | None = None
    status: str
    last_error: str | None = None
    token_preview: str | None = None
    # Returned (not redacted) so the operator can paste it into the Meta
    # dashboard webhook config alongside the webhook path below.
    verify_token: str
    webhook_path: str
    last_checked_at: str | None = None


class WhatsAppTestRead(BaseModel):
    status: str
    display_phone_number: str | None = None
    verified_name: str | None = None
    last_error: str | None = None
