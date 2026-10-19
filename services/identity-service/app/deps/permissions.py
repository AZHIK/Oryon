"""Fine-grained permission-check FastAPI dependency factories.

This module provides dependency factories that read permissions already
embedded in JWT claims (issued by the auth routers) and enforce them at
the endpoint level.  It deliberately does *not* re-derive permissions
from the database — that work is done once at token-issue time by
``app.services.permission_resolver``.  These dependencies are pure
claims-readers.

════════════════════════════════════════════════════════
AVAILABLE DEPENDENCY FACTORIES
════════════════════════════════════════════════════════

``require_permission(code)``
    Rejects with 403 if ``claims["permissions"]`` does not contain
    *code*.  Validates *code* against the ``PermissionCode`` enum at
    factory-call time (i.e. at module import / app startup), so a
    typo'd string raises ``ValueError`` loudly on startup rather than
    silently returning 403 on every real request.

    Usage::

        @router.post(
            "/inventory/adjust",
            dependencies=[Depends(require_permission(PermissionCode.INVENTORY_ADJUST))],
        )
        async def adjust_inventory(...): ...

``require_any_permission(*codes)``
    Rejects with 403 only if *none* of the supplied codes are present.
    Useful for "view OR manage" patterns.

``require_all_permissions(*codes)``
    Rejects with 403 if even one of the supplied codes is missing.

``require_business_context()``
    Rejects with 403 if ``claims["active_business_id"]`` is absent or
    ``None``.  Returns the ``active_business_id`` string so route
    handlers can use it directly to scope DB queries::

        @router.get("/orders")
        async def list_orders(
            business_id: str = Depends(require_business_context()),
            db: AsyncSession = Depends(get_async_session),
        ) -> list[OrderRead]:
            ...

``require_business_permission(code)``
    Chains ``require_business_context()`` and ``require_permission(code)``
    in a single dependency.  This is the most common pattern for
    business-scoped endpoints.  Returns ``active_business_id``::

        @router.get(
            "/businesses/{business_id}/roles",
            dependencies=[
                Depends(require_business_permission(PermissionCode.BUSINESS_ROLES_VIEW))
            ],
        )
        async def list_business_roles(...): ...

``require_platform_staff()``
    Rejects with 403 if ``claims["user_category"]`` is not
    ``"platform_staff"``.  Use this as a category-level gate for
    endpoints that must never be reachable by business users regardless
    of what permissions they hold.

``require_store_context()``
    Rejects with 403 if ``claims["active_store_id"]`` is absent or
    ``None``.  Returns the ``active_store_id`` string so route
    handlers can use it directly to scope DB queries (store-staff only).

``require_store_permission(code)``
    Chains ``require_store_context()`` and ``require_permission(code)``
    for store-scoped endpoints.  Returns ``active_store_id``.

════════════════════════════════════════════════════════
HOW ANOTHER MICROSERVICE REUSES THIS
════════════════════════════════════════════════════════

1. **Public-key JWT verification** — copy ``app/core/security.py``'s
   ``decode_and_verify_access_token`` function (or just the
   ``_load_public_key`` + ``jwt.decode`` call).  The private key stays
   exclusively with the Identity Service; resource servers only need the
   public key (published via config or a ``/.well-known/jwks.json``
   endpoint — a future task).

2. **This file** — copy ``app/deps/permissions.py`` verbatim, adjusting
   only the import path of ``get_current_claims`` and ``PermissionCode``
   to wherever those land in the target service.

3. **PermissionCode enum** — see recommendation below.

════════════════════════════════════════════════════════
RECOMMENDATION: EXTRACT PermissionCode INTO A SHARED PACKAGE
════════════════════════════════════════════════════════

Do **not** copy-paste ``app/core/permission_codes.py`` into every
microservice.  Copy-paste creates drift: if the Identity Service adds
``PermissionCode.INVENTORY_EXPORT`` but another service's copy is stale,
``require_permission(PermissionCode.INVENTORY_EXPORT)`` raises
``ValueError`` at startup of that service — noisy and honest, but still
an operational incident.

**Recommended approach:** Extract ``PermissionCode`` (and any other
shared data contracts such as event schemas) into a small internal
package, e.g. ``foodlink-shared-contracts``, published to an internal
PyPI (or distributed as a Git dependency).  All services declare it as a
dependency.  Adding a new permission code then requires:
  - one PR to ``foodlink-shared-contracts``
  - version bumps in each consuming service's ``pyproject.toml``

This is the standard "contract library" pattern for internal microservice
ecosystems and prevents silent mismatches far better than documentation
alone.

The current in-tree ``PermissionCode`` is intentionally the single source
of truth until the shared-contracts package is created.  When it is
created, replace the import in this file and in
``app/core/permission_codes.py`` uniformly.
"""

