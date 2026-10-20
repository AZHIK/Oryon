"""Allow users to exist without a phone number (email-only staff invites).

Revision ID: c4d5e6f7a8b9
Revises: b3c4d5e6f7a8

Staff invited by email are created with ``email`` set and no phone yet. The
unique constraint on ``phone`` remains: Postgres treats NULLs as distinct, so
any number of email-only users can coexist while real numbers stay unique.
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "c4d5e6f7a8b9"
down_revision: Union[str, None] = "b3c4d5e6f7a8"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.alter_column("users", "phone", existing_type=sa.String(20), nullable=True)


def downgrade() -> None:
    # Restoring NOT NULL requires every user to have a phone. Email-only
    # invites have none, so they cannot survive a downgrade; delete them
    # first rather than failing halfway through the migration.
    op.execute("DELETE FROM users WHERE phone IS NULL")
    op.alter_column("users", "phone", existing_type=sa.String(20), nullable=False)
