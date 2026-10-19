"""Business, driver, and consumer authentication endpoints.

All business-user/driver/consumer auth flows live here: registration,
OTP-based login, password login, password reset, token refresh, session
management, and business-context switching.
"""

from contextlib import suppress
from typing import Any
from uuid import UUID

import structlog
from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlmodel import select
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.config import (
    RATE_LIMIT_LOGIN_PASSWORD_IP_LIMIT,
    RATE_LIMIT_LOGIN_PASSWORD_IP_WINDOW,
    RATE_LIMIT_LOGIN_PASSWORD_PHONE_LIMIT,
    RATE_LIMIT_LOGIN_PASSWORD_PHONE_WINDOW,
    RATE_LIMIT_OTP_REQUEST_IP_LIMIT,
    RATE_LIMIT_OTP_REQUEST_IP_WINDOW,
    RATE_LIMIT_OTP_REQUEST_PHONE_LIMIT,
    RATE_LIMIT_OTP_REQUEST_PHONE_WINDOW,
    RATE_LIMIT_PASSWORD_RESET_REQUEST_IP_LIMIT,
    RATE_LIMIT_PASSWORD_RESET_REQUEST_IP_WINDOW,
    RATE_LIMIT_PASSWORD_RESET_REQUEST_PHONE_LIMIT,
    RATE_LIMIT_PASSWORD_RESET_REQUEST_PHONE_WINDOW,
    RATE_LIMIT_REFRESH_IP_LIMIT,
    RATE_LIMIT_REFRESH_IP_WINDOW,
)
from app.core.database import get_async_session
from app.core.events import publish_event
from app.core.exceptions import (
    InvalidRefreshTokenError,
    OtpAttemptsExhaustedError,
    OtpCodeInvalidError,
    OtpDeliveryError,
    TokenReuseDetectedError,
)
from app.core.permission_codes import PermissionCode
from app.core.rate_limit import RateLimitDependency, body_field_source
from app.core.security import create_access_token, hash_password, verify_password
from app.deps.auth import get_current_claims
from app.models.auth import AuthEventType, AuthRiskLevel, RefreshToken, VerificationCodePurpose
from app.models.business import (
    BusinessRole,
    BusinessRolePermission,
    Store,
    UserBusinessPermission,
    UserBusinessRole,
    UserStoreRole,
)
from app.models.user import User, UserCategory, UserStatus
from app.schemas.auth import (
    BusinessUserRegisterRequest,
    LogoutRequest,
    PasswordLoginRequest,
    PasswordResetConfirm,
    PasswordResetRequest,
    RefreshRequest,
    RequestOTPRequest,
    SwitchBusinessContextRequest,
    SwitchStoreContextRequest,
    TokenResponse,
    VerifyOTPRequest,
)
from app.schemas.auth_security import UserSessionRead
from app.services.auth_risk_event_service import (
    rate_limit_with_risk_event,
    record_auth_risk_event,
)
from app.services.login_attempt_service import record_login_attempt
from app.services.otp_delivery_service import generate_and_send_otp_sms
from app.services.otp_service import verify_otp
from app.services.permission_resolver import (
    compute_platform_role_permissions,
    resolve_effective_permissions,
)
from app.services.session_service import (
    hash_refresh_token as session_hash_refresh_token,
)
from app.services.session_service import (
    issue_login_session,
    list_active_sessions,
    revoke_all_sessions_for_user,
    revoke_refresh_token,
    revoke_session,
    rotate_refresh_token,
)

logger = structlog.get_logger(__name__)

router = APIRouter(prefix="/api/v1/auth", tags=["Auth"])


