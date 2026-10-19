"""Production undo + saved tolerance + simple cost (simple words).

Adds to productionevent:
  voided_at, void_reason (undo keeps history, puts stock back),
  yield_tolerance_percent (saved so history always reads the same),
  production_cost_total / production_cost_per_unit (simple cost),
  idempotency_key (safe retry: same key = one record).

Adds to productionrun: cancel_reason, cancelled_at, idempotency_key.
Adds movementtype 'production_reversal' and runstatus 'cancelled'.

Revision ID: w3x4y5z6a7b8
Revises: v1w2x3y4z5a6
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "w3x4y5z6a7b8"
down_revision: Union[str, None] = "v1w2x3y4z5a6"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.execute("ALTER TYPE movementtype ADD VALUE IF NOT EXISTS 'production_reversal'")
    op.execute("ALTER TYPE runstatus ADD VALUE IF NOT EXISTS 'cancelled'")

    op.add_column(
        "productionevent",
        sa.Column("voided_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column(
        "productionevent",
        sa.Column("void_reason", sa.String(length=500), nullable=True),
    )
    op.add_column(
        "productionevent",
        sa.Column(
            "yield_tolerance_percent",
            sa.Numeric(precision=12, scale=3),
            nullable=False,
            server_default="5",
        ),
    )
    op.add_column(
        "productionevent",
        sa.Column("production_cost_total", sa.Numeric(precision=12, scale=4), nullable=True),
    )
    op.add_column(
        "productionevent",
        sa.Column("production_cost_per_unit", sa.Numeric(precision=12, scale=4), nullable=True),
    )
    op.add_column(
        "productionevent",
        sa.Column("idempotency_key", sa.String(length=100), nullable=True),
    )
    op.create_index(
        op.f("ix_productionevent_idempotency_key"),
        "productionevent",
        ["business_id", "idempotency_key"],
    )

    op.add_column(
        "productionrun",
        sa.Column("cancel_reason", sa.String(length=500), nullable=True),
    )
    op.add_column(
        "productionrun",
        sa.Column("cancelled_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column(
        "productionrun",
        sa.Column("idempotency_key", sa.String(length=100), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("productionrun", "idempotency_key")
    op.drop_column("productionrun", "cancelled_at")
    op.drop_column("productionrun", "cancel_reason")
    op.drop_index(op.f("ix_productionevent_idempotency_key"), table_name="productionevent")
    op.drop_column("productionevent", "idempotency_key")
    op.drop_column("productionevent", "production_cost_per_unit")
    op.drop_column("productionevent", "production_cost_total")
    op.drop_column("productionevent", "yield_tolerance_percent")
    op.drop_column("productionevent", "void_reason")
    op.drop_column("productionevent", "voided_at")
    # ENUM values left in place (Postgres cannot drop them).
