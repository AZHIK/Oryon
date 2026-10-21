#!/usr/bin/env python3
# /// script
# requires-python = ">=3.12"
# dependencies = ["asyncpg>=0.29"]
# ///
"""Create a new test store and seed full data for it across ALL services.

Covers every store-scoped / business-scoped table so all store features
can be tested manually (store CRUD, inventory, recipes, production,
reorders, POS sales, customers, finance):

  Identity  (oryonfoods_auth):       store, store_settings (+ optional staff assignment)
  Inventory (oryonfoods_inventory):  supplier, item, stocklevel, stockmovement,
                                     recipe, recipecomponent, productionevent,
                                     productioneventcomponent, reorder
  POS       (oryonfoods_pos):        customers, sales, sale_line_items,
                                     other_expenses, other_incomes

Usage:
    # Seed a brand-new store under the first restaurant business:
    uv run scripts/seed_test_store.py

    # Pick business + name explicitly:
    uv run scripts/seed_test_store.py --business-id <uuid> --store-name "Mbezi Store"

    # Add data to an EXISTING store instead of creating one:
    uv run scripts/seed_test_store.py --store-id <uuid> --business-id <uuid>

    # Assign a staff user (by phone) as Manager of the new store:
    uv run scripts/seed_test_store.py --staff-phone +255712345678

    # Remove everything this script created for a store (see clean script too):
    uv run scripts/seed_test_store.py --delete --store-id <uuid> --business-id <uuid>

DB connection (defaults match the local docker-compose ports):
    --auth-db / $AUTH_DB_URL         (default localhost:5455/oryonfoods_auth)
    --inventory-db / $INVENTORY_DB_URL  (default localhost:5434/oryonfoods_inventory)
    --pos-db / $POS_DB_URL           (default localhost:5435/oryonfoods_pos)

Idempotency: a store named <store-name> is created once per business
(unique constraint). Re-running without --store-id fails fast unless
--force is given (deletes + reseeds). All seeded rows carry a
run-specific prefix so --delete only removes this script's data.
"""

from __future__ import annotations

import argparse
import asyncio
import os
import secrets
import sys
from datetime import datetime, timezone
from decimal import Decimal
from uuid import UUID, uuid4

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

NOW = datetime.now(timezone.utc)


# --------------------------------------------------------------------------
# helpers
# --------------------------------------------------------------------------

def nid() -> UUID:
    return uuid4()


async def fetch_id(conn, table: str, where: str, *args):
    return await conn.fetchval(f"SELECT id FROM {table} WHERE {where}", *args)


# --------------------------------------------------------------------------
# 1. Identity: store + settings (+ optional staff)
# --------------------------------------------------------------------------

async def create_store(conn, business_id: UUID, name: str) -> dict:
    biz = await conn.fetchrow("SELECT id, business_type FROM businesses WHERE id=$1", business_id)
    if biz is None:
        raise SystemExit(f"Business {business_id} not found.")
    if biz["business_type"] != "restaurant":
        print(f"WARNING: business_type={biz['business_type']!r} (expected 'restaurant').")
    existing = await conn.fetchrow(
        "SELECT id FROM store WHERE business_id=$1 AND name=$2", business_id, name
    )
    if existing:
        raise SystemExit(
            f"Store {name!r} already exists for this business ({existing['id']}). "
            "Pass --store-id to seed it, --force to delete+reseed, or another --store-name."
        )
    store_id = nid()
    await conn.execute(
        """INSERT INTO store
           (id, business_id, name, token, location_type, status, country_code,
            city, address, timezone, is_primary, is_deleted)
           VALUES ($1,$2,$3,$4,'restaurant_branch','active','TZ',
                   'Dar es Salaam','Test Road 1','Africa/Dar_es_Salaam',false,false)""",
        store_id, business_id, name, "tst_" + secrets.token_hex(8),
    )
    await conn.execute(
        """INSERT INTO store_settings
           (id, store_id, active, address, email, phone, preferred_currency,
            offer_retail, offer_wholesale, display_prices_inclusive_of_tax, is_deleted)
           VALUES ($1,$2,true,'Test Road 1, Dar es Salaam','teststore@example.com',
                   '+255700000001','TZS',true,false,false,false)""",
        nid(), store_id,
    )
    return {"id": store_id}


