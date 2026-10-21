"""Health-check endpoints — liveness and readiness probes.

- GET /health        : liveness — always returns 200 if the process is alive.
- GET /health/ready  : readiness — returns 200 only when DB and Redis respond.

Readiness is cached for a few seconds and reuses the application's shared
Redis client. Creating a new Redis connection per probe allowed an
unauthenticated caller to exhaust connections (SEC-13). The deployment edge
should additionally deny public access to this path and keep `/health` as the
only internet-reachable probe.
"""

import time

import structlog
from fastapi import APIRouter
from sqlmodel import select

from app.core.database import async_session_factory
from app.core.redis_client import get_redis
from app.schemas.health import HealthResponse, ReadinessResponse

logger = structlog.get_logger(__name__)
router = APIRouter(tags=["health"])

_READINESS_CACHE_TTL_SECONDS = 5.0
_readiness_cached_at = 0.0
_readiness_cached: ReadinessResponse | None = None


@router.get("/health", response_model=HealthResponse)
async def health() -> HealthResponse:
    return HealthResponse()


@router.get("/health/ready", response_model=ReadinessResponse)
async def readiness() -> ReadinessResponse:
    global _readiness_cached, _readiness_cached_at

    now = time.monotonic()
    if (
        _readiness_cached is not None
        and now - _readiness_cached_at < _READINESS_CACHE_TTL_SECONDS
    ):
        return _readiness_cached

    db_status = "unknown"
    redis_status = "unknown"

    # Check database connectivity
    try:
        async with async_session_factory() as session:
            await session.exec(select(1))
            db_status = "healthy"
    except Exception as exc:
        logger.warning("readiness_check_db_failed", error=str(exc))
        db_status = "unhealthy"

    # Check Redis connectivity using the one shared client.
    try:
        redis_client = await get_redis()
        await redis_client.ping()
        redis_status = "healthy"
    except Exception as exc:
        logger.warning("readiness_check_redis_failed", error=str(exc))
        redis_status = "unhealthy"

    overall = (
        "healthy" if db_status == "healthy" and redis_status == "healthy" else "unhealthy"
    )
    result = ReadinessResponse(status=overall, database=db_status, redis=redis_status)
    _readiness_cached = result
    _readiness_cached_at = now
    return result
