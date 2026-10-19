from decimal import Decimal
from enum import StrEnum
from typing import TYPE_CHECKING, Optional
from uuid import UUID

from sqlalchemy import Column, Numeric, String, UniqueConstraint
from sqlmodel import Field, Relationship, SQLModel

from app.models.base import SoftDeleteMixin, TimestampMixin, UUIDMixin

if TYPE_CHECKING:
    from app.models.user import User


# ═══════════════════════════════════════════════════════════════════════════
# Enums
#
# Shared string-enum vocabulary used across the business tables below. Every
# enum is persisted as a plain varchar and validated at the API/schema layer.
# ═══════════════════════════════════════════════════════════════════════════


class PermissionType(StrEnum):
    """Grant/deny type for a single user's permission override."""

    GRANT = "grant"
    DENY = "deny"


class BusinessType(StrEnum):
    """Classification of a business (drives which role templates apply)."""

    RESTAURANT = "restaurant"
    SUPPLIER = "supplier"
    FARMER = "farmer"
    DISTRIBUTOR = "distributor"
    PLATFORM_OPERATOR = "platform_operator"


class BusinessStatus(StrEnum):
    """Lifecycle status shared by businesses and stores."""

    ACTIVE = "active"
    INACTIVE = "inactive"
    SUSPENDED = "suspended"


class LocationType(StrEnum):
    """Physical kind of a store (validated per-business-type by service logic)."""

    HEAD_OFFICE = "head_office"
    RESTAURANT_BRANCH = "restaurant_branch"
    KITCHEN = "kitchen"
    WAREHOUSE = "warehouse"
    FARM = "farm"
    DEPOT = "depot"


# ═══════════════════════════════════════════════════════════════════════════
# Group 1 — Business hierarchy (identity core)
#
# The ownership tree: an Organization groups multiple Businesses; a Business
# owns one or more operating Stores; each Store has exactly one StoreSetting
# (true one-to-one, enforced by a unique store_id).
# ═══════════════════════════════════════════════════════════════════════════


class Organization(UUIDMixin, TimestampMixin, SoftDeleteMixin, SQLModel, table=True):
    """A parent grouping that owns multiple businesses (e.g. a holding group)."""

    __tablename__ = "organizations"

    name: str = Field(max_length=255)
    legal_name: str | None = Field(default=None, max_length=255)
    country_code: str = Field(default="TZ", max_length=2)
    default_timezone: str = Field(default="Africa/Dar_es_Salaam", max_length=64)
    owner_user_id: UUID = Field(foreign_key="users.id")

    businesses: list["Business"] = Relationship(back_populates="organization")


class Business(UUIDMixin, TimestampMixin, SoftDeleteMixin, SQLModel, table=True):
    """The registered legal entity that owns stores.

    Holds the company-level identity and contact details. ``status`` uses the
    shared ``BusinessStatus`` enum; ``logo`` and ``license_document_url`` are
    URL/path placeholder columns only (no upload mechanism). Soft-delete is a
    real FK to users via ``deleted_by`` (same-database discipline: users live
    here too). ``owner_user_id`` is unique — one business per owner.
    """

    __tablename__ = "businesses"

    name: str = Field(max_length=255)
    business_type: BusinessType = Field(sa_type=String)
    owner_user_id: UUID = Field(foreign_key="users.id", unique=True)
    organization_id: UUID | None = Field(
        default=None, foreign_key="organizations.id", nullable=True
    )
    tax_id: str | None = Field(default=None, max_length=100)
    registration_number: str | None = Field(default=None, max_length=100)
    email: str | None = Field(default=None, max_length=255)
    phone: str | None = Field(default=None, max_length=20)
    address: str | None = Field(default=None, max_length=500)
    status: BusinessStatus = Field(default=BusinessStatus.ACTIVE, sa_type=String)
    logo: str | None = Field(default=None, max_length=500)
    # Reference/URL to a business license or registration document. Text
    # only — there is no file-upload/object-storage pipeline yet, same
    # placeholder-only pattern as `logo`.
    license_document_url: str | None = Field(default=None, max_length=500)
    cuisine_type: str | None = Field(default=None, max_length=100)
    deleted_by: UUID | None = Field(default=None, foreign_key="users.id", nullable=True)
    country_code: str = Field(default="TZ", max_length=2)
    city: str | None = Field(default=None, max_length=100)
    timezone: str = Field(default="Africa/Dar_es_Salaam", max_length=64)

    organization: Organization | None = Relationship(back_populates="businesses")
    owner: "User" = Relationship(
        back_populates="businesses",
        # businesses → users via owner_user_id; the deleted_by FK is a real
        # FK too, so the join must be pinned to avoid ambiguity.
        sa_relationship_kwargs={"foreign_keys": "Business.owner_user_id"},
    )
    stores: list["Store"] = Relationship(back_populates="business")
    roles: list["BusinessRole"] = Relationship(back_populates="business")
    user_business_roles: list["UserBusinessRole"] = Relationship(back_populates="business")
    user_business_permissions: list["UserBusinessPermission"] = Relationship(
        back_populates="business"
    )


