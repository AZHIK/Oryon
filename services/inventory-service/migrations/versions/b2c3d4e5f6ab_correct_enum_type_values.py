"""Correct enum type values to match the ORM values_callable contract.

══════════════════════════════════════════════════════════════════════════
WHY THIS MIGRATION EXISTS
══════════════════════════════════════════════════════════════════════════

The ORM layer now persists enum **values** (lowercase, via
``values_callable`` on every enum column) instead of the default member
**names** (uppercase).  The initial schema already created the native
Postgres enum types with lowercase values, so a database built by
``alembic upgrade head`` is already correct.

This migration exists to guarantee the enum types hold the correct
lowercase values in ANY pre-existing database — most importantly one that
was ever created via ``SQLModel.metadata.create_all`` (the old test
strategy), which would have created the types with uppercase member
names.  Without this cleanup, such a database would now reject the
lowercase values the ORM sends.

Pre-launch status confirmed: the live ``oryonfoods_inventory`` database
holds only ``alembic_version`` — no business data.  The affected tables
are empty, so the enum types are simply dropped (CASCADE removes any
dependent columns) and recreated with the correct values.  This is the
deliberate drop-and-recreate approach, NOT a value-preserving
``ALTER TYPE``, because there is no data worth preserving.

Revision ID: b2c3d4e5f6ab
Revises: b2c3d4e5f6a9
Create Date: 2026-07-31
"""

from typing import Sequence, Union

from alembic import op

revision: str = "b2c3d4e5f6ab"
down_revision: Union[str, None] = "b2c3d4e5f6a9"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # DROP CASCADE also removes the enum-typed columns (item.unit_of_measure,
    # item.item_type, stockmovement.movement_type, stockmovement.actor_type)
    # if they exist.  There are no dependent views or constraints.
    op.execute("DROP TYPE IF EXISTS unitofmeasure CASCADE")
    op.execute("DROP TYPE IF EXISTS itemtype CASCADE")
    op.execute("DROP TYPE IF EXISTS movementtype CASCADE")
    op.execute("DROP TYPE IF EXISTS actortype CASCADE")

    # Recreate with lowercase .value strings — must mirror the enum class
    # definitions in app/models/inventory.py.
    op.execute(
        "CREATE TYPE unitofmeasure AS ENUM ('kg', 'g', 'l', 'ml', 'unit', 'pack')"
    )
    op.execute(
        "CREATE TYPE itemtype AS ENUM ('sellable', 'raw_material', 'both')"
    )
    op.execute(
        "CREATE TYPE movementtype AS ENUM ("
        "'sale', 'purchase_received', 'manual_adjustment', 'waste', "
        "'transfer_in', 'transfer_out', 'sale_reversal', 'refund_reversal')"
    )
    op.execute("CREATE TYPE actortype AS ENUM ('user', 'system', 'service')")

    # Restore the columns that DROP CASCADE removed, only if the owning
    # table still exists (defensive — on a database where the tables were
    # already dropped, e.g. after create_all/drop_all test runs, nothing is
    # recreated here).  Columns are re-added NOT NULL with no default, which
    # matches the post-a6a7 schema (item_type has no server default).
    op.execute(
        """
        DO $$
        BEGIN
            IF to_regclass('public.item') IS NOT NULL THEN
                ALTER TABLE item
                    ADD COLUMN unit_of_measure unitofmeasure NOT NULL,
                    ADD COLUMN item_type itemtype NOT NULL;
            END IF;
            IF to_regclass('public.stockmovement') IS NOT NULL THEN
                ALTER TABLE stockmovement
                    ADD COLUMN movement_type movementtype NOT NULL,
                    ADD COLUMN actor_type actortype NOT NULL;
            END IF;
        END
        $$;
        """
    )


def downgrade() -> None:
    """No-op downgrade — see the sale_reversal migration for the pattern.

    The enum types created here hold the same lowercase values that every
    other migration in the chain produces, so there is no meaningful prior
    state to restore.  A downgrade that recreated the types with uppercase
    member names would contradict the rest of the migration lineage and
    break the ORM's values_callable contract.  If a full schema rollback is
    ever required, drop the database and re-run ``alembic upgrade head``.
    """
    pass
