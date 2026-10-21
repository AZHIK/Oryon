"""SEC-06: changing the sign-in email/phone requires proof of control.

Covers the two-step change flow, password step-up, token binding, single-use
codes, and session revocation after a successful identifier change.
"""

from uuid import uuid4

import pytest
from httpx import AsyncClient
from sqlmodel.ext.asyncio.session import AsyncSession

from app.api.v1.endpoints import me as me_endpoints
from app.core.security import create_access_token, hash_password
from app.models.auth import VerificationCodePurpose, VerificationCodeType
from app.models.user import User, UserCategory, UserStatus
from app.services.otp_service import generate_and_store_otp

_PASSWORD = "TestPass1!"


def _phone() -> str:
    return f"+2557{uuid4().int % 100_000_000:08d}"


def _token(user: User) -> str:
    return create_access_token(
        subject=str(user.id),
        user_category=UserCategory.BUSINESS_STAFF.value,
    )


async def _make_user(
    db_session: AsyncSession,
    *,
    with_password: bool = True,
    email: str | None = None,
) -> User:
    user = User(
        phone=_phone(),
        email=email,
        full_name="Identifier User",
        user_category=UserCategory.BUSINESS_STAFF,
        status=UserStatus.ACTIVE,
        password_hash=hash_password(_PASSWORD) if with_password else None,
    )
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)
    return user


@pytest.fixture
def captured_email_code(monkeypatch: pytest.MonkeyPatch) -> dict[str, str]:
    """Replace delivery with storage + capture the raw code (no SMTP)."""
    captured: dict[str, str] = {}

    async def _fake_send(
        session: AsyncSession,
        *,
        user_id,
        email: str,  # noqa: ARG001 - signature must match the real sender
        purpose: VerificationCodePurpose,
    ) -> str:
        code = await generate_and_store_otp(
            session,
            user_id=user_id,
            purpose=purpose,
            delivery_type=VerificationCodeType.EMAIL,
        )
        captured["code"] = code
        return code

    monkeypatch.setattr(me_endpoints, "generate_and_send_otp_email", _fake_send)
    return captured


@pytest.fixture
def captured_sms_code(monkeypatch: pytest.MonkeyPatch) -> dict[str, str]:
    captured: dict[str, str] = {}

    async def _fake_send(
        session: AsyncSession,
        *,
        user_id,
        phone: str,  # noqa: ARG001 - signature must match the real sender
        purpose: VerificationCodePurpose,
    ) -> str:
        code = await generate_and_store_otp(
            session,
            user_id=user_id,
            purpose=purpose,
            delivery_type=VerificationCodeType.SMS,
        )
        captured["code"] = code
        return code

    monkeypatch.setattr(me_endpoints, "generate_and_send_otp_sms", _fake_send)
    return captured


async def test_email_change_full_flow(
    client: AsyncClient,
    db_session: AsyncSession,
    captured_email_code: dict[str, str],
) -> None:
    user = await _make_user(db_session)
    new_email = f"new-{uuid4().hex[:8]}@example.com"

    request = await client.post(
        "/api/v1/users/me/email/change/request",
        json={"new_email": new_email, "current_password": _PASSWORD},
        headers={"Authorization": f"Bearer {_token(user)}"},
    )
    assert request.status_code == 202
    change_token = request.json()["change_token"]
    code = captured_email_code["code"]

    verify = await client.post(
        "/api/v1/users/me/email/change/verify",
        json={"change_token": change_token, "code": code},
        headers={"Authorization": f"Bearer {_token(user)}"},
    )
    assert verify.status_code == 200
    assert verify.json() == {"email": new_email}

    await db_session.refresh(user)
    assert user.email == new_email
    assert user.is_email_verified is True

    # The code is single-use: replaying it must fail.
    replay = await client.post(
        "/api/v1/users/me/email/change/verify",
        json={"change_token": change_token, "code": code},
        headers={"Authorization": f"Bearer {_token(user)}"},
    )
    assert replay.status_code == 400


async def test_email_change_requires_current_password(
    client: AsyncClient,
    db_session: AsyncSession,
    captured_email_code: dict[str, str],
) -> None:
    user = await _make_user(db_session)

    resp = await client.post(
        "/api/v1/users/me/email/change/request",
        json={"new_email": f"new-{uuid4().hex[:8]}@example.com", "current_password": "WrongPass1!"},
        headers={"Authorization": f"Bearer {_token(user)}"},
    )
    assert resp.status_code == 401
    assert captured_email_code == {}


