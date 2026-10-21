"""Store and store-setting endpoints.

Store endpoints are business-scoped: the path ``business_id`` must always
match the token's active business context. Viewing stores only requires that
context — any authenticated member of the business can see its store list,
the same way logging in and landing on the dashboard doesn't ask for a
specific grant. Mutating routes (create/update) still require the relevant
``stores.*`` permission code.

Store settings are one-to-one with their store and are created atomically
with it (both at business creation and standalone store creation), so there
is deliberately NO standalone POST for settings — only GET/PATCH. The
store-level ``stores.update`` code is reused for the settings PATCH route: a
settings row is intrinsic to its store, so a separate STORE_SETTINGS_* code
set would add seed surface without any distinct authorization semantics.
"""

from typing import Any
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.exc import IntegrityError
from sqlmodel import select
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.database import get_async_session
from app.core.exceptions import InvalidStoreTypeError
from app.core.permission_codes import PermissionCode
from app.deps.auth import get_current_claims, get_current_user_id_uuid
from app.deps.permissions import require_business_context, require_business_permission
from app.models.business import Business, BusinessRole, Store, StoreSetting, UserStoreRole
from app.models.user import User, UserCategory, UserStatus
from app.schemas.business_rbac import AssignStaffRequest, StaffMemberRead, StaffRoleSummary
from app.schemas.store import StoreCreate, StoreRead, StoreUpdate
from app.schemas.store_setting import StoreSettingRead, StoreSettingUpdate
from app.services.rbac_guard import (
    reject_protected_role,
    require_can_grant,
    role_permission_codes,
)
from app.services.store import generate_store_token, validate_store_type

router = APIRouter(prefix="/api/v1/businesses", tags=["Stores"])


async def _get_business_or_404(db: AsyncSession, business_id: UUID) -> Business:
    biz = await db.get(Business, business_id)
    if biz is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Business not found")
    return biz


async def _get_store_or_404(db: AsyncSession, business_id: UUID, store_id: UUID) -> Store:
    store = await db.get(Store, store_id)
    if store is None or store.business_id != business_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Store not found")
    return store


def _require_context_match(business_id: UUID, caller_business_id: str) -> None:
    if str(business_id) != caller_business_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Token business context does not match the requested business",
        )


def _require_store_scope_match(store_id: UUID, claims: dict[str, Any]) -> None:
    """If the caller has an active_store_id (business_store_staff), the path
    store_id must match it. business_staff/platform_staff have no
    active_store_id and are unrestricted here."""
    active_store_id = claims.get("active_store_id")
    if active_store_id and str(store_id) != active_store_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Token store context does not match the requested store",
        )


def _apply_update(model: object, values: dict[str, Any]) -> None:
    for field, value in values.items():
        setattr(model, field, value)


# ── Stores ───────────────────────────────────────────────────────────────


@router.get("/{business_id}/stores", response_model=list[StoreRead])
async def list_stores(
    business_id: UUID,
    db: AsyncSession = Depends(get_async_session),
    # Viewing your own business's stores is basic post-login navigation, not
    # a privilege some staff can be denied — any authenticated member of the
    # business context may see the list. STORES_VIEW still gates nothing
    # here on purpose; it's checked on the mutation routes below.
    caller_business_id: str = Depends(require_business_context()),
    claims: dict[str, Any] = Depends(get_current_claims),
) -> list[Store]:
    if claims.get("user_category") == "business_store_staff":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not available to store-scoped staff",
        )
    _require_context_match(business_id, caller_business_id)

    stores = (
        await db.exec(
            select(Store).where(Store.business_id == business_id).where(Store.is_deleted == False)  # noqa: E712
        )
    ).all()
    return list(stores)


