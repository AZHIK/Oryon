"""SQLModel table=False / Pydantic schemas (API request/response shapes).

Available modules:
    items        — ItemBase, ItemCreate, ItemUpdate, ItemRead, ItemListFilters
    stock_levels — StockLevelRead (read-only, never written directly)
    movements    — StockMovementRead (read-only — immutable audit trail)
    operations   — AdjustStockRequest, RecordWasteRequest, TransferStockRequest
"""

from app.schemas.items import (
    ItemBase,
    ItemCreate,
    ItemListFilters,
    ItemRead,
    ItemUpdate,
)
from app.schemas.movements import StockMovementRead
from app.schemas.operations import (
    AdjustStockRequest,
    RecordWasteRequest,
    TransferStockRequest,
)
from app.schemas.stock_levels import StockLevelRead

__all__ = [
    "AdjustStockRequest",
    "ItemBase",
    "ItemCreate",
    "ItemListFilters",
    "ItemRead",
    "ItemUpdate",
    "RecordWasteRequest",
    "StockLevelRead",
    "StockMovementRead",
    "TransferStockRequest",
]
