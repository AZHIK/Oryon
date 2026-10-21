#!/usr/bin/env python3
# /// script
# requires-python = ">=3.12"
# dependencies = ["asyncpg>=0.29"]
# ///
"""Delete a test store and ALL of its seeded data across all services.

Removes (in FK-safe order):
  Inventory: stockmovement, stocklevel, productioneventcomponent,
             productionevent, recipecomponent, recipe, reorder, item,
             SEED suppliers
  POS:       sale_line_items, sales, other_expenses, other_incomes,
             SEED customers
  Identity:  user_store_roles, store_settings, store

Usage:
    uv run scripts/clean_test_store.py --store-id <uuid> [--business-id <uuid>]

    # preview without deleting:
    uv run scripts/clean_test_store.py --store-id <uuid> --dry-run
"""

from __future__ import annotations

import argparse
import asyncio
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__)))

import asyncpg

AUTH_DB_URL = os.getenv(
    "AUTH_DB_URL", "postgresql://oryonfoods:oryonfoods@localhost:5455/oryonfoods_auth"
)
INVENTORY_DB_URL = os.getenv(
    "INVENTORY_DB_URL", "postgresql://oryonfoods:oryonfoods@localhost:5434/oryonfoods_inventory"
)
POS_DB_URL = os.getenv(
    "POS_DB_URL", "postgresql://oryonfoods:oryonfoods@localhost:5435/oryonfoods_pos"
)


async def counts(inv, pos, auth, store_id, business_id) -> dict:
    item_ids = [r["id"] for r in await inv.fetch("SELECT id FROM item WHERE store_id=$1", store_id)]
    sale_ids = [r["id"] for r in await pos.fetch("SELECT id FROM sales WHERE store_id=$1", store_id)]
    out = {
        "inv.items": len(item_ids),
        "inv.movements": await inv.fetchval("SELECT count(*) FROM stockmovement WHERE store_id=$1", store_id),
        "inv.levels": await inv.fetchval("SELECT count(*) FROM stocklevel WHERE store_id=$1", store_id),
        "inv.productions": await inv.fetchval(
            "SELECT count(*) FROM productionevent WHERE store_id=$1", store_id),
        "inv.recipes": await inv.fetchval(
            "SELECT count(*) FROM recipe WHERE sellable_item_id = ANY($1::uuid[])", item_ids) if item_ids else 0,
        "inv.reorders": await inv.fetchval("SELECT count(*) FROM reorder WHERE store_id=$1", store_id),
        "pos.sales": len(sale_ids),
        "pos.lines": await pos.fetchval(
            "SELECT count(*) FROM sale_line_items WHERE sale_id = ANY($1::uuid[])", sale_ids) if sale_ids else 0,
        "pos.expenses": await pos.fetchval(
            "SELECT count(*) FROM other_expenses WHERE store_id=$1", store_id),
        "pos.incomes": await pos.fetchval(
            "SELECT count(*) FROM other_incomes WHERE store_id=$1", store_id),
        "auth.store_roles": await auth.fetchval(
            "SELECT count(*) FROM user_store_roles WHERE store_id=$1", store_id),
    }
    return out


async def main() -> None:
    from uuid import UUID

    ap = argparse.ArgumentParser(description="Delete a test store and all its data.")
    ap.add_argument("--store-id", required=True)
    ap.add_argument("--business-id", default=None)
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--auth-db", default=AUTH_DB_URL)
    ap.add_argument("--inventory-db", default=INVENTORY_DB_URL)
    ap.add_argument("--pos-db", default=POS_DB_URL)
    args = ap.parse_args()

    store_id = UUID(args.store_id)
    auth = await asyncpg.connect(args.auth_db)
    try:
        store = await auth.fetchrow("SELECT id, business_id, name FROM store WHERE id=$1", store_id)
        if store is None:
            raise SystemExit(f"Store {store_id} not found.")
        business_id = UUID(args.business_id) if args.business_id else store["business_id"]
        print(f"Store: {store['name']!r} ({store_id}) in business {business_id}")

        inv = await asyncpg.connect(args.inventory_db)
        pos = await asyncpg.connect(args.pos_db)
        try:
            c = await counts(inv, pos, auth, store_id, business_id)
            for k, v in c.items():
                print(f"  {k:18s} {v}")
            if args.dry_run:
                print("Dry run — nothing deleted.")
                return
            from seed_test_store import delete_store_data
            await delete_store_data(inv, pos, auth, business_id, store_id, prefix="")
        finally:
            await inv.close()
            await pos.close()
    finally:
        await auth.close()


if __name__ == "__main__":
    asyncio.run(main())
