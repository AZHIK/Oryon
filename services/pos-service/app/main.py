"""FastAPI application factory for Oryon Foods POS Service."""

from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.v1.endpoints import (
    couriers,
    customers,
    finance_attachments,
    other_expenses,
    other_incomes,
    reports,
    sales,
    void_refund,
)
from app.core.config import get_settings
from app.core.logging import configure_logging
from app.core.telemetry import configure_telemetry
from app.routers import health

settings = get_settings()


@asynccontextmanager
async def lifespan(_app: FastAPI) -> AsyncIterator[None]:
    """Application lifespan — configure logging and telemetry on startup."""
    configure_logging()
    configure_telemetry()
    try:
        yield
    finally:
        pass


app = FastAPI(
    title=settings.service_name,
    version="0.1.0",
    lifespan=lifespan,
    docs_url="/docs" if settings.environment != "prod" else None,
    redoc_url="/redoc" if settings.environment != "prod" else None,
)

# ── CORS — locked to explicit origins from config, NEVER a wildcard ──────
origins = [o.strip() for o in settings.cors_allowed_origins.split(",") if o.strip()]
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Routes ───────────────────────────────────────────────────────────────
# health stays unprefixed; every real API route is mounted under /api/v1,
# matching identity-service and inventory-service's convention.
app.include_router(health.router, prefix="")
app.include_router(sales.router, prefix="/api/v1")
app.include_router(couriers.router, prefix="/api/v1")
app.include_router(reports.router, prefix="/api/v1")
app.include_router(void_refund.router, prefix="/api/v1")
app.include_router(other_expenses.router, prefix="/api/v1")
app.include_router(other_incomes.router, prefix="/api/v1")
app.include_router(finance_attachments.router, prefix="/api/v1")
app.include_router(customers.router, prefix="/api/v1")
