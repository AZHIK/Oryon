"""Reorder domain model — a purchase order for restocking an inventory item.

═══════════════════════════════════════════════════════════════════════════
STORE-SCOPED, NOT BUSINESS-SCOPED (unlike ``Supplier``)
═══════════════════════════════════════════════════════════════════════════

Receiving a reorder credits a specific ``StockLevel`` row, which is keyed by
``(item_id, store_id)`` — so a ``Reorder`` must carry ``store_id`` from
creation, the same reasoning ``StockMovement`` itself is store-scoped.

═══════════════════════════════════════════════════════════════════════════
REAL FOREIGN KEYS, NOT CROSS-SERVICE REFERENCES
═══════════════════════════════════════════════════════════════════════════

Unlike ``business_id``/``store_id`` (Identity Service references, see
``app/models/inventory.py``), ``item_id`` and ``supplier_id`` reference rows
in THIS service's own database, so real FK constraints apply —
``ondelete="RESTRICT"``: a reorder is a purchase record and must not be
silently orphaned by an item/supplier row disappearing. Neither ``Item`` nor
``Supplier`` rows are ever hard-deleted in this codebase (both use
``is_active``/``is_deleted`` soft-flags), so RESTRICT never actually fires
in practice — it exists as a guard against ever changing that.

═══════════════════════════════════════════════════════════════════════════
NO SOFT-DELETE — STATE TRANSITIONS INSTEAD (mirrors ``Sale``, not ``Customer``)
═══════════════════════════════════════════════════════════════════════════

A ``Reorder`` is an append-only purchase record once created, exactly like
``Sale`` in pos-service: ``status`` moves ``pending`` -> ``received`` or
``pending`` -> ``cancelled`` and never moves again, recorded via a timestamp
+ actor pair per transition rather than a mutable row that gets deleted.
"""

from __future__ import annotations

from datetime import UTC, datetime
from decimal import Decimal
from enum import Enum as PyEnum
from uuid import UUID, uuid4

from sqlalchemy import Column, DateTime, Enum as SAEnum, Numeric, func
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlmodel import Field, ForeignKey, SQLModel


class ReorderStatus(str, PyEnum):
    PENDING = "pending"
    RECEIVED = "received"
    CANCELLED = "cancelled"


def _enum_db_values(enum_class: type[PyEnum]) -> list[str]:
    """See ``app/models/inventory.py`` — same rationale, kept local to avoid
    importing a private helper across model files."""

    return [member.value for member in enum_class]


class Reorder(SQLModel, table=True):
    """A purchase order placed with a supplier to restock an item.

    Qty-only: cost is captured at receive time (optional ``unit_cost`` on
    the receive call) and flows into ``Item.unit_cost`` via weighted
    averaging — never stored on the reorder itself."""

    id: UUID = Field(
        default_factory=uuid4,
        primary_key=True,
        nullable=False,
        sa_type=PG_UUID,
    )
    business_id: UUID = Field(
        nullable=False,
        index=True,
        sa_type=PG_UUID,
    )
    store_id: UUID = Field(
        nullable=False,
        index=True,
        sa_type=PG_UUID,
    )
    item_id: UUID = Field(
        sa_column=Column(
            PG_UUID,
            ForeignKey("item.id", ondelete="RESTRICT"),
            nullable=False,
            index=True,
        ),
    )
    supplier_id: UUID = Field(
        sa_column=Column(
            PG_UUID,
            ForeignKey("supplier.id", ondelete="RESTRICT"),
            nullable=False,
            index=True,
        ),
    )
    quantity: Decimal = Field(
        nullable=False,
        sa_type=Numeric(precision=12, scale=3),
    )
    # Denormalized from the item at creation time — a purchase record should
    # keep showing what was actually ordered even if the item's unit of
    # measure is edited afterward (same reasoning `OrderLine` in pos-service
    # freezes price at time of sale).
    unit: str = Field(nullable=False, max_length=16)
    status: ReorderStatus = Field(
        default=ReorderStatus.PENDING,
        sa_column=Column(
            SAEnum(ReorderStatus, values_callable=_enum_db_values, name="reorderstatus"),
            nullable=False,
            index=True,
        ),
    )
    notes: str | None = Field(default=None, max_length=1000)
    ordered_at: datetime = Field(
        default_factory=lambda: datetime.now(UTC),
        sa_type=DateTime(timezone=True),
        nullable=False,
    )
    ordered_by: UUID | None = Field(default=None, sa_type=PG_UUID)
    expected_at: datetime | None = Field(default=None, sa_type=DateTime(timezone=True))
    received_at: datetime | None = Field(default=None, sa_type=DateTime(timezone=True))
    received_by: UUID | None = Field(default=None, sa_type=PG_UUID)
    cancelled_at: datetime | None = Field(default=None, sa_type=DateTime(timezone=True))
    cancelled_by: UUID | None = Field(default=None, sa_type=PG_UUID)
    created_at: datetime = Field(
        default_factory=lambda: datetime.now(UTC),
        sa_type=DateTime(timezone=True),
        sa_column_kwargs={"server_default": func.now()},
        nullable=False,
    )
