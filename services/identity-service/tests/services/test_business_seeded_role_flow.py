"""Integration proof (Part 3) that seeded role_templates actually flow into the
business-creation flow as real business_roles.

Creating a new business must clone its business_type's Owner template AND every
seeded non-owner template into BusinessRole/BusinessRolePermission rows.
"""

from uuid import uuid4

import pytest_asyncio
from sqlmodel import select
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.permission_codes import PermissionCode
from app.db.seed_role_templates import seed_role_templates
from app.models import BusinessRole, BusinessRolePermission
from app.models.user import User, UserCategory
from app.services.business_service import create_business


@pytest_asyncio.fixture
async def test_user(db_session: AsyncSession) -> User:
    user = User(
        phone=f"+2558{uuid4().hex[:9]}",
        full_name="Seeded Flow Creator",
        user_category=UserCategory.BUSINESS_STAFF,
    )
    async with db_session.begin():
        db_session.add(user)
    return user


@pytest_asyncio.fixture
async def _seeded(db_session: AsyncSession) -> None:
    """Seed all role templates via the production seed function."""
    await db_session.run_sync(seed_role_templates)


# Owner roles carry the full owner template's set (validated exactly in the unit
# tests); here we prove the cloned owner has real permissions by requiring a
# business-type-appropriate subset.
_RESTAURANT_OWNER_REQUIRED = {
    PermissionCode.POS_WRITE.value,
    PermissionCode.POS_REFUND.value,
    PermissionCode.INVENTORY_VIEW.value,
    PermissionCode.INVENTORY_ADJUST.value,
    PermissionCode.BUSINESSES_VIEW.value,
    PermissionCode.BUSINESSES_UPDATE.value,
}

_SUPPLIER_OWNER_REQUIRED = {
    PermissionCode.INVENTORY_VIEW.value,
    PermissionCode.INVENTORY_ADJUST.value,
    PermissionCode.BUSINESSES_VIEW.value,
    PermissionCode.BUSINESSES_UPDATE.value,
    PermissionCode.SUPPLIER_PRICE_MANAGE.value,
    PermissionCode.PROCUREMENT_CREATE.value,
}

# Non-owner roles: EXACT full permission sets.
_RESTAURANT_NON_OWNER: dict[str, set[str]] = {
    "Manager": {
        PermissionCode.POS_WRITE.value,
        PermissionCode.POS_VIEW.value,
        PermissionCode.POS_REFUND.value,
        PermissionCode.INVENTORY_VIEW.value,
        PermissionCode.INVENTORY_ADJUST.value,
        PermissionCode.INVENTORY_WASTE_RECORD.value,
        PermissionCode.INVENTORY_TRANSFER.value,
        PermissionCode.INVENTORY_ITEMS_CREATE.value,
        PermissionCode.INVENTORY_ITEMS_UPDATE.value,
        PermissionCode.INVENTORY_ITEMS_DEACTIVATE.value,
        PermissionCode.USER_BUSINESS_ROLES_VIEW.value,
        PermissionCode.USER_BUSINESS_ROLES_ASSIGN.value,
        PermissionCode.STORES_SWITCH.value,
        PermissionCode.REPORTS_VIEW.value,
        PermissionCode.REPORTS_EXPORT.value,
        PermissionCode.COURIERS_VIEW.value,
    },
    "Cashier": {
        PermissionCode.POS_WRITE.value,
        PermissionCode.POS_VIEW.value,
        PermissionCode.INVENTORY_VIEW.value,
        PermissionCode.COURIERS_VIEW.value,
    },
    "Kitchen Staff": {
        PermissionCode.INVENTORY_VIEW.value,
        PermissionCode.INVENTORY_WASTE_RECORD.value,
        PermissionCode.REPORTS_VIEW.value,
    },
    "Stock Controller": {
        PermissionCode.INVENTORY_VIEW.value,
        PermissionCode.INVENTORY_ADJUST.value,
        PermissionCode.INVENTORY_WASTE_RECORD.value,
        PermissionCode.INVENTORY_TRANSFER.value,
        PermissionCode.INVENTORY_ITEMS_CREATE.value,
        PermissionCode.INVENTORY_ITEMS_UPDATE.value,
        PermissionCode.REPORTS_VIEW.value,
    },
}

_SUPPLIER_NON_OWNER: dict[str, set[str]] = {
    "Sales Admin": {
        PermissionCode.SUPPLIER_PRICE_MANAGE.value,
        PermissionCode.INVENTORY_VIEW.value,
        PermissionCode.INVENTORY_ADJUST.value,
    },
    "Warehouse Staff": {
        PermissionCode.INVENTORY_VIEW.value,
        PermissionCode.INVENTORY_ADJUST.value,
        PermissionCode.INVENTORY_TRANSFER.value,
    },
}


async def _role_codes(db_session: AsyncSession, role: BusinessRole) -> set[str]:
    return {
        p.permission_code
        for p in (
            await db_session.exec(
                select(BusinessRolePermission).where(
                    BusinessRolePermission.business_role_id == role.id
                )
            )
        ).all()
    }


async def test_restaurant_creation_provisions_owner_plus_all_four_templates(
    db_session: AsyncSession, test_user: User, _seeded: None
) -> None:
    result = await create_business(
        db_session,
        creator_user_id=test_user.id,
        name="Seeded Restaurant",
        business_type="restaurant",
    )
    biz = result.business

    roles = (
        await db_session.exec(select(BusinessRole).where(BusinessRole.business_id == biz.id))
    ).all()
    role_by_name = {r.name: r for r in roles}

    want_names = {"restaurant_owner", *list(_RESTAURANT_NON_OWNER)}
    assert set(role_by_name) == want_names, f"got {sorted(role_by_name)}"

    owner = role_by_name["restaurant_owner"]
    assert owner.is_protected is True
    owner_codes = await _role_codes(db_session, owner)
    assert owner_codes >= _RESTAURANT_OWNER_REQUIRED

    for name, want in _RESTAURANT_NON_OWNER.items():
        role = role_by_name[name]
        assert role.is_protected is False
        got = await _role_codes(db_session, role)
        assert got == want, f"{name} got {sorted(got)} want {sorted(want)}"


async def test_supplier_business_provisions_owner_and_two_templates(
    db_session: AsyncSession, test_user: User, _seeded: None
) -> None:
    result = await create_business(
        db_session,
        creator_user_id=test_user.id,
        name="Seeded Supplier",
        business_type="supplier",
    )
    biz = result.business

    roles = (
        await db_session.exec(select(BusinessRole).where(BusinessRole.business_id == biz.id))
    ).all()
    role_by_name = {r.name: r for r in roles}

    want_names = {"supplier_owner", *list(_SUPPLIER_NON_OWNER)}
    assert set(role_by_name) == want_names, f"got {sorted(role_by_name)}"

    owner = role_by_name["supplier_owner"]
    owner_codes = await _role_codes(db_session, owner)
    assert owner_codes >= _SUPPLIER_OWNER_REQUIRED

    for name, want in _SUPPLIER_NON_OWNER.items():
        role = role_by_name[name]
        assert role.is_protected is False
        got = await _role_codes(db_session, role)
        assert got == want, f"{name} got {sorted(got)} want {sorted(want)}"
