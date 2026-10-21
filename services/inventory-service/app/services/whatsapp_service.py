"""WhatsApp Business Cloud API — connection management and webhooks.

Per-business credentials live in ``whatsappconnection`` (one row per
business). The access token is stored plaintext in this pass — same MVP
tradeoff as ``internal_service_token`` — move to a secret manager before
multi-tenant prod.

Staff send order messages via the wa.me deep link on the prepared payload
(manual send). Inbound: ``apply_status_callbacks`` moves ``sent →
delivered → read`` (or ``failed`` with provider detail) by ``wamid``;
``record_inbound_reply`` stores supplier replies and flags confirmation
keywords (EN + SW) for display — the PO itself is never auto-advanced.
"""

from __future__ import annotations

import hashlib
import hmac
import re
import secrets
from datetime import UTC, datetime
from typing import Any
from uuid import UUID

import httpx
import structlog
from sqlalchemy import desc
from sqlmodel import select
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.config import get_settings
from app.models.purchases import PurchaseOrder
from app.models.requisition import (
    MessageDirection,
    MessageStatus,
    SupplierMessage,
)
from app.models.suppliers import Supplier
from app.models.whatsapp import WhatsAppConnection, WhatsAppConnectionStatus

logger = structlog.get_logger(__name__)


class CloudApiError(Exception):
    """The Graph API rejected the call — surfaced to staff verbatim."""

    def __init__(self, message: str, status_code: int | None = None) -> None:
        super().__init__(message)
        self.status_code = status_code


class WhatsAppNotConnectedError(Exception):
    """No live connection for this business — UI should show Connect."""


class WhatsAppNoNumberError(Exception):
    """The supplier has no WhatsApp number — UI should show wa.me fallback."""


def graph_base() -> str:
    settings = get_settings()
    return f"{settings.whatsapp_graph_base_url.rstrip('/')}/{settings.whatsapp_graph_version}"


def normalize_recipient(raw: str | None) -> str | None:
    """Digits-only recipient for the Cloud API (E.164 without the ``+``)."""
    if not raw:
        return None
    digits = "".join(ch for ch in raw.strip() if ch.isdigit())
    if len(digits) < 7:
        return None
    return digits


def mask_token(token: str) -> str:
    """Last-4 preview for list screens — the full secret never leaves PUT."""
    tail = token[-4:] if len(token) >= 4 else token
    return f"…{tail}"


def generate_verify_token() -> str:
    return secrets.token_urlsafe(24)


async def fetch_phone_number(
    *,
    phone_number_id: str,
    access_token: str,
    client: httpx.AsyncClient | None = None,
) -> dict[str, Any]:
    """Live-check credentials: GET the sender number object from Graph."""
    url = f"{graph_base()}/{phone_number_id}"
    params = {"fields": "display_phone_number,verified_name,quality_rating"}
    headers = {"Authorization": f"Bearer {access_token}"}
    owns_client = client is None
    if client is None:
        client = httpx.AsyncClient(timeout=httpx.Timeout(30.0))
    try:
        response = await client.get(url, params=params, headers=headers)
    finally:
        if owns_client:
            await client.aclose()
    if response.status_code >= 400:
        detail: Any = None
        try:
            detail = response.json().get("error", {}).get("message")
        except Exception:  # noqa: BLE001
            detail = None
        raise CloudApiError(
            detail or f"WhatsApp API rejected the credentials (HTTP {response.status_code})",
            status_code=response.status_code,
        )
    data = response.json()
    if not isinstance(data, dict):
        raise CloudApiError("WhatsApp API returned an unexpected response")
    return data


async def get_connection(session: AsyncSession, *, business_id: UUID) -> WhatsAppConnection | None:
    return (
        await session.exec(
            select(WhatsAppConnection).where(WhatsAppConnection.business_id == business_id)
        )
    ).one_or_none()