from collections.abc import Awaitable, Callable
from typing import Annotated, Any

from fastapi import Depends, HTTPException, status

from app.core.permission_codes import PermissionCode, coerce_permission_code
from app.deps.auth import get_current_claims

# ═══════════════════════════════════════════════════════════════════════════
# 1. require_permission — single code
# ═══════════════════════════════════════════════════════════════════════════


def require_permission(
    permission_code: str | PermissionCode,
) -> Callable[..., Awaitable[dict[str, Any]]]:
    """Dependency factory: require a single permission code in claims.

    Validates *permission_code* against the ``PermissionCode`` enum at
    factory-call time.  A ``ValueError`` is raised immediately (at app
    startup / module import) for unknown codes rather than silently
    always returning 403 at runtime.

    Usage::

        @router.post(
            "/...",
            dependencies=[Depends(require_permission(PermissionCode.INVENTORY_ADJUST))],
        )
    """
    # Validate at factory-call time — fails loudly at import/startup for typos.
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


# ═══════════════════════════════════════════════════════════════════════════
# 2. require_any_permission — at least one of several codes
# ═══════════════════════════════════════════════════════════════════════════


def require_any_permission(
    *permission_codes: str | PermissionCode,
) -> Callable[..., Awaitable[dict[str, Any]]]:
    """Dependency factory: require at least one of the supplied codes.

    Rejects with 403 only when *none* of the codes are present.
    Validates all codes against the enum at factory-call time.
    """
    validated = tuple(coerce_permission_code(c) for c in permission_codes)

    async def _check_any(
        claims: Annotated[dict[str, Any], Depends(get_current_claims)],
    ) -> dict[str, Any]:
        permissions: list[str] = claims.get("permissions", [])
        if "*" not in permissions and not any(str(c) in permissions for c in validated):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"At least one of {[str(c) for c in validated]} is required",
            )
        return claims

    return _check_any


# ═══════════════════════════════════════════════════════════════════════════
# 3. require_all_permissions — every code must be present
# ═══════════════════════════════════════════════════════════════════════════


def require_all_permissions(
    *permission_codes: str | PermissionCode,
) -> Callable[..., Awaitable[dict[str, Any]]]:
    """Dependency factory: require all of the supplied codes.

    Rejects with 403 if even one code is absent.
    Validates all codes against the enum at factory-call time.
    """
    validated = tuple(coerce_permission_code(c) for c in permission_codes)

    async def _check_all(
        claims: Annotated[dict[str, Any], Depends(get_current_claims)],
    ) -> dict[str, Any]:
        permissions: list[str] = claims.get("permissions", [])
        if "*" in permissions:
            return claims
        missing = [str(c) for c in validated if str(c) not in permissions]
        if missing:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Missing required permissions: {missing}",
            )
        return claims

    return _check_all


# ═══════════════════════════════════════════════════════════════════════════
# 4. require_business_context — active_business_id must be present
# ═══════════════════════════════════════════════════════════════════════════


