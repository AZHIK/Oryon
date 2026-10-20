from enum import StrEnum
from typing import TYPE_CHECKING, Optional

from sqlalchemy import String
from sqlmodel import Field, Relationship, SQLModel

from app.models.base import SoftDeleteMixin, TimestampMixin, UUIDMixin

if TYPE_CHECKING:
    from app.models.business import Business, UserBusinessPermission, UserBusinessRole
    from app.models.internal import UserGroup, UserRole
    from app.models.platform import UserPlatformRole


class UserCategory(StrEnum):
    PLATFORM_STAFF = "platform_staff"
    BUSINESS_STAFF = "business_staff"
    BUSINESS_STORE_STAFF = "business_store_staff"
    DRIVER = "driver"
    CONSUMER = "consumer"
    FARMER = "farmer"
    LOGISTICS_PROVIDER = "logistics_provider"
    QA = "qa"


class UserStatus(StrEnum):
    ACTIVE = "active"
    INVITED = "invited"
    SUSPENDED = "suspended"
    LOCKED = "locked"


class User(UUIDMixin, TimestampMixin, SoftDeleteMixin, SQLModel, table=True):
    __tablename__ = "users"

    # Nullable: staff can be invited by email alone, in which case they have
    # no phone on file until they add one. Postgres permits multiple NULLs in
    # a unique column, so the unique constraint still holds for real numbers.
    phone: str | None = Field(default=None, unique=True, max_length=20)
    email: str | None = Field(default=None, unique=True, nullable=True, max_length=255)
    full_name: str = Field(max_length=255)
    user_category: UserCategory = Field(sa_type=String)
    status: UserStatus = Field(default=UserStatus.ACTIVE, sa_type=String)
    password_hash: str | None = Field(default=None, nullable=True)
    is_active: bool = Field(default=True)
    is_phone_verified: bool = Field(default=False)
    is_email_verified: bool = Field(default=False)

    user_group: Optional["UserGroup"] = Relationship(back_populates="user")
    user_roles: list["UserRole"] = Relationship(back_populates="user")
    user_business_roles: list["UserBusinessRole"] = Relationship(back_populates="user")
    user_business_permissions: list["UserBusinessPermission"] = Relationship(
        back_populates="user",
        sa_relationship_kwargs={"foreign_keys": "UserBusinessPermission.user_id"},
    )
    created_business_permissions: list["UserBusinessPermission"] = Relationship(
        back_populates="created_by_user",
        sa_relationship_kwargs={"foreign_keys": "UserBusinessPermission.created_by"},
    )
    user_platform_roles: list["UserPlatformRole"] = Relationship(back_populates="user")
    businesses: list["Business"] = Relationship(
        back_populates="owner",
        sa_relationship_kwargs={"foreign_keys": "Business.owner_user_id"},
    )
