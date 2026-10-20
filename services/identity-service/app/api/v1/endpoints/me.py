"""User self-service endpoints.

Self-service (authenticated) endpoints that act on the caller's own
account, as opposed to admin/management endpoints.
"""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import select
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.database import get_async_session
from app.deps.auth import get_current_user
from app.models.business import UserBusinessRole
from app.models.user import User
from app.schemas.auth import UpdateProfileRequest

router = APIRouter(prefix="/api/v1/users", tags=["User Self-Service"])


@router.get("/me/onboarding-status")
async def get_onboarding_status(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_async_session),
) -> dict[str, str | bool | None]:
    """Whether the caller still needs to complete onboarding.

    ``needs_onboarding`` is ``true`` only when the user has zero
    business-role *and* zero store-role assignments. Invited staff become
    ``false`` once the owner has assigned them a role, even before they
    first log in — business staff via ``UserBusinessRole``, store staff
    (cashiers, etc.) via ``UserStoreRole``.

    When onboarding is complete (``needs_onboarding=false``), the response
    also includes ``business_id`` and ``business_name`` from the user's
    single business role assignment (enforced by the one-business-per-user
    constraint), or from their store assignment when they hold no
    business-level role.

    Also carries ``full_name``/``email`` so a phone-first (OTP-only) signup
    — which never goes through /auth/register — can tell whether the caller
    still needs to fill in their name via PATCH /users/me.
    """
    from app.models.business import Business, UserStoreRole

    result = await db.exec(
        select(UserBusinessRole, Business.name)
        .join(Business, UserBusinessRole.business_id == Business.id)  # type: ignore[arg-type]
        .where(UserBusinessRole.user_id == user.id)
        .limit(1)
    )
    first = result.one_or_none()
    base: dict[str, str | bool | None] = {
        "full_name": user.full_name,
        "email": user.email,
    }
    if first is None:
        # No business-level role — store staff are assigned via
        # UserStoreRole instead, so check that before reporting
        # needs_onboarding (otherwise invited cashiers get routed to the
        # business-creation onboarding screen on first login).
        store_result = await db.exec(
            select(UserStoreRole, Business.name)
            .join(Business, UserStoreRole.business_id == Business.id)  # type: ignore[arg-type]
            .where(UserStoreRole.user_id == user.id)
            .order_by(UserStoreRole.id)  # type: ignore[arg-type]
            .limit(1)
        )
        store_first = store_result.one_or_none()
        if store_first is None:
            return base | {"needs_onboarding": True, "business_id": None, "business_name": None}
        usr, business_name = store_first
        return base | {
            "needs_onboarding": False,
            "business_id": str(usr.business_id),
            "business_name": business_name,
        }
    ubr, business_name = first
    return base | {
        "needs_onboarding": False,
        "business_id": str(ubr.business_id),
        "business_name": business_name,
    }


@router.patch("/me")
async def update_profile(
    body: UpdateProfileRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_async_session),
) -> dict[str, str | None]:
    """Update the caller's own full name/email/phone.

    The only way a phone-first (OTP-only) signup can record its name, and the
    only way an email-first signup can add a phone number, since those paths
    never go through /auth/register.

    ``email`` and ``phone`` are only touched when the request actually
    includes them: the client omits a field the user left blank, and an
    email-first account's address is its login identifier — clearing it as a
    side effect of saving a name would lock the user out.
    """
    if "email" in body.model_fields_set:
        if body.email:
            result = await db.exec(select(User).where(User.email == body.email, User.id != user.id))
            if result.one_or_none():
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail="Email already registered",
                )
        user.email = body.email

    if "phone" in body.model_fields_set:
        if body.phone:
            result = await db.exec(select(User).where(User.phone == body.phone, User.id != user.id))
            if result.one_or_none():
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail="Phone number already registered",
                )
        if body.phone != user.phone:
            # An added/changed number has not been proven by an SMS code yet;
            # the next phone OTP login marks it verified.
            user.is_phone_verified = False
        user.phone = body.phone

    user.full_name = body.full_name
    db.add(user)
    await db.flush()
    await db.commit()

    return {"full_name": user.full_name, "email": user.email}
