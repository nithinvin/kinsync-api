"""Database engine creation and connectivity checks."""

import logging

from sqlalchemy import text
from sqlalchemy.engine import make_url
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.ext.asyncio import AsyncEngine, create_async_engine

from internal.config import Settings

logger = logging.getLogger(__name__)


class DatabaseConnectionError(RuntimeError):
    """Raised when the database cannot be reached or queried."""


def create_engine(settings: Settings) -> AsyncEngine:
    """Build the async SQLAlchemy engine from configured settings."""
    url = make_url(settings.database_url)
    if url.get_backend_name() == 'postgresql':
        # Postgres is only ever reached over loopback, so client-side TLS is unnecessary here
        # (public traffic is already terminated at Caddy). This also sidesteps asyncpg's default
        # 'prefer' sslmode, which probes ~/.postgresql/postgresql.crt and raises PermissionError
        # under systemd's ProtectHome=true sandboxing.
        url = url.update_query_dict({'ssl': 'disable'})
    return create_async_engine(url, pool_pre_ping=True)


async def check_connection(engine: AsyncEngine) -> None:
    """Run a trivial query to confirm the database is reachable.

    Args:
        engine: The async SQLAlchemy engine to check.

    Raises:
        DatabaseConnectionError: if the query fails for any reason.
    """
    try:
        async with engine.connect() as connection:
            await connection.execute(text('SELECT 1'))
    except SQLAlchemyError as exc:
        logger.error('Database connectivity check failed: %s', exc)
        raise DatabaseConnectionError('Unable to reach the database') from exc
