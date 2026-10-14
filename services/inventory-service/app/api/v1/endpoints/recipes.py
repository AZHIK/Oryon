"""Recipe management endpoints — bill-of-materials CRUD (Stage 1).

┌──────────────────────────────────────────────────────────────────────────┐
│ PERMISSION MODEL                                                         │
│                                                                          │
│   POST   /businesses/{business_id}/recipes          → RECIPES_CREATE     │
│   GET    /businesses/{business_id}/recipes          → RECIPES_VIEW       │
│   GET    /businesses/{business_id}/recipes/{id}     → RECIPES_VIEW       │
│   PATCH  /businesses/{business_id}/recipes/{id}     → RECIPES_UPDATE     │
│   POST   /businesses/{business_id}/recipes/{id}/link → RECIPES_UPDATE    │
│   DELETE /businesses/{business_id}/recipes/{id}     → RECIPES_DELETE     │
│                                                                          │
│ Business-context binding is enforced at the shared dependency level      │
│ (``require_business_permission``), not per-endpoint.                     │
│                                                                          │
│ DELETE is a hard delete. A recipe is configuration, not a transaction    │
│ record: nothing in the audit trail or stock tables references it (Stage  │
│ 2 production events will reference the recipe only at execution time,    │
│ recording their own movements), so there is no history to preserve the  │
│ way item soft-delete preserves it. Components die with their header via  │
│ ``ON DELETE CASCADE``.                                                   │
└──────────────────────────────────────────────────────────────────────────┘
"""

from __future__ import annotations

from decimal import Decimal
from typing import Annotated
from uuid import UUID

import structlog
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.exc import IntegrityError
from sqlmodel import select
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.database import get_db
from app.deps.auth import require_business_permission
from app.models.inventory import Item, ItemType, Recipe, RecipeComponent
from app.models.units import Unit
from app.schemas.recipes import (
    RecipeComponentInput,
    RecipeComponentRead,
    RecipeCreate,
    RecipeLink,
    RecipeRead,
    RecipeUpdate,
)

logger = structlog.get_logger(__name__)
router = APIRouter(prefix="/businesses/{business_id}/recipes", tags=["recipes"])

# Item types that may HAVE a recipe (the dish being produced).
_SELLABLE_TYPES = (ItemType.SELLABLE, ItemType.BOTH)
# Item types that may BE an ingredient (stock the kitchen consumes).
_INGREDIENT_TYPES = (ItemType.RAW_MATERIAL, ItemType.BOTH)


async def _get_recipe_or_404(
    business_id: UUID,
    recipe_id: UUID,
    session: AsyncSession,
) -> Recipe:
    """Fetch a recipe header scoped to the business, or 404.

    Scoping by ``business_id`` here (not just the PK) is what stops one
    business from reading/mutating another's recipes by id.
    """
    stmt = select(Recipe).where(
        Recipe.id == recipe_id, Recipe.business_id == business_id
    )
    result = await session.exec(stmt)
    recipe = result.one_or_none()
    if recipe is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Recipe not found"
        )
    return recipe


async def _get_sellable_or_error(
    business_id: UUID,
    sellable_item_id: UUID,
    session: AsyncSession,
) -> Item:
    """Fetch the sellable item, enforcing existence, ownership, and type.

    404 when the item does not exist in this business (wrong id or another
    business's id — deliberately indistinguishable); 422 when it exists but
    is a raw-material-only line that cannot have a recipe.
    """
    stmt = select(Item).where(
        Item.id == sellable_item_id, Item.business_id == business_id
    )
    result = await session.exec(stmt)
    item = result.one_or_none()
    if item is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Sellable item not found in this business",
        )
    if item.item_type not in _SELLABLE_TYPES:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Item '{item.name}' is item_type '{item.item_type.value}' — "
            "only sellable or both items can have a recipe",
        )
    return item


async def _validate_components(
    business_id: UUID,
    components: list[RecipeComponentInput],
    session: AsyncSession,
) -> dict[UUID, Item]:
    """Validate a full ingredient set, returning raw items keyed by id.

    Rejects (all 422): a duplicated ingredient within the payload, an id
    that is not an item of THIS business (nonexistent and cross-business
    ids share one message — the caller cannot probe other businesses'
    catalogs by distinguishing them), and an id pointing at a
    sellable-only item, which the kitchen cannot consume as an ingredient.
    """
    seen: set[UUID] = set()
    for line in components:
        if line.raw_material_item_id in seen:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=f"Ingredient {line.raw_material_item_id} is listed twice — "
                "change the amount instead of adding a second line",
            )
        seen.add(line.raw_material_item_id)

    stmt = select(Item).where(
        Item.id.in_(list(seen)), Item.business_id == business_id
    )
    result = await session.exec(stmt)
    found = {item.id: item for item in result.all()}

    for raw_id in seen:
        item = found.get(raw_id)
        if item is None:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=f"Ingredient item {raw_id} does not exist in this business",
            )
        if item.item_type not in _INGREDIENT_TYPES:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=f"Item '{item.name}' is item_type '{item.item_type.value}' — "
                "only raw_material or both items can be recipe ingredients",
            )
    return found


