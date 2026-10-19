"""Item product-photo upload/download endpoints.

One photo per item, replaced in place: uploading a second photo overwrites
the first (see ``app/services/item_image_storage.py`` for the storage
design and its documented single-node/backup tradeoffs).

Uploads ride the item's own write permission (``inventory.items.update``)
— a photo is part of the item's data, not a separate resource with its own
permission. Reads ride ``inventory.view``, matching the item GETs.

The photo URL is exposed as ``image_url`` on ``ItemRead`` (null when no
photo), so the catalog pull the app already performs carries photo
presence with no extra round-trip per item.
"""

from __future__ import annotations

from typing import Annotated, Any
from uuid import UUID

import structlog
from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status
from fastapi.responses import FileResponse
from sqlmodel.ext.asyncio.session import AsyncSession

from app.api.v1.endpoints.items import _get_item_or_404
from app.core.database import get_db
from app.deps.auth import (
    ensure_store_access,
    get_current_claims,
    require_business_permission,
)
from app.schemas.items import ItemRead
from app.services.item_image_storage import (
    ItemImageStorage,
    ItemImageValidationError,
    get_item_image_storage,
)

logger = structlog.get_logger(__name__)
router = APIRouter(prefix="/businesses/{business_id}/items/{item_id}", tags=["items"])


@router.put("/image", response_model=ItemRead)
async def upload_item_image(
    business_id: UUID,
    item_id: UUID,
    file: UploadFile = File(...),
    session: AsyncSession = Depends(get_db),
    storage: ItemImageStorage = Depends(get_item_image_storage),
    _jwt_biz_id: str = Depends(require_business_permission("inventory.items.update")),
    claims: dict[str, Any] = Depends(get_current_claims),
) -> ItemRead:
    """Upload (or replace) the item's product photo.

    Accepts JPEG, PNG, or WebP up to the configured size limit — the same
    "up to 5 MB" the app's picker advertises. Returns the updated item,
    whose ``image_url`` is now populated.
    """
    item = await _get_item_or_404(business_id, item_id, session)
    ensure_store_access(claims, item.store_id)

    try:
        stored = await storage.save(business_id=business_id, item_id=item.id, upload=file)
    except ItemImageValidationError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc

    item.image_path = stored.storage_key
    session.add(item)
    await session.commit()
    await session.refresh(item)

    logger.info(
        "item.image_uploaded",
        item_id=str(item.id),
        business_id=str(business_id),
        byte_size=stored.byte_size,
    )
    return ItemRead.model_validate(item)


@router.get("/image")
async def download_item_image(
    business_id: UUID,
    item_id: UUID,
    session: Annotated[AsyncSession, Depends(get_db)],
    storage: Annotated[ItemImageStorage, Depends(get_item_image_storage)],
    _jwt_biz_id: Annotated[str, Depends(require_business_permission("inventory.view"))],
    claims: Annotated[dict[str, Any], Depends(get_current_claims)],
) -> FileResponse:
    """Serve the item's product photo bytes.

    404 (not 403) on a cross-business id — don't confirm existence across
    tenants. 404 as well when the item simply has no photo yet.
    """
    item = await _get_item_or_404(business_id, item_id, session)
    ensure_store_access(claims, item.store_id)
    if not item.image_path:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Item has no photo")

    path = storage.resolve_path(item.image_path)
    if not path.is_file():
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Item has no photo")

    suffix = path.suffix.lower()
    media_type = {
        ".jpg": "image/jpeg",
        ".jpeg": "image/jpeg",
        ".png": "image/png",
        ".webp": "image/webp",
    }.get(suffix, "application/octet-stream")

    return FileResponse(
        path,
        media_type=media_type,
        headers={
            "X-Content-Type-Options": "nosniff",
            "Cache-Control": "private, max-age=86400",
        },
    )


@router.delete("/image", response_model=ItemRead)
async def delete_item_image(
    business_id: UUID,
    item_id: UUID,
    session: Annotated[AsyncSession, Depends(get_db)],
    storage: Annotated[ItemImageStorage, Depends(get_item_image_storage)],
    _jwt_biz_id: Annotated[str, Depends(require_business_permission("inventory.items.update"))],
    claims: Annotated[dict[str, Any], Depends(get_current_claims)],
) -> ItemRead:
    """Remove the item's product photo.

    Idempotent: deleting when there is no photo still returns the item
    (with a null ``image_url``) rather than a 404 — the desired end state
    is "no photo" either way.
    """
    item = await _get_item_or_404(business_id, item_id, session)
    ensure_store_access(claims, item.store_id)
    if item.image_path:
        storage.delete(item.image_path)
        item.image_path = None
        session.add(item)
        await session.commit()
        await session.refresh(item)
        logger.info("item.image_deleted", item_id=str(item.id), business_id=str(business_id))
    return ItemRead.model_validate(item)
