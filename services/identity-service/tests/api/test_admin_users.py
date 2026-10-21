from uuid import uuid4

import pytest
from httpx import AsyncClient
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.database import async_session_factory
from app.core.security import create_access_token
from app.models.user import User, UserCategory, UserStatus

# Specific fine-grained permission codes (new)
USERS_VIEW = "users.view"
USERS_UPDATE = "users.update"
USERS_DEACTIVATE = "users.deactivate"
USERS_REACTIVATE = "users.reactivate"

# Coarse/legacy permission (old)
USERS_MANAGE = "users.manage"


def _unique_phone() -> str:
    return f"+2557{uuid4().int % 100_000_000:08d}"


async def _create_business_user_token(db_session: AsyncSession) -> str:
    async with db_session.begin():
        user = User(
            phone=_unique_phone(),
            full_name="Business User",
            user_category=UserCategory.BUSINESS_STAFF,
            status=UserStatus.ACTIVE,
        )
        db_session.add(user)

    return create_access_token(
        subject=str(user.id),
        user_category=UserCategory.BUSINESS_STAFF.value,
        roles=[],
        permissions=[],
    )


async def _create_staff_token_no_perm(db_session: AsyncSession) -> str:
    async with db_session.begin():
        user = User(
            phone=_unique_phone(),
            email="staff_no_perm@oryonfoods.com",
            full_name="Staff No Perm",
            user_category=UserCategory.PLATFORM_STAFF,
            status=UserStatus.ACTIVE,
            is_email_verified=True,
        )
        db_session.add(user)

    return create_access_token(
        subject=str(user.id),
        user_category=UserCategory.PLATFORM_STAFF.value,
        roles=[],
        permissions=[],
    )


async def _create_staff_token_with_perms(db_session: AsyncSession, perms: list[str]) -> str:
    async with db_session.begin():
        user = User(
            phone=_unique_phone(),
            email="staff_with_perm@oryonfoods.com",
            full_name="Staff With Perm",
            user_category=UserCategory.PLATFORM_STAFF,
            status=UserStatus.ACTIVE,
            is_email_verified=True,
        )
        db_session.add(user)

    return create_access_token(
        subject=str(user.id),
        user_category=UserCategory.PLATFORM_STAFF.value,
        roles=["admin"],
        permissions=perms,
    )


async def _create_staff_token_with_coarse_perm(db_session: AsyncSession) -> str:
    """Token with only the legacy coarse USERS_MANAGE permission."""
    return await _create_staff_token_with_perms(db_session, [USERS_MANAGE])


async def _create_test_users(db_session: AsyncSession) -> list[User]:
    users = []
    async with db_session.begin():
        for i, (cat, status, active) in enumerate(
            [
                (UserCategory.PLATFORM_STAFF, UserStatus.ACTIVE, True),
                (UserCategory.BUSINESS_STAFF, UserStatus.ACTIVE, True),
                (UserCategory.DRIVER, UserStatus.ACTIVE, True),
                (UserCategory.CONSUMER, UserStatus.ACTIVE, True),
                (UserCategory.BUSINESS_STAFF, UserStatus.SUSPENDED, False),
            ]
        ):
            user = User(
                phone=_unique_phone(),
                full_name=f"Test User {i}",
                user_category=cat,
                status=status,
                is_active=active,
            )
            db_session.add(user)
            users.append(user)
    return users


