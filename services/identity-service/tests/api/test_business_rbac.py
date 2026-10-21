"""Integration tests for business-scoped RBAC management endpoints."""

from uuid import UUID, uuid4

from httpx import AsyncClient
from sqlmodel import select
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.permission_codes import PermissionCode
from app.core.security import create_access_token, hash_password
from app.models.business import (
    Business,
    BusinessRole,
    BusinessRolePermission,
    BusinessType,
    LocationType,
    Store,
    UserBusinessRole,
    UserStoreRole,
)
from app.models.user import User, UserCategory, UserStatus

_TEST_PASSWORD = "TestPass1!"


async def _make_business(db_session: AsyncSession, owner: User) -> Business:
    biz = Business(
        name=f"Test Biz {uuid4().hex[:8]}",
        business_type=BusinessType.RESTAURANT,
        owner_user_id=owner.id,
        country_code="TZ",
    )
    db_session.add(biz)
    await db_session.commit()
    await db_session.refresh(biz)
    return biz


async def _make_business_user(
    db_session: AsyncSession,
    phone: str | None = None,
    email: str | None = None,
) -> User:
    user = User(
        phone=phone or f"+2557{uuid4().int % 100_000_000:08d}",
        email=email,
        full_name="Business User",
        user_category=UserCategory.BUSINESS_STAFF,
        status=UserStatus.ACTIVE,
        password_hash=hash_password(_TEST_PASSWORD),
    )
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)
    return user


def _owner_token(user: User, business_id) -> str:
    return create_access_token(
        subject=str(user.id),
        user_category=UserCategory.BUSINESS_STAFF.value,
        active_business_id=str(business_id),
        roles=["owner"],
        permissions=["*"],
        other_businesses=[],
    )


def _staff_token(user: User, business_id, perms: list[str]) -> str:
    return create_access_token(
        subject=str(user.id),
        user_category=UserCategory.BUSINESS_STAFF.value,
        active_business_id=str(business_id),
        roles=["manager"],
        permissions=perms,
        other_businesses=[],
    )


