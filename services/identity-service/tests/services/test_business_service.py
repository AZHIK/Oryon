from uuid import uuid4

import pytest
import pytest_asyncio
from sqlmodel import select
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.permission_codes import PermissionCode
from app.models.business import (
    Business,
    BusinessRole,
    BusinessRolePermission,
    Store,
    StoreSetting,
    UserBusinessRole,
)
from app.models.user import User, UserCategory
from app.services.business_service import create_business
from app.services.store import validate_store_type


@pytest_asyncio.fixture
async def test_user(db_session: AsyncSession) -> User:
    user = User(
        phone=f"+2557{uuid4().hex[:9]}",
        full_name="Business Creator",
        user_category=UserCategory.BUSINESS_STAFF,
    )
    async with db_session.begin():
        db_session.add(user)
    return user


async def _make_user(db_session: AsyncSession) -> User:
    """A second (or third...) distinct owner, for tests that need more than
    one business — owner_user_id is now unique, so a single test_user can no
    longer own two of them.
    """
    user = User(
        phone=f"+2557{uuid4().hex[:9]}",
        full_name="Business Creator",
        user_category=UserCategory.BUSINESS_STAFF,
    )
    async with db_session.begin():
        db_session.add(user)
    return user


@pytest_asyncio.fixture
async def seeded_templates(db_session: AsyncSession) -> None:
    """Seed all role templates into the test DB."""
    import app.db.seed_role_templates as srt
    from app.models.template import RoleTemplate, RoleTemplatePermission

    async with db_session.begin():
        for template_seed in srt.ROLE_TEMPLATE_SEEDS:
            rt = RoleTemplate(
                name=template_seed.name,
                description=template_seed.description,
                business_type=template_seed.business_type,
                is_owner_template=template_seed.is_owner_template,
            )
            db_session.add(rt)
            await db_session.flush()
            for code in template_seed.permissions:
                permission_code = code.value if isinstance(code, PermissionCode) else code
                db_session.add(
                    RoleTemplatePermission(
                        role_template_id=rt.id,
                        permission_code=permission_code,
                    )
                )


