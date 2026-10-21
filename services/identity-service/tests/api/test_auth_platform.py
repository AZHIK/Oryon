"""Integration tests for the platform-staff auth API."""

from uuid import uuid4

from httpx import AsyncClient
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.config import (
    RATE_LIMIT_PLATFORM_LOGIN_EMAIL_LIMIT,
    RATE_LIMIT_PLATFORM_LOGIN_IP_LIMIT,
)
from app.core.security import create_access_token, hash_password
from app.models.internal import Group, Role, RolePermission, UserGroup
from app.models.user import User, UserCategory, UserStatus

_TEST_PASSWORD = "StrongPass1!"


def _platform_phone() -> str:
    return f"+2556{uuid4().int % 100_000_000:08d}"


async def _create_admin_token(db_session: AsyncSession) -> str:
    async with db_session.begin():
        user = User(
            phone="+255700000001",
            email="admin@oryonfoods.com",
            full_name="Admin User",
            user_category=UserCategory.PLATFORM_STAFF,
            status=UserStatus.ACTIVE,
            is_email_verified=True,
        )
        db_session.add(user)

    return create_access_token(
        subject=str(user.id),
        user_category=UserCategory.PLATFORM_STAFF.value,
        roles=["admin"],
        permissions=["*"],
    )


async def _create_non_admin_token(db_session: AsyncSession) -> str:
    async with db_session.begin():
        user = User(
            phone="+255700000002",
            email="staff@oryonfoods.com",
            full_name="Staff User",
            user_category=UserCategory.PLATFORM_STAFF,
            status=UserStatus.ACTIVE,
            is_email_verified=True,
        )
        db_session.add(user)

    return create_access_token(
        subject=str(user.id),
        user_category=UserCategory.PLATFORM_STAFF.value,
        roles=["viewer"],
        permissions=["*"],
    )


