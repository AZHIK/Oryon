"""Purchases domain models — two-step purchase orders, GRNs.

═══════════════════════════════════════════════════════════════════════════
TWO-STEP FLOW: CREATE → RECEIVE (FULFILLED / UNFULFILLED)
═══════════════════════════════════════════════════════════════════════════

A purchase order is drafted with ``status=unfulfilled`` and received
directly — there is no submit/approve handshake and no payables ledger.
Each ``GoodsReceiptLine`` carries the actual ``unit_cost`` for that
delivery (the single point where purchase cost enters), and after every
receipt the header is re-derived: all lines fully received → ``fulfilled``,
otherwise still ``unfulfilled`` (more GRNs may follow). ``cancelled`` is
only reachable before anything has been received.

═══════════════════════════════════════════════════════════════════════════
STORE-SCOPED HEADERS (like ``Reorder``, unlike ``Supplier``)
═══════════════════════════════════════════════════════════════════════════

Receiving credits a specific ``StockLevel`` row keyed by
``(item_id, store_id)`` — so ``PurchaseOrder`` and ``GoodsReceipt`` both
carry ``store_id`` from creation, the same reasoning
``StockMovement`` itself is store-scoped.

═══════════════════════════════════════════════════════════════════════════
REAL FOREIGN KEYS, NOT CROSS-SERVICE REFERENCES
═══════════════════════════════════════════════════════════════════════════

``item_id``/``supplier_id``/``purchase_order_id`` reference rows in THIS
service's own database, so real FK constraints apply (``RESTRICT`` on
records, ``CASCADE`` on owned lines). ``business_id``/``store_id`` remain
plain indexed UUIDs (Identity Service references — see
``app/models/inventory.py``). Do NOT add FK constraints to those columns.

═══════════════════════════════════════════════════════════════════════════
NO SOFT-DELETE — STATE TRANSITIONS INSTEAD (mirrors ``Reorder``/``Sale``)
═══════════════════════════════════════════════════════════════════════════

Orders, receipts, returns, invoices and payments are append-only purchase
records: ``status`` moves forward and never moves back, recorded via a
timestamp + actor pair per transition rather than a mutable row that gets
deleted. GRN/receipt/return/payment rows are never updated or deleted by
application code.

═══════════════════════════════════════════════════════════════════════════
ONLINE-ONLY
═══════════════════════════════════════════════════════════════════════════

All writes go through the API in a single transaction (GRN receipt loops
``record_movement(..., commit=False)`` then commits once). There is no
offline outbox for purchases — the Flutter client gates writes on
connectivity and calls the API directly, mirroring the existing
supplier/reorder no-outbox convention.
"""

from __future__ import annotations

from datetime import UTC, datetime
from decimal import Decimal
from enum import Enum as PyEnum
from uuid import UUID, uuid4

from sqlalchemy import Column, DateTime, Numeric, UniqueConstraint, func
from sqlalchemy import Enum as SAEnum
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlmodel import Field, ForeignKey, SQLModel


class PurchaseOrderStatus(str, PyEnum):
    UNFULFILLED = "unfulfilled"
    FULFILLED = "fulfilled"
    CANCELLED = "cancelled"


def _enum_db_values(enum_class: type[PyEnum]) -> list[str]:
    """See ``app/models/inventory.py`` — same rationale, kept local to avoid
    importing a private helper across model files."""

    return [member.value for member in enum_class]


class PurchaseOrder(SQLModel, table=True):
    """Qty-only purchase order header with one supplier per order.

    Created ``unfulfilled`` and received directly — no submit/approve
    handshake. ``fulfilled`` once every line is fully received, else still
    ``unfulfilled`` (further GRNs may follow). ``cancelled`` only before
    anything has been received.
    """

    __table_args__ = (
        UniqueConstraint(
            "business_id",
            "po_number",
            name="uq_purchaseorder_business_po_number",
        ),
    )

    id: UUID = Field(
        default_factory=uuid4,
        primary_key=True,
        nullable=False,
        sa_type=PG_UUID,
    )
    business_id: UUID = Field(nullable=False, index=True, sa_type=PG_UUID)
    store_id: UUID = Field(nullable=False, index=True, sa_type=PG_UUID)
    supplier_id: UUID = Field(
        sa_column=Column(
            PG_UUID,
            ForeignKey("supplier.id", ondelete="RESTRICT"),
            nullable=False,
            index=True,
        ),
    )
    po_number: str = Field(nullable=False, max_length=32)
    # ── Requisition-split linkage (additive, nullable so legacy POs keep
    # working). Set when the PO was produced by a requisition submit.
    requisition_id: UUID | None = Field(
        default=None,
        sa_column=Column(
            PG_UUID,
            ForeignKey("requisition.id", ondelete="RESTRICT"),
            nullable=True,
            index=True,
        ),
    )
    # Idempotency key echoed from the requisition submit (business-scoped
    # uniqueness enforced at the requisition level, stored here for audit).
    idempotency_key: str | None = Field(default=None, max_length=128, index=True)
    status: PurchaseOrderStatus = Field(
        default=PurchaseOrderStatus.UNFULFILLED,
        sa_column=Column(
            SAEnum(
                PurchaseOrderStatus,
                values_callable=_enum_db_values,
                name="purchaseorderstatus",
            ),
            nullable=False,
            index=True,
        ),
    )
    # Purchase orders are qty-only: no money lives on the header. Actual
    # cost is captured per receipt on ``GoodsReceiptLine.unit_cost`` and
    # flows into weighted-average costing from there.
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
    updated_at: datetime = Field(
        default_factory=lambda: datetime.now(UTC),
        sa_type=DateTime(timezone=True),
        sa_column_kwargs={"server_default": func.now(), "onupdate": func.now()},
        nullable=False,
    )