async def _resolve_store_staff_context(
    session: AsyncSession, user_id: UUID
) -> tuple[UUID | None, UUID | None, list[str], list[str]]:
    """Resolve (active_business_id, active_store_id, role_names, effective_permissions)
    for a business_store_staff user from their UserStoreRole assignment.

    Single-store only: if more than one UserStoreRole row exists, the first
    by id is used and a warning is logged. Returns all-None/empty if the
    user has no UserStoreRole yet (not assigned to any store).
    """
    result = await session.exec(
        select(UserStoreRole).where(UserStoreRole.user_id == user_id).order_by(UserStoreRole.id)  # type: ignore[arg-type]
    )
    store_roles = result.all()
    if not store_roles:
        return None, None, [], []
    if len(store_roles) > 1:
        logger.warning("user_has_multiple_store_roles", user_id=str(user_id))
    usr = store_roles[0]

    role = await session.get(BusinessRole, usr.business_role_id)
    role_names = [role.name] if role else []
    role_permission_codes: list[str] = []
    if role:
        perm_result = await session.exec(
            select(BusinessRolePermission).where(BusinessRolePermission.business_role_id == role.id)
        )
        role_permission_codes = [rp.permission_code for rp in perm_result.all()]

    grant_result = await session.exec(
        select(UserBusinessPermission).where(
            UserBusinessPermission.user_id == user_id,
            UserBusinessPermission.business_id == usr.business_id,
            UserBusinessPermission.type == "grant",
        )
    )
    deny_result = await session.exec(
        select(UserBusinessPermission).where(
            UserBusinessPermission.user_id == user_id,
            UserBusinessPermission.business_id == usr.business_id,
            UserBusinessPermission.type == "deny",
        )
    )
    grants = [p.permission_code for p in grant_result.all()]
    denies = [p.permission_code for p in deny_result.all()]

    effective = resolve_effective_permissions(
        business_role_permissions=[],
        location_role_permissions=role_permission_codes,
        grants=grants,
        denies=denies,
    )
    return usr.business_id, usr.store_id, role_names, [str(p) for p in effective]


async def _resolve_business_staff_context(
    session: AsyncSession, user_id: UUID
) -> tuple[UUID | None, list[str], list[str]]:
    """Resolve (active_business_id, role_names, effective_permissions) for a
    business_staff user from their UserBusinessRole assignments.

    This is the same resolution `/auth/context/switch` does for an
    explicitly requested business, used here because `/auth/refresh` has no
    business_id in the request to switch to — it has to infer which
    business the caller was already scoped to.

    Single-business only: if the user holds roles at more than one
    business, the first by id is used and a warning is logged, mirroring
    `_resolve_store_staff_context`'s handling of multi-store staff. Returns
    all-None/empty if the user has no UserBusinessRole yet.
    """
    result = await session.exec(
        select(UserBusinessRole)
        .where(UserBusinessRole.user_id == user_id)
        .order_by(UserBusinessRole.id)  # type: ignore[arg-type]
    )
    all_roles = result.all()
    if not all_roles:
        return None, [], []

    business_id = all_roles[0].business_id
    if any(r.business_id != business_id for r in all_roles[1:]):
        logger.warning("user_has_roles_at_multiple_businesses", user_id=str(user_id))
    roles = [r for r in all_roles if r.business_id == business_id]

    role_names = []
    role_permission_codes: list[str] = []
    for ubr in roles:
        role = await session.get(BusinessRole, ubr.business_role_id)
        if role:
            role_names.append(role.name)
            perm_result = await session.exec(
                select(BusinessRolePermission).where(
                    BusinessRolePermission.business_role_id == role.id,
                )
            )
            for rp in perm_result.all():
                role_permission_codes.append(rp.permission_code)

    grant_result = await session.exec(
        select(UserBusinessPermission).where(
            UserBusinessPermission.user_id == user_id,
            UserBusinessPermission.business_id == business_id,
            UserBusinessPermission.type == "grant",
        )
    )
    deny_result = await session.exec(
        select(UserBusinessPermission).where(
            UserBusinessPermission.user_id == user_id,
            UserBusinessPermission.business_id == business_id,
            UserBusinessPermission.type == "deny",
        )
    )
    grants = [p.permission_code for p in grant_result.all()]
    denies = [p.permission_code for p in deny_result.all()]

    effective = resolve_effective_permissions(
        business_role_permissions=role_permission_codes,
        location_role_permissions=[],
        grants=grants,
        denies=denies,
    )
    return business_id, role_names, [str(p) for p in effective]


