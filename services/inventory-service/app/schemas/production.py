"""Schemas for production events (Stage 2 + target-based planning).

Two input UX flows share one commit path:

1. LEADING-INGREDIENT flow (original): the owner measures ONE leading
   ingredient ("2kg rice") — every other consumption follows from the
   recipe ratio, and the output suggestion is pre-filled but
   owner-adjustable.
2. TARGET-OUTPUT flow (new): the owner enters how many products they want
   ("100 plates") — the app recommends every grocery amount
   (``quantity_required * target``), each line remains adjustable, and
   after cooking the owner confirms the amount actually achieved. The
   system then reports whether the yield is above / within / below the
   allowed threshold around the target.

Both flows commit through ``ProduceRequest``; the server computes the
yield verdict (never the client) so history and insights agree.
"""

from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from enum import Enum as PyEnum
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, model_validator


class YieldStatus(str, PyEnum):
    """Yield verdict of a production run vs its goal.

    * ``above`` — actual exceeds goal + tolerance (over-yield).
    * ``within_threshold`` — actual landed inside goal ± tolerance.
    * ``below`` — actual fell short of goal − tolerance (under-yield).
    """

    ABOVE = "above"
    WITHIN_THRESHOLD = "within_threshold"
    BELOW = "below"


DEFAULT_YIELD_TOLERANCE_PERCENT = Decimal("5")


def evaluate_yield(
    *,
    actual: Decimal,
    goal: Decimal,
    tolerance_percent: Decimal = DEFAULT_YIELD_TOLERANCE_PERCENT,
) -> tuple[YieldStatus, Decimal, Decimal | None]:
    """Compare ``actual`` against ``goal`` with a ± tolerance band.

    Returns ``(status, variance, variance_percent)`` where
    ``variance = actual - goal`` and ``variance_percent`` is
    ``variance / goal * 100`` (``None`` when goal is zero, which the
    request validators already reject — defensive only).
    """
    variance = actual - goal
    if goal == 0:
        return YieldStatus.BELOW, variance, None
    raw_percent = variance / goal * Decimal("100")
    tolerance = abs(tolerance_percent)
    if abs(raw_percent) <= tolerance:
        status = YieldStatus.WITHIN_THRESHOLD
    elif variance > 0:
        status = YieldStatus.ABOVE
    else:
        status = YieldStatus.BELOW
    # Rounded for stable API output (the verdict above used full precision,
    # so a 5.004% shortfall still reads "below" a 5% band).
    variance_percent = raw_percent.quantize(Decimal("0.01"))
    return status, variance, variance_percent


class MeasuredComponentInput(BaseModel):
    """One adjustable ingredient line on a target-based produce request.

    ``quantity_used`` is the owner-adjusted measured amount in the raw
    material's own unit. When ``components`` is supplied it must cover the
    whole recipe exactly once — a partial override would silently leave
    some ingredient on ratio math and some on manual math.
    """

    raw_material_item_id: UUID
    quantity_used: Decimal = Field(gt=Decimal("0"))


