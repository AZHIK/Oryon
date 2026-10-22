"""Unit tests for operation request schemas — validation rules."""

from uuid import UUID

import pytest
from pydantic import ValidationError

from app.schemas.operations import (
    AdjustStockRequest,
    RecordWasteRequest,
    TransferStockRequest,
)


class TestAdjustStockRequest:
    def test_valid_request_succeeds(self) -> None:
        req = AdjustStockRequest(quantity_delta=-5.0, reason="Found damaged goods during audit")
        assert req.quantity_delta == -5.0

    def test_rejects_empty_reason(self) -> None:
        with pytest.raises(ValidationError) as exc:
            AdjustStockRequest(quantity_delta=3.0, reason="")
        errors = exc.value.errors()
        assert any("Reason" in e["msg"] or "reason" in str(e).lower() for e in errors)

    def test_rejects_too_short_reason(self) -> None:
        with pytest.raises(ValidationError):
            AdjustStockRequest(quantity_delta=3.0, reason="ab")


class TestRecordWasteRequest:
    def test_valid_request_succeeds(self) -> None:
        req = RecordWasteRequest(quantity=12.5, reason="Spoiled during transport")
        assert req.quantity == 12.5

    def test_rejects_negative_quantity(self) -> None:
        with pytest.raises(ValidationError):
            RecordWasteRequest(quantity=-5.0, reason="Spoiled goods")

    def test_rejects_zero_quantity(self) -> None:
        with pytest.raises(ValidationError):
            RecordWasteRequest(quantity=0, reason="Spoiled goods")

    def test_rejects_missing_reason(self) -> None:
        with pytest.raises(ValidationError):
            RecordWasteRequest(quantity=5.0, reason="")

    def test_rejects_too_short_reason(self) -> None:
        with pytest.raises(ValidationError):
            RecordWasteRequest(quantity=5.0, reason="ok")


class TestTransferStockRequest:
    def test_valid_request_succeeds(self) -> None:
        req = TransferStockRequest(
            item_id=UUID("11111111-1111-1111-1111-111111111111"),
            source_store_id=UUID("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"),
            destination_store_id=UUID("bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"),
            quantity=50.0,
        )
        assert req.quantity == 50.0

    def test_rejects_same_source_and_destination(self) -> None:
        loc = UUID("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")
        with pytest.raises(ValidationError) as exc:
            TransferStockRequest(
                item_id=UUID("11111111-1111-1111-1111-111111111111"),
                source_store_id=loc,
                destination_store_id=loc,
                quantity=10.0,
            )
        errors = exc.value.errors()
        assert any("different" in str(e).lower() or "same" in str(e).lower() for e in errors)

    def test_rejects_non_positive_quantity(self) -> None:
        with pytest.raises(ValidationError):
            TransferStockRequest(
                item_id=UUID("11111111-1111-1111-1111-111111111111"),
                source_store_id=UUID("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"),
                destination_store_id=UUID("bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"),
                quantity=0,
            )

    def test_rejects_negative_quantity(self) -> None:
        with pytest.raises(ValidationError):
            TransferStockRequest(
                item_id=UUID("11111111-1111-1111-1111-111111111111"),
                source_store_id=UUID("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"),
                destination_store_id=UUID("bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"),
                quantity=-1,
            )
