"""WhatsApp Business Cloud API endpoints — connection + webhooks.

┌──────────────────────────────────────────────────────────────────────────┐
│ PERMISSION MODEL                                                         │
│                                                                          │
│   GET    /whatsapp/connection        → PROCUREMENT_VIEW                   │
│   PUT    /whatsapp/connection        → PROCUREMENT_CREATE (store+verify)  │
│   DELETE /whatsapp/connection        → PROCUREMENT_CREATE                 │
│   POST   /whatsapp/connection/test   → PROCUREMENT_CREATE                │
│   GET/POST /whatsapp/webhook         → NO JWT (Meta calls these; GET is    │
│     guarded by the per-business verify token, POST by the optional       │
│     X-Hub-Signature-256 app-secret check + verify-token scoping)          │
└──────────────────────────────────────────────────────────────────────────┘

PUT stores the operator-pasted credentials AND live-verifies them against
Graph in the same call, so "Connect" either reports ``connected`` or the
provider's own error — never a silent store of dead credentials.

Staff send order messages via the wa.me deep link on the prepared payload
(manual send); there is no Cloud API per-PO send and no PO send lifecycle.
Incoming webhooks still advance message delivery states and store supplier
replies.
"""

from __future__ import annotations

import secrets
from typing import Annotated, Any
from uuid import UUID

import structlog
from fastapi import APIRouter, Depends, HTTPException, Query, Request, Response, status
from sqlmodel import select
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.config import get_settings
from app.core.database import get_db
from app.deps.auth import require_business_permission
from app.models.whatsapp import WhatsAppConnection
from app.schemas.whatsapp import (
    WhatsAppConnectionRead,
    WhatsAppConnectionUpsert,
    WhatsAppTestRead,
)
from app.services import whatsapp_service
from app.services.whatsapp_service import CloudApiError

logger = structlog.get_logger(__name__)
router = APIRouter(prefix="/businesses/{business_id}/whatsapp", tags=["whatsapp"])
webhook_router = APIRouter(prefix="/whatsapp", tags=["whatsapp-webhook"])


def _read_model(connection: WhatsAppConnection) -> WhatsAppConnectionRead:
    return WhatsAppConnectionRead(**whatsapp_service.connection_public_view(connection))


@router.get("/connection", response_model=WhatsAppConnectionRead)
async def get_whatsapp_connection(
    business_id: UUID,
    session: Annotated[AsyncSession, Depends(get_db)],
    _jwt_biz_id: Annotated[str, Depends(require_business_permission("procurement.view"))],
) -> WhatsAppConnectionRead:
    connection = await whatsapp_service.get_connection(session, business_id=business_id)
    if connection is None or not connection.access_token:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="WhatsApp is not connected for this business",
        )
    return _read_model(connection)


@router.put("/connection", response_model=WhatsAppConnectionRead)
async def connect_whatsapp(
    business_id: UUID,
    body: WhatsAppConnectionUpsert,
    session: Annotated[AsyncSession, Depends(get_db)],
    _jwt_biz_id: Annotated[str, Depends(require_business_permission("procurement.create"))],
) -> WhatsAppConnectionRead:
    connection = await whatsapp_service.upsert_connection(
        session,
        business_id=business_id,
        phone_number_id=body.phone_number_id,
        display_phone_number=body.display_phone_number,
        access_token=body.access_token,
    )
    try:
        info = await whatsapp_service.fetch_phone_number(
            phone_number_id=connection.phone_number_id,
            access_token=connection.access_token,
        )
    except CloudApiError as exc:
        await whatsapp_service.mark_checked(session, connection, ok=False, error=str(exc))
        await session.commit()
        await session.refresh(connection)
        logger.warning("whatsapp.connect_failed", business_id=str(business_id), error=str(exc))
        return _read_model(connection)
    await whatsapp_service.mark_checked(
        session,
        connection,
        ok=True,
        display_phone_number=info.get("display_phone_number"),
    )
    await session.commit()
    await session.refresh(connection)
    logger.info("whatsapp.connected", business_id=str(business_id))
    return _read_model(connection)


@router.delete("/connection", response_model=WhatsAppConnectionRead)
async def disconnect_whatsapp(
    business_id: UUID,
    session: Annotated[AsyncSession, Depends(get_db)],
    _jwt_biz_id: Annotated[str, Depends(require_business_permission("procurement.create"))],
) -> WhatsAppConnectionRead:
    connection = await whatsapp_service.get_connection(session, business_id=business_id)
    if connection is None or not connection.access_token:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="WhatsApp is not connected for this business",
        )
    await whatsapp_service.disconnect_connection(session, connection)
    await session.commit()
    await session.refresh(connection)
    logger.info("whatsapp.disconnected", business_id=str(business_id))
    return _read_model(connection)