async def _business_role_permissions(
    db: AsyncSession, user_id: UUID, business_id: UUID
) -> tuple[list[str], list[str]]:
    """Role names + effective permission codes for a user at one business.

    Shared by the business/store context-switch endpoints so both resolve
    the identical permission set for the same (user, business) pair.
    """
    result = await db.exec(
        select(UserBusinessRole).where(
            UserBusinessRole.user_id == user_id,
            UserBusinessRole.business_id == business_id,
        )
    )
    roles = result.all()

    role_names = []
    role_permission_codes: list[str] = []
    for ubr in roles:
        role = await db.get(BusinessRole, ubr.business_role_id)
        if role:
            role_names.append(role.name)
            perm_result = await db.exec(
                select(BusinessRolePermission).where(
                    BusinessRolePermission.business_role_id == role.id,
                )
            )
            for rp in perm_result.all():
                role_permission_codes.append(rp.permission_code)

    grant_result = await db.exec(
        select(UserBusinessPermission).where(
            UserBusinessPermission.user_id == user_id,
            UserBusinessPermission.business_id == business_id,
            UserBusinessPermission.type == "grant",
        )
    )
    deny_result = await db.exec(
        select(UserBusinessPermission).where(
            UserBusinessPermission.user_id == user_id,
            UserBusinessPermission.business_id == business_id,
            UserBusinessPermission.type == "deny",
        )
    )
    grants = [p.permission_code for p in grant_result.all()]
    denies = [p.permission_code for p in deny_result.all()]

    effective = resolve_effective_permissions(
        business_role_permissions=role_permission_codes,
        location_role_permissions=[],
        grants=grants,
        denies=denies,
    )
    return role_names, [str(p) for p in effective]


async def _issue_tokens(
    session: AsyncSession,
    user: User,
    request: Request | None = None,
) -> TokenResponse:
    await session.commit()
    user_id_str = str(user.id)
    device_info = request.headers.get("user-agent") if request else None
    ip_address = request.client.host if request and request.client else None

    if user.user_category in (UserCategory.DRIVER, UserCategory.CONSUMER):
        platform_perms = await compute_platform_role_permissions(session, user.id)
        access_token = create_access_token(
            subject=user_id_str,
            user_category=user.user_category.value,
            platform_role=user.user_category.value,
            permissions=sorted(platform_perms),
        )
    elif user.user_category == UserCategory.BUSINESS_STORE_STAFF:
        biz_id, store_id, role_names, perms = await _resolve_store_staff_context(session, user.id)
        access_token = create_access_token(
            subject=user_id_str,
            user_category=UserCategory.BUSINESS_STORE_STAFF.value,
            active_business_id=str(biz_id) if biz_id else None,
            active_store_id=str(store_id) if store_id else None,
            roles=role_names,
            permissions=perms,
        )
    else:
        access_token = create_access_token(
            subject=user_id_str,
            user_category=UserCategory.BUSINESS_STAFF.value,
            active_business_id=None,
            roles=[],
            permissions=[],
            other_businesses=[],
        )

    # The permission-resolution reads above autobegin a transaction on the
    # session. `issue_login_session` owns its own `session.begin()` block, so
    # the read transaction must be closed first — otherwise SQLAlchemy raises
    # `InvalidRequestError: A transaction is already begun on this Session`
    # (500 on POST /auth/otp/verify). Mirrors the switch-context endpoints,
    # which already commit before issuing a session.
    await session.commit()

    issued = await issue_login_session(
        session,
        user_id=user.id,
        device_info=device_info,
        ip_address=ip_address,
    )

    return TokenResponse(access_token=access_token, refresh_token=issued.raw_token)