class ProduceRequest(BaseModel):
    """Record a production run against a recipe.

    Backward-compatible superset of the original shape:

    * ``leading_item_id`` + ``leading_quantity_used`` — still required
      (the anchor the ratio and audit trail hang off). In the target flow
      this is simply whichever ingredient the cook weighed first; when
      ``components`` is supplied its entry must equal
      ``leading_quantity_used``.
    * ``target_output_quantity`` — optional goal ("I need 100 plates").
      When present the suggestion and the yield verdict are anchored on
      it instead of on the ratio.
    * ``components`` — optional full adjustable ingredient list. Omit it
      and the server derives every line from the ratio (original
      behaviour); supply it and the server consumes exactly those
      amounts (after validating full-recipe coverage).
    * ``actual_output_quantity`` — optional confirmed output; omit it and
      the server commits the suggestion (plan-met portions).
    * ``yield_tolerance_percent`` — half-width of the "met plan" band
      around the goal, in percent (0–100, default 5). Everything inside
      the band reports ``within_threshold``.
    """

    leading_item_id: UUID
    leading_quantity_used: Decimal = Field(gt=Decimal("0"))
    target_output_quantity: Decimal | None = Field(default=None, gt=Decimal("0"))
    components: list[MeasuredComponentInput] | None = Field(default=None, min_length=1)
    actual_output_quantity: Decimal | None = Field(default=None, gt=Decimal("0"))
    yield_tolerance_percent: Decimal = Field(
        default=DEFAULT_YIELD_TOLERANCE_PERCENT, ge=Decimal("0"), le=Decimal("100")
    )
    # Safe retry: same key sent twice makes only one record.
    idempotency_key: str | None = Field(default=None, max_length=100)

    @model_validator(mode="after")
    def _leading_matches_override(self) -> ProduceRequest:
        if self.components is None:
            return self
        for line in self.components:
            if line.raw_material_item_id == self.leading_item_id:
                if line.quantity_used != self.leading_quantity_used:
                    raise ValueError(
                        "components entry for the leading ingredient must equal "
                        "leading_quantity_used — adjust both together"
                    )
                return self
        raise ValueError(
            "components must include the leading ingredient "
            "(one entry per recipe ingredient, including the leading one)"
        )


class ProductionPlanRequest(BaseModel):
    """Ask "I need N products — how much of each grocery item?".

    Pure calculation, no stock movement. Every line is a recommendation
    the cook may adjust before committing via ``ProduceRequest.components``.
    """

    target_output_quantity: Decimal = Field(gt=Decimal("0"))


class PlannedComponentRead(BaseModel):
    """One recommended ingredient line for a target output."""

    raw_material_item_id: UUID
    raw_material_name: str
    raw_material_unit: str
    quantity_required_per_unit: Decimal
    planned_quantity: Decimal


class ProductionPlanRead(BaseModel):
    """Recommendation for a target output: one line per ingredient."""

    recipe_id: UUID
    recipe_name: str
    sellable_item_id: UUID
    sellable_item_name: str
    target_output_quantity: Decimal
    suggested_output_quantity: Decimal
    components: list[PlannedComponentRead] = []


class ProductionComponentRead(BaseModel):
    """One ingredient consumed by the event, with its resolved item details."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    production_event_id: UUID
    raw_material_item_id: UUID
    raw_material_name: str
    raw_material_unit: str
    quantity_consumed: Decimal


class ProductionEventRead(BaseModel):
    """A recorded production run with its yield verdict.

    ``yield_goal_quantity`` is the number the verdict is measured against:
    the entered target when the target flow was used, else the
    recipe-computed suggestion. ``yield_status`` is ``above`` /
    ``within_threshold`` / ``below`` per ``yield_tolerance_percent``.
    """

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    business_id: UUID
    store_id: UUID
    recipe_id: UUID
    recipe_name: str
    sellable_item_id: UUID
    sellable_item_name: str
    leading_component_item_id: UUID
    leading_quantity_used: Decimal
    target_output_quantity: Decimal | None = None
    suggested_output_quantity: Decimal
    actual_output_quantity: Decimal
    run_id: UUID | None = None
    waste_reason: str | None = None
    # True when this record was undone (stock put back). History kept.
    voided_at: datetime | None = None
    void_reason: str | None = None
    # Simple cost: what all used items cost, and per made item.
    production_cost_total: Decimal | None = None
    production_cost_per_unit: Decimal | None = None
    yield_goal_quantity: Decimal
    yield_variance: Decimal
    yield_variance_percent: Decimal | None = None
    yield_status: YieldStatus
    yield_tolerance_percent: Decimal = DEFAULT_YIELD_TOLERANCE_PERCENT
    actor_id: UUID | None = None
    occurred_at: datetime
    created_at: datetime
    components: list[ProductionComponentRead] = []
