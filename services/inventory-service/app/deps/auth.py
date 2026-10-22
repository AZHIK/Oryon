"""Authentication and permission-check FastAPI dependency factories.

This service verifies JWT tokens using Identity Service's public key
(see app/core/security.py).  Permission checks read claims embedded in
the token at issue time — no database round-trips.

════════════════════════════════════════════════════════
AVAILABLE DEPENDENCY FACTORIES
════════════════════════════════════════════════════════

``get_current_claims``
    Extracts and verifies the JWT from the Authorization header.
    Returns the decoded claims dict.  Every protected endpoint should
    depend on this or one of the more-specific factories below.

``require_permission(code)``
    Rejects with 403 if ``claims["permissions"]`` does not contain *code*.

``require_business_context()``
    Rejects with 403 if ``claims["active_business_id"]`` is absent.
    Returns the ``active_business_id`` string.

``require_business_permission(code)``
    Chains ``require_business_context()`` AND ``require_permission(code)``
    in a single dependency.  Returns ``active_business_id``.

``require_platform_staff()``
    Rejects with 403 if ``claims["user_category"]`` is not ``"platform_staff"``.

``require_store_context()``
    Rejects with 403 if ``claims["active_store_id"]`` is absent.
    Returns the ``active_store_id`` string.

``require_store_permission(code)``
    Like ``require_business_permission`` but for store-scoped access:
    verifies store context, path-param store_id match, and permission code.
    Returns ``active_store_id``.

Store-scope helpers (used directly by route handlers)
    ``get_active_store_id(claims)`` / ``store_scope_id(claims)`` parse the
    optional ``active_store_id`` claim.  ``ensure_store_access(claims,
    store_id)`` rejects cross-store actions for pinned tokens, and
    ``resolve_store_filter(claims, requested)`` pins list/report queries.
    Unpinned owner/business tokens keep business-wide access.
"""

import secrets
from collections.abc import Awaitable, Callable
from typing import Annotated, Any
from uuid import UUID

from fastapi import Depends, Header, HTTPException, status

from app.core.config import get_settings
from app.core.exceptions import ExpiredTokenError, InvalidTokenError
from app.core.permission_codes import PermissionCode, coerce_permission_code
from app.core.security import decode_and_verify_access_token


async def get_current_claims(
    authorization: Annotated[str | None, Header(alias="Authorization")] = None,
) -> dict[str, Any]:
    """Extract and verify the JWT from the Authorization header.

    Returns the decoded claims dict on success.
    Raises 401 if the header is missing or the token is invalid/expired.
    """
    if authorization is None or not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing or invalid Authorization header",
            headers={"WWW-Authenticate": "Bearer"},
        )
    token = authorization.split(" ")[1]
    try:
        claims = decode_and_verify_access_token(token)
    except ExpiredTokenError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Access token has expired",
            headers={"WWW-Authenticate": "Bearer"},
        ) from exc
    except InvalidTokenError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid access token",
            headers={"WWW-Authenticate": "Bearer"},
        ) from exc
    return claims


def require_permission(
    permission_code: str | PermissionCode,
) -> Callable[..., Awaitable[dict[str, Any]]]:
    """Dependency factory: require a single permission code in claims.

    Validates *permission_code* against the ``PermissionCode`` enum at
    factory-call time.  A ``ValueError`` is raised immediately (at app
    startup / module import) for unknown codes rather than silently
    always returning 403 at runtime.
    """
    validated: PermissionCode = coerce_permission_code(permission_code)

    async def _check_permission(
        claims: Annotated[dict[str, Any], Depends(get_current_claims)],
    ) -> dict[str, Any]:
        permissions: list[str] = claims.get("permissions", [])
        if str(validated) not in permissions and "*" not in permissions:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Permission '{validated}' is required",
            )
        return claims

    return _check_permission


def require_business_context() -> Callable[..., Awaitable[str]]:
    """Dependency factory: require a live business context in the token.

    Returns the ``active_business_id`` string so route handlers can use
    it directly without re-extracting it from claims.

    Rejects with 403 when ``active_business_id`` is absent or ``None``.
    """

    async def _check_business_context(
        claims: Annotated[dict[str, Any], Depends(get_current_claims)],
    ) -> str:
        active_business_id: str | None = claims.get("active_business_id")
        if not active_business_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=(
                    "A valid business context is required. "
                    "Switch to a business context first via POST /auth/context/switch."
                ),
            )
        return active_business_id

    return _check_business_context


def require_business_permission(
    permission_code: str | PermissionCode,
) -> Callable[..., Awaitable[str]]:
    """Dependency factory: require a business context AND a specific permission.

    - Verifies ``active_business_id`` is present and non-null (403 if not).
    - Verifies the URL path ``business_id`` matches the token's
      ``active_business_id`` (403 if mismatch — enforces business-scoped
      access at the shared dependency level so no endpoint can forget).
    - Verifies the permission code is in claims (403 if not).
    - Returns ``active_business_id`` for direct use in route handlers.

    ═══════════════════════════════════════════════════════════════════════
    BUSINESS-CONTEXT BINDING  (Stage 8.5, Gap 1)
    ═══════════════════════════════════════════════════════════════════════

    The ``business_id`` path parameter is injected by FastAPI into the
    dependency via name resolution.  This ensures every protected endpoint
    automatically rejects a token whose ``active_business_id`` doesn't
    match the URL, even if a developer forgets to add ``_verify_biz_match``
    manually.
    """
    validated: PermissionCode = coerce_permission_code(permission_code)

    async def _check_business_permission(
        claims: Annotated[dict[str, Any], Depends(get_current_claims)],
        business_id: UUID,
    ) -> str:
        active_business_id: str | None = claims.get("active_business_id")
        if not active_business_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=(
                    "A valid business context is required. "
                    "Switch to a business context first via POST /auth/context/switch."
                ),
            )

        if str(business_id) != active_business_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Business ID in path does not match authenticated business context",
            )

        permissions: list[str] = claims.get("permissions", [])
        if str(validated) not in permissions and "*" not in permissions:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Permission '{validated}' is required",
            )

        return active_business_id

    return _check_business_permission