@router.post("/register", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
async def register(
    body: BusinessUserRegisterRequest,
    request: Request,
    db: AsyncSession = Depends(get_async_session),
) -> TokenResponse:
    result = await db.exec(select(User).where(User.phone == body.phone))
    if result.one_or_none():
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Phone number already registered",
        )

    if body.email:
        email_result = await db.exec(select(User).where(User.email == body.email))
        if email_result.one_or_none():
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Email already registered",
            )

    password_hash = hash_password(body.password) if body.password else None

    # NOTE: This endpoint defaults to business_staff. If driver/consumer
    # registration flows diverge in the future (e.g., different validation,
    # different onboarding steps), they should either get their own endpoint
    # or this endpoint should accept an explicit user_category field.
    user = User(
        phone=body.phone,
        full_name=body.full_name,
        email=body.email,
        user_category=UserCategory.BUSINESS_STAFF,
        status=UserStatus.ACTIVE,
        password_hash=password_hash,
        # No OTP has been checked at this point regardless of whether a
        # password was supplied — phone verification only happens for real
        # via /auth/otp/verify, so this must never start out True.
        is_phone_verified=False,
    )
    db.add(user)
    await db.flush()
    await db.refresh(user)
    await db.commit()

    await publish_event(
        "user.registered",
        {
            "user_id": str(user.id),
            "phone": user.phone,
            "user_category": str(user.user_category),
        },
    )

    return await _issue_tokens(db, user, request)


@router.post(
    "/otp/request",
    status_code=status.HTTP_204_NO_CONTENT,
    dependencies=[
        Depends(
            RateLimitDependency(
                "otp_request_phone",
                RATE_LIMIT_OTP_REQUEST_PHONE_LIMIT,
                RATE_LIMIT_OTP_REQUEST_PHONE_WINDOW,
                body_field_source("phone"),
            )
        ),
        Depends(
            RateLimitDependency(
                "otp_request_ip",
                RATE_LIMIT_OTP_REQUEST_IP_LIMIT,
                RATE_LIMIT_OTP_REQUEST_IP_WINDOW,
                "ip",
            )
        ),
    ],
)
async def request_otp(
    body: RequestOTPRequest,
    _request: Request,
    db: AsyncSession = Depends(get_async_session),
) -> None:
    result = await db.exec(select(User).where(User.phone == body.phone))
    user = result.one_or_none()

    # Choice: auto-provision a minimal user record on OTP request so that
    # a phone-first onboarding flow works without a separate registration
    # step. This is consistent with having BusinessUserRegisterRequest as
    # a separate endpoint for users who want to set a password at signup.
    if user is None:
        user = User(
            phone=body.phone,
            full_name="",
            user_category=UserCategory.BUSINESS_STAFF,
            status=UserStatus.ACTIVE,
            is_phone_verified=False,
        )
        db.add(user)
        await db.flush()
        await db.refresh(user)
        await db.commit()
    else:
        await db.commit()

    try:
        await generate_and_send_otp_sms(
            db,
            user_id=user.id,
            phone=body.phone,
            purpose=VerificationCodePurpose.LOGIN,
        )
    except OtpDeliveryError:
        logger.error("otp_delivery_failed", user_id=str(user.id), phone=body.phone)
        await publish_event(
            "otp.delivery_failed",
            {
                "user_id": str(user.id),
                "phone": body.phone,
            },
        )


