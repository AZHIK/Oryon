from dataclasses import dataclass
from typing import Any
from uuid import UUID

import structlog
from sqlmodel import select
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.events import publish_event
from app.core.exceptions import BusinessAlreadyExistsError
from app.models.business import (
    Business,
    BusinessRole,
    BusinessRolePermission,
    LocationType,
    Store,
    StoreSetting,
    UserBusinessRole,
)
from app.models.template import RoleTemplate, RoleTemplatePermission
from app.services.audit_events import publish_audit_recorded
from app.services.store import generate_store_token, validate_store_type

logger = structlog.get_logger(__name__)


@dataclass
class CreateBusinessResult:
    """Result of a successful business creation.

    ``business`` — the newly created Business row.
    ``default_store_id`` — the UUID of the auto-created primary store,
    which Inventory Service will attach stock records to.
    ``default_store_setting_id`` — the UUID of the auto-created one-to-one
    StoreSetting row for the default store.
    """

    business: Business
    default_store_id: UUID
    default_store_setting_id: UUID


async def create_business(
    db: AsyncSession,
    *,
    creator_user_id: UUID,
    name: str,
    business_type: str,
    organization_id: UUID | None = None,
    tax_id: str | None = None,
    registration_number: str | None = None,
    email: str | None = None,
    phone: str | None = None,
    address: str | None = None,
    status: str = "active",
    logo: str | None = None,
    license_document_url: str | None = None,
    cuisine_type: str | None = None,
    country_code: str = "TZ",
    city: str | None = None,
    timezone: str = "Africa/Dar_es_Salaam",
) -> CreateBusinessResult:
    async with db.begin():
        existing = (
            await db.exec(
                select(Business).where(
                    Business.owner_user_id == creator_user_id,
                    Business.is_deleted == False,  # noqa: E712
                )
            )
        ).one_or_none()
        if existing is not None:
            raise BusinessAlreadyExistsError(
                f"User {creator_user_id} already owns business {existing.id}"
            )

        business = Business(
            name=name,
            business_type=business_type,
            owner_user_id=creator_user_id,
            organization_id=organization_id,
            tax_id=tax_id,
            registration_number=registration_number,
            email=email,
            phone=phone,
            address=address,
            status=status,
            logo=logo,
            license_document_url=license_document_url,
            cuisine_type=cuisine_type,
            country_code=country_code,
            city=city,
            timezone=timezone,
        )
        db.add(business)
        await db.flush()
        await db.refresh(business)

        templates = (
            await db.exec(select(RoleTemplate).where(RoleTemplate.business_type == business_type))
        ).all()

        if not templates:
            logger.error(
                "no_role_templates_for_business_type",
                business_type=business_type,
            )
            raise ValueError(
                f"No role templates found for business_type '{business_type}'. "
                "Seed role_templates first."
            )

        cloned_role_ids: list[UUID] = []
        owner_role_id: UUID | None = None
        owner_role_name: str | None = None
        role_names: list[str] = []

        for template in templates:
            role = BusinessRole(
                business_id=business.id,
                name=template.name,
                description=template.description,
                is_protected=template.is_owner_template,
            )
            db.add(role)
            await db.flush()
            await db.refresh(role)
            cloned_role_ids.append(role.id)
            role_names.append(role.name)

            template_perms = (
                await db.exec(
                    select(RoleTemplatePermission).where(
                        RoleTemplatePermission.role_template_id == template.id,
                    )
                )
            ).all()

            for tp in template_perms:
                db.add(
                    BusinessRolePermission(
                        business_role_id=role.id,
                        permission_code=tp.permission_code,
                    )
                )

            if template.is_owner_template:
                owner_role_id = role.id
                owner_role_name = role.name

        if owner_role_id is None:
            logger.error(
                "no_owner_template_found",
                business_type=business_type,
            )
            raise ValueError(
                f"No owner template found for business_type '{business_type}'. "
                "Ensure one role_template has is_owner_template=true."
            )

        db.add(
            UserBusinessRole(
                user_id=creator_user_id,
                business_id=business.id,
                business_role_id=owner_role_id,
            )
        )

        default_store_type = LocationType.HEAD_OFFICE
        validate_store_type(business_type, default_store_type.value)
        store_name = "Main Location"
        default_store = Store(
            business_id=business.id,
            name=store_name,
            token=generate_store_token(),
            location_type=default_store_type,
            is_primary=True,
            country_code=business.country_code,
            city=business.city,
            timezone=business.timezone,
        )
        db.add(default_store)
        await db.flush()
        await db.refresh(default_store)

        default_store_setting = StoreSetting(store_id=default_store.id, active=True)
        db.add(default_store_setting)
        await db.flush()
        await db.refresh(default_store_setting)

        logger.info(
            "default_store_and_settings_created",
            business_id=str(business.id),
            store_id=str(default_store.id),
            store_name=store_name,
            location_type=default_store_type.value,
            store_setting_id=str(default_store_setting.id),
        )

    await publish_event(
        "business.created",
        {
            "business_id": str(business.id),
            "creator_user_id": str(creator_user_id),
            "business_type": business_type,
            "cloned_role_count": len(cloned_role_ids),
            "role_names": role_names,
            "owner_role_name": owner_role_name,
        },
    )

    await publish_audit_recorded(
        actor_id=creator_user_id,
        actor_type="user",
        business_id=business.id,
        action="business.created",
        resource_type="business",
        resource_id=business.id,
        details={
            "business_type": business_type,
            "cloned_role_count": len(cloned_role_ids),
        },
    )

    await publish_audit_recorded(
        actor_id=creator_user_id,
        actor_type="user",
        business_id=business.id,
        action="business_role.assigned",
        resource_type="business_role",
        resource_id=owner_role_id,
        details={
            "role_name": owner_role_name,
            "target_user_id": str(creator_user_id),
        },
    )

    return CreateBusinessResult(
        business=business,
        default_store_id=default_store.id,
        default_store_setting_id=default_store_setting.id,
    )


async def update_business(
    db: AsyncSession,
    *,
    business_id: UUID,
    values: dict[str, Any],
    actor_user_id: UUID,
) -> Business | None:
    """Partial-update a business. `values` is already `model_dump(exclude_unset=True)`
    from BusinessUpdate — only keys present are applied. Returns None if not found.
    """
    business = None
    async with db.begin():
        business = await db.get(Business, business_id)
        if business is None:
            return None
        for field, value in values.items():
            setattr(business, field, value)
        db.add(business)

    await db.refresh(business)

    await publish_audit_recorded(
        actor_id=actor_user_id,
        actor_type="user",
        business_id=business.id,
        action="business.updated",
        resource_type="business",
        resource_id=business.id,
        details={"updated_fields": list(values.keys())},
    )
    return business
