"""Tests for internal.health routes."""

from collections.abc import Iterator

import pytest
from fastapi.testclient import TestClient

from internal.database import DatabaseConnectionError
from main import create_app


@pytest.fixture(name='client')
def fixture_client(monkeypatch: pytest.MonkeyPatch) -> Iterator[TestClient]:
    """A TestClient wired to an in-memory sqlite database via app lifespan."""
    monkeypatch.setenv('DATABASE_URL', 'sqlite+aiosqlite:///:memory:')
    app = create_app()
    with TestClient(app) as test_client:
        yield test_client


def test_health_returns_ok(client: TestClient) -> None:
    """Happy path: liveness check always reports ok."""
    response = client.get('/health')

    assert response.status_code == 200
    assert response.json() == {'status': 'ok'}


def test_health_db_returns_ok_when_database_reachable(client: TestClient) -> None:
    """Happy path: db health check reports ok when the database responds."""
    response = client.get('/health/db')

    assert response.status_code == 200
    assert response.json() == {'status': 'ok'}


def test_health_db_returns_503_when_database_unreachable(
    client: TestClient, monkeypatch: pytest.MonkeyPatch
) -> None:
    """Error path: db health check surfaces a 503 without leaking driver internals."""

    async def _raise_unreachable(*_args: object, **_kwargs: object) -> None:
        raise DatabaseConnectionError('boom')

    monkeypatch.setattr('internal.health.check_connection', _raise_unreachable)

    response = client.get('/health/db')

    assert response.status_code == 503
    assert response.json() == {'detail': 'Database unreachable'}
