"""Unit domain model — the measurement-unit taxonomy (kg, g, L, ml, each, pack).

Global, not business-scoped: like ``Category``, a unit is a single shared
taxonomy used by every business on the platform, not something each
restaurant curates independently. Hence no ``business_id`` column.

Replaces the old ``Item.unit_of_measure`` Postgres enum (see
``a1b2c3d4e5f6_initial_schema``) with a real table for the same reason
categories moved off a free-text column: new units (e.g. "case", "dozen")
previously required a schema migration to add an enum value; now they are a
seed-data change.

No soft-delete: ``Item.unit_id`` is a real FK with ``ondelete="RESTRICT"``
(see ``app/models/inventory.py``), so a unit referenced by any item can never
actually be deleted — the database enforces that. ``is_active`` is
sufficient to hide a unit from new-item pickers while existing items keep
resolving it.

``code`` is the stable slug that was the old enum's ``.value`` (``"kg"``,
``"l"``, ...) — kept identical so every place that used to read the raw enum
value (``Reorder.unit``, ``StockLevelRead.item_unit_of_measure``) keeps
returning the exact same strings. ``abbreviation`` is the short label meant
for display next to a quantity (e.g. ``"L"`` for liters, ``"ea"`` for each) —
API consumers should treat ``id`` (the UUID) as the durable identifier.
"""

from __future__ import annotations

from datetime import UTC, datetime
from uuid import UUID, uuid4

from sqlalchemy import DateTime, func
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlmodel import Field, SQLModel


class Unit(SQLModel, table=True):
    """A measurement unit (e.g. Kilogram, Liter, Each)."""

    id: UUID = Field(
        default_factory=uuid4,
        primary_key=True,
        nullable=False,
        sa_type=PG_UUID,
    )
    code: str = Field(nullable=False, max_length=64, unique=True, index=True)
    name: str = Field(nullable=False, max_length=255)
    abbreviation: str = Field(nullable=False, max_length=16)
    sort_order: int = Field(default=0, nullable=False)
    is_active: bool = Field(
        default=True,
        nullable=False,
        sa_column_kwargs={"server_default": "true"},
    )
    created_at: datetime = Field(
        default_factory=lambda: datetime.now(UTC),
        sa_type=DateTime(timezone=True),
        sa_column_kwargs={"server_default": func.now()},
        nullable=False,
    )
    updated_at: datetime = Field(
        default_factory=lambda: datetime.now(UTC),
        sa_type=DateTime(timezone=True),
        sa_column_kwargs={"server_default": func.now(), "onupdate": func.now()},
        nullable=False,
    )
