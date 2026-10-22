from __future__ import annotations

from datetime import UTC, datetime, timedelta
from decimal import Decimal
from unittest.mock import AsyncMock
from uuid import UUID, uuid4

import pytest
from sqlalchemy.ext.asyncio import AsyncSession
from sqlmodel import select

from app.core.config import get_settings
from app.models.pos import PaymentMethod, Sale, SaleLineItem, SaleStatus
from app.schemas.line_items import SaleLineItemInput
from app.schemas.sales import SaleSyncBatchRequest, SaleSyncInput, SyncResult
from app.schemas.void_refund import VoidRefundRequest
from app.services.sale_service import (
    InvalidSaleStateError,
    detect_time_drift,
    sync_sale_batch,
    void_or_refund_sale,
)

# ═══════════════════════════════════════════════════════════════════════
# detect_time_drift
# ═══════════════════════════════════════════════════════════════════════


class TestDetectTimeDrift:
    """Pure-function tests for clock-drift detection."""

    def test_past_beyond_threshold_is_suspect(self) -> None:
        now = datetime.now(UTC)
        assert detect_time_drift(now - timedelta(hours=49), now) is True

    def test_future_beyond_tolerance_is_suspect(self) -> None:
        now = datetime.now(UTC)
        assert detect_time_drift(now + timedelta(minutes=6), now) is True

    def test_within_past_threshold_is_clean(self) -> None:
        now = datetime.now(UTC)
        assert detect_time_drift(now - timedelta(hours=1), now) is False

    def test_exact_threshold_boundary_is_clean(self) -> None:
        now = datetime.now(UTC)
        assert detect_time_drift(now - timedelta(hours=48), now) is False

    def test_exact_future_tolerance_boundary_is_clean(self) -> None:
        now = datetime.now(UTC)
        assert detect_time_drift(now + timedelta(minutes=5), now) is False

    def test_uses_explicit_synced_at(self) -> None:
        synced_at = datetime(2025, 6, 15, 12, 0, 0, tzinfo=UTC)
        assert detect_time_drift(synced_at - timedelta(hours=49), synced_at) is True
        assert detect_time_drift(synced_at - timedelta(hours=1), synced_at) is False


# ═══════════════════════════════════════════════════════════════════════
# sync_sale_batch
# ═══════════════════════════════════════════════════════════════════════


def _sale_input(
    client_sale_id: str = "test-1",
    status: str = "completed",
    store_id: UUID | None = None,
    line_items: list[SaleLineItemInput] | None = None,
    discount_amount: Decimal = Decimal("0"),
    payment_method: str = "cash",
    occurred_at: datetime | None = None,
    void_or_refund_reason: str | None = None,
) -> SaleSyncInput:
    return SaleSyncInput(
        client_sale_id=client_sale_id,
        status=status,
        store_id=store_id or uuid4(),
        line_items=line_items or [
            SaleLineItemInput(
                item_id=uuid4(),
                quantity=Decimal("1"),
                unit_price=Decimal("10.00"),
            ),
        ],
        discount_amount=discount_amount,
        payment_method=payment_method,
        occurred_at=occurred_at or datetime.now(UTC),
        void_or_refund_reason=void_or_refund_reason,
    )


