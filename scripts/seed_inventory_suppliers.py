#!/usr/bin/env python3
# /// script
# requires-python = ">=3.12"
# dependencies = ["asyncpg>=0.29"]
# ///
"""Seed suppliers + link inventory items in the TZ recipe restaurant.

Companion to ``scripts/seed_tanzania_recipes.py`` — run that first so the
``TZ `` raw materials / sellables exist, then run this to:

  1. create 5 ``TZ `` suppliers (business-scoped) for the same business,
  2. link every existing ``TZ `` item to its preferred supplier via
     ``item.supplier_id`` (nullable — sellables stay unlinked unless mapped),
  3. create 3 extra ``TZ `` grocery items (salt, sugar, tea leaves) with
     opening stock, one of them deliberately left without a supplier to
     prove the link is optional.

Usage:
    uv run scripts/seed_inventory_suppliers.py
    uv run scripts/seed_inventory_suppliers.py --business-id <uuid> --store-id <uuid>
    uv run scripts/seed_inventory_suppliers.py --force   # re-link + reseed extras

DB connection (defaults match the local docker-compose ports):
    --auth-db / $AUTH_DB_URL         (default localhost:5455/oryonfoods_auth)
    --inventory-db / $INVENTORY_DB_URL  (default localhost:5434/oryonfoods_inventory)

Idempotency: suppliers are matched by (business_id, name). Re-running
without --force keeps existing suppliers and only fills in missing links +
missing extra items. With --force, TZ suppliers are deleted (items become
unlinked via ON DELETE SET NULL) and everything is recreated.
"""

from __future__ import annotations

import argparse
import asyncio
import os
from decimal import Decimal
from uuid import UUID, uuid4

import asyncpg

AUTH_DB_URL = os.getenv(
    "AUTH_DB_URL", "postgresql://oryonfoods:oryonfoods@localhost:5455/oryonfoods_auth"
)
INVENTORY_DB_URL = os.getenv(
    "INVENTORY_DB_URL", "postgresql://oryonfoods:oryonfoods@localhost:5434/oryonfoods_inventory"
)

PREFIX = "TZ "

# (key, name, phone, email, address, notes)
SUPPLIERS = [
    ("agro", "Jumbo Agro Suppliers", "+255711111111", "agro@example.com",
     "Kariakoo, Dar es Salaam", "Dry goods — rice, beans, flour, oil"),
    ("meat", "Ng'ombe Meat Supply", "+255722222222", "meat@example.com",
     "Manzese, Dar es Salaam", "Beef, chicken, fish"),
    ("produce", "Soko Fresh Produce", "+255733333333", "fresh@example.com",
     "Kisutu Market, Dar es Salaam", "Potatoes, onions, tomatoes"),
    ("spices", "Viungo Spices Ltd", "+255744444444", "spices@example.com",
     "Arusha, Tanzania", "Pilau / biryani masala"),
    ("dairy", "Maziwa Dairy Co", "+255755555555", "dairy@example.com",
     "Morogoro Road, Dar es Salaam", "Eggs, coconut milk, yoghurt"),
]

# Raw-material name fragment (without TZ prefix) -> supplier key.
# Matches the names seeded by seed_tanzania_recipes.py.
ITEM_SUPPLIER_MAP = {
    "Mchele (Rice)": "agro",
    "Maharage (Red Beans)": "agro",
    "Unga wa Mahindi (Maize Flour)": "agro",
    "Mafuta ya Kupikia (Cooking Oil)": "agro",
    "Nyama Ng'ombe (Beef)": "meat",
    "Kuku (Chicken)": "meat",
    "Samaki (Fish)": "meat",
    "Viazi (Potatoes)": "produce",
    "Vitunguu (Onions)": "produce",
    "Nyanya (Tomatoes)": "produce",
    "Viungo vya Pilau (Pilau Masala)": "spices",
    "Viungo vya Biryani (Biryani Masala)": "spices",
    "Mayai (Eggs)": "dairy",
    "Tui la Nazi (Coconut Milk)": "dairy",
    "Mtindi (Yoghurt)": "dairy",
}

