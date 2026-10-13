"""Line-item schemas for POS sales.

``SaleLineItemInput`` is the client-submitted shape within a sale sync.
``SaleLineItemRead`` is the full server-side representation with computed
fields (id, sale_id, line_total).
"""

from __future__ import annotations

from decimal import Decimal
from uuid import UUID

from pydantic import BaseModel, Field


class SaleLineItemInput(BaseModel):
    """A single line item within a submitted sale.

    ``quantity`` and ``unit_price`` must both be strictly positive — a
    zero-quantity line item is meaningless, and a negative one is nearly
    always a client bug worth rejecting early.

    ``unit_cost`` is the per-unit production cost snapshot at sale time
    (the recipe cost at current grocery prices when the ticket closed).
    Optional so older clients keep syncing; stored frozen for profit
    history while live recipe costs keep moving.
    """

    item_id: UUID
    quantity: Decimal = Field(gt=Decimal("0"))
    unit_price: Decimal = Field(gt=Decimal("0"))
    discount_amount: Decimal = Field(default=Decimal("0"), ge=Decimal("0"))
    unit_cost: Decimal | None = Field(default=None, ge=Decimal("0"))


class SaleLineItemRead(SaleLineItemInput):
    """Full line-item representation for reads.

    Adds server-assigned fields (``id``, ``sale_id``) and the computed
    ``line_total`` which is persisted alongside the input fields.
    """

    id: UUID
    sale_id: UUID
    line_total: Decimal
