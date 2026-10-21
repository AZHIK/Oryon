"""Business-scoped RBAC management endpoints.

Business owners (or anyone with the right business permission) can manage
custom roles, assign permissions to those roles, and assign/revoke staff
members.  All endpoints require an ``active_business_id`` in the JWT
(obtained via ``POST /auth/context/switch``) and the appropriate
permission code.
"""

from typing import Any
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import select
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.database import get_async_session
from app.core.permission_codes import PermissionCode, coerce_permission_code
from app.deps.auth import get_current_claims, get_current_user_id_uuid
from app.deps.permissions import require_business_permission
from app.models.business import (
    Business,
    BusinessRole,
    BusinessRolePermission,
    Store,
    UserBusinessRole,
    UserStoreRole,
)
from app.models.user import User, UserCategory, UserStatus
from app.schemas.business_rbac import (
    AddRolePermissionRequest,
    AssignStaffRequest,
    BusinessRoleCreateRequest,
    BusinessRolePermissionRead,
    BusinessRoleRead,
    BusinessRoleUpdateRequest,
    StaffMemberRead,
    StaffRoleSummary,
)
from app.services.rbac_guard import (
    reject_protected_role,
    require_can_grant,
    role_permission_codes,
)

router = APIRouter(prefix="/api/v1/businesses", tags=["Business RBAC"])


# ── Helpers ──────────────────────────────────────────────────────────────────


async def _get_business_or_404(db: AsyncSession, business_id: UUID) -> Business:
    biz = await db.get(Business, business_id)
    if biz is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Business not found")
    return biz


async def _get_business_role_or_404(
    db: AsyncSession, business_id: UUID, role_id: UUID
) -> BusinessRole:
    role = await db.get(BusinessRole, role_id)
    if role is None or role.business_id != business_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Business role not found")
    return role


def _require_matching_business(business_id: UUID, token_business_id: str) -> None:
    """Reject if the path's business_id doesn't match the token's active context.

    ``require_business_permission`` only checks that *a* business context and
    permission are present — it never compares that context against the
    ``business_id`` in the URL. Without this check, a caller with the right
    permission on their own business could act on any other business by
    swapping the path parameter. The read/write endpoints below (staff list,
    role-permission list, staff-role revoke) all cross-check explicitly.
    """
    if str(business_id) != token_business_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Token business context does not match the requested business",
        )


# ── 1. Create Business Role ──────────────────────────────────────────────────


@router.post(
    "/{business_id}/roles",
    response_model=BusinessRoleRead,
    status_code=status.HTTP_201_CREATED,
)
async def create_business_role(
    business_id: UUID,
    body: BusinessRoleCreateRequest,
    _biz_id: str = Depends(require_business_permission(PermissionCode.BUSINESS_ROLES_CREATE)),
    db: AsyncSession = Depends(get_async_session),
) -> BusinessRole:
    async with db.begin():
        await _get_business_or_404(db, business_id)
        _require_matching_business(business_id, _biz_id)

        existing = (
            await db.exec(
                select(BusinessRole).where(
                    BusinessRole.business_id == business_id,
                    BusinessRole.name == body.name,
                )
            )
        ).one_or_none()
        if existing:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"A role named '{body.name}' already exists for this business",
            )

        role = BusinessRole(
            business_id=business_id,
            name=body.name,
            description=body.description,
            is_protected=False,
        )
        db.add(role)
    await db.refresh(role)
    return role


# ── 2. Update Business Role ──────────────────────────────────────────────────


@router.patch(
    "/{business_id}/roles/{role_id}",
    response_model=BusinessRoleRead,
)
async def update_business_role(
    business_id: UUID,
    role_id: UUID,
    body: BusinessRoleUpdateRequest,
    _biz_id: str = Depends(require_business_permission(PermissionCode.BUSINESS_ROLES_UPDATE)),
    db: AsyncSession = Depends(get_async_session),
) -> BusinessRole:
    async with db.begin():
        role = await _get_business_role_or_404(db, business_id, role_id)
        _require_matching_business(business_id, _biz_id)

        if role.is_protected:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Protected roles cannot be modified",
            )

        if body.name is not None:
            existing = (
                await db.exec(
                    select(BusinessRole).where(
                        BusinessRole.business_id == business_id,
                        BusinessRole.name == body.name,
                        BusinessRole.id != role_id,
                    )
                )
            ).one_or_none()
            if existing:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=f"A role named '{body.name}' already exists for this business",
                )
            role.name = body.name

        if body.description is not None:
            role.description = body.description

        db.add(role)
    await db.refresh(role)
    return role


