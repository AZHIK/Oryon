"""Requisition service — bulk-assign, PO split, WhatsApp payload, rollup.

Pure business logic over ``Requisition``/``PurchaseOrder``/``SupplierMessage``.
Endpoint layers handle auth + HTTP mapping; everything transactional lives here.

Purchase orders are qty-only: no money lives on the PO or in the supplier
payload. Actual cost enters later on ``GoodsReceiptLine.unit_cost``. The
``SupplierItem`` catalogue and ``RequisitionLine`` price snapshots remain as
buyer-side reference only — they are never copied to the PO nor rendered in
the WhatsApp message.
"""

from __future__ import annotations

from datetime import UTC, datetime
from decimal import Decimal
from typing import Any
from urllib.parse import quote
from uuid import UUID

from sqlalchemy import func
from sqlmodel import select
from sqlmodel.ext.asyncio.session import AsyncSession

from app.models.inventory import Item
from app.models.purchases import PurchaseOrder, PurchaseOrderLine, PurchaseOrderStatus
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

# Statuses a requisition PO may hold while still appendable. Rule confirmed:
# SAME REQUISITION ONLY — we append to an unfulfilled PO from the same
# requisition+supplier, never to another day's or cart's PO.
_APPENDABLE = (PurchaseOrderStatus.UNFULFILLED,)


def _supplier_number(supplier: Supplier) -> str | None:
    """Resolve the WhatsApp number: explicit field first, legacy ``phone`` fallback."""
    raw = (supplier.whatsapp_number or supplier.phone or "").strip()
    if not raw:
        return None
    digits = "".join(ch for ch in raw if ch.isdigit() or ch == "+")
    return digits or None


def _resolve_price(
    catalogue: dict[tuple[UUID, UUID], SupplierItem | None],
    supplier_id: UUID,
    item_id: UUID,
) -> tuple[Decimal | None, bool]:
    """Return (unit_price, price_unconfirmed) for a supplier+item pairing."""
    row = catalogue.get((supplier_id, item_id))
    if row is not None and row.price is not None:
        return row.price, False
    return None, True


async def bulk_assign_supplier(
    session: AsyncSession,
    *,
    requisition_id: UUID,
    business_id: UUID,
    supplier_id: UUID,
    scope: str,
    overwrite: bool = False,
) -> list[RequisitionLine]:
    """Apply ``supplier_id`` to matching lines of a requisition.

    * ``scope="unassigned_items_only"`` (default): only lines with no
      supplier are touched.
    * ``scope="all_items"``: every line is a candidate, BUT existing
      per-item choices are preserved unless ``overwrite=True`` (the explicit
      "override all" toggle confirmed for this project).
    * Unit prices re-resolve from ``SupplierItem``; missing mapping →
      ``price_unconfirmed=True`` (never blocks).
    * Idempotent: re-running re-assigns + re-resolves, no duplicate rows.
    """
    if scope not in ("all_items", "unassigned_items_only"):
        raise ValueError(f"Unknown bulk-assign scope: {scope!r}")

    requisition = (
        await session.exec(
            select(Requisition).where(
                Requisition.id == requisition_id, Requisition.business_id == business_id
            )
        )
    ).one_or_none()
    if requisition is None:
        raise LookupError("Requisition not found")

    supplier = (
        await session.exec(
            select(Supplier).where(Supplier.id == supplier_id, Supplier.business_id == business_id)
        )
    ).one_or_none()
    if supplier is None or supplier.is_deleted:
        raise LookupError("Supplier not found")

    lines = (
        await session.exec(
            select(RequisitionLine).where(RequisitionLine.requisition_id == requisition_id)
        )
    ).all()

    catalogue_rows = (
        await session.exec(select(SupplierItem).where(SupplierItem.supplier_id == supplier_id))
    ).all()
    catalogue = {(row.supplier_id, row.item_id): row for row in catalogue_rows}

    touched: list[RequisitionLine] = []
    for line in lines:
        if scope == "unassigned_items_only" and line.supplier_id is not None:
            continue
        if scope == "all_items" and line.supplier_id is not None and not overwrite:
            continue
        price, unconfirmed = _resolve_price(catalogue, supplier_id, line.item_id)
        line.supplier_id = supplier_id
        line.supplier_assignment_source = AssignmentSource.BULK_ALL
        line.unit_price_snapshot = price
        line.price_unconfirmed = unconfirmed
        session.add(line)
        touched.append(line)
    return touched