# Extra grocery items this script owns:
# (key, name, unit_code, category_code, threshold, qty, unit_cost, opening, supplier_key|None)
EXTRA_ITEMS = [
    ("salt", "Chumvi (Salt)", "kg", "dry", "2", "10", "1500", "15.000", "agro"),
    ("sugar", "Sukari (Sugar)", "kg", "dry", "5", "25", "2800", "20.000", "agro"),
    ("tea", "Chai (Tea Leaves)", "kg", "dry", "1", "5", "18000", "4.000", None),
]


def nid() -> UUID:
    return uuid4()


async def resolve_business(auth_conn, business_id: str | None) -> UUID:
    if business_id:
        return UUID(business_id)
    row = await auth_conn.fetchrow(
        "SELECT id, name FROM businesses WHERE business_type='restaurant' AND is_deleted=false LIMIT 1"
    )
    if row is None:
        raise SystemExit("No restaurant business found; pass --business-id explicitly.")
    print(f"Using business {row['name']!r} ({row['id']}).")
    return row["id"]


async def resolve_store(auth_conn, business_id: UUID, store_id: str | None) -> tuple[UUID, str]:
    if store_id:
        row = await auth_conn.fetchrow(
            "SELECT id, name FROM store WHERE id=$1 AND business_id=$2 AND is_deleted=false",
            UUID(store_id), business_id,
        )
        if row is None:
            raise SystemExit(f"Store {store_id} not found in business {business_id}.")
        return row["id"], row["name"]
    row = await auth_conn.fetchrow(
        "SELECT id, name FROM store WHERE business_id=$1 AND is_deleted=false ORDER BY name LIMIT 1",
        business_id,
    )
    if row is None:
        raise SystemExit("Business has no stores; create one (see seed_test_store.py).")
    print(f"Using store {row['name']!r} ({row['id']}).")
    return row["id"], row["name"]


async def ensure_supplier_column(inv_conn) -> None:
    has_col = await inv_conn.fetchval(
        "SELECT 1 FROM information_schema.columns "
        "WHERE table_name='item' AND column_name='supplier_id'"
    )
    if not has_col:
        raise SystemExit(
            "Column item.supplier_id is missing — run migrations first:\n"
            "  cd services/inventory-service && alembic upgrade head"
        )


async def upsert_suppliers(inv_conn, business_id: UUID, force: bool) -> dict[str, UUID]:
    if force:
        # SET NULL keeps items; just drop our suppliers so they are recreated.
        await inv_conn.execute(
            "DELETE FROM supplier WHERE business_id=$1 AND name LIKE 'TZ %'",
            business_id,
        )
    suppliers: dict[str, UUID] = {}
    for key, name, phone, email, address, notes in SUPPLIERS:
        full_name = PREFIX + name
        row = await inv_conn.fetchrow(
            "SELECT id FROM supplier WHERE business_id=$1 AND name=$2",
            business_id, full_name,
        )
        if row is None:
            sid = nid()
            await inv_conn.execute(
                """INSERT INTO supplier
                   (id, business_id, name, phone, email, address_line1, notes, is_deleted)
                   VALUES ($1,$2,$3,$4,$5,$6,$7,false)""",
                sid, business_id, full_name, phone, email, address, notes,
            )
            suppliers[key] = sid
        else:
            suppliers[key] = row["id"]
    print(f"  suppliers: {len(suppliers)}")
    return suppliers


async def link_existing_items(inv_conn, business_id: UUID, store_id: UUID,
                              suppliers: dict[str, UUID]) -> int:
    rows = await inv_conn.fetch(
        "SELECT id, name, supplier_id FROM item "
        "WHERE business_id=$1 AND store_id=$2 AND name LIKE 'TZ %'",
        business_id, store_id,
    )
    linked = 0
    for r in rows:
        bare = r["name"][len(PREFIX):] if r["name"].startswith(PREFIX) else r["name"]
        sup_key = ITEM_SUPPLIER_MAP.get(bare)
        if sup_key is None:
            continue  # sellables / extras without a mapping stay as-is
        want = suppliers[sup_key]
        if r["supplier_id"] != want:
            await inv_conn.execute(
                "UPDATE item SET supplier_id=$1 WHERE id=$2", want, r["id"])
            linked += 1
    print(f"  linked: {linked} TZ items now point at their supplier")
    return linked