class TestPlatformRegister:
    async def test_unauthenticated_register_returns_401(
        self,
        client: AsyncClient,
        db_session: AsyncSession,
    ) -> None:
        resp = await client.post(
            "/api/v1/auth/platform/register",
            json={
                "email": "newstaff@oryonfoods.com",
                "full_name": "New Staff",
                "password": "StrongPass1!",
                "group_id": str(uuid4()),
            },
        )
        assert resp.status_code == 401

    async def test_non_admin_user_returns_403(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        token = await _create_non_admin_token(db_session)

        resp = await client.post(
            "/api/v1/auth/platform/register",
            json={
                "email": "newstaff2@oryonfoods.com",
                "full_name": "New Staff",
                "password": "StrongPass1!",
                "group_id": str(uuid4()),
            },
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 403

    async def test_register_by_admin_succeeds(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        async with db_session.begin():
            group = Group(name=f"admins_{uuid4().hex[:8]}")
            db_session.add(group)

        admin_token = await _create_admin_token(db_session)

        email = f"staff{uuid4().hex[:8]}@oryonfoods.com"
        resp = await client.post(
            "/api/v1/auth/platform/register",
            json={
                "email": email,
                "full_name": "New Staff Member",
                "password": "StrongPass1!",
                "group_id": str(group.id),
            },
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert resp.status_code == 201, resp.text
        data = resp.json()
        assert "access_token" in data
        assert "refresh_token" in data

    async def test_duplicate_email_returns_409(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        async with db_session.begin():
            group = Group(name=f"admins_{uuid4().hex[:8]}")
            db_session.add(group)

        admin_token = await _create_admin_token(db_session)
        email = f"dup{uuid4().hex[:8]}@oryonfoods.com"

        resp = await client.post(
            "/api/v1/auth/platform/register",
            json={
                "email": email,
                "full_name": "First",
                "password": "StrongPass1!",
                "group_id": str(group.id),
            },
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert resp.status_code == 201

        resp = await client.post(
            "/api/v1/auth/platform/register",
            json={
                "email": email,
                "full_name": "Second",
                "password": "StrongPass1!",
                "group_id": str(group.id),
            },
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert resp.status_code == 409


class TestPlatformLogin:
    async def test_correct_credentials_returns_tokens_with_group_roles(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        async with db_session.begin():
            group = Group(name=f"analysts_{uuid4().hex[:8]}")
            db_session.add(group)

        async with db_session.begin():
            role = Role(name="analyst", group_id=group.id)
            db_session.add(role)
            rp = RolePermission(role_id=role.id, permission_code="reports.view")
            db_session.add(rp)

        async with db_session.begin():
            user = User(
                phone=_platform_phone(),
                email=f"analyst{uuid4().hex[:8]}@oryonfoods.com",
                full_name="Analyst User",
                user_category=UserCategory.PLATFORM_STAFF,
                status=UserStatus.ACTIVE,
                password_hash=hash_password(_TEST_PASSWORD),
                is_email_verified=True,
            )
            db_session.add(user)

        async with db_session.begin():
            ug = UserGroup(user_id=user.id, group_id=group.id)
            db_session.add(ug)

        resp = await client.post(
            "/api/v1/auth/platform/login",
            json={"email": user.email, "password": _TEST_PASSWORD},
        )
        assert resp.status_code == 200, resp.text
        data = resp.json()
        assert "access_token" in data
        assert "refresh_token" in data

    async def test_wrong_password_returns_401(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        async with db_session.begin():
            user = User(
                phone=_platform_phone(),
                email=f"badlogin{uuid4().hex[:8]}@oryonfoods.com",
                full_name="Bad Login",
                user_category=UserCategory.PLATFORM_STAFF,
                status=UserStatus.ACTIVE,
                password_hash=hash_password(_TEST_PASSWORD),
                is_email_verified=True,
            )
            db_session.add(user)

        resp = await client.post(
            "/api/v1/auth/platform/login",
            json={"email": user.email, "password": "WrongPass1!"},
        )
        assert resp.status_code == 401


class TestPlatformMFA:
    async def test_mfa_verify_returns_501(
        self,
        client: AsyncClient,
        db_session: AsyncSession,
    ) -> None:
        resp = await client.post(
            "/api/v1/auth/platform/mfa/verify",
            json={"email": "admin@oryonfoods.com", "code": "123456"},
        )
        assert resp.status_code == 501
        assert "not yet implemented" in resp.json()["detail"].lower()


class TestPlatformLoginRateLimit:
    async def test_exceeds_email_limit_returns_429(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        async with db_session.begin():
            user = User(
                phone=_platform_phone(),
                email="ratelimit@oryonfoods.com",
                full_name="Rate Limit User",
                user_category=UserCategory.PLATFORM_STAFF,
                status=UserStatus.ACTIVE,
                password_hash=hash_password(_TEST_PASSWORD),
                is_email_verified=True,
            )
            db_session.add(user)

        # Make requests up to the limit
        for _ in range(RATE_LIMIT_PLATFORM_LOGIN_EMAIL_LIMIT):
            resp = await client.post(
                "/api/v1/auth/platform/login",
                json={"email": user.email, "password": "WrongPass1!"},
            )
            assert resp.status_code == 401  # wrong password, but not rate limited yet

        # Next request should be rate limited
        resp = await client.post(
            "/api/v1/auth/platform/login",
            json={"email": user.email, "password": "WrongPass1!"},
        )
        assert resp.status_code == 429
        assert "Retry-After" in resp.headers
        assert resp.json()["detail"] == "Too many attempts, please try again later"

    async def test_exceeds_ip_limit_returns_429(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        # Create multiple users with different emails but same IP (test client)
        emails = [f"user{i}@oryonfoods.com" for i in range(RATE_LIMIT_PLATFORM_LOGIN_IP_LIMIT + 1)]
        for email in emails:
            async with db_session.begin():
                user = User(
                    phone=_platform_phone(),
                    email=email,
                    full_name=f"User {email}",
                    user_category=UserCategory.PLATFORM_STAFF,
                    status=UserStatus.ACTIVE,
                    password_hash=hash_password(_TEST_PASSWORD),
                    is_email_verified=True,
                )
                db_session.add(user)

        # Make requests up to the IP limit
        for email in emails[:RATE_LIMIT_PLATFORM_LOGIN_IP_LIMIT]:
            resp = await client.post(
                "/api/v1/auth/platform/login",
                json={"email": email, "password": "WrongPass1!"},
            )
            assert resp.status_code == 401

        # Next request from same IP should be rate limited
        resp = await client.post(
            "/api/v1/auth/platform/login",
            json={"email": emails[-1], "password": "WrongPass1!"},
        )
        assert resp.status_code == 429
        assert "Retry-After" in resp.headers

    async def test_different_email_not_blocked_by_another_email_limit(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        email1 = "limit1@oryonfoods.com"
        email2 = "limit2@oryonfoods.com"

        async with db_session.begin():
            user1 = User(
                phone=_platform_phone(),
                email=email1,
                full_name="User 1",
                user_category=UserCategory.PLATFORM_STAFF,
                status=UserStatus.ACTIVE,
                password_hash=hash_password(_TEST_PASSWORD),
                is_email_verified=True,
            )
            user2 = User(
                phone=_platform_phone(),
                email=email2,
                full_name="User 2",
                user_category=UserCategory.PLATFORM_STAFF,
                status=UserStatus.ACTIVE,
                password_hash=hash_password(_TEST_PASSWORD),
                is_email_verified=True,
            )
            db_session.add(user1)
            db_session.add(user2)

        # Exhaust limit for email1
        for _ in range(RATE_LIMIT_PLATFORM_LOGIN_EMAIL_LIMIT):
            await client.post(
                "/api/v1/auth/platform/login",
                json={"email": email1, "password": "WrongPass1!"},
            )

        # email1 should be blocked
        resp = await client.post(
            "/api/v1/auth/platform/login",
            json={"email": email1, "password": "WrongPass1!"},
        )
        assert resp.status_code == 429

        # email2 should still work (not blocked by email1's limit)
        resp = await client.post(
            "/api/v1/auth/platform/login",
            json={"email": email2, "password": "WrongPass1!"},
        )
        assert resp.status_code == 401  # wrong password, but not rate limited


class TestPlatformRegisterPermissionGuard:
    """Verify the stacked require_platform_staff + require_role guards.

    POST /api/v1/auth/platform/register now has two guards:
      1. require_platform_staff() — category gate
      2. require_role("admin")    — role gate

    These tests confirm that each guard independently blocks the right tokens.
    """

    async def test_business_user_with_admin_role_is_rejected_by_category_gate(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        """A business_user token carrying role='admin' must be blocked (403).

        Before the require_platform_staff() retrofit, only require_role("admin")
        was checked, meaning a business_user with 'admin' in their roles list
        could theoretically reach this endpoint.  This test locks that down.
        """
        from app.models.user import User, UserCategory, UserStatus

        async with db_session.begin():
            biz_user = User(
                phone="+255777000111",
                full_name="Business Admin",
                user_category=UserCategory.BUSINESS_STAFF,
                status=UserStatus.ACTIVE,
                is_phone_verified=True,
            )
            db_session.add(biz_user)

        # Craft a business_user token that *also* has role "admin" — the worst case
        business_admin_token = create_access_token(
            subject=str(biz_user.id),
            user_category=UserCategory.BUSINESS_STAFF.value,
            roles=["admin"],
            permissions=[],
            active_business_id=None,
        )

        resp = await client.post(
            "/api/v1/auth/platform/register",
            json={
                "email": "injected@evil.com",
                "full_name": "Evil",
                "password": "StrongPass1!",
                "group_id": str(uuid4()),
            },
            headers={"Authorization": f"Bearer {business_admin_token}"},
        )
        # The category gate (require_platform_staff) blocks this before role check
        assert resp.status_code == 403
        assert "platform staff" in resp.json()["detail"].lower()

    async def test_platform_staff_without_admin_role_is_rejected_by_role_gate(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        """A platform_staff token without role='admin' must be blocked (403).

        The category gate passes (it is platform_staff), but require_role("admin")
        then blocks because "admin" is not in the token's roles list.
        """
        async with db_session.begin():
            staff_user = User(
                phone="+255777000222",
                email="viewer@oryonfoods.com",
                full_name="Viewer Staff",
                user_category=UserCategory.PLATFORM_STAFF,
                status=UserStatus.ACTIVE,
                is_email_verified=True,
            )
            db_session.add(staff_user)

        viewer_token = create_access_token(
            subject=str(staff_user.id),
            user_category=UserCategory.PLATFORM_STAFF.value,
            roles=["viewer"],  # NOT admin
            permissions=[],
        )

        resp = await client.post(
            "/api/v1/auth/platform/register",
            json={
                "email": "newstaff_viewer_attempt@oryonfoods.com",
                "full_name": "New Staff",
                "password": "StrongPass1!",
                "group_id": str(uuid4()),
            },
            headers={"Authorization": f"Bearer {viewer_token}"},
        )
        assert resp.status_code == 403

    async def test_platform_staff_with_admin_role_succeeds(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        """platform_staff + admin role must still succeed (regression guard)."""
        async with db_session.begin():
            group = Group(name=f"admins_{uuid4().hex[:8]}")
            db_session.add(group)

        admin_token = await _create_admin_token(db_session)
        email = f"newstaff_{uuid4().hex[:8]}@oryonfoods.com"

        resp = await client.post(
            "/api/v1/auth/platform/register",
            json={
                "email": email,
                "full_name": "Legit New Staff",
                "password": "StrongPass1!",
                "group_id": str(group.id),
            },
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert resp.status_code == 201, resp.text