# ── 3. Delete Business Role ──────────────────────────────────────────────────


@router.delete(
    "/{business_id}/roles/{role_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
async def delete_business_role(
    business_id: UUID,
    role_id: UUID,
    _biz_id: str = Depends(require_business_permission(PermissionCode.BUSINESS_ROLES_DELETE)),
    db: AsyncSession = Depends(get_async_session),
) -> None:
    async with db.begin():
        role = await _get_business_role_or_404(db, business_id, role_id)
        _require_matching_business(business_id, _biz_id)

        if role.is_protected:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Protected roles cannot be deleted",
            )

        active_user_roles = (
            await db.exec(
                select(UserBusinessRole).where(UserBusinessRole.business_role_id == role_id)
            )
        ).all()
        if active_user_roles:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=(
                    "Cannot delete role with active user assignments. "
                    "Remove all staff assignments first."
                ),
            )

        active_store_roles = (
            await db.exec(select(UserStoreRole).where(UserStoreRole.business_role_id == role_id))
        ).all()
        if active_store_roles:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=(
                    "Cannot delete role with active store-level user assignments. "
                    "Remove all store-based assignments first."
                ),
            )

        await db.delete(role)


# ── 4. Assign Permission to Role ─────────────────────────────────────────────


@router.post(
    "/{business_id}/roles/{role_id}/permissions",
    status_code=status.HTTP_201_CREATED,
)
async def assign_role_permission(
    business_id: UUID,
    role_id: UUID,
    body: AddRolePermissionRequest,
    _biz_id: str = Depends(
        require_business_permission(PermissionCode.BUSINESS_ROLES_MANAGE_PERMISSIONS)
    ),
    claims: dict[str, Any] = Depends(get_current_claims),
    db: AsyncSession = Depends(get_async_session),
) -> dict[str, str]:
    async with db.begin():
        role = await _get_business_role_or_404(db, business_id, role_id)
        _require_matching_business(business_id, _biz_id)
        reject_protected_role(role, action="modified")

        current_permissions = await role_permission_codes(db, role_id)
        require_can_grant(claims, current_permissions)

        try:
            validated_code = coerce_permission_code(body.permission_code)
        except ValueError:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                detail=f"Invalid permission code: {body.permission_code}",
            ) from None

        require_can_grant(claims, {str(validated_code)})

        existing = (
            await db.exec(
                select(BusinessRolePermission).where(
                    BusinessRolePermission.business_role_id == role_id,
                    BusinessRolePermission.permission_code == str(validated_code),
                )
            )
        ).one_or_none()
        if existing:
            return {"detail": "Permission already assigned to role"}

        rp = BusinessRolePermission(
            business_role_id=role_id,
            permission_code=str(validated_code),
        )
        db.add(rp)

    return {"detail": "Permission assigned to role"}


# ── 5. Remove Permission from Role ───────────────────────────────────────────


@router.delete(
    "/{business_id}/roles/{role_id}/permissions/{permission_code}",
    status_code=status.HTTP_204_NO_CONTENT,
)
async def remove_role_permission(
    business_id: UUID,
    role_id: UUID,
    permission_code: str,
    _biz_id: str = Depends(
        require_business_permission(PermissionCode.BUSINESS_ROLES_MANAGE_PERMISSIONS)
    ),
    claims: dict[str, Any] = Depends(get_current_claims),
    db: AsyncSession = Depends(get_async_session),
) -> None:
    async with db.begin():
        role = await _get_business_role_or_404(db, business_id, role_id)
        _require_matching_business(business_id, _biz_id)
        reject_protected_role(role, action="modified")

        current_permissions = await role_permission_codes(db, role_id)
        require_can_grant(claims, current_permissions)

        rp = (
            await db.exec(
                select(BusinessRolePermission).where(
                    BusinessRolePermission.business_role_id == role_id,
                    BusinessRolePermission.permission_code == permission_code,
                )
            )
        ).one_or_none()
        if rp is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Permission not assigned to role",
            )

        await db.delete(rp)


