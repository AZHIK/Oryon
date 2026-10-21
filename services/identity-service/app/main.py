"""FastAPI application factory for Oryon Foods Auth Service."""

from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.v1.endpoints import auth, business_rbac, businesses, me, platform_auth, stores
from app.api.v1.endpoints.admin import internal_rbac, users
from app.core.config import get_settings
from app.core.logging import configure_logging
from app.core.redis_client import close_redis
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
        await close_redis()


app = FastAPI(
    title=settings.app_name,
    version="0.1.0",
    lifespan=lifespan,
    docs_url="/docs" if settings.environment != "prod" else None,
    redoc_url="/redoc" if settings.environment != "prod" else None,
)

# CORS — locked to explicit origins from config.
# The wildcard "*" is intentionally avoided.  Set CORS_ALLOWED_ORIGINS in
# the environment to the comma-separated list of origins that need access
# (e.g. http://localhost:3000,https://admin.oryonfoods.com).  The Flutter app
# origin must be included here if Flutter makes direct browser-based
# requests (otherwise Flutter uses native HTTP which is not subject to CORS).
origins = [o.strip() for o in settings.cors_allowed_origins.split(",") if o.strip()]
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(health.router, prefix="")
app.include_router(auth.router)
app.include_router(platform_auth.router)
app.include_router(businesses.router)
app.include_router(business_rbac.router)
app.include_router(users.router)
app.include_router(internal_rbac.router)
app.include_router(me.router)
app.include_router(stores.router)
