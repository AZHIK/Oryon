from uuid import UUID, uuid4

import pytest
from httpx import AsyncClient
from sqlmodel import select
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.security import create_access_token
from app.models.internal import Group, Role, UserGroup, UserRole
from app.models.platform import PlatformRole
from app.models.user import User, UserCategory, UserStatus

# All fine-grained codes needed by the CRUD tests below.
_TEST_PERMISSIONS = [
    "groups.view",
    "groups.create",
    "groups.update",
    "groups.delete",
    "groups.assign_user",
    "roles.view",
    "roles.create",
    "roles.update",
    "roles.delete",
    "roles.assign_to_user",
    "roles.manage_permissions",
    "platform_roles.view",
    "platform_roles.create",
    "platform_roles.update",
    "platform_roles.delete",
    "platform_roles.assign_to_user",
    "platform_roles.manage_permissions",
]


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


async def _create_staff_token_with_perm(db_session: AsyncSession) -> str:
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
        permissions=_TEST_PERMISSIONS,
    )


class TestAdminRBACAccess:
    """Verify that category and permission gates work on all internal_rbac endpoints."""

    @pytest.mark.parametrize(
        "method,path_template",
        [
            ("GET", "/admin/groups"),
            ("GET", "/admin/groups/{group_id}"),
            ("POST", "/admin/groups"),
            ("PATCH", "/admin/groups/{group_id}"),
            ("DELETE", "/admin/groups/{group_id}"),
            ("GET", "/admin/roles"),
            ("GET", "/admin/roles/{role_id}"),
            ("POST", "/admin/roles"),
            ("PATCH", "/admin/roles/{role_id}"),
            ("DELETE", "/admin/roles/{role_id}"),
            ("GET", "/admin/platform-roles"),
            ("GET", "/admin/platform-roles/{pr_id}"),
            ("POST", "/admin/platform-roles"),
            ("PATCH", "/admin/platform-roles/{pr_id}"),
            ("DELETE", "/admin/platform-roles/{pr_id}"),
        ],
    )
    async def test_business_user_rejected(
        self, method: str, path_template: str, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        token = await _create_business_user_token(db_session)
        rid = uuid4()
        path = path_template.format(group_id=rid, role_id=rid, pr_id=rid)
        resp = await client.request(
            method,
            path,
            headers={"Authorization": f"Bearer {token}"},
            json={"name": "test", "group_id": str(rid)} if method == "POST" else None,
        )
        assert resp.status_code == 403

    async def test_staff_without_permission_rejected(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        token = await _create_staff_token_no_perm(db_session)
        resp = await client.get("/admin/groups", headers={"Authorization": f"Bearer {token}"})
        assert resp.status_code == 403
        assert "Permission" in resp.json()["detail"]


class TestAdminGroups:
    async def test_create_and_list_groups(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        token = await _create_staff_token_with_perm(db_session)
        name = f"test_group_{uuid4().hex[:8]}"

        resp = await client.post(
            "/admin/groups",
            json={"name": name, "description": "test desc"},
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 201
        data = resp.json()
        assert data["name"] == name
        assert data["description"] == "test desc"
        group_id = data["id"]

        resp = await client.get("/admin/groups", headers={"Authorization": f"Bearer {token}"})
        assert resp.status_code == 200
        ids = [g["id"] for g in resp.json()]
        assert group_id in ids

    async def test_get_group(self, client: AsyncClient, db_session: AsyncSession) -> None:
        token = await _create_staff_token_with_perm(db_session)
        name = f"get_group_{uuid4().hex[:8]}"

        resp = await client.post(
            "/admin/groups",
            json={"name": name},
            headers={"Authorization": f"Bearer {token}"},
        )
        gid = resp.json()["id"]

        resp = await client.get(
            f"/admin/groups/{gid}", headers={"Authorization": f"Bearer {token}"}
        )
        assert resp.status_code == 200
        assert resp.json()["name"] == name

    async def test_update_group(self, client: AsyncClient, db_session: AsyncSession) -> None:
        token = await _create_staff_token_with_perm(db_session)
        name = f"upd_group_{uuid4().hex[:8]}"

        resp = await client.post(
            "/admin/groups",
            json={"name": name},
            headers={"Authorization": f"Bearer {token}"},
        )
        gid = resp.json()["id"]

        resp = await client.patch(
            f"/admin/groups/{gid}",
            json={"description": "updated desc"},
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 200
        assert resp.json()["description"] == "updated desc"

    async def test_delete_group_with_no_users_succeeds(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        token = await _create_staff_token_with_perm(db_session)
        name = f"del_group_{uuid4().hex[:8]}"

        resp = await client.post(
            "/admin/groups",
            json={"name": name},
            headers={"Authorization": f"Bearer {token}"},
        )
        gid = resp.json()["id"]

        resp = await client.delete(
            f"/admin/groups/{gid}", headers={"Authorization": f"Bearer {token}"}
        )
        assert resp.status_code == 204


class TestAdminRoles:
    async def test_create_and_list_roles(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        token = await _create_staff_token_with_perm(db_session)
        async with db_session.begin():
            group = Group(name=f"role_test_group_{uuid4().hex[:8]}")
            db_session.add(group)

        resp = await client.post(
            "/admin/roles",
            json={
                "name": f"test_role_{uuid4().hex[:8]}",
                "group_id": str(group.id),
                "description": "test role",
            },
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 201
        role_id = resp.json()["id"]

        resp = await client.get("/admin/roles", headers={"Authorization": f"Bearer {token}"})
        assert resp.status_code == 200
        assert role_id in [r["id"] for r in resp.json()]

    async def test_delete_role_with_active_assignments_returns_409(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        token = await _create_staff_token_with_perm(db_session)
        async with db_session.begin():
            group = Group(name=f"role_del_{uuid4().hex[:8]}")
            db_session.add(group)
        group_id = group.id

        resp = await client.post(
            "/admin/roles",
            json={"name": f"protected_role_{uuid4().hex[:8]}", "group_id": str(group_id)},
            headers={"Authorization": f"Bearer {token}"},
        )
        role_id = resp.json()["id"]

        async with db_session.begin():
            user = User(
                phone=_unique_phone(),
                full_name="Role Assignment User",
                user_category=UserCategory.PLATFORM_STAFF,
                status=UserStatus.ACTIVE,
            )
            db_session.add(user)
        user_id = user.id

        async with db_session.begin():
            db_session.add(UserRole(user_id=user_id, role_id=UUID(role_id)))

        resp = await client.delete(
            f"/admin/roles/{role_id}",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 409
        assert "active user assignments" in resp.json()["detail"].lower()


class TestAdminPlatformRoles:
    async def test_create_and_list_platform_roles(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        token = await _create_staff_token_with_perm(db_session)
        name = f"test_pr_{uuid4().hex[:8]}"

        resp = await client.post(
            "/admin/platform-roles",
            json={"name": name},
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 201
        pr_id = resp.json()["id"]

        resp = await client.get(
            "/admin/platform-roles", headers={"Authorization": f"Bearer {token}"}
        )
        assert resp.status_code == 200
        assert pr_id in [p["id"] for p in resp.json()]


class TestAdminRolePermissions:
    async def test_assign_and_remove_role_permission(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        token = await _create_staff_token_with_perm(db_session)
        async with db_session.begin():
            group = Group(name=f"rp_group_{uuid4().hex[:8]}")
            db_session.add(group)

        resp = await client.post(
            "/admin/roles",
            json={"name": f"rp_role_{uuid4().hex[:8]}", "group_id": str(group.id)},
            headers={"Authorization": f"Bearer {token}"},
        )
        role_id = resp.json()["id"]

        resp = await client.post(
            f"/admin/roles/{role_id}/permissions",
            json={"permission_code": "users.manage"},
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 201

        resp = await client.delete(
            f"/admin/roles/{role_id}/permissions",
            params={"permission_code": "users.manage"},
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 204


class TestAdminPlatformRolePermissions:
    async def test_assign_and_remove_platform_role_permission(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        token = await _create_staff_token_with_perm(db_session)
        name = f"pr_perm_{uuid4().hex[:8]}"

        resp = await client.post(
            "/admin/platform-roles",
            json={"name": name},
            headers={"Authorization": f"Bearer {token}"},
        )
        pr_id = resp.json()["id"]

        resp = await client.post(
            f"/admin/platform-roles/{pr_id}/permissions",
            json={"permission_code": "users.manage"},
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 201

        resp = await client.delete(
            f"/admin/platform-roles/{pr_id}/permissions",
            params={"permission_code": "users.manage"},
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 204


class TestAdminUserGroupAssignment:
    async def test_assign_user_to_group(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        token = await _create_staff_token_with_perm(db_session)
        async with db_session.begin():
            user = User(
                phone=_unique_phone(),
                full_name="Group Assign User",
                user_category=UserCategory.PLATFORM_STAFF,
                status=UserStatus.ACTIVE,
            )
            db_session.add(user)
            group = Group(name=f"ug_group_{uuid4().hex[:8]}")
            db_session.add(group)

        resp = await client.post(
            f"/admin/users/{user.id}/group",
            json={"group_id": str(group.id)},
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 201

        row = (
            await db_session.exec(select(UserGroup).where(UserGroup.user_id == user.id))
        ).one_or_none()
        assert row is not None

    async def test_assign_second_group_rejected(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        token = await _create_staff_token_with_perm(db_session)
        async with db_session.begin():
            user = User(
                phone=_unique_phone(),
                full_name="Second Group User",
                user_category=UserCategory.PLATFORM_STAFF,
                status=UserStatus.ACTIVE,
            )
            db_session.add(user)
            group1 = Group(name=f"ug1_{uuid4().hex[:8]}")
            group2 = Group(name=f"ug2_{uuid4().hex[:8]}")
            db_session.add(group1)
            db_session.add(group2)

        resp = await client.post(
            f"/admin/users/{user.id}/group",
            json={"group_id": str(group1.id)},
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 201

        resp = await client.post(
            f"/admin/users/{user.id}/group",
            json={"group_id": str(group2.id)},
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 409
        assert "already has a group" in resp.json()["detail"].lower()

    async def test_remove_user_from_group(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        token = await _create_staff_token_with_perm(db_session)
        async with db_session.begin():
            user = User(
                phone=_unique_phone(),
                full_name="Remove Group User",
                user_category=UserCategory.PLATFORM_STAFF,
                status=UserStatus.ACTIVE,
            )
            db_session.add(user)
            group = Group(name=f"ug_rem_{uuid4().hex[:8]}")
            db_session.add(group)

        resp = await client.post(
            f"/admin/users/{user.id}/group",
            json={"group_id": str(group.id)},
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 201

        resp = await client.delete(
            f"/admin/users/{user.id}/group",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 204

        row = (
            await db_session.exec(select(UserGroup).where(UserGroup.user_id == user.id))
        ).one_or_none()
        assert row is None


class TestAdminUserRoleAssignment:
    async def test_assign_user_role_with_group_mismatch_rejected(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        token = await _create_staff_token_with_perm(db_session)
        async with db_session.begin():
            user = User(
                phone=_unique_phone(),
                full_name="Role Mismatch User",
                user_category=UserCategory.PLATFORM_STAFF,
                status=UserStatus.ACTIVE,
            )
            db_session.add(user)
            group_a = Group(name=f"role_mismatch_a_{uuid4().hex[:8]}")
            group_b = Group(name=f"role_mismatch_b_{uuid4().hex[:8]}")
            db_session.add(group_a)
            db_session.add(group_b)

        async with db_session.begin():
            role_b = Role(
                name=f"role_b_{uuid4().hex[:8]}",
                group_id=group_b.id,
            )
            db_session.add(role_b)

        async with db_session.begin():
            db_session.add(UserGroup(user_id=user.id, group_id=group_a.id))

        resp = await client.post(
            f"/admin/users/{user.id}/roles",
            json={"role_id": str(role_b.id)},
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 400
        assert "group" in resp.json()["detail"].lower()

    async def test_assign_and_remove_user_role_succeeds(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        token = await _create_staff_token_with_perm(db_session)
        async with db_session.begin():
            user = User(
                phone=_unique_phone(),
                full_name="User Role Success",
                user_category=UserCategory.PLATFORM_STAFF,
                status=UserStatus.ACTIVE,
            )
            db_session.add(user)
            group = Group(name=f"ur_success_{uuid4().hex[:8]}")
            db_session.add(group)

        async with db_session.begin():
            role = Role(name=f"ur_role_{uuid4().hex[:8]}", group_id=group.id)
            db_session.add(role)

        async with db_session.begin():
            db_session.add(UserGroup(user_id=user.id, group_id=group.id))

        resp = await client.post(
            f"/admin/users/{user.id}/roles",
            json={"role_id": str(role.id)},
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 201

        row = (
            await db_session.exec(
                select(UserRole).where(UserRole.user_id == user.id, UserRole.role_id == role.id)
            )
        ).one_or_none()
        assert row is not None

        resp = await client.delete(
            f"/admin/users/{user.id}/roles",
            params={"role_id": str(role.id)},
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 204

        row = (
            await db_session.exec(
                select(UserRole).where(UserRole.user_id == user.id, UserRole.role_id == role.id)
            )
        ).one_or_none()
        assert row is None


class TestAdminUserPlatformRoleAssignment:
    async def test_assign_and_remove_user_platform_role(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        token = await _create_staff_token_with_perm(db_session)
        async with db_session.begin():
            user = User(
                phone=_unique_phone(),
                full_name="UPR User",
                user_category=UserCategory.PLATFORM_STAFF,
                status=UserStatus.ACTIVE,
            )
            db_session.add(user)
            pr = PlatformRole(name=f"upr_role_{uuid4().hex[:8]}")
            db_session.add(pr)

        resp = await client.post(
            f"/admin/users/{user.id}/platform-roles",
            json={"platform_role_id": str(pr.id)},
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 201

        resp = await client.delete(
            f"/admin/users/{user.id}/platform-roles",
            params={"platform_role_id": str(pr.id)},
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 204
