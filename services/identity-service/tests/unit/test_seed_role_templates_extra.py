"""Tests for the non-owner (deferred) business role_templates seeding (Part 3).

Uses an in-memory SQLite Session (same style as the permission-seed tests).
Integration with the business-creation flow lives in
``tests/services/test_business_seeded_role_flow.py``.
"""

import pytest
from sqlmodel import Session, SQLModel, create_engine, select

from app.core.permission_codes import PermissionCode
from app.db.seed_role_templates import ROLE_TEMPLATE_SEEDS, seed_role_templates
from app.models import RoleTemplate, RoleTemplatePermission


@pytest.fixture
def session() -> Session:
    engine = create_engine("sqlite:///:memory:")
    SQLModel.metadata.create_all(engine)
    with Session(engine) as session:
        yield session


def _template_codes(session: Session, template: RoleTemplate) -> set[str]:
    return {
        rtp.permission_code
        for rtp in session.exec(
            select(RoleTemplatePermission).where(
                RoleTemplatePermission.role_template_id == template.id
            )
        ).all()
    }


def test_seeding_twice_produces_no_duplicates(session: Session) -> None:
    seed_role_templates(session)
    seed_role_templates(session)

    templates = session.exec(select(RoleTemplate)).all()
    assert len(templates) == len(ROLE_TEMPLATE_SEEDS)
    assert len({(t.name, t.business_type) for t in templates}) == len(templates)

    perms = session.exec(select(RoleTemplatePermission)).all()
    pairs = {(p.role_template_id, p.permission_code) for p in perms}
    assert len(perms) == len(pairs)


def test_non_owner_templates_seeded_scoped_and_unprotected(session: Session) -> None:
    seed_role_templates(session)

    template_by_key = {
        (t.name, t.business_type): t for t in session.exec(select(RoleTemplate)).all()
    }

    non_owner = [seed for seed in ROLE_TEMPLATE_SEEDS if not seed.is_owner_template]
    assert non_owner, "expected non-owner templates to be defined"

    for seed in non_owner:
        template = template_by_key[(seed.name, seed.business_type)]
        assert template.business_type == seed.business_type
        assert template.is_owner_template is False, f"{seed.name} must not be owner"


def test_exact_permissions_for_every_template(session: Session) -> None:
    seed_role_templates(session)

    expected = {
        # restaurant
        "restaurant_owner": {
            PermissionCode.POS_WRITE.value,
            PermissionCode.POS_REFUND.value,
            PermissionCode.INVENTORY_VIEW.value,
            PermissionCode.INVENTORY_ADJUST.value,
            PermissionCode.PROCUREMENT_CREATE.value,
            PermissionCode.PROCUREMENT_APPROVE.value,
            PermissionCode.PROCUREMENT_AUTO_ORDER_ENABLE.value,
            PermissionCode.AI_FORECAST_VIEW.value,
            PermissionCode.AI_RECOMMENDATION_APPROVE.value,
            PermissionCode.BUSINESSES_VIEW.value,
            PermissionCode.BUSINESSES_UPDATE.value,
            PermissionCode.BUSINESS_ROLES_VIEW.value,
            PermissionCode.BUSINESS_ROLES_CREATE.value,
            PermissionCode.BUSINESS_ROLES_UPDATE.value,
            PermissionCode.BUSINESS_ROLES_DELETE.value,
            PermissionCode.BUSINESS_ROLES_MANAGE_PERMISSIONS.value,
            PermissionCode.USER_BUSINESS_ROLES_VIEW.value,
            PermissionCode.USER_BUSINESS_ROLES_ASSIGN.value,
            PermissionCode.USER_BUSINESS_ROLES_REVOKE.value,
            PermissionCode.STORES_VIEW.value,
            PermissionCode.STORES_CREATE.value,
            PermissionCode.STORES_UPDATE.value,
            PermissionCode.STORES_DELETE.value,
            PermissionCode.ORGANIZATIONS_VIEW.value,
        },
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
        # supplier / distributor
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
        # farmer
        "Farm Coordinator": {
            PermissionCode.FARMER_SUPPLY_COMMITMENT_MANAGE.value,
            PermissionCode.INVENTORY_VIEW.value,
            PermissionCode.INVENTORY_ADJUST.value,
        },
    }

    template_by_key = {
        (t.name, t.business_type): t for t in session.exec(select(RoleTemplate)).all()
    }
    for seed in ROLE_TEMPLATE_SEEDS:
        template = template_by_key[(seed.name, seed.business_type)]
        assert template.business_type == seed.business_type
        codes = _template_codes(session, template)
        if seed.is_owner_template:
            # Owner templates predate this work; verify the seed wrote exactly
            # its own (dup-free) definition. Owner templates include the "*"
            # wildcard, which is a plain string (not a PermissionCode member).
            assert codes == {
                c.value if isinstance(c, PermissionCode) else c for c in seed.permissions
            }, f"{seed.name} did not persist its own definition"
            continue
        assert seed.name in expected, f"no expected set defined for {seed.name}"
        assert codes == expected[seed.name], (
            f"{seed.name} ({seed.business_type}) mismatch: got {sorted(codes)} "
            f"want {sorted(expected[seed.name])}"
        )


def test_distributor_matches_supplier_sets(session: Session) -> None:
    seed_role_templates(session)
    by_type_name = {(t.business_type, t.name): t for t in session.exec(select(RoleTemplate)).all()}
    for name in ("Sales Admin", "Warehouse Staff"):
        supplier_codes = _template_codes(session, by_type_name[("supplier", name)])
        distributor_codes = _template_codes(session, by_type_name[("distributor", name)])
        assert supplier_codes == distributor_codes


def test_platform_operator_has_only_owner_template(session: Session) -> None:
    seed_role_templates(session)
    platform_templates = [
        t
        for t in session.exec(select(RoleTemplate)).all()
        if t.business_type == "platform_operator"
    ]
    assert len(platform_templates) == 1
    assert platform_templates[0].is_owner_template is True


def test_all_definitions_reference_enum_members() -> None:
    for seed in ROLE_TEMPLATE_SEEDS:
        for code in seed.permissions:
            if code == "*":
                # Owner templates carry the wildcard sentinel; it is not a
                # PermissionCode member because it grants every code.
                assert seed.is_owner_template
                continue
            assert isinstance(code, PermissionCode)
            assert PermissionCode(code.value) == code
