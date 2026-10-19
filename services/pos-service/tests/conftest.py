"""pytest fixtures — async client, test database session."""

from collections.abc import AsyncGenerator

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from sqlmodel import SQLModel
from sqlmodel.ext.asyncio.session import AsyncSession

from app.db.session import async_session_factory, engine
from app.main import app


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