async def assign_staff(conn, business_id: UUID, store_id: UUID, phone: str) -> None:
    user_id = await conn.fetchval("SELECT id FROM users WHERE phone=$1", phone)
    if user_id is None:
        print(f"WARNING: no user with phone {phone}; skipping staff assignment.")
        return
    role_id = await conn.fetchval(
        "SELECT id FROM business_roles WHERE business_id=$1 AND name='Manager'", business_id
    )
    if role_id is None:
        print("WARNING: no 'Manager' role in this business; skipping staff assignment.")
        return
    await conn.execute(
        """INSERT INTO user_store_roles (id, user_id, business_id, store_id, business_role_id, is_deleted)
           VALUES ($1,$2,$3,$4,$5,false)
           ON CONFLICT DO NOTHING""",
        nid(), user_id, business_id, store_id, role_id,
    )
    print(f"  staff: user {phone} assigned as Manager")


async def resolve_business(conn, business_id: str | None) -> UUID:
    if business_id:
        return UUID(business_id)
    row = await conn.fetchrow(
        "SELECT id FROM businesses WHERE business_type='restaurant' AND is_deleted=false LIMIT 1"
    )
    if row is None:
        raise SystemExit("No restaurant business found; pass --business-id explicitly.")
    print(f"Using business {row['id']} (first restaurant business).")
    return row["id"]


# --------------------------------------------------------------------------
# 2. Inventory seed
# --------------------------------------------------------------------------

SUPPLIERS = [
    {"key": "agro", "name": "SEED Jumbo Agro Suppliers", "phone": "+255711111111",
     "email": "agro@example.com", "address": "Kariakoo, Dar es Salaam"},
    {"key": "fresh", "name": "SEED Dar Fresh Produce", "phone": "+255722222222",
     "email": "fresh@example.com", "address": "Mzinga, Dar es Salaam"},
]

# (key, name, item_type, unit_code, category_code, reorder_threshold,
#  reorder_quantity, unit_cost, selling_price, opening_qty)
ITEMS = [
    ("rice", "Mchele (Rice)", "raw_material", "kg", "dry", 10, 50, "1800.0000", None, "100.000"),
    ("chicken_raw", "Kuku Mbichi (Raw Chicken)", "raw_material", "kg", "meat", 5, 20, "9500.0000", None, "30.000"),
    ("oil", "Mafuta ya Kupikia (Cooking Oil)", "raw_material", "l", "dry", 5, 20, "6500.0000", None, "25.000"),
    ("tomato", "Nyanya (Tomatoes)", "raw_material", "kg", "produce", 5, 15, "2500.0000", None, "12.000"),
    ("pilau", "Pilau Nyama (Plate)", "sellable", "unit", "mains", 5, 20, "4500.0000", "8000.00", "15.000"),
    ("kuku_choma", "Kuku Choma na Chips", "sellable", "unit", "mains", 5, 15, "9000.0000", "15000.00", "8.000"),
    ("soda", "Soda 300ml", "both", "unit", "drinks", 12, 48, "900.0000", "1500.00", "48.000"),
]

RECIPES = [
    {"key": "pilau", "sellable": "pilau", "name": "Pilau Recipe",
     "components": [("rice", "0.200"), ("chicken_raw", "0.150"), ("oil", "0.050")]},
    {"key": "kuku_choma", "sellable": "kuku_choma", "name": "Kuku Choma Recipe",
     "components": [("chicken_raw", "0.500"), ("oil", "0.050"), ("tomato", "0.100")]},
]


