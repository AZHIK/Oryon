"""Schemas for scheduled production runs (Production Module, Tab 2 + 3).

A run is a cooking batch with a lifecycle:

    pending → in_progress → completed → published
    (plan)     (inputs       (actual      (output stocked +
               deducted)      recorded)     history event)

Creation snapshots the plan (per-ingredient quantities for the target) so
later recipe edits never rewrite a cook's shift plan. Starting deducts the
measured (adjustable) inputs; completing records the actual yield and the
waste/variance reason; publishing stocks the output — the "one-click
conversion" that makes the finished item sellable on the POS — and writes
the immutable history event the yield verdict is computed from.
"""

from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, model_validator

from app.schemas.production import DEFAULT_YIELD_TOLERANCE_PERCENT, YieldStatus


class RunCreate(BaseModel):
    """Schedule a batch: recipe + how many products to make.

    No stock moves — the plan (per-ingredient quantities for the target)
    is snapshotted onto the run for the cook to measure against.
    """

    recipe_id: UUID
    target_output_quantity: Decimal = Field(gt=Decimal("0"))
    yield_tolerance_percent: Decimal = Field(
        default=DEFAULT_YIELD_TOLERANCE_PERCENT, ge=Decimal("0"), le=Decimal("100")
    )
    # Safe retry: same key sent twice makes only one batch.
    idempotency_key: str | None = Field(default=None, max_length=100)


class RunMeasuredComponentInput(BaseModel):
    """One weighed ingredient line at start (adjustable plan line)."""

    raw_material_item_id: UUID
    quantity_used: Decimal = Field(gt=Decimal("0"))


class RunStartRequest(BaseModel):
    """Start a pending run: deduct the weighed ingredients.

    Omit ``components`` and the snapshotted plan is weighed exactly as
    written; supply it (full recipe coverage, leading line included and
    equal to ``leading_quantity_used``) to record what was actually on
    the scale. Output is NOT stocked — that happens at publish.
    """

    leading_item_id: UUID
    leading_quantity_used: Decimal = Field(gt=Decimal("0"))
    components: list[RunMeasuredComponentInput] | None = Field(default=None, min_length=1)

    @model_validator(mode="after")
    def _leading_matches_override(self) -> RunStartRequest:
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


class RunCompleteRequest(BaseModel):
    """Finish an in-progress run: what cooking actually produced.

    ``waste_reason`` is the kitchen's own words for lost stock
    (spillage, burning, over-portioning) — optional, kept on the run and
    carried onto the published history event for loss tracking.
    """

    actual_output_quantity: Decimal = Field(gt=Decimal("0"))
    waste_reason: str | None = Field(default=None, max_length=500)


class RunComponentRead(BaseModel):
    """One snapshotted plan line with its measured outcome."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    production_run_id: UUID
    raw_material_item_id: UUID
    raw_material_name: str
    raw_material_unit: str
    planned_quantity: Decimal
    measured_quantity: Decimal | None = None


class RunRead(BaseModel):
    """A scheduled batch with its lifecycle state.

    Yield fields are populated once the actual is known (completed):
    the goal is always the run target, the verdict follows the run's
    tolerance band. ``published_at`` null means the output is not in
    stock yet — Tab 3's Publish button commits it.
    """

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    business_id: UUID
    store_id: UUID
    recipe_id: UUID
    recipe_name: str
    sellable_item_id: UUID
    sellable_item_name: str
    target_output_quantity: Decimal
    status: str
    leading_component_item_id: UUID | None = None
    yield_tolerance_percent: Decimal
    actual_output_quantity: Decimal | None = None
    waste_reason: str | None = None
    yield_goal_quantity: Decimal
    yield_variance: Decimal | None = None
    yield_variance_percent: Decimal | None = None
    yield_status: YieldStatus | None = None
    published_at: datetime | None = None
    # True when this batch was stopped (items put back).
    cancel_reason: str | None = None
    cancelled_at: datetime | None = None
    created_by: UUID | None = None
    started_at: datetime | None = None
    completed_at: datetime | None = None
    created_at: datetime
    updated_at: datetime
    components: list[RunComponentRead] = []
