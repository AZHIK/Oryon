"""Schemas for Recipe / RecipeComponent (Stage 1: Recipe CRUD + batch formulas).

A recipe is a bill-of-materials for one sellable item — "Pilau = 200g rice
+ 100g meat + 20ml oil + 30g onions". Quantities are expressed in the raw
material item's own unit (the unit the stockroom counts it in), so no unit
conversion is part of this stage.

BATCH FORMULA SEMANTICS: component quantities are totals for the recipe's
``target_yield_quantity`` (e.g. "10kg rice for 50 portions"). Per-unit
math (production ratios, cost per plate) divides by the target yield; a
target of 1 reproduces the original per-unit recipe exactly.

Update semantics are full-replace, not partial-patch: ``RecipeUpdate``
carries a complete component list and the endpoint deletes-then-inserts it.
A partial "add/remove one line" patch invites lost-update races between two
editors and complicates validation (e.g. "remove the last line" must still
be rejected as an empty recipe) — replace-the-set is the simplest correct
shape, matching how the owner thinks about a recipe card.
"""

from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class RecipeComponentInput(BaseModel):
    """One ingredient line on a create/update payload.

    ``quantity_required`` is the TOTAL amount of the raw material for the
    recipe's target yield (e.g. "10kg rice for 50 portions"), in the raw
    material's own unit. Strictly positive — a zero or negative ingredient
    line is meaningless.
    """

    raw_material_item_id: UUID
    quantity_required: Decimal = Field(gt=Decimal("0"))


class RecipeCreate(BaseModel):
    """Create a recipe, optionally for a sellable item.

    ``sellable_item_id`` may be omitted to define a standalone formula
    before its menu item exists (linked later via ``POST /recipes/{id}/link``).
    ``name`` defaults to the sellable item's own name when omitted — but a
    standalone recipe has no sellable to default from, so ``name`` is
    required when ``sellable_item_id`` is omitted. At least one component is
    required — a recipe with zero ingredients is meaningless and is rejected
    here, not at the database. ``target_yield_quantity`` sizes the batch the
    component totals are written for (1 = per-unit).
    """

    sellable_item_id: UUID | None = None
    name: str | None = Field(default=None, max_length=255)
    category: str | None = Field(default=None, max_length=50)
    target_yield_quantity: Decimal = Field(default=Decimal("1"), gt=Decimal("0"))
    target_yield_unit: str = Field(default="portions", max_length=50)
    components: list[RecipeComponentInput] = Field(min_length=1)


class RecipeLink(BaseModel):
    """Link a standalone recipe to its sellable item (set-once, never moved)."""

    sellable_item_id: UUID


class RecipeUpdate(BaseModel):
    """Replace a recipe's component list (full set) and optionally rename it.

    ``components`` is required and replaces the stored set entirely — lines
    absent from the payload are deleted. ``None`` fields keep their stored
    values; pass a value to change them. When the target yield changes, the
    payload components must already be totals for the NEW yield (the server
    does not rescale — silently rescaling would corrupt recipes whose
    editor only meant to fix a typo).
    """

    name: str | None = Field(default=None, max_length=255)
    category: str | None = Field(default=None, max_length=50)
    target_yield_quantity: Decimal | None = Field(default=None, gt=Decimal("0"))
    target_yield_unit: str | None = Field(default=None, max_length=50)
    components: list[RecipeComponentInput] = Field(min_length=1)


class RecipeComponentRead(BaseModel):
    """One stored ingredient line with resolved item details.

    IDs alone are not enough for the owner reading a recipe card — the read
    resolves the raw material's name and unit code ("200g Rice", not a
    ``raw_material_item_id``). ``raw_material_unit`` is ``""`` when the item
    has no unit assigned (nullable FK server-side), mirroring the stock-level
    read convention in ``reports.py``.
    """

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    recipe_id: UUID
    raw_material_item_id: UUID
    raw_material_name: str
    raw_material_unit: str
    quantity_required: Decimal
    # Per-unit share (batch total ÷ recipe target yield) — what one plate
    # actually consumes. Resolved server-side so clients never divide.
    quantity_per_unit: Decimal
    # Line cost at current raw material prices (null when the raw item has
    # no unit_cost set — unknown, not zero; see ``cost_complete``).
    line_cost: Decimal | None = None


class RecipeRead(BaseModel):
    """A recipe header with its full resolved component list.

    ``total_cost`` is the batch cost at current raw material prices;
    ``cost_per_unit`` divides it by the target yield. ``cost_complete`` is
    False when any ingredient lacks a unit_cost — the totals then cover
    only the priced lines and understate the truth.
    """

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    business_id: UUID
    sellable_item_id: UUID | None = None
    sellable_item_name: str | None = None
    name: str
    category: str | None = None
    target_yield_quantity: Decimal
    target_yield_unit: str
    total_cost: Decimal
    cost_per_unit: Decimal
    cost_complete: bool
    created_at: datetime
    updated_at: datetime
    components: list[RecipeComponentRead] = []
