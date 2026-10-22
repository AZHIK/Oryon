"""Application settings via pydantic-settings.

All environment variables are loaded through this class.
Use `get_settings()` (cached) rather than instantiating directly.
"""

from __future__ import annotations

import os
from decimal import Decimal
from functools import lru_cache
from typing import Literal
from urllib.parse import urlsplit

from pydantic import model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        # Docker secrets are read from /run/secrets when present. Filenames
        # must match field names (db_url, internal_service_token, ...).
        secrets_dir="/run/secrets" if os.path.isdir("/run/secrets") else None,
    )

    # ── App ────────────────────────────────────
    service_name: str = "pos-service"
    environment: Literal["local", "dev", "staging", "prod"] = "local"
    debug: bool = True
    log_level: str = "DEBUG"

    # ── Database ───────────────────────────────
    db_url: str = "postgresql+asyncpg://oryonfoods:oryonfoods@localhost:5432/oryonfoods_pos"

    # ── JWT (verification only — no private key in this service) ──
    jwt_public_key_path: str = "keys/public.pem"
    jwt_algorithm: str = "RS256"
    # Required in prod; optional locally so existing local tokens still work.
    jwt_issuer: str | None = None
    jwt_audience: str | None = None
    jwt_key_id: str | None = None
    jwt_public_key: str | None = None

    # ── RabbitMQ ───────────────────────────────
    # Unused for now — see app/core/events.py. publish_event currently makes
    # a direct synchronous HTTP call to Inventory Service instead (MVP,
    # avoids standing up a broker); these settings stay defined so the
    # eventual broker migration doesn't need a new settings section.
    rabbitmq_url: str = "amqp://guest:guest@localhost:5672/"
    events_exchange: str = "oryonfoods.events"

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
    receipt_storage_root: str = "/var/lib/oryonfoods/receipts"
    receipt_max_bytes: int = 5 * 1024 * 1024

    # ── Host ───────────────────────────────────
    host: str = "0.0.0.0"
    port: int = 8200

    @model_validator(mode="after")
    def _reject_insecure_production_settings(self) -> Settings:
        """Fail closed when ENVIRONMENT=prod still carries development defaults."""
        if self.environment != "prod":
            return self

        errors: list[str] = []

        if self.debug:
            errors.append("DEBUG must be false in production")
        if self.log_level.upper() == "DEBUG":
            errors.append("LOG_LEVEL must not be DEBUG in production")

        if "oryonfoods:oryonfoods@" in self.db_url:
            errors.append("DB_URL still uses the default oryonfoods/oryonfoods credentials")

        if self.internal_service_token == "change-me-internal-token":
            errors.append("INTERNAL_SERVICE_TOKEN still uses the default value")
        elif len(self.internal_service_token) < 32:
            errors.append("INTERNAL_SERVICE_TOKEN must be at least 32 characters")

        if not self.jwt_issuer:
            errors.append("JWT_ISSUER is required in production")
        if not self.jwt_audience:
            errors.append("JWT_AUDIENCE is required in production")
        if not self.jwt_key_id:
            errors.append("JWT_KEY_ID is required in production")

        for setting_name, url in (
            ("INVENTORY_SERVICE_URL", self.inventory_service_url),
            ("IDENTITY_SERVICE_URL", self.identity_service_url),
        ):
            host = urlsplit(url).hostname or ""
            if host in {"", "localhost", "127.0.0.1", "::1"}:
                errors.append(f"{setting_name} must point at the production service, not localhost")

        origins = [
            origin.strip() for origin in self.cors_allowed_origins.split(",") if origin.strip()
        ]
        if "*" in origins:
            errors.append("CORS_ALLOWED_ORIGINS must not contain '*' in production")
        if any("localhost" in origin or "127.0.0.1" in origin for origin in origins):
            errors.append("CORS_ALLOWED_ORIGINS must not contain localhost origins in production")

        if errors:
            raise ValueError("Insecure production configuration:\n  - " + "\n  - ".join(errors))
        return self


@lru_cache
def get_settings() -> Settings:
    """Return a cached, immutable Settings singleton."""
    return Settings()
