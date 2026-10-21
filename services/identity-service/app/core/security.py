"""Security primitives — password hashing, JWT creation/verification, and OTP/refresh-token helpers.

All functions are pure and stateless — no database access.
They can be unit-tested in isolation and reused by other microservices.
"""

from __future__ import annotations

import secrets
from datetime import UTC, datetime, timedelta
from pathlib import Path
from typing import Any

import bcrypt
import jwt

from app.core.config import get_settings
from app.core.exceptions import ExpiredTokenError, InvalidTokenError

# ═══════════════════════════════════════════════════════════════════════════
# Internal helpers — bcrypt wrapper
# ═══════════════════════════════════════════════════════════════════════════
#
# Three separate "contexts" (password / refresh-token / OTP) are preserved
# as distinct bcrypt gensalt calls so that hashing parameters can be tuned
# independently later without affecting other hash families.  Even though
# all three currently use the same bcrypt rounds, separating them at the
# function level communicates intent and makes future divergence a simple
# one-line change per function.

_BCRYPT_ROUNDS = 12


def _bcrypt_hash(secret: str) -> str:
    encoded = secret.encode("utf-8")
    salt = bcrypt.gensalt(rounds=_BCRYPT_ROUNDS)
    return bcrypt.hashpw(encoded, salt).decode("utf-8")


def _bcrypt_verify(secret: str, hashed: str) -> bool:
    return bcrypt.checkpw(secret.encode("utf-8"), hashed.encode("utf-8"))


# ═══════════════════════════════════════════════════════════════════════════
# 1. Password hashing
# ═══════════════════════════════════════════════════════════════════════════


