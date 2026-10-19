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
"""

from collections.abc import Awaitable, Callable
from typing import Annotated, Any
from uuid import UUID

from fastapi import Depends, Header, HTTPException, Query, status

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


def get_pinned_store_id(claims: dict[str, Any]) -> UUID | None:
    """Return the token's ``active_store_id``, or ``None`` for unpinned tokens.

    Store-pinned tokens (store staff) must never read or write another
    store's records. Business-level tokens have no ``active_store_id`` and
    retain access to every store in their business.
    """
    raw_store_id = claims.get("active_store_id")
    if not raw_store_id:
        return None
    try:
        return UUID(str(raw_store_id))
    except (TypeError, ValueError) as exc:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Invalid store context",
        ) from exc


def ensure_store_access(claims: dict[str, Any], store_id: UUID) -> None:
    """Reject (403) when a store-pinned token targets a different store."""
    pinned_store_id = get_pinned_store_id(claims)
    if pinned_store_id is not None and store_id != pinned_store_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Store ID does not match authenticated store context",
        )


def resolve_store_scope(
    claims: dict[str, Any],
    requested_store_id: UUID | None,
) -> UUID | None:
    """Resolve an optional store filter against the token's pinned store.

    * Unpinned token → return the requested filter unchanged (``None`` means
      all stores in the business).
    * Pinned token + no filter → return the pinned store so reads are
      automatically narrowed to it.
    * Pinned token + matching filter → return that store.
    * Pinned token + foreign filter → 403.
    """
    pinned_store_id = get_pinned_store_id(claims)
    if pinned_store_id is None:
        return requested_store_id
    if requested_store_id is not None and requested_store_id != pinned_store_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Store ID does not match authenticated store context",
        )
    return pinned_store_id


async def store_scope_filter(
    claims: Annotated[dict[str, Any], Depends(get_current_claims)],
    store_id: UUID | None = Query(default=None, description="Filter by store"),
) -> UUID | None:
    """Dependency: validate/pin the ``store_id`` query parameter."""
    return resolve_store_scope(claims, store_id)


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
    BUSINESS-CONTEXT BINDING  (Stage 8.5, Gap 1 — ported from Inventory
    Service's already-hardened version)
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