def require_business_context() -> Callable[..., Awaitable[str]]:
    """Dependency factory: require a live business context in the token.

    Returns the ``active_business_id`` string so route handlers can use
    it directly without re-extracting it from claims::

        async def my_endpoint(
            business_id: str = Depends(require_business_context()),
        ): ...

    Rejects with 403 when ``active_business_id`` is absent or ``None``
    (e.g. a freshly-registered business user who has not switched to any
    business context yet).
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


# ═══════════════════════════════════════════════════════════════════════════
# 5. require_business_permission — context + single permission in one call
# ═══════════════════════════════════════════════════════════════════════════


def require_business_permission(
    permission_code: str | PermissionCode,
) -> Callable[..., Awaitable[str]]:
    """Dependency factory: require a business context AND a specific permission.

    This is the most common pattern for business-scoped endpoints:

    - First verifies ``active_business_id`` is present and non-null (403 if not).
    - Then verifies the permission code is in claims (403 if not).
    - Returns ``active_business_id`` for direct use in route handlers.

    Usage::

        @router.get("/businesses/{business_id}/roles")
        async def list_roles(
            business_id: str = Depends(
                require_business_permission(PermissionCode.BUSINESS_ROLES_VIEW)
            ),
        ): ...

    The business_context check always runs first so that a token with
    no business context gets a context-specific 403 message rather than
    a generic "permission not found" message.
    """
    validated: PermissionCode = coerce_permission_code(permission_code)

    async def _check_business_permission(
        claims: Annotated[dict[str, Any], Depends(get_current_claims)],
    ) -> str:
        # 1. Business context gate (runs first, always)
        active_business_id: str | None = claims.get("active_business_id")
        if not active_business_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=(
                    "A valid business context is required. "
                    "Switch to a business context first via POST /auth/context/switch."
                ),
            )

        # 2. Permission gate
        permissions: list[str] = claims.get("permissions", [])
        if str(validated) not in permissions and "*" not in permissions:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Permission '{validated}' is required",
            )

        return active_business_id

    return _check_business_permission


# ═══════════════════════════════════════════════════════════════════════════
# 5b. require_any_business_permission — context + at least one of several
# ═══════════════════════════════════════════════════════════════════════════


def require_any_business_permission(
    *permission_codes: str | PermissionCode,
) -> Callable[..., Awaitable[str]]:
    """Dependency factory: require a business context AND any of the codes.

    Same shape as [require_business_permission], but for endpoints that
    should be reachable by more than one role — e.g. the roles list is
    needed both by someone managing roles (``business_roles.view``) and by
    someone assigning a role to staff, who needs the list to populate a
    picker but has no reason to hold the roles-management permission
    (``user_business_roles.assign``).
    """
    validated = tuple(coerce_permission_code(c) for c in permission_codes)

    async def _check_any_business_permission(
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

        permissions: list[str] = claims.get("permissions", [])
        if "*" not in permissions and not any(str(c) in permissions for c in validated):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"At least one of {[str(c) for c in validated]} is required",
            )

        return active_business_id

    return _check_any_business_permission


# ═══════════════════════════════════════════════════════════════════════════
# 6. require_platform_staff — category-level gate
# ═══════════════════════════════════════════════════════════════════════════


def require_platform_staff() -> Callable[..., Awaitable[dict[str, Any]]]:
    """Dependency factory: allow only platform_staff tokens.

    This is a *category-level* gate, not a permission-level one.
    No business permission code should ever grant access to endpoints
    that are internal-only (e.g. listing all businesses on the platform,
    managing internal groups/roles).

    Use this alongside ``require_role(...)`` when an endpoint must be
    both platform-staff-only AND require a specific internal role.

    Usage::

        @router.get(
            "/internal/businesses",
            dependencies=[Depends(require_platform_staff())],
        )
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


# ═══════════════════════════════════════════════════════════════════════════
# 7. require_store_context — active_store_id must be present
# ═══════════════════════════════════════════════════════════════════════════


def require_store_context() -> Callable[..., Awaitable[str]]:
    """Dependency factory: require a live store context in the token.

    Returns the ``active_store_id`` string so route handlers can use
    it directly without re-extracting it from claims.

    Rejects with 403 when ``active_store_id`` is absent or ``None``
    (e.g. a store-staff user not yet assigned to any store).
    """

    async def _check_store_context(
        claims: Annotated[dict[str, Any], Depends(get_current_claims)],
    ) -> str:
        active_store_id: str | None = claims.get("active_store_id")
        if not active_store_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=(
                    "A valid store context is required. "
                    "Ask a business administrator to assign you to a store."
                ),
            )
        return active_store_id

    return _check_store_context


# ═══════════════════════════════════════════════════════════════════════════
# 8. require_store_permission — context + single permission for store scope
# ═══════════════════════════════════════════════════════════════════════════


def require_store_permission(
    permission_code: str | PermissionCode,
) -> Callable[..., Awaitable[str]]:
    """Dependency factory: require a store context AND a specific permission.

    Similar to require_business_permission but for store-scoped endpoints:

    - First verifies ``active_store_id`` is present and non-null (403 if not).
    - Then verifies the permission code is in claims (403 if not).
    - Returns ``active_store_id`` for direct use in route handlers.
    """
    validated: PermissionCode = coerce_permission_code(permission_code)

    async def _check_store_permission(
        claims: Annotated[dict[str, Any], Depends(get_current_claims)],
    ) -> str:
        # 1. Store context gate (runs first, always)
        active_store_id: str | None = claims.get("active_store_id")
        if not active_store_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=(
                    "A valid store context is required. "
                    "Ask a business administrator to assign you to a store."
                ),
            )

        # 2. Permission gate
        permissions: list[str] = claims.get("permissions", [])
        if str(validated) not in permissions and "*" not in permissions:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Permission '{validated}' is required",
            )

        return active_store_id

    return _check_store_permission
