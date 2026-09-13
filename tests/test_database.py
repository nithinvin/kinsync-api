"""Tests for internal.database."""

import pytest
from sqlalchemy.ext.asyncio import create_async_engine

from internal.config import Settings
from internal.database import DatabaseConnectionError, check_connection, create_engine


def test_create_engine_uses_configured_database_url() -> None:
    """Happy path: the engine is built with the driver from settings."""
    settings = Settings(_env_file=None, database_url='sqlite+aiosqlite:///:memory:')  # type: ignore[call-arg]

    engine = create_engine(settings)

    assert engine.url.drivername == 'sqlite+aiosqlite'


@pytest.mark.asyncio
async def test_check_connection_succeeds_against_reachable_database() -> None:
    """Happy path: a reachable database does not raise."""
    engine = create_async_engine('sqlite+aiosqlite:///:memory:')

    await check_connection(engine)


@pytest.mark.asyncio
async def test_check_connection_raises_specific_error_when_unreachable() -> None:
    """Error path: an unreachable database raises DatabaseConnectionError, not a raw driver error."""
    engine = create_async_engine('sqlite+aiosqlite:////nonexistent-dir/does-not-exist.db')

    with pytest.raises(DatabaseConnectionError):
        await check_connection(engine)