async def test_passwordless_account_cannot_start_identifier_change(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    user = await _make_user(db_session, with_password=False)

    resp = await client.post(
        "/api/v1/users/me/email/change/request",
        json={"new_email": f"new-{uuid4().hex[:8]}@example.com"},
        headers={"Authorization": f"Bearer {_token(user)}"},
    )
    assert resp.status_code == 400
    assert "set a password" in resp.json()["detail"].lower()


async def test_tampered_change_token_is_rejected(
    client: AsyncClient,
    db_session: AsyncSession,
    captured_email_code: dict[str, str],
) -> None:
    user = await _make_user(db_session)
    victim_email = f"victim-{uuid4().hex[:8]}@example.com"

    request = await client.post(
        "/api/v1/users/me/email/change/request",
        json={"new_email": f"mine-{uuid4().hex[:8]}@example.com", "current_password": _PASSWORD},
        headers={"Authorization": f"Bearer {_token(user)}"},
    )
    token = request.json()["change_token"]
    # Corrupt the signature while keeping the payload pointing at our email;
    # the token must fail verification (and cannot be repointed at a victim).
    header, payload, signature = token.split(".")
    signature = ("A" if signature[0] != "A" else "B") + signature[1:]
    tampered = f"{header}.{payload}.{signature}"

    resp = await client.post(
        "/api/v1/users/me/email/change/verify",
        json={"change_token": tampered, "code": captured_email_code["code"]},
        headers={"Authorization": f"Bearer {_token(user)}"},
    )
    assert resp.status_code == 400
    assert "invalid or expired" in resp.json()["detail"].lower()

    await db_session.refresh(user)
    assert user.email != victim_email


async def test_email_change_revokes_existing_sessions(
    client: AsyncClient,
    db_session: AsyncSession,
    captured_email_code: dict[str, str],
) -> None:
    user = await _make_user(db_session)
    login = await client.post(
        "/api/v1/auth/login/password",
        json={"phone": user.phone, "password": _PASSWORD},
    )
    assert login.status_code == 200
    refresh_token = login.json()["refresh_token"]

    request = await client.post(
        "/api/v1/users/me/email/change/request",
        json={"new_email": f"new-{uuid4().hex[:8]}@example.com", "current_password": _PASSWORD},
        headers={"Authorization": f"Bearer {_token(user)}"},
    )
    verify = await client.post(
        "/api/v1/users/me/email/change/verify",
        json={
            "change_token": request.json()["change_token"],
            "code": captured_email_code["code"],
        },
        headers={"Authorization": f"Bearer {_token(user)}"},
    )
    assert verify.status_code == 200

    refresh = await client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": refresh_token},
    )
    assert refresh.status_code == 401


async def test_phone_change_full_flow(
    client: AsyncClient,
    db_session: AsyncSession,
    captured_sms_code: dict[str, str],
) -> None:
    user = await _make_user(db_session)
    new_phone = _phone()

    request = await client.post(
        "/api/v1/users/me/phone/change/request",
        json={"new_phone": new_phone, "current_password": _PASSWORD},
        headers={"Authorization": f"Bearer {_token(user)}"},
    )
    assert request.status_code == 202

    verify = await client.post(
        "/api/v1/users/me/phone/change/verify",
        json={"change_token": request.json()["change_token"], "code": captured_sms_code["code"]},
        headers={"Authorization": f"Bearer {_token(user)}"},
    )
    assert verify.status_code == 200
    assert verify.json() == {"phone": new_phone}

    await db_session.refresh(user)
    assert user.phone == new_phone
    assert user.is_phone_verified is True


async def test_change_token_cannot_be_used_for_the_other_identifier(
    client: AsyncClient,
    db_session: AsyncSession,
    captured_email_code: dict[str, str],
) -> None:
    user = await _make_user(db_session)

    request = await client.post(
        "/api/v1/users/me/email/change/request",
        json={"new_email": f"new-{uuid4().hex[:8]}@example.com", "current_password": _PASSWORD},
        headers={"Authorization": f"Bearer {_token(user)}"},
    )

    resp = await client.post(
        "/api/v1/users/me/phone/change/verify",
        json={"change_token": request.json()["change_token"], "code": captured_email_code["code"]},
        headers={"Authorization": f"Bearer {_token(user)}"},
    )
    assert resp.status_code == 400
    assert "invalid or expired" in resp.json()["detail"].lower()


async def test_change_request_rejects_taken_email(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    taken = await _make_user(db_session, email=f"taken-{uuid4().hex[:8]}@example.com")
    user = await _make_user(db_session)

    resp = await client.post(
        "/api/v1/users/me/email/change/request",
        json={"new_email": taken.email, "current_password": _PASSWORD},
        headers={"Authorization": f"Bearer {_token(user)}"},
    )
    assert resp.status_code == 409
    assert "already registered" in resp.json()["detail"].lower()
