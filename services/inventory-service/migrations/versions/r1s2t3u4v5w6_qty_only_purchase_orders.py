"""Qty-only purchase orders — cost moves to GRN lines.

Revision ID: r1s2t3u4v5w6
Revises: q9r0s1t2u3v4
Create Date: 2026-10-13 00:00:00.000000

Purchase orders (``purchaseorder`` + ``purchaseorderline``) and the legacy
``reorder`` table no longer carry money:

* ``goodsreceiptline`` gains non-nullable ``unit_cost`` — the single point
  where purchase cost enters (backfilled from the parent PO line so legacy
  receipts keep their valuation).
* ``purchaseorderline`` loses ``unit_cost`` + ``price_unconfirmed``.
* ``purchaseorder`` loses ``total_amount``.
* ``reorder`` loses ``unit_cost`` (cost arrives on the receive call).
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "r1s2t3u4v5w6"
down_revision: Union[str, None] = "q9r0s1t2u3v4"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ── 1. GRN line cost (nullable first, backfill, then NOT NULL) ──────
    op.add_column(
        "goodsreceiptline",
        sa.Column("unit_cost", sa.Numeric(precision=12, scale=4), nullable=True),
    )
    op.execute(
        "UPDATE goodsreceiptline SET unit_cost = "
        "(SELECT unit_cost FROM purchaseorderline "
        "WHERE purchaseorderline.id = goodsreceiptline.purchase_order_line_id) "
        "WHERE unit_cost IS NULL"
    )
    # Rows whose parent PO line is gone (should not happen — RESTRICT) or
    # test fixtures with no cost fall back to zero rather than failing.
    op.execute("UPDATE goodsreceiptline SET unit_cost = 0 WHERE unit_cost IS NULL")
    op.alter_column("goodsreceiptline", "unit_cost", nullable=False)

    # ── 2. Drop PO money ────────────────────────────────────────────────
    op.drop_column("purchaseorderline", "price_unconfirmed")
    op.drop_column("purchaseorderline", "unit_cost")
    op.drop_column("purchaseorder", "total_amount")

    # ── 3. Drop legacy reorder money ────────────────────────────────────
    op.drop_column("reorder", "unit_cost")


def downgrade() -> None:
    op.add_column(
        "reorder",
        sa.Column(
            "unit_cost",
            sa.Numeric(precision=12, scale=4),
            nullable=False,
            server_default="0",
        ),
    )
    op.add_column(
        "purchaseorder",
        sa.Column(
            "total_amount",
            sa.Numeric(precision=12, scale=2),
            nullable=False,
            server_default="0.00",
        ),
    )
    op.add_column(
        "purchaseorderline",
        sa.Column(
            "unit_cost",
            sa.Numeric(precision=12, scale=4),
            nullable=False,
            server_default="0",
        ),
    )
    op.add_column(
        "purchaseorderline",
        sa.Column(
            "price_unconfirmed",
            sa.Boolean(),
            nullable=False,
            server_default=sa.false(),
        ),
    )
    op.drop_column("goodsreceiptline", "unit_cost")
