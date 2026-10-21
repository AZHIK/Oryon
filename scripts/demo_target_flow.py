#!/usr/bin/env python3
# /// script
# requires-python = ">=3.12,<3.14"
# dependencies = [
#     "sqlmodel>=0.0.22",
#     "asyncpg>=0.30.0",
#     "structlog>=24.4.0",
#     "pydantic-settings>=2.6.0",
# ]
# ///
"""Demonstrate the target-based production flow on real (seeded) data.

Runs the exact journey from the request — no mocks, no test fixtures:

    1. PLAN    cook enters how many plates are needed
               → app recommends every grocery amount (req × target)
    2. MEASURE cook weighs each line, adjusting anything
               → run A measures exactly, run B pours a little extra oil
    3. CONFIRM cook enters what cooking actually produced
               → system reports above / within / below the ±5% threshold

Two runs on the same recipe show two verdicts: run A hits the plan
(within_threshold), run B falls short (below). Stock moves atomically
through the same service + transaction the API endpoint commits.

Usage:
    uv run scripts/demo_target_flow.py --business-id <uuid> [--recipe 'TZ Pilau Nyama']
    uv run scripts/demo_target_flow.py --business-id <uuid> --target 50 --actual-b 26

Requires scripts/seed_tanzania_recipes.py to have been run first.

Part 2 demonstrates the scheduled-run lifecycle from the Production
Module spec (Tabs 2 + 3): plan a batch (pending, nothing moves) → start
it (inputs deducted instantly) → complete it (actual + waste reason) →
publish it ("Publish to POS & Inventory": output stocked, history
written, verdict computed).
"""

from __future__ import annotations

import argparse
import asyncio
import os
import sys
from decimal import Decimal
from pathlib import Path
from uuid import UUID

SERVICE_DIR = Path(__file__).resolve().parents[1] / "services" / "inventory-service"
sys.path.insert(0, str(SERVICE_DIR))


def parse_args() -> argparse.Namespace:
    ap = argparse.ArgumentParser(description="Demo the target-based production flow.")
    ap.add_argument("--business-id", required=True, help="Business owning the TZ recipes.")
    ap.add_argument("--recipe", default="TZ Pilau Nyama", help="Recipe name to produce.")
    ap.add_argument("--target", default="50", help="Run A target plates (plan met).")
    ap.add_argument("--target-b", default="30", help="Run B target plates (shortfall).")
    ap.add_argument("--actual-b", default="26", help="Run B actual plates achieved.")
    ap.add_argument("--inventory-db", default=os.getenv(
        "INVENTORY_DB_URL", "postgresql://oryonfoods:oryonfoods@localhost:5434/oryonfoods_inventory"))
    return ap.parse_args()


