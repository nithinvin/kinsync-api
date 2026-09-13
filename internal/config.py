"""Application configuration loaded and validated from the environment."""

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Runtime configuration for the kinsync-api service.

    All values are sourced from environment variables (or a local ``.env``
    file during development). Required fields intentionally have no default
    so that a misconfigured deployment fails fast at startup rather than
    behaving unpredictably at request time.
    """

    model_config = SettingsConfigDict(env_file='.env', env_file_encoding='utf-8', extra='ignore')

    database_url: str = Field(
        ...,
        min_length=1,
        description='SQLAlchemy async connection URL for PostgreSQL, '
        'e.g. postgresql+asyncpg://user:pass@host/kinsync',
    )
    log_level: str = Field(default='INFO', description='Root logger level')


def get_settings() -> Settings:
    """Load and validate settings from the environment.

    Raises:
        pydantic.ValidationError: if required configuration is missing or invalid.
    """
    return Settings()  # type: ignore[call-arg]  # values are sourced from the environment