async def seed_inventory(conn, business_id: UUID, store_id: UUID, prefix: str) -> dict:
    units = {r["code"]: r["id"] for r in await conn.fetch("SELECT id, code FROM unit")}
    cats = {r["code"]: r["id"] for r in await conn.fetch("SELECT id, code FROM category")}
    for _, _, _, u, c, *_ in ITEMS:
        assert u in units, f"unit {u!r} missing — run seed_units first"
        assert c in cats, f"category {c!r} missing — run seed_categories first"

    # suppliers (business-scoped, shared; SEED-prefixed so --delete can find them)
    suppliers = {}
    for s in SUPPLIERS:
        sid = await fetch_id(conn, "supplier", "business_id=$1 AND name=$2", business_id, s["name"])
        if sid is None:
            sid = nid()
            await conn.execute(
                """INSERT INTO supplier
                   (id, business_id, name, phone, email, address_line1, notes, is_deleted)
                   VALUES ($1,$2,$3,$4,$5,$6,'Seeded by seed_test_store.py',false)""",
                sid, business_id, s["name"], s["phone"], s["email"], s["address"],
            )
        suppliers[s["key"]] = sid
    print(f"  suppliers: {len(suppliers)}")

    # items + stock levels + opening movements
    items = {}
    for key, name, itype, ucode, ccode, thr, qty, cost, price, opening in ITEMS:
        iid = nid()
        await conn.execute(
            """INSERT INTO item
               (id, business_id, store_id, name, item_type, unit_id, category_id,
                reorder_threshold, reorder_quantity, unit_cost, selling_price,
                allow_negative_stock, is_active)
               VALUES ($1,$2,$3,$4,$5::itemtype,$6,$7,$8,$9,$10,$11,false,true)""",
            iid, business_id, store_id, f"SEED {name}", itype, units[ucode], cats[ccode],
            Decimal(thr), Decimal(qty),
            Decimal(cost), Decimal(price) if price else None,
        )
        await conn.execute(
            "INSERT INTO stocklevel (id, item_id, store_id, current_quantity) VALUES ($1,$2,$3,$4)",
            nid(), iid, store_id, Decimal(opening),
        )
        mtype = "purchase_received" if itype == "raw_material" else "manual_adjustment"
        await conn.execute(
            """INSERT INTO stockmovement
               (id, item_id, business_id, store_id, quantity_delta,
                movement_type, actor_type, reference_type, reason)
               VALUES ($1,$2,$3,$4,$5,$6::movementtype,'system'::actortype,'seed','Opening balance')""",
            nid(), iid, business_id, store_id, Decimal(opening), mtype,
        )
        items[key] = iid
    print(f"  items: {len(items)} (+ stock levels + opening movements)")

    # recipes + components
    recipes = {}
    for r in RECIPES:
        rid = nid()
        await conn.execute(
            "INSERT INTO recipe (id, business_id, sellable_item_id, name) VALUES ($1,$2,$3,$4)",
            rid, business_id, items[r["sellable"]], r["name"],
        )
        for comp_key, qty in r["components"]:
            await conn.execute(
                "INSERT INTO recipecomponent (id, recipe_id, raw_material_item_id, quantity_required)"
                " VALUES ($1,$2,$3,$4)",
                nid(), rid, items[comp_key], Decimal(qty),
            )
        recipes[r["key"]] = rid
    print(f"  recipes: {len(recipes)}")

    # production event: make 20 plates of pilau, rice measured as leading ingredient
    pe_id = nid()
    await conn.execute(
        """INSERT INTO productionevent
           (id, business_id, store_id, recipe_id, leading_component_item_id,
            leading_quantity_used, suggested_output_quantity, actual_output_quantity,
            occurred_at)
           VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)""",
        pe_id, business_id, store_id, recipes["pilau"], items["rice"],
        Decimal("4.000"), Decimal("20.000"), Decimal("20.000"), NOW,
    )
    consumed = {"rice": "4.000", "chicken_raw": "3.000", "oil": "1.000"}
    for comp_key, qty in consumed.items():
        await conn.execute(
            "INSERT INTO productioneventcomponent (id, production_event_id, raw_material_item_id, quantity_consumed)"
            " VALUES ($1,$2,$3,$4)",
            nid(), pe_id, items[comp_key], Decimal(qty),
        )
        await conn.execute(
            """INSERT INTO stockmovement
               (id, item_id, business_id, store_id, quantity_delta,
                movement_type, actor_type, reference_type, reference_id, reason)
               VALUES ($1,$2,$3,$4,$5,'production_input'::movementtype,'system'::actortype,
                       'production',$6,'Pilau production run')""",
            nid(), items[comp_key], business_id, store_id, -Decimal(qty), pe_id,
        )
    # adjust stock levels for consumed inputs + produced output
    for comp_key, qty in consumed.items():
        await conn.execute(
            "UPDATE stocklevel SET current_quantity = current_quantity - $1 WHERE item_id=$2 AND store_id=$3",
            Decimal(qty), items[comp_key], store_id,
        )
    await conn.execute(
        "UPDATE stocklevel SET current_quantity = current_quantity + $1 WHERE item_id=$2 AND store_id=$3",
        Decimal("20.000"), items["pilau"], store_id,
    )
    await conn.execute(
        """INSERT INTO stockmovement
           (id, item_id, business_id, store_id, quantity_delta,
            movement_type, actor_type, reference_type, reference_id, reason)
           VALUES ($1,$2,$3,$4,$5,'production_output'::movementtype,'system'::actortype,
                   'production',$6,'Pilau production run')""",
        nid(), items["pilau"], business_id, store_id, Decimal("20.000"), pe_id,
    )
    print("  production: 1 event (20x Pilau) + input/output movements")

    # reorders: 1 pending, 1 received (credits stock), 1 cancelled
    await conn.execute(
        """INSERT INTO reorder
           (id, business_id, store_id, item_id, supplier_id, quantity, unit,
            unit_cost, status, notes, ordered_at, expected_at)
           VALUES ($1,$2,$3,$4,$5,$6,$7,$8,'pending'::reorderstatus,$9,$10,$11)""",
        nid(), business_id, store_id, items["tomato"], suppliers["fresh"],
        Decimal("10.000"), "kg", Decimal("2500.0000"),
        f"{prefix}: restock tomatoes", NOW, NOW,
    )
    await conn.execute(
        """INSERT INTO reorder
           (id, business_id, store_id, item_id, supplier_id, quantity, unit,
            unit_cost, status, notes, ordered_at, received_at)
           VALUES ($1,$2,$3,$4,$5,$6,$7,$8,'received'::reorderstatus,$9,$10,$11)""",
        nid(), business_id, store_id, items["rice"], suppliers["agro"],
        Decimal("25.000"), "kg", Decimal("1800.0000"),
        f"{prefix}: restock rice", NOW, NOW,
    )
    await conn.execute(
        "UPDATE stocklevel SET current_quantity = current_quantity + $1 WHERE item_id=$2 AND store_id=$3",
        Decimal("25.000"), items["rice"], store_id,
    )
    await conn.execute(
        """INSERT INTO stockmovement
           (id, item_id, business_id, store_id, quantity_delta,
            movement_type, actor_type, reference_type, reason)
           VALUES ($1,$2,$3,$4,$5,'purchase_received'::movementtype,'system'::actortype,
                   'reorder','Rice reorder received')""",
        nid(), items["rice"], business_id, store_id, Decimal("25.000"),
    )
    await conn.execute(
        """INSERT INTO reorder
           (id, business_id, store_id, item_id, supplier_id, quantity, unit,
            unit_cost, status, notes, ordered_at, cancelled_at)
           VALUES ($1,$2,$3,$4,$5,$6,$7,$8,'cancelled'::reorderstatus,$9,$10,$11)""",
        nid(), business_id, store_id, items["oil"], suppliers["agro"],
        Decimal("20.000"), "l", Decimal("6500.0000"),
        f"{prefix}: cancelled oil order", NOW, NOW,
    )
    print("  reorders: 1 pending + 1 received + 1 cancelled")
    return items


