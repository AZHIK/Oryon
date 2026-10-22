"""Category domain model — the product/item category taxonomy.

Global, not business-scoped: unlike ``Supplier``, a category is a single
shared taxonomy used by every business on the platform (Produce, Dairy,
Meat & Fish, ...), not something each restaurant curates independently.
Hence no ``business_id`` column.

No soft-delete: ``Item.category_id`` is a real FK with ``ondelete="RESTRICT"``
(see ``app/models/inventory.py``), so a category referenced by any item can
never actually be deleted — the database enforces that. ``is_active`` is
sufficient to hide a category from new-item pickers while existing items
keep resolving it.

``code`` is a stable slug (e.g. ``"produce"``) used only for seeding and the
one-time backfill migration off the old free-text ``Item.category`` column —
API consumers should treat ``id`` (the UUID) as the durable identifier.
"""

from __future__ import annotations

from datetime import UTC, datetime
from uuid import UUID, uuid4

from sqlalchemy import DateTime, func
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlmodel import Field, SQLModel


class Category(SQLModel, table=True):
    """A product/item category (e.g. Produce, Dairy, Beverages)."""

    id: UUID = Field(
        default_factory=uuid4,
        primary_key=True,
        nullable=False,
        sa_type=PG_UUID,
    )
    code: str = Field(nullable=False, max_length=64, unique=True, index=True)
    name: str = Field(nullable=False, max_length=255)
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
