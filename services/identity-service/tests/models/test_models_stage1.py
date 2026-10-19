"""Stage 1 — SQLModel model shape tests.

Each model class is instantiated (no DB) to confirm required fields exist
and relationships are wired.  Persistence tests (FK relationships, cascade)
use the real Postgres test DB in Stage 2.
"""

from datetime import datetime
from uuid import UUID

from sqlmodel import SQLModel

from app.models import (
    Business,
    BusinessRole,
    BusinessRolePermission,
    BusinessStatus,
    BusinessType,
    Group,
    LocationType,
    LoginAttempt,
    Organization,
    Permission,
    PermissionType,
    PlatformRole,
    PlatformRolePermission,
    Role,
    RolePermission,
    RoleTemplate,
    RoleTemplatePermission,
    Store,
    StoreSetting,
    User,
    UserBusinessPermission,
    UserBusinessRole,
    UserCategory,
    UserGroup,
    UserPlatformRole,
    UserRole,
    UserStatus,
    UserStoreRole,
)


class TestUserModel:
    def test_create_user_minimal(self) -> None:
        u = User(phone="+254700000001", full_name="Alice", user_category=UserCategory.CONSUMER)
        assert isinstance(u.id, UUID)
        assert u.phone == "+254700000001"
        assert u.full_name == "Alice"
        assert u.user_category == UserCategory.CONSUMER
        assert u.status == UserStatus.ACTIVE
        assert u.is_active is True
        assert u.is_phone_verified is False
        assert u.is_email_verified is False
        assert u.email is None
        assert u.password_hash is None
        assert isinstance(u.created_at, datetime)
        assert isinstance(u.updated_at, datetime)

    def test_user_category_enum(self) -> None:
        assert UserCategory.PLATFORM_STAFF.value == "platform_staff"
        assert UserCategory.BUSINESS_STAFF.value == "business_staff"
        assert UserCategory.DRIVER.value == "driver"
        assert UserCategory.CONSUMER.value == "consumer"


class TestGroupModel:
    def test_create_permission(self) -> None:
        p = Permission(
            code="procurement.auto_order.enable",
            name="Enable automated orders",
            domain="procurement",
            is_ai_sensitive=True,
            requires_human_approval=True,
        )
        assert isinstance(p.id, UUID)
        assert p.is_ai_sensitive is True

    def test_create_group(self) -> None:
        g = Group(name="Finance")
        assert isinstance(g.id, UUID)
        assert g.name == "Finance"


class TestRoleModel:
    def test_create_role(self) -> None:
        r = Role(name="Manager", group_id=UUID("00000000-0000-0000-0000-000000000001"))
        assert isinstance(r.id, UUID)
        assert r.name == "Manager"


class TestRolePermissionModel:
    def test_create_role_permission(self) -> None:
        rp = RolePermission(
            role_id=UUID("00000000-0000-0000-0000-000000000001"),
            permission_code="pos.write",
        )
        assert rp.role_id == UUID("00000000-0000-0000-0000-000000000001")
        assert rp.permission_code == "pos.write"


class TestUserGroupModel:
    def test_create_user_group(self) -> None:
        ug = UserGroup(
            user_id=UUID("00000000-0000-0000-0000-000000000001"),
            group_id=UUID("00000000-0000-0000-0000-000000000002"),
        )
        assert ug.user_id == UUID("00000000-0000-0000-0000-000000000001")
        assert ug.group_id == UUID("00000000-0000-0000-0000-000000000002")


class TestUserRoleModel:
    def test_create_user_role(self) -> None:
        ur = UserRole(
            user_id=UUID("00000000-0000-0000-0000-000000000001"),
            role_id=UUID("00000000-0000-0000-0000-000000000002"),
        )
        assert ur.user_id == UUID("00000000-0000-0000-0000-000000000001")
        assert ur.role_id == UUID("00000000-0000-0000-0000-000000000002")


