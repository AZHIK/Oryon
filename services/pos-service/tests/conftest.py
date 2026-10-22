"""pytest fixtures — async client, test database session.

The suite creates and drops every table it touches, so it must never point at
the dev database.  ``TEST_DB_URL`` selects a dedicated ``*_test`` database;
without it the suite refuses to run.
"""

import os
from collections.abc import AsyncGenerator

# Must happen before the app imports below: the engine is built from DB_URL at
# import time.
if _test_db_url := os.environ.get("TEST_DB_URL"):
    os.environ["DB_URL"] = _test_db_url

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from sqlmodel import SQLModel
from sqlmodel.ext.asyncio.session import AsyncSession

from app.db.session import async_session_factory, engine
from app.main import app


def _assert_safe_database() -> None:
    """Abort before dropping tables in a database that is not disposable."""
    from urllib.parse import urlsplit

    from app.core.config import get_settings

    name = urlsplit(get_settings().db_url).path.lstrip("/")
    if name.endswith("_test"):
        return
    if os.environ.get("ALLOW_DEV_DB_TESTS") == "1":
        return
    raise RuntimeError(
        f"Refusing to run the test suite against database {name!r}: every test "
        "drops all tables in it. Set TEST_DB_URL to a dedicated database whose "
        "name ends in '_test', e.g.\n"
        "  TEST_DB_URL=postgresql+asyncpg://oryonfoods:oryonfoods@localhost:5435/"
        "oryonfoods_pos_test uv run pytest\n"
        "Set ALLOW_DEV_DB_TESTS=1 only if you really intend to wipe that database."
    )



@pytest_asyncio.fixture(scope="session")
def event_loop():
    import asyncio

    loop = asyncio.new_event_loop()
    yield loop
    loop.close()


@pytest.fixture(autouse=True)
def _use_test_jwt_public_key(monkeypatch: pytest.MonkeyPatch) -> None:
    """Verify tokens with the test keypair embedded in the test suite.

    ``keys/public.pem`` holds the deployment key and may rotate independently
    of the tests.  Patching the loader keeps token tests focused on JWT
    handling rather than on whichever key happens to be checked in.
    """
    from app.core import security
    from tests.test_token_verification import TEST_PUBLIC_KEY

    monkeypatch.setattr(security, "_load_public_key", lambda: TEST_PUBLIC_KEY)


@pytest.fixture
async def client() -> AsyncGenerator[AsyncClient, None]:
    """FastAPI test client using ASGI transport (no server needed)."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


@pytest_asyncio.fixture(autouse=True)
async def _apply_migrations() -> AsyncGenerator[None, None]:
    """Create all tables before each test and drop them after.

    Uses SQLModel.metadata.create_all (standard test practice) rather than
    running Alembic migrations.  This mirrors Identity Service's test setup
    and avoids coupling test execution to migration file state.
    """
    _assert_safe_database()
    async with engine.begin() as conn:
        await conn.run_sync(SQLModel.metadata.create_all)
    try:
        yield
    finally:
        async with engine.begin() as conn:
            await conn.run_sync(SQLModel.metadata.drop_all)


@pytest_asyncio.fixture
async def db_session() -> AsyncGenerator[AsyncSession, None]:
    """Provide an isolated DB session backed by Postgres.

    Tables are created before each test and dropped after (autouse fixture above).
    Each test gets a fresh set of tables, so data never leaks between tests.
    """
    async with async_session_factory() as session:
        yield session