def build_whatsapp_payload(
    *,
    po: PurchaseOrder,
    supplier: Supplier,
    lines: list[dict[str, Any]],
    restaurant_name: str,
    order_date: str,
    delivery_requested_date: str | None,
    notes: str | None,
) -> dict[str, Any] | None:
    """Build the provider-agnostic WhatsApp JSON for one supplier PO.

    Qty-only: each entry carries ``name``/``qty``/``unit`` — no prices, no
    totals. Returns ``None`` when the supplier has no WhatsApp number — the
    PO is still created; payload/deep_link generation is skipped and the UI
    shows "Add WhatsApp number to send."
    """
    number = _supplier_number(supplier)
    if number is None:
        return None

    items: list[dict[str, Any]] = [
        {"name": entry["name"], "qty": str(entry["qty"]), "unit": entry.get("unit", "")}
        for entry in lines
    ]

    header = (
        f"Hello {supplier.name}, new order from {restaurant_name} "
        f"({po.po_number}) dated {order_date}."
    )
    if delivery_requested_date:
        header += f" Delivery requested: {delivery_requested_date}."
    body_lines = [header, ""]
    for it in items:
        body_lines.append(f"- {it['name']}: {it['qty']} {it['unit']}".rstrip())
    if notes:
        body_lines += ["", f"Notes: {notes}"]
    text_preview = "\n".join(body_lines)

    digits = number.lstrip("+")
    deep_link = f"https://wa.me/{digits}?text={quote(text_preview, safe='')}"

    return {
        "po_id": str(po.id),
        "supplier": {"name": supplier.name, "whatsapp_number": number},
        "message_type": "purchase_order",
        "text_preview": text_preview,
        "structured_data": {
            "po_number": po.po_number,
            "restaurant_name": restaurant_name,
            "order_date": order_date,
            "delivery_requested_date": delivery_requested_date,
            "items": items,
            "notes": notes,
        },
        "deep_link": deep_link,
    }


def rollup_requisition_status(po_statuses: list[str]) -> str:
    """Pure rollup: derive the requisition-level state from child PO statuses.

    * all fulfilled → ``Fulfilled``
    * all cancelled → ``Cancelled``
    * otherwise → ``Unfulfilled`` (actionable: staff must receive)
    """
    if not po_statuses:
        return "Unfulfilled"
    if all(s == "fulfilled" for s in po_statuses):
        return "Fulfilled"
    if all(s == "cancelled" for s in po_statuses):
        return "Cancelled"
    return "Unfulfilled"


async def _next_po_number(session: AsyncSession, business_id: UUID) -> str:
    """Next global-sequential ``PO-0001`` number scoped to the business."""
    count = (
        await session.exec(
            select(func.count())
            .select_from(PurchaseOrder)
            .where(PurchaseOrder.business_id == business_id)
        )
    ).one()
    return f"PO-{int(count) + 1:04d}"


