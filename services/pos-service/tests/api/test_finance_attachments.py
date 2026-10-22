"""API tests for receipt attachment upload/download."""

from __future__ import annotations

from pathlib import Path
from uuid import UUID, uuid4

import pytest
from httpx import AsyncClient

from app.main import app
from app.services.receipt_storage import LocalDiskReceiptStorage, get_receipt_storage
from tests.test_token_verification import _build_token

UPLOAD_URL = "/api/v1/businesses/{business_id}/finance/attachments"
DOWNLOAD_URL = "/api/v1/businesses/{business_id}/finance/attachments/{attachment_id}"

# PNG magic-byte signature followed by arbitrary payload bytes — the storage
# layer's `_sniff_content_type` only checks the leading signature, not full
# PNG structure, so this is sufficient to pass validation.
_TINY_PNG = b"\x89PNG\r\n\x1a\n" + b"fake-but-signature-valid-png-payload"


def _auth_header(
    *, business_id: UUID | None = None, permissions: list[str] | None = None
) -> dict[str, str]:
    biz_id = business_id or uuid4()
    token = _build_token(
        extra_claims={
            "permissions": permissions or ["finance.view", "finance.attachments.upload"],
            "active_business_id": str(biz_id),
        },
    )
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture(autouse=True)
def _override_receipt_storage(tmp_path: Path):
    app.dependency_overrides[get_receipt_storage] = lambda: LocalDiskReceiptStorage(tmp_path)
    yield
    app.dependency_overrides.pop(get_receipt_storage, None)


class TestUploadAndDownload:
    async def test_upload_then_download_roundtrips_bytes(self, client: AsyncClient) -> None:
        business_id = uuid4()
        headers = _auth_header(business_id=business_id)

        upload_resp = await client.post(
            UPLOAD_URL.format(business_id=business_id),
            files={"file": ("receipt.png", _TINY_PNG, "image/png")},
            headers=headers,
        )
        assert upload_resp.status_code == 201
        attachment_id = upload_resp.json()["id"]
        assert upload_resp.json()["byte_size"] == len(_TINY_PNG)

        download_resp = await client.get(
            DOWNLOAD_URL.format(business_id=business_id, attachment_id=attachment_id),
            headers=headers,
        )
        assert download_resp.status_code == 200
        assert download_resp.content == _TINY_PNG
        assert download_resp.headers["content-type"] == "image/png"

    async def test_disallowed_content_type_rejected(self, client: AsyncClient) -> None:
        business_id = uuid4()
        headers = _auth_header(business_id=business_id)
        resp = await client.post(
            UPLOAD_URL.format(business_id=business_id),
            files={"file": ("virus.exe", b"whatever", "application/x-msdownload")},
            headers=headers,
        )
        assert resp.status_code == 400

    async def test_mismatched_magic_bytes_rejected(self, client: AsyncClient) -> None:
        """A .png filename/content-type with non-PNG bytes must be rejected — the
        server sniffs actual content rather than trusting the declared type."""
        business_id = uuid4()
        headers = _auth_header(business_id=business_id)
        resp = await client.post(
            UPLOAD_URL.format(business_id=business_id),
            files={"file": ("fake.png", b"not a real png file", "image/png")},
            headers=headers,
        )
        assert resp.status_code == 400

    async def test_oversize_upload_rejected(self, client: AsyncClient, monkeypatch) -> None:
        from app.core import config

        config.get_settings.cache_clear()
        monkeypatch.setenv("RECEIPT_MAX_BYTES", "10")
        config.get_settings.cache_clear()
        try:
            business_id = uuid4()
            headers = _auth_header(business_id=business_id)
            resp = await client.post(
                UPLOAD_URL.format(business_id=business_id),
                files={"file": ("receipt.png", _TINY_PNG, "image/png")},
                headers=headers,
            )
            assert resp.status_code == 400
        finally:
            config.get_settings.cache_clear()

    async def test_download_from_different_business_returns_404(self, client: AsyncClient) -> None:
        business_id = uuid4()
        other_business_id = uuid4()
        headers = _auth_header(business_id=business_id)

        upload_resp = await client.post(
            UPLOAD_URL.format(business_id=business_id),
            files={"file": ("receipt.png", _TINY_PNG, "image/png")},
            headers=headers,
        )
        attachment_id = upload_resp.json()["id"]

        other_headers = _auth_header(business_id=other_business_id)
        resp = await client.get(
            DOWNLOAD_URL.format(business_id=other_business_id, attachment_id=attachment_id),
            headers=other_headers,
        )
        assert resp.status_code == 404

    async def test_upload_without_permission_returns_403(self, client: AsyncClient) -> None:
        business_id = uuid4()
        headers = _auth_header(business_id=business_id, permissions=["finance.view"])
        resp = await client.post(
            UPLOAD_URL.format(business_id=business_id),
            files={"file": ("receipt.png", _TINY_PNG, "image/png")},
            headers=headers,
        )
        assert resp.status_code == 403
