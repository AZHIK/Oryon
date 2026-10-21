from __future__ import annotations

from typing import Any
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlmodel import select
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.database import get_async_session
from app.core.permission_codes import PermissionCode
from app.deps.auth import get_current_user_id_uuid
from app.deps.permissions import require_permission, require_platform_staff
from app.models.internal import Group, Role, UserGroup, UserRole
from app.models.platform import PlatformRole, UserPlatformRole
from app.models.user import User
from app.schemas.user import UserAdminUpdate, UserListFilters, UserRead
from app.services.session_service import revoke_all_sessions_for_user

router = APIRouter(prefix="/admin/users", tags=["Admin Users"])


@router.get("", response_model=list[UserRead])
async def list_users(
    _staff: None = Depends(require_platform_staff()),
    _perm: None = Depends(require_permission(PermissionCode.USERS_VIEW)),
    filters: UserListFilters = Depends(),
    limit: int = Query(default=50, ge=1, le=500),
    offset: int = Query(default=0, ge=0),
    db: AsyncSession = Depends(get_async_session),
) -> list[User]:
    query = select(User)

    if filters.user_category is not None:
        query = query.where(User.user_category == filters.user_category)
    if filters.status is not None:
        query = query.where(User.status == filters.status)
    if filters.is_active is not None:
        query = query.where(User.is_active == filters.is_active)
    if filters.search:
        pattern = f"%{filters.search}%"
        query = query.where(
            (User.full_name.ilike(pattern)) | (User.phone.ilike(pattern))  # type: ignore[attr-defined]
        )

    query = query.offset(offset).limit(limit)
    result = await db.exec(query)
    return list(result.all())


@router.get("/{user_id}")
async def get_user_detail(
    user_id: UUID,
    _staff: None = Depends(require_platform_staff()),
    _perm: None = Depends(require_permission(PermissionCode.USERS_VIEW)),
    db: AsyncSession = Depends(get_async_session),
) -> dict[str, Any]:
    user = await db.get(User, user_id)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )

    group_data = None
    roles_data: list[dict[str, Any]] = []
    platform_roles_data: list[dict[str, Any]] = []

    user_group = (
        await db.exec(select(UserGroup).where(UserGroup.user_id == user_id))
    ).one_or_none()
    if user_group:
        group = await db.get(Group, user_group.group_id)
        if group:
            group_data = {"id": str(group.id), "name": group.name, "description": group.description}

        user_roles = (await db.exec(select(UserRole).where(UserRole.user_id == user_id))).all()
        for ur in user_roles:
            role = await db.get(Role, ur.role_id)
            if role:
                roles_data.append(
                    {
                        "id": str(role.id),
                        "name": role.name,
                        "description": role.description,
                        "group_id": str(role.group_id),
                    }
                )

    user_platform_roles = (
        await db.exec(select(UserPlatformRole).where(UserPlatformRole.user_id == user_id))
    ).all()
    for upr in user_platform_roles:
        pr = await db.get(PlatformRole, upr.platform_role_id)
        if pr:
            platform_roles_data.append({"id": str(pr.id), "name": pr.name})

    return {
        "id": str(user.id),
        "phone": user.phone,
        "email": user.email,
        "full_name": user.full_name,
        "user_category": str(user.user_category),
        "status": str(user.status),
        "is_active": user.is_active,
        "is_phone_verified": user.is_phone_verified,
        "is_email_verified": user.is_email_verified,
        "created_at": user.created_at.isoformat() if user.created_at else None,
        "updated_at": user.updated_at.isoformat() if user.updated_at else None,
        "group": group_data,
        "roles": roles_data,
        "platform_roles": platform_roles_data,
    }


@router.patch("/{user_id}", response_model=UserRead)
async def update_user(
    user_id: UUID,
    body: UserAdminUpdate,
    _staff: None = Depends(require_platform_staff()),
    _perm: None = Depends(require_permission(PermissionCode.USERS_UPDATE)),
    db: AsyncSession = Depends(get_async_session),
) -> User:
    async with db.begin():
        user = await db.get(User, user_id)
        if user is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found",
            )

        update_data = body.model_dump(exclude_unset=True)
        if not update_data:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="No fields to update",
            )

        for field, value in update_data.items():
            setattr(user, field, value)
        db.add(user)

    needs_revoke = bool(
        ("is_active" in update_data and update_data["is_active"] is False)
        or (
            "status" in update_data
            and str(update_data["status"]) in {"suspended", "locked"}
        )
    )

    if needs_revoke:
        await revoke_all_sessions_for_user(db, user_id)

    await db.refresh(user)
    return user


@router.delete("/{user_id}", status_code=status.HTTP_204_NO_CONTENT)
async def deactivate_user(
    user_id: UUID,
    _staff: None = Depends(require_platform_staff()),
    _perm: None = Depends(require_permission(PermissionCode.USERS_DEACTIVATE)),
    _current_user_id: str = Depends(get_current_user_id_uuid),
    db: AsyncSession = Depends(get_async_session),
) -> None:
    """Soft-delete a user by setting is_active=false.

    This is NOT a hard row deletion — the row remains in the database
    to preserve referential integrity across RBAC tables and the audit
    trail.  Use PATCH to reactivate if needed.
    """
    async with db.begin():
        user = await db.get(User, user_id)
        if user is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found",
            )

        if str(user.id) == _current_user_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Cannot deactivate yourself",
            )

        user.is_active = False
        db.add(user)

    # Deactivation must also kill existing sessions, not just future logins.
    await revoke_all_sessions_for_user(db, user_id)


@router.post("/{user_id}/reactivate", response_model=UserRead)
async def reactivate_user(
    user_id: UUID,
    _staff: None = Depends(require_platform_staff()),
    _perm: None = Depends(require_permission(PermissionCode.USERS_REACTIVATE)),
    _current_user_id: str = Depends(get_current_user_id_uuid),
    db: AsyncSession = Depends(get_async_session),
) -> User:
    """Reactivate a previously deactivated user by setting is_active=true."""
    async with db.begin():
        user = await db.get(User, user_id)
        if user is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found",
            )

        if str(user.id) == _current_user_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Cannot reactivate yourself (you are already active)",
            )

        if user.is_active:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="User is already active",
            )

        user.is_active = True
        db.add(user)

    await db.refresh(user)
    return user