class TestSyncSaleBatch:
    """Service-layer tests for sync_sale_batch."""

    # ── Helpers ──────────────────────────────────────────────────────

    @staticmethod
    async def _sync(
        db_session: AsyncSession,
        business_id: UUID | None = None,
        actor_id: UUID | None = None,
        sales: list[SaleSyncInput] | None = None,
    ) -> tuple[AsyncMock, list[SyncResult]]:
        bid = business_id or uuid4()
        sales = sales or [_sale_input()]
        batch = SaleSyncBatchRequest(sales=sales)
        mock_publish = AsyncMock()
        response = await sync_sale_batch(
            db_session, bid, actor_id, batch, publish=mock_publish,
        )
        return mock_publish, response.results

    # ── New sale creation ────────────────────────────────────────────

    async def test_sync_creates_sale_and_line_items(self, db_session: AsyncSession) -> None:
        _, results = await self._sync(db_session)
        assert results[0].client_sale_id == "test-1"
        assert results[0].status == "created"

        sale = (
            await db_session.exec(
                select(Sale).where(Sale.client_sale_id == "test-1")
            )
        ).one()
        assert sale.subtotal == Decimal("10.00")
        assert sale.discount_amount == Decimal("0")
        assert sale.tax_amount == Decimal("0")
        assert sale.total == Decimal("10.00")
        assert sale.payment_method == PaymentMethod.CASH
        assert sale.is_time_suspect is False

        items = (
            await db_session.exec(
                select(SaleLineItem).where(SaleLineItem.sale_id == sale.id)
            )
        ).all()
        assert len(items) == 1
        assert items[0].line_total == Decimal("10.00")

    async def test_sync_with_discount_and_tax(self, db_session: AsyncSession) -> None:
        settings = get_settings()
        tax_rate = settings.default_tax_rate

        line_items = [
            SaleLineItemInput(
                item_id=uuid4(), quantity=Decimal("3"), unit_price=Decimal("4.50"),
            ),
        ]
        discount = Decimal("2.00")
        _, results = await self._sync(
            db_session,
            sales=[_sale_input(
                client_sale_id="tax-test",
                line_items=line_items,
                discount_amount=discount,
            )],
        )
        assert results[0].status == "created"

        sale = (
            await db_session.exec(
                select(Sale).where(Sale.client_sale_id == "tax-test")
            )
        ).one()
        expected_subtotal = Decimal("13.50")
        expected_tax = (expected_subtotal * tax_rate).quantize(Decimal("0.01"))
        expected_total = expected_subtotal - discount + expected_tax

        assert sale.subtotal == expected_subtotal
        assert sale.discount_amount == discount
        assert sale.tax_amount == expected_tax
        assert sale.total == expected_total

    async def test_sync_multiple_line_items(self, db_session: AsyncSession) -> None:
        item_id_a = uuid4()
        item_id_b = uuid4()
        line_items = [
            SaleLineItemInput(item_id=item_id_a, quantity=Decimal("2"), unit_price=Decimal("5.00")),
            SaleLineItemInput(item_id=item_id_b, quantity=Decimal("1"), unit_price=Decimal("7.50")),
        ]
        _, results = await self._sync(
            db_session,
            sales=[_sale_input(client_sale_id="multi-li", line_items=line_items)],
        )
        assert results[0].status == "created"

        sale = (
            await db_session.exec(
                select(Sale).where(Sale.client_sale_id == "multi-li")
            )
        ).one()
        assert sale.subtotal == Decimal("17.50")

        items = (
            await db_session.exec(
                select(SaleLineItem).where(SaleLineItem.sale_id == sale.id)
            )
        ).all()
        assert len(items) == 2
        totals_by_item = {str(i.item_id): i.line_total for i in items}
        assert totals_by_item[str(item_id_a)] == Decimal("10.00")
        assert totals_by_item[str(item_id_b)] == Decimal("7.50")

    # ── Idempotency ──────────────────────────────────────────────────

    async def test_idempotency_cross_batch(self, db_session: AsyncSession) -> None:
        _, first_results = await self._sync(db_session)
        assert first_results[0].status == "created"

        batch = SaleSyncBatchRequest(sales=[_sale_input()])
        mock = AsyncMock()
        response = await sync_sale_batch(db_session, uuid4(), None, batch, publish=mock)
        assert response.results[0].status == "duplicate"

        sales = (
            await db_session.exec(
                select(Sale).where(Sale.client_sale_id == "test-1")
            )
        ).all()
        assert len(sales) == 1

    async def test_idempotency_within_batch(self, db_session: AsyncSession) -> None:
        loc_id = uuid4()
        sales = [
            _sale_input(client_sale_id="dup-key", store_id=loc_id),
            _sale_input(
                client_sale_id="dup-key",
                store_id=uuid4(),
                payment_method="card",
            ),
        ]
        _, results = await self._sync(db_session, sales=sales)
        assert results[0].status == "created"
        assert results[1].status == "duplicate"

        sales_rows = (
            await db_session.exec(
                select(Sale).where(Sale.client_sale_id == "dup-key")
            )
        ).all()
        assert len(sales_rows) == 1

    # ── Partial success ──────────────────────────────────────────────

    async def test_partial_success_one_fails_one_succeeds(self, db_session: AsyncSession) -> None:
        valid = _sale_input(client_sale_id="ok-1")
        invalid = _sale_input(
            client_sale_id="fail-1",
            status="voided",
            void_or_refund_reason="will-be-removed",
        )
        # Build the batch with validated SaleSyncInput objects, then bypass
        # Pydantic's per-field validation by mutating the list element directly
        # so the SaleSyncBatchRequest stores the modified input as-is.
        batch = SaleSyncBatchRequest(sales=[valid, invalid])
        batch.sales[1].void_or_refund_reason = None

        bid = uuid4()
        mock_publish = AsyncMock()
        response = await sync_sale_batch(
            db_session, bid, None, batch, publish=mock_publish,
        )
        results = response.results

        assert results[0].client_sale_id == "ok-1"
        assert results[0].status == "created"
        assert results[1].client_sale_id == "fail-1"
        assert results[1].status == "failed"

        valid_sale = (
            await db_session.exec(
                select(Sale).where(Sale.client_sale_id == "ok-1")
            )
        ).first()
        assert valid_sale is not None

        failed_sale = (
            await db_session.exec(
                select(Sale).where(Sale.client_sale_id == "fail-1")
            )
        ).first()
        assert failed_sale is None

    # ── Pre-voided / pre-refunded sales ──────────────────────────────

    async def test_pre_voided_sale_creates_row(self, db_session: AsyncSession) -> None:
        now = datetime.now(UTC)
        _, results = await self._sync(
            db_session,
            sales=[_sale_input(
                client_sale_id="voided-once",
                status="voided",
                occurred_at=now,
                void_or_refund_reason="Cashier pressed wrong button",
            )],
        )
        assert results[0].status == "created"

        sale = (
            await db_session.exec(
                select(Sale).where(Sale.client_sale_id == "voided-once")
            )
        ).one()
        assert sale.status == SaleStatus.VOIDED
        assert sale.voided_at is not None
        assert sale.void_or_refund_reason == "Cashier pressed wrong button"

    async def test_pre_refunded_sale_creates_row(self, db_session: AsyncSession) -> None:
        now = datetime.now(UTC)
        _, results = await self._sync(
            db_session,
            sales=[_sale_input(
                client_sale_id="refunded-once",
                status="refunded",
                occurred_at=now,
                void_or_refund_reason="Customer changed mind",
            )],
        )
        assert results[0].status == "created"

        sale = (
            await db_session.exec(
                select(Sale).where(Sale.client_sale_id == "refunded-once")
            )
        ).one()
        assert sale.status == SaleStatus.REFUNDED
        assert sale.refunded_at is not None
        assert sale.void_or_refund_reason == "Customer changed mind"

    # ── Event publishing ─────────────────────────────────────────────

    async def test_completed_sale_publishes_sale_completed(self, db_session: AsyncSession) -> None:
        item_id = uuid4()
        sales_input = _sale_input(
            client_sale_id="event-test",
            line_items=[SaleLineItemInput(
                item_id=item_id, quantity=Decimal("2"), unit_price=Decimal("5.00"),
            )],
        )
        mock_publish, results = await self._sync(
            db_session, sales=[sales_input], actor_id=None,
        )
        assert results[0].status == "created"

        sale = (
            await db_session.exec(
                select(Sale).where(Sale.client_sale_id == "event-test")
            )
        ).one()

        mock_publish.assert_awaited_once()
        call_args = mock_publish.await_args
        assert call_args is not None
        event_name, payload = call_args.args
        assert event_name == "sale.completed"
        assert payload["event_id"] == str(sale.id)
        assert payload["sale_id"] == str(sale.id)
        assert payload["business_id"] == str(sale.business_id)
        assert payload["store_id"] == str(sale.store_id)
        assert payload["line_items"] == [
            {"item_id": str(item_id), "quantity": "2"},
        ]

    async def test_pre_voided_sale_does_not_publish_sale_completed(
        self, db_session: AsyncSession,
    ) -> None:
        mock_publish, results = await self._sync(
            db_session,
            sales=[_sale_input(
                client_sale_id="no-event-void",
                status="voided",
                void_or_refund_reason="Test void",
            )],
        )
        assert results[0].status == "created"
        mock_publish.assert_not_awaited()

    async def test_pre_refunded_sale_does_not_publish_sale_completed(
        self, db_session: AsyncSession,
    ) -> None:
        mock_publish, results = await self._sync(
            db_session,
            sales=[_sale_input(
                client_sale_id="no-event-refund",
                status="refunded",
                void_or_refund_reason="Test refund",
            )],
        )
        assert results[0].status == "created"
        mock_publish.assert_not_awaited()

    async def test_event_id_is_stable_deterministic(self, db_session: AsyncSession) -> None:
        """event_id must equal str(sale.id) for Inventory Service idempotency."""
        mock_publish, results = await self._sync(db_session)
        assert results[0].status == "created"

        sale = (
            await db_session.exec(
                select(Sale).where(Sale.client_sale_id == "test-1")
            )
        ).one()

        mock_publish.assert_awaited_once()
        payload = mock_publish.await_args.args[1]  # type: ignore[union-attr]
        assert payload["event_id"] == str(sale.id)

    # ── Time drift on sale ───────────────────────────────────────────

    async def test_time_drift_marked_on_past_occurred_at(self, db_session: AsyncSession) -> None:
        far_past = datetime.now(UTC) - timedelta(hours=49)
        _, results = await self._sync(
            db_session,
            sales=[_sale_input(client_sale_id="drift-past", occurred_at=far_past)],
        )
        assert results[0].status == "created"

        sale = (
            await db_session.exec(
                select(Sale).where(Sale.client_sale_id == "drift-past")
            )
        ).one()
        assert sale.is_time_suspect is True

    async def test_time_drift_marked_on_future_occurred_at(self, db_session: AsyncSession) -> None:
        far_future = datetime.now(UTC) + timedelta(minutes=6)
        _, results = await self._sync(
            db_session,
            sales=[_sale_input(client_sale_id="drift-future", occurred_at=far_future)],
        )
        assert results[0].status == "created"

        sale = (
            await db_session.exec(
                select(Sale).where(Sale.client_sale_id == "drift-future")
            )
        ).one()
        assert sale.is_time_suspect is True

    async def test_normal_occurred_at_not_marked_drift(self, db_session: AsyncSession) -> None:
        recent = datetime.now(UTC) - timedelta(hours=1)
        _, results = await self._sync(
            db_session,
            sales=[_sale_input(client_sale_id="drift-clean", occurred_at=recent)],
        )
        assert results[0].status == "created"

        sale = (
            await db_session.exec(
                select(Sale).where(Sale.client_sale_id == "drift-clean")
            )
        ).one()
        assert sale.is_time_suspect is False


