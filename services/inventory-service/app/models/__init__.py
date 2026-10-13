"""SQLModel table=True models for FoodLink Inventory Service.

Each model defined here inherits from SQLModel and has table=True,
meaning it maps to a Postgres table.

Import all models here so SQLModel.metadata is complete for Alembic.
"""

from app.models.categories import Category
from app.models.inventory import (
    ActorType,
    Item,
    ItemType,
    MovementType,
    ProcessedEvent,
    ProductionEvent,
    ProductionEventComponent,
    Recipe,
    RecipeComponent,
    StockLevel,
    StockMovement,
)
from app.models.purchases import (
    GoodsReceipt,
    GoodsReceiptLine,
    PurchaseOrder,
    PurchaseOrderLine,
    PurchaseOrderStatus,
)
from app.models.reorders import Reorder, ReorderStatus
from app.models.requisition import (
    AssignmentSource,
    MessageChannel,
    MessageDirection,
    MessageStatus,
    Requisition,
    RequisitionLine,
    SupplierItem,
    SupplierMessage,
)
from app.models.suppliers import Supplier
from app.models.units import Unit
from app.models.whatsapp import WhatsAppConnection, WhatsAppConnectionStatus

__all__ = [
    "ActorType",
    "Category",
    "GoodsReceipt",
    "GoodsReceiptLine",
    "PurchaseOrder",
    "PurchaseOrderLine",
    "PurchaseOrderStatus",
    "Item",
    "ItemType",
    "MovementType",
    "ProcessedEvent",
    "ProductionEvent",
    "ProductionEventComponent",
    "Recipe",
    "RecipeComponent",
    "Reorder",
    "ReorderStatus",
    "AssignmentSource",
    "MessageChannel",
    "MessageDirection",
    "MessageStatus",
    "Requisition",
    "RequisitionLine",
    "SupplierItem",
    "SupplierMessage",
    "StockLevel",
    "StockMovement",
    "Supplier",
    "Unit",
    "WhatsAppConnection",
    "WhatsAppConnectionStatus",
]
