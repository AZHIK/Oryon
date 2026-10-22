"""Health-check endpoints — liveness probe.

- GET /health : liveness — always returns 200 if the process is alive.
"""

import structlog
from fastapi import APIRouter

from app.schemas.health import HealthResponse

logger = structlog.get_logger(__name__)
router = APIRouter(tags=["health"])


@router.get("/health", response_model=HealthResponse)
async def health() -> HealthResponse:
    return HealthResponse()