# ═══════════════════════════════════════════════════════════════════════
# void_or_refund_sale
# ═══════════════════════════════════════════════════════════════════════


class TestVoidOrRefundSale:
    """Service-layer tests for void_or_refund_sale."""

    @staticmethod
    async def _do_void_or_refund(
        db_session: AsyncSession,
        business_id: UUID,
        sale_id: UUID,
        new_status: str = "voided",
        client_action_id: str | None = None,
    ) -> tuple[AsyncMock, Sale]:
        mock_publish = AsyncMock()
        sale = await void_or_refund_sale(
            db_session,
            business_id,
            sale_id,
            actor_id=None,
            request=VoidRefundRequest(
                client_action_id=client_action_id or f"act-{uuid4()}",
                new_status=new_status,
                reason="Test reason",
            ),
            publish=mock_publish,
        )
        return mock_publish, sale

    # ── Void completed sale ──────────────────────────────────────────

    async def test_void_completed_sale_updates_status(self, db_session: AsyncSession) -> None:
        item_id = uuid4()
        bid = uuid4()
        await sync_sale_batch(
            db_session,
            bid,
            None,
            SaleSyncBatchRequest(sales=[_sale_input(
                client_sale_id="void-test-1",
                line_items=[
                    SaleLineItemInput(
                        item_id=item_id, quantity=Decimal("2"), unit_price=Decimal("5.00"),
                    ),
                ],
            )]),
            publish=AsyncMock(),
        )
        sale = (
            await db_session.exec(
                select(Sale).where(Sale.client_sale_id == "void-test-1")
            )
        ).one()
        assert sale.status == SaleStatus.COMPLETED

        mock_publish, updated = await self._do_void_or_refund(
            db_session, bid, sale.id,
            new_status="voided", client_action_id="void-test-act-1",
        )
        assert updated.status == SaleStatus.VOIDED
        assert updated.voided_at is not None
        assert updated.void_or_refund_reason == "Test reason"
        assert updated.void_client_action_id == "void-test-act-1"

        # Verify persistence
        reloaded = (
            await db_session.exec(select(Sale).where(Sale.id == sale.id))
        ).one()
        assert reloaded.status == SaleStatus.VOIDED

    async def test_void_publishes_sale_voided_with_correct_payload(
        self, db_session: AsyncSession,
    ) -> None:
        item_id = uuid4()
        bid = uuid4()
        await sync_sale_batch(
            db_session,
            bid,
            None,
            SaleSyncBatchRequest(sales=[_sale_input(
                client_sale_id="void-pub-test",
                line_items=[
                    SaleLineItemInput(
                        item_id=item_id, quantity=Decimal("2"), unit_price=Decimal("5.00"),
                    ),
                ],
            )]),
            publish=AsyncMock(),
        )
        sale = (
            await db_session.exec(
                select(Sale).where(Sale.client_sale_id == "void-pub-test")
            )
        ).one()

        mock_publish, updated = await self._do_void_or_refund(
            db_session, bid, sale.id,
            new_status="voided", client_action_id="void-pub-act",
        )

        # Verify sale.voided was published
        sale_voided_calls = [
            c for c in mock_publish.await_args_list
            if c.args[0] == "sale.voided"
        ]
        assert len(sale_voided_calls) == 1
        payload = sale_voided_calls[0].args[1]
        assert payload["event_id"] == "void-pub-act"
        assert payload["sale_id"] == str(sale.id)
        assert payload["business_id"] == str(bid)
        assert payload["line_items"] == [
            {"item_id": str(item_id), "quantity": "2"},
        ]

    async def test_void_publishes_audit_recorded(
        self, db_session: AsyncSession,
    ) -> None:
        bid = uuid4()
        await sync_sale_batch(
            db_session,
            bid,
            None,
            SaleSyncBatchRequest(sales=[_sale_input(
                client_sale_id="void-audit-test",
            )]),
            publish=AsyncMock(),
        )
        sale = (
            await db_session.exec(
                select(Sale).where(Sale.client_sale_id == "void-audit-test")
            )
        ).one()

        mock_publish, _ = await self._do_void_or_refund(
            db_session, bid, sale.id,
            new_status="voided", client_action_id="void-audit-act",
        )

        audit_calls = [
            c for c in mock_publish.await_args_list
            if c.args[0] == "audit.recorded"
        ]
        assert len(audit_calls) == 1
        payload = audit_calls[0].args[1]
        assert payload["action"] == "sale.voided"

    # ── Refund completed sale ────────────────────────────────────────

    async def test_refund_completed_sale_updates_status(self, db_session: AsyncSession) -> None:
        bid = uuid4()
        await sync_sale_batch(
            db_session,
            bid,
            None,
            SaleSyncBatchRequest(sales=[_sale_input(
                client_sale_id="ref-test-1",
            )]),
            publish=AsyncMock(),
        )
        sale = (
            await db_session.exec(
                select(Sale).where(Sale.client_sale_id == "ref-test-1")
            )
        ).one()
        assert sale.status == SaleStatus.COMPLETED

        mock_publish, updated = await self._do_void_or_refund(
            db_session, bid, sale.id,
            new_status="refunded", client_action_id="ref-test-act-1",
        )
        assert updated.status == SaleStatus.REFUNDED
        assert updated.refunded_at is not None
        assert updated.void_or_refund_reason == "Test reason"
        assert updated.refund_client_action_id == "ref-test-act-1"

        reloaded = (
            await db_session.exec(select(Sale).where(Sale.id == sale.id))
        ).one()
        assert reloaded.status == SaleStatus.REFUNDED

    async def test_refund_publishes_sale_refunded_with_correct_payload(
        self, db_session: AsyncSession,
    ) -> None:
        item_id = uuid4()
        bid = uuid4()
        await sync_sale_batch(
            db_session,
            bid,
            None,
            SaleSyncBatchRequest(sales=[_sale_input(
                client_sale_id="ref-pub-test",
                line_items=[
                    SaleLineItemInput(
                        item_id=item_id, quantity=Decimal("1"), unit_price=Decimal("15.00"),
                    ),
                ],
            )]),
            publish=AsyncMock(),
        )
        sale = (
            await db_session.exec(
                select(Sale).where(Sale.client_sale_id == "ref-pub-test")
            )
        ).one()

        mock_publish, _ = await self._do_void_or_refund(
            db_session, bid, sale.id,
            new_status="refunded", client_action_id="ref-pub-act",
        )

        refund_calls = [
            c for c in mock_publish.await_args_list
            if c.args[0] == "sale.refunded"
        ]
        assert len(refund_calls) == 1
        payload = refund_calls[0].args[1]
        assert payload["event_id"] == "ref-pub-act"
        assert payload["sale_id"] == str(sale.id)
        assert payload["line_items"] == [
            {"item_id": str(item_id), "quantity": "1"},
        ]

    async def test_refund_publishes_audit_recorded(
        self, db_session: AsyncSession,
    ) -> None:
        bid = uuid4()
        await sync_sale_batch(
            db_session,
            bid,
            None,
            SaleSyncBatchRequest(sales=[_sale_input(
                client_sale_id="ref-audit-test",
            )]),
            publish=AsyncMock(),
        )
        sale = (
            await db_session.exec(
                select(Sale).where(Sale.client_sale_id == "ref-audit-test")
            )
        ).one()

        mock_publish, _ = await self._do_void_or_refund(
            db_session, bid, sale.id,
            new_status="refunded", client_action_id="ref-audit-act",
        )

        audit_calls = [
            c for c in mock_publish.await_args_list
            if c.args[0] == "audit.recorded"
        ]
        assert len(audit_calls) == 1
        payload = audit_calls[0].args[1]
        assert payload["action"] == "sale.refunded"

    # ── State guards ─────────────────────────────────────────────────

    async def test_void_refund_rejects_already_voided(self, db_session: AsyncSession) -> None:
        bid = uuid4()
        await sync_sale_batch(
            db_session,
            bid,
            None,
            SaleSyncBatchRequest(sales=[_sale_input(
                client_sale_id="already-voided",
            )]),
            publish=AsyncMock(),
        )
        sale = (
            await db_session.exec(
                select(Sale).where(Sale.client_sale_id == "already-voided")
            )
        ).one()

        # First void succeeds
        await void_or_refund_sale(
            db_session,
            bid, sale.id,
            None,
            VoidRefundRequest(
                client_action_id="act-already-1", new_status="voided",
                reason="First void",
            ),
            publish=AsyncMock(),
        )

        # Second void raises InvalidSaleStateError
        with pytest.raises(InvalidSaleStateError):
            await void_or_refund_sale(
                db_session,
                bid, sale.id,
                None,
                VoidRefundRequest(
                    client_action_id="act-already-2", new_status="voided",
                    reason="Second void",
                ),
                publish=AsyncMock(),
            )

    async def test_void_refund_rejects_already_refunded(self, db_session: AsyncSession) -> None:
        bid = uuid4()
        await sync_sale_batch(
            db_session,
            bid,
            None,
            SaleSyncBatchRequest(sales=[_sale_input(
                client_sale_id="already-refunded",
            )]),
            publish=AsyncMock(),
        )
        sale = (
            await db_session.exec(
                select(Sale).where(Sale.client_sale_id == "already-refunded")
            )
        ).one()

        await void_or_refund_sale(
            db_session,
            bid, sale.id,
            None,
            VoidRefundRequest(
                client_action_id="act-already-ref-1", new_status="refunded",
                reason="First refund",
            ),
            publish=AsyncMock(),
        )

        with pytest.raises(InvalidSaleStateError):
            await void_or_refund_sale(
                db_session,
                bid, sale.id,
                None,
                VoidRefundRequest(
                    client_action_id="act-already-ref-2", new_status="refunded",
                    reason="Second refund",
                ),
                publish=AsyncMock(),
            )

    async def test_void_refund_rejects_pre_voided_sale(
        self, db_session: AsyncSession,
    ) -> None:
        """A sale that arrived pre-voided via sync (Stage 4) cannot be voided."""
        bid = uuid4()
        await sync_sale_batch(
            db_session,
            bid,
            None,
            SaleSyncBatchRequest(sales=[_sale_input(
                client_sale_id="pre-voided-reject",
                status="voided",
                void_or_refund_reason="Pre-voided at sync",
            )]),
            publish=AsyncMock(),
        )
        sale = (
            await db_session.exec(
                select(Sale).where(Sale.client_sale_id == "pre-voided-reject")
            )
        ).one()
        assert sale.status == SaleStatus.VOIDED

        with pytest.raises(InvalidSaleStateError):
            await void_or_refund_sale(
                db_session,
                bid, sale.id,
                None,
                VoidRefundRequest(
                    client_action_id="act-pre-voided", new_status="voided",
                    reason="Should fail",
                ),
                publish=AsyncMock(),
            )

    async def test_void_refund_rejects_pre_refunded_sale(
        self, db_session: AsyncSession,
    ) -> None:
        """A sale that arrived pre-refunded via sync (Stage 4) cannot be refunded."""
        bid = uuid4()
        await sync_sale_batch(
            db_session,
            bid,
            None,
            SaleSyncBatchRequest(sales=[_sale_input(
                client_sale_id="pre-refunded-reject",
                status="refunded",
                void_or_refund_reason="Pre-refunded at sync",
            )]),
            publish=AsyncMock(),
        )
        sale = (
            await db_session.exec(
                select(Sale).where(Sale.client_sale_id == "pre-refunded-reject")
            )
        ).one()
        assert sale.status == SaleStatus.REFUNDED

        with pytest.raises(InvalidSaleStateError):
            await void_or_refund_sale(
                db_session,
                bid, sale.id,
                None,
                VoidRefundRequest(
                    client_action_id="act-pre-refunded", new_status="refunded",
                    reason="Should fail",
                ),
                publish=AsyncMock(),
            )

    # ── Idempotency ──────────────────────────────────────────────────

    async def test_void_same_client_action_id_twice_is_idempotent(
        self, db_session: AsyncSession,
    ) -> None:
        bid = uuid4()
        await sync_sale_batch(
            db_session,
            bid,
            None,
            SaleSyncBatchRequest(sales=[_sale_input(
                client_sale_id="idemp-void",
            )]),
            publish=AsyncMock(),
        )
        sale = (
            await db_session.exec(
                select(Sale).where(Sale.client_sale_id == "idemp-void")
            )
        ).one()

        client_action_id = "idemp-act-void"

        mock1 = AsyncMock()
        result1 = await void_or_refund_sale(
            db_session, bid, sale.id, None,
            VoidRefundRequest(
                client_action_id=client_action_id, new_status="voided",
                reason="First",
            ),
            publish=mock1,
        )
        assert result1.status == SaleStatus.VOIDED
        assert mock1.await_args is not None  # events were published

        mock2 = AsyncMock()
        result2 = await void_or_refund_sale(
            db_session, bid, sale.id, None,
            VoidRefundRequest(
                client_action_id=client_action_id, new_status="voided",
                reason="Should be ignored",
            ),
            publish=mock2,
        )
        assert result2.status == SaleStatus.VOIDED
        assert result2.void_client_action_id == client_action_id

        # Second call must NOT re-publish events
        mock2.assert_not_awaited()

        # Only one sale row exists
        sales = (
            await db_session.exec(
                select(Sale).where(Sale.client_sale_id == "idemp-void")
            )
        ).all()
        assert len(sales) == 1

    # ── KNOWN_GAP RESOLVED: Inventory Service now reverses stock ────

    async def test_void_publishes_sale_voided_event_gap_closed(
        self, db_session: AsyncSession,
    ) -> None:
        """POS Service publishes ``sale.voided`` correctly — the consuming
        side is now implemented in Inventory Service.

        This test verifies POS Service's side of the contract (event payload
        shape).  The consumption side is tested separately in Inventory
        Service's ``test_event_handlers.py``
        (``test_sale_voided_increases_stock`` and related tests).
        The gap that was previously tracked here is now closed.
        """
        item_id = uuid4()
        bid = uuid4()
        await sync_sale_batch(
            db_session,
            bid,
            None,
            SaleSyncBatchRequest(sales=[_sale_input(
                client_sale_id="gap-closed-void",
                line_items=[
                    SaleLineItemInput(
                        item_id=item_id, quantity=Decimal("3"),
                        unit_price=Decimal("7.00"),
                    ),
                ],
            )]),
            publish=AsyncMock(),
        )
        sale = (
            await db_session.exec(
                select(Sale).where(Sale.client_sale_id == "gap-closed-void")
            )
        ).one()

        mock_publish = AsyncMock()
        await void_or_refund_sale(
            db_session, bid, sale.id, None,
            VoidRefundRequest(
                client_action_id="gap-closed-act", new_status="voided",
                reason="Gap closure demonstration",
            ),
            publish=mock_publish,
        )

        sale_voided_calls = [
            c for c in mock_publish.await_args_list
            if c.args[0] == "sale.voided"
        ]
        assert len(sale_voided_calls) == 1
        payload = sale_voided_calls[0].args[1]
        assert payload["event_id"] == "gap-closed-act"
        assert payload["sale_id"] == str(sale.id)
        assert payload["line_items"] == [
            {"item_id": str(item_id), "quantity": "3"},
        ]
        # Inventory Service's handle_sale_voided now consumes this event
        # (see inventory-service/app/services/event_handlers.py).
