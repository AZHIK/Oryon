"""Shared authorization guards for business role management.

These checks are deliberately separate from the JWT permission dependency:
that dependency proves the caller holds the *endpoint* permission, while these
guards ensure the caller cannot use that endpoint to escalate their own (or a
collaborator's) privileges.

See SEC-32 in ``docs/security/SECURITY_AUDIT.md``.
"""

from typing import Any
from uuid import UUID

from fastapi import HTTPException, status
from sqlmodel import select
from sqlmodel.ext.asyncio.session import AsyncSession

from app.models.business import BusinessRole, BusinessRolePermission


async def role_permission_codes(db: AsyncSession, role_id: UUID) -> set[str]:
    """Return every permission code currently attached to a role."""
    rows = await db.exec(
        select(BusinessRolePermission.permission_code).where(
            BusinessRolePermission.business_role_id == role_id
        )
    )
    return set(rows.all())


def require_can_grant(claims: dict[str, Any], permissions: set[str]) -> None:
    """Enforce "you can only grant or manage what you already hold".

    Permissions are claims-based, so this compares against the caller's
    current effective set. ``*`` (platform-wide grant) is an explicit
    override. This is the core defence against a staff manager building an
    owner-equivalent role or editing a role above their own level (SEC-32).
    """
    actor_permissions = set(claims.get("permissions", []))
    if "*" in actor_permissions:
        return

    missing = permissions - actor_permissions
    if missing:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=(
                "You cannot grant or manage permissions you do not hold: "
                + ", ".join(sorted(missing))
            ),
        )


def reject_protected_role(role: BusinessRole, *, action: str) -> None:
    """Block assignment/modification of the seeded, protected owner role."""
    if role.is_protected:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=(
                f"The protected owner role cannot be {action} through this endpoint. "
                "Ownership transfer requires a dedicated audited flow."
            ),
        )
