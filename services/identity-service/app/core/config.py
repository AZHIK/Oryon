"""Application settings via pydantic-settings.

All environment variables are loaded through this class.
Use `get_settings()` (cached) rather than instantiating directly.
"""

import os
from functools import lru_cache
from typing import Literal

from pydantic import AliasChoices, Field, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        # A stray key in a local .env (e.g. credentials meant for another
        # tool) must not take the whole service down.
        extra="ignore",
        # Docker secrets are read from /run/secrets when present. Filenames
        # must match field names (db_url, redis_url, at_api_key, ...). This
        # keeps credentials out of `docker inspect` and env files.
        secrets_dir="/run/secrets" if os.path.isdir("/run/secrets") else None,
    )

    # ── App ────────────────────────────────────
    environment: Literal["local", "dev", "staging", "prod"] = "local"
    debug: bool = True
    app_name: str = "Oryon Foods Auth"
    log_level: str = "DEBUG"

    # ── Database ───────────────────────────────
    db_url: str = "postgresql+asyncpg://oryonfoods:oryonfoods@localhost:5432/oryonfoods_auth"

    # ── Redis ──────────────────────────────────
    redis_url: str = "redis://localhost:6379/0"

    # ── JWT (placeholder) ──────────────────────
    jwt_private_key_path: str = "keys/private.pem"
    jwt_public_key_path: str = "keys/public.pem"
    jwt_algorithm: str = "RS256"
    jwt_access_token_ttl_minutes: int = 15
    jwt_refresh_token_ttl_days: int = 7
    jwt_private_key: str | None = None
    jwt_public_key: str | None = None

    # ── OTP ────────────────────────────────────
    otp_provider: str = "twilio"
    otp_api_key: str = ""
    otp_sender_id: str = "Oryon Foods"
    otp_expire_minutes: int = 5
    otp_max_attempts: int = 5

    # ── Session ────────────────────────────────
    session_ttl_minutes: int = 60

    # ── SMS ────────────────────────────────────
    sms_provider: Literal["console", "africastalking"] = "console"

    # ── Africa's Talking ────────────────────────
    at_username: str = "sandbox"
    at_api_key: str = ""
    at_sender_id: str | None = None

    # ── Email ──────────────────────────────────
    # console logs the full OTP email to stdout (see email_console_send in
    # the API logs) — useful for local manual testing without a mail
    # provider. Use brevo in deployed environments.
    email_provider: Literal["console", "mailjet", "brevo"] = "console"

    # ── Brevo (Transactional Email API v3) ─────
    # Brevo renamed from Sendinblue, so accept the legacy env var too.
    brevo_api_key: str = Field(
        "",
        validation_alias=AliasChoices("BREVO_API_KEY", "SENDINBLUE_API_KEY", "brevo_api_key"),
    )
    brevo_from_email: str = "no-reply@oryonfoods.com"
    brevo_from_name: str = "Oryon Foods"
    brevo_api_url: str = "https://api.brevo.com/v3/smtp/email"
    brevo_timeout_seconds: int = 15

    # ── Mailjet (kept as an alternative provider) ──
    # Mailjet's own docs use MJ_APIKEY_PUBLIC/MJ_APIKEY_PRIVATE (the names
    # their dashboard exports); our .env.example uses MAILJET_*. Accept both.
    mailjet_api_key: str = Field(
        "",
        validation_alias=AliasChoices("MAILJET_API_KEY", "MJ_APIKEY_PUBLIC", "mailjet_api_key"),
    )
    mailjet_secret_key: str = Field(
        "",
        validation_alias=AliasChoices(
            "MAILJET_SECRET_KEY", "MJ_APIKEY_PRIVATE", "mailjet_secret_key"
        ),
    )
    mailjet_from_email: str = "no-reply@oryonfoods.com"
    mailjet_from_name: str = "Oryon Foods"
    mailjet_api_url: str = "https://api.mailjet.com/v3.1/send"
    mailjet_timeout_seconds: int = 15

    # ── CORS ────────────────────────────────────
    # Comma-separated list of allowed origins. In production, set this to
    # the actual Flutter app origin (e.g. https://app.oryonfoods.com) and the
    # Next.js admin dashboard domain. Defaults to http://localhost:3000 for
    # local Next.js dev.
    cors_allowed_origins: str = "http://localhost:3000"

    # ── Host ───────────────────────────────────
    host: str = "0.0.0.0"
    port: int = 8000

    # ── Rate limiting ──────────────────────────
    # Configurable defaults; tune per environment rather than treating these
    # as production-final abuse thresholds.
    rate_limit_login_password_phone_limit: int = 5
    rate_limit_login_password_phone_window: int = 900  # 15 min
    rate_limit_login_password_ip_limit: int = 20
    rate_limit_login_password_ip_window: int = 900

    rate_limit_otp_request_phone_limit: int = 3
    rate_limit_otp_request_phone_window: int = 600  # 10 min
    rate_limit_otp_request_ip_limit: int = 10
    rate_limit_otp_request_ip_window: int = 600

    rate_limit_otp_request_email_limit: int = 3
    rate_limit_otp_request_email_window: int = 600  # 10 min
    rate_limit_otp_request_email_ip_limit: int = 10
    rate_limit_otp_request_email_ip_window: int = 600

    rate_limit_password_reset_request_phone_limit: int = 3
    rate_limit_password_reset_request_phone_window: int = 600
    rate_limit_password_reset_request_ip_limit: int = 10
    rate_limit_password_reset_request_ip_window: int = 600

    rate_limit_refresh_ip_limit: int = 30
    rate_limit_refresh_ip_window: int = 600  # 10 min

    rate_limit_platform_login_email_limit: int = 5
    rate_limit_platform_login_email_window: int = 900  # 15 min
    rate_limit_platform_login_ip_limit: int = 20
    rate_limit_platform_login_ip_window: int = 900

    @model_validator(mode="after")
    def _reject_insecure_production_settings(self) -> "Settings":
        """Fail closed when ENVIRONMENT=prod still carries development defaults.

        Every check below is something that has silently shipped a dev
        configuration to production in the past (SEC-02). Refusing to boot is
        safer than serving real users with console OTP/email providers,
        default database credentials, or localhost CORS.
        """
        if self.environment != "prod":
            return self

        errors: list[str] = []

        if self.debug:
            errors.append("DEBUG must be false in production")
        if self.log_level.upper() == "DEBUG":
            errors.append("LOG_LEVEL must not be DEBUG in production")

        if "oryonfoods:oryonfoods@" in self.db_url:
            errors.append("DB_URL still uses the default oryonfoods/oryonfoods credentials")
        if self.redis_url.rstrip("/") == "redis://localhost:6379/0":
            errors.append(
                "REDIS_URL still points at the local default; set the production Redis URL"
            )

        if not self.jwt_private_key and self.jwt_private_key_path in {"", "keys/private.pem"}:
            errors.append(
                "JWT_PRIVATE_KEY_PATH must point at the mounted production key "
                "(not the repo-local default)"
            )
        if not self.jwt_public_key and self.jwt_public_key_path in {"", "keys/public.pem"}:
            errors.append(
                "JWT_PUBLIC_KEY_PATH must point at the mounted production key "
                "(not the repo-local default)"
            )

        if self.sms_provider == "console":
            errors.append("SMS_PROVIDER=console is not allowed in production")
        if self.sms_provider == "africastalking":
            if not self.at_api_key:
                errors.append("AT_API_KEY is required when SMS_PROVIDER=africastalking")
            if self.at_username in {"", "sandbox"}:
                errors.append("AT_USERNAME must be the production username, not 'sandbox'")

        if self.email_provider == "console":
            errors.append("EMAIL_PROVIDER=console is not allowed in production")
        if self.email_provider == "brevo" and not self.brevo_api_key:
            errors.append("BREVO_API_KEY is required when EMAIL_PROVIDER=brevo")
        if self.email_provider == "mailjet" and not (
            self.mailjet_api_key and self.mailjet_secret_key
        ):
            errors.append(
                "MAILJET_API_KEY and MAILJET_SECRET_KEY are required when "
                "EMAIL_PROVIDER=mailjet"
            )

        origins = [
            origin.strip()
            for origin in self.cors_allowed_origins.split(",")
            if origin.strip()
        ]
        if "*" in origins:
            errors.append("CORS_ALLOWED_ORIGINS must not contain '*' in production")
        if any("localhost" in origin or "127.0.0.1" in origin for origin in origins):
            errors.append("CORS_ALLOWED_ORIGINS must not contain localhost origins in production")

        if errors:
            raise ValueError(
                "Insecure production configuration:\n  - " + "\n  - ".join(errors)
            )
        return self


