"""User self-service endpoints.

Self-service (authenticated) endpoints that act on the caller's own
account, as opposed to admin/management endpoints.
"""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import select
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.config import (
    RATE_LIMIT_OTP_REQUEST_EMAIL_IP_LIMIT,
    RATE_LIMIT_OTP_REQUEST_EMAIL_IP_WINDOW,
    RATE_LIMIT_OTP_REQUEST_EMAIL_LIMIT,
    RATE_LIMIT_OTP_REQUEST_EMAIL_WINDOW,
    RATE_LIMIT_OTP_REQUEST_IP_LIMIT,
    RATE_LIMIT_OTP_REQUEST_IP_WINDOW,
    RATE_LIMIT_OTP_REQUEST_PHONE_LIMIT,
    RATE_LIMIT_OTP_REQUEST_PHONE_WINDOW,
)
from app.core.database import get_async_session
from app.core.exceptions import (
    InvalidTokenError,
    OtpAttemptsExhaustedError,
    OtpCodeInvalidError,
)
from app.core.rate_limit import RateLimitDependency, body_field_source
from app.core.security import (
    create_identifier_change_token,
    decode_identifier_change_token,
    verify_password,
)
from app.deps.auth import get_current_user
from app.models.auth import VerificationCodePurpose
from app.models.business import UserBusinessRole
from app.models.user import User
from app.schemas.auth import (
    EmailChangeRequest,
    IdentifierChangeVerifyRequest,
    PhoneChangeRequest,
    UpdateProfileRequest,
)
from app.services.otp_delivery_service import (
    generate_and_send_otp_email,
    generate_and_send_otp_sms,
)
from app.services.otp_service import verify_otp
from app.services.session_service import revoke_all_sessions_for_user

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
    """Update the caller's own full name.

    ``email`` and ``phone`` may be sent only when they match the current
    identifier (the client saves the whole form, including unchanged fields).
    Changing either identifier requires proof of control of the new value via
    ``/users/me/email/change/*`` or ``/users/me/phone/change/*`` (SEC-06).
    """
    if "email" in body.model_fields_set and body.email != user.email:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                "Changing your email requires verification. "
                "Use POST /api/v1/users/me/email/change/request."
            ),
        )

    if "phone" in body.model_fields_set and body.phone != user.phone:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                "Changing your phone number requires verification. "
                "Use POST /api/v1/users/me/phone/change/request."
            ),
        )

    user.full_name = body.full_name
    db.add(user)
    await db.flush()
    await db.commit()

    return {"full_name": user.full_name, "email": user.email}


# ── Identifier change: prove control of the new email/phone ───────────────


def _require_current_password(user: User, current_password: str | None) -> None:
    """Require the current password so a stolen session cannot start a takeover.

    OTP-only accounts have no password to prove; they must set one first
    (via the password reset flow) rather than allowing a bearer token alone
    to rewrite the sign-in identifier.
    """
    if user.password_hash is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                "Set a password before changing your sign-in identifier, "
                "then retry with your current password."
            ),
        )
    if not current_password or not verify_password(current_password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Current password is incorrect",
        )


async def _consume_identifier_change(
    db: AsyncSession,
    *,
    user: User,
    change_token: str,
    expected_type: str,
    code: str,
) -> str:
    """Validate the signed change token + OTP and return the new identifier."""
    try:
        payload = decode_identifier_change_token(change_token, expected_type=expected_type)
    except InvalidTokenError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired change request",
        ) from None

    if payload.get("sub") != str(user.id):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Change request does not belong to this account",
        )

    purpose = (
        VerificationCodePurpose.EMAIL_CHANGE
        if expected_type == "email_change"
        else VerificationCodePurpose.PHONE_CHANGE
    )
    # The auth dependency's user load autobegins a transaction; verify_otp()
    # owns its own begin() block and requires a clean session.
    await db.commit()
    try:
        valid = await verify_otp(
            db,
            user_id=user.id,
            purpose=purpose,
            submitted_code=code,
        )
    except (OtpCodeInvalidError, OtpAttemptsExhaustedError):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired verification code",
        ) from None

    if not valid:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired verification code",
        )

    return str(payload["new_value"])


