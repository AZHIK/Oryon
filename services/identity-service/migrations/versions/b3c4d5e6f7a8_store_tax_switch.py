"""Per-store tax switch (default off) + tax rate.

Adds to store_settings:
  tax_enabled BOOLEAN DEFAULT false (off = no tax charged or shown),
  tax_rate NUMERIC(5,4) DEFAULT 0 (fraction, 0.18 = 18%).

Backfills existing stores to off/0.

Revision ID: b3c4d5e6f7a8
Revises: a2b3c4d5e6f7
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "b3c4d5e6f7a8"
down_revision: Union[str, None] = "a2b3c4d5e6f7"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "store_settings",
        sa.Column("tax_enabled", sa.Boolean(), nullable=False, server_default="false"),
    )
    op.add_column(
        "store_settings",
        sa.Column("tax_rate", sa.Numeric(precision=5, scale=4), nullable=True, server_default="0"),
    )


def downgrade() -> None:
    op.drop_column("store_settings", "tax_rate")
    op.drop_column("store_settings", "tax_enabled")