# --------------------------------------------------------------------------
# 3. POS seed
# --------------------------------------------------------------------------

CUSTOMERS = [
    {"name": "SEED Amina Juma", "phone": "+255733333333", "email": "amina@example.com"},
    {"name": "SEED Juma Mwinyi", "phone": "+255744444444", "email": "juma@example.com"},
]


async def seed_pos(conn, business_id: UUID, store_id: UUID, items: dict, prefix: str) -> None:
    # customers (business-scoped)
    customers = []
    for c in CUSTOMERS:
        cid = await fetch_id(conn, "customers", "business_id=$1 AND phone=$2", business_id, c["phone"])
        if cid is None:
            cid = nid()
            await conn.execute(
                """INSERT INTO customers
                   (id, business_id, name, phone, email, joined_at, is_deleted)
                   VALUES ($1,$2,$3,$4,$5,$6,false)""",
                cid, business_id, c["name"], c["phone"], c["email"], NOW,
            )
        customers.append(cid)
    print(f"  customers: {len(customers)}")

    prices = {"pilau": Decimal("8000.00"), "kuku_choma": Decimal("15000.00"), "soda": Decimal("1500.00")}

    async def make_sale(client_id: str, status: str, cust_idx: int | None,
                        lines: list[tuple[str, str]], pay: str, reason: str | None = None) -> None:
        sale_id = nid()
        subtotal = sum(Decimal(q) * prices[k] for k, q in lines)
        tax = (subtotal * Decimal("0.18")).quantize(Decimal("0.01"))
        await conn.execute(
            """INSERT INTO sales
               (id, business_id, store_id, client_sale_id, status, subtotal,
                discount_amount, tax_amount, total, payment_method, customer_id,
                occurred_at, voided_at, refunded_at, void_or_refund_reason,
                void_client_action_id, refund_client_action_id, is_time_suspect)
               VALUES ($1,$2,$3,$4,$5::salestatus,$6,0,$7,$8,$9::paymentmethod,$10,$11,$12,$13,$14,$15,$16,false)""",
            sale_id, business_id, store_id, client_id, status, subtotal, tax, subtotal + tax,
            pay, customers[cust_idx] if cust_idx is not None else None, NOW,
            NOW if status in ("voided", "refunded") else None,
            NOW if status == "refunded" else None,
            reason,
            f"{client_id}-void" if status == "voided" else None,
            f"{client_id}-refund" if status == "refunded" else None,
        )
        for item_key, qty in lines:
            line_total = Decimal(qty) * prices[item_key]
            await conn.execute(
                """INSERT INTO sale_line_items
                   (id, sale_id, item_id, quantity, unit_price, discount_amount, line_total)
                   VALUES ($1,$2,$3,$4,$5,0,$6)""",
                nid(), sale_id, items[item_key], Decimal(qty), prices[item_key], line_total,
            )

    await make_sale(f"{prefix}-sale-completed", "completed", 0,
                    [("pilau", "2"), ("soda", "1")], "cash")
    await make_sale(f"{prefix}-sale-voided", "voided", 1,
                    [("kuku_choma", "1")], "mobile_money", reason="Cashier error — wrong item")
    await make_sale(f"{prefix}-sale-refunded", "refunded", 0,
                    [("pilau", "1")], "card", reason="Customer complaint — cold food")
    print("  sales: 1 completed + 1 voided + 1 refunded (+ line items)")

    for i, (cat, amount, desc, payee) in enumerate([
        ("rent", "500000.00", f"{prefix}: shop rent", "Landlord"),
        ("utilities", "85000.00", f"{prefix}: electricity (LUKU)", "TANESCO"),
    ]):
        await conn.execute(
            """INSERT INTO other_expenses
               (id, business_id, store_id, client_expense_id, category, amount,
                description, payee, payment_method, occurred_at, is_deleted)
               VALUES ($1,$2,$3,$4,$5,$6,$7,$8,'cash'::paymentmethod,$9,false)""",
            nid(), business_id, store_id, f"{prefix}-exp-{i}", cat,
            Decimal(amount), desc, payee, NOW,
        )
    await conn.execute(
        """INSERT INTO other_incomes
           (id, business_id, store_id, client_income_id, category, amount,
            description, source, payment_method, occurred_at, is_deleted)
           VALUES ($1,$2,$3,$4,'catering',$5,$6,'Wedding client','mobile_money'::paymentmethod,$7,false)""",
        nid(), business_id, store_id, f"{prefix}-inc-0",
        Decimal("250000.00"), f"{prefix}: catering deposit", NOW,
    )
    print("  finance: 2 expenses + 1 income")