@router.post("/otp/verify", response_model=TokenResponse)
async def verify_otp_endpoint(
    body: VerifyOTPRequest,
    request: Request,
    db: AsyncSession = Depends(get_async_session),
) -> TokenResponse:
    user_agent = request.headers.get("user-agent")
    ip_address = request.client.host if request.client else None

    result = await db.exec(select(User).where(User.phone == body.phone))
    user = result.one_or_none()

    if user is None:
        await record_login_attempt(
            db,
            identifier=body.phone,
            success=False,
            failure_reason="user_not_found",
            ip_address=ip_address,
            user_agent=user_agent,
        )
        await db.commit()
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired code",
        )

    await db.commit()

    user_id = user.id
    phone = body.phone
    try:
        valid = await verify_otp(
            db,
            user_id=user_id,
            purpose=VerificationCodePurpose.LOGIN,
            submitted_code=body.code,
        )
    except OtpCodeInvalidError:
        await db.rollback()
        await record_login_attempt(
            db,
            user_id=user_id,
            identifier=phone,
            success=False,
            failure_reason="invalid_otp",
            ip_address=ip_address,
            user_agent=user_agent,
        )
        await db.commit()
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired code",
        ) from None
    except OtpAttemptsExhaustedError:
        await db.rollback()
        await record_login_attempt(
            db,
            user_id=user_id,
            identifier=phone,
            success=False,
            failure_reason="otp_locked_out",
            ip_address=ip_address,
            user_agent=user_agent,
        )
        await record_auth_risk_event(
            db,
            user_id=user_id,
            event_type=AuthEventType.OTP_FAILURE,
            risk_level=AuthRiskLevel.MEDIUM,
            reason="otp_attempts_exhausted",
            ip_address=ip_address,
        )
        await db.commit()
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired code",
        ) from None

    if not valid:
        await record_login_attempt(
            db,
            user_id=user.id,
            identifier=body.phone,
            success=False,
            failure_reason="invalid_otp",
            ip_address=ip_address,
            user_agent=user_agent,
        )
        await db.commit()
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired code",
        )

    await record_login_attempt(
        db,
        user_id=user.id,
        identifier=body.phone,
        success=True,
        ip_address=ip_address,
        user_agent=user_agent,
    )
    await record_auth_risk_event(
        db,
        user_id=user.id,
        event_type=AuthEventType.LOGIN_SUCCESS,
        risk_level=AuthRiskLevel.LOW,
        reason=None,
        ip_address=ip_address,
    )

    if not user.is_phone_verified or user.status == UserStatus.INVITED:
        user.is_phone_verified = True
        if user.status == UserStatus.INVITED:
            user.status = UserStatus.ACTIVE
        db.add(user)
        await db.flush()
        await db.commit()

    return await _issue_tokens(db, user, request)


@router.post(
    "/login/password",
    response_model=TokenResponse,
    dependencies=[
        Depends(
            rate_limit_with_risk_event(
                "login_password_phone",
                RATE_LIMIT_LOGIN_PASSWORD_PHONE_LIMIT,
                RATE_LIMIT_LOGIN_PASSWORD_PHONE_WINDOW,
                body_field_source("phone"),
                event_type=AuthEventType.ACCOUNT_LOCKED,
                risk_level=AuthRiskLevel.HIGH,
                reason="rate_limit_exceeded",
                identifier_field="phone",
                lookup_field="phone",
            )
        ),
        Depends(
            RateLimitDependency(
                "login_password_ip",
                RATE_LIMIT_LOGIN_PASSWORD_IP_LIMIT,
                RATE_LIMIT_LOGIN_PASSWORD_IP_WINDOW,
                "ip",
            )
        ),
    ],
)
async def login_password(
    body: PasswordLoginRequest,
    request: Request,
    db: AsyncSession = Depends(get_async_session),
) -> TokenResponse:
    user_agent = request.headers.get("user-agent")
    ip_address = request.client.host if request.client else None

    result = await db.exec(select(User).where(User.phone == body.phone))
    user = result.one_or_none()

    if user is None:
        await record_login_attempt(
            db,
            identifier=body.phone,
            success=False,
            failure_reason="user_not_found",
            ip_address=ip_address,
            user_agent=user_agent,
        )
        await db.commit()
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid phone number or password",
        )

    if user.password_hash is None or not verify_password(body.password, user.password_hash):
        await record_login_attempt(
            db,
            user_id=user.id,
            identifier=body.phone,
            success=False,
            failure_reason="invalid_credentials",
            ip_address=ip_address,
            user_agent=user_agent,
        )
        await db.commit()
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid phone number or password",
        )

    await record_login_attempt(
        db,
        user_id=user.id,
        identifier=body.phone,
        success=True,
        ip_address=ip_address,
        user_agent=user_agent,
    )
    await record_auth_risk_event(
        db,
        user_id=user.id,
        event_type=AuthEventType.LOGIN_SUCCESS,
        risk_level=AuthRiskLevel.LOW,
        reason=None,
        ip_address=ip_address,
    )
    await db.commit()
    return await _issue_tokens(db, user, request)


