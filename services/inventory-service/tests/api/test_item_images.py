"""Integration tests for item product-photo endpoints.

Upload (PUT), download (GET), and removal (DELETE) of one photo per item
through the full auth + permission stack with a real Postgres-backed
session. File bytes land in a tmp dir (dependency override), never in the
repo or a container volume.
"""

from __future__ import annotations

from decimal import Decimal
from uuid import UUID

import pytest
from httpx import AsyncClient
from sqlmodel import select
from sqlmodel.ext.asyncio.session import AsyncSession

from app.main import app
from app.models.inventory import Item, ItemType
from app.models.units import Unit
from app.services.item_image_storage import (
    LocalDiskItemImageStorage,
    get_item_image_storage,
)
from tests.api.test_reports import (
    BUSINESS_ID,
    OTHER_BUSINESS_ID,
    STORE_ID,
    _build_token,
)

BASE = "/api/v1/businesses/{business_id}/items/{item_id}/image"

ITEMS_BASE = "/api/v1/businesses/{business_id}/items"

# Minimal valid PNG (1x1) and JPEG (SOI + JFIF-ish) payloads — only the
# magic bytes matter to the sniffer.
PNG_BYTES = (
    b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01"
    b"\x08\x02\x00\x00\x00\x90wS\xde\x00\x00\x00\x0cIDATx\x9cc\xf8\x0f\x00"
    b"\x00\x01\x01\x00\x05\x18\xd8N\x00\x00\x00\x00IEND\xaeB`\x82"
)
JPEG_BYTES = b"\xff\xd8\xff\xe0\x00\x10JFIF\x00" + b"\x00" * 64


def _auth(permissions: list[str], business_id: UUID = BUSINESS_ID) -> dict[str, str]:
    return {
        "Authorization": "Bearer "
        + _build_token(permissions=permissions, active_business_id=str(business_id))
    }


@pytest.fixture
def _tmp_storage(tmp_path, monkeypatch):
    """Point the storage dependency at a tmp dir for one test."""
    storage = LocalDiskItemImageStorage(tmp_path / "item_images")
    app.dependency_overrides[get_item_image_storage] = lambda: storage
    yield storage
    app.dependency_overrides.pop(get_item_image_storage, None)


async def _create_item(db_session: AsyncSession, name: str = "Tomatoes") -> Item:
    unit_id = (await db_session.exec(select(Unit).where(Unit.code == "kg"))).one().id
    item = Item(
        business_id=BUSINESS_ID,
        store_id=STORE_ID,
        name=name,
        unit_id=unit_id,
        reorder_threshold=Decimal("10.000"),
        reorder_quantity=Decimal("20.000"),
        item_type=ItemType.RAW_MATERIAL,
    )
    db_session.add(item)
    await db_session.commit()
    await db_session.refresh(item)
    return item


def _image_url(business_id: UUID, item_id: UUID) -> str:
    return f"/businesses/{business_id}/items/{item_id}/image"


class TestUploadItemImage:
    async def test_upload_roundtrip(
        self, client: AsyncClient, db_session: AsyncSession, _tmp_storage
    ) -> None:
        item = await _create_item(db_session)

        resp = await client.put(
            BASE.format(business_id=BUSINESS_ID, item_id=item.id),
            headers=_auth(["inventory.items.update"]),
            files={"file": ("photo.png", PNG_BYTES, "image/png")},
        )
        assert resp.status_code == 200, resp.text
        assert resp.json()["image_url"] == _image_url(BUSINESS_ID, item.id)

        # The catalog GET carries the URL too — no extra round-trip per item.
        got = await client.get(
            ITEMS_BASE.format(business_id=BUSINESS_ID) + f"/{item.id}",
            headers=_auth(["inventory.view"]),
        )
        assert got.status_code == 200, got.text
        assert got.json()["image_url"] == _image_url(BUSINESS_ID, item.id)

        # And the bytes come back with their content type.
        dl = await client.get(
            BASE.format(business_id=BUSINESS_ID, item_id=item.id),
            headers=_auth(["inventory.view"]),
        )
        assert dl.status_code == 200, dl.text
        assert dl.content == PNG_BYTES
        assert dl.headers["content-type"] == "image/png"

    async def test_upload_replaces_previous_photo(
        self, client: AsyncClient, db_session: AsyncSession, _tmp_storage
    ) -> None:
        item = await _create_item(db_session)
        url = BASE.format(business_id=BUSINESS_ID, item_id=item.id)
        headers = _auth(["inventory.items.update", "inventory.view"])

        first = await client.put(
            url, headers=headers, files={"file": ("a.png", PNG_BYTES, "image/png")}
        )
        assert first.status_code == 200, first.text

        second = await client.put(
            url, headers=headers, files={"file": ("b.jpg", JPEG_BYTES, "image/jpeg")}
        )
        assert second.status_code == 200, second.text

        # The stale .png must be gone — exactly one file per item.
        leftovers = list((_tmp_storage._root / str(BUSINESS_ID)).glob(f"{item.id}.*"))
        assert [p.suffix for p in leftovers] == [".jpg"]

        dl = await client.get(url, headers=headers)
        assert dl.content == JPEG_BYTES

    async def test_rejects_non_image(
        self, client: AsyncClient, db_session: AsyncSession, _tmp_storage
    ) -> None:
        item = await _create_item(db_session)
        resp = await client.put(
            BASE.format(business_id=BUSINESS_ID, item_id=item.id),
            headers=_auth(["inventory.items.update"]),
            files={"file": ("doc.pdf", b"%PDF-1.4 fake", "application/pdf")},
        )
        assert resp.status_code == 400, resp.text

    async def test_rejects_lying_content(
        self, client: AsyncClient, db_session: AsyncSession, _tmp_storage
    ) -> None:
        item = await _create_item(db_session)
        resp = await client.put(
            BASE.format(business_id=BUSINESS_ID, item_id=item.id),
            headers=_auth(["inventory.items.update"]),
            files={"file": ("evil.png", b"not an image at all", "image/png")},
        )
        assert resp.status_code == 400, resp.text

    async def test_unknown_item_is_404(self, client: AsyncClient, _tmp_storage) -> None:
        from uuid import uuid4

        resp = await client.put(
            BASE.format(business_id=BUSINESS_ID, item_id=uuid4()),
            headers=_auth(["inventory.items.update"]),
            files={"file": ("photo.png", PNG_BYTES, "image/png")},
        )
        assert resp.status_code == 404, resp.text