# --------------------------------------------------------------------------
# delete mode (used by --delete/--force)
# --------------------------------------------------------------------------

async def delete_seed_rows(inv_conn, pos_conn, business_id: UUID, store_id: UUID) -> None:
    """Remove seeded inventory + POS rows but KEEP the store itself."""
    item_ids = [r["id"] for r in await inv_conn.fetch(
        "SELECT id FROM item WHERE store_id=$1", store_id)]
    if item_ids:
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
        await inv_conn.execute("DELETE FROM reorder WHERE store_id=$1", store_id)
        await inv_conn.execute("DELETE FROM item WHERE store_id=$1", store_id)
    # Suppliers are business-scoped and shared between stores: only remove
    # ones no remaining reorder references.
    await inv_conn.execute(
        """DELETE FROM supplier
           WHERE business_id=$1 AND name LIKE 'SEED %'
           AND NOT EXISTS (SELECT 1 FROM reorder WHERE reorder.supplier_id = supplier.id)""",
        business_id)

    sale_ids = [r["id"] for r in await pos_conn.fetch(
        "SELECT id FROM sales WHERE store_id=$1", store_id)]
    if sale_ids:
        await pos_conn.execute(
            "DELETE FROM sale_line_items WHERE sale_id = ANY($1::uuid[])", sale_ids)
        await pos_conn.execute("DELETE FROM sales WHERE store_id=$1", store_id)
    await pos_conn.execute("DELETE FROM other_expenses WHERE store_id=$1", store_id)
    await pos_conn.execute("DELETE FROM other_incomes WHERE store_id=$1", store_id)
    # Same for business-scoped customers: keep ones still referenced by any sale
    # (Sale.customer_id is SET NULL on delete, but we don't want to orphan
    # another store's attribution).
    await pos_conn.execute(
        """DELETE FROM customers
           WHERE business_id=$1 AND name LIKE 'SEED %'
           AND NOT EXISTS (SELECT 1 FROM sales WHERE sales.customer_id = customers.id)""",
        business_id)


