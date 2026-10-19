"""Per-store tax lookup for sales (tax switch, default off).

Reads the store's ``tax_enabled`` / ``tax_rate`` from Identity Service's
store-settings endpoint, forwarding the caller's own JWT (the caller
already passed this service's auth, so Identity can authorize the read).

Rules (simple):
- tax off / rate missing / Identity unreachable  ->  tax 0 (never blocks a sale)
- tax on  ->  subtotal * rate

Results are cached briefly (TTL) so a sync batch with many stores does
one Identity call per store, and an Identity outage degrades to tax 0
instead of failing sales.
"""

from __future__ import annotations

import time
from decimal import Decimal
from uuid import UUID

import httpx
import structlog

from app.core.config import get_settings

logger = structlog.get_logger(__name__)

_CACHE_TTL_SECONDS = 60.0
_cache: dict[str, tuple[float, bool, Decimal]] = {}


def clear_tax_cache() -> None:
    """Drop cached tax lookups (tests)."""
    _cache.clear()


async def get_store_tax(
    business_id: UUID,
    store_id: UUID,
    authorization: str | None,
) -> tuple[bool, Decimal]:
    """Return ``(tax_enabled, tax_rate)`` for a store.

    ``tax_rate`` is a fraction (0.18 = 18%). Never raises — any failure
    (no token, Identity down, bad payload) means tax off (rate 0), so a
    tax-config problem can never block revenue.
    """
    key = f"{business_id}:{store_id}"
    now = time.monotonic()
    hit = _cache.get(key)
    if hit is not None and now - hit[0] < _CACHE_TTL_SECONDS:
        return hit[1], hit[2]

    enabled, rate = await _fetch_store_tax(business_id, store_id, authorization)
    _cache[key] = (now, enabled, rate)
    return enabled, rate


async def _fetch_store_tax(
    business_id: UUID,
    store_id: UUID,
    authorization: str | None,
) -> tuple[bool, Decimal]:
    settings = get_settings()
    if not authorization:
        return False, settings.default_tax_rate
    url = (
        f"{settings.identity_service_url}/businesses/{business_id}"
        f"/stores/{store_id}/settings"
    )
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            response = await client.get(url, headers={"Authorization": authorization})
        if response.status_code >= 400:
            logger.warning(
                "store_tax_lookup_failed",
                business_id=str(business_id),
                store_id=str(store_id),
                status_code=response.status_code,
            )
            return False, settings.default_tax_rate
        data = response.json()
    except httpx.HTTPError as exc:
        logger.warning(
            "store_tax_lookup_error",
            business_id=str(business_id),
            store_id=str(store_id),
            error=str(exc),
        )
        return False, settings.default_tax_rate

    try:
        enabled = bool(data.get("tax_enabled", False))
        raw_rate = data.get("tax_rate", 0) or 0
        rate = Decimal(str(raw_rate))
        if rate < Decimal("0") or rate > Decimal("1"):
            logger.warning("store_tax_rate_out_of_range", rate=str(rate))
            return False, Decimal("0")
    except Exception as exc:
        logger.warning("store_tax_parse_failed", error=str(exc))
        return False, settings.default_tax_rate
    if not enabled:
        return False, Decimal("0")
    return True, rate
