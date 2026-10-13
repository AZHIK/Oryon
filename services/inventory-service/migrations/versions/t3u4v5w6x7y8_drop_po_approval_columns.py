"""Drop purchase-order approval columns (no approve step anymore).

Revision ID: t3u4v5w6x7y8
Revises: s2t3u4v5w6x7
Create Date: 2026-10-13 00:00:00.000000
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "t3u4v5w6x7y8"
down_revision: Union[str, None] = "s2t3u4v5w6x7"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.drop_column("purchaseorder", "approved_by")
    op.drop_column("purchaseorder", "approved_at")


def downgrade() -> None:
    op.add_column(
        "purchaseorder",
        sa.Column("approved_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column("purchaseorder", sa.Column("approved_by", sa.Uuid(), nullable=True))