@router.post("/connection/test", response_model=WhatsAppTestRead)
async def test_whatsapp_connection(
    business_id: UUID,
    session: Annotated[AsyncSession, Depends(get_db)],
    _jwt_biz_id: Annotated[str, Depends(require_business_permission("procurement.create"))],
) -> WhatsAppTestRead:
    connection = await whatsapp_service.get_connection(session, business_id=business_id)
    if connection is None or not connection.access_token:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="WhatsApp is not connected for this business",
        )
    try:
        info = await whatsapp_service.fetch_phone_number(
            phone_number_id=connection.phone_number_id,
            access_token=connection.access_token,
        )
    except CloudApiError as exc:
        await whatsapp_service.mark_checked(session, connection, ok=False, error=str(exc))
        await session.commit()
        return WhatsAppTestRead(status="error", last_error=str(exc))
    await whatsapp_service.mark_checked(
        session,
        connection,
        ok=True,
        display_phone_number=info.get("display_phone_number"),
    )
    await session.commit()
    return WhatsAppTestRead(
        status="connected",
        display_phone_number=info.get("display_phone_number"),
        verified_name=info.get("verified_name"),
    )


# ── Webhooks (Meta → us; no JWT) ──────────────────────────────────────────


@webhook_router.get("/webhook")
async def verify_webhook(
    session: Annotated[AsyncSession, Depends(get_db)],
    hub_mode: Annotated[str | None, Query(alias="hub.mode")] = None,
    hub_verify_token: Annotated[str | None, Query(alias="hub.verify_token")] = None,
    hub_challenge: Annotated[str | None, Query(alias="hub.challenge")] = None,
    business_id: Annotated[UUID | None, Query()] = None,
    t: Annotated[str | None, Query()] = None,
) -> Response:
    """Meta's webhook verification handshake.

    Per-business URL form (shown in Settings):
    ``/api/v1/whatsapp/webhook?business_id=<bid>&t=<verify_token>`` —
    ``hub.verify_token`` must equal the connection's ``verify_token`` (the
    ``t`` pass-through is accepted too since Meta echoes our query string).
    Without ``business_id``, falls back to the global
    ``WHATSAPP_WEBHOOK_VERIFY_TOKEN`` setting.
    """
    if hub_mode != "subscribe" or not hub_challenge:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Bad verify request")
    ok = False
    if business_id is not None:
        connection = (
            await session.exec(
                select(WhatsAppConnection).where(WhatsAppConnection.business_id == business_id)
            )
        ).one_or_none()
        presented = hub_verify_token or t
        ok = bool(
            connection is not None
            and presented
            and secrets.compare_digest(presented, connection.verify_token)
        )
    else:
        expected = get_settings().whatsapp_webhook_verify_token
        ok = bool(
            expected and hub_verify_token and secrets.compare_digest(hub_verify_token, expected)
        )
    if not ok:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Verify token mismatch")
    return Response(content=hub_challenge, media_type="text/plain")


@webhook_router.post("/webhook")
async def receive_webhook(
    request: Request,
    session: Annotated[AsyncSession, Depends(get_db)],
) -> dict[str, Any]:
    """Inbound Cloud API callbacks: delivery statuses + supplier replies."""
    raw = await request.body()
    if not whatsapp_service.verify_signature(raw, request.headers.get("X-Hub-Signature-256")):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Bad webhook signature"
        )
    try:
        payload = await request.json()
    except Exception as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid JSON") from exc

    statuses: list[dict[str, Any]] = []
    replies: list[dict[str, Any]] = []
    for entry in payload.get("entry", []) or []:
        for change in entry.get("changes", []) or []:
            value = change.get("value", {}) or {}
            for item in value.get("statuses", []) or []:
                if isinstance(item, dict):
                    statuses.append(item)
            messages = value.get("messages", []) or []
            metadata = value.get("metadata", {}) or {}
            if not messages:
                continue
            connection = (
                await session.exec(
                    select(WhatsAppConnection).where(
                        WhatsAppConnection.phone_number_id == str(metadata.get("phone_number_id"))
                    )
                )
            ).one_or_none()
            if connection is None:
                logger.warning(
                    "whatsapp.webhook.unknown_number",
                    phone_number_id=str(metadata.get("phone_number_id")),
                )
                continue
            for msg in messages:
                if not isinstance(msg, dict):
                    continue
                text_body: str | None = None
                if isinstance(msg.get("text"), dict):
                    text_body = msg["text"].get("body")
                replies.append(
                    await whatsapp_service.record_inbound_reply(
                        session,
                        connection=connection,
                        sender=str(msg.get("from", "")),
                        text=text_body,
                        provider_message_id=msg.get("id"),
                    )
                )
    applied: list[dict[str, Any]] = []
    if statuses:
        applied = await whatsapp_service.apply_status_callbacks(session, statuses=statuses)
    await session.commit()
    return {"received": True, "statuses_applied": applied, "replies": replies}
