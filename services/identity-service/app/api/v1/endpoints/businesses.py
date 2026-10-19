from uuid import UUID

import structlog
from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import select
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.database import get_async_session
from app.core.exceptions import BusinessAlreadyExistsError
from app.core.permission_codes import PermissionCode
from app.deps.auth import get_current_user_id
from app.deps.permissions import require_any_business_permission, require_business_permission
from app.models.business import Business, BusinessRole
from app.schemas.business import (
    BusinessCreateRequest,
    BusinessCreateResponse,
    BusinessExistsResponse,
    BusinessRead,
    BusinessUpdate,
)
from app.schemas.business_rbac import BusinessRoleRead
from app.services.business_service import create_business, update_business

logger = structlog.get_logger(__name__)

router = APIRouter(prefix="/api/v1/businesses", tags=["Businesses"])


@router.post("", response_model=BusinessCreateResponse, status_code=status.HTTP_201_CREATED)
async def create_business_endpoint(
    body: BusinessCreateRequest,
    db: AsyncSession = Depends(get_async_session),
    creator_user_id: str = Depends(get_current_user_id),
) -> BusinessCreateResponse:
    try:
        result = await create_business(
            db,
            creator_user_id=UUID(creator_user_id),
            name=body.name,
            business_type=body.business_type.value,
            organization_id=body.organization_id,
            tax_id=body.tax_id,
            registration_number=body.registration_number,
            email=body.email,
            phone=body.phone,
            address=body.address,
            status=body.status.value,
            logo=body.logo,
            license_document_url=body.license_document_url,
            cuisine_type=body.cuisine_type,
            country_code=body.country_code,
            city=body.city,
            timezone=body.timezone,
        )
    except BusinessAlreadyExistsError as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="You already own a business",
        ) from exc
    except ValueError as exc:
        logger.error("business_creation_misconfigured", error=str(exc))
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Business setup is not fully configured. Contact support.",
        ) from exc
    business = result.business

    roles = (
        await db.exec(select(BusinessRole).where(BusinessRole.business_id == business.id))
    ).all()
    role_names = [r.name for r in roles]
    owner_role = next((r for r in roles if r.is_protected), None)

    return BusinessCreateResponse(
        business=BusinessRead.model_validate(business),
        roles_created=role_names,
        owner_role_name=owner_role.name if owner_role else "",
    )


@router.get("/{business_id}", response_model=BusinessRead)
async def get_business(
    business_id: UUID,
    db: AsyncSession = Depends(get_async_session),
    _caller_business_id: str = Depends(require_business_permission(PermissionCode.BUSINESSES_VIEW)),
) -> BusinessRead:
    business = await db.get(Business, business_id)
    if business is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Business not found",
        )
    return BusinessRead.model_validate(business)


@router.get("/{business_id}/exists", response_model=BusinessExistsResponse)
async def business_exists(
    business_id: UUID,
    db: AsyncSession = Depends(get_async_session),
) -> BusinessExistsResponse:
    """Public existence probe for offline-first terminals.

    Deliberately unauthenticated: a device whose session is dead (expired,
    revoked, or wiped server-side) cannot call any authed endpoint, yet
    must still answer "is my locked business still on this server?" before
    deciding to wipe its local database. The UUID path is unguessable, so
    this reveals nothing enumerable — 404 when absent, the id echoed when
    present. No business data is returned.
    """
    business = await db.get(Business, business_id)
    if business is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Business not found",
        )
    return BusinessExistsResponse(business_id=business.id, exists=True)


@router.patch("/{business_id}", response_model=BusinessRead)
async def update_business_endpoint(
    business_id: UUID,
    body: BusinessUpdate,
    db: AsyncSession = Depends(get_async_session),
    caller_business_id: str = Depends(
        require_business_permission(PermissionCode.BUSINESSES_UPDATE)
    ),
    caller_user_id: str = Depends(get_current_user_id),
) -> BusinessRead:
    if str(business_id) != caller_business_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Token business context does not match the requested business",
        )
    business = await update_business(
        db,
        business_id=business_id,
        values=body.model_dump(exclude_unset=True),
        actor_user_id=UUID(caller_user_id),
    )
    if business is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Business not found")
    return BusinessRead.model_validate(business)


@router.get("/{business_id}/roles", response_model=list[BusinessRoleRead])
async def list_business_roles(
    business_id: UUID,
    db: AsyncSession = Depends(get_async_session),
    caller_business_id: str = Depends(
        require_any_business_permission(
            PermissionCode.BUSINESS_ROLES_VIEW,
            PermissionCode.USER_BUSINESS_ROLES_ASSIGN,
        )
    ),
) -> list[BusinessRoleRead]:
    if str(business_id) != caller_business_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Token business context does not match the requested business",
        )

    roles = (
        await db.exec(
            select(BusinessRole)
            .where(BusinessRole.business_id == business_id)
            .where(BusinessRole.is_deleted == False)  # noqa: E712
        )
    ).all()

    return [BusinessRoleRead.model_validate(r) for r in roles]