class PurchaseOrderLine(SQLModel, table=True):
    """One item line of a ``PurchaseOrder`` — qty-only.

    ``unit`` is denormalized from the item at creation (same reasoning as
    ``Reorder.unit``). ``quantity_received`` is a counter maintained by GRN
    receipts — never client-supplied on receive. Cost is deliberately
    absent: the actual price is recorded on ``GoodsReceiptLine.unit_cost``
    when goods arrive.
    """

    __table_args__ = (
        UniqueConstraint(
            "purchase_order_id",
            "item_id",
            name="uq_purchaseorderline_order_item",
        ),
    )

    id: UUID = Field(
        default_factory=uuid4,
        primary_key=True,
        nullable=False,
        sa_type=PG_UUID,
    )
    purchase_order_id: UUID = Field(
        sa_column=Column(
            PG_UUID,
            ForeignKey("purchaseorder.id", ondelete="CASCADE"),
            nullable=False,
            index=True,
        ),
    )
    item_id: UUID = Field(
        sa_column=Column(
            PG_UUID,
            ForeignKey("item.id", ondelete="RESTRICT"),
            nullable=False,
            index=True,
        ),
    )
    quantity_ordered: Decimal = Field(
        nullable=False,
        sa_type=Numeric(precision=12, scale=3),
    )
    quantity_received: Decimal = Field(
        default=Decimal("0.000"),
        sa_type=Numeric(precision=12, scale=3),
    )
    unit: str = Field(nullable=False, max_length=16)
    notes: str | None = Field(default=None, max_length=500)


class GoodsReceipt(SQLModel, table=True):
    """One goods-received event against a ``PurchaseOrder`` (partial GRNs).

    A receipt is a RECORD: never updated or deleted by application code.
    Each ``GoodsReceiptLine`` produces one ``PURCHASE_RECEIVED`` movement in
    the same transaction (``reference_type="goods_receipt"``).
    """

    __table_args__ = (
        UniqueConstraint(
            "business_id",
            "grn_number",
            name="uq_goodsreceipt_business_grn_number",
        ),
    )

    id: UUID = Field(
        default_factory=uuid4,
        primary_key=True,
        nullable=False,
        sa_type=PG_UUID,
    )
    business_id: UUID = Field(nullable=False, index=True, sa_type=PG_UUID)
    store_id: UUID = Field(nullable=False, index=True, sa_type=PG_UUID)
    purchase_order_id: UUID = Field(
        sa_column=Column(
            PG_UUID,
            ForeignKey("purchaseorder.id", ondelete="RESTRICT"),
            nullable=False,
            index=True,
        ),
    )
    grn_number: str = Field(nullable=False, max_length=32)
    notes: str | None = Field(default=None, max_length=1000)
    received_at: datetime = Field(
        default_factory=lambda: datetime.now(UTC),
        sa_type=DateTime(timezone=True),
        nullable=False,
    )
    received_by: UUID | None = Field(default=None, sa_type=PG_UUID)
    created_at: datetime = Field(
        default_factory=lambda: datetime.now(UTC),
        sa_type=DateTime(timezone=True),
        sa_column_kwargs={"server_default": func.now()},
        nullable=False,
    )


class GoodsReceiptLine(SQLModel, table=True):
    """One received quantity within a ``GoodsReceipt``.

    ``unit_cost`` is the actual price for THIS delivery — the single point
    where purchase cost enters the system. It drives the weighted-average
    revaluation of ``Item.unit_cost`` and the invoice-amount default.
    """

    id: UUID = Field(
        default_factory=uuid4,
        primary_key=True,
        nullable=False,
        sa_type=PG_UUID,
    )
    goods_receipt_id: UUID = Field(
        sa_column=Column(
            PG_UUID,
            ForeignKey("goodsreceipt.id", ondelete="CASCADE"),
            nullable=False,
            index=True,
        ),
    )
    purchase_order_line_id: UUID = Field(
        sa_column=Column(
            PG_UUID,
            ForeignKey("purchaseorderline.id", ondelete="RESTRICT"),
            nullable=False,
            index=True,
        ),
    )
    item_id: UUID = Field(
        sa_column=Column(
            PG_UUID,
            ForeignKey("item.id", ondelete="RESTRICT"),
            nullable=False,
            index=True,
        ),
    )
    quantity_received: Decimal = Field(
        nullable=False,
        sa_type=Numeric(precision=12, scale=3),
    )
    unit_cost: Decimal = Field(
        nullable=False,
        sa_type=Numeric(precision=12, scale=4),
    )
    # Traceable lot identity for the Lot / Stock Expiry reports. Nullable so
    # legacy receipts keep working — when absent the GRN number is used as
    # the display lot.
    lot_no: str | None = Field(default=None, max_length=64, index=True)
    expiry_date: datetime | None = Field(default=None, sa_type=DateTime(timezone=True))
