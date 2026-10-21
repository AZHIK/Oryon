"""Tests for login_attempts and auth_risk_events recording."""

import random
from uuid import uuid4

from httpx import AsyncClient
from sqlmodel import select
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.config import (
    RATE_LIMIT_LOGIN_PASSWORD_PHONE_LIMIT,
    get_settings,
)
from app.core.security import hash_password
from app.models.auth import AuthEventType, AuthRiskEvent, LoginAttempt
from app.models.user import User, UserCategory, UserStatus


def _phone() -> str:
    digits = "".join(str(random.randint(0, 9)) for _ in range(8))
    return f"+2557{digits}"


_TEST_PASSWORD = "TestPass1!"


class TestLoginAttemptsRecording:
    """Verify login_attempts rows are written on every login attempt."""

    async def test_failed_password_login_creates_login_attempt(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        phone = _phone()
        async with db_session.begin():
            user = User(
                phone=phone,
                full_name="Test User",
                user_category=UserCategory.BUSINESS_STAFF,
                password_hash=hash_password(_TEST_PASSWORD),
            )
            db_session.add(user)

        resp = await client.post(
            "/api/v1/auth/login/password",
            json={"phone": phone, "password": "WrongPass1!"},
        )
        assert resp.status_code == 401

        result = await db_session.exec(select(LoginAttempt).where(LoginAttempt.identifier == phone))
        attempts = result.all()
        assert len(attempts) == 1
        assert attempts[0].success is False
        assert attempts[0].failure_reason == "invalid_credentials"
        assert attempts[0].user_id == user.id
        assert attempts[0].ip_address is not None

    async def test_successful_password_login_creates_login_attempt(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        phone = _phone()
        async with db_session.begin():
            user = User(
                phone=phone,
                full_name="Test User",
                user_category=UserCategory.BUSINESS_STAFF,
                password_hash=hash_password(_TEST_PASSWORD),
            )
            db_session.add(user)

        resp = await client.post(
            "/api/v1/auth/login/password",
            json={"phone": phone, "password": _TEST_PASSWORD},
        )
        assert resp.status_code == 200

        result = await db_session.exec(select(LoginAttempt).where(LoginAttempt.identifier == phone))
        attempts = result.all()
        assert len(attempts) >= 1
        success_attempts = [a for a in attempts if a.success is True]
        assert len(success_attempts) >= 1
        assert success_attempts[0].failure_reason is None
        assert success_attempts[0].user_id == user.id

    async def test_user_not_found_login_attempt(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        phone = _phone()

        resp = await client.post(
            "/api/v1/auth/login/password",
            json={"phone": phone, "password": _TEST_PASSWORD},
        )
        assert resp.status_code == 401

        result = await db_session.exec(select(LoginAttempt).where(LoginAttempt.identifier == phone))
        attempts = result.all()
        assert len(attempts) == 1
        assert attempts[0].success is False
        assert attempts[0].failure_reason == "user_not_found"
        assert attempts[0].user_id is None

    async def test_otp_failure_login_attempt(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        phone = _phone()
        async with db_session.begin():
            user = User(
                phone=phone,
                full_name="OTP User",
                user_category=UserCategory.BUSINESS_STAFF,
            )
            db_session.add(user)

        from app.models.auth import VerificationCodePurpose, VerificationCodeType
        from app.services.otp_service import generate_and_store_otp

        await generate_and_store_otp(
            db_session,
            user_id=user.id,
            purpose=VerificationCodePurpose.LOGIN,
            delivery_type=VerificationCodeType.SMS,
        )

        resp = await client.post(
            "/api/v1/auth/otp/verify",
            json={"phone": phone, "code": "999999"},
        )
        assert resp.status_code == 401

        result = await db_session.exec(select(LoginAttempt).where(LoginAttempt.identifier == phone))
        attempts = result.all()
        assert len(attempts) >= 1
        assert attempts[-1].success is False
        assert attempts[-1].failure_reason == "invalid_otp"

    async def test_platform_login_failure_creates_login_attempt(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        email = f"staff_{uuid4().hex[:8]}@oryonfoods.com"
        async with db_session.begin():
            user = User(
                phone=_phone(),
                email=email,
                full_name="Staff User",
                user_category=UserCategory.PLATFORM_STAFF,
                status=UserStatus.ACTIVE,
                password_hash=hash_password(_TEST_PASSWORD),
                is_email_verified=True,
            )
            db_session.add(user)

        resp = await client.post(
            "/api/v1/auth/platform/login",
            json={"email": email, "password": "WrongPass1!"},
        )
        assert resp.status_code == 401

        result = await db_session.exec(select(LoginAttempt).where(LoginAttempt.identifier == email))
        attempts = result.all()
        assert len(attempts) == 1
        assert attempts[0].success is False
        assert attempts[0].failure_reason == "invalid_credentials"

    async def test_platform_login_success_creates_login_attempt(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        email = f"staff_{uuid4().hex[:8]}@oryonfoods.com"
        async with db_session.begin():
            user = User(
                phone=_phone(),
                email=email,
                full_name="Staff User",
                user_category=UserCategory.PLATFORM_STAFF,
                status=UserStatus.ACTIVE,
                password_hash=hash_password(_TEST_PASSWORD),
                is_email_verified=True,
            )
            db_session.add(user)

        resp = await client.post(
            "/api/v1/auth/platform/login",
            json={"email": email, "password": _TEST_PASSWORD},
        )
        assert resp.status_code == 200

        result = await db_session.exec(select(LoginAttempt).where(LoginAttempt.identifier == email))
        attempts = result.all()
        success_attempts = [a for a in attempts if a.success is True]
        assert len(success_attempts) >= 1
        assert success_attempts[0].failure_reason is None


class TestAuthRiskEventsRecording:
    """Verify auth_risk_events rows are written for specific situations."""

    async def test_rate_limit_exceeded_creates_account_locked_event(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        phone = _phone()
        async with db_session.begin():
            user = User(
                phone=phone,
                full_name="Rate Limit User",
                user_category=UserCategory.BUSINESS_STAFF,
                password_hash=hash_password(_TEST_PASSWORD),
            )
            db_session.add(user)

        for _ in range(RATE_LIMIT_LOGIN_PASSWORD_PHONE_LIMIT):
            resp = await client.post(
                "/api/v1/auth/login/password",
                json={"phone": phone, "password": "WrongPass1!"},
            )
            assert resp.status_code == 401

        resp = await client.post(
            "/api/v1/auth/login/password",
            json={"phone": phone, "password": "WrongPass1!"},
        )
        assert resp.status_code == 429

        await db_session.commit()
        result = await db_session.exec(
            select(AuthRiskEvent).where(
                AuthRiskEvent.event_type == AuthEventType.ACCOUNT_LOCKED.value,
                AuthRiskEvent.user_id == user.id,
            )
        )
        events = result.all()
        assert len(events) >= 1
        assert events[-1].risk_level == "high"
        assert events[-1].reason == "rate_limit_exceeded"

    async def test_token_reuse_creates_risk_event(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        phone = _phone()
        async with db_session.begin():
            user = User(
                phone=phone,
                full_name="Replay User",
                user_category=UserCategory.BUSINESS_STAFF,
                password_hash=hash_password(_TEST_PASSWORD),
            )
            db_session.add(user)

        login_resp = await client.post(
            "/api/v1/auth/login/password",
            json={"phone": phone, "password": _TEST_PASSWORD},
        )
        assert login_resp.status_code == 200
        refresh_token = login_resp.json()["refresh_token"]

        refresh_resp = await client.post(
            "/api/v1/auth/refresh",
            json={"refresh_token": refresh_token},
        )
        assert refresh_resp.status_code == 200

        replay_resp = await client.post(
            "/api/v1/auth/refresh",
            json={"refresh_token": refresh_token},
        )
        assert replay_resp.status_code == 401

        await db_session.commit()
        result = await db_session.exec(
            select(AuthRiskEvent).where(
                AuthRiskEvent.event_type == AuthEventType.ACCOUNT_LOCKED.value,
                AuthRiskEvent.user_id == user.id,
            )
        )
        events = result.all()
        assert len(events) >= 1
        assert events[-1].risk_level == "critical"
        assert events[-1].reason == "refresh_token_replay_detected"

    async def test_otp_lockout_creates_otp_failure_event(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        phone = _phone()
        settings = get_settings()

        async with db_session.begin():
            user = User(
                phone=phone,
                full_name="OTP Lockout User",
                user_category=UserCategory.BUSINESS_STAFF,
            )
            db_session.add(user)

        from app.models.auth import VerificationCodePurpose, VerificationCodeType
        from app.services.otp_service import generate_and_store_otp

        await generate_and_store_otp(
            db_session,
            user_id=user.id,
            purpose=VerificationCodePurpose.LOGIN,
            delivery_type=VerificationCodeType.SMS,
        )

        for _ in range(settings.otp_max_attempts):
            resp = await client.post(
                "/api/v1/auth/otp/verify",
                json={"phone": phone, "code": "111111"},
            )
            assert resp.status_code == 401

        resp = await client.post(
            "/api/v1/auth/otp/verify",
            json={"phone": phone, "code": "111111"},
        )
        assert resp.status_code == 401

        await db_session.commit()
        result = await db_session.exec(
            select(AuthRiskEvent).where(
                AuthRiskEvent.event_type == AuthEventType.OTP_FAILURE.value,
                AuthRiskEvent.user_id == user.id,
            )
        )
        events = result.all()
        assert len(events) >= 1
        assert events[-1].risk_level == "medium"
        assert events[-1].reason == "otp_attempts_exhausted"

    async def test_password_reset_request_creates_event(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        phone = _phone()
        async with db_session.begin():
            user = User(
                phone=phone,
                full_name="Reset User",
                user_category=UserCategory.BUSINESS_STAFF,
                password_hash=hash_password(_TEST_PASSWORD),
            )
            db_session.add(user)

        resp = await client.post(
            "/api/v1/auth/password/reset/request",
            json={"phone": phone},
        )
        assert resp.status_code == 204

        await db_session.commit()
        result = await db_session.exec(
            select(AuthRiskEvent).where(
                AuthRiskEvent.event_type == AuthEventType.PASSWORD_RESET_REQUEST.value,
                AuthRiskEvent.user_id == user.id,
            )
        )
        events = result.all()
        assert len(events) >= 1
        assert events[0].risk_level == "low"
        assert events[0].reason is None

    async def test_successful_login_creates_login_success_event(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        phone = _phone()
        async with db_session.begin():
            user = User(
                phone=phone,
                full_name="Test User",
                user_category=UserCategory.BUSINESS_STAFF,
                password_hash=hash_password(_TEST_PASSWORD),
            )
            db_session.add(user)

        resp = await client.post(
            "/api/v1/auth/login/password",
            json={"phone": phone, "password": _TEST_PASSWORD},
        )
        assert resp.status_code == 200

        await db_session.commit()
        result = await db_session.exec(
            select(AuthRiskEvent).where(
                AuthRiskEvent.event_type == AuthEventType.LOGIN_SUCCESS.value,
                AuthRiskEvent.user_id == user.id,
            )
        )
        events = result.all()
        assert len(events) >= 1
        assert events[0].risk_level == "low"

    async def test_platform_login_success_creates_login_success_event(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        email = f"staff_{uuid4().hex[:8]}@oryonfoods.com"
        async with db_session.begin():
            user = User(
                phone=_phone(),
                email=email,
                full_name="Staff User",
                user_category=UserCategory.PLATFORM_STAFF,
                status=UserStatus.ACTIVE,
                password_hash=hash_password(_TEST_PASSWORD),
                is_email_verified=True,
            )
            db_session.add(user)

        resp = await client.post(
            "/api/v1/auth/platform/login",
            json={"email": email, "password": _TEST_PASSWORD},
        )
        assert resp.status_code == 200

        await db_session.commit()
        result = await db_session.exec(
            select(AuthRiskEvent).where(
                AuthRiskEvent.event_type == AuthEventType.LOGIN_SUCCESS.value,
                AuthRiskEvent.user_id == user.id,
            )
        )
        events = result.all()
        assert len(events) >= 1
        assert events[0].risk_level == "low"


class TestCORS:
    """Verify CORS configuration."""

    async def test_cors_allowed_origin_returns_header(self, client: AsyncClient) -> None:
        resp = await client.options(
            "/api/v1/auth/login/password",
            headers={
                "Origin": "http://localhost:3000",
                "Access-Control-Request-Method": "POST",
            },
        )
        assert resp.status_code == 200
        assert resp.headers.get("access-control-allow-origin") == "http://localhost:3000"

    async def test_cors_disallowed_origin_no_header(self, client: AsyncClient) -> None:
        resp = await client.options(
            "/api/v1/auth/login/password",
            headers={
                "Origin": "https://evil.com",
                "Access-Control-Request-Method": "POST",
            },
        )
        allow_origin = resp.headers.get("access-control-allow-origin")
        assert allow_origin is None or allow_origin != "https://evil.com"
