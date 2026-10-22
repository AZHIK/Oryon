"""Base mixins for SQLModel table models.

SQLModel-compatible mixins that add common columns (UUID PK,
timestamps) without conflicting with the metaclass.
"""

from datetime import UTC, datetime
from uuid import UUID, uuid4

from sqlalchemy import DateTime, func
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlmodel import Field


class UUIDMixin:
    """Auto-generated UUID primary key."""

    id: UUID = Field(
        default_factory=uuid4,
        primary_key=True,
        index=True,
        nullable=False,
        sa_type=PG_UUID,
    )


class TimestampMixin:
    """created_at / updated_at with server-side defaults."""

    created_at: datetime = Field(
        default_factory=lambda: datetime.now(UTC),
        sa_type=DateTime(timezone=True),
        sa_column_kwargs={"server_default": func.now()},
        nullable=False,
    )
    updated_at: datetime = Field(
        default_factory=lambda: datetime.now(UTC),
        sa_type=DateTime(timezone=True),
        sa_column_kwargs={
            "server_default": func.now(),
            "onupdate": func.now(),
        },
        nullable=False,
    )


class CreatedAtMixin:
    """created_at only (for immutable tables like stock_movements)."""

    created_at: datetime = Field(
        default_factory=lambda: datetime.now(UTC),
        sa_type=DateTime(timezone=True),
        sa_column_kwargs={"server_default": func.now()},
        nullable=False,
    )