@router.post(
    "/{business_id}/stores",
    response_model=StoreRead,
    status_code=status.HTTP_201_CREATED,
)
async def create_store_endpoint(
    business_id: UUID,
    body: StoreCreate,
    db: AsyncSession = Depends(get_async_session),
    caller_business_id: str = Depends(require_business_permission(PermissionCode.STORES_CREATE)),
    claims: dict[str, Any] = Depends(get_current_claims),
) -> Store:
    if claims.get("user_category") == "business_store_staff":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not available to store-scoped staff",
        )
    _require_context_match(business_id, caller_business_id)

    async with db.begin():
        business = await _get_business_or_404(db, business_id)
        try:
            validate_store_type(business.business_type, body.location_type.value)
        except InvalidStoreTypeError as exc:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                detail=str(exc),
            ) from None

        duplicate = (
            await db.exec(
                select(Store)
                .where(Store.business_id == business_id)
                .where(Store.name == body.name)
                .where(Store.is_deleted == False)  # noqa: E712
            )
        ).first()
        if duplicate is not None:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"A store named '{body.name}' already exists in this business.",
            )

        store = Store(
            business_id=business.id,
            name=body.name,
            token=generate_store_token(),
            location_type=body.location_type,
            status=body.status,
            country_code=body.country_code,
            city=body.city,
            address=body.address,
            timezone=body.timezone,
            is_primary=body.is_primary,
        )
        db.add(store)
        try:
            await db.flush()
        except IntegrityError:
            # Race with a concurrent create (or a soft-deleted row holding
            # the name, which the live-row check above skips): same answer.
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"A store named '{body.name}' already exists in this business.",
            ) from None
        db.add(StoreSetting(store_id=store.id, active=True))

    await db.refresh(store)
    return store


@router.get("/{business_id}/stores/{store_id}", response_model=StoreRead)
async def get_store(
    business_id: UUID,
    store_id: UUID,
    db: AsyncSession = Depends(get_async_session),
    caller_business_id: str = Depends(require_business_context()),
    claims: dict[str, Any] = Depends(get_current_claims),
) -> Store:
    _require_context_match(business_id, caller_business_id)
    _require_store_scope_match(store_id, claims)
    return await _get_store_or_404(db, business_id, store_id)


@router.patch("/{business_id}/stores/{store_id}", response_model=StoreRead)
async def update_store(
    business_id: UUID,
    store_id: UUID,
    body: StoreUpdate,
    db: AsyncSession = Depends(get_async_session),
    caller_business_id: str = Depends(require_business_permission(PermissionCode.STORES_UPDATE)),
    claims: dict[str, Any] = Depends(get_current_claims),
) -> Store:
    _require_context_match(business_id, caller_business_id)
    _require_store_scope_match(store_id, claims)

    values = body.model_dump(exclude_unset=True)
    if "location_type" in values:
        business = await _get_business_or_404(db, business_id)
        try:
            validate_store_type(business.business_type, values["location_type"].value)
        except InvalidStoreTypeError as exc:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                detail=str(exc),
            ) from None

    async with db.begin():
        store = await _get_store_or_404(db, business_id, store_id)
        _apply_update(store, values)
        db.add(store)

    await db.refresh(store)
    return store


# ── Store settings (1:1 with store; no standalone POST) ──────────────────


@router.get("/{business_id}/stores/{store_id}/settings", response_model=StoreSettingRead)
async def get_store_settings(
    business_id: UUID,
    store_id: UUID,
    db: AsyncSession = Depends(get_async_session),
    caller_business_id: str = Depends(require_business_context()),
    claims: dict[str, Any] = Depends(get_current_claims),
) -> StoreSetting:
    _require_context_match(business_id, caller_business_id)
    _require_store_scope_match(store_id, claims)
    await _get_store_or_404(db, business_id, store_id)

    setting = (
        await db.exec(select(StoreSetting).where(StoreSetting.store_id == store_id))
    ).one_or_none()
    if setting is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Store settings not found",
        )
    return setting


@router.patch("/{business_id}/stores/{store_id}/settings", response_model=StoreSettingRead)
async def update_store_settings(
    business_id: UUID,
    store_id: UUID,
    body: StoreSettingUpdate,
    db: AsyncSession = Depends(get_async_session),
    caller_business_id: str = Depends(require_business_permission(PermissionCode.STORES_UPDATE)),
    claims: dict[str, Any] = Depends(get_current_claims),
) -> StoreSetting:
    _require_context_match(business_id, caller_business_id)
    _require_store_scope_match(store_id, claims)

    values = body.model_dump(exclude_unset=True)

    # Every read lives inside the transaction (same shape as update_store):
    # a `db.get`/`db.exec` before `db.begin()` autobegins and the explicit
    # begin then fails with "transaction is already begun".
    async with db.begin():
        await _get_store_or_404(db, business_id, store_id)
        setting = (
            await db.exec(select(StoreSetting).where(StoreSetting.store_id == store_id))
        ).one_or_none()
        if setting is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Store settings not found",
            )
        _apply_update(setting, values)
        db.add(setting)

    await db.refresh(setting)
    return setting


# ── Store staff assignment endpoints ─────────────────────────────────────


