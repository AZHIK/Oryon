"""pytest fixtures — async client, test database session (real migrations).

The test database is genuinely separate from dev: ``oryonfoods_inventory_test``
(``TEST_DB_URL``).  The schema is built ONCE per test session by running
``alembic upgrade head`` against it — the same path production uses — instead
of the old ``create_all``/``drop_all``-per-test strategy, which silently hid
migration drift (e.g. the enum case mismatch).  Per-test isolation is achieved
by truncating rows, never by dropping and recreating tables.
"""

import asyncio
import os
import subprocess
import sys
from collections.abc import AsyncGenerator
from pathlib import Path

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from sqlalchemy import text
from sqlalchemy.engine import make_url
from sqlalchemy.ext.asyncio import create_async_engine
from sqlmodel.ext.asyncio.session import AsyncSession

# ── Test database resolution ────────────────────────────────────────────────
# Resolve TEST_DB_URL BEFORE importing any app module so that
# app.core.database (via Settings) binds its engine to the test database,
# never the dev database.  The api-dev container sets TEST_DB_URL; for a
# bare local run we derive <db_url>_test from DB_URL.
if "TEST_DB_URL" not in os.environ:
    _dev_url = os.environ.get(
        "DB_URL",
        "postgresql+asyncpg://oryonfoods:oryonfoods@localhost:5432/oryonfoods_inventory",
    )
    _dev = make_url(_dev_url)
    os.environ["TEST_DB_URL"] = _dev.set(database=f"{_dev.database}_test").render_as_string(
        hide_password=False
    )

TEST_DB_URL = os.environ["TEST_DB_URL"]
PROJECT_ROOT = Path(__file__).resolve().parents[1]

# ── JWT verification key ────────────────────────────────────────────────────
# Every test module signs its tokens with the embedded TEST_PRIVATE_KEY
# keypair (see tests/test_token_verification.py).  Point verification at the
# matching public key so the suite does not depend on whichever deployment
# key happens to sit in the local, git-ignored keys/public.pem.  Without this,
# rotating the identity-service keypair makes every authenticated test fail
# with "Signature verification failed" even though the token is well-formed.
TEST_PUBLIC_KEY = """-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAoeArXtZ+XrZt5klLXLay
TcGOFZCOUZ9tbexpmrdMcXzwxAzxh+ByKOHyJEJ1xXB6hdZZMWV/66rHMG+dx3l8
w8o3woM1Ae/QEz7Yf8Zx1Eu3eqCRE05QzX0c1SfSxrzNQ91czCIRW3vyq2CQ/dnD
3xqFP7asLrfihqYzw2SzSNyoOJo3EAYwv2IdkJJeQepco+WX5OjZBrYOB9YFXySm
o32cT7uT6eIIo1CJFYqCvfK6OeAwoQy92wOJxod1VcPYRBbFU86bTnge2+ymbjpn
nMDUUyF5pl+05raXwrg3pz8ibXjsV+9aGx1Qs1pAd0IMB6b9JegMcRy3SCdUgvcz
/wIDAQAB
-----END PUBLIC KEY-----"""

# Set before importing any app module: app.core.database calls get_settings()
# at import time, and Settings is cached for the whole session.
os.environ["JWT_PUBLIC_KEY"] = TEST_PUBLIC_KEY

# App imports must come AFTER TEST_DB_URL and JWT_PUBLIC_KEY are set.
from app.core.database import async_session_factory, engine  # noqa: E402
from app.main import app  # noqa: E402

APP_TABLES = (
    "item",
    "recipe",
    "recipecomponent",
    "productionevent",
    "productioneventcomponent",
    "stocklevel",
    "stockmovement",
    "processedevent",
    "reorder",
    "supplier",
    "purchaseorder",
    "purchaseorderline",
    "goodsreceipt",
    "goodsreceiptline",
    "requisition",
    "requisitionline",
    "supplieritem",
    "suppliermessage",
    "whatsappconnection",
)


def _ensure_test_database_exists() -> None:
    """Create the test database if it does not already exist (idempotent)."""

    async def _create() -> None:
        url = make_url(TEST_DB_URL)
        admin_engine = create_async_engine(
            url.set(database="postgres"),
            isolation_level="AUTOCOMMIT",
        )
        async with admin_engine.connect() as conn:
            row = await conn.execute(
                text("SELECT 1 FROM pg_database WHERE datname = :name"),
                {"name": url.database},
            )
            if row.scalar() is None:
                await conn.execute(text(f'CREATE DATABASE "{url.database}"'))
        await admin_engine.dispose()

    asyncio.run(_create())


def _run_alembic_upgrade() -> None:
    """Run `alembic upgrade head` against the test database.

    Executed in a subprocess so it is the real Alembic CLI (as in
    deployment) and cannot conflict with pytest-asyncio's event loop.
    """
    env = dict(os.environ)
    env["TEST_DB_URL"] = TEST_DB_URL
    alembic_bin = Path(sys.executable).parent / "alembic"
    subprocess.run(
        [str(alembic_bin), "upgrade", "head"],
        cwd=PROJECT_ROOT,
        env=env,
        check=True,
    )