def require_platform_staff() -> Callable[..., Awaitable[dict[str, Any]]]:
    """Dependency factory: allow only platform_staff tokens.

    This is a *category-level* gate, not a permission-level one.
    """

    async def _check_platform_staff(
        claims: Annotated[dict[str, Any], Depends(get_current_claims)],
    ) -> dict[str, Any]:
        if claims.get("user_category") != "platform_staff":
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="This endpoint is restricted to platform staff",
            )
        return claims

    return _check_platform_staff


def require_store_context() -> Callable[..., Awaitable[str]]:
    """Dependency factory: require a live store context in the token.

    Returns the ``active_store_id`` string so route handlers can use
    it directly without re-extracting it from claims.

    Rejects with 403 when ``active_store_id`` is absent or ``None``.
    """

    async def _check_store_context(
        claims: Annotated[dict[str, Any], Depends(get_current_claims)],
    ) -> str:
        active_store_id: str | None = claims.get("active_store_id")
        if not active_store_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="A valid store context is required.",
            )
        return active_store_id

    return _check_store_context


def require_store_permission(
    permission_code: str | PermissionCode,
) -> Callable[..., Awaitable[str]]:
    """Dependency factory: require a store context AND a specific permission.

    - Verifies ``active_store_id`` is present and non-null (403 if not).
    - Verifies the URL path ``store_id`` matches the token's
      ``active_store_id`` (403 if mismatch — enforces store-scoped
      access at the shared dependency level).
    - Verifies the permission code is in claims (403 if not).
    - Returns ``active_store_id`` for direct use in route handlers.
    """
    validated: PermissionCode = coerce_permission_code(permission_code)

    async def _check_store_permission(
        claims: Annotated[dict[str, Any], Depends(get_current_claims)],
        store_id: UUID,
    ) -> str:
        active_store_id: str | None = claims.get("active_store_id")
        if not active_store_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="A valid store context is required.",
            )
        if str(store_id) != active_store_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Store ID in path does not match authenticated store context",
            )
        permissions: list[str] = claims.get("permissions", [])
        if str(validated) not in permissions and "*" not in permissions:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Permission '{validated}' is required",
            )
        return active_store_id

    return _check_store_permission


def get_active_store_id(claims: dict[str, Any]) -> str | None:
    """Return the store the token is pinned to, or ``None``.

    Store-staff tokens carry ``active_store_id``; owner/business-level
    tokens do not and therefore keep business-wide access.
    """
    raw = claims.get("active_store_id")
    return str(raw) if raw else None


def store_scope_id(claims: dict[str, Any]) -> UUID | None:
    """Return the token's pinned store as a ``UUID`` (``None`` if unpinned)."""
    raw = get_active_store_id(claims)
    if raw is None:
        return None
    try:
        return UUID(raw)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Invalid store context in token",
        ) from None


def ensure_store_access(claims: dict[str, Any], store_id: UUID | str) -> None:
    """Reject a store-pinned token acting on a different store.

    Unpinned tokens (owners, business staff) retain business-wide access.
    Use this for single-row/action endpoints where the target store is
    known before the write.
    """
    pinned = get_active_store_id(claims)
    if pinned is not None and str(store_id) != pinned:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Store ID does not match authenticated store context",
        )


def resolve_store_filter(claims: dict[str, Any], requested_store_id: UUID | None) -> UUID | None:
    """Resolve the store a list/report query must be constrained to.

    - Unpinned token: the caller's filter is returned unchanged.
    - Pinned token with no filter: the token's store is returned, so
      queries can never leak another store's rows.
    - Pinned token asking for another store: 403.
    """
    pinned = store_scope_id(claims)
    if pinned is None:
        return requested_store_id
    if requested_store_id is not None and requested_store_id != pinned:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Store ID does not match authenticated store context",
        )
    return pinned


async def require_internal_service_token(
    x_internal_service_token: Annotated[
        str | None, Header(alias="X-Internal-Service-Token")
    ] = None,
) -> None:
    """Dependency: require a shared-secret header for service-to-service calls.

    Not an end-user JWT check — this gates endpoints meant to be called
    only by other trusted backend services (e.g. POS Service's
    ``publish_event``, see ``app/api/v1/endpoints/internal_events.py``).
    Rejects with 401 if the header is missing or doesn't match this
    service's configured ``internal_service_token`` exactly.

    Uses a constant-time comparison so response timing can't be used to
    guess the token byte-by-byte.
    """
    expected = get_settings().internal_service_token
    if not x_internal_service_token or not secrets.compare_digest(
        x_internal_service_token, expected
    ):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing or invalid internal service token",
        )
