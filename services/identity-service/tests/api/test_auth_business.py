"""Integration tests for the business/driver/consumer auth API."""

import random
import re
from uuid import UUID

import pytest
from httpx import AsyncClient
from sqlmodel import select
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.config import (
    RATE_LIMIT_LOGIN_PASSWORD_PHONE_LIMIT,
    RATE_LIMIT_OTP_REQUEST_EMAIL_LIMIT,
    RATE_LIMIT_OTP_REQUEST_PHONE_LIMIT,
    RATE_LIMIT_PASSWORD_RESET_REQUEST_PHONE_LIMIT,
    RATE_LIMIT_REFRESH_IP_LIMIT,
    get_settings,
)
from app.core.security import hash_password
from app.models import VerificationCode, VerificationCodePurpose, VerificationCodeType
from app.models.user import User, UserCategory, UserStatus
from app.services.email.base import EmailSendResult
from app.services.otp_service import generate_and_store_otp

_TEST_PASSWORD = "TestPass1"


def _valid_phone() -> str:
    """Generate a valid Tanzanian phone number (E.164 format)."""
    digits = "".join(str(random.randint(0, 9)) for _ in range(8))
    return f"+2557{digits}"


def _valid_email() -> str:
    suffix = "".join(str(random.randint(0, 9)) for _ in range(8))
    return f"user-{suffix}@example.com"


