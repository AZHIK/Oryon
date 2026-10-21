#!/usr/bin/env python3
# /// script
# requires-python = ">=3.12"
# dependencies = ["asyncpg>=0.29"]
# ///
"""Seed 5 classic Tanzanian restaurant recipes into the inventory database.

Dishes (per 1 plate — the recipe unit the production flow scales from):
    1. Pilau Nyama          5. Biryani Kuku
    2. Wali Maharage        (plus all shared raw materials
    3. Ugali Samaki          with opening stock, so the
    4. Chipsi Mayai          plan → measure → confirm demo runs end to end)

Inventory-only: raw materials + sellables + stock levels + opening
movements + recipes. Business/store rows live in the Identity database,
so this script only READS those (to resolve ids) and never writes them —
run scripts/seed_test_store.py first if you need a store created.

Usage:
    # Seed into the first restaurant business's Main Location store:
    uv run scripts/seed_tanzania_recipes.py

    # Pick business + store explicitly:
    uv run scripts/seed_tanzania_recipes.py --business-id <uuid> --store-id <uuid>

    # Wipe this script's rows for the store, then reseed:
    uv run scripts/seed_tanzania_recipes.py --store-id <uuid> --business-id <uuid> --force

DB connection (defaults match the local docker-compose ports):
    --auth-db / $AUTH_DB_URL         (default localhost:5455/oryonfoods_auth)
    --inventory-db / $INVENTORY_DB_URL  (default localhost:5434/oryonfoods_inventory)

Idempotency: every row this script owns is prefixed "TZ ". Re-running
refuses when TZ rows already exist for the store (pass --force to wipe
+ reseed). Pair with scripts/demo_target_flow.py to watch the
target-based production flow work on this data.
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

# (key, name, item_type, unit_code, category_code,
#  reorder_threshold, reorder_quantity, unit_cost_TZS, opening_qty)
RAW_MATERIALS = [
    ("rice", "Mchele (Rice)", "kg", "dry", "10", "50", "3200", "60.000"),
    ("beef", "Nyama Ng'ombe (Beef)", "kg", "meat", "5", "20", "14000", "25.000"),
    ("chicken", "Kuku (Chicken)", "kg", "meat", "5", "20", "11000", "25.000"),
    ("fish", "Samaki (Fish)", "kg", "meat", "5", "20", "12000", "20.000"),
    ("maize_flour", "Unga wa Mahindi (Maize Flour)", "kg", "dry", "10", "40", "2500", "40.000"),
    ("beans", "Maharage (Red Beans)", "kg", "dry", "8", "30", "4000", "30.000"),
    ("potatoes", "Viazi (Potatoes)", "kg", "produce", "10", "40", "1800", "40.000"),
    ("eggs", "Mayai (Eggs)", "unit", "dairy", "30", "120", "400", "200.000"),
    ("oil", "Mafuta ya Kupikia (Cooking Oil)", "l", "dry", "5", "20", "7500", "30.000"),
    ("onion", "Vitunguu (Onions)", "kg", "produce", "5", "20", "2000", "20.000"),
    ("tomato", "Nyanya (Tomatoes)", "kg", "produce", "5", "20", "3000", "20.000"),
    ("coconut", "Tui la Nazi (Coconut Milk)", "l", "dairy", "3", "10", "5000", "10.000"),
    ("yoghurt", "Mtindi (Yoghurt)", "l", "dairy", "3", "10", "4000", "10.000"),
    ("pilau_masala", "Viungo vya Pilau (Pilau Masala)", "kg", "dry", "0.5", "2", "30000", "3.000"),
    ("biryani_masala", "Viungo vya Biryani (Biryani Masala)", "kg", "dry", "0.5", "2", "32000", "3.000"),
]

# (key, name, unit_cost_TZS, selling_price_TZS) — counted in "unit" (plates),
# opening 0 so the demo's produced counts are easy to follow.
SELLABLES = [
    ("pilau", "Pilau Nyama (Plate)", "5500", "8000.00"),
    ("wali_maharage", "Wali Maharage (Plate)", "4000", "6000.00"),
    ("ugali_samaki", "Ugali Samaki (Plate)", "6500", "10000.00"),
    ("chipsi_mayai", "Chipsi Mayai (Plate)", "4500", "7000.00"),
    ("biryani", "Biryani Kuku (Plate)", "8000", "12000.00"),
]

# (recipe name, sellable key, category, batch yield qty, batch yield unit,
#  [(raw key, TOTAL qty for the batch)])
# Batch formulas: component totals are written for the stated yield —
# per-plate shares are identical to the old per-unit recipes.
RECIPES = [
    ("Pilau Nyama", "pilau", "finished", "50", "portions", [
        ("rice", "10.000"), ("beef", "7.500"), ("oil", "1.500"),
        ("onion", "2.000"), ("tomato", "2.500"), ("pilau_masala", "0.250"),
    ]),
    ("Wali Maharage", "wali_maharage", "finished", "50", "portions", [
        ("rice", "10.000"), ("beans", "6.000"), ("coconut", "5.000"),
        ("oil", "1.000"), ("onion", "1.500"),
    ]),
    ("Ugali Samaki", "ugali_samaki", "finished", "50", "portions", [
        ("maize_flour", "12.500"), ("fish", "12.500"), ("tomato", "4.000"),
        ("oil", "1.500"), ("onion", "2.000"),
    ]),
    ("Chipsi Mayai", "chipsi_mayai", "finished", "50", "portions", [
        ("potatoes", "17.500"), ("eggs", "100"), ("oil", "5.000"),
        ("tomato", "2.500"), ("onion", "1.500"),
    ]),
    ("Biryani Kuku", "biryani", "finished", "50", "portions", [
        ("rice", "10.000"), ("chicken", "10.000"), ("yoghurt", "2.500"),
        ("oil", "1.500"), ("onion", "2.500"), ("biryani_masala", "0.250"),
    ]),
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


async def tz_row_count(inv_conn, store_id: UUID) -> int:
    return await inv_conn.fetchval(
        "SELECT count(*) FROM item WHERE store_id=$1 AND name LIKE 'TZ %'", store_id
    )


async def delete_tz_rows(inv_conn, store_id: UUID) -> None:
    """Remove this script's rows for the store (FK-safe order)."""
    item_ids = [r["id"] for r in await inv_conn.fetch(
        "SELECT id FROM item WHERE store_id=$1 AND name LIKE 'TZ %'", store_id)]
    if not item_ids:
        print("  nothing to wipe.")
        return
    await inv_conn.execute(
        "DELETE FROM stockmovement WHERE item_id = ANY($1::uuid[])", item_ids)
    await inv_conn.execute(
        "DELETE FROM stocklevel WHERE item_id = ANY($1::uuid[])", item_ids)
    await inv_conn.execute(
        "DELETE FROM productioneventcomponent WHERE raw_material_item_id = ANY($1::uuid[])",
        item_ids)
    pe_ids = [r["id"] for r in await inv_conn.fetch(
        "SELECT id FROM productionevent WHERE store_id=$1", store_id)]
    if pe_ids:
        await inv_conn.execute(
            "DELETE FROM productionevent WHERE id = ANY($1::uuid[])", pe_ids)
    await inv_conn.execute(
        "DELETE FROM recipecomponent WHERE raw_material_item_id = ANY($1::uuid[])", item_ids)
    rids = [r["id"] for r in await inv_conn.fetch(
        "SELECT id FROM recipe WHERE sellable_item_id = ANY($1::uuid[])", item_ids)]
    if rids:
        await inv_conn.execute("DELETE FROM recipe WHERE id = ANY($1::uuid[])", rids)
    await inv_conn.execute(
        "DELETE FROM reorder WHERE store_id=$1 AND item_id = ANY($2::uuid[])", store_id, item_ids)
    await inv_conn.execute("DELETE FROM item WHERE store_id=$1 AND name LIKE 'TZ %'", store_id)
    print(f"  wiped {len(item_ids)} TZ items (+ their stock, recipes, history).")


