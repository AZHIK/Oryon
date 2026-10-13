"""Schemas for inventory analytics endpoints (waste, production, valuation).

Same read-only conventions as ``reports.py``: business-scoped, computed in
SQL, and denormalized just enough (item names, unit codes) that callers
render without a second round-trip per row.
"""

from __future__ import annotations

from decimal import Decimal
from uuid import UUID

from pydantic import BaseModel


class WasteLine(BaseModel):
    """One item's recorded waste in the window — quantity and cost.

    ``cost_wasted`` uses each movement's frozen ``unit_cost`` where present
    (period-appropriate basis); legacy rows without a snapshot fall back to
    the item's current ``unit_cost`` and set ``cost_estimated``.
    """

    item_id: UUID
    item_name: str
    item_unit: str
    quantity_wasted: Decimal
    cost_wasted: Decimal
    cost_estimated: bool = False


class WasteSummaryResponse(BaseModel):
    lines: list[WasteLine]
    total_cost_wasted: Decimal
    # True when any line used the current-cost fallback (legacy rows or
    # items with no basis on file) — history is then soft, not frozen.
    estimated: bool = False


class IngredientConsumption(BaseModel):
    raw_material_item_id: UUID
    raw_material_name: str
    raw_material_unit: str
    quantity_consumed: Decimal


class ProductionSummaryResponse(BaseModel):
    """Production runs in the window, with the portioning signal kept.

    ``suggested_total`` vs ``actual_total`` is the same gap the event
    payloads carry per run, summed here so the report answers "are we
    over-portioning" at a glance. Positive ``over_portioned_by`` means
    more was stocked than recipes suggested.
    """

    runs: int
    suggested_total: Decimal
    actual_total: Decimal
    over_portioned_by: Decimal
    ingredients_consumed: list[IngredientConsumption]


class StockValuationLine(BaseModel):
    category: str | None
    item_count: int
    total_value: Decimal


class StockValuationResponse(BaseModel):
    total_value: Decimal
    lines: list[StockValuationLine]


# ── Product purchase report: what was bought, from whom ───────────────────


class ProductPurchaseLine(BaseModel):
    """One item+supplier bucket of purchasing.

    Maps to the on-screen **Product Purchase Report**. Ordered qty comes
    from the (qty-only) PO; received qty and cost come from GRN actuals.
    """

    item_id: UUID
    item_name: str
    item_unit: str
    supplier_id: UUID | None
    supplier_name: str
    quantity_ordered: Decimal
    quantity_received: Decimal
    total_cost: Decimal


class ProductPurchaseResponse(BaseModel):
    lines: list[ProductPurchaseLine]
    total_cost: Decimal


# ── Supplier purchases: received value per supplier ──────────────────────


class SupplierPurchaseLine(BaseModel):
    """One supplier's received purchase value.

    Supplier leg of the **Supplier & Customer Report** (the customer-spend
    leg lives in POS Service's ``customer-spend`` report). POs are qty-only
    with no payables ledger, so ``total_received`` is the received value
    (Σ receipt qty × receipt unit_cost), not an order-time estimate.
    """

    supplier_id: UUID
    supplier_name: str
    orders_count: int
    total_received: Decimal


class SupplierPurchaseResponse(BaseModel):
    lines: list[SupplierPurchaseLine]


# ── Stock adjustment report: manual corrections business-wide ─────────────


class StockAdjustmentLine(BaseModel):
    """One manual-adjustment movement with item context.

    Maps to the on-screen **Stock Adjustment Report**. The existing
    per-item ``movements`` endpoint stays; this is the business-wide view
    the report screen needs.
    """

    id: UUID
    item_id: UUID
    item_name: str
    store_id: UUID
    quantity_delta: Decimal
    reason: str | None = None
    actor_id: UUID | None = None
    created_at: str


class StockAdjustmentResponse(BaseModel):
    lines: list[StockAdjustmentLine]
    total: int


# ── Lot report: goods receipts as traceable lots ──────────────────────────


class LotLine(BaseModel):
    """One goods receipt treated as a lot.

    Maps to the on-screen **Lot Report**. ``lot_no`` defaults to the GRN
    number; per-batch ``lot_no``/``expiry_date`` on the receipt line are
    surfaced when present (see ``p8q9r0s1t2u3`` migration). ``unit_cost`` is
    the frozen receipt cost for the lot; ``total_cost`` is qty × cost.
    """

    goods_receipt_id: UUID
    lot_no: str
    item_id: UUID
    item_name: str
    quantity_received: Decimal
    unit_cost: Decimal
    total_cost: Decimal
    supplier_name: str | None = None
    expiry_date: str | None = None
    received_at: str


class LotReportResponse(BaseModel):
    lines: list[LotLine]


# ── Stock expiry report: lots expiring in the window ──────────────────────


class ExpiryLine(BaseModel):
    """One receipt line with an expiry date inside the window.

    Maps to the on-screen **Stock Expiry Report**. Lines without an
    expiry date never appear here — unknown expiry is not "expiring".
    """

    goods_receipt_id: UUID
    lot_no: str
    item_id: UUID
    item_name: str
    quantity_received: Decimal
    unit_cost: Decimal
    total_cost: Decimal
    expiry_date: str
    received_at: str


class ExpiryReportResponse(BaseModel):
    lines: list[ExpiryLine]


# ── Activity log: recent stock movements as the audit trail ────────────────


class ActivityLogLine(BaseModel):
    """One auditable event (any movement type), newest first.

    Maps to the on-screen **Activity Log** (inventory leg — sales-side
    activity lives in POS Service's sales list).
    """

    id: UUID
    item_id: UUID
    item_name: str
    movement_type: str
    quantity_delta: Decimal
    store_id: UUID
    actor_id: UUID | None = None
    reason: str | None = None
    created_at: str


class ActivityLogResponse(BaseModel):
    lines: list[ActivityLogLine]
    total: int


# ── Cost history: immutable receipt lots as the price record ─────────────


class CostHistoryLine(BaseModel):
    """One receipt lot's frozen cost — the answer to "what did X cost in March".

    Sourced from the append-only ``GoodsReceiptLine`` rows (never overwritten,
    unlike ``Item.unit_cost`` / ``SupplierItem.price``), so historical P&L can
    be reconstructed from scratch.
    """

    goods_receipt_id: UUID
    grn_number: str
    lot_no: str
    item_id: UUID
    item_name: str
    supplier_name: str | None = None
    quantity_received: Decimal
    unit_cost: Decimal
    total_cost: Decimal
    received_at: str


class CostHistoryResponse(BaseModel):
    lines: list[CostHistoryLine]
