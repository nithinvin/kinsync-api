"""Tests for internal.config."""

import pytest
from pydantic import ValidationError

from internal.config import Settings, get_settings


def test_get_settings_reads_database_url_from_env(monkeypatch: pytest.MonkeyPatch) -> None:
    """Happy path: required DATABASE_URL is read and LOG_LEVEL defaults to INFO."""
    monkeypatch.setenv('DATABASE_URL', 'postgresql+asyncpg://user:pass@localhost/kinsync')
    monkeypatch.delenv('LOG_LEVEL', raising=False)

    settings = get_settings()

    assert settings.database_url == 'postgresql+asyncpg://user:pass@localhost/kinsync'
    assert settings.log_level == 'INFO'


def test_get_settings_reads_custom_log_level(monkeypatch: pytest.MonkeyPatch) -> None:
    """Edge case: an explicit LOG_LEVEL overrides the default."""
    monkeypatch.setenv('DATABASE_URL', 'postgresql+asyncpg://user:pass@localhost/kinsync')
    monkeypatch.setenv('LOG_LEVEL', 'DEBUG')

    settings = get_settings()

    assert settings.log_level == 'DEBUG'


def test_settings_missing_database_url_raises(monkeypatch: pytest.MonkeyPatch) -> None:
    """Error path: missing required configuration fails fast at startup."""
    monkeypatch.delenv('DATABASE_URL', raising=False)

    with pytest.raises(ValidationError):
        Settings(_env_file=None)  # type: ignore[call-arg]


def test_settings_rejects_empty_database_url(monkeypatch: pytest.MonkeyPatch) -> None:
    """Malformed input: an empty DATABASE_URL is rejected rather than silently accepted."""
    with pytest.raises(ValidationError):
        Settings(_env_file=None, database_url='')  # type: ignore[call-arg]