@router.post(
    "/password/reset/request",
    status_code=status.HTTP_204_NO_CONTENT,
    dependencies=[
        Depends(
            RateLimitDependency(
                "password_reset_request_phone",
                RATE_LIMIT_PASSWORD_RESET_REQUEST_PHONE_LIMIT,
                RATE_LIMIT_PASSWORD_RESET_REQUEST_PHONE_WINDOW,
                body_field_source("phone"),
            )
        ),
        Depends(
            RateLimitDependency(
                "password_reset_request_ip",
                RATE_LIMIT_PASSWORD_RESET_REQUEST_IP_LIMIT,
                RATE_LIMIT_PASSWORD_RESET_REQUEST_IP_WINDOW,
                "ip",
            )
        ),
    ],
)
async def password_reset_request(
    body: PasswordResetRequest,
    request: Request,
    db: AsyncSession = Depends(get_async_session),
) -> None:
    ip_address = request.client.host if request.client else None

    result = await db.exec(select(User).where(User.phone == body.phone))
    user = result.one_or_none()

    if user is None:
        return

    await db.commit()

    await record_auth_risk_event(
        db,
        user_id=user.id,
        event_type=AuthEventType.PASSWORD_RESET_REQUEST,
        risk_level=AuthRiskLevel.LOW,
        reason=None,
        ip_address=ip_address,
    )
    await db.commit()

    try:
        await generate_and_send_otp_sms(
            db,
            user_id=user.id,
            phone=body.phone,
            purpose=VerificationCodePurpose.PASSWORD_RESET,
        )
    except OtpDeliveryError:
        logger.error("password_reset_otp_delivery_failed", user_id=str(user.id), phone=body.phone)
        await publish_event(
            "password_reset.otp_delivery_failed",
            {
                "user_id": str(user.id),
                "phone": body.phone,
            },
        )


@router.post("/password/reset/confirm", response_model=TokenResponse)
async def password_reset_confirm(
    body: PasswordResetConfirm,
    request: Request,
    db: AsyncSession = Depends(get_async_session),
) -> TokenResponse:
    result = await db.exec(select(User).where(User.phone == body.phone))
    user = result.one_or_none()

    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired code",
        )

    await db.commit()

    try:
        valid = await verify_otp(
            db,
            user_id=user.id,
            purpose=VerificationCodePurpose.PASSWORD_RESET,
            submitted_code=body.code,
        )
    except (OtpCodeInvalidError, OtpAttemptsExhaustedError):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired code",
        ) from None

    if not valid:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired code",
        )

    user.password_hash = hash_password(body.new_password)
    db.add(user)
    await db.flush()
    await db.commit()

    await revoke_all_sessions_for_user(db, user.id)

    return await _issue_tokens(db, user, request)