async def _read_recipes(
    recipes: list[Recipe],
    session: AsyncSession,
) -> list[RecipeRead]:
    """Build full ``RecipeRead`` payloads with resolved ingredient details.

    One bulk pass (components → items → units) regardless of recipe count,
    so listing N recipes costs a constant number of queries, not N+1.
    """
    if not recipes:
        return []

    recipe_ids = [r.id for r in recipes]
    comp_result = await session.exec(
        select(RecipeComponent).where(RecipeComponent.recipe_id.in_(recipe_ids))
    )
    components = list(comp_result.all())

    item_ids = {r.sellable_item_id for r in recipes if r.sellable_item_id is not None} | {
        c.raw_material_item_id for c in components
    }
    item_result = await session.exec(select(Item).where(Item.id.in_(list(item_ids))))
    items = {item.id: item for item in item_result.all()}

    unit_ids = {item.unit_id for item in items.values() if item.unit_id is not None}
    units: dict[UUID, str] = {}
    if unit_ids:
        unit_result = await session.exec(
            select(Unit).where(Unit.id.in_(list(unit_ids)))
        )
        units = {unit.id: unit.code for unit in unit_result.all()}

    comps_by_recipe: dict[UUID, list[RecipeComponentRead]] = {
        r.id: [] for r in recipes
    }
    by_recipe: dict[UUID, Recipe] = {r.id: r for r in recipes}
    for comp in components:
        raw = items[comp.raw_material_item_id]
        target = by_recipe[comp.recipe_id].target_yield_quantity or Decimal("1")
        per_unit = (comp.quantity_required / target).quantize(Decimal("0.001"))
        line_cost = (
            (comp.quantity_required * raw.unit_cost).quantize(Decimal("0.01"))
            if raw.unit_cost is not None
            else None
        )
        comps_by_recipe[comp.recipe_id].append(
            RecipeComponentRead(
                id=comp.id,
                recipe_id=comp.recipe_id,
                raw_material_item_id=comp.raw_material_item_id,
                raw_material_name=raw.name,
                raw_material_unit=units.get(raw.unit_id) if raw.unit_id else "",
                quantity_required=comp.quantity_required,
                quantity_per_unit=per_unit,
                line_cost=line_cost,
            )
        )

    reads = []
    for r in recipes:
        lines = comps_by_recipe[r.id]
        total = sum((c.line_cost for c in lines if c.line_cost is not None),
                    Decimal("0.00")).quantize(Decimal("0.01"))
        target = r.target_yield_quantity or Decimal("1")
        sellable_name = (
            items[r.sellable_item_id].name
            if r.sellable_item_id is not None
            else None
        )
        reads.append(
            RecipeRead(
                id=r.id,
                business_id=r.business_id,
                sellable_item_id=r.sellable_item_id,
                sellable_item_name=sellable_name,
                name=r.name,
                category=r.category,
                target_yield_quantity=r.target_yield_quantity,
                target_yield_unit=r.target_yield_unit,
                total_cost=total,
                cost_per_unit=(total / target).quantize(Decimal("0.01")),
                cost_complete=all(c.line_cost is not None for c in lines),
                created_at=r.created_at,
                updated_at=r.updated_at,
                components=lines,
            )
        )
    return reads


