"""Event publishing and subscribing interface stubs.

Wired to RabbitMQ in a later stage.  For now, events are logged.
"""

from typing import Any

import structlog

logger = structlog.get_logger(__name__)


async def publish_event(event_name: str, payload: dict[str, Any]) -> None:
    """Publish an event to the shared event bus.

    Currently logs the event.  Will be wired to RabbitMQ producer in a later stage.
    """
    logger.info("event_published", event_name=event_name, payload=payload)


async def subscribe_event(event_name: str, handler: Any) -> None:  # noqa: ARG001
    """Register a handler for an incoming event.

    This is a stub — the function signature defines the interface that will
    be wired to a real RabbitMQ consumer in a later stage.  At that point,
    this function will bind *handler* to the queue bound to *event_name*.
    """
    logger.info("event_subscriber_stub", event_name=event_name)
