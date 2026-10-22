"""JWT token verification — public-key-only, no signing capability.

Inventory Service never possesses a private key.  It only verifies tokens
issued by Identity Service using the shared public key.
"""

from __future__ import annotations

from pathlib import Path
from typing import Any

import jwt

from app.core.config import get_settings
from app.core.exceptions import ExpiredTokenError, InvalidTokenError


def _load_public_key() -> str:
    settings = get_settings()
    if settings.jwt_public_key:
        return settings.jwt_public_key
    path = Path(settings.jwt_public_key_path)
    try:
        return path.read_text()
    except FileNotFoundError:
        raise RuntimeError(
            f"JWT public key not found at {settings.jwt_public_key_path}. "
            "Copy the public key from Identity Service's keys/ directory."
        ) from None


def _verify_expected_key_id(token: str, expected_key_id: str | None) -> None:
    if not expected_key_id:
        return
    try:
        header = jwt.get_unverified_header(token)
    except jwt.InvalidTokenError as exc:
        raise InvalidTokenError(str(exc)) from None
    if header.get("kid") != expected_key_id:
        raise InvalidTokenError("Token was signed by an unknown key")


def decode_and_verify_access_token(token: str) -> dict[str, Any]:
    settings = get_settings()
    public_key = _load_public_key()
    _verify_expected_key_id(token, settings.jwt_key_id)

    required_claims = ["exp", "iat", "type"]
    decode_kwargs: dict[str, Any] = {}
    if settings.jwt_issuer:
        decode_kwargs["issuer"] = settings.jwt_issuer
        required_claims.append("iss")
    if settings.jwt_audience:
        decode_kwargs["audience"] = settings.jwt_audience
        required_claims.append("aud")

    try:
        payload: dict[str, Any] = jwt.decode(
            token,
            public_key,
            algorithms=[settings.jwt_algorithm],
            options={"require": required_claims},
            **decode_kwargs,
        )
    except jwt.ExpiredSignatureError:
        raise ExpiredTokenError("Access token has expired") from None
    except jwt.InvalidTokenError as exc:
        raise InvalidTokenError(str(exc)) from None
    if payload.get("type") != "access":
        raise InvalidTokenError("Token type is not 'access' — possibly a refresh token")
    return payload