# ── 6. Assign Staff to Role ──────────────────────────────────────────────────


@router.post(
    "/{business_id}/staff",
    status_code=status.HTTP_201_CREATED,
)
async def assign_staff_role(
    business_id: UUID,
    body: AssignStaffRequest,
    _biz_id: str = Depends(require_business_permission(PermissionCode.USER_BUSINESS_ROLES_ASSIGN)),
    claims: dict[str, Any] = Depends(get_current_claims),
    actor_id: str = Depends(get_current_user_id_uuid),
    db: AsyncSession = Depends(get_async_session),
) -> dict[str, str]:
    async with db.begin():
        await _get_business_or_404(db, business_id)
        _require_matching_business(business_id, _biz_id)

        target_user: User | None = None
        if body.user_id is not None:
            target_user = await db.get(User, body.user_id)
        elif body.phone is not None:
            result = await db.exec(select(User).where(User.phone == body.phone))
            target_user = result.one_or_none()
        elif body.email is not None:
            result = await db.exec(select(User).where(User.email == body.email))
            target_user = result.one_or_none()
        else:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                detail="Either 'user_id', 'phone' or 'email' must be provided",
            )

        if (
            target_user is None
            and body.user_id is None
            and (body.phone is not None or body.email is not None)
        ):
            target_user = User(
                phone=body.phone,
                email=str(body.email) if body.email is not None else None,
                full_name=(body.full_name or "").strip(),
                user_category=UserCategory.BUSINESS_STAFF,
                status=UserStatus.INVITED,
                password_hash=None,
                is_phone_verified=False,
                is_email_verified=False,
            )
            db.add(target_user)
            await db.flush()
            await db.refresh(target_user)
        elif target_user is not None and not target_user.full_name.strip() and body.full_name:
            # A previous invite may have been created without a name; fill it
            # in, but never overwrite a name that is already set.
            target_user.full_name = body.full_name.strip()

        if target_user is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found",
            )

        role = await db.get(BusinessRole, body.business_role_id)
        if role is None or role.business_id != business_id:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Business role not found",
            )
        reject_protected_role(role, action="assigned")

        role_permissions = await role_permission_codes(db, role.id)
        require_can_grant(claims, role_permissions)

        if str(target_user.id) == actor_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="You cannot change your own role assignments",
            )

        if target_user.user_category != UserCategory.BUSINESS_STAFF:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=(
                    "Only business staff can be assigned business roles. "
                    "The target user's category is not 'business_staff'."
                ),
            )

        existing = (
            await db.exec(
                select(UserBusinessRole).where(
                    UserBusinessRole.user_id == target_user.id,
                    UserBusinessRole.business_id == business_id,
                    UserBusinessRole.business_role_id == body.business_role_id,
                )
            )
        ).one_or_none()
        if existing:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=("This user already has this role assignment at this business."),
            )

        ubr = UserBusinessRole(
            user_id=target_user.id,
            business_id=business_id,
            business_role_id=body.business_role_id,
        )
        db.add(ubr)

    return {"detail": "Staff role assigned"}


# ── 7. List Staff ─────────────────────────────────────────────────────────