def _seed_units() -> None:
    """Seed the unit-of-measure taxonomy once per test session.

    Mirrors `_seed_categories()` below — see its docstring for why this uses
    its own engine/event loop rather than the app's shared one.
    """
    from app.db.seed_units import seed_units

    async def _seed() -> None:
        seed_engine = create_async_engine(TEST_DB_URL)
        async with AsyncSession(seed_engine) as session:
            await session.run_sync(lambda sync_session: seed_units(sync_session))
        await seed_engine.dispose()

    asyncio.run(_seed())


def _seed_categories() -> None:
    """Seed the category taxonomy once per test session.

    Seeding is NOT part of the migration itself (see
    ``f1a2b3c4d5e6_create_category_and_migrate_item_category``'s docstring)
    — it's a deliberate, separate step in every environment, exactly like
    running ``scripts/seed_categories.py`` after migrating a real deployment.

    Uses its own engine rather than the app's shared ``engine``/
    ``async_session_factory`` — same reasoning as
    ``_ensure_test_database_exists``'s ``admin_engine``: this runs inside
    its own ``asyncio.run()`` loop, and a connection opened here would
    otherwise be pooled against a now-closed loop once that call returns,
    breaking a later `await` against the shared engine from pytest-asyncio's
    own loop ("Event loop is closed").
    """
    from app.db.seed_categories import seed_categories

    async def _seed() -> None:
        seed_engine = create_async_engine(TEST_DB_URL)
        async with AsyncSession(seed_engine) as session:
            await session.run_sync(lambda sync_session: seed_categories(sync_session))
        await seed_engine.dispose()

    asyncio.run(_seed())


@pytest.fixture(scope="session", autouse=True)
def _migrate_test_database() -> None:
    """Build the test schema with REAL migrations once per test session.

    Replaces the old create_all/drop_all-per-test strategy.  The schema is
    created by `alembic upgrade head` on the separate test database — the
    exact path production uses — so enum-case drift and migration divergence
    can no longer hide behind self-consistent create_all.
    """
    _ensure_test_database_exists()
    _run_alembic_upgrade()
    _seed_categories()
    _seed_units()


@pytest_asyncio.fixture(scope="session")
def event_loop():
    loop = asyncio.new_event_loop()
    yield loop
    loop.close()


@pytest.fixture
async def client() -> AsyncGenerator[AsyncClient, None]:
    """FastAPI test client using ASGI transport (no server needed)."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


@pytest_asyncio.fixture(autouse=True)
async def _clean_tables() -> AsyncGenerator[None, None]:
    """Truncate app tables before each test (schema persists per session).

    The schema is created once by `alembic upgrade head` at session start;
    per-test isolation comes from truncating rows, never from dropping or
    recreating tables.  alembic_version is intentionally left untouched.
    """
    async with engine.begin() as conn:
        await conn.execute(
            text(
                "TRUNCATE TABLE item, recipe, recipecomponent, productionevent, "
                "productioneventcomponent, stocklevel, "
                "stockmovement, processedevent, reorder, supplier, "
                "purchaseorder, purchaseorderline, goodsreceipt, "
                "goodsreceiptline, requisition, requisitionline, "
                "supplieritem, suppliermessage, whatsappconnection "
                "RESTART IDENTITY CASCADE"
            )
        )
    yield


@pytest_asyncio.fixture
async def db_session() -> AsyncGenerator[AsyncSession, None]:
    """Provide an isolated DB session backed by the test database."""
    async with async_session_factory() as session:
        yield session


async def _category_id_by_code(code: str) -> str:
    """Look up a seeded category's id by its stable code.

    Categories are seeded once per test session by `_seed_categories()`
    above, so this just resolves the real (server-generated) id rather than
    hardcoding one in every test.
    """
    from sqlmodel import select

    from app.models.categories import Category

    async with async_session_factory() as session:
        result = await session.exec(select(Category).where(Category.code == code))
        return str(result.one().id)


@pytest_asyncio.fixture
async def produce_category_id() -> str:
    return await _category_id_by_code("produce")


async def _unit_id_by_code(code: str) -> str:
    """Look up a seeded unit's id by its stable code.

    Units are seeded once per test session by `_seed_units()` above, so this
    just resolves the real (server-generated) id rather than hardcoding one
    in every test — mirrors `_category_id_by_code`.
    """
    from sqlmodel import select

    from app.models.units import Unit

    async with async_session_factory() as session:
        result = await session.exec(select(Unit).where(Unit.code == code))
        return str(result.one().id)


@pytest_asyncio.fixture
async def kg_unit_id() -> str:
    return await _unit_id_by_code("kg")


@pytest_asyncio.fixture
async def each_unit_id() -> str:
    return await _unit_id_by_code("unit")
