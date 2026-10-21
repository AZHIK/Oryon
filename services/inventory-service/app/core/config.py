"""Application settings via pydantic-settings.

All environment variables are loaded through this class.
Use `get_settings()` (cached) rather than instantiating directly.
"""

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
    service_name: str = "inventory-service"
    environment: Literal["local", "dev", "staging", "prod"] = "local"
    debug: bool = True
    log_level: str = "DEBUG"

    # ── Database ───────────────────────────────
    db_url: str = "postgresql+asyncpg://oryonfoods:oryonfoods@localhost:5432/oryonfoods_inventory"

    # Genuinely separate test database.  When set (TEST_DB_URL env var), the
    # app engine AND Alembic target this database instead of db_url.  The test
    # suite sets it so tests never touch the dev database.
    test_db_url: str | None = None

    # ── JWT (verification only — no private key in this service) ──
    jwt_public_key_path: str = "keys/public.pem"
    jwt_algorithm: str = "RS256"
    jwt_public_key: str | None = None

    # ── RabbitMQ ───────────────────────────────
    # Unused for now — see app/api/v1/endpoints/internal_events.py. POS
    # Service currently calls that endpoint directly over HTTP (MVP,
    # avoids standing up a broker) instead of publishing to a queue.
    rabbitmq_url: str = "amqp://guest:guest@localhost:5672/"
    events_exchange: str = "oryonfoods.events"

    # ── Inter-service events (MVP transport: synchronous HTTP) ────
    # Shared secret for service-to-service calls (e.g. POS Service's
    # publish_event) — must match the caller's own internal_service_token
    # setting exactly. Not an end-user JWT; checked by
    # app.deps.auth.require_internal_service_token.
    internal_service_token: str = "change-me-internal-token"

    # ── CORS ────────────────────────────────────
    cors_allowed_origins: str = "http://localhost:3000"

    # ── Host ───────────────────────────────────
    host: str = "0.0.0.0"
    port: int = 8100

    # ── Item product photos ──────────────────────
    # Local-disk storage for item image uploads (see
    # ``app/services/item_image_storage.py``) — same MVP tradeoff as POS
    # Service's receipt storage: no cloud bucket exists in this repo yet, so
    # files live on a mounted volume. Single-node only; the volume must be
    # part of the backup story alongside the Postgres dump.
    item_image_storage_root: str = "/var/lib/oryonfoods/item_images"
    # Matches the "up to 5 MB" hint the app's image picker shows.
    item_image_max_bytes: int = 5 * 1024 * 1024

    # ── WhatsApp Business Cloud API ──────────────
    # Outbound PO sends POST to {graph_base_url}/{graph_version}/
    # {phone_number_id}/messages with the connection's access token.
    whatsapp_graph_base_url: str = "https://graph.facebook.com"
    whatsapp_graph_version: str = "v21.0"
    # Optional Meta App Secret — when set, inbound webhooks must carry a
    # valid X-Hub-Signature-256 header; when unset the per-business
    # verify-token query param is the only check (fine for MVP).
    whatsapp_app_secret: str | None = None
    # Optional global fallback for webhook GET verification when the caller
    # does not supply a per-business ?business_id=…&t=… pair.
    whatsapp_webhook_verify_token: str | None = None
    # Public base URL of this service (e.g. https://api.example.com) used
    # to render the per-business webhook URL shown in Settings. When unset
    # the app composes the path itself.
    public_base_url: str | None = None


@lru_cache
def get_settings() -> Settings:
    """Return a cached, immutable Settings singleton."""
    return Settings()
