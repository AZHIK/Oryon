"""SQLModel table=True models for Oryon Foods POS Service.

Each model defined here inherits from SQLModel and has table=True,
meaning it maps to a Postgres table.

Import all models here so SQLModel.metadata is complete for Alembic.
"""

from app.models.couriers import Courier
from app.models.customers import Customer
from app.models.finance import (
    ExpenseCategory,
    FinanceAttachment,
    IncomeCategory,
    OtherExpense,
    OtherIncome,
)
from app.models.pos import (
    DeliveryStatus,
    OrderType,
    PaymentMethod,
    Sale,
    SaleLineItem,
    SaleStatus,
)

__all__ = [
    "Courier",
    "Customer",
    "DeliveryStatus",
    "OrderType",
    "ExpenseCategory",
    "FinanceAttachment",
    "IncomeCategory",
    "OtherExpense",
    "OtherIncome",
    "PaymentMethod",
    "Sale",
    "SaleLineItem",
    "SaleStatus",
]