class TestDownloadItemImage:
    async def test_no_photo_is_404(
        self, client: AsyncClient, db_session: AsyncSession, _tmp_storage
    ) -> None:
        item = await _create_item(db_session)
        resp = await client.get(
            BASE.format(business_id=BUSINESS_ID, item_id=item.id),
            headers=_auth(["inventory.view"]),
        )
        assert resp.status_code == 404, resp.text

    async def test_cross_business_is_404_not_403(
        self, client: AsyncClient, db_session: AsyncSession, _tmp_storage
    ) -> None:
        item = await _create_item(db_session)
        await client.put(
            BASE.format(business_id=BUSINESS_ID, item_id=item.id),
            headers=_auth(["inventory.items.update"]),
            files={"file": ("photo.png", PNG_BYTES, "image/png")},
        )
        resp = await client.get(
            BASE.format(business_id=OTHER_BUSINESS_ID, item_id=item.id),
            headers=_auth(["inventory.view"], business_id=OTHER_BUSINESS_ID),
        )
        # Same 404 as a missing item — don't confirm existence across tenants.
        assert resp.status_code == 404, resp.text


class TestDeleteItemImage:
    async def test_delete_clears_url_and_bytes(
        self, client: AsyncClient, db_session: AsyncSession, _tmp_storage
    ) -> None:
        item = await _create_item(db_session)
        url = BASE.format(business_id=BUSINESS_ID, item_id=item.id)
        headers = _auth(["inventory.items.update", "inventory.view"])

        put = await client.put(
            url, headers=headers, files={"file": ("photo.png", PNG_BYTES, "image/png")}
        )
        assert put.status_code == 200, put.text

        deleted = await client.request("DELETE", url, headers=headers)
        assert deleted.status_code == 200, deleted.text
        assert deleted.json()["image_url"] is None

        assert (await client.get(url, headers=headers)).status_code == 404
        assert list((_tmp_storage._root / str(BUSINESS_ID)).glob(f"{item.id}.*")) == []

    async def test_delete_without_photo_is_idempotent(
        self, client: AsyncClient, db_session: AsyncSession, _tmp_storage
    ) -> None:
        item = await _create_item(db_session)
        resp = await client.request(
            "DELETE",
            BASE.format(business_id=BUSINESS_ID, item_id=item.id),
            headers=_auth(["inventory.items.update"]),
        )
        assert resp.status_code == 200, resp.text
        assert resp.json()["image_url"] is None


class TestItemImageRbac:
    async def test_upload_rejects_without_update_perm(
        self, client: AsyncClient, db_session: AsyncSession, _tmp_storage
    ) -> None:
        item = await _create_item(db_session)
        resp = await client.put(
            BASE.format(business_id=BUSINESS_ID, item_id=item.id),
            headers=_auth(["inventory.view"]),
            files={"file": ("photo.png", PNG_BYTES, "image/png")},
        )
        assert resp.status_code == 403, resp.text

    async def test_download_rejects_without_view_perm(
        self, client: AsyncClient, db_session: AsyncSession, _tmp_storage
    ) -> None:
        item = await _create_item(db_session)
        resp = await client.get(
            BASE.format(business_id=BUSINESS_ID, item_id=item.id),
            headers=_auth(["inventory.adjust"]),
        )
        assert resp.status_code == 403, resp.text

    async def test_item_without_photo_has_null_image_url(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        item = await _create_item(db_session)
        resp = await client.get(
            ITEMS_BASE.format(business_id=BUSINESS_ID) + f"/{item.id}",
            headers=_auth(["inventory.view"]),
        )
        assert resp.status_code == 200, resp.text
        assert resp.json()["image_url"] is None