@lru_cache
def get_settings() -> Settings:
    """Return a cached, immutable Settings singleton."""
    return Settings()


_settings = get_settings()

# Backwards-compatible named constants for route dependency construction.
RATE_LIMIT_LOGIN_PASSWORD_PHONE_LIMIT = _settings.rate_limit_login_password_phone_limit
RATE_LIMIT_LOGIN_PASSWORD_PHONE_WINDOW = _settings.rate_limit_login_password_phone_window
RATE_LIMIT_LOGIN_PASSWORD_IP_LIMIT = _settings.rate_limit_login_password_ip_limit
RATE_LIMIT_LOGIN_PASSWORD_IP_WINDOW = _settings.rate_limit_login_password_ip_window

RATE_LIMIT_OTP_REQUEST_PHONE_LIMIT = _settings.rate_limit_otp_request_phone_limit
RATE_LIMIT_OTP_REQUEST_PHONE_WINDOW = _settings.rate_limit_otp_request_phone_window
RATE_LIMIT_OTP_REQUEST_IP_LIMIT = _settings.rate_limit_otp_request_ip_limit
RATE_LIMIT_OTP_REQUEST_IP_WINDOW = _settings.rate_limit_otp_request_ip_window

RATE_LIMIT_OTP_REQUEST_EMAIL_LIMIT = _settings.rate_limit_otp_request_email_limit
RATE_LIMIT_OTP_REQUEST_EMAIL_WINDOW = _settings.rate_limit_otp_request_email_window
RATE_LIMIT_OTP_REQUEST_EMAIL_IP_LIMIT = _settings.rate_limit_otp_request_email_ip_limit
RATE_LIMIT_OTP_REQUEST_EMAIL_IP_WINDOW = _settings.rate_limit_otp_request_email_ip_window