@router.post("", response_model=RecipeRead, status_code=status.HTTP_201_CREATED)
async def create_recipe(
    business_id: UUID,
    body: RecipeCreate,
    session: Annotated[AsyncSession, Depends(get_db)],
    _jwt_biz_id: Annotated[str, Depends(require_business_permission("recipes.create"))],
) -> RecipeRead:
    """Create a recipe header plus its full ingredient set, atomically.

    ``sellable_item_id`` may be omitted for a standalone formula (linked
    later via ``POST /recipes/{id}/link``) — but then ``name`` is required,
    since there is no sellable name to default from. When a sellable IS
    given, a pre-check surfaces "already has a recipe" as a clear 409; the
    ``UNIQUE`` on ``recipe.sellable_item_id`` remains the backstop and an
    ``IntegrityError`` catch maps a lost race to the same 409 (never a raw
    DB error to the caller).
    """
    sellable: Item | None = None
    sellable_name: str | None = None
    if body.sellable_item_id is not None:
        sellable = await _get_sellable_or_error(
            business_id, body.sellable_item_id, session
        )

        existing = await session.exec(
            select(Recipe).where(
                Recipe.business_id == business_id,
                Recipe.sellable_item_id == body.sellable_item_id,
            )
        )
        if existing.one_or_none() is not None:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Item '{sellable.name}' already has a recipe — "
                "update it instead of creating a second one",
            )
    elif not body.name:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="A recipe without a menu item needs a name — "
            "pass 'name' or link it to a sellable item",
        )

    await _validate_components(business_id, body.components, session)

    # Captured BEFORE the commit below: a failed commit + rollback expires
    # every ORM object in this session, and reading `sellable.name` after
    # that would fire a synchronous lazy-load SELECT with no greenlet
    # context (MissingGreenlet). Never touch ORM state past a rollback.
    sellable_name = sellable.name if sellable is not None else body.name
    recipe = Recipe(
        business_id=business_id,
        sellable_item_id=body.sellable_item_id,
        name=(body.name or sellable_name),
        category=body.category,
        target_yield_quantity=body.target_yield_quantity,
        target_yield_unit=body.target_yield_unit,
    )
    session.add(recipe)
    await session.flush()  # recipe.id needed for the component rows below
    for line in body.components:
        session.add(
            RecipeComponent(
                recipe_id=recipe.id,
                raw_material_item_id=line.raw_material_item_id,
                quantity_required=line.quantity_required,
            )
        )
    try:
        await session.commit()
    except IntegrityError as exc:
        await session.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Item '{sellable_name}' already has a recipe — "
            "update it instead of creating a second one",
        ) from exc
    await session.refresh(recipe)

    logger.info(
        "recipe.created",
        recipe_id=str(recipe.id),
        business_id=str(business_id),
        sellable_item_id=str(body.sellable_item_id),
        component_count=len(body.components),
    )
    return (await _read_recipes([recipe], session))[0]


@router.post("/{recipe_id}/link", response_model=RecipeRead)
async def link_recipe(
    business_id: UUID,
    recipe_id: UUID,
    body: RecipeLink,
    session: Annotated[AsyncSession, Depends(get_db)],
    _jwt_biz_id: Annotated[str, Depends(require_business_permission("recipes.update"))],
) -> RecipeRead:
    """Link a standalone recipe to its sellable item (set-once, never moved).

    422 when the recipe is already linked — a recipe produces exactly one
    menu item, so links are never moved between items. 409 when the target
    item already has a recipe.
    """
    recipe = await _get_recipe_or_404(business_id, recipe_id, session)
    if recipe.sellable_item_id is not None:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Recipe '{recipe.name}' is already linked to a menu item — "
            "links are never moved between items",
        )
    sellable = await _get_sellable_or_error(
        business_id, body.sellable_item_id, session
    )
    existing = await session.exec(
        select(Recipe).where(
            Recipe.business_id == business_id,
            Recipe.sellable_item_id == body.sellable_item_id,
        )
    )
    if existing.one_or_none() is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Item '{sellable.name}' already has a recipe — "
            "update it instead of linking a second one",
        )
    sellable_name = sellable.name
    recipe.sellable_item_id = body.sellable_item_id
    session.add(recipe)
    try:
        await session.commit()
    except IntegrityError as exc:
        await session.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Item '{sellable_name}' already has a recipe — "
            "update it instead of linking a second one",
        ) from exc
    await session.refresh(recipe)

    logger.info(
        "recipe.linked",
        recipe_id=str(recipe.id),
        business_id=str(business_id),
        sellable_item_id=str(body.sellable_item_id),
    )
    return (await _read_recipes([recipe], session))[0]


@router.get("", response_model=list[RecipeRead])
async def list_recipes(
    business_id: UUID,
    session: Annotated[AsyncSession, Depends(get_db)],
    _jwt_biz_id: Annotated[str, Depends(require_business_permission("recipes.view"))],
    limit: int = Query(default=20, ge=1, le=100, description="Max recipes per page"),
    offset: int = Query(default=0, ge=0, description="Number of recipes to skip"),
) -> list[RecipeRead]:
    """List this business's recipes, newest first, with resolved ingredients."""
    stmt = (
        select(Recipe)
        .where(Recipe.business_id == business_id)
        .order_by(Recipe.created_at.desc())
        .offset(offset)
        .limit(limit)
    )
    result = await session.exec(stmt)
    recipes = list(result.all())

    logger.info(
        "recipes.listed", business_id=str(business_id), count=len(recipes)
    )
    return await _read_recipes(recipes, session)