class TestCreateBusinessRole:
    async def test_creates_role(self, client: AsyncClient, db_session: AsyncSession) -> None:
        owner = await _make_business_user(db_session)
        biz = await _make_business(db_session, owner)
        token = _owner_token(owner, biz.id)

        resp = await client.post(
            f"/api/v1/businesses/{biz.id}/roles",
            json={"name": "Cashier", "description": "Handles POS transactions"},
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 201
        data = resp.json()
        assert data["name"] == "Cashier"
        assert data["description"] == "Handles POS transactions"
        assert data["is_protected"] is False
        assert data["business_id"] == str(biz.id)

    async def test_duplicate_name_returns_409(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        owner = await _make_business_user(db_session)
        biz = await _make_business(db_session, owner)
        token = _owner_token(owner, biz.id)

        await client.post(
            f"/api/v1/businesses/{biz.id}/roles",
            json={"name": "Cashier"},
            headers={"Authorization": f"Bearer {token}"},
        )
        resp = await client.post(
            f"/api/v1/businesses/{biz.id}/roles",
            json={"name": "Cashier"},
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 409
        assert "already exists" in resp.json()["detail"].lower()

    async def test_same_name_different_business_ok(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        owner = await _make_business_user(db_session)
        # owner_user_id is unique per business now, so biz2 needs its own
        # owner — the token below still authenticates as `owner` scoped to
        # biz2, which is what the permission check actually looks at.
        other_owner = await _make_business_user(db_session)
        biz1 = await _make_business(db_session, owner)
        biz2 = await _make_business(db_session, other_owner)
        token = _owner_token(owner, biz1.id)

        await client.post(
            f"/api/v1/businesses/{biz1.id}/roles",
            json={"name": "Cashier"},
            headers={"Authorization": f"Bearer {token}"},
        )
        await db_session.commit()

        token_biz2 = _owner_token(owner, biz2.id)
        resp = await client.post(
            f"/api/v1/businesses/{biz2.id}/roles",
            json={"name": "Cashier"},
            headers={"Authorization": f"Bearer {token_biz2}"},
        )
        assert resp.status_code == 201

    async def test_without_permission_returns_403(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        owner = await _make_business_user(db_session)
        biz = await _make_business(db_session, owner)
        token = _staff_token(owner, biz.id, [PermissionCode.INVENTORY_VIEW])

        resp = await client.post(
            f"/api/v1/businesses/{biz.id}/roles",
            json={"name": "Cashier"},
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 403

    async def test_no_business_context_returns_403(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        owner = await _make_business_user(db_session)
        token = create_access_token(
            subject=str(owner.id),
            user_category=UserCategory.BUSINESS_STAFF.value,
            permissions=["*"],
        )

        resp = await client.post(
            f"/api/v1/businesses/{uuid4()}/roles",
            json={"name": "Cashier"},
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 403


class TestUpdateBusinessRole:
    async def test_updates_name(self, client: AsyncClient, db_session: AsyncSession) -> None:
        owner = await _make_business_user(db_session)
        biz = await _make_business(db_session, owner)
        token = _owner_token(owner, biz.id)

        create_resp = await client.post(
            f"/api/v1/businesses/{biz.id}/roles",
            json={"name": "Cashier"},
            headers={"Authorization": f"Bearer {token}"},
        )
        role_id = create_resp.json()["id"]

        resp = await client.patch(
            f"/api/v1/businesses/{biz.id}/roles/{role_id}",
            json={"name": "Senior Cashier"},
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 200
        assert resp.json()["name"] == "Senior Cashier"

    async def test_protected_role_returns_403(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        owner = await _make_business_user(db_session)
        biz = await _make_business(db_session, owner)
        token = _owner_token(owner, biz.id)

        create_resp = await client.post(
            f"/api/v1/businesses/{biz.id}/roles",
            json={"name": "Manager"},
            headers={"Authorization": f"Bearer {token}"},
        )
        role_id = create_resp.json()["id"]

        role = await db_session.get(BusinessRole, UUID(role_id))
        role.is_protected = True
        db_session.add(role)
        await db_session.commit()

        resp = await client.patch(
            f"/api/v1/businesses/{biz.id}/roles/{role_id}",
            json={"name": "Changed"},
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 403


class TestDeleteBusinessRole:
    async def test_deletes_role(self, client: AsyncClient, db_session: AsyncSession) -> None:
        owner = await _make_business_user(db_session)
        biz = await _make_business(db_session, owner)
        token = _owner_token(owner, biz.id)

        create_resp = await client.post(
            f"/api/v1/businesses/{biz.id}/roles",
            json={"name": "Temp Role"},
            headers={"Authorization": f"Bearer {token}"},
        )
        role_id = create_resp.json()["id"]

        resp = await client.delete(
            f"/api/v1/businesses/{biz.id}/roles/{role_id}",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 204

        fetched = await db_session.get(BusinessRole, UUID(role_id))
        assert fetched is None or fetched.is_deleted is True

    async def test_protected_role_returns_403(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        owner = await _make_business_user(db_session)
        biz = await _make_business(db_session, owner)
        token = _owner_token(owner, biz.id)

        create_resp = await client.post(
            f"/api/v1/businesses/{biz.id}/roles",
            json={"name": "Protected Role"},
            headers={"Authorization": f"Bearer {token}"},
        )
        role_id = create_resp.json()["id"]

        role = await db_session.get(BusinessRole, UUID(role_id))
        role.is_protected = True
        db_session.add(role)
        await db_session.commit()

        resp = await client.delete(
            f"/api/v1/businesses/{biz.id}/roles/{role_id}",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 403

    async def test_role_with_assignments_returns_409(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        owner = await _make_business_user(db_session)
        biz = await _make_business(db_session, owner)
        token = _owner_token(owner, biz.id)

        create_resp = await client.post(
            f"/api/v1/businesses/{biz.id}/roles",
            json={"name": "Staff Role"},
            headers={"Authorization": f"Bearer {token}"},
        )
        role_id = UUID(create_resp.json()["id"])

        staff = await _make_business_user(db_session)

        ubr = UserBusinessRole(user_id=staff.id, business_id=biz.id, business_role_id=role_id)
        db_session.add(ubr)
        await db_session.commit()

        resp = await client.delete(
            f"/api/v1/businesses/{biz.id}/roles/{role_id}",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 409
        assert "active user assignments" in resp.json()["detail"].lower()


class TestAssignPermission:
    async def test_assigns_permission(self, client: AsyncClient, db_session: AsyncSession) -> None:
        owner = await _make_business_user(db_session)
        biz = await _make_business(db_session, owner)
        token = _owner_token(owner, biz.id)

        create_resp = await client.post(
            f"/api/v1/businesses/{biz.id}/roles",
            json={"name": "Cashier"},
            headers={"Authorization": f"Bearer {token}"},
        )
        role_id = create_resp.json()["id"]

        resp = await client.post(
            f"/api/v1/businesses/{biz.id}/roles/{role_id}/permissions",
            json={"permission_code": "pos.write"},
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 201
        assert resp.json()["detail"] == "Permission assigned to role"

        rp = (
            await db_session.exec(
                select(BusinessRolePermission).where(
                    BusinessRolePermission.business_role_id == UUID(role_id),
                    BusinessRolePermission.permission_code == "pos.write",
                )
            )
        ).one_or_none()
        assert rp is not None

    async def test_invalid_permission_code_returns_422(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        owner = await _make_business_user(db_session)
        biz = await _make_business(db_session, owner)
        token = _owner_token(owner, biz.id)

        create_resp = await client.post(
            f"/api/v1/businesses/{biz.id}/roles",
            json={"name": "Cashier"},
            headers={"Authorization": f"Bearer {token}"},
        )
        role_id = create_resp.json()["id"]

        resp = await client.post(
            f"/api/v1/businesses/{biz.id}/roles/{role_id}/permissions",
            json={"permission_code": "not.a.real.code"},
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 422


class TestRemovePermission:
    async def test_removes_permission(self, client: AsyncClient, db_session: AsyncSession) -> None:
        owner = await _make_business_user(db_session)
        biz = await _make_business(db_session, owner)
        token = _owner_token(owner, biz.id)

        create_resp = await client.post(
            f"/api/v1/businesses/{biz.id}/roles",
            json={"name": "Cashier"},
            headers={"Authorization": f"Bearer {token}"},
        )
        role_id = create_resp.json()["id"]

        await client.post(
            f"/api/v1/businesses/{biz.id}/roles/{role_id}/permissions",
            json={"permission_code": "pos.write"},
            headers={"Authorization": f"Bearer {token}"},
        )

        resp = await client.delete(
            f"/api/v1/businesses/{biz.id}/roles/{role_id}/permissions/pos.write",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 204

    async def test_not_found_returns_404(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        owner = await _make_business_user(db_session)
        biz = await _make_business(db_session, owner)
        token = _owner_token(owner, biz.id)

        create_resp = await client.post(
            f"/api/v1/businesses/{biz.id}/roles",
            json={"name": "Cashier"},
            headers={"Authorization": f"Bearer {token}"},
        )
        role_id = create_resp.json()["id"]

        resp = await client.delete(
            f"/api/v1/businesses/{biz.id}/roles/{role_id}/permissions/nonexistent.code",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 404


class TestAssignStaff:
    async def test_assigns_by_user_id(self, client: AsyncClient, db_session: AsyncSession) -> None:
        owner = await _make_business_user(db_session)
        biz = await _make_business(db_session, owner)
        token = _owner_token(owner, biz.id)

        create_resp = await client.post(
            f"/api/v1/businesses/{biz.id}/roles",
            json={"name": "Cashier"},
            headers={"Authorization": f"Bearer {token}"},
        )
        role_id = create_resp.json()["id"]

        staff = await _make_business_user(db_session)

        resp = await client.post(
            f"/api/v1/businesses/{biz.id}/staff",
            json={
                "business_role_id": role_id,
                "user_id": str(staff.id),
            },
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 201
        assert resp.json()["detail"] == "Staff role assigned"

    async def test_assigns_by_phone(self, client: AsyncClient, db_session: AsyncSession) -> None:
        phone = f"+2557{uuid4().int % 100_000_000:08d}"
        owner = await _make_business_user(db_session)
        biz = await _make_business(db_session, owner)
        token = _owner_token(owner, biz.id)

        create_resp = await client.post(
            f"/api/v1/businesses/{biz.id}/roles",
            json={"name": "Cashier"},
            headers={"Authorization": f"Bearer {token}"},
        )
        role_id = create_resp.json()["id"]

        await _make_business_user(db_session, phone=phone)

        resp = await client.post(
            f"/api/v1/businesses/{biz.id}/staff",
            json={
                "business_role_id": role_id,
                "phone": phone,
            },
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 201

    async def test_duplicate_assignment_returns_409(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        owner = await _make_business_user(db_session)
        biz = await _make_business(db_session, owner)
        token = _owner_token(owner, biz.id)

        create_resp = await client.post(
            f"/api/v1/businesses/{biz.id}/roles",
            json={"name": "Cashier"},
            headers={"Authorization": f"Bearer {token}"},
        )
        role_id = create_resp.json()["id"]

        staff = await _make_business_user(db_session)

        await client.post(
            f"/api/v1/businesses/{biz.id}/staff",
            json={
                "business_role_id": role_id,
                "user_id": str(staff.id),
            },
            headers={"Authorization": f"Bearer {token}"},
        )

        resp = await client.post(
            f"/api/v1/businesses/{biz.id}/staff",
            json={
                "business_role_id": role_id,
                "user_id": str(staff.id),
            },
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 409

    async def test_neither_user_id_nor_phone_returns_422(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        owner = await _make_business_user(db_session)
        biz = await _make_business(db_session, owner)
        token = _owner_token(owner, biz.id)

        create_resp = await client.post(
            f"/api/v1/businesses/{biz.id}/roles",
            json={"name": "Cashier"},
            headers={"Authorization": f"Bearer {token}"},
        )
        role_id = create_resp.json()["id"]

        resp = await client.post(
            f"/api/v1/businesses/{biz.id}/staff",
            json={
                "business_role_id": role_id,
            },
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 422

    async def test_non_business_user_rejected(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        owner = await _make_business_user(db_session)
        biz = await _make_business(db_session, owner)
        token = _owner_token(owner, biz.id)

        create_resp = await client.post(
            f"/api/v1/businesses/{biz.id}/roles",
            json={"name": "Cashier"},
            headers={"Authorization": f"Bearer {token}"},
        )
        role_id = create_resp.json()["id"]

        platform_user = User(
            phone=f"+2557{uuid4().int % 100_000_000:08d}",
            email=f"staff{uuid4().hex[:8]}@oryonfoods.com",
            full_name="Platform Staff",
            user_category=UserCategory.PLATFORM_STAFF,
            status=UserStatus.ACTIVE,
            is_email_verified=True,
        )
        db_session.add(platform_user)
        await db_session.commit()

        resp = await client.post(
            f"/api/v1/businesses/{biz.id}/staff",
            json={
                "business_role_id": role_id,
                "user_id": str(platform_user.id),
            },
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 400

    async def test_invite_by_unseen_phone_creates_invited_user(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        phone = f"+2557{uuid4().int % 100_000_000:08d}"
        owner = await _make_business_user(db_session)
        biz = await _make_business(db_session, owner)
        token = _owner_token(owner, biz.id)

        create_resp = await client.post(
            f"/api/v1/businesses/{biz.id}/roles",
            json={"name": "Cashier"},
            headers={"Authorization": f"Bearer {token}"},
        )
        role_id = create_resp.json()["id"]

        resp = await client.post(
            f"/api/v1/businesses/{biz.id}/staff",
            json={
                "business_role_id": role_id,
                "phone": phone,
            },
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 201
        assert resp.json()["detail"] == "Staff role assigned"

        user = (await db_session.exec(select(User).where(User.phone == phone))).one()
        assert user.user_category == UserCategory.BUSINESS_STAFF
        assert user.status == UserStatus.INVITED
        assert user.password_hash is None
        assert user.is_phone_verified is False

        ubr = (
            await db_session.exec(
                select(UserBusinessRole).where(
                    UserBusinessRole.user_id == user.id,
                    UserBusinessRole.business_id == biz.id,
                    UserBusinessRole.business_role_id == UUID(role_id),
                )
            )
        ).one()
        assert ubr is not None

    async def test_assigns_by_email(self, client: AsyncClient, db_session: AsyncSession) -> None:
        email = f"staff-{uuid4().hex[:8]}@example.com"
        owner = await _make_business_user(db_session)
        biz = await _make_business(db_session, owner)
        token = _owner_token(owner, biz.id)

        create_resp = await client.post(
            f"/api/v1/businesses/{biz.id}/roles",
            json={"name": "Cashier"},
            headers={"Authorization": f"Bearer {token}"},
        )
        role_id = create_resp.json()["id"]

        staff = await _make_business_user(db_session, email=email)

        resp = await client.post(
            f"/api/v1/businesses/{biz.id}/staff",
            json={"business_role_id": role_id, "email": email},
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 201

        ubr = (
            await db_session.exec(
                select(UserBusinessRole).where(
                    UserBusinessRole.user_id == staff.id,
                    UserBusinessRole.business_id == biz.id,
                )
            )
        ).one()
        assert ubr.business_role_id == UUID(role_id)

    async def test_invite_by_unseen_email_creates_invited_user(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        # Emails are normalised to lowercase by the request schema.
        email = f"New-Staff-{uuid4().hex[:8]}@Example.com"
        normalised = email.lower()
        owner = await _make_business_user(db_session)
        biz = await _make_business(db_session, owner)
        token = _owner_token(owner, biz.id)

        create_resp = await client.post(
            f"/api/v1/businesses/{biz.id}/roles",
            json={"name": "Cashier"},
            headers={"Authorization": f"Bearer {token}"},
        )
        role_id = create_resp.json()["id"]

        resp = await client.post(
            f"/api/v1/businesses/{biz.id}/staff",
            json={
                "business_role_id": role_id,
                "email": email,
                "full_name": "Email Invitee",
            },
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 201

        user = (
            await db_session.exec(select(User).where(User.email == normalised))
        ).one()
        assert user.phone is None
        assert user.full_name == "Email Invitee"
        assert user.user_category == UserCategory.BUSINESS_STAFF
        assert user.status == UserStatus.INVITED
        assert user.password_hash is None
        assert user.is_email_verified is False

        listed = await client.get(
            f"/api/v1/businesses/{biz.id}/staff",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert listed.status_code == 200
        entry = next(row for row in listed.json() if row["user_id"] == str(user.id))
        assert entry["phone"] is None
        assert entry["email"] == normalised

    async def test_invite_by_email_reuses_existing_phone_less_user(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        email = f"phone-less-{uuid4().hex[:8]}@example.com"
        existing = User(
            phone=None,
            email=email,
            full_name="",
            user_category=UserCategory.BUSINESS_STAFF,
            status=UserStatus.INVITED,
        )
        db_session.add(existing)
        await db_session.commit()
        await db_session.refresh(existing)

        owner = await _make_business_user(db_session)
        biz = await _make_business(db_session, owner)
        token = _owner_token(owner, biz.id)

        create_resp = await client.post(
            f"/api/v1/businesses/{biz.id}/roles",
            json={"name": "Cashier"},
            headers={"Authorization": f"Bearer {token}"},
        )
        role_id = create_resp.json()["id"]

        resp = await client.post(
            f"/api/v1/businesses/{biz.id}/staff",
            json={
                "business_role_id": role_id,
                "email": email,
                "full_name": "Now Named",
            },
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 201

        users = (await db_session.exec(select(User).where(User.email == email))).all()
        assert len(users) == 1
        assert users[0].id == existing.id
        await db_session.refresh(existing)
        # A blank name left by an earlier invite is filled in.
        assert users[0].full_name == "Now Named"

    async def test_store_invite_by_unseen_email_creates_store_staff(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        email = f"store-staff-{uuid4().hex[:8]}@example.com"
        owner = await _make_business_user(db_session)
        biz = await _make_business(db_session, owner)
        token = _owner_token(owner, biz.id)

        store = Store(
            business_id=biz.id,
            name="Store A",
            token=f"st-{uuid4().hex[:12]}",
            location_type=LocationType.RESTAURANT_BRANCH,
        )
        db_session.add(store)
        await db_session.commit()
        await db_session.refresh(store)

        create_resp = await client.post(
            f"/api/v1/businesses/{biz.id}/roles",
            json={"name": "Cashier"},
            headers={"Authorization": f"Bearer {token}"},
        )
        role_id = create_resp.json()["id"]

        resp = await client.post(
            f"/api/v1/businesses/{biz.id}/stores/{store.id}/staff",
            json={
                "business_role_id": role_id,
                "email": email,
                "full_name": "Store Invitee",
            },
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 201

        user = (await db_session.exec(select(User).where(User.email == email))).one()
        assert user.phone is None
        assert user.user_category == UserCategory.BUSINESS_STORE_STAFF
        assert user.status == UserStatus.INVITED
        assert user.full_name == "Store Invitee"

        usr = (
            await db_session.exec(
                select(UserStoreRole).where(
                    UserStoreRole.user_id == user.id,
                    UserStoreRole.store_id == store.id,
                )
            )
        ).one()
        assert usr.business_role_id == UUID(role_id)

    async def test_invite_existing_active_user_reuses_no_duplicate(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        phone = f"+2557{uuid4().int % 100_000_000:08d}"
        owner = await _make_business_user(db_session)
        biz = await _make_business(db_session, owner)
        token = _owner_token(owner, biz.id)

        create_resp = await client.post(
            f"/api/v1/businesses/{biz.id}/roles",
            json={"name": "Cashier"},
            headers={"Authorization": f"Bearer {token}"},
        )
        role_id = create_resp.json()["id"]

        staff = await _make_business_user(db_session, phone=phone)

        resp = await client.post(
            f"/api/v1/businesses/{biz.id}/staff",
            json={
                "business_role_id": role_id,
                "phone": phone,
            },
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 201

        users = (await db_session.exec(select(User).where(User.phone == phone))).all()
        assert len(users) == 1
        assert users[0].id == staff.id
        assert users[0].status == UserStatus.ACTIVE

        ubr = (
            await db_session.exec(
                select(UserBusinessRole).where(
                    UserBusinessRole.user_id == staff.id,
                    UserBusinessRole.business_id == biz.id,
                )
            )
        ).all()
        assert len(ubr) == 1

    async def test_invite_rolls_back_when_assign_fails_after_user_creation(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        phone = f"+2557{uuid4().int % 100_000_000:08d}"
        owner = await _make_business_user(db_session)
        other_owner = await _make_business_user(db_session)
        biz = await _make_business(db_session, owner)
        other_biz = await _make_business(db_session, other_owner)
        token = _owner_token(owner, biz.id)

        other_role_resp = await client.post(
            f"/api/v1/businesses/{other_biz.id}/roles",
            json={"name": "Cashier"},
            headers={"Authorization": f"Bearer {token}"},
        )
        other_role_id = other_role_resp.json()["id"]

        resp = await client.post(
            f"/api/v1/businesses/{biz.id}/staff",
            json={
                "business_role_id": other_role_id,
                "phone": phone,
            },
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 404

        user = (await db_session.exec(select(User).where(User.phone == phone))).one_or_none()
        assert user is None


class TestListStaff:
    async def test_empty_business_returns_empty_list(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        owner = await _make_business_user(db_session)
        biz = await _make_business(db_session, owner)
        token = _owner_token(owner, biz.id)

        resp = await client.get(
            f"/api/v1/businesses/{biz.id}/staff",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 200
        assert resp.json() == []

    async def test_lists_staff_with_their_roles(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        owner = await _make_business_user(db_session)
        biz = await _make_business(db_session, owner)
        token = _owner_token(owner, biz.id)

        cashier_resp = await client.post(
            f"/api/v1/businesses/{biz.id}/roles",
            json={"name": "Cashier"},
            headers={"Authorization": f"Bearer {token}"},
        )
        cashier_id = cashier_resp.json()["id"]

        phone = f"+2557{uuid4().int % 100_000_000:08d}"
        staff = await _make_business_user(db_session, phone=phone)

        await client.post(
            f"/api/v1/businesses/{biz.id}/staff",
            json={"business_role_id": cashier_id, "phone": phone},
            headers={"Authorization": f"Bearer {token}"},
        )

        resp = await client.get(
            f"/api/v1/businesses/{biz.id}/staff",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 200
        data = resp.json()
        assert len(data) == 1
        assert data[0]["user_id"] == str(staff.id)
        assert data[0]["phone"] == phone
        assert data[0]["full_name"] == "Business User"
        assert data[0]["status"] == "active"
        assert data[0]["roles"] == [
            {
                "business_role_id": cashier_id,
                "name": "Cashier",
                "store_id": None,
                "store_name": None,
            }
        ]

    async def test_multi_role_staff_grouped_into_one_entry(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        owner = await _make_business_user(db_session)
        biz = await _make_business(db_session, owner)
        token = _owner_token(owner, biz.id)

        cashier_id = (
            await client.post(
                f"/api/v1/businesses/{biz.id}/roles",
                json={"name": "Cashier"},
                headers={"Authorization": f"Bearer {token}"},
            )
        ).json()["id"]
        kitchen_id = (
            await client.post(
                f"/api/v1/businesses/{biz.id}/roles",
                json={"name": "Kitchen"},
                headers={"Authorization": f"Bearer {token}"},
            )
        ).json()["id"]

        phone = f"+2557{uuid4().int % 100_000_000:08d}"
        await _make_business_user(db_session, phone=phone)

        for role_id in (cashier_id, kitchen_id):
            resp = await client.post(
                f"/api/v1/businesses/{biz.id}/staff",
                json={"business_role_id": role_id, "phone": phone},
                headers={"Authorization": f"Bearer {token}"},
            )
            assert resp.status_code == 201

        resp = await client.get(
            f"/api/v1/businesses/{biz.id}/staff",
            headers={"Authorization": f"Bearer {token}"},
        )
        data = resp.json()
        assert len(data) == 1
        role_names = {r["name"] for r in data[0]["roles"]}
        assert role_names == {"Cashier", "Kitchen"}

    async def test_store_only_staff_appears_with_store_fields(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        from app.models.business import UserStoreRole

        owner = await _make_business_user(db_session)
        biz = await _make_business(db_session, owner)
        token = _owner_token(owner, biz.id)

        cashier_id = (
            await client.post(
                f"/api/v1/businesses/{biz.id}/roles",
                json={"name": "Cashier"},
                headers={"Authorization": f"Bearer {token}"},
            )
        ).json()["id"]

        store_id = (
            await client.post(
                f"/api/v1/businesses/{biz.id}/stores",
                json={"name": "Branch", "location_type": "restaurant_branch"},
                headers={"Authorization": f"Bearer {token}"},
            )
        ).json()["id"]

        phone = f"+2557{uuid4().int % 100_000_000:08d}"
        staffer = await _make_business_user(db_session, phone=phone)
        db_session.add(
            UserStoreRole(
                user_id=staffer.id,
                business_id=biz.id,
                store_id=UUID(store_id),
                business_role_id=UUID(cashier_id),
            )
        )
        await db_session.commit()

        resp = await client.get(
            f"/api/v1/businesses/{biz.id}/staff",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 200
        data = resp.json()
        assert len(data) == 1
        assert data[0]["user_id"] == str(staffer.id)
        assert data[0]["roles"] == [
            {
                "business_role_id": cashier_id,
                "name": "Cashier",
                "store_id": store_id,
                "store_name": "Branch",
            }
        ]

    async def test_without_permission_returns_403(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        owner = await _make_business_user(db_session)
        biz = await _make_business(db_session, owner)
        token = _staff_token(owner, biz.id, [PermissionCode.INVENTORY_VIEW.value])

        resp = await client.get(
            f"/api/v1/businesses/{biz.id}/staff",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 403

    async def test_token_for_different_business_returns_403(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        owner = await _make_business_user(db_session)
        other_owner = await _make_business_user(db_session)
        biz = await _make_business(db_session, owner)
        other_biz = await _make_business(db_session, other_owner)
        # Token scoped to `biz`, but the request path names `other_biz`.
        token = _owner_token(owner, biz.id)

        resp = await client.get(
            f"/api/v1/businesses/{other_biz.id}/staff",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 403


class TestRevokeStaffRole:
    async def test_revokes_one_role_leaves_others(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        owner = await _make_business_user(db_session)
        biz = await _make_business(db_session, owner)
        token = _owner_token(owner, biz.id)

        cashier_id = (
            await client.post(
                f"/api/v1/businesses/{biz.id}/roles",
                json={"name": "Cashier"},
                headers={"Authorization": f"Bearer {token}"},
            )
        ).json()["id"]
        kitchen_id = (
            await client.post(
                f"/api/v1/businesses/{biz.id}/roles",
                json={"name": "Kitchen"},
                headers={"Authorization": f"Bearer {token}"},
            )
        ).json()["id"]

        phone = f"+2557{uuid4().int % 100_000_000:08d}"
        staff = await _make_business_user(db_session, phone=phone)
        for role_id in (cashier_id, kitchen_id):
            await client.post(
                f"/api/v1/businesses/{biz.id}/staff",
                json={"business_role_id": role_id, "phone": phone},
                headers={"Authorization": f"Bearer {token}"},
            )

        resp = await client.delete(
            f"/api/v1/businesses/{biz.id}/staff/{staff.id}/roles/{cashier_id}",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 204

        remaining = (
            await db_session.exec(
                select(UserBusinessRole).where(
                    UserBusinessRole.user_id == staff.id,
                    UserBusinessRole.business_id == biz.id,
                )
            )
        ).all()
        assert len(remaining) == 1
        assert remaining[0].business_role_id == UUID(kitchen_id)

    async def test_nonexistent_assignment_returns_404(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        owner = await _make_business_user(db_session)
        biz = await _make_business(db_session, owner)
        token = _owner_token(owner, biz.id)

        role_id = (
            await client.post(
                f"/api/v1/businesses/{biz.id}/roles",
                json={"name": "Cashier"},
                headers={"Authorization": f"Bearer {token}"},
            )
        ).json()["id"]
        staff = await _make_business_user(db_session)

        resp = await client.delete(
            f"/api/v1/businesses/{biz.id}/staff/{staff.id}/roles/{role_id}",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 404

    async def test_without_permission_returns_403(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        owner = await _make_business_user(db_session)
        biz = await _make_business(db_session, owner)
        token = _staff_token(owner, biz.id, [PermissionCode.INVENTORY_VIEW.value])
        staff = await _make_business_user(db_session)

        resp = await client.delete(
            f"/api/v1/businesses/{biz.id}/staff/{staff.id}/roles/{uuid4()}",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 403


class TestListRolePermissions:
    async def test_lists_assigned_permissions(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        owner = await _make_business_user(db_session)
        biz = await _make_business(db_session, owner)
        token = _owner_token(owner, biz.id)

        role_id = (
            await client.post(
                f"/api/v1/businesses/{biz.id}/roles",
                json={"name": "Cashier"},
                headers={"Authorization": f"Bearer {token}"},
            )
        ).json()["id"]

        for code in (PermissionCode.POS_WRITE.value, PermissionCode.INVENTORY_VIEW.value):
            resp = await client.post(
                f"/api/v1/businesses/{biz.id}/roles/{role_id}/permissions",
                json={"permission_code": code},
                headers={"Authorization": f"Bearer {token}"},
            )
            assert resp.status_code == 201

        resp = await client.get(
            f"/api/v1/businesses/{biz.id}/roles/{role_id}/permissions",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 200
        codes = {p["permission_code"] for p in resp.json()}
        assert codes == {PermissionCode.POS_WRITE.value, PermissionCode.INVENTORY_VIEW.value}

    async def test_role_with_no_permissions_returns_empty_list(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        owner = await _make_business_user(db_session)
        biz = await _make_business(db_session, owner)
        token = _owner_token(owner, biz.id)

        role_id = (
            await client.post(
                f"/api/v1/businesses/{biz.id}/roles",
                json={"name": "Cashier"},
                headers={"Authorization": f"Bearer {token}"},
            )
        ).json()["id"]

        resp = await client.get(
            f"/api/v1/businesses/{biz.id}/roles/{role_id}/permissions",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 200
        assert resp.json() == []

    async def test_wrong_business_returns_404(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        owner = await _make_business_user(db_session)
        other_owner = await _make_business_user(db_session)
        biz = await _make_business(db_session, owner)
        other_biz = await _make_business(db_session, other_owner)
        token = _owner_token(owner, biz.id)

        role_id = (
            await client.post(
                f"/api/v1/businesses/{other_biz.id}/roles",
                json={"name": "Cashier"},
                headers={"Authorization": f"Bearer {token}"},
            )
        ).json()["id"]

        # Token is scoped to `biz`, but this role belongs to `other_biz`.
        resp = await client.get(
            f"/api/v1/businesses/{biz.id}/roles/{role_id}/permissions",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 404