async def seed(inv_conn, business_id: UUID, store_id: UUID) -> dict:
    units = {r["code"]: r["id"] for r in await inv_conn.fetch("SELECT id, code FROM unit")}
    cats = {r["code"]: r["id"] for r in await inv_conn.fetch("SELECT id, code FROM category")}

    items: dict[str, UUID] = {}

    async def add_item(key: str, name: str, itype: str, ucode: str, ccode: str,
                       thr: str, qty: str, cost: str, price: str | None, opening: str) -> None:
        assert ucode in units, f"unit {ucode!r} missing — seed units first"
        assert ccode in cats, f"category {ccode!r} missing — seed categories first"
        iid = nid()
        await inv_conn.execute(
            """INSERT INTO item
               (id, business_id, store_id, name, item_type, unit_id, category_id,
                reorder_threshold, reorder_quantity, unit_cost, selling_price,
                allow_negative_stock, is_active)
               VALUES ($1,$2,$3,$4,$5::itemtype,$6,$7,$8,$9,$10,$11,false,true)""",
            iid, business_id, store_id, PREFIX + name, itype, units[ucode], cats[ccode],
            Decimal(thr), Decimal(qty), Decimal(cost),
            Decimal(price) if price else None,
        )
        await inv_conn.execute(
            "INSERT INTO stocklevel (id, item_id, store_id, current_quantity) VALUES ($1,$2,$3,$4)",
            nid(), iid, store_id, Decimal(opening),
        )
        mtype = "purchase_received" if itype == "raw_material" else "manual_adjustment"
        await inv_conn.execute(
            """INSERT INTO stockmovement
               (id, item_id, business_id, store_id, quantity_delta,
                movement_type, actor_type, reference_type, reason)
               VALUES ($1,$2,$3,$4,$5,$6::movementtype,'system'::actortype,'seed','TZ opening balance')""",
            nid(), iid, business_id, store_id, Decimal(opening), mtype,
        )
        items[key] = iid

    for key, name, ucode, ccode, thr, qty, cost, opening in RAW_MATERIALS:
        await add_item(key, name, "raw_material", ucode, ccode, thr, qty, cost, None, opening)
    for key, name, cost, price in SELLABLES:
        await add_item(key, name, "sellable", "unit", "mains", "5", "20", cost, price, "0.000")
    print(f"  items: {len(items)} (15 raw + 5 sellables, with stock + opening movements)")

    recipes: dict[str, UUID] = {}
    for name, sell_key, category, batch_qty, batch_unit, comps in RECIPES:
        rid = nid()
        await inv_conn.execute(
            """INSERT INTO recipe
               (id, business_id, sellable_item_id, name, category,
                target_yield_quantity, target_yield_unit)
               VALUES ($1,$2,$3,$4,$5,$6,$7)""",
            rid, business_id, items[sell_key], PREFIX + name, category,
            Decimal(batch_qty), batch_unit,
        )
        for comp_key, qty in comps:
            await inv_conn.execute(
                "INSERT INTO recipecomponent (id, recipe_id, raw_material_item_id, quantity_required)"
                " VALUES ($1,$2,$3,$4)",
                nid(), rid, items[comp_key], Decimal(qty),
            )
        recipes[name] = rid
    print(f"  recipes: {len(recipes)}")
    return {"items": items, "recipes": recipes}


