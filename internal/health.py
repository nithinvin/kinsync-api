"""Health-check API routes (liveness and database connectivity)."""

import logging

from fastapi import APIRouter, HTTPException, Request

from internal.database import DatabaseConnectionError, check_connection

logger = logging.getLogger(__name__)

router = APIRouter()


@router.get('/health')
async def get_health() -> dict[str, str]:
    """Liveness check; returns ok whenever the process is running."""
    return {'status': 'ok'}


@router.get('/health/db')
async def get_health_db(request: Request) -> dict[str, str]:
    """Confirm PostgreSQL connectivity by executing a trivial query.

    Raises:
        HTTPException: with status 503 if the database is unreachable.
    """
    engine = request.app.state.db_engine
    try:
        await check_connection(engine)
    except DatabaseConnectionError as exc:
        raise HTTPException(status_code=503, detail='Database unreachable') from exc
    return {'status': 'ok'}