async def main() -> None:
    args = parse_args()
    business_id = UUID(args.business_id)

    # Point the app at the inventory DB BEFORE importing it (same mechanism
    # the test-suite uses to bind the engine — see tests/conftest.py).
    db_url = args.inventory_db
    if db_url.startswith("postgresql://"):
        db_url = "postgresql+asyncpg://" + db_url[len("postgresql://"):]
    os.environ["DB_URL"] = db_url

    from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine
    from sqlmodel import select
    from sqlmodel.ext.asyncio.session import AsyncSession

    from app.models.inventory import Item, Recipe, StockLevel
    from app.models.units import Unit
    from app.schemas.production import (
        DEFAULT_YIELD_TOLERANCE_PERCENT,
        evaluate_yield,
    )
    from app.services.production_service import (
        plan_production_quantities,
        record_production_event,
    )
    from app.services.run_service import (
        complete_run,
        create_run,
        publish_run,
        start_run,
    )

    engine = create_async_engine(db_url)
    # Same session semantics as the API (see app/core/database.py):
    # objects stay readable after the service's internal commit.
    factory = async_sessionmaker(
        bind=engine, class_=AsyncSession, expire_on_commit=False
    )

    async with factory() as db:
        recipe = (await db.exec(select(Recipe).where(
            Recipe.business_id == business_id, Recipe.name == args.recipe
        ))).one_or_none()
        if recipe is None:
            raise SystemExit(f"Recipe {args.recipe!r} not found — run seed_tanzania_recipes.py first.")
        units = {u.id: u.code for u in (await db.exec(select(Unit))).all()}

        async def stock_of(item_id: UUID, store_id: UUID) -> Decimal:
            lvl = (await db.exec(select(StockLevel).where(
                StockLevel.item_id == item_id, StockLevel.store_id == store_id
            ))).one_or_none()
            return lvl.current_quantity if lvl else Decimal("0.000")

        async def run(target: Decimal, actual: Decimal | None,
                      tweak: dict[str, Decimal] | None = None, label: str = "") -> None:
            print(f"\n{'═' * 68}\n{label}: target {target} plates of {recipe.name}\n{'═' * 68}")
            plan_recipe, sellable, lines = await plan_production_quantities(
                db, business_id, recipe.id, target)

            # 1. PLAN — recommended amounts (batch totals ÷ yield × target).
            print("  1) PLAN — recommended amounts (per-plate × target):")
            batch = plan_recipe.target_yield_quantity or Decimal("1")
            planned: dict[UUID, Decimal] = {}
            for comp, item in lines:
                qty = (comp.quantity_required * target / batch).quantize(
                    Decimal("0.001"))
                planned[item.id] = qty
                on_hand = await stock_of(item.id, sellable.store_id)
                print(f"     {item.name:<34} {qty:>8} {units.get(item.unit_id, ''):<4}"
                      f"  (in stock: {on_hand})")

            # Leading ingredient = the bulk line (what hits the scale first).
            leading = max(lines, key=lambda pair: planned[pair[1].id])[1]

            # 2. MEASURE — adjustable; the cook may tweak any line.
            measured = dict(planned)
            if tweak:
                by_name = {item.name: item.id for _, item in lines}
                for name, qty in tweak.items():
                    measured[by_name[name]] = qty
                    print(f"  2) MEASURE — cook adjusted {name}: {planned[by_name[name]]} → {qty}")
            if not tweak:
                print("  2) MEASURE — cook weighs every line exactly as recommended.")
            print(f"     leading ingredient on the scale: {leading.name} = {measured[leading.id]}")

            # 3. CONFIRM — actual achieved; server computes the verdict.
            event = await record_production_event(
                db, business_id, recipe.id,
                leading_item_id=leading.id,
                leading_quantity_used=measured[leading.id],
                target_output_quantity=target,
                components_override=measured,
                actual_output_quantity=actual,
            )
            goal = event.target_output_quantity or event.suggested_output_quantity
            status, variance, pct = evaluate_yield(
                actual=event.actual_output_quantity, goal=goal,
                tolerance_percent=DEFAULT_YIELD_TOLERANCE_PERCENT)
            actual_out = actual if actual is not None else event.suggested_output_quantity
            print(f"  3) CONFIRM — achieved {actual_out} vs target {goal} "
                  f"(±{DEFAULT_YIELD_TOLERANCE_PERCENT}% band):")
            print(f"     verdict: {status.value}  (variance {variance}, {pct}%)")

            plates = await stock_of(sellable.id, sellable.store_id)
            print(f"     stock now: {sellable.name} = {plates} plates")

        await run(Decimal(args.target), Decimal(args.target),
                  label=f"RUN A ({args.recipe})")
        await run(Decimal(args.target_b), Decimal(args.actual_b),
                  tweak={"TZ Mafuta ya Kupikia (Cooking Oil)": Decimal("0.950")},
                  label=f"RUN B ({args.recipe}, shortfall + extra oil)")

        print(f"\n{'═' * 68}\nRUN C (scheduled batch lifecycle: Wali Maharage × 20)\n{'═' * 68}")
        wali = (await db.exec(select(Recipe).where(
            Recipe.business_id == business_id, Recipe.name == "TZ Wali Maharage"
        ))).one_or_none()
        if wali is None:
            print("  (TZ Wali Maharage not seeded — skipping run demo.)")
        else:
            run = await create_run(db, business_id, wali.id, Decimal("20"))
            print(f"  1) PLAN — run {run.id} pending: target 20 plates, "
                  "nothing deducted.")
            rice_id = next(
                item.id for comp, item in
                (await plan_production_quantities(db, business_id, wali.id, Decimal("20")))[2]
                if item.name == "TZ Mchele (Rice)")
            run = await start_run(
                db, business_id, run.id,
                leading_item_id=rice_id,
                leading_quantity_used=Decimal("4.000"))
            print("  2) START — in_progress: 4kg rice + scaled lines deducted "
                  "instantly; output NOT stocked yet.")
            run = await complete_run(
                db, business_id, run.id,
                actual_output_quantity=Decimal("19"),
                waste_reason="coconut milk spilt while simmering")
            print("  3) COMPLETE — actual 19 vs target 20, waste reason kept; "
                  "still nothing sellable.")
            event = await publish_run(db, business_id, run.id)
            status, variance, pct = evaluate_yield(
                actual=event.actual_output_quantity,
                goal=event.target_output_quantity,
                tolerance_percent=DEFAULT_YIELD_TOLERANCE_PERCENT)
            print(f"  4) PUBLISH — {event.actual_output_quantity} plates stocked "
                  f"(POS can sell), history {event.id}:")
            print(f"     verdict: {status.value}  (variance {variance}, {pct}%), "
                  f"waste: {event.waste_reason}")

        n = len((await db.exec(select(Recipe).where(Recipe.id == recipe.id))).all())
        print(f"\nDone — {n} recipe row(s) for {args.recipe!r}; all runs committed atomically.")

    await engine.dispose()


if __name__ == "__main__":
    asyncio.run(main())
