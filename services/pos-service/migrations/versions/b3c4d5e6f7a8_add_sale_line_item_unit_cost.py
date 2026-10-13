"""Add sale_line_items.unit_cost production-cost snapshot.

Per-unit cost of the item when the ticket closed, frozen for profit
history while live recipe costs keep moving. Nullable: sales synced by
older clients carry no snapshot, and reports fall back to live recipe
costs for those rows.

Revision ID: b3c4d5e6f7a8
Revises: a1b2c3d4e5f7
Create Date: 2026-10-08 00:00:00.000000
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "b3c4d5e6f7a8"
down_revision: Union[str, None] = "a1b2c3d4e5f7"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "sale_line_items",
        sa.Column("unit_cost", sa.Numeric(precision=12, scale=4), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("sale_line_items", "unit_cost")