async def upsert_connection(
    session: AsyncSession,
    *,
    business_id: UUID,
    phone_number_id: str,
    display_phone_number: str | None,
    access_token: str,
) -> WhatsAppConnection:
    """Store credentials (token replaced wholesale — never merged)."""
    existing = await get_connection(session, business_id=business_id)
    if existing is None:
        row = WhatsAppConnection(
            business_id=business_id,
            phone_number_id=phone_number_id.strip(),
            display_phone_number=(display_phone_number or None),
            access_token=access_token,
            verify_token=generate_verify_token(),
            status=WhatsAppConnectionStatus.DISCONNECTED,
        )
        session.add(row)
        await session.flush()
        return row
    existing.phone_number_id = phone_number_id.strip()
    if display_phone_number:
        existing.display_phone_number = display_phone_number
    existing.access_token = access_token
    existing.status = WhatsAppConnectionStatus.DISCONNECTED
    existing.last_error = None
    session.add(existing)
    await session.flush()
    return existing


async def mark_checked(
    session: AsyncSession,
    connection: WhatsAppConnection,
    *,
    ok: bool,
    error: str | None = None,
    display_phone_number: str | None = None,
) -> None:
    connection.status = (
        WhatsAppConnectionStatus.CONNECTED if ok else WhatsAppConnectionStatus.ERROR
    )
    connection.last_error = None if ok else error
    if display_phone_number:
        connection.display_phone_number = display_phone_number
    connection.last_checked_at = datetime.now(UTC)
    session.add(connection)


async def disconnect_connection(session: AsyncSession, connection: WhatsAppConnection) -> None:
    """Clear secrets, keep the row so the verify-token URL stays stable."""
    connection.access_token = ""
    connection.status = WhatsAppConnectionStatus.DISCONNECTED
    connection.last_error = None
    connection.last_checked_at = datetime.now(UTC)
    session.add(connection)


def connection_public_view(connection: WhatsAppConnection) -> dict[str, Any]:
    """Safe shape for GET — token preview only, verify token included so
    the operator can paste it into the Meta dashboard webhook config."""
    return {
        "business_id": str(connection.business_id),
        "phone_number_id": connection.phone_number_id,
        "display_phone_number": connection.display_phone_number,
        "status": connection.status.value,
        "last_error": connection.last_error,
        "token_preview": mask_token(connection.access_token) if connection.access_token else None,
        "verify_token": connection.verify_token,
        "webhook_path": "/api/v1/whatsapp/webhook",
        "last_checked_at": connection.last_checked_at.isoformat()
        if connection.last_checked_at
        else None,
    }


# ── Webhooks ──────────────────────────────────────────────────────────────

_META_TO_STATUS: dict[str, MessageStatus] = {
    "sent": MessageStatus.SENT,
    "delivered": MessageStatus.DELIVERED,
    "read": MessageStatus.READ,
    "failed": MessageStatus.FAILED,
    "deleted": MessageStatus.FAILED,
}


def verify_signature(raw_body: bytes, signature_header: str | None) -> bool:
    """Verify Meta's ``X-Hub-Signature-256`` header.

    Fails closed: if no app secret is configured, every inbound webhook is
    rejected. Production startup already refuses to boot without the secret
    (SEC-02); this also protects local/dev deployments from silently
    accepting forged callbacks.
    """
    secret = get_settings().whatsapp_app_secret
    if not secret:
        logger.error("whatsapp.webhook.no_app_secret")
        return False
    if not signature_header or not signature_header.startswith("sha256="):
        return False
    expected = hmac.new(secret.encode(), raw_body, hashlib.sha256).hexdigest()
    presented = signature_header.removeprefix("sha256=")
    return hmac.compare_digest(expected, presented)