@router.post(
    "/me/email/change/request",
    status_code=status.HTTP_202_ACCEPTED,
    dependencies=[
        Depends(
            RateLimitDependency(
                "email_change_request_email",
                RATE_LIMIT_OTP_REQUEST_EMAIL_LIMIT,
                RATE_LIMIT_OTP_REQUEST_EMAIL_WINDOW,
                body_field_source("new_email"),
            )
        ),
        Depends(
            RateLimitDependency(
                "email_change_request_ip",
                RATE_LIMIT_OTP_REQUEST_EMAIL_IP_LIMIT,
                RATE_LIMIT_OTP_REQUEST_EMAIL_IP_WINDOW,
                "ip",
            )
        ),
    ],
)
async def request_email_change(
    body: EmailChangeRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_async_session),
) -> dict[str, str | int]:
    """Send an OTP to the proposed new email and return a signed change token."""
    _require_current_password(user, body.current_password)
    new_email = str(body.new_email)

    if new_email == user.email:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="That is already your email address",
        )

    existing = await db.exec(select(User).where(User.email == new_email, User.id != user.id))
    if existing.one_or_none():
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Email already registered",
        )

    await db.commit()

    await generate_and_send_otp_email(
        db,
        user_id=user.id,
        email=new_email,
        purpose=VerificationCodePurpose.EMAIL_CHANGE,
    )
    token = create_identifier_change_token(
        subject=str(user.id),
        change_type="email_change",
        new_value=new_email,
    )
    return {"change_token": token, "expires_in_seconds": 600}


@router.post(
    "/me/email/change/verify",
    dependencies=[
        Depends(
            RateLimitDependency(
                "email_change_verify_ip",
                RATE_LIMIT_OTP_REQUEST_EMAIL_IP_LIMIT,
                RATE_LIMIT_OTP_REQUEST_EMAIL_IP_WINDOW,
                "ip",
            )
        )
    ],
)
async def verify_email_change(
    body: IdentifierChangeVerifyRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_async_session),
) -> dict[str, str]:
    """Apply a verified email change, then revoke every existing session."""
    new_email = await _consume_identifier_change(
        db,
        user=user,
        change_token=body.change_token,
        expected_type="email_change",
        code=body.code,
    )

    existing = await db.exec(select(User).where(User.email == new_email, User.id != user.id))
    if existing.one_or_none():
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Email already registered",
        )

    user.email = new_email
    user.is_email_verified = True
    db.add(user)
    await db.commit()

    await revoke_all_sessions_for_user(db, user.id)
    return {"email": new_email}


@router.post(
    "/me/phone/change/request",
    status_code=status.HTTP_202_ACCEPTED,
    dependencies=[
        Depends(
            RateLimitDependency(
                "phone_change_request_phone",
                RATE_LIMIT_OTP_REQUEST_PHONE_LIMIT,
                RATE_LIMIT_OTP_REQUEST_PHONE_WINDOW,
                body_field_source("new_phone"),
            )
        ),
        Depends(
            RateLimitDependency(
                "phone_change_request_ip",
                RATE_LIMIT_OTP_REQUEST_IP_LIMIT,
                RATE_LIMIT_OTP_REQUEST_IP_WINDOW,
                "ip",
            )
        ),
    ],
)
async def request_phone_change(
    body: PhoneChangeRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_async_session),
) -> dict[str, str | int]:
    """Send an OTP to the proposed new phone and return a signed change token."""
    _require_current_password(user, body.current_password)
    new_phone = str(body.new_phone)

    if new_phone == user.phone:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="That is already your phone number",
        )

    existing = await db.exec(select(User).where(User.phone == new_phone, User.id != user.id))
    if existing.one_or_none():
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Phone number already registered",
        )

    await db.commit()

    await generate_and_send_otp_sms(
        db,
        user_id=user.id,
        phone=new_phone,
        purpose=VerificationCodePurpose.PHONE_CHANGE,
    )
    token = create_identifier_change_token(
        subject=str(user.id),
        change_type="phone_change",
        new_value=new_phone,
    )
    return {"change_token": token, "expires_in_seconds": 600}


@router.post(
    "/me/phone/change/verify",
    dependencies=[
        Depends(
            RateLimitDependency(
                "phone_change_verify_ip",
                RATE_LIMIT_OTP_REQUEST_IP_LIMIT,
                RATE_LIMIT_OTP_REQUEST_IP_WINDOW,
                "ip",
            )
        )
    ],
)
async def verify_phone_change(
    body: IdentifierChangeVerifyRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_async_session),
) -> dict[str, str]:
    """Apply a verified phone change, then revoke every existing session."""
    new_phone = await _consume_identifier_change(
        db,
        user=user,
        change_token=body.change_token,
        expected_type="phone_change",
        code=body.code,
    )

    existing = await db.exec(select(User).where(User.phone == new_phone, User.id != user.id))
    if existing.one_or_none():
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Phone number already registered",
        )

    user.phone = new_phone
    user.is_phone_verified = True
    db.add(user)
    await db.commit()

    await revoke_all_sessions_for_user(db, user.id)
    return {"phone": new_phone}