class TestAdminUserAccess:
    """Verify that category and permission gates work on all endpoints."""

    @pytest.mark.parametrize(
        "method,path_template",
        [
            ("GET", "/admin/users"),
            ("GET", "/admin/users/{user_id}"),
            ("PATCH", "/admin/users/{user_id}"),
            ("DELETE", "/admin/users/{user_id}"),
        ],
    )
    async def test_business_user_rejected(
        self, method: str, path_template: str, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        token = await _create_business_user_token(db_session)
        user_id = uuid4()
        path = path_template.format(user_id=user_id)
        resp = await client.request(method, path, headers={"Authorization": f"Bearer {token}"})
        assert resp.status_code == 403

    async def test_staff_without_permission_rejected(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        token = await _create_staff_token_no_perm(db_session)
        resp = await client.get("/admin/users", headers={"Authorization": f"Bearer {token}"})
        assert resp.status_code == 403
        assert "Permission" in resp.json()["detail"]


class TestAdminUserList:
    async def test_list_users_with_view_perm_succeeds(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        await _create_test_users(db_session)
        token = await _create_staff_token_with_perms(db_session, [USERS_VIEW])

        resp = await client.get("/admin/users", headers={"Authorization": f"Bearer {token}"})
        assert resp.status_code == 200
        data = resp.json()
        assert isinstance(data, list)
        assert len(data) >= 5

    async def test_list_users_with_coarse_perm_rejected(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        """Legacy coarse USERS_MANAGE should NOT grant access to specific endpoints."""
        await _create_test_users(db_session)
        token = await _create_staff_token_with_coarse_perm(db_session)

        resp = await client.get("/admin/users", headers={"Authorization": f"Bearer {token}"})
        assert resp.status_code == 403

    async def test_list_users_filters_user_category(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        await _create_test_users(db_session)
        token = await _create_staff_token_with_perms(db_session, [USERS_VIEW])

        resp = await client.get(
            "/admin/users?user_category=business_staff",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 200
        data = resp.json()
        assert all(u["user_category"] == "business_staff" for u in data)

    async def test_list_users_filters_status(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        await _create_test_users(db_session)
        token = await _create_staff_token_with_perms(db_session, [USERS_VIEW])

        resp = await client.get(
            "/admin/users?status=suspended",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 200
        data = resp.json()
        assert all(u["status"] == "suspended" for u in data)

    async def test_list_users_filters_is_active(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        await _create_test_users(db_session)
        token = await _create_staff_token_with_perms(db_session, [USERS_VIEW])

        resp = await client.get(
            "/admin/users?is_active=false",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 200
        data = resp.json()
        assert all(u["is_active"] is False for u in data)
        assert len(data) == 1

    async def test_list_users_search_by_name(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        await _create_test_users(db_session)
        token = await _create_staff_token_with_perms(db_session, [USERS_VIEW])

        resp = await client.get(
            "/admin/users?search=Test+User",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 200
        data = resp.json()
        assert len(data) >= 5


class TestAdminUserDetail:
    async def test_get_user_detail_succeeds(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        users = await _create_test_users(db_session)
        token = await _create_staff_token_with_perms(db_session, [USERS_VIEW])
        target = users[0]

        resp = await client.get(
            f"/admin/users/{target.id}",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["id"] == str(target.id)
        assert data["full_name"] == target.full_name

    async def test_get_user_detail_not_found(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        token = await _create_staff_token_with_perms(db_session, [USERS_VIEW])
        resp = await client.get(
            f"/admin/users/{uuid4()}",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 404


class TestAdminUserUpdate:
    async def test_patch_user_status(self, client: AsyncClient, db_session: AsyncSession) -> None:
        users = await _create_test_users(db_session)
        token = await _create_staff_token_with_perms(db_session, [USERS_UPDATE])
        target = users[0]

        resp = await client.patch(
            f"/admin/users/{target.id}",
            json={"status": "suspended"},
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["status"] == "suspended"

    async def test_patch_user_is_active(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        users = await _create_test_users(db_session)
        token = await _create_staff_token_with_perms(db_session, [USERS_UPDATE])
        target = users[0]

        resp = await client.patch(
            f"/admin/users/{target.id}",
            json={"is_active": False},
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["is_active"] is False

    async def test_patch_user_not_found(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        token = await _create_staff_token_with_perms(db_session, [USERS_UPDATE])
        resp = await client.patch(
            f"/admin/users/{uuid4()}",
            json={"is_active": False},
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 404

    async def test_patch_user_coarse_perm_rejected(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        """USERS_MANAGE alone should NOT grant PATCH access to specific endpoint."""
        users = await _create_test_users(db_session)
        token = await _create_staff_token_with_coarse_perm(db_session)
        target = users[0]

        resp = await client.patch(
            f"/admin/users/{target.id}",
            json={"is_active": False},
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 403


class TestAdminUserDelete:
    async def test_delete_sets_is_active_false(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        users = await _create_test_users(db_session)
        token = await _create_staff_token_with_perms(db_session, [USERS_DEACTIVATE])
        target_id = users[0].id

        resp = await client.delete(
            f"/admin/users/{target_id}",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 204

        async with async_session_factory() as check_session:
            async with check_session.begin():
                row = await check_session.get(User, target_id)
            assert row is not None
            assert row.is_active is False

    async def test_delete_not_found(self, client: AsyncClient, db_session: AsyncSession) -> None:
        token = await _create_staff_token_with_perms(db_session, [USERS_DEACTIVATE])
        resp = await client.delete(
            f"/admin/users/{uuid4()}",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 404

    async def test_cannot_deactivate_self(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        async with db_session.begin():
            user = User(
                phone=_unique_phone(),
                email="selfdeact@oryonfoods.com",
                full_name="Self Deactivator",
                user_category=UserCategory.PLATFORM_STAFF,
                status=UserStatus.ACTIVE,
                is_email_verified=True,
            )
            db_session.add(user)

        token = create_access_token(
            subject=str(user.id),
            user_category=UserCategory.PLATFORM_STAFF.value,
            roles=["admin"],
            permissions=[USERS_DEACTIVATE],
        )

        resp = await client.delete(
            f"/admin/users/{user.id}",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 400
        assert "Cannot deactivate yourself" in resp.json()["detail"]

    async def test_delete_coarse_perm_rejected(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        """USERS_MANAGE alone should NOT grant DELETE access to specific endpoint."""
        users = await _create_test_users(db_session)
        target_id = users[0].id

        token = await _create_staff_token_with_coarse_perm(db_session)
        resp = await client.delete(
            f"/admin/users/{target_id}",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 403
