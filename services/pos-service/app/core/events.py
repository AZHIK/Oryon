"""Event publishing and subscribing interface.

MVP transport: a synchronous HTTP call from this service directly to
Inventory Service's internal event-ingestion endpoint, instead of a message
broker. No RabbitMQ (or any) broker exists anywhere in this repo yet, and
Inventory Service's consumer-side handlers (``handle_sale_completed`` etc.,
see ``services/inventory-service/app/services/event_handlers.py``) are
already written and tested — this just gives them a call site.

``publish_event`` MUST NOT let a failure here affect the caller. A sale is
the source of truth for revenue and must sync successfully even if
Inventory Service is unreachable, slow, or returns an error — the stock
deduction is a best-effort side effect, not a precondition. Every exception
is caught and logged, never re-raised.

Swapping this for a real broker later only means changing this function's
body — ``sale_service.py``'s call sites and the payload shape stay the same.
"""

from typing import Any

import httpx
import structlog

from app.core.config import get_settings

logger = structlog.get_logger(__name__)

# event_name -> path segment used by Inventory Service's internal endpoint.
_EVENT_TYPES = {"sale.completed", "sale.voided", "sale.refunded"}


async def publish_event(event_name: str, payload: dict[str, Any]) -> None:
    """Publish an event to the shared event bus.

    Stock-affecting events (``sale.completed``/``sale.voided``/
    ``sale.refunded``) are forwarded to Inventory Service's internal
    stock-events endpoint. Anything else (e.g. ``audit.recorded``) is only
    logged for now — no consumer exists yet for non-stock events.

    Never raises: a failure here is logged and swallowed so it can never
    roll back or block the sale/void/refund that triggered it.
    """
    logger.info("event_published", event_name=event_name, payload=payload)

    if event_name not in _EVENT_TYPES:
        return

    settings = get_settings()
    business_id = payload.get("business_id")
    if not business_id:
        logger.warning("event_publish_skipped_no_business_id", event_name=event_name)
        return

    url = f"{settings.inventory_service_url}/internal/businesses/{business_id}/stock-events"
    body = {"event_type": event_name, **payload}

    try:
        async with httpx.AsyncClient(timeout=settings.internal_event_timeout_seconds) as client:
            response = await client.post(
                url,
                json=body,
                headers={"X-Internal-Service-Token": settings.internal_service_token},
            )
        if response.status_code >= 400:
            logger.warning(
                "stock_event_publish_failed",
                event_name=event_name,
                status_code=response.status_code,
                body=response.text,
            )
        else:
            logger.info(
                "stock_event_published",
                event_name=event_name,
                results=response.json().get("results"),
            )
    except httpx.HTTPError as exc:
        # Connection errors, timeouts, etc. — Inventory Service being down
        # must never affect this sale's own sync result.
        logger.warning("stock_event_publish_error", event_name=event_name, error=str(exc))


async def subscribe_event(event_name: str, handler: Any) -> None:  # noqa: ARG001
    """Register a handler for an incoming event.

    This is a stub — the function signature defines the interface that will
    be wired to a real RabbitMQ consumer in a later stage. At that point,
    this function will bind *handler* to the queue bound to *event_name*.
    """
    logger.info("event_subscriber_stub", event_name=event_name)