@router.post(
    "/refresh",
    response_model=TokenResponse,
    dependencies=[
        Depends(
            RateLimitDependency(
                "refresh_ip",
                RATE_LIMIT_REFRESH_IP_LIMIT,
                RATE_LIMIT_REFRESH_IP_WINDOW,
                "ip",
            )
        ),
    ],
)
async def refresh(
    body: RefreshRequest,
    request: Request,
    db: AsyncSession = Depends(get_async_session),
) -> TokenResponse:
    device_info = request.headers.get("user-agent")
    ip_address = request.client.host if request.client else None

    try:
        rotated = await rotate_refresh_token(
            db,
            raw_token=body.refresh_token,
            device_info=device_info,
            ip_address=ip_address,
        )
    except InvalidRefreshTokenError:
        await record_login_attempt(
            db,
            identifier="refresh_token",
            success=False,
            failure_reason="invalid_refresh_token",
            ip_address=ip_address,
            user_agent=device_info,
        )
        await db.commit()
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid, expired, or revoked refresh token",
        ) from None
    except TokenReuseDetectedError:
        old_result = await db.exec(
            select(RefreshToken).where(
                RefreshToken.token_hash == session_hash_refresh_token(body.refresh_token)
            )
        )
        replayed_token = old_result.one_or_none()
        replay_user_id = replayed_token.user_id if replayed_token else None

        await record_login_attempt(
            db,
            user_id=replay_user_id,
            identifier="refresh_token",
            success=False,
            failure_reason="token_reuse_detected",
            ip_address=ip_address,
            user_agent=device_info,
        )
        await record_auth_risk_event(
            db,
            user_id=replay_user_id,
            event_type=AuthEventType.ACCOUNT_LOCKED,
            risk_level=AuthRiskLevel.CRITICAL,
            reason="refresh_token_replay_detected",
            ip_address=ip_address,
        )
        await db.commit()
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid, expired, or revoked refresh token",
        ) from None

    user_id_str = str(rotated.refresh_token.user_id)
    result = await db.exec(select(User).where(User.id == rotated.refresh_token.user_id))
    user = result.one_or_none()

    if user is None:
        await record_login_attempt(
            db,
            user_id=rotated.refresh_token.user_id,
            identifier="refresh_token",
            success=False,
            failure_reason="user_not_found",
            ip_address=ip_address,
            user_agent=device_info,
        )
        await db.commit()
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found",
        )

    identifier = user.phone or user.email or "refresh_token"

    await record_login_attempt(
        db,
        user_id=user.id,
        identifier=identifier,
        success=True,
        ip_address=ip_address,
        user_agent=device_info,
    )
    await db.commit()

    if user.user_category in (UserCategory.DRIVER, UserCategory.CONSUMER):
        platform_perms = await compute_platform_role_permissions(db, user.id)
        access_token = create_access_token(
            subject=user_id_str,
            user_category=user.user_category.value,
            platform_role=user.user_category.value,
            permissions=sorted(platform_perms),
        )
    elif user.user_category == UserCategory.BUSINESS_STORE_STAFF:
        biz_id, store_id, role_names, perms = await _resolve_store_staff_context(db, user.id)
        access_token = create_access_token(
            subject=user_id_str,
            user_category=UserCategory.BUSINESS_STORE_STAFF.value,
            active_business_id=str(biz_id) if biz_id else None,
            active_store_id=str(store_id) if store_id else None,
            roles=role_names,
            permissions=perms,
        )
    elif user.user_category == UserCategory.BUSINESS_STAFF:
        biz_id, role_names, perms = await _resolve_business_staff_context(db, user.id)

        other_business_result = await db.exec(
            select(UserBusinessRole).where(UserBusinessRole.user_id == user.id)
        )
        seen: set[UUID] = set()
        other_businesses = []
        for ubr in other_business_result.all():
            if ubr.business_id not in seen and ubr.business_id != biz_id:
                seen.add(ubr.business_id)
                other_businesses.append({"id": str(ubr.business_id), "name": ""})

        access_token = create_access_token(
            subject=user_id_str,
            user_category=UserCategory.BUSINESS_STAFF.value,
            active_business_id=str(biz_id) if biz_id else None,
            roles=role_names,
            permissions=perms,
            other_businesses=other_businesses,
        )
    else:
        access_token = create_access_token(
            subject=user_id_str,
            user_category=user.user_category.value,
            permissions=[],
        )

    return TokenResponse(access_token=access_token, refresh_token=rotated.raw_token)


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
async def logout(
    body: LogoutRequest,
    claims: dict[str, Any] = Depends(get_current_claims),
    db: AsyncSession = Depends(get_async_session),
) -> None:
    from app.models import RefreshToken

    token_hash = session_hash_refresh_token(body.refresh_token)

    result = await db.exec(
        select(RefreshToken).where(
            RefreshToken.token_hash == token_hash,
            RefreshToken.user_id == UUID(claims["sub"]),
        )
    )
    rt = result.one_or_none()

    if rt is not None:
        await db.commit()
        with suppress(InvalidRefreshTokenError):
            await revoke_refresh_token(db, rt.id)


@router.get("/sessions", response_model=list[UserSessionRead])
async def list_sessions(
    claims: dict[str, Any] = Depends(get_current_claims),
    db: AsyncSession = Depends(get_async_session),
) -> list[UserSessionRead]:
    user_id = UUID(claims["sub"])
    sessions = await list_active_sessions(db, user_id)
    return [UserSessionRead.model_validate(s) for s in sessions]


@router.delete("/sessions/{session_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_session(
    session_id: UUID,
    claims: dict[str, Any] = Depends(get_current_claims),
    db: AsyncSession = Depends(get_async_session),
) -> None:
    user_id = UUID(claims["sub"])

    from app.models import UserSession

    sess = await db.get(UserSession, session_id)
    if sess is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Session not found",
        )
    if sess.user_id != user_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Cannot revoke another user's session",
        )

    await db.commit()
    await revoke_session(db, session_id)