@router.get(
    "/{business_id}/staff",
    response_model=list[StaffMemberRead],
)
async def list_staff(
    business_id: UUID,
    token_business_id: str = Depends(
        require_business_permission(PermissionCode.USER_BUSINESS_ROLES_VIEW)
    ),
    db: AsyncSession = Depends(get_async_session),
) -> list[StaffMemberRead]:
    """One entry per staff member, with every role they hold at this business.

    A user can hold more than one ``UserBusinessRole`` row here (the model
    allows multiple simultaneous roles per business) — this groups them
    rather than returning one row per role.
    """
    _require_matching_business(business_id, token_business_id)
    await _get_business_or_404(db, business_id)

    result = await db.exec(
        select(UserBusinessRole, User, BusinessRole)
        .join(User, UserBusinessRole.user_id == User.id)  # type: ignore[arg-type]
        .join(BusinessRole, UserBusinessRole.business_role_id == BusinessRole.id)  # type: ignore[arg-type]
        .where(UserBusinessRole.business_id == business_id)
        .order_by(User.phone)
    )

    by_user: dict[UUID, StaffMemberRead] = {}
    for _ubr, user, role in result.all():
        entry = by_user.get(user.id)
        if entry is None:
            entry = StaffMemberRead(
                user_id=user.id,
                phone=user.phone,
                full_name=user.full_name,
                email=user.email,
                status=user.status,
                roles=[],
            )
            by_user[user.id] = entry
        entry.roles.append(StaffRoleSummary(business_role_id=role.id, name=role.name))

    # Store-scoped assignments live in UserStoreRole, not UserBusinessRole —
    # without this merge, anyone invited as store staff is invisible to the
    # roster. Business roles come first so the primary role stays
    # business-wide; store roles append with their store attached.
    store_result = await db.exec(
        select(UserStoreRole, User, BusinessRole, Store)
        .join(User, UserStoreRole.user_id == User.id)  # type: ignore[arg-type]
        .join(BusinessRole, UserStoreRole.business_role_id == BusinessRole.id)  # type: ignore[arg-type]
        .join(Store, UserStoreRole.store_id == Store.id)  # type: ignore[arg-type]
        .where(UserStoreRole.business_id == business_id)
        .order_by(User.phone)
    )
    for _usr, user, role, store in store_result.all():
        entry = by_user.get(user.id)
        if entry is None:
            entry = StaffMemberRead(
                user_id=user.id,
                phone=user.phone,
                full_name=user.full_name,
                email=user.email,
                status=user.status,
                roles=[],
            )
            by_user[user.id] = entry
        entry.roles.append(
            StaffRoleSummary(
                business_role_id=role.id,
                name=role.name,
                store_id=store.id,
                store_name=store.name,
            )
        )

    return list(by_user.values())


# ── 8. Revoke Staff Role ─────────────────────────────────────────────────


@router.delete(
    "/{business_id}/staff/{user_id}/roles/{role_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
async def revoke_staff_role(
    business_id: UUID,
    user_id: UUID,
    role_id: UUID,
    token_business_id: str = Depends(
        require_business_permission(PermissionCode.USER_BUSINESS_ROLES_REVOKE)
    ),
    claims: dict[str, Any] = Depends(get_current_claims),
    db: AsyncSession = Depends(get_async_session),
) -> None:
    """Remove one role assignment from a staff member.

    Removes exactly the ``(user_id, business_id, role_id)`` assignment —
    any other roles the user holds at this business are untouched.
    """
    _require_matching_business(business_id, token_business_id)

    async with db.begin():
        role = await _get_business_role_or_404(db, business_id, role_id)
        reject_protected_role(role, action="revoked")
        require_can_grant(claims, await role_permission_codes(db, role.id))

        ubr = (
            await db.exec(
                select(UserBusinessRole).where(
                    UserBusinessRole.user_id == user_id,
                    UserBusinessRole.business_id == business_id,
                    UserBusinessRole.business_role_id == role_id,
                )
            )
        ).one_or_none()
        if ubr is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Staff role assignment not found",
            )

        await db.delete(ubr)


# ── 9. List Role Permissions ─────────────────────────────────────────────


@router.get(
    "/{business_id}/roles/{role_id}/permissions",
    response_model=list[BusinessRolePermissionRead],
)
async def list_role_permissions(
    business_id: UUID,
    role_id: UUID,
    token_business_id: str = Depends(
        require_business_permission(PermissionCode.BUSINESS_ROLES_VIEW)
    ),
    db: AsyncSession = Depends(get_async_session),
) -> list[BusinessRolePermission]:
    """The permission codes currently assigned to a role.

    Needed because assign/remove (endpoints 4-5 above) only ever touch one
    code at a time — there is no other way to learn a role's current
    permission set.
    """
    _require_matching_business(business_id, token_business_id)
    await _get_business_role_or_404(db, business_id, role_id)

    result = await db.exec(
        select(BusinessRolePermission).where(BusinessRolePermission.business_role_id == role_id)
    )
    return list(result.all())