@router.get("/{recipe_id}", response_model=RecipeRead)
async def get_recipe(
    business_id: UUID,
    recipe_id: UUID,
    session: Annotated[AsyncSession, Depends(get_db)],
    _jwt_biz_id: Annotated[str, Depends(require_business_permission("recipes.view"))],
) -> RecipeRead:
    """Full detail for one recipe, with resolved ingredient names/units."""
    recipe = await _get_recipe_or_404(business_id, recipe_id, session)
    return (await _read_recipes([recipe], session))[0]


@router.patch("/{recipe_id}", response_model=RecipeRead)
async def update_recipe(
    business_id: UUID,
    recipe_id: UUID,
    body: RecipeUpdate,
    session: Annotated[AsyncSession, Depends(get_db)],
    _jwt_biz_id: Annotated[str, Depends(require_business_permission("recipes.update"))],
) -> RecipeRead:
    """Replace a recipe's component list as a full set (plus optional rename).

    Lines absent from the payload are deleted — the stored set after this
    call is exactly the payload set. Validation is identical to create, so
    an update cannot smuggle in a sellable-only "ingredient" or a
    cross-business reference either.
    """
    recipe = await _get_recipe_or_404(business_id, recipe_id, session)
    await _validate_components(business_id, body.components, session)

    if body.name is not None:
        recipe.name = body.name
    if body.category is not None:
        recipe.category = body.category
    if body.target_yield_quantity is not None:
        recipe.target_yield_quantity = body.target_yield_quantity
    if body.target_yield_unit is not None:
        recipe.target_yield_unit = body.target_yield_unit
    session.add(recipe)
    # Full-set replace: delete-then-insert inside the same transaction, so a
    # failure below rolls the old set back rather than leaving it half-gone.
    existing_result = await session.exec(
        select(RecipeComponent).where(RecipeComponent.recipe_id == recipe.id)
    )
    for old in existing_result.all():
        await session.delete(old)
    # Flush the deletes before inserting the replacement set: same-table
    # INSERTs otherwise flush first and trip the (recipe_id,
    # raw_material_item_id) uniqueness guard on lines the update keeps.
    await session.flush()
    for line in body.components:
        session.add(
            RecipeComponent(
                recipe_id=recipe.id,
                raw_material_item_id=line.raw_material_item_id,
                quantity_required=line.quantity_required,
            )
        )
    try:
        await session.commit()
    except IntegrityError as exc:
        await session.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Recipe update conflicts with an existing record",
        ) from exc
    await session.refresh(recipe)

    logger.info(
        "recipe.updated",
        recipe_id=str(recipe.id),
        business_id=str(business_id),
        component_count=len(body.components),
    )
    return (await _read_recipes([recipe], session))[0]


@router.delete("/{recipe_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_recipe(
    business_id: UUID,
    recipe_id: UUID,
    session: Annotated[AsyncSession, Depends(get_db)],
    _jwt_biz_id: Annotated[str, Depends(require_business_permission("recipes.delete"))],
) -> None:
    """Hard-delete a recipe header; components cascade.

    Hard (not soft) delete is correct here: a recipe is configuration with
    no stock or audit rows referencing it, so there is no history to
    preserve — unlike items, whose historical movements must keep resolving.

    One guard: production history RESTRICTs on the header (Stage 2), so a
    recipe that has ever been produced cannot be deleted out from under its
    records — that surfaces here as a clear 409, not a raw DB error.
    """
    recipe = await _get_recipe_or_404(business_id, recipe_id, session)
    # Captured BEFORE the commit below: a failed commit + rollback expires
    # every ORM object in this session, and reading `recipe.name` after
    # that would fire a synchronous lazy-load SELECT with no greenlet
    # context (MissingGreenlet). Never touch ORM state past a rollback.
    recipe_name = recipe.name
    await session.delete(recipe)
    try:
        await session.commit()
    except IntegrityError as exc:
        await session.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Recipe '{recipe_name}' cannot be deleted — "
            "production events were recorded against it",
        ) from exc

    logger.info(
        "recipe.deleted", recipe_id=str(recipe.id), business_id=str(business_id)
    )