class TestRegister:
    async def test_full_register_returns_tokens(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        phone = _valid_phone()
        resp = await client.post(
            "/api/v1/auth/register",
            json={
                "phone": phone,
                "full_name": "New User",
                "password": _TEST_PASSWORD,
            },
        )
        assert resp.status_code == 201
        data = resp.json()
        assert "access_token" in data
        assert "refresh_token" in data
        assert data["token_type"] == "bearer"

        resp2 = await client.get(
            "/api/v1/auth/sessions",
            headers={"Authorization": f"Bearer {data['access_token']}"},
        )
        assert resp2.status_code == 200

    async def test_duplicate_phone_returns_409(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        phone = _valid_phone()
        await client.post(
            "/api/v1/auth/register",
            json={
                "phone": phone,
                "full_name": "User One",
                "password": _TEST_PASSWORD,
            },
        )
        resp = await client.post(
            "/api/v1/auth/register",
            json={
                "phone": phone,
                "full_name": "User Two",
                "password": _TEST_PASSWORD,
            },
        )
        assert resp.status_code == 409

    async def test_duplicate_email_returns_409(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        email = f"{_valid_phone().strip('+')}@example.com"
        await client.post(
            "/api/v1/auth/register",
            json={
                "phone": _valid_phone(),
                "full_name": "User One",
                "email": email,
                "password": _TEST_PASSWORD,
            },
        )
        resp = await client.post(
            "/api/v1/auth/register",
            json={
                "phone": _valid_phone(),
                "full_name": "User Two",
                "email": email,
                "password": _TEST_PASSWORD,
            },
        )
        assert resp.status_code == 409

    async def test_new_account_is_not_phone_verified(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        phone = _valid_phone()
        await client.post(
            "/api/v1/auth/register",
            json={
                "phone": phone,
                "full_name": "New User",
                "password": _TEST_PASSWORD,
            },
        )
        result = await db_session.exec(select(User).where(User.phone == phone))
        user = result.one()
        assert user.is_phone_verified is False


class TestOTP:
    async def test_otp_verify_with_correct_code_returns_tokens(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        phone = _valid_phone()
        async with db_session.begin():
            user = User(
                phone=phone,
                full_name="OTP User",
                user_category=UserCategory.BUSINESS_STAFF,
                status=UserStatus.ACTIVE,
            )
            db_session.add(user)

        code = await generate_and_store_otp(
            db_session,
            user_id=user.id,
            purpose=VerificationCodePurpose.LOGIN,
            delivery_type=VerificationCodeType.SMS,
        )

        resp = await client.post(
            "/api/v1/auth/otp/verify",
            json={"phone": phone, "code": code},
        )
        assert resp.status_code == 200, resp.text
        data = resp.json()
        assert "access_token" in data
        assert "refresh_token" in data

    async def test_otp_verify_wrong_code_returns_401(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        phone = _valid_phone()
        async with db_session.begin():
            user = User(
                phone=phone,
                full_name="OTP User",
                user_category=UserCategory.BUSINESS_STAFF,
            )
            db_session.add(user)

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
        detail = resp.json()["detail"].lower()
        assert "invalid" in detail or "expired" in detail

    async def test_otp_verify_lockout_after_max_attempts(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        phone = _valid_phone()
        settings = get_settings()

        async with db_session.begin():
            user = User(
                phone=phone,
                full_name="Lockout User",
                user_category=UserCategory.BUSINESS_STAFF,
            )
            db_session.add(user)

        code = await generate_and_store_otp(
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
            json={"phone": phone, "code": code},
        )
        assert resp.status_code == 401

    async def test_otp_verify_reuses_invited_staff_user(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        phone = _valid_phone()
        async with db_session.begin():
            user = User(
                phone=phone,
                full_name="",
                user_category=UserCategory.BUSINESS_STAFF,
                status=UserStatus.INVITED,
                is_phone_verified=False,
            )
            db_session.add(user)
        invited_id = user.id

        code = await generate_and_store_otp(
            db_session,
            user_id=invited_id,
            purpose=VerificationCodePurpose.LOGIN,
            delivery_type=VerificationCodeType.SMS,
        )

        resp = await client.post(
            "/api/v1/auth/otp/verify",
            json={"phone": phone, "code": code},
        )
        assert resp.status_code == 200, resp.text
        data = resp.json()
        assert "access_token" in data
        assert "refresh_token" in data

        refreshed = (await db_session.exec(select(User).where(User.id == invited_id))).one()
        await db_session.refresh(refreshed)
        assert refreshed.status == UserStatus.ACTIVE
        assert refreshed.is_phone_verified is True

    async def test_otp_verify_brand_new_phone_still_works(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        phone = _valid_phone()
        async with db_session.begin():
            user = User(
                phone=phone,
                full_name="",
                user_category=UserCategory.BUSINESS_STAFF,
                status=UserStatus.ACTIVE,
                is_phone_verified=False,
            )
            db_session.add(user)

        code = await generate_and_store_otp(
            db_session,
            user_id=user.id,
            purpose=VerificationCodePurpose.LOGIN,
            delivery_type=VerificationCodeType.SMS,
        )

        resp = await client.post(
            "/api/v1/auth/otp/verify",
            json={"phone": phone, "code": code},
        )
        assert resp.status_code == 200, resp.text

        refreshed = (await db_session.exec(select(User).where(User.id == user.id))).one()
        await db_session.refresh(refreshed)
        assert refreshed.status == UserStatus.ACTIVE
        assert refreshed.is_phone_verified is True


class TestEmailOTP:
    async def test_request_sends_an_email_code_for_a_registered_address(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        email = _valid_email()
        async with db_session.begin():
            user = User(
                phone=_valid_phone(),
                email=email,
                full_name="Email User",
                user_category=UserCategory.BUSINESS_STAFF,
            )
            db_session.add(user)

        resp = await client.post(
            "/api/v1/auth/otp/email/request",
            json={"email": email},
        )
        assert resp.status_code == 204

        code = (
            await db_session.exec(
                select(VerificationCode).where(
                    VerificationCode.user_id == user.id,
                    VerificationCode.purpose == VerificationCodePurpose.LOGIN,
                )
            )
        ).one()
        assert code.type == VerificationCodeType.EMAIL

    async def test_request_for_unknown_email_provisions_an_account(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        """Email-first signup mirrors the phone flow: first use creates the
        account so the code can be verified into a session."""
        email = _valid_email()
        resp = await client.post(
            "/api/v1/auth/otp/email/request",
            json={"email": email},
        )
        assert resp.status_code == 204

        user = (await db_session.exec(select(User).where(User.email == email))).one()
        assert user.phone is None
        assert user.user_category == UserCategory.BUSINESS_STAFF
        assert user.status == UserStatus.ACTIVE
        assert user.is_email_verified is False

        code = (
            await db_session.exec(
                select(VerificationCode).where(
                    VerificationCode.user_id == user.id,
                    VerificationCode.purpose == VerificationCodePurpose.LOGIN,
                )
            )
        ).one()
        assert code.type == VerificationCodeType.EMAIL

    async def test_email_signup_completes_from_request_to_tokens(
        self,
        client: AsyncClient,
        db_session: AsyncSession,
        monkeypatch: pytest.MonkeyPatch,
    ) -> None:
        """The whole email-first path: an unseen address is provisioned, the
        emailed code verifies, and the account ends up active and verified —
        exactly what the phone flow does."""
        email = _valid_email()
        captured: dict[str, str] = {}

        class CapturingProvider:
            async def send_email(
                self,
                *,
                to: str,
                subject: str,
                text_body: str,
                html_body: str | None = None,
            ) -> EmailSendResult:
                _ = to, subject, html_body
                captured["text"] = text_body
                return EmailSendResult(success=True, provider_message_id="test-id")

        monkeypatch.setattr(
            "app.services.otp_delivery_service.get_email_provider",
            lambda: CapturingProvider(),
        )

        resp = await client.post(
            "/api/v1/auth/otp/email/request",
            json={"email": email},
        )
        assert resp.status_code == 204

        match = re.search(r"\b(\d{6})\b", captured["text"])
        assert match is not None, captured["text"]
        code = match.group(1)

        verify = await client.post(
            "/api/v1/auth/otp/email/verify",
            json={"email": email, "code": code},
        )
        assert verify.status_code == 200, verify.text
        assert "access_token" in verify.json()

        user = (await db_session.exec(select(User).where(User.email == email))).one()
        await db_session.refresh(user)
        assert user.phone is None
        assert user.status == UserStatus.ACTIVE
        assert user.is_email_verified is True

    async def test_verify_with_correct_code_returns_tokens(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        email = _valid_email()
        async with db_session.begin():
            user = User(
                phone=_valid_phone(),
                email=email,
                full_name="Email User",
                user_category=UserCategory.BUSINESS_STAFF,
                status=UserStatus.INVITED,
                is_email_verified=False,
            )
            db_session.add(user)

        code = await generate_and_store_otp(
            db_session,
            user_id=user.id,
            purpose=VerificationCodePurpose.LOGIN,
            delivery_type=VerificationCodeType.EMAIL,
        )

        resp = await client.post(
            "/api/v1/auth/otp/email/verify",
            json={"email": email, "code": code},
        )
        assert resp.status_code == 200, resp.text
        assert "access_token" in resp.json()
        assert "refresh_token" in resp.json()

        refreshed = (await db_session.exec(select(User).where(User.id == user.id))).one()
        await db_session.refresh(refreshed)
        assert refreshed.status == UserStatus.ACTIVE
        assert refreshed.is_email_verified is True

    async def test_verify_wrong_code_returns_401(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        email = _valid_email()
        async with db_session.begin():
            user = User(
                phone=_valid_phone(),
                email=email,
                full_name="Email User",
                user_category=UserCategory.BUSINESS_STAFF,
            )
            db_session.add(user)

        await generate_and_store_otp(
            db_session,
            user_id=user.id,
            purpose=VerificationCodePurpose.LOGIN,
            delivery_type=VerificationCodeType.EMAIL,
        )

        resp = await client.post(
            "/api/v1/auth/otp/email/verify",
            json={"email": email, "code": "999999"},
        )
        assert resp.status_code == 401

    async def test_request_ignores_platform_staff(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        """Platform staff must not receive business-staff login codes."""
        email = _valid_email()
        async with db_session.begin():
            user = User(
                phone=_valid_phone(),
                email=email,
                full_name="Platform Admin",
                user_category=UserCategory.PLATFORM_STAFF,
            )
            db_session.add(user)

        resp = await client.post(
            "/api/v1/auth/otp/email/request",
            json={"email": email},
        )
        assert resp.status_code == 204

        code = (
            await db_session.exec(
                select(VerificationCode).where(
                    VerificationCode.user_id == user.id,
                )
            )
        ).one_or_none()
        assert code is None

    async def test_verify_rejects_platform_staff(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        """A valid code still cannot mint tokens for a platform-staff account."""
        email = _valid_email()
        async with db_session.begin():
            user = User(
                phone=_valid_phone(),
                email=email,
                full_name="Platform Admin",
                user_category=UserCategory.PLATFORM_STAFF,
            )
            db_session.add(user)

        code = await generate_and_store_otp(
            db_session,
            user_id=user.id,
            purpose=VerificationCodePurpose.LOGIN,
            delivery_type=VerificationCodeType.EMAIL,
        )

        resp = await client.post(
            "/api/v1/auth/otp/email/verify",
            json={"email": email, "code": code},
        )
        assert resp.status_code == 401

    async def test_request_email_limit_exceeded(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        """Repeated requests for the same email hit the email-based limit."""
        email = _valid_email()
        async with db_session.begin():
            user = User(
                phone=_valid_phone(),
                email=email,
                full_name="Email Rate Limit User",
                user_category=UserCategory.BUSINESS_STAFF,
            )
            db_session.add(user)

        for _ in range(RATE_LIMIT_OTP_REQUEST_EMAIL_LIMIT):
            resp = await client.post(
                "/api/v1/auth/otp/email/request",
                json={"email": email},
            )
            assert resp.status_code == 204

        resp = await client.post(
            "/api/v1/auth/otp/email/request",
            json={"email": email},
        )
        assert resp.status_code == 429
        assert "Retry-After" in resp.headers


class TestPasswordLogin:
    async def test_correct_credentials_returns_tokens(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        phone = _valid_phone()
        async with db_session.begin():
            user = User(
                phone=phone,
                full_name="Password User",
                user_category=UserCategory.BUSINESS_STAFF,
                password_hash=hash_password(_TEST_PASSWORD),
            )
            db_session.add(user)

        resp = await client.post(
            "/api/v1/auth/login/password",
            json={"phone": phone, "password": _TEST_PASSWORD},
        )
        assert resp.status_code == 200
        data = resp.json()
        assert "access_token" in data
        assert "refresh_token" in data

    async def test_wrong_password_returns_401(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        phone = _valid_phone()
        async with db_session.begin():
            user = User(
                phone=phone,
                full_name="Password User",
                user_category=UserCategory.BUSINESS_STAFF,
                password_hash=hash_password(_TEST_PASSWORD),
            )
            db_session.add(user)

        resp = await client.post(
            "/api/v1/auth/login/password",
            json={"phone": phone, "password": "WrongPass1"},
        )
        assert resp.status_code == 401

    async def test_nonexistent_phone_returns_401(
        self,
        client: AsyncClient,
        db_session: AsyncSession,
    ) -> None:
        resp = await client.post(
            "/api/v1/auth/login/password",
            json={"phone": "+255712345678", "password": _TEST_PASSWORD},
        )
        assert resp.status_code == 401

    async def test_invited_user_without_password_login_returns_401_not_500(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        phone = _valid_phone()
        async with db_session.begin():
            user = User(
                phone=phone,
                full_name="",
                user_category=UserCategory.BUSINESS_STAFF,
                status=UserStatus.INVITED,
                password_hash=None,
            )
            db_session.add(user)

        resp = await client.post(
            "/api/v1/auth/login/password",
            json={"phone": phone, "password": _TEST_PASSWORD},
        )
        assert resp.status_code == 401
        assert "invalid" in resp.json()["detail"].lower()

    async def test_deactivated_account_cannot_login(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        phone = _valid_phone()
        async with db_session.begin():
            user = User(
                phone=phone,
                full_name="Deactivated User",
                user_category=UserCategory.BUSINESS_STAFF,
                password_hash=hash_password(_TEST_PASSWORD),
                is_active=False,
            )
            db_session.add(user)

        resp = await client.post(
            "/api/v1/auth/login/password",
            json={"phone": phone, "password": _TEST_PASSWORD},
        )
        assert resp.status_code == 401
        assert "invalid" in resp.json()["detail"].lower()

    async def test_suspended_account_cannot_login(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        phone = _valid_phone()
        async with db_session.begin():
            user = User(
                phone=phone,
                full_name="Suspended User",
                user_category=UserCategory.BUSINESS_STAFF,
                password_hash=hash_password(_TEST_PASSWORD),
                status=UserStatus.SUSPENDED,
            )
            db_session.add(user)

        resp = await client.post(
            "/api/v1/auth/login/password",
            json={"phone": phone, "password": _TEST_PASSWORD},
        )
        assert resp.status_code == 401
        assert "invalid" in resp.json()["detail"].lower()


class TestPasswordReset:
    async def test_full_reset_flow(self, client: AsyncClient, db_session: AsyncSession) -> None:
        phone = _valid_phone()
        async with db_session.begin():
            user = User(
                phone=phone,
                full_name="Reset User",
                user_category=UserCategory.BUSINESS_STAFF,
                password_hash=hash_password("OldPass1"),
            )
            db_session.add(user)

        resp = await client.post(
            "/api/v1/auth/password/reset/request",
            json={"phone": phone},
        )
        assert resp.status_code == 204

        code = await generate_and_store_otp(
            db_session,
            user_id=user.id,
            purpose=VerificationCodePurpose.PASSWORD_RESET,
            delivery_type=VerificationCodeType.SMS,
        )

        resp = await client.post(
            "/api/v1/auth/password/reset/confirm",
            json={"phone": phone, "code": code, "new_password": "NewPass1"},
        )
        assert resp.status_code == 200, resp.text
        data = resp.json()
        assert "access_token" in data
        assert "refresh_token" in data

        resp = await client.post(
            "/api/v1/auth/login/password",
            json={"phone": phone, "password": "NewPass1"},
        )
        assert resp.status_code == 200

        resp = await client.post(
            "/api/v1/auth/login/password",
            json={"phone": phone, "password": "OldPass1"},
        )
        assert resp.status_code == 401


class TestRefreshToken:
    async def test_refresh_rotation(self, client: AsyncClient, db_session: AsyncSession) -> None:
        phone = _valid_phone()
        async with db_session.begin():
            user = User(
                phone=phone,
                full_name="Refresh User",
                user_category=UserCategory.BUSINESS_STAFF,
                password_hash=hash_password(_TEST_PASSWORD),
            )
            db_session.add(user)

        login_resp = await client.post(
            "/api/v1/auth/login/password",
            json={"phone": phone, "password": _TEST_PASSWORD},
        )
        assert login_resp.status_code == 200
        old_refresh = login_resp.json()["refresh_token"]

        refresh_resp = await client.post(
            "/api/v1/auth/refresh",
            json={"refresh_token": old_refresh},
        )
        assert refresh_resp.status_code == 200
        new_data = refresh_resp.json()
        assert new_data["refresh_token"] != old_refresh

        reauth_resp = await client.post(
            "/api/v1/auth/refresh",
            json={"refresh_token": old_refresh},
        )
        assert reauth_resp.status_code == 401

    async def test_deactivated_account_cannot_refresh_or_use_access_token(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        phone = _valid_phone()
        async with db_session.begin():
            user = User(
                phone=phone,
                full_name="Refresh Deactivated",
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
        access_token = login_resp.json()["access_token"]

        async with db_session.begin():
            row = (
                await db_session.exec(select(User).where(User.phone == phone))
            ).one()
            row.is_active = False
            db_session.add(row)

        refresh_resp = await client.post(
            "/api/v1/auth/refresh",
            json={"refresh_token": refresh_token},
        )
        assert refresh_resp.status_code == 401

        me_resp = await client.get(
            "/api/v1/users/me/onboarding-status",
            headers={"Authorization": f"Bearer {access_token}"},
        )
        assert me_resp.status_code == 401


class TestLogout:
    async def test_logout_revokes_session(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        phone = _valid_phone()
        async with db_session.begin():
            user = User(
                phone=phone,
                full_name="Logout User",
                user_category=UserCategory.BUSINESS_STAFF,
                password_hash=hash_password(_TEST_PASSWORD),
            )
            db_session.add(user)

        login_resp = await client.post(
            "/api/v1/auth/login/password",
            json={"phone": phone, "password": _TEST_PASSWORD},
        )
        assert login_resp.status_code == 200
        tokens = login_resp.json()

        logout_resp = await client.post(
            "/api/v1/auth/logout",
            json={"refresh_token": tokens["refresh_token"]},
            headers={"Authorization": f"Bearer {tokens['access_token']}"},
        )
        assert logout_resp.status_code == 204

        reuse_resp = await client.post(
            "/api/v1/auth/refresh",
            json={"refresh_token": tokens["refresh_token"]},
        )
        assert reuse_resp.status_code == 401


class TestSessions:
    async def test_list_sessions_returns_only_own(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        phone1 = _valid_phone()
        phone2 = _valid_phone()

        async with db_session.begin():
            user1 = User(
                phone=phone1,
                full_name="User One",
                user_category=UserCategory.BUSINESS_STAFF,
                password_hash=hash_password(_TEST_PASSWORD),
            )
            user2 = User(
                phone=phone2,
                full_name="User Two",
                user_category=UserCategory.BUSINESS_STAFF,
                password_hash=hash_password(_TEST_PASSWORD),
            )
            db_session.add(user1)
            db_session.add(user2)

        login1 = await client.post(
            "/api/v1/auth/login/password",
            json={"phone": phone1, "password": _TEST_PASSWORD},
        )
        token1 = login1.json()["access_token"]

        login2 = await client.post(
            "/api/v1/auth/login/password",
            json={"phone": phone2, "password": _TEST_PASSWORD},
        )
        token2 = login2.json()["access_token"]

        sessions1 = await client.get(
            "/api/v1/auth/sessions",
            headers={"Authorization": f"Bearer {token1}"},
        )
        assert sessions1.status_code == 200
        data1 = sessions1.json()
        for s in data1:
            assert s["user_id"] == str(user1.id)

        sessions2 = await client.get(
            "/api/v1/auth/sessions",
            headers={"Authorization": f"Bearer {token2}"},
        )
        data2 = sessions2.json()
        for s in data2:
            assert s["user_id"] == str(user2.id)

    async def test_delete_other_users_session_returns_403(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        phone1 = _valid_phone()
        phone2 = _valid_phone()

        async with db_session.begin():
            user1 = User(
                phone=phone1,
                full_name="User One",
                user_category=UserCategory.BUSINESS_STAFF,
                password_hash=hash_password(_TEST_PASSWORD),
            )
            user2 = User(
                phone=phone2,
                full_name="User Two",
                user_category=UserCategory.BUSINESS_STAFF,
                password_hash=hash_password(_TEST_PASSWORD),
            )
            db_session.add(user1)
            db_session.add(user2)

        login1 = await client.post(
            "/api/v1/auth/login/password",
            json={"phone": phone1, "password": _TEST_PASSWORD},
        )
        token1 = login1.json()["access_token"]

        login2 = await client.post(
            "/api/v1/auth/login/password",
            json={"phone": phone2, "password": _TEST_PASSWORD},
        )

        sessions2 = await client.get(
            "/api/v1/auth/sessions",
            headers={"Authorization": f"Bearer {login2.json()['access_token']}"},
        )
        data2 = sessions2.json()

        for s in data2:
            resp = await client.delete(
                f"/api/v1/auth/sessions/{s['id']}",
                headers={"Authorization": f"Bearer {token1}"},
            )
            assert resp.status_code == 403


class TestContextSwitch:
    async def test_switch_to_unowned_business_returns_403(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        from app.models.business import Business, BusinessType

        phone = _valid_phone()

        async with db_session.begin():
            user = User(
                phone=phone,
                full_name="Switch User",
                user_category=UserCategory.BUSINESS_STAFF,
                password_hash=hash_password(_TEST_PASSWORD),
            )
            db_session.add(user)

        async with db_session.begin():
            biz = Business(
                name="Test Business",
                business_type=BusinessType.RESTAURANT,
                owner_user_id=user.id,
                country_code="TZ",
            )
            db_session.add(biz)

        login_resp = await client.post(
            "/api/v1/auth/login/password",
            json={"phone": phone, "password": _TEST_PASSWORD},
        )
        token = login_resp.json()["access_token"]

        resp = await client.post(
            "/api/v1/auth/context/switch",
            json={"business_id": str(biz.id)},
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 403


class TestStoreContextSwitch:
    @staticmethod
    async def _owner_with_stores(
        db_session: AsyncSession,
        phone: str,
        *,
        with_switch_perm: bool = True,
        perm: str | None = None,
    ):
        from uuid import uuid4

        from app.models.business import (
            Business,
            BusinessRole,
            BusinessRolePermission,
            BusinessType,
            LocationType,
            Store,
            UserBusinessRole,
        )

        async with db_session.begin():
            user = User(
                phone=phone,
                full_name="Store Switcher",
                user_category=UserCategory.BUSINESS_STAFF,
                password_hash=hash_password(_TEST_PASSWORD),
            )
            db_session.add(user)

        async with db_session.begin():
            biz = Business(
                name="Switch Business",
                business_type=BusinessType.RESTAURANT,
                owner_user_id=user.id,
                country_code="TZ",
            )
            db_session.add(biz)

        async with db_session.begin():
            role = BusinessRole(business_id=biz.id, name="Manager")
            db_session.add(role)

        async with db_session.begin():
            db_session.add(
                BusinessRolePermission(
                    business_role_id=role.id,
                    permission_code=(
                        perm
                        if perm is not None
                        else ("stores.switch" if with_switch_perm else "pos.view")
                    ),
                )
            )
            db_session.add(
                UserBusinessRole(
                    user_id=user.id,
                    business_id=biz.id,
                    business_role_id=role.id,
                )
            )

        async with db_session.begin():
            store_a = Store(
                business_id=biz.id,
                name="Store A",
                token=f"sw-a-{uuid4().hex[:12]}",
                location_type=LocationType.RESTAURANT_BRANCH,
            )
            store_b = Store(
                business_id=biz.id,
                name="Store B",
                token=f"sw-b-{uuid4().hex[:12]}",
                location_type=LocationType.RESTAURANT_BRANCH,
            )
            db_session.add(store_a)
            db_session.add(store_b)

        return user, biz, store_a, store_b

    async def _login(self, client: AsyncClient, phone: str) -> str:
        resp = await client.post(
            "/api/v1/auth/login/password",
            json={"phone": phone, "password": _TEST_PASSWORD},
        )
        assert resp.status_code == 200
        return resp.json()["access_token"]

    @staticmethod
    async def _login_scoped(client: AsyncClient, phone: str, business_id: UUID) -> str:
        """Login, then bind the token to a business.

        Business-staff login tokens deliberately start with no active
        business context; the store-switch endpoint requires one, so the
        documented flow is login -> /auth/context/switch -> switch-store.
        """
        resp = await client.post(
            "/api/v1/auth/login/password",
            json={"phone": phone, "password": _TEST_PASSWORD},
        )
        assert resp.status_code == 200
        token = resp.json()["access_token"]

        resp = await client.post(
            "/api/v1/auth/context/switch",
            json={"business_id": str(business_id)},
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 200
        return resp.json()["access_token"]

    async def test_switch_store_success_returns_store_scoped_token(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        import jwt

        phone = _valid_phone()
        _, biz, _, store_b = await self._owner_with_stores(db_session, phone)
        token = await self._login_scoped(client, phone, biz.id)

        resp = await client.post(
            "/api/v1/auth/context/switch-store",
            json={"store_id": str(store_b.id)},
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 200
        data = resp.json()
        assert "access_token" in data and "refresh_token" in data

        claims = jwt.decode(data["access_token"], options={"verify_signature": False})
        assert claims["active_store_id"] == str(store_b.id)
        assert claims["active_business_id"] == str(biz.id)
        assert "stores.switch" in claims["permissions"]

    async def test_switch_store_without_permission_returns_403(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        phone = _valid_phone()
        _, biz, _, store_b = await self._owner_with_stores(
            db_session, phone, with_switch_perm=False
        )
        token = await self._login_scoped(client, phone, biz.id)

        resp = await client.post(
            "/api/v1/auth/context/switch-store",
            json={"store_id": str(store_b.id)},
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 403

    async def test_switch_store_as_store_staff_returns_403(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        phone = _valid_phone()
        _, _, _, store_b = await self._owner_with_stores(db_session, _valid_phone())

        async with db_session.begin():
            staffer = User(
                phone=phone,
                full_name="Store Staffer",
                user_category=UserCategory.BUSINESS_STORE_STAFF,
                password_hash=hash_password(_TEST_PASSWORD),
            )
            db_session.add(staffer)

        token = await self._login(client, phone)

        resp = await client.post(
            "/api/v1/auth/context/switch-store",
            json={"store_id": str(store_b.id)},
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 403

    async def test_switch_store_other_business_returns_403(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        phone = _valid_phone()
        _, biz, _, _ = await self._owner_with_stores(db_session, phone)
        _, _, _, foreign_store = await self._owner_with_stores(db_session, _valid_phone())
        token = await self._login_scoped(client, phone, biz.id)

        resp = await client.post(
            "/api/v1/auth/context/switch-store",
            json={"store_id": str(foreign_store.id)},
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 403

    async def test_switch_store_missing_returns_404(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        from uuid import uuid4

        phone = _valid_phone()
        _, biz, _, _ = await self._owner_with_stores(db_session, phone)
        token = await self._login_scoped(client, phone, biz.id)

        resp = await client.post(
            "/api/v1/auth/context/switch-store",
            json={"store_id": str(uuid4())},
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 404


class TestCreateStoreConflict:
    async def test_duplicate_store_name_returns_409_not_500(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        phone = _valid_phone()
        _, biz, store_a, _ = await TestStoreContextSwitch._owner_with_stores(
            db_session, phone, perm="stores.create"
        )
        token = await TestStoreContextSwitch._login_scoped(client, phone, biz.id)

        resp = await client.post(
            f"/api/v1/businesses/{biz.id}/stores",
            json={
                "name": "Store A",
                "location_type": "restaurant_branch",
                "status": "active",
            },
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 409
        assert "already exists" in resp.json()["detail"]
        assert store_a.name == "Store A"


class TestRateLimits:
    """Tests for rate-limiting on auth endpoints."""

    async def test_login_password_phone_limit_exceeded(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        """Repeated wrong password on same phone hits phone-based limit."""
        phone = _valid_phone()
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
                json={"phone": phone, "password": "WrongPass1"},
            )
            assert resp.status_code == 401

        # Next request should be rate-limited (429)
        resp = await client.post(
            "/api/v1/auth/login/password",
            json={"phone": phone, "password": "WrongPass1"},
        )
        assert resp.status_code == 429
        assert "Retry-After" in resp.headers
        assert resp.json()["detail"] == "Too many attempts, please try again later"

    async def test_login_password_different_phone_not_blocked(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        """A different phone is not affected by another phone's limit."""
        phone1 = _valid_phone()
        phone2 = _valid_phone()
        async with db_session.begin():
            user1 = User(
                phone=phone1,
                full_name="User One",
                user_category=UserCategory.BUSINESS_STAFF,
                password_hash=hash_password(_TEST_PASSWORD),
            )
            user2 = User(
                phone=phone2,
                full_name="User Two",
                user_category=UserCategory.BUSINESS_STAFF,
                password_hash=hash_password(_TEST_PASSWORD),
            )
            db_session.add(user1)
            db_session.add(user2)

        # Exhaust limit on phone1
        for _ in range(RATE_LIMIT_LOGIN_PASSWORD_PHONE_LIMIT):
            await client.post(
                "/api/v1/auth/login/password",
                json={"phone": phone1, "password": "WrongPass1"},
            )

        # phone2 should still work
        resp = await client.post(
            "/api/v1/auth/login/password",
            json={"phone": phone2, "password": _TEST_PASSWORD},
        )
        assert resp.status_code == 200

    async def test_otp_request_phone_limit_exceeded(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        """Repeated OTP requests on same phone hits phone-based limit."""
        phone = _valid_phone()
        async with db_session.begin():
            user = User(
                phone=phone,
                full_name="OTP Rate Limit User",
                user_category=UserCategory.BUSINESS_STAFF,
            )
            db_session.add(user)

        for _ in range(RATE_LIMIT_OTP_REQUEST_PHONE_LIMIT):
            resp = await client.post(
                "/api/v1/auth/otp/request",
                json={"phone": phone},
            )
            assert resp.status_code == 204

        # Next request should be rate-limited
        resp = await client.post(
            "/api/v1/auth/otp/request",
            json={"phone": phone},
        )
        assert resp.status_code == 429
        assert "Retry-After" in resp.headers

    async def test_otp_request_different_phone_not_blocked(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        """A different phone is not affected by another phone's OTP limit."""
        phone1 = _valid_phone()
        phone2 = _valid_phone()
        async with db_session.begin():
            user1 = User(
                phone=phone1,
                full_name="User One",
                user_category=UserCategory.BUSINESS_STAFF,
            )
            user2 = User(
                phone=phone2,
                full_name="User Two",
                user_category=UserCategory.BUSINESS_STAFF,
            )
            db_session.add(user1)
            db_session.add(user2)

        for _ in range(RATE_LIMIT_OTP_REQUEST_PHONE_LIMIT):
            await client.post("/api/v1/auth/otp/request", json={"phone": phone1})

        resp = await client.post("/api/v1/auth/otp/request", json={"phone": phone2})
        assert resp.status_code == 204

    async def test_password_reset_request_phone_limit_exceeded(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        """Repeated password reset requests on same phone hits phone-based limit."""
        phone = _valid_phone()
        async with db_session.begin():
            user = User(
                phone=phone,
                full_name="Reset Rate Limit User",
                user_category=UserCategory.BUSINESS_STAFF,
                password_hash=hash_password(_TEST_PASSWORD),
            )
            db_session.add(user)

        for _ in range(RATE_LIMIT_PASSWORD_RESET_REQUEST_PHONE_LIMIT):
            resp = await client.post(
                "/api/v1/auth/password/reset/request",
                json={"phone": phone},
            )
            assert resp.status_code == 204

        resp = await client.post(
            "/api/v1/auth/password/reset/request",
            json={"phone": phone},
        )
        assert resp.status_code == 429
        assert "Retry-After" in resp.headers

    async def test_refresh_ip_limit_exceeded(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        """Repeated refresh requests from same IP hits IP-based limit."""
        phone = _valid_phone()
        async with db_session.begin():
            user = User(
                phone=phone,
                full_name="Refresh Rate Limit User",
                user_category=UserCategory.BUSINESS_STAFF,
                password_hash=hash_password(_TEST_PASSWORD),
            )
            db_session.add(user)

        # First, login to get a valid refresh token
        login_resp = await client.post(
            "/api/v1/auth/login/password",
            json={"phone": phone, "password": _TEST_PASSWORD},
        )
        assert login_resp.status_code == 200
        refresh_token = login_resp.json()["refresh_token"]

        # Use refresh up to the limit
        for _ in range(RATE_LIMIT_REFRESH_IP_LIMIT):
            resp = await client.post(
                "/api/v1/auth/refresh",
                json={"refresh_token": refresh_token},
            )
            assert resp.status_code == 200
            # rotate token for next attempt
            refresh_token = resp.json()["refresh_token"]

        # Next refresh should be rate-limited
        resp = await client.post(
            "/api/v1/auth/refresh",
            json={"refresh_token": refresh_token},
        )
        assert resp.status_code == 429
        assert "Retry-After" in resp.headers