async def submit_requisition(
    session: AsyncSession,
    *,
    business_id: UUID,
    store_id: UUID,
    created_by: UUID | None,
    notes: str | None,
    expected_at: datetime | None,
    lines: list[dict[str, Any]],
    idempotency_key: str | None,
    restaurant_name: str,
) -> tuple[Requisition, list[PurchaseOrder], list[SupplierMessage], list[str]]:
    """Create a requisition and split it into one qty-only PO per supplier.

    * Rejects lines with no ``supplier_id`` — structured error naming items.
    * ``SupplierItem`` catalogue prices are snapshotted onto
      ``RequisitionLine`` as buyer-side reference only (plus the
      ``price_unconfirmed`` flag list returned for UI hints) — they are
      never copied to the PO nor rendered in the supplier payload.
    * Same (item, supplier) pair appearing twice merges into ONE PO line
      (quantities summed); the SAME item under TWO suppliers yields two
      lines in two POs.
    * Append rule (confirmed): reuse an UNFULFILLED PO from the SAME
      requisition+supplier — on first submit there is none, so one PO per
      supplier is created. Idempotent re-submit returns the existing rows.
    * All-or-nothing transaction boundary is owned by the caller (the
      endpoint commits once); on error we raise before any flush persists.
    """
    if not lines:
        raise ValueError("A requisition must contain at least one line")

    # Idempotency: same key + business → return existing graph, no duplicates.
    if idempotency_key:
        existing = (
            await session.exec(
                select(Requisition).where(
                    Requisition.business_id == business_id,
                    Requisition.idempotency_key == idempotency_key,
                )
            )
        ).one_or_none()
        if existing is not None:
            pos = (
                await session.exec(
                    select(PurchaseOrder).where(PurchaseOrder.requisition_id == existing.id)
                )
            ).all()
            msgs: list[SupplierMessage] = []
            for po in pos:
                msgs.extend(
                    (
                        await session.exec(
                            select(SupplierMessage).where(SupplierMessage.po_id == po.id)
                        )
                    ).all()
                )
            flagged = [
                str(rl.item_id)
                for rl in (
                    await session.exec(
                        select(RequisitionLine).where(
                            RequisitionLine.requisition_id == existing.id,
                            RequisitionLine.price_unconfirmed == True,  # noqa: E712
                        )
                    )
                ).all()
            ]
            return existing, list(pos), msgs, flagged

    # ── validate suppliers + items ──────────────────────────────────────
    supplier_ids = {ln["supplier_id"] for ln in lines if ln.get("supplier_id")}
    suppliers: dict[UUID, Supplier] = {}
    for sid in supplier_ids:
        sup = (
            await session.exec(
                select(Supplier).where(Supplier.id == sid, Supplier.business_id == business_id)
            )
        ).one_or_none()
        if sup is None or sup.is_deleted:
            raise LookupError(f"Supplier '{sid}' not found")
        suppliers[sid] = sup

    missing = [ln for ln in lines if not ln.get("supplier_id")]
    if missing:
        item_ids = [ln["item_id"] for ln in missing]
        items = (await session.exec(select(Item).where(Item.id.in_(item_ids)))).all()
        names = {str(it.id): it.name for it in items}
        unnamed = [names.get(str(ln["item_id"]), str(ln["item_id"])) for ln in missing]
        raise ValueError(f"Items need a supplier: {', '.join(unnamed)}")

    items_by_id: dict[UUID, Item] = {}
    units_by_id: dict[UUID, str] = {}
    for ln in lines:
        item = (
            await session.exec(
                select(Item).where(Item.id == ln["item_id"], Item.business_id == business_id)
            )
        ).one_or_none()
        if item is None:
            raise LookupError(f"Item '{ln['item_id']}' not found")
        from app.models.inventory import ItemType as _IT

        if item.item_type == _IT.SELLABLE:
            raise ValueError(
                f"Cannot purchase sellable-only item '{item.name}' — "
                "order its raw-material components instead."
            )
        if item.unit_id is None:
            raise ValueError(f"Item '{item.name}' has no unit assigned.")
        unit = (await session.exec(select(Unit).where(Unit.id == item.unit_id))).one_or_none()
        if unit is None:
            raise LookupError(f"Item '{item.name}' references a missing unit.")
        items_by_id[item.id] = item
        units_by_id[item.id] = unit.code

    catalogue_rows = (
        (
            await session.exec(
                select(SupplierItem).where(
                    SupplierItem.supplier_id.in_(list(supplier_ids)),
                    SupplierItem.item_id.in_([ln["item_id"] for ln in lines]),
                )
            )
        ).all()
        if supplier_ids
        else []
    )
    catalogue = {(r.supplier_id, r.item_id): r for r in catalogue_rows}

    # ── create requisition + lines ──────────────────────────────────────
    requisition = Requisition(
        business_id=business_id,
        store_id=store_id,
        created_by=created_by,
        notes=notes,
        expected_at=expected_at,
        idempotency_key=idempotency_key,
    )
    session.add(requisition)
    await session.flush()

    # Group by supplier; merge duplicate (supplier, item) pairs by summing qty.
    grouped: dict[UUID, dict[UUID, dict[str, Any]]] = {}
    for ln in lines:
        sid, iid = ln["supplier_id"], ln["item_id"]
        qty = Decimal(str(ln["qty"]))
        if qty <= 0:
            raise ValueError("Quantity must be a positive number")
        bucket = grouped.setdefault(sid, {})
        if iid in bucket:
            bucket[iid]["qty"] = bucket[iid]["qty"] + qty
        else:
            bucket[iid] = {"qty": qty}

    order_date = datetime.now(UTC).date().isoformat()
    delivery_requested = expected_at.date().isoformat() if expected_at else None
    created_pos: list[PurchaseOrder] = []
    created_msgs: list[SupplierMessage] = []
    flagged_names: list[str] = []

    for supplier_id, items_map in grouped.items():
        # Same-requisition append: reuse an unfulfilled PO only if this very
        # requisition already produced one (re-submit path); otherwise new.
        po = (
            await session.exec(
                select(PurchaseOrder).where(
                    PurchaseOrder.requisition_id == requisition.id,
                    PurchaseOrder.supplier_id == supplier_id,
                    PurchaseOrder.status.in_(_APPENDABLE),
                )
            )
        ).one_or_none()
        if po is None:
            po_number = await _next_po_number(session, business_id)
            po = PurchaseOrder(
                business_id=business_id,
                store_id=store_id,
                supplier_id=supplier_id,
                po_number=po_number,
                status=PurchaseOrderStatus.UNFULFILLED,
                notes=notes,
                ordered_at=datetime.now(UTC),
                ordered_by=created_by,
                expected_at=expected_at,
                requisition_id=requisition.id,
                idempotency_key=idempotency_key,
            )
            session.add(po)
            await session.flush()

        payload_entries: list[dict[str, Any]] = []
        for item_id, agg in items_map.items():
            item = items_by_id[item_id]
            row = catalogue.get((supplier_id, item_id))
            if row is not None and row.price is not None:
                unit_price, unconfirmed = row.price, False
            else:
                # Buyer-side reference only — never copied to the PO.
                if item.unit_cost is not None:
                    unit_price, unconfirmed = item.unit_cost, True
                else:
                    unit_price, unconfirmed = Decimal("0"), True
            if unconfirmed:
                flagged_names.append(item.name)

            rline = RequisitionLine(
                requisition_id=requisition.id,
                item_id=item_id,
                qty=agg["qty"],
                supplier_id=supplier_id,
                unit_price_snapshot=unit_price if not unconfirmed or row is not None else None,
                price_unconfirmed=unconfirmed,
                supplier_assignment_source=AssignmentSource.MANUAL_PER_ITEM,
            )
            session.add(rline)

            existing_line = (
                await session.exec(
                    select(PurchaseOrderLine).where(
                        PurchaseOrderLine.purchase_order_id == po.id,
                        PurchaseOrderLine.item_id == item_id,
                    )
                )
            ).one_or_none()
            if existing_line is None:
                session.add(
                    PurchaseOrderLine(
                        purchase_order_id=po.id,
                        item_id=item_id,
                        quantity_ordered=agg["qty"],
                        quantity_received=Decimal("0.000"),
                        unit=units_by_id[item_id],
                    )
                )
            else:
                existing_line.quantity_ordered = existing_line.quantity_ordered + agg["qty"]
                session.add(existing_line)
            payload_entries.append(
                {
                    "name": item.name,
                    "qty": agg["qty"],
                    "unit": units_by_id[item_id],
                }
            )

        session.add(po)
        created_pos.append(po)

        payload = build_whatsapp_payload(
            po=po,
            supplier=suppliers[supplier_id],
            lines=payload_entries,
            restaurant_name=restaurant_name,
            order_date=order_date,
            delivery_requested_date=delivery_requested,
            notes=notes,
        )
        if payload is not None:
            created_msgs.append(
                SupplierMessage(
                    po_id=po.id,
                    direction=MessageDirection.OUTBOUND,
                    channel=MessageChannel.WHATSAPP,
                    payload=payload,
                    status=MessageStatus.READY,
                )
            )
    for msg in created_msgs:
        session.add(msg)
    await session.flush()
    return requisition, created_pos, created_msgs, sorted(set(flagged_names))