async def delete_store_data(inv_conn, pos_conn, auth_conn,
                            business_id: UUID, store_id: UUID, prefix: str) -> None:
    await delete_seed_rows(inv_conn, pos_conn, business_id, store_id)
    await auth_conn.execute("DELETE FROM user_store_roles WHERE store_id=$1", store_id)
    await auth_conn.execute("DELETE FROM store_settings WHERE store_id=$1", store_id)
    await auth_conn.execute("DELETE FROM store WHERE id=$1", store_id)
    print(f"Deleted all seeded data for store {store_id} (prefix {prefix!r} rows by store scope).")


# --------------------------------------------------------------------------
# main
# --------------------------------------------------------------------------

async def main() -> None:
    ap = argparse.ArgumentParser(description="Create a test store + seed all its data.")
    ap.add_argument("--business-id", default=None)
    ap.add_argument("--store-id", default=None, help="Reuse existing store instead of creating one.")
    ap.add_argument("--store-name", default="Test Store")
    ap.add_argument("--staff-phone", default=None, help="Assign user with this phone as Manager.")
    ap.add_argument("--prefix", default=None,
                    help="Prefix for client ids/notes. Defaults to a unique 'seedt-xxxxxx' per run "
                         "(client_sale_id is globally unique, so a fixed prefix collides across stores).")
    ap.add_argument("--skip-inventory", action="store_true")
    ap.add_argument("--skip-pos", action="store_true")
    ap.add_argument("--force", action="store_true", help="With --store-id: wipe + reseed that store.")
    ap.add_argument("--delete", action="store_true", help="Delete data for --store-id and exit.")
    ap.add_argument("--auth-db", default=AUTH_DB_URL)
    ap.add_argument("--inventory-db", default=INVENTORY_DB_URL)
    ap.add_argument("--pos-db", default=POS_DB_URL)
    args = ap.parse_args()

    if not args.prefix:
        args.prefix = f"seedt-{secrets.token_hex(3)}"
        print(f"Using run prefix {args.prefix!r} (pass --prefix to override).")

    auth_conn = await asyncpg.connect(args.auth_db)
    try:
        business_id = await resolve_business(auth_conn, args.business_id)

        if args.delete:
            if not args.store_id:
                raise SystemExit("--delete requires --store-id.")
            inv_conn = await asyncpg.connect(args.inventory_db)
            pos_conn = await asyncpg.connect(args.pos_db)
            try:
                await delete_store_data(inv_conn, pos_conn, auth_conn,
                                        business_id, UUID(args.store_id), args.prefix)
            finally:
                await inv_conn.close()
                await pos_conn.close()
            return

        if args.store_id:
            store_id = UUID(args.store_id)
            row = await auth_conn.fetchrow("SELECT id FROM store WHERE id=$1 AND business_id=$2",
                                           store_id, business_id)
            if row is None:
                raise SystemExit(f"Store {store_id} not found in business {business_id}.")
            if args.force:
                inv_conn = await asyncpg.connect(args.inventory_db)
                pos_conn = await asyncpg.connect(args.pos_db)
                try:
                    await delete_seed_rows(inv_conn, pos_conn, business_id, store_id)
                finally:
                    await inv_conn.close()
                    await pos_conn.close()
                print(f"Wiped previous seed data for store {store_id}; reseeding.")
            else:
                # Guard against double-seeding: items have no per-store unique
                # constraint, so reseeding without --force would duplicate rows.
                inv_check = await asyncpg.connect(args.inventory_db)
                try:
                    n_items = await inv_check.fetchval(
                        "SELECT count(*) FROM item WHERE store_id=$1", store_id)
                finally:
                    await inv_check.close()
                if n_items:
                    raise SystemExit(
                        f"Store {store_id} already has {n_items} items. "
                        "Pass --force to wipe + reseed, or use a fresh store.")
                print(f"Seeding existing store {store_id}.")
        else:
            info = await create_store(auth_conn, business_id, args.store_name)
            store_id = info["id"]
            print(f"Created store {store_id} ({args.store_name!r}).")

        if args.staff_phone:
            await assign_staff(auth_conn, business_id, store_id, args.staff_phone)

        items: dict = {}
        if not args.skip_inventory:
            inv_conn = await asyncpg.connect(args.inventory_db)
            try:
                items = await seed_inventory(inv_conn, business_id, store_id, args.prefix)
            finally:
                await inv_conn.close()
        if not args.skip_pos:
            pos_conn = await asyncpg.connect(args.pos_db)
            try:
                if not items:
                    # --skip-inventory: load this store's existing items for sale lines
                    inv_conn = await asyncpg.connect(args.inventory_db)
                    try:
                        rows = await inv_conn.fetch(
                            "SELECT id, name FROM item WHERE store_id=$1", store_id)
                    finally:
                        await inv_conn.close()
                    for r in rows:
                        n = r["name"].replace("SEED ", "")
                        for key, _name, *_ in ITEMS:
                            if _name == n:
                                items[key] = r["id"]
                    if not {"pilau", "kuku_choma", "soda"} <= set(items):
                        raise SystemExit(
                            "Store has no seeded sellable items; run without --skip-inventory first.")
                await seed_pos(pos_conn, business_id, store_id, items, args.prefix)
            finally:
                await pos_conn.close()

        print("\nDone.")
        print(f"  business_id = {business_id}")
        print(f"  store_id    = {store_id}")
        print("Log in with a business-staff token scoped to this business to test store features.")
    finally:
        await auth_conn.close()


if __name__ == "__main__":
    asyncio.run(main())