class TestCreateBusiness:
    async def test_creates_business_with_owner_role(
        self, db_session: AsyncSession, test_user: User, seeded_templates: None
    ) -> None:
        result = await create_business(
            db_session,
            creator_user_id=test_user.id,
            name="Test Restaurant",
            business_type="restaurant",
        )
        biz = result.business

        assert biz.name == "Test Restaurant"
        assert biz.business_type == "restaurant"
        assert biz.owner_user_id == test_user.id

        roles = (
            await db_session.exec(select(BusinessRole).where(BusinessRole.business_id == biz.id))
        ).all()
        assert len(roles) >= 1

        owner_role = next((r for r in roles if r.is_protected), None)
        assert owner_role is not None
        assert "owner" in owner_role.name.lower()

        assignment = (
            await db_session.exec(
                select(UserBusinessRole).where(
                    UserBusinessRole.user_id == test_user.id,
                    UserBusinessRole.business_id == biz.id,
                )
            )
        ).one_or_none()
        assert assignment is not None
        assert assignment.business_role_id == owner_role.id

    async def test_owner_role_has_permissions(
        self, db_session: AsyncSession, test_user: User, seeded_templates: None
    ) -> None:
        result = await create_business(
            db_session,
            creator_user_id=test_user.id,
            name="Perm Test Biz",
            business_type="restaurant",
        )
        biz = result.business

        roles = (
            await db_session.exec(select(BusinessRole).where(BusinessRole.business_id == biz.id))
        ).all()
        owner_role = next(r for r in roles if r.is_protected)

        perms = (
            await db_session.exec(
                select(BusinessRolePermission).where(
                    BusinessRolePermission.business_role_id == owner_role.id,
                )
            )
        ).all()
        codes = {p.permission_code for p in perms}
        assert PermissionCode.POS_WRITE.value in codes
        assert PermissionCode.INVENTORY_VIEW.value in codes
        assert PermissionCode.BUSINESSES_VIEW.value in codes

    async def test_supplier_gets_different_roles_than_restaurant(
        self, db_session: AsyncSession, test_user: User, seeded_templates: None
    ) -> None:
        other_owner = await _make_user(db_session)
        rest_result = await create_business(
            db_session,
            creator_user_id=test_user.id,
            name="R",
            business_type="restaurant",
        )
        supp_result = await create_business(
            db_session,
            creator_user_id=other_owner.id,
            name="S",
            business_type="supplier",
        )
        restaurant = rest_result.business
        supplier = supp_result.business

        rest_roles = (
            await db_session.exec(
                select(BusinessRole).where(BusinessRole.business_id == restaurant.id)
            )
        ).all()
        supp_roles = (
            await db_session.exec(
                select(BusinessRole).where(BusinessRole.business_id == supplier.id)
            )
        ).all()

        rest_names = {r.name for r in rest_roles}
        supp_names = {r.name for r in supp_roles}
        assert rest_names != supp_names

        rest_owner = next(r for r in rest_roles if r.is_protected)
        rest_perms = {
            p.permission_code
            for p in (
                await db_session.exec(
                    select(BusinessRolePermission).where(
                        BusinessRolePermission.business_role_id == rest_owner.id,
                    )
                )
            ).all()
        }
        assert PermissionCode.POS_WRITE.value in rest_perms

        supp_owner = next(r for r in supp_roles if r.is_protected)
        supp_perms = {
            p.permission_code
            for p in (
                await db_session.exec(
                    select(BusinessRolePermission).where(
                        BusinessRolePermission.business_role_id == supp_owner.id,
                    )
                )
            ).all()
        }
        assert PermissionCode.SUPPLIER_PRICE_MANAGE.value in supp_perms
        assert PermissionCode.POS_WRITE.value not in supp_perms

    async def test_rolls_back_entirely_on_failure(
        self, db_session: AsyncSession, test_user: User, seeded_templates: None
    ) -> None:
        async with db_session.begin():
            before_biz_count = (await db_session.exec(select(Business))).all()

        with pytest.raises(ValueError):
            await create_business(
                db_session,
                creator_user_id=test_user.id,
                name="Fail Biz",
                business_type="nonexistent_type",
            )

        async with db_session.begin():
            after_biz_count = (await db_session.exec(select(Business))).all()
        assert len(after_biz_count) == len(before_biz_count)

        async with db_session.begin():
            roles = (await db_session.exec(select(BusinessRole))).all()
        assert len(roles) == 0

        async with db_session.begin():
            stores = (await db_session.exec(select(Store))).all()
        assert len(stores) == 0

        async with db_session.begin():
            settings = (await db_session.exec(select(StoreSetting))).all()
        assert len(settings) == 0

    async def test_second_business_for_same_owner_is_rejected(
        self, db_session: AsyncSession, test_user: User, seeded_templates: None
    ) -> None:
        from app.core.exceptions import BusinessAlreadyExistsError

        await create_business(
            db_session,
            creator_user_id=test_user.id,
            name="First Biz",
            business_type="restaurant",
        )

        with pytest.raises(BusinessAlreadyExistsError):
            await create_business(
                db_session,
                creator_user_id=test_user.id,
                name="Second Biz",
                business_type="restaurant",
            )

    async def test_forced_failure_mid_creation_rolls_back_business_store_settings(
        self, db_session: AsyncSession, test_user: User, seeded_templates: None
    ) -> None:
        """A failure after the store + settings rows are flushed still rolls
        back all three (business, store, store_setting) atomically."""
        from unittest.mock import patch

        with (
            patch(
                "app.services.business_service.generate_store_token",
                side_effect=RuntimeError("token generation failed"),
            ),
            pytest.raises(RuntimeError),
        ):
            await create_business(
                db_session,
                creator_user_id=test_user.id,
                name="Atomic Biz",
                business_type="restaurant",
            )

        async with db_session.begin():
            assert (await db_session.exec(select(Business))).all() == []
        async with db_session.begin():
            assert (await db_session.exec(select(Store))).all() == []
        async with db_session.begin():
            assert (await db_session.exec(select(StoreSetting))).all() == []

    async def test_creates_default_primary_store_and_settings(
        self, db_session: AsyncSession, test_user: User, seeded_templates: None
    ) -> None:
        result = await create_business(
            db_session,
            creator_user_id=test_user.id,
            name="Loc Test",
            business_type="restaurant",
            country_code="TZ",
            city="Arusha",
            timezone="Africa/Dar_es_Salaam",
        )
        biz = result.business

        assert result.default_store_id is not None
        assert result.default_store_setting_id is not None

        stores = (await db_session.exec(select(Store).where(Store.business_id == biz.id))).all()
        assert len(stores) == 1

        store = stores[0]
        assert store.is_primary is True
        assert store.name == "Main Location"
        assert store.token
        assert store.country_code == biz.country_code
        assert store.city == biz.city
        assert store.timezone == biz.timezone

        settings = (
            await db_session.exec(select(StoreSetting).where(StoreSetting.store_id == store.id))
        ).all()
        assert len(settings) == 1
        assert settings[0].active is True
        assert settings[0].store_id == store.id

        validate_store_type(biz.business_type, store.location_type)

    async def test_default_store_type_is_valid_for_business_type(
        self, db_session: AsyncSession, test_user: User, seeded_templates: None
    ) -> None:
        cases: list[tuple[str, Business]] = []
        for bt in ("restaurant", "supplier", "farmer", "distributor", "platform_operator"):
            owner = await _make_user(db_session)
            result = await create_business(
                db_session,
                creator_user_id=owner.id,
                name=f"Type Test {bt}",
                business_type=bt,
            )
            cases.append((bt, result.business))

        for bt, biz in cases:
            stores = (await db_session.exec(select(Store).where(Store.business_id == biz.id))).all()
            assert len(stores) == 1
            store = stores[0]
            validate_store_type(bt, store.location_type)

    async def test_each_business_store_has_unique_token(
        self, db_session: AsyncSession, test_user: User, seeded_templates: None
    ) -> None:
        other_owner = await _make_user(db_session)
        await create_business(
            db_session, creator_user_id=test_user.id, name="Token A", business_type="restaurant"
        )
        await create_business(
            db_session, creator_user_id=other_owner.id, name="Token B", business_type="restaurant"
        )

        stores = (await db_session.exec(select(Store))).all()
        assert len(stores) == 2
        assert len({s.token for s in stores}) == 2
        assert all(s.token for s in stores)

    async def test_events_fire_with_correct_payloads(
        self, db_session: AsyncSession, test_user: User, seeded_templates: None
    ) -> None:
        from unittest.mock import patch

        events: list[dict] = []

        async def _capture(event_name: str, payload: dict) -> None:
            events.append({"name": event_name, "payload": payload})

        with (
            patch("app.services.business_service.publish_event", side_effect=_capture),
            patch("app.services.audit_events.publish_event", side_effect=_capture),
        ):
            result = await create_business(
                db_session,
                creator_user_id=test_user.id,
                name="Event Test",
                business_type="restaurant",
            )
            biz = result.business

        event_names = {e["name"] for e in events}
        assert "business.created" in event_names
        assert "audit.recorded" in event_names

        biz_created = [e for e in events if e["name"] == "business.created"][0]
        assert biz_created["payload"]["business_id"] == str(biz.id)
        assert biz_created["payload"]["creator_user_id"] == str(test_user.id)
        assert biz_created["payload"]["business_type"] == "restaurant"
        assert biz_created["payload"]["cloned_role_count"] >= 1

        audits = [e for e in events if e["name"] == "audit.recorded"]
        actions = {a["payload"]["action"] for a in audits}
        assert "business.created" in actions
        assert "business_role.assigned" in actions