@router.post("/context/switch", response_model=TokenResponse)
async def switch_business_context(
    body: SwitchBusinessContextRequest,
    request: Request,
    claims: dict[str, Any] = Depends(get_current_claims),
    db: AsyncSession = Depends(get_async_session),
) -> TokenResponse:
    if claims.get("user_category") != "business_staff":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="This endpoint is for business-staff accounts only.",
        )

    user_id = UUID(claims["sub"])

    result = await db.exec(
        select(UserBusinessRole).where(
            UserBusinessRole.user_id == user_id,
            UserBusinessRole.business_id == body.business_id,
        )
    )
    roles = result.all()

    if not roles:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User does not have any roles at the requested business",
        )

    role_names, effective = await _business_role_permissions(db, user_id, body.business_id)

    result_user = await db.exec(select(User).where(User.id == user_id))
    user = result_user.one()

    other_business_result = await db.exec(
        select(UserBusinessRole).where(UserBusinessRole.user_id == user_id)
    )
    seen: set[UUID] = set()
    other_businesses = []
    for ubr in other_business_result.all():
        if ubr.business_id not in seen and ubr.business_id != body.business_id:
            seen.add(ubr.business_id)
            other_businesses.append({"id": str(ubr.business_id), "name": ""})

    access_token = create_access_token(
        subject=str(user.id),
        user_category=UserCategory.BUSINESS_STAFF.value,
        active_business_id=str(body.business_id),
        roles=role_names,
        permissions=[str(p) for p in effective],
        other_businesses=other_businesses,
    )

    device_info = request.headers.get("user-agent")
    ip_address = request.client.host if request.client else None
    await db.commit()
    issued = await issue_login_session(
        db,
        user_id=user.id,
        device_info=device_info,
        ip_address=ip_address,
    )

    return TokenResponse(access_token=access_token, refresh_token=issued.raw_token)


@router.post("/context/switch-store", response_model=TokenResponse)
async def switch_store_context(
    body: SwitchStoreContextRequest,
    request: Request,
    claims: dict[str, Any] = Depends(get_current_claims),
    db: AsyncSession = Depends(get_async_session),
) -> TokenResponse:
    """Switch the terminal's operating store within the active business.

    Business-staff only, gated on the ``stores.switch`` permission: a
    store-scoped token is already pinned to exactly one store, and moving the
    till is a management action, not a cashier one. Reissues tokens with
    ``active_store_id`` set to the requested store, so downstream services
    can verify store scope from claims instead of trusting a client-sent id.
    """
    if claims.get("user_category") != "business_staff":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="This endpoint is for business-staff accounts only.",
        )

    if PermissionCode.STORES_SWITCH.value not in (claims.get("permissions") or []):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Switching stores requires the stores.switch permission.",
        )

    user_id = UUID(claims["sub"])
    active_business_id = claims.get("active_business_id")

    store = await db.get(Store, body.store_id)
    if store is None or store.is_deleted:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Store not found",
        )
    if active_business_id is None or str(store.business_id) != active_business_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Store does not belong to the active business",
        )

    membership = await db.exec(
        select(UserBusinessRole).where(
            UserBusinessRole.user_id == user_id,
            UserBusinessRole.business_id == store.business_id,
        )
    )
    if not membership.all():
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User does not have any roles at the store's business",
        )

    role_names, effective = await _business_role_permissions(db, user_id, store.business_id)

    result_user = await db.exec(select(User).where(User.id == user_id))
    user = result_user.one()

    access_token = create_access_token(
        subject=str(user.id),
        user_category=UserCategory.BUSINESS_STAFF.value,
        active_business_id=str(store.business_id),
        active_store_id=str(store.id),
        roles=role_names,
        permissions=[str(p) for p in effective],
    )

    device_info = request.headers.get("user-agent")
    ip_address = request.client.host if request.client else None
    await db.commit()
    issued = await issue_login_session(
        db,
        user_id=user.id,
        device_info=device_info,
        ip_address=ip_address,
    )

    return TokenResponse(access_token=access_token, refresh_token=issued.raw_token)
