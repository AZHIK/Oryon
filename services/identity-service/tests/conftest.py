"""pytest fixtures — async client, test database, and Redis.

The suite truncates every table between tests, so it must never point at a
database you care about. Set ``TEST_DB_URL`` to a dedicated database whose
name ends in ``_test``; it is created automatically if missing. Without it,
``DB_URL`` is used only when it already points at a ``*_test`` database or
when ``ALLOW_DEV_DB_TESTS=1`` is set explicitly.
"""

import os
from collections.abc import AsyncGenerator
from pathlib import Path
from urllib.parse import urlsplit

# Must happen before the app imports below: the async engine is built from
# DB_URL at import time.
if _test_db_url := os.environ.get("TEST_DB_URL"):
    os.environ["DB_URL"] = _test_db_url

# The suite exercises OTP endpoints end-to-end; never let a developer's .env
# with real provider credentials actually send mail (or SMS) while doing so.
os.environ["EMAIL_PROVIDER"] = "console"
os.environ["SMS_PROVIDER"] = "console"

import pytest  # noqa: E402
import pytest_asyncio  # noqa: E402
import redis.asyncio as aioredis  # noqa: E402
from httpx import ASGITransport, AsyncClient  # noqa: E402
from sqlalchemy import text  # noqa: E402
from sqlalchemy.engine import make_url  # noqa: E402
from sqlmodel.ext.asyncio.session import AsyncSession  # noqa: E402

from app.core.config import get_settings  # noqa: E402
from app.core.database import async_session_factory, engine  # noqa: E402
from app.core.redis_client import close_redis  # noqa: E402
from app.main import app  # noqa: E402

PROJECT_ROOT = Path(__file__).resolve().parents[1]


def _database_name() -> str:
    """Return the database name the suite would truncate."""
    return urlsplit(get_settings().db_url).path.lstrip("/")


def _assert_safe_database() -> None:
    """Abort before touching a database that is not explicitly disposable."""
    name = _database_name()
    if name.endswith("_test"):
        return
    if os.environ.get("ALLOW_DEV_DB_TESTS") == "1":
        return
    raise RuntimeError(
        f"Refusing to run the test suite against database {name!r}: every test "
        "truncates all tables in it. Set TEST_DB_URL to a dedicated database "
        "whose name ends in '_test' (it is created automatically), e.g.\n"
        "  TEST_DB_URL=postgresql+asyncpg://foodlink:foodlink@localhost:5455/"
        "foodlink_auth_test uv run pytest\n"
        "Set ALLOW_DEV_DB_TESTS=1 only if you really intend to wipe that "
        "database."
    )


async def _ensure_test_database(name: str) -> None:
    """Create the dedicated test database if it does not exist yet."""
    if not name.endswith("_test"):
        return

    import asyncpg

    admin_dsn = (
        make_url(get_settings().db_url)
        .set(database="postgres")
        .render_as_string(hide_password=False)
        .replace("+asyncpg", "")
    )
    connection = await asyncpg.connect(admin_dsn)
    try:
        exists = await connection.fetchval("SELECT 1 FROM pg_database WHERE datname = $1", name)
        if not exists:
            await connection.execute(f'CREATE DATABASE "{name}"')
    finally:
        await connection.close()


@pytest_asyncio.fixture(scope="session")
def event_loop():
    """Single event loop for the whole session to avoid asyncpg
    'Future attached to a different loop' errors across fixtures."""
    import asyncio

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
async def _clean_redis() -> AsyncGenerator[None, None]:
    """Flush Redis around each test so rate-limit counters do not leak."""
    settings = get_settings()
    client = aioredis.from_url(settings.redis_url, decode_responses=True)
    await client.flushdb()
    await close_redis()
    yield
    await client.flushdb()
    await close_redis()
    await client.aclose()


@pytest_asyncio.fixture(scope="session", autouse=True)
async def _apply_migrations() -> None:
    """Apply alembic migrations once per test session."""
    import subprocess

    _assert_safe_database()
    await _ensure_test_database(_database_name())

    result = subprocess.run(
        ["alembic", "upgrade", "head"],
        cwd=PROJECT_ROOT,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise RuntimeError(f"alembic upgrade failed: {result.stderr}")


@pytest_asyncio.fixture
async def db_session() -> AsyncGenerator[AsyncSession, None]:
    """Provide an isolated DB session backed by Postgres.

    Uses the alembic-managed schema. Truncates all tables before each test
    to ensure data isolation without re-creating the schema.
    """
    # Truncate all tables before test
    async with engine.begin() as conn:
        await conn.execute(
            text("""
            TRUNCATE TABLE
                user_store_roles,
                user_business_permissions,
                user_business_roles,
                business_role_permissions,
                store_settings,
                store,
                business_roles,
                businesses,
                organizations,
                role_template_permissions,
                role_templates,
                platform_role_permissions,
                user_platform_roles,
                platform_roles,
                user_roles,
                user_group,
                role_permissions,
                roles,
                groups,
                permissions,
                verification_codes,
                refresh_tokens,
                user_sessions,
                trusted_devices,
                login_attempts,
                auth_risk_events,
                users
            RESTART IDENTITY CASCADE;
        """)
        )

    async with async_session_factory() as session:
        yield session

    # Clean up after test
    async with engine.begin() as conn:
        await conn.execute(
            text("""
            TRUNCATE TABLE
                user_store_roles,
                user_business_permissions,
                user_business_roles,
                business_role_permissions,
                store_settings,
                store,
                business_roles,
                businesses,
                organizations,
                role_template_permissions,
                role_templates,
                platform_role_permissions,
                user_platform_roles,
                platform_roles,
                user_roles,
                user_group,
                role_permissions,
                roles,
                groups,
                permissions,
                verification_codes,
                refresh_tokens,
                user_sessions,
                trusted_devices,
                login_attempts,
                auth_risk_events,
                users
            RESTART IDENTITY CASCADE;
        """)
        )


@pytest_asyncio.fixture
async def async_session(db_session: AsyncSession) -> AsyncSession:
    """Alias for db_session — matches the parameter name used by
    platform-role-permission tests and other async-SQLModel tests."""
    return db_session


@pytest_asyncio.fixture
async def redis_client() -> AsyncGenerator[aioredis.Redis, None]:
    """Provide a Redis client connected to the test instance.

    Flushes the database before and after each test to ensure isolation.
    """
    settings = get_settings()
    client = aioredis.from_url(settings.redis_url, decode_responses=True)
    await client.flushdb()
    yield client
    await client.flushdb()
    await client.aclose()
