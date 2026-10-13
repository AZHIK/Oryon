"""Two-step purchase orders — create → receive (fulfilled / unfulfilled).

Revision ID: s2t3u4v5w6x7
Revises: r1s2t3u4v5w6
Create Date: 2026-10-13 00:00:00.000000

The submit/approve handshake and the payables ledger are gone:

* ``purchaseorderstatus`` shrinks to ``unfulfilled`` / ``fulfilled`` /
  ``cancelled``. Open POs (draft/submitted/approved/payload_ready/sent/
  confirmed/partially_received/partially_fulfilled) map to ``unfulfilled``;
  received/fulfilled map to ``fulfilled``; cancelled stays cancelled.
* ``purchaseorder.invoice_status`` (+ the ``invoicestatus`` type) is dropped.
* ``purchasereturn`` / ``supplierinvoice`` / ``supplierpayment`` tables are
  dropped.
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


# revision identifiers, used by Alembic.
revision: str = "s2t3u4v5w6x7"
down_revision: Union[str, None] = "r1s2t3u4v5w6"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

_NEW_STATUS_VALUES = ("unfulfilled", "fulfilled", "cancelled")
_OLD_STATUS_VALUES = (
    "draft",
    "submitted",
    "approved",
    "partially_received",
    "received",
    "cancelled",
    "payload_ready",
    "sent",
    "confirmed",
    "partially_fulfilled",
    "fulfilled",
)
_INVOICE_STATUS_VALUES = ("unbilled", "unpaid", "partial", "paid")


def upgrade() -> None:
    # ── 1. Shrink the PO status enum ────────────────────────────────────
    # The column carries a server_default from the original DDL — drop it
    # first or Postgres cannot cast the default to the new type.
    op.execute("ALTER TABLE purchaseorder ALTER COLUMN status DROP DEFAULT")
    op.execute(
        "CREATE TYPE purchaseorderstatus_new AS ENUM "
        f"({', '.join(repr(v) for v in _NEW_STATUS_VALUES)})"
    )
    op.execute(
        "ALTER TABLE purchaseorder ALTER COLUMN status TYPE "
        "purchaseorderstatus_new USING (CASE status::text "
        "WHEN 'received' THEN 'fulfilled'::purchaseorderstatus_new "
        "WHEN 'fulfilled' THEN 'fulfilled'::purchaseorderstatus_new "
        "WHEN 'cancelled' THEN 'cancelled'::purchaseorderstatus_new "
        "ELSE 'unfulfilled'::purchaseorderstatus_new END)"
    )
    op.execute("DROP TYPE purchaseorderstatus")
    op.execute("ALTER TYPE purchaseorderstatus_new RENAME TO purchaseorderstatus")
    op.execute("ALTER TABLE purchaseorder ALTER COLUMN status SET DEFAULT 'unfulfilled'")

    # ── 2. Drop returns + payables tables (before the enum type they use) ──
    op.drop_index(op.f("ix_supplierpayment_invoice_id"), table_name="supplierpayment")
    op.drop_index(op.f("ix_supplierpayment_business_id"), table_name="supplierpayment")
    op.drop_table("supplierpayment")
    op.drop_index(op.f("ix_supplierinvoice_status"), table_name="supplierinvoice")
    op.drop_index(
        op.f("ix_supplierinvoice_purchase_order_id"), table_name="supplierinvoice"
    )
    op.drop_index(op.f("ix_supplierinvoice_supplier_id"), table_name="supplierinvoice")
    op.drop_index(op.f("ix_supplierinvoice_business_id"), table_name="supplierinvoice")
    op.drop_table("supplierinvoice")
    op.drop_index(op.f("ix_purchasereturn_item_id"), table_name="purchasereturn")
    op.drop_index(
        op.f("ix_purchasereturn_goods_receipt_id"), table_name="purchasereturn"
    )
    op.drop_index(
        op.f("ix_purchasereturn_purchase_order_id"), table_name="purchasereturn"
    )
    op.drop_index(op.f("ix_purchasereturn_store_id"), table_name="purchasereturn")
    op.drop_index(op.f("ix_purchasereturn_business_id"), table_name="purchasereturn")
    op.drop_table("purchasereturn")

    # ── 3. Drop the invoice-status column + type ─────────────────────────
    op.drop_index(op.f("ix_purchaseorder_invoice_status"), table_name="purchaseorder")
    op.drop_column("purchaseorder", "invoice_status")
    op.execute("DROP TYPE IF EXISTS invoicestatus")


def downgrade() -> None:
    # ── 3. Recreate returns + payables tables (empty) ───────────────────
    op.create_table(
        "purchasereturn",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("business_id", sa.Uuid(), nullable=False),
        sa.Column("store_id", sa.Uuid(), nullable=False),
        sa.Column("purchase_order_id", sa.Uuid(), nullable=True),
        sa.Column("goods_receipt_id", sa.Uuid(), nullable=True),
        sa.Column("item_id", sa.Uuid(), nullable=False),
        sa.Column("quantity", sa.Numeric(precision=12, scale=3), nullable=False),
        sa.Column("reason", sa.String(500), nullable=True),
        sa.Column("created_by", sa.Uuid(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["purchase_order_id"], ["purchaseorder.id"], ondelete="RESTRICT"
        ),
        sa.ForeignKeyConstraint(
            ["goods_receipt_id"], ["goodsreceipt.id"], ondelete="RESTRICT"
        ),
        sa.ForeignKeyConstraint(["item_id"], ["item.id"], ondelete="RESTRICT"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        op.f("ix_purchasereturn_business_id"), "purchasereturn", ["business_id"]
    )
    op.create_index(
        op.f("ix_purchasereturn_store_id"), "purchasereturn", ["store_id"]
    )
    op.create_index(
        op.f("ix_purchasereturn_purchase_order_id"),
        "purchasereturn",
        ["purchase_order_id"],
    )
    op.create_index(
        op.f("ix_purchasereturn_goods_receipt_id"),
        "purchasereturn",
        ["goods_receipt_id"],
    )
    op.create_index(op.f("ix_purchasereturn_item_id"), "purchasereturn", ["item_id"])
    op.create_table(
        "supplierinvoice",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("business_id", sa.Uuid(), nullable=False),
        sa.Column("supplier_id", sa.Uuid(), nullable=False),
        sa.Column("purchase_order_id", sa.Uuid(), nullable=False),
        sa.Column("invoice_number", sa.String(64), nullable=False),
        sa.Column(
            "amount_total", sa.Numeric(precision=12, scale=2), nullable=False
        ),
        sa.Column(
            "amount_paid",
            sa.Numeric(precision=12, scale=2),
            nullable=False,
            server_default="0.00",
        ),
        sa.Column(
            "status",
            postgresql.ENUM(
                *_INVOICE_STATUS_VALUES, name="invoicestatus", create_type=False
            ),
            nullable=False,
            server_default="unpaid",
        ),
        sa.Column("due_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_by", sa.Uuid(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["supplier_id"], ["supplier.id"], ondelete="RESTRICT"),
        sa.ForeignKeyConstraint(
            ["purchase_order_id"], ["purchaseorder.id"], ondelete="RESTRICT"
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        op.f("ix_supplierinvoice_business_id"), "supplierinvoice", ["business_id"]
    )
    op.create_index(
        op.f("ix_supplierinvoice_supplier_id"), "supplierinvoice", ["supplier_id"]
    )
    op.create_index(
        op.f("ix_supplierinvoice_purchase_order_id"),
        "supplierinvoice",
        ["purchase_order_id"],
    )
    op.create_index(op.f("ix_supplierinvoice_status"), "supplierinvoice", ["status"])
    op.create_table(
        "supplierpayment",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("business_id", sa.Uuid(), nullable=False),
        sa.Column("invoice_id", sa.Uuid(), nullable=False),
        sa.Column("amount", sa.Numeric(precision=12, scale=2), nullable=False),
        sa.Column("method", sa.String(32), nullable=True),
        sa.Column("reference", sa.String(128), nullable=True),
        sa.Column("paid_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("paid_by", sa.Uuid(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["invoice_id"], ["supplierinvoice.id"], ondelete="CASCADE"
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        op.f("ix_supplierpayment_business_id"), "supplierpayment", ["business_id"]
    )
    op.create_index(
        op.f("ix_supplierpayment_invoice_id"), "supplierpayment", ["invoice_id"]
    )

    # ── 2. Restore the invoice-status column + type ─────────────────────
    op.execute(
        "CREATE TYPE invoicestatus AS ENUM "
        f"({', '.join(repr(v) for v in _INVOICE_STATUS_VALUES)})"
    )
    op.add_column(
        "purchaseorder",
        sa.Column(
            "invoice_status",
            postgresql.ENUM(
                *_INVOICE_STATUS_VALUES, name="invoicestatus", create_type=False
            ),
            nullable=False,
            server_default="unbilled",
        ),
    )
    op.create_index(
        op.f("ix_purchaseorder_invoice_status"), "purchaseorder", ["invoice_status"]
    )

    # ── 1. Restore the wide PO status enum ─────────────────────────────
    op.execute("ALTER TABLE purchaseorder ALTER COLUMN status DROP DEFAULT")
    op.execute(
        "CREATE TYPE purchaseorderstatus_old AS ENUM "
        f"({', '.join(repr(v) for v in _OLD_STATUS_VALUES)})"
    )
    op.execute(
        "ALTER TABLE purchaseorder ALTER COLUMN status TYPE "
        "purchaseorderstatus_old USING (CASE status::text "
        "WHEN 'fulfilled' THEN 'received'::purchaseorderstatus_old "
        "WHEN 'cancelled' THEN 'cancelled'::purchaseorderstatus_old "
        "ELSE 'draft'::purchaseorderstatus_old END)"
    )
    op.execute("DROP TYPE purchaseorderstatus")
    op.execute("ALTER TYPE purchaseorderstatus_old RENAME TO purchaseorderstatus")
    op.execute("ALTER TABLE purchaseorder ALTER COLUMN status SET DEFAULT 'draft'")