async def main() -> None:
    ap = argparse.ArgumentParser(description="Seed 5 Tanzanian restaurant recipes.")
    ap.add_argument("--business-id", default=None)
    ap.add_argument("--store-id", default=None)
    ap.add_argument("--auth-db", default=AUTH_DB_URL)
    ap.add_argument("--inventory-db", default=INVENTORY_DB_URL)
    ap.add_argument("--force", action="store_true", help="Wipe this script's rows, then reseed.")
    args = ap.parse_args()

    auth_conn = await asyncpg.connect(args.auth_db)
    try:
        business_id = await resolve_business(auth_conn, args.business_id)
        store_id, store_name = await resolve_store(auth_conn, business_id, args.store_id)
    finally:
        await auth_conn.close()

    inv_conn = await asyncpg.connect(args.inventory_db)
    try:
        existing = await tz_row_count(inv_conn, store_id)
        if existing:
            if not args.force:
                raise SystemExit(
                    f"Store already has {existing} TZ items. Pass --force to wipe + reseed.")
            await delete_tz_rows(inv_conn, store_id)
        seeded = await seed(inv_conn, business_id, store_id)
    finally:
        await inv_conn.close()

    print("\nDone.")
    print(f"  business_id = {business_id}")
    print(f"  store_id    = {store_id} ({store_name})")
    print("  recipes:")
    for name, rid in seeded["recipes"].items():
        print(f"    {PREFIX + name}  ({rid})")
    print("\nWatch the target flow work on this data:")
    print(f"  uv run scripts/demo_target_flow.py --business-id {business_id} --recipe 'TZ Pilau Nyama'")


if __name__ == "__main__":
    asyncio.run(main())
