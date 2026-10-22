"""Inventory domain models — items, stock levels, movements, and related tables.

═══════════════════════════════════════════════════════════════════════════
CROSS-SERVICE REFERENCE CONVENTION
═══════════════════════════════════════════════════════════════════════════

Columns named ``business_id`` and ``store_id`` store UUIDs that
reference rows in Identity Service's database (``businesses`` and
``store`` tables).  These are stored as **plain indexed UUID
columns with no foreign key constraint** because the referenced tables live
in a separate database (the Identity Service's Postgres instance).

This is the correct pattern in a microservices architecture — foreign keys
cannot span database boundaries.  Referential integrity is enforced at the
application layer (every request is scoped by an authenticated JWT that
already ties the caller to a specific business context).

Do NOT add FK constraints to these columns.  If you feel tempted, re-read
the line above about separate databases.

═══════════════════════════════════════════════════════════════════════════
IMMUTABLE TABLE CONVENTION
═══════════════════════════════════════════════════════════════════════════

``stock_movements`` is an **immutable audit trail**.  Rows in this table
must never be updated or deleted by application code — only inserted.
It intentionally has no ``updated_at`` column.  Violating this convention
will corrupt the audit trail and make financial reconciliation impossible.
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

# ═══════════════════════════════════════════════════════════════════════
# Enums
# ═══════════════════════════════════════════════════════════════════════


class ItemType(str, PyEnum):
    """Classification of an item's role in the business — determines which movement types affect it.

    Semantics that Stage 5's ``record_movement`` must enforce:

    * ``sellable``
        - Decremented by ``sale`` / ``order.confirmed`` events.
        - Never incremented by ``purchase_received`` (you don't purchase a
          menu item from a supplier).
        - Waste, manual_adjustment, transfer_in, transfer_out still apply
          (physical stock corrections are not purchase-or-sale transactions).

    * ``raw_material``
        - Incremented by ``purchase_received``.
        - Decremented by ``waste``, ``manual_adjustment``, ``transfer_out``.
        - Never touched by ``sale`` / ``order`` events directly (no recipe
          decomposition in MVP — see ``RecipeComponent``'s docstring).

    * ``both``
        - A physical item purchased AND sold as-is with no transformation
          (e.g. a bottled drink bought from a supplier and resold unchanged).
        - Accepts either ``purchase_received`` or ``sale`` / ``order`` events.

    ``waste``, ``manual_adjustment``, ``transfer_in``, and ``transfer_out``
    apply to **any** item_type — these represent physical stock corrections
    or movement, not a purchase-or-sale transaction, so they are never
    restricted by this field.
    """

    SELLABLE = "sellable"
    RAW_MATERIAL = "raw_material"
    BOTH = "both"


class MovementType(str, PyEnum):
    """Category of stock movement for audit trail classification.

    ``sale_reversal`` — stock came back due to a voided sale
    (POS Service's ``sale.voided`` event).  ``refund_reversal`` —
    stock came back due to a refunded sale (POS Service's
    ``sale.refunded`` event).  Both are semantically distinct from
    ``manual_adjustment`` — an audit report should be able to count
    reversal movements separately from manual corrections.

    ``production_input`` / ``production_output`` — the two legs of a
    Stage 2 production event: raw materials consumed and the sellable
    item produced.  Distinct types (not ``manual_adjustment``) so a
    kitchen audit can answer "how much rice went into Pilau" without
    disentangling corrections.
    """

    SALE = "sale"
    PURCHASE_RECEIVED = "purchase_received"
    MANUAL_ADJUSTMENT = "manual_adjustment"
    WASTE = "waste"
    TRANSFER_IN = "transfer_in"
    TRANSFER_OUT = "transfer_out"
    SALE_REVERSAL = "sale_reversal"
    REFUND_REVERSAL = "refund_reversal"
    PRODUCTION_INPUT = "production_input"
    PRODUCTION_OUTPUT = "production_output"
    PRODUCTION_REVERSAL = "production_reversal"


class ActorType(str, PyEnum):
    """Who or what caused a stock movement."""

    USER = "user"
    SYSTEM = "system"
    SERVICE = "service"


def _enum_db_values(enum_class: type[PyEnum]) -> list[str]:
    """Return the ``.value`` strings (lowercase) for a Python enum.

    SQLAlchemy's default for a PEP-435 enum class is to persist the member
    **name** (``SELLABLE``) rather than the value (``sellable``).  The
    hand-written Alembic migrations create the native Postgres enum types
    with lowercase ``.value`` strings, so the ORM must be told explicitly
    to send/read lowercase values or every insert on a migration-built
    database is rejected.  ``values_callable`` removes that implicit
    coupling between model code and migration files.
    """

    return [member.value for member in enum_class]


# ═══════════════════════════════════════════════════════════════════════
# Tables
# ═══════════════════════════════════════════════════════════════════════


class Item(SQLModel, table=True):
    """Master record for a single stock-keeping unit (SKU).

    ``business_id`` and ``store_id`` are cross-service
    references to Identity Service's ``businesses`` and
    ``store`` tables (see module docstring for rationale).
    """

    id: UUID = Field(
        default_factory=uuid4,
        primary_key=True,
        nullable=False,
        sa_type=PG_UUID,
    )
    business_id: UUID = Field(
        nullable=False,
        index=True,
        sa_type=PG_UUID,
    )
    store_id: UUID = Field(
        nullable=False,
        index=True,
        sa_type=PG_UUID,
    )
    name: str = Field(nullable=False, max_length=255)
    unit_id: UUID | None = Field(
        default=None,
        sa_column=Column(
            PG_UUID,
            ForeignKey("unit.id", ondelete="RESTRICT"),
            nullable=True,
            index=True,
        ),
    )
    category_id: UUID | None = Field(
        default=None,
        sa_column=Column(
            PG_UUID,
            ForeignKey("category.id", ondelete="RESTRICT"),
            nullable=True,
            index=True,
        ),
    )
    supplier_id: UUID | None = Field(
        default=None,
        sa_column=Column(
            PG_UUID,
            ForeignKey("supplier.id", ondelete="SET NULL"),
            nullable=True,
            index=True,
        ),
    )
    reorder_threshold: Decimal = Field(
        nullable=False,
        sa_type=Numeric(precision=12, scale=3),
    )
    reorder_quantity: Decimal = Field(
        nullable=False,
        sa_type=Numeric(precision=12, scale=3),
    )
    # NOTE (validation judgment call): selling_price is intentionally NOT
    # constrained by item_type.  A raw_material-only item may legitimately
    # carry a selling_price (a raw material can later become sellable), and
    # rejecting a harmless nullable field based on item_type adds friction
    # for little protection.  Flagged as a deliberate decision — see the
    # add-selling-price task summary.
    selling_price: Decimal | None = Field(
        default=None,
        sa_type=Numeric(precision=12, scale=2),
    )
    # Cost basis for the "inventory value" reporting metric (stock * unit_cost).
    # Distinct from selling_price (retail) — a raw_material item typically has
    # a cost but no selling_price, and the two can differ for a `both` item.
    unit_cost: Decimal | None = Field(
        default=None,
        sa_type=Numeric(precision=12, scale=4),
    )
    allow_negative_stock: bool = Field(default=False, nullable=False)
    item_type: ItemType = Field(
        sa_column=Column(
            SAEnum(ItemType, values_callable=_enum_db_values, name="itemtype"),
            nullable=False,
        ),
    )
    is_active: bool = Field(default=True, nullable=False)
    # Storage key of the item's product photo (see
    # ``app/services/item_image_storage.py``), e.g.
    # ``"<business_id>/<item_id>.jpg"``. Null means no photo — callers fall
    # back to the display placeholder. Photos are replaced in place (one
    # photo per item), never versioned.
    image_path: str | None = Field(default=None, max_length=512)
    created_at: datetime = Field(
        default_factory=lambda: datetime.now(UTC),
        sa_type=DateTime(timezone=True),
        sa_column_kwargs={"server_default": func.now()},
        nullable=False,
    )
    updated_at: datetime = Field(
        default_factory=lambda: datetime.now(UTC),
        sa_type=DateTime(timezone=True),
        sa_column_kwargs={
            "server_default": func.now(),
            "onupdate": func.now(),
        },
        nullable=False,
    )


class Recipe(SQLModel, table=True):
    """A named bill-of-materials, optionally linked to one sellable item.

    A "recipe" is a GROUP of ``RecipeComponent`` rows sharing one header.
    The header exists so whole-recipe operations are single actions — "delete
    this recipe" is one row delete, not N coordinated component deletes —
    and so the MVP rule "one active recipe per sellable item" has a natural
    home (the ``UNIQUE`` on ``sellable_item_id``) instead of a racy
    application-level check. It also carries recipe-level metadata (``name``,
    which defaults to the sellable item's own name but may diverge if recipe
    variants ever land).

    STANDALONE RECIPES: ``sellable_item_id`` is nullable so the kitchen can
    define a formula before its menu item exists. The ``UNIQUE`` is kept —
    Postgres treats NULLs as distinct, so any number of standalone recipes
    can coexist while a linked menu item still owns at most one recipe. A
    standalone recipe is linked once via ``POST /recipes/{id}/link`` (link
    is set-once, never moved); production runs/plans refuse unlinked
    recipes with a 422 because the output needs a sellable item to stock.

    BATCH FORMULA SEMANTICS: component quantities are totals for the
    recipe's ``target_yield_quantity`` (e.g. "2kg rice for 50 portions"),
    not per-unit amounts. Per-unit math divides by the target yield, so a
    recipe with the default target of 1 behaves exactly like the original
    per-unit recipe — all pre-batch data is math-identical.

    ``business_id`` follows this module's cross-service convention: a plain
    indexed UUID with no FK (Identity Service owns that table). ``name`` is
    snapshot at creation — renaming the sellable item later does not rewrite
    history here.
    """

    id: UUID = Field(
        default_factory=uuid4,
        primary_key=True,
        nullable=False,
        sa_type=PG_UUID,
    )
    business_id: UUID = Field(
        nullable=False,
        index=True,
        sa_type=PG_UUID,
    )
    sellable_item_id: UUID | None = Field(
        default=None,
        sa_column=Column(
            PG_UUID,
            ForeignKey("item.id", ondelete="CASCADE"),
            nullable=True,
            unique=True,
        ),
    )
    name: str = Field(nullable=False, max_length=255)
    # Kitchen category: prep / sauce / finished dish (free text so kitchens
    # can add their own; the app offers presets). Null = uncategorised.
    category: str | None = Field(default=None, max_length=50)
    # Standard batch size this formula is written for ("makes 50 portions").
    # Components are totals for this yield; per-unit math divides by it.
    target_yield_quantity: Decimal = Field(
        default=Decimal("1"),
        sa_type=Numeric(precision=12, scale=3),
    )
    target_yield_unit: str = Field(default="portions", max_length=50)
    created_at: datetime = Field(
        default_factory=lambda: datetime.now(UTC),
        sa_type=DateTime(timezone=True),
        sa_column_kwargs={"server_default": func.now()},
        nullable=False,
    )
    updated_at: datetime = Field(
        default_factory=lambda: datetime.now(UTC),
        sa_type=DateTime(timezone=True),
        sa_column_kwargs={
            "server_default": func.now(),
            "onupdate": func.now(),
        },
        nullable=False,
    )


class RecipeComponent(SQLModel, table=True):
    """One ingredient line of a ``Recipe``: a raw material and the quantity
    of it required to produce one unit of the recipe's sellable item.

    Rewired in Stage 1 from ``sellable_item_id`` to ``recipe_id`` — the
    header owns the sellable link (and its uniqueness), components are dumb
    rows. The ``(recipe_id, raw_material_item_id)`` unique constraint keeps
    the same ingredient from being listed twice on one recipe; changing an
    amount is an update of the row, not a second row.

    Quantities are in the raw material item's own unit (see
    ``RecipeComponentRead`` — reads resolve the unit code so owners see
    "200g Rice", not a bare number). Batch semantics: the quantity is the
    TOTAL for the recipe's ``target_yield_quantity`` — per-unit math
    divides by it (see ``Recipe``).
    """

    __table_args__ = (
        UniqueConstraint(
            "recipe_id",
            "raw_material_item_id",
            name="uq_recipe_components_recipe_ingredient",
        ),
    )

    id: UUID = Field(
        default_factory=uuid4,
        primary_key=True,
        nullable=False,
        sa_type=PG_UUID,
    )
    recipe_id: UUID = Field(
        sa_column=Column(
            PG_UUID,
            ForeignKey("recipe.id", ondelete="CASCADE"),
            nullable=False,
            index=True,
        ),
    )
    raw_material_item_id: UUID = Field(
        sa_column=Column(
            PG_UUID,
            ForeignKey("item.id", ondelete="CASCADE"),
            nullable=False,
        ),
    )
    quantity_required: Decimal = Field(
        nullable=False,
        sa_type=Numeric(precision=12, scale=3),
    )


class RunStatus(str, PyEnum):
    """Lifecycle of a scheduled production run (Production Module, Tab 2).

    * ``pending`` — planned (recipe + target + recommended lines), no stock
      moved. The only deletable state.
    * ``in_progress`` — started: the (possibly adjusted) ingredients were
      deducted from inventory. Output is NOT stocked yet.
    * ``completed`` — actual yield (+ optional waste/variance reason)
      recorded. Output is still NOT stocked — it lands in inventory when
      the run is **published** (Tab 3's "Publish to POS & Inventory").
    """

    PENDING = "pending"
    IN_PROGRESS = "in_progress"
    COMPLETED = "completed"
    CANCELLED = "cancelled"


class ProductionRun(SQLModel, table=True):
    """One scheduled cooking batch: plan → start → complete → publish.

    A run snapshots the plan at creation (recipe + target + per-ingredient
    planned quantities) so later recipe edits never rewrite a cook's
    shift plan. Starting deducts the measured (adjustable) inputs;
    completing records what cooking actually produced and why any stock
    was lost; publishing stocks the output, writes the immutable
    ``ProductionEvent`` history row (linked back via ``run_id``), and
    stamps ``published_at`` — that publish is the "one-click conversion"
    that makes the finished item sellable on the POS.
    """

    id: UUID = Field(
        default_factory=uuid4,
        primary_key=True,
        nullable=False,
        sa_type=PG_UUID,
    )
    business_id: UUID = Field(
        nullable=False,
        index=True,
        sa_type=PG_UUID,
    )
    store_id: UUID = Field(
        nullable=False,
        index=True,
        sa_type=PG_UUID,
    )
    recipe_id: UUID = Field(
        sa_column=Column(
            PG_UUID,
            ForeignKey("recipe.id", ondelete="RESTRICT"),
            nullable=False,
            index=True,
        ),
    )
    target_output_quantity: Decimal = Field(
        nullable=False,
        sa_type=Numeric(precision=12, scale=3),
    )
    status: RunStatus = Field(
        default=RunStatus.PENDING,
        sa_column=Column(
            SAEnum(RunStatus, values_callable=_enum_db_values, name="runstatus"),
            nullable=False,
        ),
    )
    leading_component_item_id: UUID | None = Field(
        default=None,
        sa_column=Column(
            PG_UUID,
            ForeignKey("item.id", ondelete="RESTRICT"),
            nullable=True,
        ),
    )
    yield_tolerance_percent: Decimal = Field(
        default=Decimal("5"),
        sa_type=Numeric(precision=12, scale=3),
    )
    actual_output_quantity: Decimal | None = Field(
        default=None,
        sa_type=Numeric(precision=12, scale=3),
    )
    # Loss tracking: why stock went missing (spillage, burning,
    # over-portioning). Free text — the kitchen's own words.
    waste_reason: str | None = Field(default=None, max_length=500)
    # Simple words for the undo button: why this batch was stopped.
    cancel_reason: str | None = Field(default=None, max_length=500)
    cancelled_at: datetime | None = Field(
        default=None, sa_type=DateTime(timezone=True)
    )
    # Safe retry: same key sent twice makes only one batch.
    idempotency_key: str | None = Field(default=None, max_length=100)
    published_at: datetime | None = Field(
        default=None, sa_type=DateTime(timezone=True)
    )
    created_by: UUID | None = Field(default=None, sa_type=PG_UUID)
    started_at: datetime | None = Field(
        default=None, sa_type=DateTime(timezone=True)
    )
    completed_at: datetime | None = Field(
        default=None, sa_type=DateTime(timezone=True)
    )
    created_at: datetime = Field(
        default_factory=lambda: datetime.now(UTC),
        sa_type=DateTime(timezone=True),
        sa_column_kwargs={"server_default": func.now()},
        nullable=False,
    )
    updated_at: datetime = Field(
        default_factory=lambda: datetime.now(UTC),
        sa_type=DateTime(timezone=True),
        sa_column_kwargs={
            "server_default": func.now(),
            "onupdate": func.now(),
        },
        nullable=False,
    )


class ProductionRunComponent(SQLModel, table=True):
    """One ingredient line of a ``ProductionRun``'s snapshot plan.

    ``planned_quantity`` is the recommendation (per-unit requirement ×
    target) frozen at creation; ``measured_quantity`` is what the cook
    actually weighed at start (adjustable — null until the run starts,
    then exactly what was deducted).
    """

    __table_args__ = (
        UniqueConstraint(
            "production_run_id",
            "raw_material_item_id",
            name="uq_run_components_run_ingredient",
        ),
    )

    id: UUID = Field(
        default_factory=uuid4,
        primary_key=True,
        nullable=False,
        sa_type=PG_UUID,
    )
    production_run_id: UUID = Field(
        sa_column=Column(
            PG_UUID,
            ForeignKey("productionrun.id", ondelete="CASCADE"),
            nullable=False,
            index=True,
        ),
    )
    raw_material_item_id: UUID = Field(
        sa_column=Column(
            PG_UUID,
            ForeignKey("item.id", ondelete="CASCADE"),
            nullable=False,
        ),
    )
    planned_quantity: Decimal = Field(
        nullable=False,
        sa_type=Numeric(precision=12, scale=3),
    )
    measured_quantity: Decimal | None = Field(
        default=None,
        sa_type=Numeric(precision=12, scale=3),
    )


class ProductionEvent(SQLModel, table=True):
    """One recorded production run (Stage 2): raw materials in, sellable out.

    A production is a third kind of stock transaction, distinct from sales
    and purchases — it exists because a flat sale/purchase model cannot
    answer "how much rice does my Pilau consume".  The ingredient math comes
    from the linked ``Recipe``; this row records what was actually measured
    and confirmed.

    ``suggested_output_quantity`` is the recipe-computed output (leading
    quantity ÷ leading requirement, or the entered target when the
    target-based flow is used); ``target_output_quantity`` is the goal the
    cook entered before measuring (nullable for pre-target runs);
    ``actual_output_quantity`` is what the owner confirmed after cooking.
    The gap between actual and target/suggested is the yield signal used
    for the above/within/below-threshold verdict.

    ``store_id`` is the sellable item's store (see ``production_service`` —
    derived, not client-supplied).  ``occurred_at`` is the business time of
    the run (server-set in MVP; the filterable field for history), while
    ``created_at`` is row-creation time.

    Production rows are RECORDS, like movements: never updated or deleted by
    application code.  ``recipe_id`` is RESTRICT (not CASCADE) so deleting a
    recipe with production history is refused instead of silently destroying
    that history — see the recipes endpoint's 409 mapping.
    """

    id: UUID = Field(
        default_factory=uuid4,
        primary_key=True,
        nullable=False,
        sa_type=PG_UUID,
    )
    business_id: UUID = Field(
        nullable=False,
        index=True,
        sa_type=PG_UUID,
    )
    store_id: UUID = Field(
        nullable=False,
        index=True,
        sa_type=PG_UUID,
    )
    recipe_id: UUID = Field(
        sa_column=Column(
            PG_UUID,
            ForeignKey("recipe.id", ondelete="RESTRICT"),
            nullable=False,
            index=True,
        ),
    )
    leading_component_item_id: UUID = Field(
        sa_column=Column(
            PG_UUID,
            ForeignKey("item.id", ondelete="RESTRICT"),
            nullable=False,
        ),
    )
    leading_quantity_used: Decimal = Field(
        nullable=False,
        sa_type=Numeric(precision=12, scale=3),
    )
    target_output_quantity: Decimal | None = Field(
        default=None,
        sa_type=Numeric(precision=12, scale=3),
    )
    suggested_output_quantity: Decimal = Field(
        nullable=False,
        sa_type=Numeric(precision=12, scale=3),
    )
    actual_output_quantity: Decimal = Field(
        nullable=False,
        sa_type=Numeric(precision=12, scale=3),
    )
    # The run this event published (null for direct/quick records that
    # never went through the run lifecycle).
    run_id: UUID | None = Field(
        default=None,
        sa_column=Column(
            PG_UUID,
            ForeignKey("productionrun.id", ondelete="RESTRICT"),
            nullable=True,
            index=True,
        ),
    )
    # Loss tracking carried over from the run's completion.
    waste_reason: str | None = Field(default=None, max_length=500)
    # Simple undo: when set, this record is undone (stock was put back).
    # History is kept — we never delete rows.
    voided_at: datetime | None = Field(
        default=None, sa_type=DateTime(timezone=True)
    )
    void_reason: str | None = Field(default=None, max_length=500)
    # The band used for the "met plan" check, saved so history always
    # reads the same (was request-only before).
    yield_tolerance_percent: Decimal = Field(
        default=Decimal("5"),
        sa_type=Numeric(precision=12, scale=3),
    )
    # Simple cost: what all used items cost in total, and per made item.
    # Null when items have no cost on file.
    production_cost_total: Decimal | None = Field(
        default=None,
        sa_type=Numeric(precision=12, scale=4),
    )
    production_cost_per_unit: Decimal | None = Field(
        default=None,
        sa_type=Numeric(precision=12, scale=4),
    )
    # Safe retry: same key sent twice makes only one record.
    idempotency_key: str | None = Field(default=None, max_length=100)
    actor_id: UUID | None = Field(default=None, sa_type=PG_UUID)
    occurred_at: datetime = Field(
        default_factory=lambda: datetime.now(UTC),
        sa_type=DateTime(timezone=True),
        sa_column_kwargs={"server_default": func.now()},
        nullable=False,
    )
    created_at: datetime = Field(
        default_factory=lambda: datetime.now(UTC),
        sa_type=DateTime(timezone=True),
        sa_column_kwargs={"server_default": func.now()},
        nullable=False,
    )


class ProductionEventComponent(SQLModel, table=True):
    """One ingredient actually consumed by a ``ProductionEvent``.

    Not a copy of the recipe — the recipe says what SHOULD go in per unit,
    this says what DID go in for this run (recipe ratio × leading quantity).
    The leading ingredient's own row equals ``leading_quantity_used``
    exactly (no float round-trip through the ratio).  One row per
    ingredient per event, enforced by the unique constraint.
    """

    __table_args__ = (
        UniqueConstraint(
            "production_event_id",
            "raw_material_item_id",
            name="uq_production_components_event_ingredient",
        ),
    )

    id: UUID = Field(
        default_factory=uuid4,
        primary_key=True,
        nullable=False,
        sa_type=PG_UUID,
    )
    production_event_id: UUID = Field(
        sa_column=Column(
            PG_UUID,
            ForeignKey("productionevent.id", ondelete="CASCADE"),
            nullable=False,
            index=True,
        ),
    )
    raw_material_item_id: UUID = Field(
        sa_column=Column(
            PG_UUID,
            ForeignKey("item.id", ondelete="CASCADE"),
            nullable=False,
        ),
    )
    quantity_consumed: Decimal = Field(
        nullable=False,
        sa_type=Numeric(precision=12, scale=3),
    )


class StockLevel(SQLModel, table=True):
    """Current stock quantity for an item at a specific store.

    The (item_id, store_id) unique constraint is load-bearing
    for the upsert logic in Stage 5 — it enables an INSERT ... ON CONFLICT
    pattern that atomically creates-or-updates stock levels without a
    separate select-then-insert round trip.
    """

    __table_args__ = (
        UniqueConstraint(
            "item_id",
            "store_id",
            name="uq_stock_levels_item_store",
        ),
    )

    id: UUID = Field(
        default_factory=uuid4,
        primary_key=True,
        nullable=False,
        sa_type=PG_UUID,
    )
    item_id: UUID = Field(
        sa_column=Column(
            PG_UUID,
            ForeignKey("item.id", ondelete="CASCADE"),
            nullable=False,
        ),
    )
    store_id: UUID = Field(
        nullable=False,
        index=True,
        sa_type=PG_UUID,
    )
    current_quantity: Decimal = Field(
        nullable=False,
        sa_type=Numeric(precision=12, scale=3),
    )
    updated_at: datetime = Field(
        default_factory=lambda: datetime.now(UTC),
        sa_type=DateTime(timezone=True),
        sa_column_kwargs={
            "server_default": func.now(),
            "onupdate": func.now(),
        },
        nullable=False,
    )


class StockMovement(SQLModel, table=True):
    """Immutable audit trail of every stock quantity change.

    **This table is append-only.**  Rows must never be updated or deleted
    by application code.  The absence of an ``updated_at`` column is
    intentional.
    """

    id: UUID = Field(
        default_factory=uuid4,
        primary_key=True,
        nullable=False,
        sa_type=PG_UUID,
    )
    item_id: UUID = Field(
        sa_column=Column(
            PG_UUID,
            ForeignKey("item.id", ondelete="CASCADE"),
            nullable=False,
            index=True,
        ),
    )
    business_id: UUID = Field(
        nullable=False,
        index=True,
        sa_type=PG_UUID,
    )
    store_id: UUID = Field(
        nullable=False,
        index=True,
        sa_type=PG_UUID,
    )
    quantity_delta: Decimal = Field(
        nullable=False,
        sa_type=Numeric(precision=12, scale=3),
    )
    # Frozen per-unit cost basis at event time (snapshot of Item.unit_cost
    # when the movement was recorded, or the receipt's actual unit_cost for
    # PURCHASE_RECEIVED legs). Null for rows written before the snapshot
    # existed — reports fall back to the item's current unit_cost for those
    # and flag the line estimated. Never updated: history must not move when
    # later deliveries revalue Item.unit_cost.
    unit_cost: Decimal | None = Field(
        default=None,
        sa_type=Numeric(precision=12, scale=4),
    )
    movement_type: MovementType = Field(
        sa_column=Column(
            SAEnum(MovementType, values_callable=_enum_db_values, name="movementtype"),
            nullable=False,
        ),
    )
    reference_type: str | None = Field(default=None, max_length=100)
    reference_id: UUID | None = Field(default=None, sa_type=PG_UUID)
    actor_type: ActorType = Field(
        sa_column=Column(
            SAEnum(ActorType, values_callable=_enum_db_values, name="actortype"),
            nullable=False,
        ),
    )
    actor_id: UUID | None = Field(default=None, sa_type=PG_UUID)
    reason: str | None = Field(default=None, max_length=500)
    created_at: datetime = Field(
        default_factory=lambda: datetime.now(UTC),
        index=True,
        sa_type=DateTime(timezone=True),
        sa_column_kwargs={"server_default": func.now()},
        nullable=False,
    )


class ProcessedEvent(SQLModel, table=True):
    """Idempotency tracker for inbound events from the event bus.

    This table's only job is fast existence-checks via PRIMARY KEY lookup.
    Before processing an event, insert the event_id — if it already exists
    (unique violation), the event has already been processed and can be
    safely skipped.
    """

    event_id: str = Field(primary_key=True, nullable=False, max_length=255)
    processed_at: datetime = Field(
        default_factory=lambda: datetime.now(UTC),
        sa_type=DateTime(timezone=True),
        sa_column_kwargs={"server_default": func.now()},
        nullable=False,
    )