RATE_LIMIT_PASSWORD_RESET_REQUEST_PHONE_LIMIT = (
    _settings.rate_limit_password_reset_request_phone_limit
)
RATE_LIMIT_PASSWORD_RESET_REQUEST_PHONE_WINDOW = (
    _settings.rate_limit_password_reset_request_phone_window
)
RATE_LIMIT_PASSWORD_RESET_REQUEST_IP_LIMIT = _settings.rate_limit_password_reset_request_ip_limit
RATE_LIMIT_PASSWORD_RESET_REQUEST_IP_WINDOW = _settings.rate_limit_password_reset_request_ip_window

RATE_LIMIT_REFRESH_IP_LIMIT = _settings.rate_limit_refresh_ip_limit
RATE_LIMIT_REFRESH_IP_WINDOW = _settings.rate_limit_refresh_ip_window

RATE_LIMIT_PLATFORM_LOGIN_EMAIL_LIMIT = _settings.rate_limit_platform_login_email_limit
RATE_LIMIT_PLATFORM_LOGIN_EMAIL_WINDOW = _settings.rate_limit_platform_login_email_window
RATE_LIMIT_PLATFORM_LOGIN_IP_LIMIT = _settings.rate_limit_platform_login_ip_limit
RATE_LIMIT_PLATFORM_LOGIN_IP_WINDOW = _settings.rate_limit_platform_login_ip_window
