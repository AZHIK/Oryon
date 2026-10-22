"""FastAPI application factory for Oryon Foods Inventory Service."""

from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.v1.endpoints import categories as categories_endpoints
from app.api.v1.endpoints import item_images as item_images_endpoints
from app.api.v1.endpoints import items as items_endpoints
from app.api.v1.endpoints import production as production_endpoints
from app.api.v1.endpoints import purchases as purchases_endpoints
from app.api.v1.endpoints import recipes as recipes_endpoints
from app.api.v1.endpoints import reorders as reorders_endpoints
from app.api.v1.endpoints import requisitions as requisitions_endpoints
from app.api.v1.endpoints import runs as runs_endpoints
from app.api.v1.endpoints import suppliers as suppliers_endpoints
from app.api.v1.endpoints import units as units_endpoints
from app.api.v1.endpoints import whatsapp as whatsapp_endpoints
from app.api.v1.endpoints.internal_events import router as internal_events_router
from app.api.v1.endpoints.operations import business_router
from app.api.v1.endpoints.operations import items_router as ops_items_router
from app.api.v1.endpoints.reports import router as reports_router
from app.core.config import get_settings
from app.core.logging import configure_logging
from app.core.telemetry import configure_telemetry
from app.routers import health

settings = get_settings()


@asynccontextmanager
async def lifespan(_app: FastAPI) -> AsyncIterator[None]:
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

origins = [o.strip() for o in settings.cors_allowed_origins.split(",") if o.strip()]
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(health.router, prefix="")
app.include_router(items_endpoints.router, prefix="/api/v1")
app.include_router(item_images_endpoints.router, prefix="/api/v1")
app.include_router(ops_items_router, prefix="/api/v1")
app.include_router(business_router, prefix="/api/v1")
app.include_router(reports_router, prefix="/api/v1")
app.include_router(suppliers_endpoints.router, prefix="/api/v1")
app.include_router(purchases_endpoints.router, prefix="/api/v1")
app.include_router(requisitions_endpoints.router, prefix="/api/v1")
app.include_router(requisitions_endpoints.catalogue_router, prefix="/api/v1")
app.include_router(whatsapp_endpoints.router, prefix="/api/v1")
app.include_router(whatsapp_endpoints.webhook_router, prefix="/api/v1")
app.include_router(reorders_endpoints.router, prefix="/api/v1")
app.include_router(recipes_endpoints.router, prefix="/api/v1")
app.include_router(production_endpoints.produce_router, prefix="/api/v1")
app.include_router(production_endpoints.history_router, prefix="/api/v1")
app.include_router(runs_endpoints.router, prefix="/api/v1")
app.include_router(categories_endpoints.router, prefix="/api/v1")
app.include_router(units_endpoints.router, prefix="/api/v1")
app.include_router(internal_events_router, prefix="/api/v1")