def hash_password(password: str) -> str:
    """Hash a plain-text password using bcrypt.

    Strength validation is handled upstream by the schema layer
    (BusinessPassword / StrongPassword).  This function assumes
    a valid password is passed in.
    """
    return _bcrypt_hash(password)


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify a plain-text password against a bcrypt hash.

    Returns True if the password matches the hash, False otherwise.
    Uses bcrypt's constant-time comparison.
    """
    return _bcrypt_verify(plain_password, hashed_password)


# ═══════════════════════════════════════════════════════════════════════════
# 2. JWT — RS256 asymmetric signing and verification
# ═══════════════════════════════════════════════════════════════════════════
#
# RS256 is chosen over HS256 so that any service that needs to verify an
# access token only needs the public key — the private key stays exclusively
# with the Identity Service.  This prevents a compromised resource server
# from forging tokens for other services, and keeps the key-distribution
# story simple (public key published via a well-known endpoint or config).


def _load_private_key() -> str:
    """Load the RSA private key from the configured path or inline setting."""
    settings = get_settings()
    if settings.jwt_private_key:
        return settings.jwt_private_key
    path = Path(settings.jwt_private_key_path)
    try:
        return path.read_text()
    except FileNotFoundError:
        raise RuntimeError(
            f"JWT private key not found at {settings.jwt_private_key_path}. "
            "Run `uv run python scripts/generate_keys.py` to create one."
        ) from None


def _load_public_key() -> str:
    """Load the RSA public key from the configured path or inline setting."""
    settings = get_settings()
    if settings.jwt_public_key:
        return settings.jwt_public_key
    path = Path(settings.jwt_public_key_path)
    try:
        return path.read_text()
    except FileNotFoundError:
        raise RuntimeError(
            f"JWT public key not found at {settings.jwt_public_key_path}. "
            "Run `uv run python scripts/generate_keys.py` to create one."
        ) from None


def create_access_token(
    *,
    subject: str,
    user_category: str,
    roles: list[str] | None = None,
    permissions: list[str] | None = None,
    active_business_id: str | None = None,
    active_store_id: str | None = None,
    other_businesses: list[dict[str, Any]] | None = None,
    group: str | None = None,
    platform_role: str | None = None,
) -> str:
    """Create a signed RS256 JWT access token with claims matching the user's category.

    The token payload shape follows the claim schemas in app/schemas/auth.py:

    * Platform-staff tokens include group and their roles/permissions.
    * Driver/consumer tokens include their platform_role (e.g. "driver", "consumer").
    * Business-staff tokens include roles, permissions, active_business_id,
      and a list of other businesses (for business-switching).
    * Store-staff tokens include roles, permissions, active_business_id, and active_store_id.

    The ``subject`` parameter is the user's UUID as a string.
    Expiry is read from ``ACCESS_TOKEN_EXPIRE_MINUTES`` in settings (default 15 min).
    """
    settings = get_settings()
    now = datetime.now(UTC)
    payload: dict[str, Any] = {
        "sub": subject,
        "type": "access",
        "user_category": user_category,
        "iat": now,
        "exp": now + timedelta(minutes=settings.jwt_access_token_ttl_minutes),
    }

    if user_category == "platform_staff":
        payload["group"] = group or ""
        payload["roles"] = roles or []
        payload["permissions"] = permissions or []
    elif user_category in ("driver", "consumer"):
        payload["platform_role"] = platform_role or user_category
        payload["permissions"] = permissions or []
    elif user_category == "business_staff":
        payload["active_business_id"] = active_business_id
        # Set by POST /auth/context/switch-store only: pins an otherwise
        # business-wide token to one operating store, so downstream services
        # can verify store scope from claims. Absent on login/business-switch
        # tokens, where the terminal's store lives client-side instead.
        if active_store_id is not None:
            payload["active_store_id"] = active_store_id
        payload["roles"] = roles or []
        payload["permissions"] = permissions or []
        payload["other_businesses"] = other_businesses or []
    elif user_category == "business_store_staff":
        payload["active_business_id"] = active_business_id
        payload["active_store_id"] = active_store_id
        payload["roles"] = roles or []
        payload["permissions"] = permissions or []
    else:
        # Future categories with no defined claim shape yet (farmer, logistics_provider, qa, ...).
        payload["roles"] = roles or []
        payload["permissions"] = permissions or []

    private_key = _load_private_key()
    return jwt.encode(payload, private_key, algorithm=settings.jwt_algorithm)


def decode_and_verify_access_token(token: str) -> dict[str, Any]:
    """Decode and verify an RS256 JWT access token.

    Steps:
        1. Verify the RSA signature using the published public key.
        2. Reject if the token is expired.
        3. Reject if the ``type`` claim is not ``"access"``
           (prevents a refresh token JWT from being accepted as an access token).

    Returns the decoded payload dict on success.

    Raises:
        ExpiredTokenError — the token's ``exp`` claim is in the past.
        InvalidTokenError — signature invalid, malformed, or wrong type.
    """
    settings = get_settings()
    public_key = _load_public_key()

    try:
        payload: dict[str, Any] = jwt.decode(
            token,
            public_key,
            algorithms=[settings.jwt_algorithm],
            options={"require": ["exp", "iat", "type"]},
        )
    except jwt.ExpiredSignatureError:
        raise ExpiredTokenError("Access token has expired") from None
    except jwt.InvalidTokenError as exc:
        raise InvalidTokenError(str(exc)) from None

    if payload.get("type") != "access":
        raise InvalidTokenError("Token type is not 'access' — possibly a refresh token")

    return payload


IDENTIFIER_CHANGE_TOKEN_TTL_MINUTES = 10


def create_identifier_change_token(
    *,
    subject: str,
    change_type: str,
    new_value: str,
) -> str:
    """Create a short-lived, signed proof of *which* identifier is changing.

    The OTP itself only proves control of the destination. This token binds
    the destination to the authenticated account, so a code requested for
    ``attacker@example.com`` cannot be submitted with a different address in
    the verify call (SEC-06). The ``type`` is deliberately not ``access``, so
    it can never be used as a bearer token.
    """
    if change_type not in {"email_change", "phone_change"}:
        raise ValueError(f"Unsupported identifier change type: {change_type}")

    settings = get_settings()
    now = datetime.now(UTC)
    payload: dict[str, Any] = {
        "sub": subject,
        "type": change_type,
        "new_value": new_value,
        "iat": now,
        "exp": now + timedelta(minutes=IDENTIFIER_CHANGE_TOKEN_TTL_MINUTES),
    }
    return jwt.encode(payload, _load_private_key(), algorithm=settings.jwt_algorithm)


def decode_identifier_change_token(token: str, *, expected_type: str) -> dict[str, Any]:
    """Verify an identifier-change token and enforce its expected type."""
    settings = get_settings()
    try:
        payload: dict[str, Any] = jwt.decode(
            token,
            _load_public_key(),
            algorithms=[settings.jwt_algorithm],
            options={"require": ["exp", "iat", "type", "sub", "new_value"]},
        )
    except jwt.ExpiredSignatureError:
        raise ExpiredTokenError("Identifier change token has expired") from None
    except jwt.InvalidTokenError as exc:
        raise InvalidTokenError(str(exc)) from None

    if payload.get("type") != expected_type:
        raise InvalidTokenError("Identifier change token type mismatch")
    if not isinstance(payload.get("new_value"), str):
        raise InvalidTokenError("Identifier change token is missing new_value")

    return payload


# ═══════════════════════════════════════════════════════════════════════════
# 3. Refresh token primitives (generation / hashing only)
# ═══════════════════════════════════════════════════════════════════════════
# Token rotation logic and DB writes live in session_service, not here.


def generate_refresh_token() -> str:
    """Generate a cryptographically random opaque refresh token (256 bits, hex-encoded).

    This is NOT a JWT — it is an opaque bearer string that will be hashed
    before storage so the DB never holds the raw token.
    """
    return secrets.token_hex(32)


def hash_refresh_token(token: str) -> str:
    """Hash a raw refresh token using bcrypt for storage.

    Uses a separate hashing context from passwords so parameters can
    diverge later without affecting password hashes.
    """
    return _bcrypt_hash(token)


def verify_refresh_token(token: str, hashed: str) -> bool:
    """Verify a raw refresh token against its stored bcrypt hash.

    Returns True if the token matches the hash, False otherwise.
    """
    return _bcrypt_verify(token, hashed)


# ═══════════════════════════════════════════════════════════════════════════
# 4. OTP code hashing primitives (generation / delivery / lockout is elsewhere)
# ═══════════════════════════════════════════════════════════════════════════


def hash_otp_code(code: str) -> str:
    """Hash a plain-text OTP code using bcrypt for storage.

    Uses a separate hashing context so OTP parameters can be tuned independently.
    """
    return _bcrypt_hash(code)


def verify_otp_code(code: str, hashed: str) -> bool:
    """Verify a plain-text OTP code against its stored bcrypt hash.

    Returns True if the code matches, False otherwise.
    """
    return _bcrypt_verify(code, hashed)
