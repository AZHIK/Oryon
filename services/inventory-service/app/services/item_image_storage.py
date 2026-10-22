"""Local-disk storage for item product-photo uploads.

Same MVP transport as POS Service's receipt storage (see
``services/pos-service/app/services/receipt_storage.py``): files are
written to a local directory (see ``Settings.item_image_storage_root``),
not an S3/MinIO bucket. Behind the ``ItemImageStorage`` protocol so a
future S3/MinIO backend is a new class, not a rewrite of every call site.

Differences from receipts, all deliberate:

- Images only — no PDFs. A product photo is rendered in the app, never
  downloaded as a document.
- One photo per item, replaced in place. The on-disk name is always
  ``{business_id}/{item_id}{ext}``, so re-uploading overwrites the
  previous photo (stale extensions are cleaned up by the endpoint before
  saving) instead of accumulating versions.
- The client-supplied filename is NEVER used to build a filesystem path.
  The on-disk name derives solely from trusted UUIDs.

Security posture (mirrors receipts):

- Content-type is checked against an allowlist AND sniffed from the first
  bytes of the upload — a client can lie about ``Content-Type``.
- ``resolve_path`` asserts the resolved path stays inside the storage root
  before returning, as a second line of defense against a corrupted or
  tampered ``image_path``.
"""

from __future__ import annotations

import contextlib
import hashlib
import os
from dataclasses import dataclass
from pathlib import Path
from typing import Protocol
from uuid import UUID

from fastapi import UploadFile

from app.core.config import get_settings
from app.core.exceptions import DomainError

# content-type -> (file extension, magic-byte sniffer)
_MAGIC_JPEG = (b"\xff\xd8\xff",)
_MAGIC_PNG = (b"\x89PNG\r\n\x1a\n",)
_MAGIC_WEBP_RIFF = b"RIFF"
_MAGIC_WEBP_TAG = b"WEBP"

ALLOWED_CONTENT_TYPES: dict[str, str] = {
    "image/jpeg": ".jpg",
    "image/png": ".png",
    "image/webp": ".webp",
}


class ItemImageStorageError(DomainError):
    """Base for all item-image storage errors."""


class ItemImageValidationError(ItemImageStorageError):
    """The uploaded file failed a validation check (type, size, content)."""


@dataclass(frozen=True)
class StoredItemImage:
    storage_key: str
    content_type: str
    byte_size: int
    checksum_sha256: str


def _sniff_content_type(head: bytes, declared_content_type: str) -> bool:
    """Return True if *head* (the first bytes of the upload) matches the
    magic bytes expected for *declared_content_type*."""
    if declared_content_type == "image/jpeg":
        return any(head.startswith(sig) for sig in _MAGIC_JPEG)
    if declared_content_type == "image/png":
        return any(head.startswith(sig) for sig in _MAGIC_PNG)
    if declared_content_type == "image/webp":
        return head.startswith(_MAGIC_WEBP_RIFF) and head[8:12] == _MAGIC_WEBP_TAG
    return False


class ItemImageStorage(Protocol):
    async def save(
        self,
        *,
        business_id: UUID,
        item_id: UUID,
        upload: UploadFile,
    ) -> StoredItemImage: ...

    def delete(self, storage_key: str) -> None: ...

    def resolve_path(self, storage_key: str) -> Path: ...


class LocalDiskItemImageStorage:
    """Writes item photos under ``{root}/{business_id}/{item_id}{ext}``."""

    def __init__(self, root: str | Path) -> None:
        self._root = Path(root).resolve()

    def _target(self, business_id: UUID, item_id: UUID, ext: str) -> tuple[Path, str]:
        rel_path = Path(str(business_id)) / f"{item_id}{ext}"
        return self._root / rel_path, str(rel_path)

    async def save(
        self,
        *,
        business_id: UUID,
        item_id: UUID,
        upload: UploadFile,
    ) -> StoredItemImage:
        settings = get_settings()
        declared_content_type = upload.content_type or ""
        if declared_content_type not in ALLOWED_CONTENT_TYPES:
            raise ItemImageValidationError(
                f"Unsupported content type '{declared_content_type}'. "
                f"Allowed: {', '.join(sorted(ALLOWED_CONTENT_TYPES))}"
            )
        ext = ALLOWED_CONTENT_TYPES[declared_content_type]

        target_dir = self._root / str(business_id)
        target_dir.mkdir(parents=True, exist_ok=True)

        # Replacing in place: remove a previous photo with a different
        # extension first, otherwise "{item_id}.png" would linger beside the
        # new "{item_id}.jpg" and serve stale bytes by key confusion.
        for old_ext in ALLOWED_CONTENT_TYPES.values():
            if old_ext != ext:
                (target_dir / f"{item_id}{old_ext}").unlink(missing_ok=True)

        final_path, rel_key = self._target(business_id, item_id, ext)
        tmp_path = target_dir / f".{item_id}.part"

        hasher = hashlib.sha256()
        byte_size = 0
        head = b""
        max_bytes = settings.item_image_max_bytes

        try:
            with open(tmp_path, "wb") as tmp_file:
                while chunk := await upload.read(1024 * 64):
                    byte_size += len(chunk)
                    if byte_size > max_bytes:
                        raise ItemImageValidationError(
                            f"File exceeds the {max_bytes} byte upload limit"
                        )
                    if len(head) < 32:
                        head += chunk
                    hasher.update(chunk)
                    tmp_file.write(chunk)

            if byte_size == 0:
                raise ItemImageValidationError("Uploaded file is empty")
            if not _sniff_content_type(head, declared_content_type):
                raise ItemImageValidationError(
                    "File content does not match its declared content type"
                )

            os.replace(tmp_path, final_path)
        except Exception:
            tmp_path.unlink(missing_ok=True)
            raise

        return StoredItemImage(
            storage_key=rel_key,
            content_type=declared_content_type,
            byte_size=byte_size,
            checksum_sha256=hasher.hexdigest(),
        )

    def delete(self, storage_key: str) -> None:
        # A tampered key must not turn a delete into a 500 — the DB row
        # is the source of truth and is cleared regardless.
        with contextlib.suppress(ItemImageStorageError):
            self.resolve_path(storage_key).unlink(missing_ok=True)

    def resolve_path(self, storage_key: str) -> Path:
        candidate = (self._root / storage_key).resolve()
        if self._root not in candidate.parents and candidate != self._root:
            raise ItemImageStorageError(
                f"Refusing to resolve path outside storage root: {storage_key}"
            )
        return candidate


def get_item_image_storage() -> ItemImageStorage:
    """FastAPI dependency — overridable in tests via ``app.dependency_overrides``."""
    settings = get_settings()
    return LocalDiskItemImageStorage(settings.item_image_storage_root)