class Store(UUIDMixin, TimestampMixin, SoftDeleteMixin, SQLModel, table=True):
    """An operating location owned by a single business.

    Holds location/identity fields only. ``token`` is a unique plain
    identifier (no auth semantics — deliberately not wired into any
    authentication/authorization check). Contact, coordinates, and trading
    preferences live on the one-to-one ``StoreSetting`` instead, so this table
    carries no email/phone/lat/long columns.
    """

    __tablename__ = "store"

    business_id: UUID = Field(foreign_key="businesses.id")
    name: str = Field(max_length=255)
    token: str = Field(max_length=64, unique=True)
    location_type: LocationType = Field(sa_type=String)
    status: BusinessStatus = Field(default=BusinessStatus.ACTIVE, sa_type=String)
    country_code: str = Field(default="TZ", max_length=2)
    city: str | None = Field(default=None, max_length=100)
    address: str | None = Field(default=None, max_length=500)
    timezone: str = Field(default="Africa/Dar_es_Salaam", max_length=64)
    is_primary: bool = Field(default=False)
    deleted_by: UUID | None = Field(default=None, foreign_key="users.id", nullable=True)

    __table_args__ = (UniqueConstraint("business_id", "name"),)

    business: Business = Relationship(back_populates="stores")
    user_store_roles: list["UserStoreRole"] = Relationship(back_populates="store")
    settings: "StoreSetting" = Relationship(
        back_populates="store",
        sa_relationship_kwargs={"uselist": False},
    )


class StoreSetting(UUIDMixin, TimestampMixin, SoftDeleteMixin, SQLModel, table=True):
    """Per-store configuration, one row per store (true one-to-one).

    ``store_id`` is unique, so a store can never have more than one settings
    row. A row is always created atomically with its store (business-creation
    flow and ``create_store``), and the migration backfills existing stores.

    ``preferred_currency`` is an ISO 4217 code kept for future use — it is
    intentionally NOT consumed by any business logic yet. ``logo`` is a
    URL/path placeholder only, ready for when object storage is decided.
    """

    __tablename__ = "store_settings"

    store_id: UUID = Field(foreign_key="store.id", unique=True)
    active: bool = Field(default=True)
    address: str | None = Field(default=None, max_length=500)
    latitude: Decimal | None = Field(sa_column=Column(Numeric(9, 6), nullable=True))
    longitude: Decimal | None = Field(sa_column=Column(Numeric(9, 6), nullable=True))
    email: str | None = Field(default=None, max_length=255)
    phone: str | None = Field(default=None, max_length=20)
    preferred_currency: str = Field(default="TZS", max_length=3)
    # Credit/tab limit for this store, expressed in preferred_currency.
    # Interpreted from context (pairs with max_payment_time_minutes) as the
    # maximum outstanding balance a customer may accrue before payment is
    # required. Not yet consumed by any business logic.
    amount: Decimal | None = Field(sa_column=Column(Numeric(14, 2), nullable=True))
    # Maximum time allowed to settle a tab, in minutes (integer field — the
    # unit is encoded in the name rather than a Postgres interval, matching
    # the project's plain-typed column convention).
    max_payment_time_minutes: int | None = Field(default=None, nullable=True)
    logo: str | None = Field(default=None, max_length=500)
    offer_retail: bool = Field(default=True)
    offer_wholesale: bool = Field(default=False)
    display_prices_inclusive_of_tax: bool = Field(default=False)
    # Tax switch: off by default. When off, no tax is charged or shown
    # anywhere (POS, sales, reports). When on, sales charge
    # subtotal * tax_rate. tax_rate is a fraction (0.18 = 18%).
    tax_enabled: bool = Field(default=False)
    tax_rate: Decimal | None = Field(
        default=Decimal("0"), sa_column=Column(Numeric(5, 4), nullable=True)
    )
    deleted_by: UUID | None = Field(default=None, foreign_key="users.id", nullable=True)

    store: Store = Relationship(back_populates="settings")