async def seed_extra_items(inv_conn, business_id: UUID, store_id: UUID,
                           suppliers: dict[str, UUID], force: bool) -> int:
    units = {r["code"]: r["id"] for r in await inv_conn.fetch("SELECT id, code FROM unit")}
    cats = {r["code"]: r["id"] for r in await inv_conn.fetch("SELECT id, code FROM category")}
    created = 0
    for key, name, ucode, ccode, thr, qty, cost, opening, sup_key in EXTRA_ITEMS:
        full_name = PREFIX + name
        existing = await inv_conn.fetchrow(
            "SELECT id FROM item WHERE business_id=$1 AND store_id=$2 AND name=$3",
            business_id, store_id, full_name,
        )
        if existing is not None:
            if not force:
                continue
            await inv_conn.execute("DELETE FROM stockmovement WHERE item_id=$1", existing["id"])
            await inv_conn.execute("DELETE FROM stocklevel WHERE item_id=$1", existing["id"])
            await inv_conn.execute("DELETE FROM item WHERE id=$1", existing["id"])
        assert ucode in units, f"unit {ucode!r} missing — seed units first"
        assert ccode in cats, f"category {ccode!r} missing — seed categories first"
        iid = nid()
        await inv_conn.execute(
            """INSERT INTO item
               (id, business_id, store_id, name, item_type, unit_id, category_id,
                supplier_id, reorder_threshold, reorder_quantity, unit_cost,
                allow_negative_stock, is_active)
               VALUES ($1,$2,$3,$4,'raw_material'::itemtype,$5,$6,$7,$8,$9,$10,false,true)""",
            iid, business_id, store_id, full_name, units[ucode], cats[ccode],
            suppliers[sup_key] if sup_key else None,
            Decimal(thr), Decimal(qty), Decimal(cost),
        )
        await inv_conn.execute(
            "INSERT INTO stocklevel (id, item_id, store_id, current_quantity) VALUES ($1,$2,$3,$4)",
            nid(), iid, store_id, Decimal(opening),
        )
        await inv_conn.execute(
            """INSERT INTO stockmovement
               (id, item_id, business_id, store_id, quantity_delta,
                movement_type, actor_type, reference_type, reason)
               VALUES ($1,$2,$3,$4,$5,'purchase_received'::movementtype,
                       'system'::actortype,'seed','TZ opening balance')""",
            nid(), iid, business_id, store_id, Decimal(opening),
        )
        created += 1
    print(f"  extras: {created} new TZ grocery items (with stock)")
    return created


async def main() -> None:
    ap = argparse.ArgumentParser(
        description="Seed TZ suppliers + link TZ items to them.")
    ap.add_argument("--business-id", default=None)
    ap.add_argument("--store-id", default=None)
    ap.add_argument("--auth-db", default=AUTH_DB_URL)
    ap.add_argument("--inventory-db", default=INVENTORY_DB_URL)
    ap.add_argument("--force", action="store_true",
                    help="Recreate TZ suppliers and extra items, then relink.")
    args = ap.parse_args()

    auth_conn = await asyncpg.connect(args.auth_db)
    try:
        business_id = await resolve_business(auth_conn, args.business_id)
        store_id, store_name = await resolve_store(auth_conn, business_id, args.store_id)
    finally:
        await auth_conn.close()

    inv_conn = await asyncpg.connect(args.inventory_db)
    try:
        await ensure_supplier_column(inv_conn)
        suppliers = await upsert_suppliers(inv_conn, business_id, args.force)
        await link_existing_items(inv_conn, business_id, store_id, suppliers)
        await seed_extra_items(inv_conn, business_id, store_id, suppliers, args.force)
    finally:
        await inv_conn.close()

    print("\nDone.")
    print(f"  business_id = {business_id}")
    print(f"  store_id    = {store_id} ({store_name})")
    print("  suppliers:")
    for key, sid in suppliers.items():
        print(f"    {PREFIX + dict((s[0], s[1]) for s in SUPPLIERS)[key]}  ({sid})")
    print("\nVerify the links:")
    print(f"  SELECT name, supplier_id FROM item WHERE store_id='{store_id}' AND name LIKE 'TZ %';")


if __name__ == "__main__":
    asyncio.run(main())
