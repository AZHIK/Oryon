"""Tests for POS data models — schema constraints and data integrity."""

from datetime import UTC, datetime
from decimal import Decimal
from uuid import uuid4

import pytest
from sqlalchemy.ext.asyncio import AsyncSession
from sqlmodel import select

from app.models.pos import PaymentMethod, Sale, SaleLineItem, SaleStatus


class TestSaleModel:
    """Sale model — required fields, uniqueness, decimal precision."""

    async def test_create_sale_with_required_fields(self, db_session: AsyncSession) -> None:
        sale = Sale(
            business_id=uuid4(),
            store_id=uuid4(),
            client_sale_id="req-fields-test",
            status=SaleStatus.COMPLETED,
            subtotal=Decimal("100.00"),
            total=Decimal("115.00"),
            payment_method=PaymentMethod.CASH,
            occurred_at=datetime.now(UTC),
        )
        db_session.add(sale)
        await db_session.commit()
        await db_session.refresh(sale)
        assert sale.id is not None
        assert sale.created_at is not None
        assert sale.discount_amount == Decimal("0")
        assert sale.tax_amount == Decimal("0")
        assert sale.is_time_suspect is False

    async def test_client_sale_id_uniqueness(self, db_session: AsyncSession) -> None:
        sale1 = Sale(
            business_id=uuid4(),
            store_id=uuid4(),
            client_sale_id="unique-test-id",
            status=SaleStatus.COMPLETED,
            subtotal=Decimal("50.00"),
            total=Decimal("50.00"),
            payment_method=PaymentMethod.CASH,
            occurred_at=datetime.now(UTC),
        )
        db_session.add(sale1)
        await db_session.commit()

        sale2 = Sale(
            business_id=uuid4(),
            store_id=uuid4(),
            client_sale_id="unique-test-id",
            status=SaleStatus.COMPLETED,
            subtotal=Decimal("75.00"),
            total=Decimal("75.00"),
            payment_method=PaymentMethod.CARD,
            occurred_at=datetime.now(UTC),
        )
        db_session.add(sale2)
        with pytest.raises(Exception, match="unique|duplicate|already exists"):
            await db_session.commit()

    async def test_decimal_round_trip(self, db_session: AsyncSession) -> None:
        original = Sale(
            business_id=uuid4(),
            store_id=uuid4(),
            client_sale_id="decimal-rt",
            status=SaleStatus.COMPLETED,
            subtotal=Decimal("99.99"),
            discount_amount=Decimal("5.50"),
            tax_amount=Decimal("12.34"),
            total=Decimal("106.83"),
            payment_method=PaymentMethod.MOBILE_MONEY,
            occurred_at=datetime.now(UTC),
        )
        db_session.add(original)
        await db_session.commit()

        result = await db_session.exec(
            select(Sale).where(Sale.client_sale_id == "decimal-rt")
        )
        loaded = result.one()
        assert loaded.subtotal == Decimal("99.99")
        assert loaded.discount_amount == Decimal("5.50")
        assert loaded.tax_amount == Decimal("12.34")
        assert loaded.total == Decimal("106.83")

    async def test_voided_sale_round_trip(self, db_session: AsyncSession) -> None:
        now = datetime.now(UTC)
        sale = Sale(
            business_id=uuid4(),
            store_id=uuid4(),
            client_sale_id="voided-sale",
            status=SaleStatus.VOIDED,
            subtotal=Decimal("0.00"),
            total=Decimal("0.00"),
            payment_method=PaymentMethod.CASH,
            actor_id=uuid4(),
            occurred_at=now,
            voided_at=now,
            void_or_refund_reason="Cashier error",
        )
        db_session.add(sale)
        await db_session.commit()
        await db_session.refresh(sale)
        assert sale.status == SaleStatus.VOIDED
        assert sale.voided_at is not None
        assert sale.void_or_refund_reason == "Cashier error"


class TestSaleLineItemModel:
    """SaleLineItem model — FK enforcement, cross-service reference discipline."""

    async def test_create_line_item(self, db_session: AsyncSession) -> None:
        sale = Sale(
            business_id=uuid4(),
            store_id=uuid4(),
            client_sale_id="li-parent-sale",
            status=SaleStatus.COMPLETED,
            subtotal=Decimal("50.00"),
            total=Decimal("50.00"),
            payment_method=PaymentMethod.CASH,
            occurred_at=datetime.now(UTC),
        )
        db_session.add(sale)
        await db_session.commit()
        await db_session.refresh(sale)

        line_item = SaleLineItem(
            sale_id=sale.id,
            item_id=uuid4(),
            quantity=Decimal("2"),
            unit_price=Decimal("25.00"),
            line_total=Decimal("50.00"),
        )
        db_session.add(line_item)
        await db_session.commit()
        await db_session.refresh(line_item)
        assert line_item.id is not None
        assert line_item.discount_amount == Decimal("0")

    async def test_fk_enforced_nonexistent_sale(self, db_session: AsyncSession) -> None:
        line_item = SaleLineItem(
            sale_id=uuid4(),
            item_id=uuid4(),
            quantity=Decimal("1"),
            unit_price=Decimal("10.00"),
            line_total=Decimal("10.00"),
        )
        db_session.add(line_item)
        with pytest.raises(Exception):
            await db_session.commit()

    async def test_item_id_no_fk_constraint(self, db_session: AsyncSession) -> None:
        """item_id is a cross-service reference — no FK in this DB.

        A UUID that doesn't exist in any local table should be accepted,
        because Inventory Service owns item validation, not POS Service.
        """
        sale = Sale(
            business_id=uuid4(),
            store_id=uuid4(),
            client_sale_id="no-fk-item",
            status=SaleStatus.COMPLETED,
            subtotal=Decimal("30.00"),
            total=Decimal("30.00"),
            payment_method=PaymentMethod.OTHER,
            occurred_at=datetime.now(UTC),
        )
        db_session.add(sale)
        await db_session.commit()
        await db_session.refresh(sale)

        line_item = SaleLineItem(
            sale_id=sale.id,
            item_id=uuid4(),
            quantity=Decimal("3"),
            unit_price=Decimal("10.00"),
            line_total=Decimal("30.00"),
        )
        db_session.add(line_item)
        await db_session.commit()
        assert line_item.id is not None
