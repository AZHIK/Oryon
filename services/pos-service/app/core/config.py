"""Application settings via pydantic-settings.

All environment variables are loaded through this class.
Use `get_settings()` (cached) rather than instantiating directly.
"""

from __future__ import annotations

from decimal import Decimal
from functools import lru_cache
from typing import Literal

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
    )

    # ── App ────────────────────────────────────
    service_name: str = "pos-service"
    environment: Literal["local", "dev", "staging", "prod"] = "local"
    debug: bool = True
    log_level: str = "DEBUG"

    # ── Database ───────────────────────────────
    db_url: str = "postgresql+asyncpg://foodlink:foodlink@localhost:5432/foodlink_pos"

    # ── JWT (verification only — no private key in this service) ──
    jwt_public_key_path: str = "keys/public.pem"
    jwt_algorithm: str = "RS256"
    jwt_public_key: str | None = None

    # ── RabbitMQ ───────────────────────────────
    # Unused for now — see app/core/events.py. publish_event currently makes
    # a direct synchronous HTTP call to Inventory Service instead (MVP,
    # avoids standing up a broker); these settings stay defined so the
    # eventual broker migration doesn't need a new settings section.
    rabbitmq_url: str = "amqp://guest:guest@localhost:5672/"
    events_exchange: str = "foodlink.events"

    # ── Inter-service events (MVP transport: synchronous HTTP) ────
    # Where publish_event posts stock-affecting events (sale.completed,
    # sale.voided, sale.refunded). internal_service_token must match
    # Inventory Service's own INTERNAL_SERVICE_TOKEN setting exactly — this
    # is a shared secret for service-to-service calls, not an end-user JWT.
    inventory_service_url: str = "http://localhost:8100/api/v1"
    internal_service_token: str = "change-me-internal-token"
    internal_event_timeout_seconds: float = 5.0

    # ── Identity (per-store tax switch) ──────────
    # Where to read each store's tax_enabled/tax_rate. The caller's own
    # JWT is forwarded, so no service token is needed.
    identity_service_url: str = "http://localhost:8009/api/v1"

    # ── CORS ────────────────────────────────────
    cors_allowed_origins: str = "http://localhost:3000"

    # ── POS-specific ────────────────────────────
    # Time-drift detection thresholds (logic added in a later stage, config
    # centralized here from the start to avoid retrofitting).
    time_drift_suspect_threshold_hours: int = 48
    time_drift_future_tolerance_minutes: int = 5

    # Local tax configuration — kept in POS Service for MVP rather than
    # touching Identity Service's businesses table.
    # Fallback only: per-store tax_enabled/tax_rate from Identity (see
    # app/services/tax_policy.py) wins when reachable. Default 0 = off.
    default_tax_rate: Decimal = Decimal("0")

    # ── Receipt storage ─────────────────────────
    # Local-disk storage for finance receipt uploads (see
    # app/services/receipt_storage.py). No cloud infra exists yet; this is
    # deliberately behind a swappable protocol so an S3/MinIO backend can
    # replace it later without touching call sites. NOTE: local disk pins
    # this service to a single node — revisit before horizontal scaling,
    # and make sure this volume is included in the backup story.
    receipt_storage_root: str = "/var/lib/foodlink/receipts"
    receipt_max_bytes: int = 5 * 1024 * 1024

    # ── Host ───────────────────────────────────
    host: str = "0.0.0.0"
    port: int = 8200


@lru_cache
def get_settings() -> Settings:
    """Return a cached, immutable Settings singleton."""
    return Settings()