# ═══════════════════════════════════════════════════════════════════════════
# Group 2 — Business RBAC / staffing
#
# Who can do what inside a business: custom roles (BusinessRole) carry a set
# of permission codes (BusinessRolePermission); users are assigned to a role
# at the business level (UserBusinessRole) or at a specific store
# (UserStoreRole — this is the EMPLOYEE-at-store mapping, preserved as-is;
# no separate employee table is needed). UserBusinessPermission records
# per-user grant/deny overrides.
# ═══════════════════════════════════════════════════════════════════════════


class BusinessRole(UUIDMixin, TimestampMixin, SoftDeleteMixin, SQLModel, table=True):
    """A custom role scoped to one business (owner, manager, cashier, ...)."""

    __tablename__ = "business_roles"

    business_id: UUID = Field(foreign_key="businesses.id")
    name: str = Field(max_length=100)
    description: str | None = Field(default=None, max_length=500)
    is_protected: bool = Field(default=False)

    __table_args__ = (UniqueConstraint("business_id", "name"),)

    business: Business = Relationship(back_populates="roles")
    permissions: list["BusinessRolePermission"] = Relationship(back_populates="business_role")
    user_assignments: list["UserBusinessRole"] = Relationship(back_populates="business_role")


class BusinessRolePermission(SoftDeleteMixin, SQLModel, table=True):
    """Join of a business role to the permission codes it grants."""

    __tablename__ = "business_role_permissions"

    business_role_id: UUID = Field(foreign_key="business_roles.id", primary_key=True)
    permission_code: str = Field(primary_key=True, max_length=100, sa_type=String)

    business_role: BusinessRole = Relationship(back_populates="permissions")


class UserBusinessRole(UUIDMixin, SoftDeleteMixin, SQLModel, table=True):
    """Assignment of a user to a role at the business level."""

    __tablename__ = "user_business_roles"

    user_id: UUID = Field(foreign_key="users.id")
    business_id: UUID = Field(foreign_key="businesses.id")
    business_role_id: UUID = Field(foreign_key="business_roles.id")

    __table_args__ = (UniqueConstraint("user_id", "business_id", "business_role_id"),)

    user: "User" = Relationship(back_populates="user_business_roles")
    business: Business = Relationship(back_populates="user_business_roles")
    business_role: BusinessRole = Relationship(back_populates="user_assignments")


class UserStoreRole(UUIDMixin, SoftDeleteMixin, SQLModel, table=True):
    """EMPLOYEE-at-store mapping: a user assigned a role at a specific store.

    This is the employee concept for this system — preserved as-is, not
    duplicated into a new table. ``store_id`` points at the (renamed) store.
    """

    __tablename__ = "user_store_roles"

    user_id: UUID = Field(foreign_key="users.id")
    business_id: UUID = Field(foreign_key="businesses.id")
    store_id: UUID = Field(foreign_key="store.id")
    business_role_id: UUID = Field(foreign_key="business_roles.id")

    __table_args__ = (
        UniqueConstraint(
            "user_id",
            "store_id",
            "business_role_id",
        ),
    )

    store: Store = Relationship(back_populates="user_store_roles")


class UserBusinessPermission(UUIDMixin, TimestampMixin, SoftDeleteMixin, SQLModel, table=True):
    """Per-user permission override (grant or deny) inside a business."""

    __tablename__ = "user_business_permissions"

    user_id: UUID = Field(foreign_key="users.id")
    business_id: UUID = Field(foreign_key="businesses.id")
    permission_code: str = Field(max_length=100, sa_type=String)
    type: PermissionType = Field(sa_type=String)
    created_by: UUID | None = Field(default=None, foreign_key="users.id", nullable=True)

    __table_args__ = (UniqueConstraint("user_id", "business_id", "permission_code"),)

    user: "User" = Relationship(
        back_populates="user_business_permissions",
        sa_relationship_kwargs={"foreign_keys": "UserBusinessPermission.user_id"},
    )
    created_by_user: Optional["User"] = Relationship(
        back_populates="created_business_permissions",
        sa_relationship_kwargs={"foreign_keys": "UserBusinessPermission.created_by"},
    )
    business: Business = Relationship(back_populates="user_business_permissions")