class TestBusinessModel:
    def test_create_organization(self) -> None:
        org = Organization(
            name="Dar Restaurant Group",
            owner_user_id=UUID("00000000-0000-0000-0000-000000000001"),
        )
        assert isinstance(org.id, UUID)
        assert org.country_code == "TZ"

    def test_create_business(self) -> None:
        b = Business(
            name="Nairobi Bistro",
            business_type=BusinessType.RESTAURANT,
            owner_user_id=UUID("00000000-0000-0000-0000-000000000001"),
        )
        assert isinstance(b.id, UUID)
        assert b.name == "Nairobi Bistro"
        assert b.business_type == BusinessType.RESTAURANT
        assert b.status == BusinessStatus.ACTIVE
        assert b.logo is None
        assert b.deleted_by is None

    def test_create_store(self) -> None:
        store = Store(
            business_id=UUID("00000000-0000-0000-0000-000000000001"),
            name="Main Kitchen",
            token="tok-123",
            location_type=LocationType.KITCHEN,
            is_primary=True,
        )
        assert isinstance(store.id, UUID)
        assert store.location_type == LocationType.KITCHEN
        assert store.status == BusinessStatus.ACTIVE
        assert store.token == "tok-123"
        assert store.deleted_by is None

    def test_create_store_setting(self) -> None:
        setting = StoreSetting(store_id=UUID("00000000-0000-0000-0000-000000000001"))
        assert isinstance(setting.id, UUID)
        assert setting.active is True
        assert setting.offer_retail is True
        assert setting.offer_wholesale is False
        assert setting.display_prices_inclusive_of_tax is False
        assert setting.preferred_currency == "TZS"
        assert setting.amount is None
        assert setting.max_payment_time_minutes is None


class TestBusinessRoleModel:
    def test_create_business_role(self) -> None:
        br = BusinessRole(
            business_id=UUID("00000000-0000-0000-0000-000000000001"),
            name="Cashier",
        )
        assert isinstance(br.id, UUID)
        assert br.name == "Cashier"
        assert br.is_protected is False


class TestBusinessRolePermissionModel:
    def test_create_business_role_permission(self) -> None:
        brp = BusinessRolePermission(
            business_role_id=UUID("00000000-0000-0000-0000-000000000001"),
            permission_code="pos.write",
        )
        assert brp.permission_code == "pos.write"


class TestUserBusinessRoleModel:
    def test_create_user_business_role(self) -> None:
        ubr = UserBusinessRole(
            user_id=UUID("00000000-0000-0000-0000-000000000001"),
            business_id=UUID("00000000-0000-0000-0000-000000000002"),
            business_role_id=UUID("00000000-0000-0000-0000-000000000003"),
        )
        assert isinstance(ubr.id, UUID)
        assert ubr.user_id != ubr.business_id

    def test_create_user_store_role(self) -> None:
        assignment = UserStoreRole(
            user_id=UUID("00000000-0000-0000-0000-000000000001"),
            business_id=UUID("00000000-0000-0000-0000-000000000002"),
            store_id=UUID("00000000-0000-0000-0000-000000000003"),
            business_role_id=UUID("00000000-0000-0000-0000-000000000004"),
        )
        assert isinstance(assignment.id, UUID)
        assert assignment.store_id != assignment.business_role_id


class TestUserBusinessPermissionModel:
    def test_create_override(self) -> None:
        ubp = UserBusinessPermission(
            user_id=UUID("00000000-0000-0000-0000-000000000001"),
            business_id=UUID("00000000-0000-0000-0000-000000000002"),
            permission_code="pos.refund",
            type=PermissionType.GRANT,
        )
        assert ubp.type == PermissionType.GRANT
        assert ubp.created_by is None


class TestPlatformRoleModel:
    def test_create_platform_role(self) -> None:
        pr = PlatformRole(name="driver")
        assert isinstance(pr.id, UUID)
        assert pr.name == "driver"


class TestPlatformRolePermissionModel:
    def test_create_platform_role_permission(self) -> None:
        prp = PlatformRolePermission(
            platform_role_id=UUID("00000000-0000-0000-0000-000000000001"),
            permission_code="delivery.update_status",
        )
        assert prp.platform_role_id == UUID("00000000-0000-0000-0000-000000000001")
        assert prp.permission_code == "delivery.update_status"


class TestUserPlatformRoleModel:
    def test_create_user_platform_role(self) -> None:
        upr = UserPlatformRole(
            user_id=UUID("00000000-0000-0000-0000-000000000001"),
            platform_role_id=UUID("00000000-0000-0000-0000-000000000002"),
        )
        assert isinstance(upr.id, UUID)


class TestAuthSecurityModel:
    def test_create_login_attempt(self) -> None:
        attempt = LoginAttempt(identifier="+255700000001", success=False)
        assert isinstance(attempt.id, UUID)
        assert attempt.success is False


class TestRoleTemplateModel:
    def test_create_role_template(self) -> None:
        rt = RoleTemplate(name="Owner Template", description="Template for business owners")
        assert isinstance(rt.id, UUID)
        assert rt.name == "Owner Template"


class TestRoleTemplatePermissionModel:
    def test_create_role_template_permission(self) -> None:
        rtp = RoleTemplatePermission(
            role_template_id=UUID("00000000-0000-0000-0000-000000000001"),
            permission_code="business.manage_roles",
        )
        assert rtp.permission_code == "business.manage_roles"


class TestMetadata:
    def test_all_27_tables_registered(self) -> None:
        assert len(SQLModel.metadata.tables) == 27