async def regenerate_payload(
    session: AsyncSession, *, po_id: UUID, business_id: UUID, restaurant_name: str
) -> SupplierMessage | None:
    """Rebuild a PO's WhatsApp payload after its lines changed.

    Upserts the (po_id, whatsapp, outbound) message row back to ``ready`` —
    pure data prep, no network call.
    """
    po = (
        await session.exec(
            select(PurchaseOrder).where(
                PurchaseOrder.id == po_id, PurchaseOrder.business_id == business_id
            )
        )
    ).one_or_none()
    if po is None:
        raise LookupError("Purchase order not found")
    supplier = (await session.exec(select(Supplier).where(Supplier.id == po.supplier_id))).one()
    polines = (
        await session.exec(
            select(PurchaseOrderLine).where(PurchaseOrderLine.purchase_order_id == po.id)
        )
    ).all()
    entries: list[dict[str, Any]] = []
    for pl in polines:
        item = (await session.exec(select(Item).where(Item.id == pl.item_id))).one()
        entries.append(
            {
                "name": item.name,
                "qty": pl.quantity_ordered,
                "unit": pl.unit,
            }
        )
    session.add(po)

    payload = build_whatsapp_payload(
        po=po,
        supplier=supplier,
        lines=entries,
        restaurant_name=restaurant_name,
        order_date=po.ordered_at.date().isoformat(),
        delivery_requested_date=po.expected_at.date().isoformat() if po.expected_at else None,
        notes=po.notes,
    )
    if payload is None:
        return None
    existing = (
        await session.exec(
            select(SupplierMessage).where(
                SupplierMessage.po_id == po.id,
                SupplierMessage.channel == MessageChannel.WHATSAPP,
                SupplierMessage.direction == MessageDirection.OUTBOUND,
            )
        )
    ).one_or_none()
    if existing is None:
        msg = SupplierMessage(
            po_id=po.id,
            direction=MessageDirection.OUTBOUND,
            channel=MessageChannel.WHATSAPP,
            payload=payload,
            status=MessageStatus.READY,
        )
        session.add(msg)
        await session.flush()
        return msg
    existing.payload = payload
    existing.status = MessageStatus.READY
    session.add(existing)
    await session.flush()
    return existing
