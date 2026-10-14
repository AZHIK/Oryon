"""Standalone recipes — recipe without a menu item yet.

Revision ID: v1w2x3y4z5a6
Revises: u4v5w6x7y8z9
Create Date: 2026-10-13 00:00:00.000000
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "v1w2x3y4z5a6"
down_revision: Union[str, None] = "u4v5w6x7y8z9"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # A recipe may now exist before its menu item does (standalone formula,
    # linked later via POST /recipes/{id}/link). The UNIQUE on
    # sellable_item_id is kept: Postgres treats NULLs as distinct, so any
    # number of standalone recipes can coexist while a linked menu item
    # still owns at most one recipe.
    op.alter_column("recipe", "sellable_item_id", nullable=True)


def downgrade() -> None:
    op.execute(
        "DELETE FROM recipe WHERE sellable_item_id IS NULL"
    )
    op.alter_column("recipe", "sellable_item_id", nullable=False)