async def apply_status_callbacks(
    session: AsyncSession, *, statuses: list[dict[str, Any]]
) -> list[dict[str, Any]]:
    """Join provider status callbacks to rows by ``wamid``."""
    applied: list[dict[str, Any]] = []
    for entry in statuses:
        wamid = entry.get("id")
        if not wamid:
            continue
        target = _META_TO_STATUS.get(str(entry.get("status", "")).lower())
        if target is None:
            continue
        row = (
            await session.exec(
                select(SupplierMessage).where(SupplierMessage.provider_message_id == str(wamid))
            )
        ).one_or_none()
        if row is None:
            logger.warning("whatsapp.status.unknown_wamid", wamid=str(wamid))
            continue
        row.status = target
        errors = entry.get("errors") or []
        if target == MessageStatus.FAILED and errors:
            row.last_error = str(errors[0].get("message") or errors[0].get("code") or "failed")
        if target in (MessageStatus.SENT, MessageStatus.DELIVERED) and row.sent_at is None:
            row.sent_at = datetime.now(UTC)
        session.add(row)
        applied.append({"provider_message_id": str(wamid), "status": target.value})
    await session.flush()
    return applied


def _digits(raw: str | None) -> str:
    return "".join(ch for ch in (raw or "") if ch.isdigit())


def _same_sender(a: str | None, b: str | None) -> bool:
    da, db = _digits(a), _digits(b)
    if not da or not db:
        return False
    if len(da) >= 9 and len(db) >= 9:
        return da[-9:] == db[-9:]
    return da == db


_CONFIRM_KEYWORDS = (
    "confirm",
    "confirmed",
    "approve",
    "approved",
    "ok",
    "okay",
    "yes",
    "sawa",
    "ndiyo",
    "ndio",
    "kubali",
    "nimepokea",
    "received",
    "noted",
)


def confirmation_detected(text: str | None) -> bool:
    """Keyword reply parser: does the supplier text read as a confirmation?

    Whole-word match (EN + SW) so "Sawa, confirmed!" hits while
    "Bei ni kubwa sana" does not.
    """
    normalized = (text or "").strip().lower()
    if not normalized:
        return False
    return re.search(
        r"\b(" + "|".join(re.escape(word) for word in _CONFIRM_KEYWORDS) + r")\b",
        normalized,
    ) is not None


async def record_inbound_reply(
    session: AsyncSession,
    *,
    connection: WhatsAppConnection,
    sender: str,
    text: str | None,
    provider_message_id: str | None,
) -> dict[str, Any]:
    """Store a supplier reply, linking the sender's latest PO when possible.

    Never advances the PO — returns ``confirmation_detected`` so the UI can
    prompt staff to "Mark Confirmed".
    """
    suppliers = (
        await session.exec(
            select(Supplier).where(
                Supplier.business_id == connection.business_id,
                Supplier.is_deleted == False,  # noqa: E712
            )
        )
    ).all()
    match = next(
        (
            s
            for s in suppliers
            if _same_sender(s.whatsapp_number, sender) or _same_sender(s.phone, sender)
        ),
        None,
    )
    po_id: UUID | None = None
    if match is not None:
        latest = (
            await session.exec(
                select(SupplierMessage)
                .where(
                    SupplierMessage.direction == MessageDirection.OUTBOUND,
                    SupplierMessage.po_id.in_(
                        select(PurchaseOrder.id).where(
                            PurchaseOrder.supplier_id == match.id,
                            PurchaseOrder.business_id == connection.business_id,
                        )
                    ),
                )
                .order_by(desc(SupplierMessage.created_at))
            )
        ).first()
        po_id = latest.po_id if latest is not None else None

    row = SupplierMessage(
        po_id=po_id,
        direction=MessageDirection.INBOUND,
        status=MessageStatus.RECEIVED,
        payload={
            "from": sender,
            "text": text,
            "provider_message_id": provider_message_id,
            "matched_supplier_id": str(match.id) if match is not None else None,
            "confirmation_detected": confirmation_detected(text),
        },
    )
    session.add(row)
    await session.flush()
    logger.info(
        "whatsapp.inbound",
        business_id=str(connection.business_id),
        matched=match is not None,
    )
    return {
        "id": str(row.id),
        "po_id": str(po_id) if po_id is not None else None,
        "matched_supplier_id": str(match.id) if match is not None else None,
        "confirmation_detected": confirmation_detected(text),
    }
