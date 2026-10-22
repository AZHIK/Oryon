"""Async SQLAlchemy engine and session factory wired via Settings.

Usage:
    async with get_db() as session:
        result = await session.exec(select(Model).where(...))

Pattern: session.exec() is SQLModel's wrapper around session.execute()
that auto-unwraps Result into scalars.  Prefer session.exec() for
SQLModel models; fall back to session.execute() for raw SQL or
SQLAlchemy-core queries.

This service uses Alembic migrations exclusively for schema management.
"""

from collections.abc import AsyncGenerator

from sqlalchemy.ext.asyncio import (
    async_sessionmaker,
    create_async_engine,
)
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.config import get_settings

settings = get_settings()

# The test suite runs with TEST_DB_URL set (via the api-dev container or
# conftest), pointing the engine at the separate test database.  Normal
# runs leave it unset and use the dev/prod URL.
_db_url = settings.test_db_url or settings.db_url

engine = create_async_engine(
    _db_url,
    echo=settings.debug,
    pool_pre_ping=True,
)

async_session_factory = async_sessionmaker(
    bind=engine,
    class_=AsyncSession,
    expire_on_commit=False,
)


async def get_db() -> AsyncGenerator[AsyncSession, None]:
    """FastAPI dependency that yields an async DB session."""
    async with async_session_factory() as session:
        try:
            yield session
        finally:
            await session.close()


get_async_session = get_db
