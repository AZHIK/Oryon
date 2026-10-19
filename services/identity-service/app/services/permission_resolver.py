from collections.abc import Iterable
from uuid import UUID

from sqlmodel import select
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.permission_codes import PermissionCode, coerce_permission_code
from app.models import (
    PlatformRole,
    PlatformRolePermission,
    User,
    UserCategory,
    UserPlatformRole,
)

_WILDCARD = "*"


def _coerce_or_wildcard(code: str | PermissionCode) -> PermissionCode | str:
    """Like `coerce_permission_code`, but lets the owner-role wildcard through.

    `"*"` is seeded directly onto owner `BusinessRole`s (see
    `db/seed_role_templates.py`) as a real, storable permission code — it is
    not a `PermissionCode` member since it grants everything rather than one
    thing, so coercing it through the enum raises. The consumption side
    (`app/deps/permissions.py`) already treats a raw `"*"` in the permissions
    list as an allow-everything sentinel; this just lets it survive resolution
    so it reaches that check instead of crashing token issuance.
    """
    if code == _WILDCARD:
        return _WILDCARD
    return coerce_permission_code(code)


def resolve_effective_permissions(
    *,
    business_role_permissions: Iterable[str | PermissionCode],
    location_role_permissions: Iterable[str | PermissionCode],
    grants: Iterable[str | PermissionCode],
    denies: Iterable[str | PermissionCode],
) -> set[PermissionCode | str]:
    """effective_permissions(user, business, location) =
          business_role_permissions(user, business)
        ∪ location_role_permissions(user, business, location)
        ∪ grants(user, business)
        − denies(user, business)

    Union role-derived permissions from both business-wide and location-scoped
    (store-scoped for business_store_staff) role assignments, then apply grant
    overrides, then remove anything in deny overrides. Deny always wins last,
    even over a grant for the same code. location_role_permissions is populated
    for store-staff from their assigned BusinessRole via UserStoreRole.
    """
    role_permissions = {
        _coerce_or_wildcard(permission) for permission in business_role_permissions
    } | {_coerce_or_wildcard(permission) for permission in location_role_permissions}
    granted_permissions = {_coerce_or_wildcard(permission) for permission in grants}
    denied_permissions = {_coerce_or_wildcard(permission) for permission in denies}
    return (role_permissions | granted_permissions) - denied_permissions


async def compute_platform_role_permissions(session: AsyncSession, user_id: UUID) -> set[str]:
    """Compute platform role permissions for a user.

    Queries platform_role_permissions via user_platform_roles.
    If no explicit user_platform_roles assignments exist, falls back to the
    PlatformRole matching the user's category (e.g. driver, consumer).
    """
    stmt = (
        select(PlatformRolePermission.permission_code)
        .join(
            UserPlatformRole,
            UserPlatformRole.platform_role_id == PlatformRolePermission.platform_role_id,  # type: ignore[arg-type]
        )
        .where(
            UserPlatformRole.user_id == user_id,
            UserPlatformRole.is_deleted == False,  # noqa: E712
            PlatformRolePermission.is_deleted == False,  # noqa: E712
        )
    )
    result = await session.exec(stmt)
    perms = set(result.all())

    if not perms:
        user = await session.get(User, user_id)
        if user and user.user_category:
            role_name = (
                user.user_category.value
                if isinstance(user.user_category, UserCategory)
                else user.user_category
            )
            fallback_stmt = (
                select(PlatformRolePermission.permission_code)
                .join(
                    PlatformRole,
                    PlatformRole.id == PlatformRolePermission.platform_role_id,  # type: ignore[arg-type]
                )
                .where(
                    PlatformRole.name == role_name,
                    PlatformRole.is_deleted == False,  # noqa: E712
                    PlatformRolePermission.is_deleted == False,  # noqa: E712
                )
            )
            fallback_result = await session.exec(fallback_stmt)
            perms = set(fallback_result.all())

    return perms