@router.post("/{business_id}/stores/{store_id}/staff", status_code=status.HTTP_201_CREATED)
async def assign_store_staff(
    business_id: UUID,
    store_id: UUID,
    body: AssignStaffRequest,
    db: AsyncSession = Depends(get_async_session),
    _biz_id: str = Depends(require_business_permission(PermissionCode.USER_STORE_ROLES_ASSIGN)),
    claims: dict[str, Any] = Depends(get_current_claims),
    actor_id: str = Depends(get_current_user_id_uuid),
) -> dict[str, str]:
    async with db.begin():
        await _get_business_or_404(db, business_id)
        await _get_store_or_404(db, business_id, store_id)
        _require_context_match(business_id, _biz_id)

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
                user_category=UserCategory.BUSINESS_STORE_STAFF,
                status=UserStatus.INVITED,
                password_hash=None,
                is_phone_verified=False,
                is_email_verified=False,
            )
            db.add(target_user)
            await db.flush()
            await db.refresh(target_user)
        elif target_user is not None and not target_user.full_name.strip() and body.full_name:
            target_user.full_name = body.full_name.strip()

        if target_user is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found",
            )

        if target_user.user_category != UserCategory.BUSINESS_STORE_STAFF:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=(
                    "Only business store staff can be assigned to stores. "
                    "The target user's category is not 'business_store_staff'."
                ),
            )

        role = await db.get(BusinessRole, body.business_role_id)
        if role is None or role.business_id != business_id:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Business role not found",
            )
        reject_protected_role(role, action="assigned")
        require_can_grant(claims, await role_permission_codes(db, role.id))

        if str(target_user.id) == actor_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="You cannot change your own store role assignments",
            )

        existing = (
            await db.exec(
                select(UserStoreRole).where(
                    UserStoreRole.user_id == target_user.id,
                    UserStoreRole.store_id == store_id,
                    UserStoreRole.business_role_id == role.id,
                )
            )
        ).one_or_none()
        if existing:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="This user already has this role assignment at this store.",
            )

        usr = UserStoreRole(
            user_id=target_user.id,
            business_id=business_id,
            store_id=store_id,
            business_role_id=role.id,
        )
        db.add(usr)

    return {"detail": "Store staff role assigned"}


@router.get("/{business_id}/stores/{store_id}/staff", response_model=list[StaffMemberRead])
async def list_store_staff(
    business_id: UUID,
    store_id: UUID,
    db: AsyncSession = Depends(get_async_session),
    _biz_id: str = Depends(require_business_permission(PermissionCode.USER_STORE_ROLES_VIEW)),
) -> list[StaffMemberRead]:
    await _get_business_or_404(db, business_id)
    await _get_store_or_404(db, business_id, store_id)
    _require_context_match(business_id, _biz_id)

    result = await db.exec(
        select(UserStoreRole, User, BusinessRole, Store)
        .join(User, UserStoreRole.user_id == User.id)  # type: ignore[arg-type]
        .join(BusinessRole, UserStoreRole.business_role_id == BusinessRole.id)  # type: ignore[arg-type]
        .join(Store, UserStoreRole.store_id == Store.id)  # type: ignore[arg-type]
        .where(
            UserStoreRole.store_id == store_id,
            UserStoreRole.business_id == business_id,
        )
        .order_by(User.phone)
    )

    by_user: dict[UUID, StaffMemberRead] = {}
    for _usr, user, role, store in result.all():
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


@router.delete(
    "/{business_id}/stores/{store_id}/staff/{user_id}/roles/{role_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
async def revoke_store_staff_role(
    business_id: UUID,
    store_id: UUID,
    user_id: UUID,
    role_id: UUID,
    db: AsyncSession = Depends(get_async_session),
    _biz_id: str = Depends(require_business_permission(PermissionCode.USER_STORE_ROLES_REVOKE)),
    claims: dict[str, Any] = Depends(get_current_claims),
) -> None:
    async with db.begin():
        await _get_business_or_404(db, business_id)
        await _get_store_or_404(db, business_id, store_id)
        _require_context_match(business_id, _biz_id)

        role = await db.get(BusinessRole, role_id)
        if role is None or role.business_id != business_id:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Business role not found",
            )
        reject_protected_role(role, action="revoked")
        require_can_grant(claims, await role_permission_codes(db, role.id))

        usr = (
            await db.exec(
                select(UserStoreRole).where(
                    UserStoreRole.user_id == user_id,
                    UserStoreRole.store_id == store_id,
                    UserStoreRole.business_role_id == role_id,
                    UserStoreRole.business_id == business_id,
                )
            )
        ).one_or_none()
        if usr is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Store staff role assignment not found",
            )

        await db.delete(usr)
